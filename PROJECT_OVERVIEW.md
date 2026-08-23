# SHOW — Project Overview

> Perimeter-driven image prompter with pixel-perfect customization.
> Last updated: 2026-08-23

---

## 1. Product summary

**SHOW** is a mobile-first (Android) application for generating AI image prompts
and AI images with **perimeter-driven, pixel-perfect customization** — the user
defines regions/perimeters on a canvas and controls the prompt and generation
behavior per region, rather than relying on a single global prompt.

The product ships as **two applications**:

| App | Audience | Purpose |
|-----|----------|---------|
| **Client App** | End users (age 40+) | Prompt + image generation, store, subscriptions, profile |
| **Admin App** | Operators / staff | User management, content/store management, moderation, analytics |

Both apps share one design system and talk to the same backend.

### Two modes (Client App)

1. **Prompt Generator** — build and refine structured, perimeter-aware text prompts.
2. **Image Generator** — render images from prompts. User picks one of two models:
   - **Gemini 3.1 Flash "Nano Banana Pro"**
   - **GPT Image** ("GPT 2 image" — *model id to be confirmed*)

All AI calls are routed through **OpenRouter.ai**.

---

## 2. Target users & UX principles

Primary users are **40 and older**. UI/UX must be crafted deliberately for this
audience:

- **Large touch targets** — minimum 48–56 dp; generous spacing.
- **Larger base typography** — comfortable default reading size, high legibility.
- **High contrast** — meet/exceed WCAG AA; matte, non-glossy surfaces.
- **Simple, shallow navigation** — few steps, obvious affordances, clear labels.
- **Forgiving interactions** — confirmations for destructive/irreversible actions,
  clear undo where possible.
- **No visual noise** — the design language (below) intentionally strips borders,
  cards, and boxes so hierarchy comes from type, spacing, and alignment.

---

## 3. Design system

**Style:** borderless, cardless, boxless — GitLab / **Swiss (International
Typographic) style**. Hierarchy is expressed through **whitespace, typographic
scale, alignment to a grid, and restrained use of dividers** — not through
outlines, drop shadows, or card containers.

- **Fonts:**
  - Latin: **Plus Jakarta Sans**
  - Myanmar: **TBD** (to be specified by the team)
- **Icons:** **Pagifye Icons** *(icon package/source to be confirmed & wired up)*
- **Color:**
  - **Gradients are strictly prohibited.** Flat, matte fills only.
  - Greys and black: **matte** tones (no gloss, no gradient).
  - White: **cream-ish / warm white** (never pure #FFFFFF as a surface).
  - Accent colors allowed, but flat and matte.
- **No elevation gimmicks** — avoid heavy shadows; prefer spacing and rules.

> Design tokens (color, type scale, spacing) live in the shared UI package so both
> apps stay consistent. See `packages/show_ui`.

---

## 4. Feature scope

### Client App
- Splash screen
- User profile system (auth, profile, preferences)
- **Prompt Generator** mode (perimeter-driven)
- **Image Generator** mode (model choice: Nano Banana Pro / GPT Image)
- Store
- Subscriptions: **Free**, **Pro — Monthly**, **Pro — Yearly**
- Generation history / library

### Admin App
- Splash screen
- Admin auth
- User management (view/search/suspend users)
- Store / catalog management
- Subscription & plan management
- Moderation of generated content
- Analytics / dashboards

---

## 5. Technical architecture

```
                ┌──────────────┐        ┌──────────────┐
                │  Client App  │        │  Admin App   │
                │  (Flutter)   │        │  (Flutter)   │
                └──────┬───────┘        └──────┬───────┘
                       │  HTTPS / REST         │
                       └───────────┬───────────┘
                                   ▼
                          ┌────────────────┐
                          │   Go API       │  Auth, CRUD, store,
                          │  (REST/JSON)   │  subscriptions, users
                          └───┬────────┬───┘
                              │        │
                   ┌──────────▼──┐   ┌─▼───────────────┐
                   │  Postgres   │   │  Python AI svc  │
                   │  (database) │   │  (OpenRouter)   │
                   └─────────────┘   └───────┬─────────┘
                                             ▼
                                     ┌────────────────┐
                                     │  OpenRouter.ai │
                                     └────────────────┘
```

### Stack
- **Frontend:** Flutter (Android target; **Flutter Web** used as the dev/preview server).
- **API / CRUD:** **Go** — REST/JSON, auth, users, store, subscriptions.
- **AI service:** **Python** — prompt logic + image generation via **OpenRouter.ai**.
- **Database:** **Postgres**.
  - Production: server provided by the team.
  - **Dev: no server is provided** → local Postgres via Docker Compose (included),
    configured through environment variables.

### Why two backend services
- Go handles high-throughput, strongly-typed CRUD and business logic.
- Python handles AI/model orchestration where the ecosystem (OpenRouter SDKs,
  image tooling) is strongest. The Go API is the single gateway the apps talk to;
  it calls the Python AI service internally.

---

## 6. Repository layout

```
SHOW/
├── PROJECT_OVERVIEW.md          # this file
├── README.md                    # quickstart & dev commands
├── .gitignore
├── .env.example                 # root-level shared env template
├── docker-compose.yml           # local Postgres for dev
├── Makefile                     # common dev tasks
│
├── apps/
│   ├── client/                  # Flutter — Client App
│   └── admin/                   # Flutter — Admin App
│
├── packages/
│   └── show_ui/                 # shared Flutter design system (tokens, widgets)
│
└── backend/
    ├── api/                     # Go — REST API, CRUD, auth, store, subs
    └── ai/                      # Python — AI orchestration (OpenRouter)
```

---

## 7. Environments & configuration

Configuration is via environment variables (never commit secrets):

- `DATABASE_URL` — Postgres connection string.
- `OPENROUTER_API_KEY` — OpenRouter credential (AI service only).
- `AI_SERVICE_URL` — where the Go API reaches the Python AI service.
- `API_BASE_URL` — where the Flutter apps reach the Go API.

Templates are provided as `.env.example` files at each service; copy to `.env`
locally. Production values come from the deployment environment.

---

## 8. Open items to confirm

These were noted during setup and need a decision from the team:

1. **Pagifye Icons** — confirm the exact icon set/package and how it is licensed
   & pulled into Flutter (font, SVG set, or pub package).
2. **"GPT 2 image"** — confirm the exact OpenRouter model id (assumed to be an
   OpenAI GPT image model).
3. **"Gemini 3.1 Flash Nano Banana Pro"** — confirm the exact OpenRouter model id.
4. **Myanmar font** — to be specified.
5. **Auth strategy** — email/password, OTP, social? (affects profile system).
6. **Payments** — store & subscription billing provider (Play Billing, Stripe, etc.).

---

## 9. Dev environment status

Verified locally at setup time:

- Flutter 3.44.4 (Dart 3.12.2)
- Go 1.24.6
- Python 3.14.5 (pip 26.1.1)
- Git 2.54

See `README.md` for how to run each service.
