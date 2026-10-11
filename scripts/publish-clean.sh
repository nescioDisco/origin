#!/usr/bin/env bash
# publish-clean.sh — create a sanitized copy of a branch with AI attribution stripped
# Usage: ./scripts/publish-clean.sh <source-branch> [target-branch]
set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────
die()  { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# ── args ─────────────────────────────────────────────────────────────────────
[[ $# -ge 1 ]] || die "usage: $0 <source-branch> [target-branch]"
SOURCE="$1"
TARGET="${2:-public/$SOURCE}"

# ── pre-flight ────────────────────────────────────────────────────────────────
git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"

git rev-parse --verify "refs/heads/$SOURCE" >/dev/null 2>&1 \
  || die "source branch '$SOURCE' does not exist"

git rev-parse --verify "refs/heads/$TARGET" >/dev/null 2>&1 \
  && die "target branch '$TARGET' already exists — delete it first or choose a different name"

# detect base (main or master)
if git rev-parse --verify refs/heads/main >/dev/null 2>&1; then
  BASE="main"
elif git rev-parse --verify refs/heads/master >/dev/null 2>&1; then
  BASE="master"
else
  die "cannot find a 'main' or 'master' branch to use as the comparison base"
fi

COMMIT_COUNT=$(git rev-list --count "refs/heads/$BASE..refs/heads/$SOURCE")
info "source branch : $SOURCE ($COMMIT_COUNT commits ahead of $BASE)"
info "target branch : $TARGET"
info "commits to rewrite: $COMMIT_COUNT"
echo

# ── confirm ───────────────────────────────────────────────────────────────────
read -r -p "Continue? [y/N] " REPLY
[[ "${REPLY,,}" == "y" ]] || { echo "Aborted."; exit 0; }

# ── choose rewrite tool ───────────────────────────────────────────────────────
USE_FILTER_REPO=false
if command -v git-filter-repo >/dev/null 2>&1; then
  USE_FILTER_REPO=true
else
  echo
  echo "WARNING: git-filter-repo not found; falling back to git filter-branch."
  echo "         git filter-branch is slower, deprecated in newer Git versions,"
  echo "         and may be disabled by GIT_ALLOW_UNSAFE_LEGACY_REWRITE=1."
  echo "         Install git-filter-repo for best results:"
  echo "           pip install git-filter-repo  OR  brew install git-filter-repo"
  echo
fi

# ── sed expression that strips AI attribution lines ──────────────────────────
# We build a single multi-expression sed command used in both paths.
SED_SCRIPT='
  /^Co-Authored-By:.*[Cc]laude/d
  /^Claude-Session:.*/d
  /^🤖 Generated with/d
  /claude\.ai\/code\/session_/d
'

# ── create target branch from source (source is never touched) ───────────────
info "Creating '$TARGET' from '$SOURCE' ..."
git branch "$TARGET" "$SOURCE"

# ── rewrite commit messages on the target branch ─────────────────────────────
if $USE_FILTER_REPO; then
  info "Rewriting with git-filter-repo ..."

  # filter-repo needs a callback script; write it to a temp file
  TMPDIR_CALLBACK=$(mktemp -d)
  CALLBACK="$TMPDIR_CALLBACK/msg_filter.py"
  trap 'rm -rf "$TMPDIR_CALLBACK"' EXIT

  cat > "$CALLBACK" <<'PYEOF'
import re

def commit_message_filter(commit):
    lines = commit.message.decode("utf-8", errors="replace").splitlines()
    cleaned = []
    for line in lines:
        if re.search(r'^Co-Authored-By:.*[Cc]laude', line):
            continue
        if re.search(r'^Claude-Session:', line):
            continue
        if re.search(r'^🤖 Generated with', line):
            continue
        if re.search(r'claude\.ai/code/session_', line):
            continue
        cleaned.append(line)
    # collapse multiple trailing blank lines into at most one
    msg = "\n".join(cleaned).rstrip() + "\n"
    commit.message = msg.encode("utf-8")
PYEOF

  # filter-repo operates on HEAD of the checked-out branch;
  # we must be on the target branch (not source) and we need --force
  # because this is not a fresh clone.
  CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
  git checkout "$TARGET"
  git filter-repo \
    --commit-callback "$(cat "$CALLBACK")" \
    --refs "$TARGET" \
    --force
  # restore previous branch if we switched away
  if [[ -n "$CURRENT_BRANCH" && "$CURRENT_BRANCH" != "$TARGET" ]]; then
    git checkout "$CURRENT_BRANCH"
  fi

else
  info "Rewriting with git filter-branch ..."
  export GIT_ALLOW_UNSAFE_LEGACY_REWRITE=1
  export FILTER_BRANCH_SQUELCH_WARNING=1

  git filter-branch --msg-filter '
    sed \
      -e "/^Co-Authored-By:.*[Cc]laude/d" \
      -e "/^Claude-Session:.*/d" \
      -e "/^🤖 Generated with/d" \
      -e "/claude\.ai\/code\/session_/d"
  ' -- "$TARGET"
fi

# ── done ─────────────────────────────────────────────────────────────────────
echo
info "Clean branch '$TARGET' ready."
echo "Review with:"
echo "  git log $TARGET --format='%s%n%b'"
echo
echo "To push publicly:"
echo "  git push <remote> $TARGET:main  # or whatever the public branch name is"
