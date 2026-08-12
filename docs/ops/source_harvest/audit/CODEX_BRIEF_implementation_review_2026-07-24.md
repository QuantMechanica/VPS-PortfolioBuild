# CODEX IMPLEMENTATION REVIEW BRIEF — 2026-07-24 audit implementation run

You are Codex, reviewing Claude's implementation of the audit package (OWNER: "alles
umsetzen"). Builder ≠ approver: none of this code is yours; review adversarially.

## Diff under review (canonical checkout C:\QM\repo, branch agents/board-advisor)

Commit range `565dea87b..HEAD` — audit-implementation commits only (skip pump
`build:`/`ops: record` churn commits by other automation). Focus files:

1. `tools/strategy_farm/farmctl.py` — **highest stakes**: (a) ARTIFACT_COMMIT_ALLOWLIST
   + event_vocabulary.json; (b) `_summary_matches_expected_evidence` None-date fix
   (commit `bd9c3e049`) — verify the relaxation cannot cross-bind summaries between
   different windowed runs and that full-history binding still enforces
   symbol/period/expert/hash identity. Run
   `python -m pytest tools/strategy_farm/tests/test_q02_evidence_binding.py -q`.
2. `tools/strategy_farm/health.py` — pump orphan-lock check (`_pid_alive_no_signal` —
   confirm it can NEVER kill/affect the probed process) + `work_items_timestamp_sanity`.
3. `tools/strategy_farm/live_book_pulse.py` — NUMBERED_PRESET_FILE_RE parser + new
   default manifest. Verify magic reconstruction (ea_id*10000 + qm_magic_slot_offset)
   against ≥3 deployed presets (READ-ONLY) and that legacy naming still parses.
4. `tools/strategy_farm/live_book_dd_guard.py` (new) — logic review: HWM handling,
   stale-pulse fail-safe, latch semantics, signal paths vs `QM_KillSwitch.mqh:486-496`
   poll paths, and that a guard crash cannot write a spurious signal. Check the
   scheduled task exists (QM_StrategyFarm_LiveBookDDGuard) — read-only.
5. `scripts/build_pipeline_state.py` — DB-derivation rewrite: verify 3 fresh spot
   checks of your choosing against work_items (mode=ro) and that
   `scripts/export_public_snapshot.ps1 -DryRun` still passes schema.
6. Registry edits: 13213 backfill row, 10940 retired flips, 10145 sets news-axes
   addition (spot-check 2 sets parse as valid UTF-16 .set with qm_news_temporal=3,
   qm_news_compliance=1), branding orphan deletion + sync_brand_tokens single output.
7. DB repairs (evidence `docs/ops/source_harvest/audit/evidence/dbrepair__*.json`):
   sanity-check current DB state matches the after-image (READ-ONLY).

## Constraints

READ-ONLY everywhere except `D:\QM\reports\audit\codex_compliance_2026-07-24\`
(your output). You may RUN: pytest on strategy_farm tests, `python -m py_compile`,
read-only farmctl/agent_router subcommands, the export dry-run. You may NOT: git
commit/checkout, edit repo files, touch T_Live/terminals/tasks/flags/config, run
builds, modify the DB (mode=ro only), start MT5.

## Output

`D:\QM\reports\audit\codex_compliance_2026-07-24\IMPLEMENTATION_REVIEW_CODEX.md`:
numbered findings, each CONFIRM / DEFECT (severity P1/P2/P3 + evidence + minimal fix)
/ NIT. Final line: `IMPL_REVIEW: CLEAN` or `IMPL_REVIEW: DEFECTS (<n>)`.
Then: `python C:\QM\repo\tools\strategy_farm\agent_router.py update-task <task_id> --state REVIEW --artifact-path "D:\QM\reports\audit\codex_compliance_2026-07-24\IMPLEMENTATION_REVIEW_CODEX.md" --verdict "<final line>"`
(find your task id via `list-tasks --agent codex --state IN_PROGRESS`). Then exit.
