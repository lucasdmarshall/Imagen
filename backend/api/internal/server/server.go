package server

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/show/api/internal/config"
	"github.com/show/api/internal/devtools"
	"github.com/show/api/internal/httpx"
	"github.com/show/api/internal/middleware"
	"github.com/show/api/internal/payments"
	"github.com/show/api/internal/services"
)

// Server wires configuration, services, and the HTTP router together.
type Server struct {
	cfg config.Config
	log *slog.Logger
	svc *services.Services
}

func New(cfg config.Config, log *slog.Logger, svc *services.Services) *Server {
	return &Server{cfg: cfg, log: log, svc: svc}
}

// Routes builds the HTTP handler (Go 1.22+ method+path patterns).
func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	auth := s.svc.Auth

	// --- Public ---
	mux.HandleFunc("GET /healthz", s.handleHealth)
	mux.HandleFunc("POST /api/v1/auth/register", s.handleRegister)
	mux.HandleFunc("POST /api/v1/auth/login", s.handleLogin)
	mux.HandleFunc("POST /api/v1/auth/google", s.handleGoogleAuth)
	mux.HandleFunc("GET /api/v1/store/items", s.handleStoreItems)
	mux.HandleFunc("GET /api/v1/subscriptions/plans", s.handlePlans)
	mux.HandleFunc("GET /api/v1/payments/methods", s.handlePaymentMethods)

	// --- Authenticated (user) ---
	mux.HandleFunc("POST /api/v1/auth/logout", httpx.Auth(auth, s.handleLogout))
	mux.HandleFunc("GET /api/v1/profile", httpx.Auth(auth, s.handleGetProfile))
	mux.HandleFunc("PATCH /api/v1/profile", httpx.Auth(auth, s.handleUpdateProfile))
	mux.HandleFunc("GET /api/v1/credits/balance", httpx.Auth(auth, s.handleBalance))
	mux.HandleFunc("GET /api/v1/credits/history", httpx.Auth(auth, s.handleCreditHistory))
	mux.HandleFunc("GET /api/v1/notifications", httpx.Auth(auth, s.handleNotifications))
	mux.HandleFunc("POST /api/v1/notifications/{id}/read", httpx.Auth(auth, s.handleReadNotification))
	mux.HandleFunc("GET /api/v1/subscriptions/me", httpx.Auth(auth, s.handleMySubscription))
	mux.HandleFunc("POST /api/v1/prompts/generate", httpx.Auth(auth, s.handleGeneratePrompt))
	mux.HandleFunc("POST /api/v1/images/generate", httpx.Auth(auth, s.handleGenerateImage))
	mux.HandleFunc("POST /api/v1/payments/proof", httpx.Auth(auth, s.handlePaymentProof))

	// Guided Prompt Engine
	mux.HandleFunc("GET /api/v1/prompts/flow", httpx.Auth(auth, s.handleFlow))
	mux.HandleFunc("POST /api/v1/prompts/compile", httpx.Auth(auth, s.handleCompile))
	mux.HandleFunc("POST /api/v1/uploads", httpx.Auth(auth, s.handleUpload))
	mux.HandleFunc("GET /api/v1/uploads/{id}", httpx.Auth(auth, s.handleGetUpload))

	// --- Admin ---
	mux.HandleFunc("GET /api/v1/admin/users", httpx.AdminOnly(auth, s.handleAdminListUsers))
	mux.HandleFunc("GET /api/v1/admin/users/{id}", httpx.AdminOnly(auth, s.handleAdminUserDetail))
	mux.HandleFunc("POST /api/v1/admin/users/{id}/role", httpx.AdminOnly(auth, s.handleAdminSetRole))
	mux.HandleFunc("POST /api/v1/admin/users/{id}/approve", httpx.AdminOnly(auth, s.handleAdminSetApproval))
	mux.HandleFunc("POST /api/v1/admin/users/{id}/credits", httpx.AdminOnly(auth, s.handleAdminAdjustCredits))
	mux.HandleFunc("POST /api/v1/admin/users/{id}/plan", httpx.AdminOnly(auth, s.handleAdminSetPlan))
	mux.HandleFunc("POST /api/v1/admin/users/{id}/ban", httpx.AdminOnly(auth, s.handleAdminSetBan))
	mux.HandleFunc("POST /api/v1/admin/users/{id}/delete", httpx.AdminOnly(auth, s.handleAdminDeleteUser))
	mux.HandleFunc("POST /api/v1/admin/users/{id}/password", httpx.AdminOnly(auth, s.handleAdminResetPassword))
	mux.HandleFunc("GET /api/v1/admin/events", httpx.AdminOnly(auth, s.handleAdminEvents))
	mux.HandleFunc("GET /api/v1/admin/catalog", httpx.AdminOnly(auth, s.handleAdminCatalog))
	mux.HandleFunc("PATCH /api/v1/admin/catalog/plans/{id}", httpx.AdminOnly(auth, s.handleAdminUpdatePlan))
	mux.HandleFunc("PATCH /api/v1/admin/catalog/packs/{id}", httpx.AdminOnly(auth, s.handleAdminUpdatePack))
	mux.HandleFunc("POST /api/v1/admin/catalog/packs", httpx.AdminOnly(auth, s.handleAdminAddPack))
	mux.HandleFunc("DELETE /api/v1/admin/catalog/packs/{id}", httpx.AdminOnly(auth, s.handleAdminRemovePack))
	mux.HandleFunc("GET /api/v1/admin/payments", httpx.AdminOnly(auth, s.handleAdminListPayments))
	mux.HandleFunc("POST /api/v1/admin/payments/{id}/approve", httpx.AdminOnly(auth, s.handleAdminApprovePayment))
	mux.HandleFunc("POST /api/v1/admin/payments/{id}/reject", httpx.AdminOnly(auth, s.handleAdminRejectPayment))

	// --- DISPOSABLE dev tools (development only) ---
	// Delete the internal/devtools package and this block after development.
	if s.cfg.DevTools {
		devtools.Mount(mux, s.svc, s.log)
		s.log.Warn("DEV TOOLS ENABLED — /api/dev/* mounted; do not enable in production")
	}

	return s.withMiddleware(mux)
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	httpx.JSON(w, http.StatusOK, map[string]any{
		"status":   "ok",
		"env":      s.cfg.Environment,
		"devTools": s.cfg.DevTools,
		"time":     time.Now().UTC().Format(time.RFC3339),
	})
}

func (s *Server) handlePaymentMethods(w http.ResponseWriter, _ *http.Request) {
	httpx.JSON(w, http.StatusOK, map[string]any{"methods": payments.Methods()})
}

func (s *Server) handlePaymentProof(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	var in struct {
		ItemID        string `json:"itemId"`
		Method        string `json:"method"`
		ProofUploadID string `json:"proofUploadId"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	order, err := s.svc.Payments.SubmitProof(u, in.ItemID, in.Method, in.ProofUploadID)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusAccepted, order)
}

// withMiddleware wraps the router in the security + idempotency stack. Order
// (outermost first): recover → security headers → CORS → rate limit → body
// limit → request log → idempotency → router.
func (s *Server) withMiddleware(mux http.Handler) http.Handler {
	return middleware.Chain(mux,
		middleware.Recover(s.log),
		middleware.SecurityHeaders(s.cfg.IsProd()),
		middleware.CORS(s.cfg.AllowedOrigins),
		middleware.RateLimit(s.cfg.RateLimitPerMin),
		middleware.MaxBody(s.cfg.MaxBodyBytes),
		s.requestLog,
		middleware.Idempotency(s.svc.Store),
	)
}

func (s *Server) requestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		s.log.Info("request",
			"method", r.Method, "path", r.URL.Path,
			"dur_ms", time.Since(start).Milliseconds())
	})
}
