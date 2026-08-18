# Lighthouse

Self-hostable, multi-user preview-environment platform — an open-source "Coolify-lite", or a
self-hosted Vercel for personal projects. Point it at a git repo, pick a branch, and it builds and
serves that branch at its own URL, with managed databases, persistent volumes and backups attached.

Runs the same way on a laptop (`MODE=local`, `*.localhost`) as on a VPS (`MODE=server`, real
domains + Let's Encrypt).

## Repo layout

This directory is the **orchestration root**: it holds shared infra and the design docs, and is the
parent of three independent git repos (not a monorepo — each has its own remote and its own `.env`).

| Path | Stack | Role | Verify with |
|---|---|---|---|
| `lighthouse-api/` | NestJS 11 + Prisma 7 | control plane — REST, auth, WebSockets, queues | `pnpm build` |
| `lighthouse-worker/` | Go 1.25 | data plane — Docker, git, builds, log streams | `go build ./... && go vet ./internal/...` |
| `lighthouse-web/` | Vue 3 + Vite | single-page UI | `pnpm typecheck` |
| `docker-compose.dev.yml`, `Makefile` | — | postgres · redis · minio · buildkit · traefik | `make up` |

## Running it

Prerequisites: Docker, Node 20+ with pnpm, Go 1.25+.

```bash
cp .env.example .env          # then fill MASTER_ENCRYPTION_KEY and JWT_SECRET
make up                       # infra containers
```

Each repo reads its **own** `.env`, so copy those too (`lighthouse-api/.env.example` is the fullest).
`MASTER_ENCRYPTION_KEY` must be byte-identical between the API and the worker — both encrypt with
AES-256-GCM against the same key, and each has to read what the other wrote.

Then, in three terminals:

```bash
cd lighthouse-worker && go run ./cmd/worker    # :8081
cd lighthouse-api    && pnpm start:dev         # :3000
cd lighthouse-web    && pnpm dev               # :5173, proxies /api to the API
```

Useful `make` targets: `up` · `down` · `restart` · `logs` · `ps` · `psql` · `redis-cli` · `reset`
(drops volumes) · `clean`. Traefik may fail to bind `:80` if something else holds it — harmless for
local development.

## Architecture boundaries

These hold across all three repos:

- **The browser only ever talks to the API.** The worker has no public surface.
- **Only the worker touches `/var/run/docker.sock`.** The API never does.
- **The API owns the Prisma schema and its migrations.** Go reads the same database through sqlc +
  pgx, from a `schema.sql` that must be re-synced whenever a migration lands.
- **API ↔ worker is Redis** — `jobs:*` streams, `deploy:{id}:logs`, `cancel:*` pubsub and an event
  outbox — plus a few internal HTTP endpoints the API proxies through (runtime logs, exec,
  maintenance runs) at `WORKER_HTTP_URL`.

## What works today

Deployments from GitHub (public and private) with a build strategy per project — Dockerfile,
compose, generated Dockerfile, nixpacks, buildpacks, railpack or a prebuilt image — plus branch
selection and merge builds, redeploy and rollback.

Around that: managed databases (Postgres, MySQL, Mongo, Redis) with snapshots, restores and
scheduled backups with retention · persistent volumes with their own backups and baselines ·
one-click templates · custom domains · environment variables and secrets · file management ·
scheduled tasks · deploy notifications (Slack, Discord, webhook) · organizations with role-based
access and invitations · an audit log · live build and runtime log streaming · and an in-browser
terminal into any running container.

## Design docs

Written before the build and still the reference for intent, in reading order:

1. [`docs/01-vision.md`](./docs/01-vision.md) — goals, non-goals, local vs server modes
2. [`docs/02-architecture.md`](./docs/02-architecture.md) — the API/worker split and how they talk
3. [`docs/03-data-model.md`](./docs/03-data-model.md) — schema, per-user model, subdomains
4. [`docs/04-pipeline.md`](./docs/04-pipeline.md) — build pipeline stages
5. [`docs/05-roadmap.md`](./docs/05-roadmap.md) — the phased plan
6. [`docs/06-pending-decisions.md`](./docs/06-pending-decisions.md) — open questions

They predate the implementation and have drifted in places — most visibly, the web app is Vue 3,
not the Next.js the early docs assumed. Where a doc and the code disagree, the code is right.
