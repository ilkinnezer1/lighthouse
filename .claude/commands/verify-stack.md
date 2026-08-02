---
description: Bring up the full Lighthouse stack and live-verify a change in the browser
argument-hint: [what to verify, e.g. "maintenance actions on a deployment"]
---

Bring up the full local stack and live-verify: **$ARGUMENTS**

Follow this procedure; report each step's result.

1. **Infra** — from the parent: `make up`. It starts postgres/redis/minio. Traefik
   may fail to bind `:80` if another container holds it — that's harmless here
   (we don't route public traffic for this test). Confirm postgres/redis/minio are
   `healthy` (`docker ps | grep lighthouse`).

2. **App processes** — start each in the background, logging to `/tmp/`:
   - worker: `cd lighthouse-worker && go run ./cmd/worker` → `/tmp/lh-worker.log` (`:8081`)
   - api: `cd lighthouse-api && pnpm start:dev` → `/tmp/lh-api.log` (`:3000`)
   - web: `cd lighthouse-web && pnpm dev` → `/tmp/lh-web.log` (`:5173`)

3. **Readiness** — tail the logs until: worker `Http listening addr=:8081`, api
   `Nest application successfully started`, web `VITE ... ready`.

4. **Pick a target** (if the change is deployment-scoped) — query the DB for a
   live deployment:
   `docker exec lighthouse-postgres psql -U lighthouse -d lighthouse_dev -c "select d.id,d.status,p.name,s.name svc,left(s.container_id,12) cid from deployments d join environments e on e.id=d.environment_id join projects p on p.id=e.project_id left join services s on s.deployment_id=d.id where d.status in ('RUNNING','SUCCEEDED') and s.container_id is not null order by d.created_at desc;"`

5. **Drive the browser** — use the Chrome MCP tools. Navigate to
   `http://localhost:5173` (session is usually already logged in as
   `test@test.com`), go to the relevant view, and exercise the change. Capture
   screenshots; check `read_network_requests` for the expected calls/status and
   `read_console_messages` for errors.

6. **Report** pass/fail with evidence (screenshot + the network status codes).
   **Do not trigger destructive/irreversible actions** (delete, run migrations,
   teardown) without asking first — verify the confirm gate instead.

7. Leave the stack running unless asked to tear it down (`make down`).
