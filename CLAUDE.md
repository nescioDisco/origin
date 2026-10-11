# CLAUDE.md — nescioDisco/origin (AI Sanitization Toolkit)

## What this repo is

Private backup-first workflow: ALL work (including AI-generated) is committed to
private repos with full attribution. Before any public push, run
`scripts/publish-clean.sh` to strip AI attribution from commits and PRs.
This repo holds those stripping tools. The stripping happens at publish time,
not at commit time.

## Commit behavior in this repo

**DO include** full attribution in every commit you make here:
- `Co-Authored-By: Claude <model> <noreply@anthropic.com>`
- `Claude-Session: https://claude.ai/code/session_...`
- The `🤖 Generated with Claude Code` PR footer

These are private backup commits. Attribution is intentional and wanted.

**Never** auto-strip or omit attribution on commits to this repo — the scripts
in this repo do that for the user at publish time, not for us at commit time.

## Files in this repo

- `scripts/publish-clean.sh` — strips AI attribution from commits before a public push
- `hooks/commit-msg` — git hook that enforces/sanitizes messages at commit time
- `scripts/install-hooks.sh` — installs the hooks into any target project's `.git/hooks/`

## When adding new scripts

- Follow the existing bash patterns (set -euo pipefail, POSIX-compatible)
- Add a `--help` flag with usage text
- Make the file executable (`chmod +x`)
- Add a one-line entry to the Files list above
