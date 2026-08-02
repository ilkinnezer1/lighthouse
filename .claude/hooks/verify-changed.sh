#!/usr/bin/env bash
# Stop hook: verify only the repos that have uncommitted changes, and block the
# session from ending (exit 2) if any verify fails — so we never stop on a
# broken tree. Clean / unchanged repos are skipped, so a normal stop is fast.
# To disable: remove the Stop hook from .claude/settings.json.
set -u

root="${CLAUDE_PROJECT_DIR:-$HOME/Documents/GitHub/lighthouse}"
fail=0
report=""

check() {
  local repo="$1" cmd="$2" dir="$root/$1"
  [ -d "$dir" ] || return 0
  # skip repos with a clean tree; --porcelain also catches untracked new files
  # (a plain `git diff` would miss a brand-new, not-yet-added source file)
  if [ -z "$(git -C "$dir" status --porcelain)" ]; then
    return 0
  fi
  local out
  if out=$(cd "$dir" && eval "$cmd" 2>&1); then
    report+=$'\n'"  ✓ ${repo}: ${cmd}"
  else
    fail=1
    report+=$'\n'"  ✗ ${repo}: ${cmd} FAILED"$'\n'"${out}"
  fi
}

check lighthouse-worker "go build ./... && go vet ./internal/..."
check lighthouse-api "pnpm build"
check lighthouse-web "npx vue-tsc -b"

if [ "$fail" -ne 0 ]; then
  printf 'Stop blocked — verification failed on changed repo(s):%s\n' "$report" >&2
  exit 2
fi
exit 0
