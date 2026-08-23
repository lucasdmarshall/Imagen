// Package devtools provides DISPOSABLE development-only HTTP endpoints under
// /api/dev/*. They are UNAUTHENTICATED and let the dev CLI (cmd/devcli) drive
// the system directly: create users, add/deduct credits, run AI calls, and
// perform admin actions (roles, plans, subscriptions).
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  DELETE-AFTER-DEVELOPMENT                                                 │
// │  To remove entirely:                                                      │
// │    1. delete this package  (backend/api/internal/devtools/)              │
// │    2. delete the CLI        (backend/api/cmd/devcli/)                     │
// │    3. delete the `if s.cfg.DevTools { devtools.Mount(...) }` block in    │
// │       internal/server/server.go and the DevTools field in config.        │
// └─────────────────────────────────────────────────────────────────────────┘
package devtools

import (
	"log/slog"
	"net/http"

	"github.com/show/api/internal/domain"
	"github.com/show/api/internal/httpx"
	"github.com/show/api/internal/services"
)

// Mount registers the disposable dev routes on mux.
func Mount(mux *http.ServeMux, svc *services.Services, log *slog.Logger) {
	h := &handler{svc: svc, log: log}
	mux.HandleFunc("POST /api/dev/users", h.createUser)
	mux.HandleFunc("GET /api/dev/users", h.listUsers)
	mux.HandleFunc("GET /api/dev/users/{id}", h.userDetail)
	mux.HandleFunc("POST /api/dev/users/{id}/credits", h.adjustCredits)
	mux.HandleFunc("POST /api/dev/users/{id}/plan", h.setPlan)
	mux.HandleFunc("POST /api/dev/users/{id}/role", h.setRole)
	mux.HandleFunc("POST /api/dev/users/{id}/notify", h.notify)
	mux.HandleFunc("POST /api/dev/users/{id}/ai/prompt", h.aiPrompt)
	mux.HandleFunc("POST /api/dev/users/{id}/ai/image", h.aiImage)
}

type handler struct {
	svc *services.Services
	log *slog.Logger
}

func (h *handler) createUser(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email       string `json:"email"`
		Password    string `json:"password"`
		DisplayName string `json:"displayName"`
		Admin       bool   `json:"admin"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	u, token, err := h.svc.Auth.Register(in.Email, in.Password, in.DisplayName)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	if in.Admin {
		_ = h.svc.Admin.SetRole(u.ID, domain.RoleAdmin)
		u.Role = domain.RoleAdmin
	}
	httpx.JSON(w, http.StatusCreated, map[string]any{"user": u, "token": token})
}

func (h *handler) listUsers(w http.ResponseWriter, _ *http.Request) {
	users, err := h.svc.Admin.ListUsers()
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"users": users})
}

func (h *handler) userDetail(w http.ResponseWriter, r *http.Request) {
	d, err := h.svc.Admin.UserDetail(r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, d)
}

// adjustCredits adds (positive) or deducts (negative) credits.
func (h *handler) adjustCredits(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Delta int    `json:"delta"`
		Note  string `json:"note"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	tx, err := h.svc.Admin.AdjustCredits(r.PathValue("id"), in.Delta, in.Note)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, tx)
}

func (h *handler) setPlan(w http.ResponseWriter, r *http.Request) {
	var in struct {
		PlanID domain.PlanID `json:"planId"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := h.svc.Admin.SetPlan(r.PathValue("id"), in.PlanID); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *handler) setRole(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Role domain.Role `json:"role"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := h.svc.Admin.SetRole(r.PathValue("id"), in.Role); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *handler) notify(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Title string `json:"title"`
		Body  string `json:"body"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	n, err := h.svc.Notifications.Notify(r.PathValue("id"), in.Title, in.Body)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, n)
}

func (h *handler) aiPrompt(w http.ResponseWriter, r *http.Request) {
	var body map[string]any
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Error(w, err)
		return
	}
	out, err := h.svc.Generation.GeneratePrompt(r.Context(), r.PathValue("id"), body)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *handler) aiImage(w http.ResponseWriter, r *http.Request) {
	var body map[string]any
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Error(w, err)
		return
	}
	out, err := h.svc.Generation.GenerateImage(r.Context(), r.PathValue("id"), body)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}
