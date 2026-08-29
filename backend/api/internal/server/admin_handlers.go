package server

import (
	"fmt"
	"net/http"
	"time"

	"github.com/show/api/internal/domain"
	"github.com/show/api/internal/httpx"
)

// handleAdminEvents is a long-lived SSE stream. Admin screens reload when a
// topic fires so lists stay live without closing the app.
func (s *Server) handleAdminEvents(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}
	// http.Server WriteTimeout would otherwise kill the stream after 3 minutes.
	_ = http.NewResponseController(w).SetWriteDeadline(time.Time{})

	h := w.Header()
	h.Set("Content-Type", "text/event-stream")
	h.Set("Cache-Control", "no-cache")
	h.Set("Connection", "keep-alive")
	h.Set("X-Accel-Buffering", "no")
	w.WriteHeader(http.StatusOK)
	flusher.Flush()

	ch, unsub := s.svc.Hub.Subscribe()
	defer unsub()

	write := func(event, data string) error {
		if _, err := fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event, data); err != nil {
			return err
		}
		flusher.Flush()
		return nil
	}
	if err := write("admin", `{"topic":"hello"}`); err != nil {
		return
	}

	tick := time.NewTicker(15 * time.Second)
	defer tick.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case topic, ok := <-ch:
			if !ok {
				return
			}
			if err := write("admin", fmt.Sprintf(`{"topic":%q}`, topic)); err != nil {
				return
			}
		case <-tick.C:
			if _, err := fmt.Fprint(w, ": ping\n\n"); err != nil {
				return
			}
			flusher.Flush()
		}
	}
}

func (s *Server) handleAdminListUsers(w http.ResponseWriter, _ *http.Request) {
	users, err := s.svc.Admin.ListUsers()
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"users": users})
}

func (s *Server) handleAdminUserDetail(w http.ResponseWriter, r *http.Request) {
	detail, err := s.svc.Admin.UserDetail(r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, detail)
}

func (s *Server) handleAdminSetRole(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Role domain.Role `json:"role"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.svc.Admin.SetRole(r.PathValue("id"), in.Role); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// handleAdminSetApproval approves (or revokes) a user's Waiting-Area access.
func (s *Server) handleAdminSetApproval(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Approved bool `json:"approved"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.svc.Admin.SetApproval(r.PathValue("id"), in.Approved); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleAdminAdjustCredits(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Delta int    `json:"delta"`
		Note  string `json:"note"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	tx, err := s.svc.Admin.AdjustCredits(r.PathValue("id"), in.Delta, in.Note)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, tx)
}

func (s *Server) handleAdminSetPlan(w http.ResponseWriter, r *http.Request) {
	var in struct {
		PlanID domain.PlanID `json:"planId"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.svc.Admin.SetPlan(r.PathValue("id"), in.PlanID); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleAdminSetBan(w http.ResponseWriter, r *http.Request) {
	admin := httpx.UserFrom(r.Context())
	var in struct {
		Banned bool `json:"banned"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	if err := s.svc.Admin.SetBan(admin.ID, r.PathValue("id"), in.Banned); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleAdminDeleteUser(w http.ResponseWriter, r *http.Request) {
	admin := httpx.UserFrom(r.Context())
	if err := s.svc.Admin.DeleteUser(admin.ID, r.PathValue("id")); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleAdminResetPassword(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Password string `json:"password"`
	}
	_ = httpx.Decode(r, &in)
	password, err := s.svc.Admin.ResetPassword(r.PathValue("id"), in.Password)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"password": password})
}

func (s *Server) handleAdminListPayments(w http.ResponseWriter, r *http.Request) {
	orders, err := s.svc.Admin.ListPayments(r.URL.Query().Get("status"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	if orders == nil {
		orders = []*domain.PaymentOrder{}
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"payments": orders})
}

func (s *Server) handleAdminApprovePayment(w http.ResponseWriter, r *http.Request) {
	admin := httpx.UserFrom(r.Context())
	order, err := s.svc.Admin.ApprovePayment(admin.ID, r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, order)
}

func (s *Server) handleAdminRejectPayment(w http.ResponseWriter, r *http.Request) {
	admin := httpx.UserFrom(r.Context())
	var in struct {
		Note string `json:"note"`
	}
	_ = httpx.Decode(r, &in)
	order, err := s.svc.Admin.RejectPayment(admin.ID, r.PathValue("id"), in.Note)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, order)
}

func (s *Server) handleAdminCatalog(w http.ResponseWriter, _ *http.Request) {
	plans, err := s.svc.Catalog.Plans()
	if err != nil {
		httpx.Error(w, err)
		return
	}
	items, err := s.svc.Catalog.StoreItems()
	if err != nil {
		httpx.Error(w, err)
		return
	}
	if plans == nil {
		plans = []domain.Plan{}
	}
	if items == nil {
		items = []domain.StoreItem{}
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"plans": plans, "items": items})
}

func (s *Server) handleAdminUpdatePlan(w http.ResponseWriter, r *http.Request) {
	var in struct {
		PriceMMK       *int `json:"priceMmk"`
		MonthlyCredits *int `json:"monthlyCredits"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	plan, err := s.svc.Catalog.UpdatePlan(domain.PlanID(r.PathValue("id")), in.PriceMMK, in.MonthlyCredits)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, plan)
}

func (s *Server) handleAdminUpdatePack(w http.ResponseWriter, r *http.Request) {
	var in struct {
		PriceMMK *int `json:"priceMmk"`
		Credits  *int `json:"credits"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	item, err := s.svc.Catalog.UpdatePack(r.PathValue("id"), in.PriceMMK, in.Credits)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, item)
}

func (s *Server) handleAdminAddPack(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Credits  int `json:"credits"`
		PriceMMK int `json:"priceMmk"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	item, err := s.svc.Catalog.AddPack(in.Credits, in.PriceMMK)
	if err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, item)
}

func (s *Server) handleAdminRemovePack(w http.ResponseWriter, r *http.Request) {
	if err := s.svc.Catalog.RemovePack(r.PathValue("id")); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
