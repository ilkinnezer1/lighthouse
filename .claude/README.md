# Lighthouse — Claude Code Agentic Workflow

A hands-on, professional setup for working on the Lighthouse multi-repo with Claude Code.
Built step by step as a **learning project**: each step adds one agentic primitive and
explains the transferable lesson. The anchor task is real work we already do by hand —
ship a feature across **web + API + worker**, then verify it live.

## Repo layout (why this lives in the parent)

```
lighthouse/                 ← git repo + Claude Code root (launch from HERE for cross-repo work)
├── lighthouse-api/         ← NestJS + Prisma  (control plane)
├── lighthouse-web/         ← Vue 3 + Vite SPA (UI)
├── lighthouse-worker/      ← Go (Docker/data plane)
├── docker-compose.dev.yml  ← infra: postgres / redis / minio / traefik
├── Makefile                ← `make up` brings infra up
└── .claude/                ← this agentic workflow
```

Launch Claude Code from the parent so a single session can read and edit all three
sub-repos at once. The sub-repos keep their own `.claude/settings.local.json` (permissions).

## The agentic primitives (what each is for)

| Primitive | Where it lives | Use it for |
|---|---|---|
| **Project memory** | `CLAUDE.md` per repo | Stable facts/conventions Claude should always know |
| **Subagents** | `.claude/agents/*.md` | Specialists with their own context, run in parallel (api/worker/web experts) |
| **Slash commands** | `.claude/commands/*.md` | Reusable, parameterized prompts for repeated tasks |
| **Hooks** | `.claude/settings.json` | Deterministic automation on events (e.g. typecheck on stop) |
| **Workflows** | `.claude/workflows/*.js` | Multi-agent orchestration: fan-out, pipeline, adversarial verify |
| **MCP tools** | session config | External capability (we already drive Chrome for live tests) |

## Build roadmap

- [x] **Step 1 — Foundation.** This index + `.claude/` scaffold. Decide cross-repo run model.
- [x] **Step 2 — Project memory.** Parent `CLAUDE.md` grounds the orchestrating session:
      repo map + verify matrix, the cross-repo architecture boundaries, the run-the-stack
      procedure, and the "delegate to the specialist" rule. *(Optional follow-up: a lean
      `CLAUDE.md` per repo for when one is opened standalone.)*
      *Lesson: context engineering — ground the session once, keep depth in agents/vault.*
- [x] **Step 3 — Subagents.** `worker-expert` (Go + DevOps), `api-expert` (NestJS backend),
      `web-expert` (Vue 3 frontend) in `.claude/agents/`. Each is scoped to one repo and
      carries that repo's locked stack, hard rules, conventions, and verification command,
      so "do X on the worker" yields idiomatic work, and a cross-repo task fans out to all
      three. *Lesson: decomposition + isolated context windows + grounding agents in real
      conventions, not generic advice.*
- [x] **Step 4 — Slash commands.** `/verify-stack` (infra up → worker/API/web → browser
      smoke test, exactly what we did for maintenance actions) and `/ship-feature`
      (design the contract → delegate to the three experts in dependency order → verify).
      In `.claude/commands/`. *Lesson: encoding a repeatable procedure so it runs the
      same way every time.*
- [x] **Step 5 — Multi-agent Workflow.** `.claude/workflows/cross-repo-review.js`: reviews a
      change in all three repos in parallel (each via its expert), then adversarially verifies
      every finding (refute-by-default) before reporting only the confirmed ones. Run from the
      parent. *Lesson: deterministic orchestration + verification beats one-shot.*
- [x] **Step 6 — Hooks.** `.claude/settings.json` registers a `Stop` hook
      (`.claude/hooks/verify-changed.sh`) that verifies only the repos with uncommitted
      changes (`go build`/`go vet`, `pnpm build`, `vue-tsc -b`) and blocks the session from
      ending on a broken tree. Disable by removing the hook. *Lesson: deterministic guardrails
      around a probabilistic agent.*
- [x] **Step 7 (stretch) — Agentic feature in the product.** Design spec for a "Deploy Doctor"
      in `.claude/deploy-doctor.md` — diagnoses a deployment from its logs/state and proposes a
      (human-confirmed) maintenance action, built on the Claude Agent SDK. **Spec only**, not
      implemented; needs an API key + model/cost decisions. *Lesson: productionizing agents.*

## Conventions for artifacts here

- Keep each agent/command single-purpose and name it by its job.
- Commands and agents state which repo(s) they touch and which checks prove success
  (`vue-tsc -b`, `nest build`, `go build ./... && go vet ./...`).
- Live verification uses the running stack + the Chrome MCP tools, never mocks.

## Status

**All steps built.** Parent `CLAUDE.md`; three `*-expert` agents; `/verify-stack`
+ `/ship-feature` commands; the `cross-repo-review` Workflow; the `Stop`
verification hook; and the Deploy Doctor spec (Step 7, design only).

Not yet exercised: the agents/commands/workflow need a **parent-rooted** Claude
Code session to load (this was authored from `lighthouse-web`). The Deploy Doctor
is a spec, not code.

### How the agents route
Launch Claude Code from this parent dir. The main session reads `.claude/agents/`
and delegates by each agent's `description`: ask "add a handler on the worker" →
`worker-expert`; "new API endpoint" → `api-expert`; "fix the deployment view" →
`web-expert`. You can also name one explicitly. A cross-repo task (like the
maintenance-actions feature) fans out to all three, each working only in its repo.
