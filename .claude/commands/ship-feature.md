---
description: Plan and implement a feature across the Lighthouse repos via the expert agents
argument-hint: [feature description]
---

Ship this feature across the Lighthouse repos: **$ARGUMENTS**

Work the seams first, then delegate. Do not start editing until the contract is decided.

1. **Design the contract end-to-end.** Decide the wire shape across all three
   layers before any code: what the web calls, what the API exposes and proxies,
   what the worker does. Reuse existing idioms rather than inventing:
   - one-shot / streaming command → worker HTTP endpoint Nest proxies (model:
     maintenance `run`, runtime-logs); async work → Redis `jobs:*` queue.
   - browser-facing state-change → API endpoint with `ensureCan` + `@Audit`.
   - live UI updates → vue-query + a `fetch`/`ReadableStream` composable, or the
     shared socket for WS.
   Write the contract down (routes, payloads, the exit/stream framing) so all
   three agents share it.

2. **Delegate in dependency order**, each to its specialist, each editing only
   its own repo and verifying before returning:
   - **`worker-expert`** — data-plane behavior (`go build ./... && go vet`).
   - **`api-expert`** — endpoint/proxy + authz/audit/config (`pnpm build`).
   - **`web-expert`** — client + UI, with `src/types/api.ts` mirroring the API
     response exactly (`npx vue-tsc -b`).

3. **Keep the contract consistent.** If an agent changes a payload shape, propagate
   it to the other layers — types on the web must match what the API returns.

4. **Live-verify** with `/verify-stack` once all three compile.

5. **Summarize** per-repo changes and provide a conventional `feat:` commit message
   per repo. Don't commit unless asked — backend (API/worker) commits are the
   user's call; web rides its feature branch.
