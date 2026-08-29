package server

import (
	"encoding/base64"
	"fmt"
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

func (s *Server) handleGoogleAuth(w http.ResponseWriter, r *http.Request) {
	var in struct {
		IDToken string `json:"id_token"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	u, token, err := s.svc.Auth.LoginWithGoogle(in.IDToken)
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
	wallet, err := s.svc.Credits.Wallet(u.ID)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"balance":             wallet.Total(),
		"subscriptionCredits": wallet.SubscriptionCredits,
		"addonCredits":        wallet.AddonCredits,
		"subPeriodEndsAt":     wallet.SubPeriodEndsAt,
	})
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
	items, err := s.svc.Catalog.StoreItems()
	if err != nil {
		httpx.Error(w, err)
		return
	}
	if items == nil {
		items = []domain.StoreItem{}
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"items": items})
}

func (s *Server) handlePlans(w http.ResponseWriter, _ *http.Request) {
	plans, err := s.svc.Catalog.Plans()
	if err != nil {
		httpx.Error(w, err)
		return
	}
	if plans == nil {
		plans = []domain.Plan{}
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"plans": plans})
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
	// Resolve uploaded reference photos into inline data URLs so the AI service
	// can do multimodal image editing (Outfit Swap, Face Swap, …). The AI
	// service consumes "images"; it ignores "reference_ids".
	if raw, ok := body["reference_ids"]; ok {
		if ids, ok := raw.([]any); ok {
			var images []string
			for _, idAny := range ids {
				id, _ := idAny.(string)
				if id == "" {
					continue
				}
				up, err := s.svc.Store.GetUpload(id)
				if err != nil {
					continue
				}
				ct := up.ContentType
				if ct == "" {
					ct = "image/jpeg"
				}
				images = append(images, fmt.Sprintf("data:%s;base64,%s",
					ct, base64.StdEncoding.EncodeToString(up.Data)))
			}
			if len(images) > 0 {
				body["images"] = images
			}
		}
		delete(body, "reference_ids")
	}
	out, err := s.svc.Generation.GenerateImage(r.Context(), u.ID, body)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}
