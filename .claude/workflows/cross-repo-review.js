export const meta = {
  name: 'cross-repo-review',
  description:
    'Review changes across the three Lighthouse repos via the expert agents, then adversarially verify each finding before reporting',
  phases: [{ title: 'Review' }, { title: 'Verify' }],
}

// Each repo is reviewed by its own specialist so findings are judged against
// that repo's real conventions, not generic rules. Run this from the parent
// dir (where the *-expert agents are registered).
const REPOS = [
  { key: 'worker', path: 'lighthouse-worker', agentType: 'worker-expert' },
  { key: 'api', path: 'lighthouse-api', agentType: 'api-expert' },
  { key: 'web', path: 'lighthouse-web', agentType: 'web-expert' },
]

const ROOT = '~/Documents/GitHub/lighthouse'

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          severity: { type: 'string', enum: ['bug', 'convention', 'nit'] },
          title: { type: 'string' },
          detail: { type: 'string' },
        },
        required: ['file', 'severity', 'title', 'detail'],
      },
    },
  },
  required: ['findings'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    isReal: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: ['isReal', 'reason'],
}

// Default target is the uncommitted working tree; pass args.target to scope it
// (e.g. a branch range "main..HEAD" or a specific feature).
const target = (args && args.target) || 'the uncommitted working-tree changes'

const results = await pipeline(
  REPOS,
  (repo) =>
    agent(
      `Review ${target} in the ${repo.path} repo. See them with ` +
        `\`git -C ${ROOT}/${repo.path} diff\` (add --cached / a range as needed). ` +
        `Flag only real correctness bugs and concrete violations of this repo's ` +
        `conventions — no speculation. Return findings (empty array if clean).`,
      { agentType: repo.agentType, label: `review:${repo.key}`, phase: 'Review', schema: FINDINGS_SCHEMA },
    ).then((r) => ({ repo, findings: (r && r.findings) || [] })),
  ({ repo, findings }) =>
    parallel(
      findings.map((f) => () =>
        agent(
          `Adversarially verify this ${repo.key} finding — try to REFUTE it by ` +
            `reading the actual code at ${ROOT}/${repo.path}. Default isReal=false ` +
            `if uncertain.\n\nFile: ${f.file}${f.line ? ':' + f.line : ''}\n` +
            `Severity: ${f.severity}\nTitle: ${f.title}\nDetail: ${f.detail}`,
          { agentType: repo.agentType, label: `verify:${repo.key}:${f.file}`, phase: 'Verify', schema: VERDICT_SCHEMA },
        ).then((v) => ({ ...f, repo: repo.key, verdict: v })),
      ),
    ),
)

const confirmed = results
  .flat()
  .filter(Boolean)
  .filter((f) => f.verdict && f.verdict.isReal)

log(`${confirmed.length} confirmed finding(s) across ${REPOS.length} repos`)
return { confirmed }
