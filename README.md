# SHOW

Perimeter-driven image prompter with pixel-perfect customization. Two apps
(**Client** + **Admin**), a Go API, and a Python AI service.

See [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) for the full product & architecture spec.

## Layout

```
apps/client       Flutter — Client app (splash, modes, store, subscriptions, profile)
apps/admin        Flutter — Admin app (users, store, subs, moderation, analytics)
packages/show_ui  Shared design system (Swiss / matte / borderless tokens & theme)
backend/api       Go — REST API, CRUD, auth, store, subscriptions
backend/ai        Python (FastAPI) — AI orchestration via OpenRouter.ai
```

## Prerequisites

Flutter 3.44+, Go 1.24+, Python 3.14+, and (optional) Docker for local Postgres.

## First-time setup

```bash
cp .env.example .env
cp backend/api/.env.example backend/api/.env
cp backend/ai/.env.example backend/ai/.env   # add your OPENROUTER_API_KEY
```

## Running (dev)

**Postgres** (dev only — production DB is provided by the team):

```bash
docker compose up -d
```

**Go API** (http://localhost:8080):

```bash
cd backend/api && go run ./cmd/api
```

**Python AI service** (http://localhost:8000):

```bash
cd backend/ai && .venv/Scripts/python -m uvicorn app.main:app --reload --port 8000
```

**Flutter Client** (dev server = Flutter Web):

```bash
cd apps/client && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

**Flutter Admin:**

```bash
cd apps/admin && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

Common tasks are also wrapped in the [Makefile](Makefile) (`make api`, `make ai`, `make client`, `make db-up`).

## Design system

The look is **borderless, cardless, boxless — Swiss style**, matte greys/black,
cream-ish white, **no gradients**, tuned for users **40+** (large targets, big
type, high contrast). All tokens live in `packages/show_ui`. See PROJECT_OVERVIEW §3.

## Open items

A few things need confirmation before deeper build — see PROJECT_OVERVIEW §8
(Pagifye icon set, exact OpenRouter model ids, Myanmar font, auth & payments).
