package server

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"time"

	"github.com/show/api/internal/httpx"
	"github.com/show/api/internal/promptflow"
	"github.com/show/api/internal/store"
)

// handleFlow serves the current Guided Prompt Engine questionnaire. The client
// walks this graph to build answers. (Later: Admin-editable, served from DB.)
func (s *Server) handleFlow(w http.ResponseWriter, _ *http.Request) {
	httpx.JSON(w, http.StatusOK, promptflow.DefaultFlow())
}

// handleCompile assembles walked answers into a final English prompt. This is
// deterministic and free (no AI, no credits). The client shows the result for
// copy, then optionally hands it to the Image Generator.
func (s *Server) handleCompile(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Answers map[string]string `json:"answers"`
	}
	if err := httpx.Decode(r, &in); err != nil {
		httpx.Error(w, err)
		return
	}
	prompt := promptflow.DefaultFlow().Compile(in.Answers)
	httpx.JSON(w, http.StatusOK, map[string]string{"prompt": prompt})
}

// handleUpload stores a reference photo and returns its id + fetch URL.
func (s *Server) handleUpload(w http.ResponseWriter, r *http.Request) {
	u := httpx.UserFrom(r.Context())
	file, header, err := r.FormFile("file")
	if err != nil {
		httpx.Error(w, err)
		return
	}
	defer file.Close()

	buf := make([]byte, header.Size)
	if _, err := readFull(file, buf); err != nil {
		httpx.Error(w, err)
		return
	}
	ct := header.Header.Get("Content-Type")
	if ct == "" {
		ct = "application/octet-stream"
	}
	id := randID()
	if err := s.svc.Store.SaveUpload(&store.Upload{
		ID: id, UserID: u.ID, ContentType: ct, Data: buf, CreatedAt: time.Now().UTC(),
	}); err != nil {
		httpx.Error(w, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]string{
		"id": id, "url": "/api/v1/uploads/" + id,
	})
}

// handleGetUpload returns a stored reference photo's bytes.
func (s *Server) handleGetUpload(w http.ResponseWriter, r *http.Request) {
	up, err := s.svc.Store.GetUpload(r.PathValue("id"))
	if err != nil {
		httpx.Error(w, err)
		return
	}
	w.Header().Set("Content-Type", up.ContentType)
	w.Header().Set("Cache-Control", "private, max-age=3600")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(up.Data)
}

func randID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// readFull fills buf from r, tolerating short multipart reads.
func readFull(r interface{ Read([]byte) (int, error) }, buf []byte) (int, error) {
	total := 0
	for total < len(buf) {
		n, err := r.Read(buf[total:])
		total += n
		if err != nil {
			if total == len(buf) {
				return total, nil
			}
			return total, err
		}
	}
	return total, nil
}
