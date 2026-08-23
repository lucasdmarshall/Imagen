// Command api is the SHOW Go API server: auth, CRUD, store, subscriptions.
// It is the single gateway the Flutter apps talk to and it proxies AI work to
// the Python AI service.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/show/api/internal/aiclient"
	"github.com/show/api/internal/config"
	"github.com/show/api/internal/server"
	"github.com/show/api/internal/services"
	"github.com/show/api/internal/store"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg := config.Load()

	// Dev has no Postgres server, so default to the in-memory store. A
	// Postgres-backed store.Store can replace this when DATABASE_URL is set.
	st := store.NewMemory()
	ai := aiclient.New(cfg.AIServiceURL)
	svc := services.New(st, ai)

	srv := server.New(cfg, log, svc)
	httpSrv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           srv.Routes(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Info("api listening", "port", cfg.Port, "env", cfg.Environment)
		if err := httpSrv.ListenAndServe(); err != nil &&
			!errors.Is(err, http.ErrServerClosed) {
			log.Error("server error", "err", err)
			os.Exit(1)
		}
	}()

	// Graceful shutdown.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	log.Info("shutting down")
	if err := httpSrv.Shutdown(ctx); err != nil {
		log.Error("shutdown error", "err", err)
	}
}
