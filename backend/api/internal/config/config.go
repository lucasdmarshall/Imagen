package config

import (
	"os"
)

// Config holds runtime configuration, sourced entirely from the environment.
// Never hardcode secrets. See .env.example.
type Config struct {
	Port         string // HTTP port to listen on.
	DatabaseURL  string // Postgres connection string.
	AIServiceURL string // Base URL of the Python AI service.
	Environment  string // "development" | "production".
}

// Load reads configuration from environment variables, applying sane defaults
// for local development.
func Load() Config {
	return Config{
		Port:         getenv("PORT", "8080"),
		DatabaseURL:  getenv("DATABASE_URL", ""),
		AIServiceURL: getenv("AI_SERVICE_URL", "http://localhost:8000"),
		Environment:  getenv("APP_ENV", "development"),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
