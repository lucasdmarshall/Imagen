# SHOW — Deployment (CI/CD)

Push to `main` → GitHub Actions runs CI → SSHes into the server → rebuilds and
restarts the Docker stack. This is the "over-the-air" path: nothing is deployed
by hand.

## Architecture on the server

Three containers, defined in [`docker-compose.yml`](docker-compose.yml):

| Container      | Image / build      | Exposed         | Purpose                     |
| -------------- | ------------------ | --------------- | --------------------------- |
| `show_postgres`| postgres:16-alpine | internal only   | Database (persistent volume)|
| `show_ai`      | `backend/ai`       | internal only   | Python FastAPI AI service   |
| `show_api`     | `backend/api`      | `8090` (public) | Go API gateway              |

The API reaches the AI service at `http://ai:8000` and Postgres at
`postgres:5432` over the compose network. Only the API is published, on the
host port from `API_HOST_PORT` (this server uses **8090** because 8080 is taken
by another app). Live: `http://187.52.120.117:8090/healthz`.

> **Persistence:** the Go API uses the Postgres store whenever `DATABASE_URL`
> is set (it is, via compose), so users/approvals survive redeploys. The
> embedded SQL migrations in `backend/api/migrations/` are idempotent and run
> automatically on every API startup.

> **First admin:** set `ADMIN_EMAIL` and `ADMIN_PASSWORD` in the server `.env`;
> the API creates/promotes that approved admin on startup (production has no dev
> tools). This server is seeded with `admin@show.dev`.

## One-time server setup

Run these on the server (`187.52.120.117`) once.

### 1. Install Docker + Compose plugin

```bash
curl -fsSL https://get.docker.com | sh
docker compose version   # confirm the v2 plugin is present
```

### 2. Clone the repo

```bash
git clone https://github.com/lucasdmarshall/Imagen.git /root/Imagen
cd /root/Imagen
```

Use `/root/Imagen` as `DEPLOY_PATH` (or pick another and set the secret to match).

### 3. Create the server `.env` (never committed)

```bash
cat > /root/Imagen/.env <<'EOF'
# ---- Postgres ----
POSTGRES_USER=show
POSTGRES_PASSWORD=CHANGE_ME_STRONG
POSTGRES_DB=show

# ---- App ----
APP_ENV=production
ALLOWED_ORIGINS=https://your-frontend-domain
DEV_TOOLS=false

# ---- OpenRouter (AI service) ----
OPENROUTER_API_KEY=sk-or-v1-REPLACE_WITH_A_FRESH_KEY
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
EOF
chmod 600 /root/Imagen/.env
```

`DATABASE_URL` and `AI_SERVICE_URL` are set by compose to the in-cluster
hostnames — you do **not** put them in `.env`.

### 4. First boot

```bash
cd /root/Imagen
docker compose up -d --build
docker compose ps
```

## GitHub Actions secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret           | Value                                             |
| ---------------- | ------------------------------------------------- |
| `SERVER_HOST`    | `187.52.120.117`                                  |
| `SERVER_USER`    | `root`                                            |
| `SERVER_PORT`    | `22`                                              |
| `DEPLOY_PATH`    | `/root/Imagen`                                    |
| `SERVER_SSH_KEY` | The **private** key whose public half is in the server's `~/.ssh/authorized_keys` |

Generate a dedicated deploy key (do this locally, not on the server):

```bash
ssh-keygen -t ed25519 -f show_deploy -C "github-actions" -N ""
# Add show_deploy.pub to the server:
ssh-copy-id -i show_deploy.pub root@187.52.120.117
# Paste the PRIVATE key file (show_deploy) as the SERVER_SSH_KEY secret.
```

## Security

- **Rotate the OpenRouter key** — the one shared in chat is considered exposed.
  Put only the fresh key in the server `.env`; it is never committed.
- `.env` is gitignored and lives only on the server.
- Prefer an SSH **key** over the root password for deploys; the workflow uses a key.
- Consider a non-root deploy user and a firewall that only exposes `:8080`
  (and `:22`).

## How a deploy runs

1. `git push` to `main`.
2. **CI** job: `go vet` + `go build`, install Python deps + import the AI app,
   validate `docker compose config`.
3. **Deploy** job (only on `main`): SSH in, `git reset --hard origin/main`,
   `docker compose up -d --build`, prune old images.

Watch progress under the repo's **Actions** tab.
