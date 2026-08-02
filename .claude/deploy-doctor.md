# Step 7 (stretch) — Deploy Doctor: an agentic feature in the product

**Status: design spec, not implemented.** This graduates from *using* agents
(the `.claude/` workflow) to *building* one into Lighthouse. It needs product
decisions (model, cost, API key) and is LLM-shaped, so before implementing,
ground in the current Claude API / Agent SDK reference (model IDs, tool use,
streaming, prompt caching) and confirm the model/cost choices.

## Goal

A one-click **"Diagnose"** on a deployment that explains *why* it failed or is
unhealthy and proposes a fix — reusing the signals and capabilities we already
built (build-log stages, runtime logs, service state, maintenance actions, exec).

## Where it lives

Server-side in **lighthouse-api** (new `deploy-doctor` module). The
`ANTHROPIC_API_KEY` never reaches the browser — the same trust boundary as
maintenance commands. The worker is unchanged; the doctor reaches container
reality through the existing API→worker proxies.

## Shape

1. **Endpoint:** `POST /deployments/:id/diagnose` — `ensureCan(user, 'deployments.exec', …)`,
   streams the analysis to the web with the same `fetch`/`ReadableStream` idiom
   as runtime-logs and maintenance actions.
2. **Context the API assembles** (no secrets — mask env values): deployment +
   stage errors, last N build-log lines, a runtime-logs tail per service,
   service/container state, and the project's `maintenanceActions` catalog.
3. **Tool-use loop (server-side)** — give Claude read-only tools that map to
   existing capabilities: `read_runtime_logs(service, lines)`,
   `read_build_log(stage)`, `list_maintenance_actions`, `inspect_service(name)`.
   The model gathers evidence, then returns a diagnosis + an optional
   *suggested* maintenance action by id.
4. **Human stays in the loop:** the doctor never executes a state change. A
   suggestion renders as "Doctor suggests: **Run migrations**" and routes through
   the **existing** maintenance confirm dialog + `POST …/actions/:actionId`.

## Web

A "Diagnose" button on `DeploymentDetailView` (near Maintenance) opens a pane
that streams the doctor's reasoning, then shows the suggested action as a
pre-filled, still-confirm-gated maintenance button.

## Model & safety

- Default to a capable Claude model via env (e.g. Opus `claude-opus-4-8` for hard
  diagnosis, Sonnet `claude-sonnet-4-6` to cut cost); cache the system prompt +
  static project context.
- Read-only by default; every state change is human-confirmed via the existing
  gate. Mask env-var values before they enter a prompt.

## Build order (when greenlit)

contract/tools → **api-expert** (module + `/diagnose` + tool loop) →
**web-expert** (Diagnose pane, reuse the streaming + confirm components) →
`/verify-stack`. No worker change.
