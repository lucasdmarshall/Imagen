// Package middleware provides SHOW's security and idempotency HTTP layer:
// panic recovery, security headers, strict CORS, per-IP rate limiting, request
// body size limits, and Idempotency-Key handling for mutating requests.
package middleware

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/show/api/internal/store"
)

// Chain applies middlewares in order (first is outermost).
func Chain(h http.Handler, mws ...func(http.Handler) http.Handler) http.Handler {
	for i := len(mws) - 1; i >= 0; i-- {
		h = mws[i](h)
	}
	return h
}

// Recover converts panics into 500s without leaking stack traces to clients.
func Recover(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					log.Error("panic recovered", "err", rec, "path", r.URL.Path)
					writeErr(w, http.StatusInternalServerError, "internal_error", "internal error")
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

// SecurityHeaders sets conservative security headers on every response.
func SecurityHeaders(prod bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h := w.Header()
			h.Set("X-Content-Type-Options", "nosniff")
			h.Set("X-Frame-Options", "DENY")
			h.Set("Referrer-Policy", "no-referrer")
			h.Set("Cross-Origin-Opener-Policy", "same-origin")
			h.Set("Cache-Control", "no-store")
			h.Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
			h.Del("Server")
			if prod {
				h.Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
			}
			next.ServeHTTP(w, r)
		})
	}
}

// CORS applies a strict allow-list. Origins not on the list get no CORS headers
// (browser blocks them). Bearer-token auth means no cookies/credentials.
func CORS(allowed []string) func(http.Handler) http.Handler {
	set := map[string]bool{}
	for _, o := range allowed {
		set[strings.TrimSpace(o)] = true
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin != "" && set[origin] {
				h := w.Header()
				h.Set("Access-Control-Allow-Origin", origin)
				h.Set("Vary", "Origin")
				h.Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
				h.Set("Access-Control-Allow-Headers", "Authorization, Content-Type, Idempotency-Key")
				h.Set("Access-Control-Max-Age", "600")
			}
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// MaxBody caps request body size to mitigate memory-exhaustion abuse.
func MaxBody(n int64) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			r.Body = http.MaxBytesReader(w, r.Body, n)
			next.ServeHTTP(w, r)
		})
	}
}

// RateLimit is a per-IP fixed-window limiter (perMinute requests / 60s).
func RateLimit(perMinute int) func(http.Handler) http.Handler {
	type window struct {
		start time.Time
		count int
	}
	var (
		mu      sync.Mutex
		windows = map[string]*window{}
	)
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := clientIP(r)
			now := time.Now()
			mu.Lock()
			win := windows[ip]
			if win == nil || now.Sub(win.start) >= time.Minute {
				win = &window{start: now}
				windows[ip] = win
			}
			win.count++
			over := win.count > perMinute
			// Opportunistic cleanup to bound memory.
			if len(windows) > 10000 {
				for k, v := range windows {
					if now.Sub(v.start) >= time.Minute {
						delete(windows, k)
					}
				}
			}
			mu.Unlock()
			if over {
				w.Header().Set("Retry-After", "60")
				writeErr(w, http.StatusTooManyRequests, "rate_limited", "too many requests")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// Idempotency enforces an Idempotency-Key on mutating requests (POST/PATCH/
// PUT/DELETE) and replays the stored response for repeated keys, so retries
// never double-apply side effects (e.g. credit charges). Keys are scoped by
// caller (bearer token or IP) + method + path so they cannot collide or be
// guessed across users. Concurrent same-key requests are serialized.
func Idempotency(st store.Store) func(http.Handler) http.Handler {
	var (
		mu    sync.Mutex
		locks = map[string]*sync.Mutex{}
	)
	keyLock := func(k string) *sync.Mutex {
		mu.Lock()
		defer mu.Unlock()
		if l, ok := locks[k]; ok {
			return l
		}
		l := &sync.Mutex{}
		locks[k] = l
		return l
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if !isMutating(r.Method) {
				next.ServeHTTP(w, r)
				return
			}
			raw := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
			if raw == "" {
				writeErr(w, http.StatusBadRequest, "idempotency_key_required",
					"Idempotency-Key header is required for this request")
				return
			}
			scope := r.Header.Get("Authorization")
			if scope == "" {
				scope = clientIP(r)
			}
			key := hashKey(scope + "|" + r.Method + "|" + r.URL.Path + "|" + raw)

			// Serialize identical keys so concurrent retries don't both run.
			l := keyLock(key)
			l.Lock()
			defer l.Unlock()

			if cached, ok := st.GetIdempotent(key); ok {
				replay(w, cached)
				return
			}

			rec := &recorder{ResponseWriter: w, status: http.StatusOK, buf: &bytes.Buffer{}}
			next.ServeHTTP(rec, r)

			// Cache deterministic outcomes; let 5xx be retried.
			if rec.status < 500 {
				st.SaveIdempotent(key, store.IdempotentResult{
					Status: rec.status, Body: rec.buf.Bytes(),
				})
			}
		})
	}
}

// --- helpers ---

func isMutating(m string) bool {
	switch m {
	case http.MethodPost, http.MethodPatch, http.MethodPut, http.MethodDelete:
		return true
	}
	return false
}

type recorder struct {
	http.ResponseWriter
	status  int
	buf     *bytes.Buffer
	written bool
}

func (r *recorder) WriteHeader(code int) {
	r.status = code
	r.written = true
	r.ResponseWriter.WriteHeader(code)
}

func (r *recorder) Write(b []byte) (int, error) {
	if !r.written {
		r.written = true
	}
	r.buf.Write(b)
	return r.ResponseWriter.Write(b)
}

func replay(w http.ResponseWriter, res *store.IdempotentResult) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Idempotency-Replayed", "true")
	w.WriteHeader(res.Status)
	_, _ = w.Write(res.Body)
}

func clientIP(r *http.Request) string {
	// Trust only the socket peer — never a spoofable X-Forwarded-For header.
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func hashKey(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

func writeErr(w http.ResponseWriter, status int, code, detail string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": code, "detail": detail})
}
