package server

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/show/api/internal/config"
	"github.com/show/api/internal/payments"
)

// Server wires configuration and the HTTP router together.
type Server struct {
	cfg config.Config
	log *slog.Logger
}

func New(cfg config.Config, log *slog.Logger) *Server {
	return &Server{cfg: cfg, log: log}
}

// Routes builds the HTTP handler. Uses Go 1.22+ method+path patterns.
//
// This is a skeleton: resource handlers return stubs so the API boots and is
// callable end-to-end before real CRUD + Postgres are implemented.
func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", s.handleHealth)

	// --- Users / profile ---
	mux.HandleFunc("GET /api/v1/users/me", s.stub("get current user profile"))
	mux.HandleFunc("PATCH /api/v1/users/me", s.stub("update profile"))

	// --- Store ---
	mux.HandleFunc("GET /api/v1/store/items", s.stub("list store items"))

	// --- Subscriptions (Free / Pro Monthly / Pro Yearly) ---
	mux.HandleFunc("GET /api/v1/subscriptions/plans", s.stub("list plans"))
	mux.HandleFunc("GET /api/v1/subscriptions/me", s.stub("current subscription"))

	// --- Payments (AYA Pay / KBZ Pay manual transfer) ---
	mux.HandleFunc("GET /api/v1/payments/methods", s.handlePaymentMethods)
	mux.HandleFunc("POST /api/v1/payments/proof", s.stub("submit payment proof"))

	// --- Generation (proxied to the Python AI service) ---
	mux.HandleFunc("POST /api/v1/prompts/generate", s.stub("generate prompt"))
	mux.HandleFunc("POST /api/v1/images/generate", s.stub("generate image"))

	return s.withMiddleware(mux)
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"status": "ok",
		"env":    s.cfg.Environment,
		"time":   time.Now().UTC().Format(time.RFC3339),
	})
}

func (s *Server) handlePaymentMethods(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"methods": payments.Methods()})
}

// stub returns a placeholder handler describing an unimplemented endpoint.
func (s *Server) stub(desc string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusNotImplemented, map[string]any{
			"error":  "not_implemented",
			"detail": desc,
		})
	}
}

// withMiddleware applies logging + JSON content type to every request.
func (s *Server) withMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		w.Header().Set("Content-Type", "application/json")
		next.ServeHTTP(w, r)
		s.log.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"dur_ms", time.Since(start).Milliseconds(),
		)
	})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
