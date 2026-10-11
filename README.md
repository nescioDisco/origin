# git-ai-sanitize

Development happens in private repos with Claude Code doing the heavy lifting — full AI attribution, session URLs, Co-Authored-By lines, all of it committed as-is. Those private repos are the source of truth and the failsafe backup. Before any branch goes public, this toolkit rewrites its history to strip the AI footprint — not out of shame, but because the workflows and agent configurations are proprietary and publishing them clean keeps that edge intact.

## Quick start

Sanitize a branch for public publishing:

```sh
./sanitize-branch.sh <branch-name>
```

This rewrites the branch in place using `git filter-branch` (or `git-filter-repo` if available). Push the result to your public remote.

Install the per-commit hook so every new commit on the current repo is sanitized at write time (optional — most users prefer the branch-level pass):

```sh
./install-hooks.sh
```

## What gets stripped

- `Co-Authored-By: Claude` lines and any `Co-Authored-By:` line referencing an Anthropic address
- `Claude-Session:` lines and `https://claude.ai/code/session_...` URLs
- `🤖 Generated with [Claude Code]` footers and similar AI-generated boilerplate
- Inline `claude.ai` session URLs anywhere in the commit message body

## Philosophy

Private repos carry the full, unredacted history — AI attribution, session links, everything — because that context is useful and the repos are not public. Public repos receive a clean projection of that history, stripped of attribution that would signal proprietary tooling. The two views of the same work are not in conflict; the private repo is the backup and the record, and the public repo is the release.
