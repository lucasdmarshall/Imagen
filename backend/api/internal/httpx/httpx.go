// Package httpx holds small HTTP helpers shared by the server and dev tools:
// JSON encoding, error mapping, and authentication middleware.
package httpx

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/show/api/internal/domain"
	"github.com/show/api/internal/services"
	"github.com/show/api/internal/store"
)

type ctxKey int

const userKey ctxKey = 0

// JSON writes v as a JSON response with the given status.
func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// Error writes a normalized JSON error, mapping known service/store errors to
// appropriate status codes.
func Error(w http.ResponseWriter, err error) {
	status := http.StatusInternalServerError
	code := "internal_error"
	switch {
	case errors.Is(err, services.ErrInvalidCredentials):
		status, code = http.StatusUnauthorized, "invalid_credentials"
	case errors.Is(err, services.ErrUnauthorized):
		status, code = http.StatusUnauthorized, "unauthorized"
	case errors.Is(err, services.ErrForbidden):
		status, code = http.StatusForbidden, "forbidden"
	case errors.Is(err, services.ErrInsufficientCredits):
		status, code = http.StatusPaymentRequired, "insufficient_credits"
	case errors.Is(err, store.ErrEmailTaken):
		status, code = http.StatusConflict, "email_taken"
	case errors.Is(err, store.ErrNotFound):
		status, code = http.StatusNotFound, "not_found"
	}
	JSON(w, status, map[string]string{"error": code, "detail": err.Error()})
}

// Decode reads a JSON request body into dst.
func Decode(r *http.Request, dst any) error {
	return json.NewDecoder(r.Body).Decode(dst)
}

// Auth wraps a handler, requiring a valid bearer token. The resolved user is
// placed in the request context (see UserFrom).
func Auth(auth *services.AuthService, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := Bearer(r)
		if token == "" {
			Error(w, services.ErrUnauthorized)
			return
		}
		u, err := auth.Authenticate(token)
		if err != nil {
			Error(w, services.ErrUnauthorized)
			return
		}
		ctx := context.WithValue(r.Context(), userKey, u)
		next(w, r.WithContext(ctx))
	}
}

// AdminOnly wraps Auth and additionally requires the admin role.
func AdminOnly(auth *services.AuthService, next http.HandlerFunc) http.HandlerFunc {
	return Auth(auth, func(w http.ResponseWriter, r *http.Request) {
		if u := UserFrom(r.Context()); u == nil || u.Role != domain.RoleAdmin {
			Error(w, services.ErrForbidden)
			return
		}
		next(w, r)
	})
}

// UserFrom returns the authenticated user from context, or nil.
func UserFrom(ctx context.Context) *domain.User {
	u, _ := ctx.Value(userKey).(*domain.User)
	return u
}

// Bearer extracts the bearer token from the Authorization header, or "".
func Bearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if strings.HasPrefix(strings.ToLower(h), "bearer ") {
		return strings.TrimSpace(h[7:])
	}
	return ""
}
