# DL-026 - Coding-Agent Done Criteria Requires Commit Hash in Close-Out

Date: 2026-04-27  
Issue: QUA-239  
Owner: CTO

## Decision

Tighten coding-agent BASIS prompts so any code or repo-tracked artifact deliverable can be marked done only when:

1. The change is committed to Git.
2. The issue close-out comment includes the commit hash.

`done` without commit-hash evidence in the close-out comment is invalid for coding deliverables.

## Why

- Addresses the repeated "done-before-commit" drift captured in `lessons-learned/2026-04-27_codex_done_before_commit.md`.
- Enforces the Hard Rule "No fantasy numbers" by requiring verifiable commit evidence in-thread.
- Prevents false completion states where files exist locally but are not recoverable from `git log`.

## Scope

Patched BASIS prompts:

- `paperclip-prompts/cto.md`
- `paperclip-prompts/development.md`
- `paperclip-prompts/devops.md`
- `paperclip-prompts/pipeline-operator.md`
- `paperclip-prompts/r-and-d.md`

## Non-Goals

- No edits to live Paperclip `instructions/AGENTS.md` runtime files in this change.
- No process hook implementation (pre-`done` validation hook remains future/optional).

## Activation Note

This is an OWNER-gated prompt patch at the BASIS layer. Runtime effect depends on prompt propagation path selected by OWNER/Paperclip operations (hot-reload, config patch, or re-hire path per DL-014 two-layer model).
