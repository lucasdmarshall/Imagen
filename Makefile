# SHOW — common dev tasks.
.PHONY: help db-up db-down api ai client admin get analyze

help:
	@echo "db-up     start local Postgres (docker)"
	@echo "db-down   stop local Postgres"
	@echo "api       run Go API on :8080"
	@echo "ai        run Python AI service on :8000"
	@echo "client    run Flutter client (web/chrome)"
	@echo "admin     run Flutter admin (web/chrome)"
	@echo "get       flutter pub get for all Flutter packages"
	@echo "analyze   flutter analyze all Flutter packages"

db-up:
	docker compose up -d

db-down:
	docker compose down

api:
	cd backend/api && go run ./cmd/api

ai:
	cd backend/ai && .venv/Scripts/python -m uvicorn app.main:app --reload --port 8000

client:
	cd apps/client && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

admin:
	cd apps/admin && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

get:
	cd packages/show_ui && flutter pub get
	cd apps/client && flutter pub get
	cd apps/admin && flutter pub get

analyze:
	cd apps/client && flutter analyze lib
	cd apps/admin && flutter analyze lib
	cd packages/show_ui && flutter analyze lib
