# Review: task 2b95f500 — Publish the Strategy Archive on quantmechanica.com

- Reviewer: Claude (review lane)
- Date: 2026-08-24
- Task: `2b95f500-e965-42d5-81af-6fdc135b9443` (ops_issue, codex, REVIEW)
- ToDo: `QM-TODO-20260823-511`
- Worker verdict: `BLOCKED_OWNER_PROJECTION_DECISION`
- Worker artifact: `docs/ops/evidence/2b95f500_strategy_archive_public_projection_blocker_2026-08-23.md`
- Review verdict: **BLOCKED (worker analysis correct; upstream OWNER decision required)**

## What the task asked

Publish a public Strategy Archive to quantmechanica.com: schema v2 for
`public-data/strategy-archive.json` carrying per-card gate coverage, a public
renderer over `archive_matrix.collect()`, wired into the guarded hourly
exporter + validator. The payload itself assigns the *projection decision* (how
much verdict detail is public: (a) coverage-only, (b) pass/fail per gate no
numbers, (c) full detail) to Claude/OWNER, and the exporter/validator
implementation to Codex.

## Worker deliverable

No public schema, snapshot, exporter, renderer, validator, scheduled task, or
website data was changed. The worker declined to pick a disclosure shape in
code because that choice discloses proprietary pipeline selectivity and the
shape of the book — a decision the task expressly reserves to Claude/OWNER — and
because no such decision exists in the durable control plane.

## Read-only verification (this review)

1. **No projection decision on record.** `grep` over `docs/`, `decisions/`,
   `cards_approved/` for the ToDo id, "projection decision", and the
   three-option wording found no decision record (only unrelated corpus-
   dependency lines in `2026-08-23_sp_d9_corpus_dependency_dry_run.md`).
   Confirms the worker's control-plane finding.
2. **Schema still v1.** `public-data/strategy-archive.schema.json` pins
   `schema_version` `"enum": [1]` (lines 8-11). No v2 exists; publishing gate
   data is a breaking public-API change requiring a new version + parallel
   window per `public-data/README.md`. Confirmed.
3. **No code changed.** `git status --porcelain public-data scripts dashboards
   tools/strategy_farm/archive_matrix.py` is empty. The refusal touched nothing.
4. **Publication guard — status changed since 08-23.** The worker cited an
   active `STALE_BUILD_RESULT_AUTO_Q02_BYPASS` hold
   (`publication_allowed=false`). Re-run today:
   `python tools/strategy_farm/public_snapshot_incident_guard.py --db
   D:/QM/strategy_farm/state/farm_state.sqlite` →
   `publication_allowed=true, active_incident_hold_count=0`. That secondary
   blocker has cleared. The **primary** blocker — no OWNER projection decision —
   remains and is dispositive.

## Assessment

The worker made the correct fail-closed call. Choosing a public disclosure
shape unilaterally would expose book selectivity — squarely an OWNER/ROT
decision (candidate-pool / book-shape disclosure), not a Codex implementation
detail. Nothing to fix by Codex; the block is real and upstream.

Recommendation carried to OWNER (Entscheidungsschlange): record one projection
choice + exact field allowlist + v1→v2 parallel-publication/cutover rule.
Claude-lane recommendation is option (a) coverage-only for the public site (no
verdicts, no numbers), (b) only if OWNER wants to demonstrate rigour. Once
OWNER records the choice, re-commission Codex for the exporter/validator with
adversarial fixtures for every forbidden class and both path separators.

## Verdict

**BLOCKED** — worker deliverable is a correct, evidence-backed refusal. Task
cannot proceed without an OWNER projection decision.
