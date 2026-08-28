// Command api is the SHOW Go API server: auth, CRUD, store, subscriptions.
// It is the single gateway the Flutter apps talk to and it proxies AI work to
// the Python AI service.
package main

import (
	"context"
	"database/sql"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib" // registers the "pgx" database/sql driver

	"github.com/show/api/internal/aiclient"
	"github.com/show/api/internal/config"
	"github.com/show/api/internal/server"
	"github.com/show/api/internal/services"
	"github.com/show/api/internal/store"
	"github.com/show/api/migrations"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg := config.Load()

	// Use Postgres when DATABASE_URL is set (production), else the in-memory
	// store (local dev / tests). The two satisfy the same store.Store interface.
	var st store.Store
	if cfg.DatabaseURL != "" {
		db, err := sql.Open("pgx", cfg.DatabaseURL)
		if err != nil {
			log.Error("open database", "err", err)
			os.Exit(1)
		}
		db.SetMaxOpenConns(20)
		db.SetMaxIdleConns(5)
		db.SetConnMaxLifetime(time.Hour)
		if err := waitForDB(db, 30*time.Second); err != nil {
			log.Error("database not reachable", "err", err)
			os.Exit(1)
		}
		if err := store.Migrate(db, migrations.FS); err != nil {
			log.Error("run migrations", "err", err)
			os.Exit(1)
		}
		defer db.Close()
		st = store.NewPostgres(db)
		log.Info("store: postgres")
	} else {
		st = store.NewMemory()
		log.Info("store: in-memory")
	}
	ai := aiclient.New(cfg.AIServiceURL)
	svc := services.New(st, ai)

	// Bootstrap the first admin in production (dev tools are off there).
	if cfg.AdminEmail != "" {
		if err := svc.Auth.EnsureAdmin(cfg.AdminEmail, cfg.AdminPassword); err != nil {
			log.Error("ensure admin", "err", err)
		} else {
			log.Info("admin ensured", "email", cfg.AdminEmail)
		}
	}

	srv := server.New(cfg, log, svc)
	httpSrv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           srv.Routes(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      3 * time.Minute, // AI proxy calls can be slow.
		IdleTimeout:       120 * time.Second,
		MaxHeaderBytes:    1 << 16,
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

// waitForDB pings the database until it responds or the timeout elapses.
// Under docker-compose the API can start before Postgres is fully ready.
func waitForDB(db *sql.DB, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	var lastErr error
	for time.Now().Before(deadline) {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		lastErr = db.PingContext(ctx)
		cancel()
		if lastErr == nil {
			return nil
		}
		time.Sleep(time.Second)
	}
	return lastErr
}
