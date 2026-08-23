package config

import (
	"os"
	"strconv"
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
}

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
	}
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
