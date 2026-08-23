package server

import (
	"net/http"

	"github.com/show/api/internal/domain"
	"github.com/show/api/internal/httpx"
)

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
