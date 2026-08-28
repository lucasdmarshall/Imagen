# SHOW Go API — multi-stage build.
# Stage 1: compile a static binary. Stage 2: minimal runtime image.

FROM golang:1.25-alpine AS build
WORKDIR /src

# Cache dependencies first.
COPY go.mod go.sum ./
RUN go mod download

# Build.
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# ---- Runtime ----
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -u 10001 app
WORKDIR /app
COPY --from=build /out/api /app/api
# Ship migrations alongside the binary (used once a Postgres store is wired in).
COPY migrations /app/migrations
USER app
EXPOSE 8080
# Alpine's busybox provides wget for the healthcheck.
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
ENTRYPOINT ["/app/api"]
