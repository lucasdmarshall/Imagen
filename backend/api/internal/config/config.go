package config

import (
	"os"
	"strconv"
	"strings"
)

// Config holds runtime configuration, sourced entirely from the environment.
// Never hardcode secrets. See .env.example.
type Config struct {
	Port         string // HTTP port to listen on.
	DatabaseURL  string // Postgres connection string (empty => in-memory store).
	AIServiceURL string // Base URL of the Python AI service.
	Environment  string // "development" | "production".

	// DevTools mounts the DISPOSABLE /api/dev/* routes. Must be false in prod.
	// Delete the internal/devtools package and this flag after development.
	DevTools bool

	// Optional admin bootstrap: if both are set, an admin account is created
	// (or promoted) at startup. Lets production seed its first admin without
	// the dev tools. Never log the password.
	AdminEmail    string
	AdminPassword string

	// Security
	AllowedOrigins  []string // CORS allow-list.
	RateLimitPerMin int      // Per-IP requests per minute.
	MaxBodyBytes    int64    // Max request body size.
}

// IsProd reports whether the server runs in production mode.
func (c Config) IsProd() bool { return c.Environment == "production" }

// Load reads configuration from environment variables, applying sane defaults
// for local development.
func Load() Config {
	env := getenv("APP_ENV", "development")
	return Config{
		Port:         getenv("PORT", "8080"),
		DatabaseURL:  getenv("DATABASE_URL", ""),
		AIServiceURL: getenv("AI_SERVICE_URL", "http://localhost:8000"),
		Environment:  env,
		// Dev tools default on in development, always off outside it.
		DevTools: env == "development" && getbool("DEV_TOOLS", true),

		AdminEmail:    getenv("ADMIN_EMAIL", ""),
		AdminPassword: getenv("ADMIN_PASSWORD", ""),

		AllowedOrigins: getlist("ALLOWED_ORIGINS",
			[]string{
				"http://localhost:5100", "http://localhost:5200",
				"http://127.0.0.1:5100", "http://127.0.0.1:5200",
				"http://localhost:8080", "http://localhost:3000",
			}),
		RateLimitPerMin: getint("RATE_LIMIT_PER_MIN", 120),
		// 32 MiB — phone camera JPEGs (and Flutter web, which often skips
		// client-side resize) otherwise 413 the upload.
		MaxBodyBytes: int64(getint("MAX_BODY_BYTES", 32<<20)),
	}
}

func getint(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}

func getlist(key string, fallback []string) []string {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	parts := strings.Split(v, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getbool(key string, fallback bool) bool {
	if v := os.Getenv(key); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return fallback
}
