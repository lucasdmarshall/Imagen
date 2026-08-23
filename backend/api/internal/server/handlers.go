package server

import (
	"net/http"

	"github.com/show/api/internal/domain"
	"github.com/show/api/internal/httpx"
)

// --- Auth ---

type credentials struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"displayName"`
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var in credentials
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	u, token, err := s.svc.Auth.Register(in.Email, in.Password, in.DisplayName)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]any{"token": token, "user": u})
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var in credentials
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	u, token, err := s.svc.Auth.Login(in.Email, in.Password)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"token": token, "user": u})
}

func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	// The token was already validated by middleware; delete it.
	_ = s.svc.Auth.Logout(httpx.Bearer(r))
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// --- Profile ---

func (s *Server) handleGetProfile(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	httpx.JSON(w, http.StatusOK, u)
}

func (s *Server) handleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	var patch domain.Profile
	if err := httpx.Decode(r, &patch); err != nil {
		httpx.Error(w, err)
		return
	}
	updated, err := s.svc.Profile.Update(u.ID, patch)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, updated)
}

// --- Credits ---

func (s *Server) handleBalance(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	bal, err := s.svc.Credits.Balance(u.ID)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]int{"balance": bal})
}

func (s *Server) handleCreditHistory(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	txs, err := s.svc.Credits.History(u.ID)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"transactions": txs})
}

// --- Notifications ---

func (s *Server) handleNotifications(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	ns, err := s.svc.Notifications.List(u.ID)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"notifications": ns})
}

func (s *Server) handleReadNotification(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	if err := s.svc.Notifications.MarkRead(u.ID, r.PathValue("id")); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// --- Catalog / subscriptions ---

func (s *Server) handleStoreItems(w http.ResponseWriter, _ *http.Request) {
	httpx.JSON(w, http.StatusOK, map[string]any{"items": s.svc.Catalog.StoreItems()})
}

func (s *Server) handlePlans(w http.ResponseWriter, _ *http.Request) {
	httpx.JSON(w, http.StatusOK, map[string]any{"plans": s.svc.Catalog.Plans()})
}

func (s *Server) handleMySubscription(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	sub, err := s.svc.Subscriptions.Get(u.ID)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, sub)
}

// --- Generation ---

func (s *Server) handleGeneratePrompt(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	var body map[string]any
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Error(w, err)
		return
	}
	out, err := s.svc.Generation.GeneratePrompt(r.Context(), u.ID, body)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (s *Server) handleGenerateImage(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	var body map[string]any
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Error(w, err)
		return
	}
	out, err := s.svc.Generation.GenerateImage(r.Context(), u.ID, body)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}
