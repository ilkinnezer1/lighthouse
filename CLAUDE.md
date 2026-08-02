# Lighthouse — multi-repo orchestration root

This directory is the **parent** of the three Lighthouse repos. Launch Claude Code
**from here** so one session can read and edit all three, and so the specialist
agents in `.claude/agents/` load. The full agentic-workflow plan is in
`.claude/README.md`.

## Repo map

| Path | Repo | Role | Verify |
|---|---|---|---|
| `lighthouse-api/` | NestJS + Prisma | control plane (API, auth, WS, queues) | `pnpm build` |
| `lighthouse-worker/` | Go | data plane (Docker, git, builds, log streams) | `go build ./... && go vet ./internal/...` |
| `lighthouse-web/` | Vue 3 + Vite | SPA UI | `npx vue-tsc -b` |
| `docker-compose.dev.yml` + `Makefile` | infra | postgres / redis / minio / traefik | `make up` |

## Golden rule — delegate to the specialist

Each repo has an expert agent that owns its stack and conventions. Route work to it:
- worker / Go / Docker / build pipeline / sqlc → **`worker-expert`**
- API / NestJS / Prisma / endpoint / gateway / authz → **`api-expert`**
- web / Vue / UI / vue-query / streaming view → **`web-expert`**

A cross-repo feature fans out to all three; each edits only its own repo and
states the contract at the seams. Don't re-derive a repo's conventions inline —
the agent files (and `~/vault/Projects/lighthouse/`) are the source of truth.

## Architecture boundaries (span all repos — never violate)

- The **browser only ever talks to Nest.** The worker is invisible to it.
- Only the **worker** touches `/var/run/docker.sock`. Nest never does.
- **Nest owns Prisma migrations**; Go reads the same schema via sqlc + pgx.
- Nest ↔ worker = Redis (`jobs:*` streams, `deploy:{id}:logs`, `cancel:*` pubsub,
  `event_outbox`), plus a few internal HTTP proxies Nest streams through
  (runtime-logs, exec, maintenance `run`) at `WORKER_HTTP_URL`.
- Crypto is AES-256-GCM with a shared `MASTER_ENCRYPTION_KEY` — the Go and Nest
  implementations must stay byte-compatible.

## Running the stack

```
make up                                   # infra (traefik may fail to bind :80 if taken — harmless here)
cd lighthouse-worker && go run ./cmd/worker   # :8081
cd lighthouse-api    && pnpm start:dev        # :3000
cd lighthouse-web    && pnpm dev              # :5173  (logged-in user: test@test.com)
```

DB inspect: `docker exec lighthouse-postgres psql -U lighthouse -d lighthouse_dev`.
Use `/verify-stack` to do all of this plus a browser live-test.

## Cross-cutting conventions

- **No code comments by default** — well-named identifiers cover WHAT; keep only a
  short WHY-line for a non-obvious invariant.
- **Locked stack** — don't propose alternatives to chosen tech; surface a tradeoff
  and ask if a deviation seems warranted.
- **Lightweight container images** — alpine/distroless; never ship the full
  `golang`/`node` image to runtime.
- Commits are **per repo**, conventional `feat:`/`fix:` style. Web rides feature
  branches; API/worker land on `main` and the **user drives backend commits**.

## Deeper context

Curated project notes (status, phases, decisions, history):
`~/vault/Projects/lighthouse/index.md`.
