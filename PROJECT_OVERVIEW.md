# SHOW — Project Overview

> Guided, pixel-level image prompt-crafting engine.
> Last updated: 2026-08-24

---

## 1. Product summary

**SHOW** is a mobile-first (Android) application for generating AI image prompts
and AI images with **pixel-level customization** via a **Guided Prompt Engine** —
a step-by-step, branching questionnaire that asks the right follow-up for every
answer (person vs object vs scene, reference photo or not, expression, setting,
lighting, camera, style, …) and compiles a precise prompt, instead of relying on
a single global prompt. (The earlier spatial "perimeter/region canvas" idea was
replaced by this guided engine — far more approachable for the 40+ audience.)

The product ships as **two applications**:

| App | Audience | Purpose |
|-----|----------|---------|
| **Client App** | End users (age 40+) | Prompt + image generation, store, subscriptions, profile |
| **Admin App** | Operators / staff | User management, content/store management, moderation, analytics |

Both apps share one design system and talk to the same backend.

### Two modes (Client App)

1. **Prompt Generator** — the **Guided Prompt Engine** (branching questionnaire).
   At the end it shows the compiled prompt to **copy**, plus a **"generate this in
   the app?"** call-to-action that hands the prompt to the Image Generator.
   Optional AI polish uses text models `google/gemini-3.7-flash` (default),
   `openai/gpt-5.6-luna`, `openai/gpt-5-mini`.
2. **Image Generator** — render images from a prompt. User picks a model:
   - **Nano Banana Pro** — `google/gemini-3.1-flash-lite-image`
   - **GPT Image 2** — `openai/gpt-image-2`

All AI calls are routed through **OpenRouter.ai**.

> **Language:** Burmese (`my`) is the app default; English (`en`) is an optional
> switch. UI labels are bilingual; compiled prompts are English (image models
> expect English).

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
  - Latin: **Plus Jakarta Sans** (via `google_fonts`)
  - Myanmar: **NamKhone** (`assets/NamKhoneUnicode.ttf`, bundled in the client;
    applied via `ShowType.myanmarFontFamily`)
- **Icons:** **Hero Icons** (`heroicons` pub package)
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
- Store — **subscriptions + add-on credit packs**
- Subscriptions: **Free**, **Pro — Monthly**, **Pro — Yearly**
- Credits (balance + ledger), notifications
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

### API surface (Go)

Public: `POST /auth/register`, `POST /auth/login`, `GET /store/items`,
`GET /subscriptions/plans`, `GET /payments/methods`.

Authenticated (bearer token): `POST /auth/logout`, `GET|PATCH /profile`,
`GET /credits/balance`, `GET /credits/history`, `GET /notifications`,
`POST /notifications/{id}/read`, `GET /subscriptions/me`,
`POST /prompts/generate`, `POST /images/generate`, `POST /payments/proof`,
`GET /prompts/flow`, `POST /prompts/compile`, `POST /uploads`, `GET /uploads/{id}`.

Admin (admin role): `GET /admin/users`, `GET /admin/users/{id}`,
`POST /admin/users/{id}/role|credits|plan`.

**Credits:** every AI call consumes credits (prompt = 1, image = 5), refunded on
failure. Plans grant monthly credits; add-on packs top up. All movements are
recorded in an immutable ledger with running balance.

### Disposable dev tools (delete after development)

`internal/devtools` mounts **unauthenticated** `/api/dev/*` routes (development
only, guarded by `DEV_TOOLS`), driven by an interactive CLI at `cmd/devcli`:
create users, add/deduct credits, run AI calls, set plans/roles, send
notifications. **To remove entirely:** delete `internal/devtools/`,
`cmd/devcli/`, and the `DevTools` wiring in `config` + `server`.

Run it with:

```bash
cd backend/api && go run ./cmd/devcli
```

### Guided Prompt Engine

A **data-driven, condition-driven questionnaire** (`internal/promptflow`). A
`Flow` is an ordered list of `Node`s; the client shows nodes in `Order`,
skipping any whose `Condition` fails and any `Advanced` node in **Quick** mode.
Node types: `single`, `multi`, `text`, `image` (reference photo), `slider`.
Labels are bilingual (Burmese default); prompt fragments are English.

- **Composition (multi-element):** the first question is a multi-select of what's
  in the image — **person / object / scene** — and each element's questions
  appear only if selected (`Condition: elements~=person`, etc.). So "a woman
  holding a teapot in a village" composes person + object + scene in one image.
  Condition ops: `=`, `!=`, `~=` (contains), `!~=` (not contains).
- **Depth modes:** **Quick** (essentials only) vs **Detailed** (all `Advanced`
  nodes: hair, pose, camera angle/lens/DoF, color palette, composition, mood,
  in-image text, …) for full pixel-level control.
- **AI polish** and **live preview** are client-orchestrated: preview re-calls
  `/prompts/compile` (free); polish runs the draft through `/prompts/generate`
  (optional, 1 credit).

- `GET /prompts/flow` — serves the current flow (`DefaultFlow()` seed; later
  Admin-editable without an app release).
- `POST /prompts/compile` — assembles walked answers into one English prompt,
  **deterministically and free** (no AI, no credits), emitting each node's
  fragment in a fixed layer order (subject → attributes → setting → light →
  camera → style → technical). Navigation-only gates (e.g. yes/no "reference
  photo?") contribute nothing. Any choice node also accepts a custom free-text
  "Other".
- `POST /uploads` + `GET /uploads/{id}` — reference-photo storage (dev:
  in-memory; prod: object storage). The upload id becomes the `image` node's
  answer and is passed to the multimodal image model.

Flow: **Prompt Generator (guided) → compiled prompt (copy) → "generate in app?"
→ Image Generator (pick model) → render**.

### Security & idempotency

Every request passes through a hardened middleware stack (outermost first):
panic-recovery → security headers → strict CORS allow-list → per-IP rate limit
→ request body size cap → request log → **idempotency**.

- **Idempotency (required on all mutations):** every `POST/PATCH/PUT/DELETE`
  must carry an `Idempotency-Key` header (400 if missing). The response is
  cached and **replayed** for repeated keys (`Idempotency-Replayed: true`), so a
  retry never double-charges credits or double-creates. Keys are scoped by
  caller (token/IP) + method + path; concurrent same-key requests are
  serialized. Both clients (Flutter `ApiClient`, dev CLI) send keys automatically.
- **Auth:** bcrypt password hashing; opaque 32-byte bearer tokens with a 30-day
  expiry; generic auth errors; admin-role gate on admin routes.
- **Headers:** `X-Content-Type-Options`, `X-Frame-Options: DENY`,
  `Referrer-Policy: no-referrer`, `Content-Security-Policy`, `Cache-Control:
  no-store`, and HSTS in production.
- **Abuse limits:** per-IP rate limit (socket peer only — never a spoofable
  `X-Forwarded-For`), request body cap, and server read/write/idle timeouts.

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

**Resolved:**

- **Icons** — Hero Icons (`heroicons` package). ✔
- **Text models** — `google/gemini-3.7-flash` (default), `openai/gpt-5.6-luna`,
  `openai/gpt-5-mini`. ✔
- **Image models** — `google/gemini-3.1-flash-lite-image` (Nano Banana Pro),
  `openai/gpt-image-2` (GPT Image 2). ✔
- **Myanmar font** — NamKhone (`NamKhoneUnicode.ttf`), bundled in the client. ✔
- **Payments** — AYA Pay + KBZ Pay, manual transfer + proof flow. ✔

**Still open:**

1. **Payment details** — receiver phone (`09........`) and the AYA/KBZ **QR
   images** are placeholders; set real values before launch.
2. **Auth strategy** — email/password, OTP, social? (affects profile system).
3. **Admin app** — should it also bundle the NamKhone font? (currently client-only).

---

## 9. Dev environment status

Verified locally at setup time:

- Flutter 3.44.4 (Dart 3.12.2)
- Go 1.24.6
- Python 3.14.5 (pip 26.1.1)
- Git 2.54

See `README.md` for how to run each service.
