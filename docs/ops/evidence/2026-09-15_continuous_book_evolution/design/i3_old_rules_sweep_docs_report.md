# Slice report — i3_old_rules_sweep_docs

**Slice key:** `i3_old_rules_sweep_docs` · **Author:** Claude (board-advisor worktree) ·
**Date:** 2026-09-15 · **Authority:** OWNER-DEC-CBE-20260915, follow-up directive §10 + §11
(`owner_followup_directive_completeness_verbatim.md`).
**Branch:** `agents/board-advisor` (worktree). **Base HEAD:** `8a3ba58fea`.

## What this slice did

Two things: (§11) an exhaustive sweep of the repo AND the vault for surviving obsolete
rule/objective assumptions, classified per occurrence, with safe fixes for the residual
ACTIVE_BUT_OBSOLETE survivors the earlier slices (b1/b2/b3/b4/d2) missed, plus a regression
guard; and (§10) a company-documentation completeness matrix over the six §10 lists, creating
the missing pages and de-drifting the scheduled-automation surface.

## Files changed (repo — in the patch)

Modified:
- `tools/strategy_farm/render_cockpit_v2.py` — dead `_render_path_to_25` heading "Weg zu 25" /
  "/25" / "ETA zu 25" → diagnostic "Qualifizierungs-Pool (Diagnostik)" / "Ref-Pool 25 (hist.)"
  + supersession comment. Function stays retained-for-history (not in `body`); no objective
  wording remains. No behaviour change (function is not rendered).
- `tools/strategy_farm/prompts/autonomous_loop.md` — HR16 hard-boundary bullet "exactly ONE
  active source … cannot violate" → Controlled Parallelism (OWNER-DEC-CBE-20260915 §24), keeping
  anti-spam pacers + determinism-first. (This prompt is consumed by `autonomous_wake.ps1` /
  `scheduled_task_autonomous_wake.xml`.)

New:
- `tools/strategy_farm/render_scheduled_automation.py` — deterministic generator for the vault
  "Scheduled Automation" page from live `Get-ScheduledTask QM_*` (pure `render_markdown` +
  `fetch_tasks` IO boundary; only `generated_at_utc` is wall-clock, isolated to one field).
- `tools/strategy_farm/tests/test_no_obsolete_rule_wording.py` — §11 regression guard.
- `tools/strategy_farm/tests/test_render_scheduled_automation.py` — generator render tests.
- `docs/ops/DOCUMENTATION_COMPLETENESS_MATRIX_2026-09-15.md` — §10 matrix (33 items).
- `docs/ops/evidence/2026-09-15_continuous_book_evolution/OLD_RULES_SWEEP_2026-09-15.md` (+ `.csv`)
  — §11 sweep.
- `docs/ops/evidence/2026-09-15_continuous_book_evolution/DOCUMENTATION_DRIFT_REPORT_2026-09-15.md`
  — §69 drift report + vault-lint before/after.

## Vault artifacts written (in place on G:, NOT in the patch — like b4)

Created (hand-written, sourced from repo, repo paths cited):
- `06 Infrastructure/Backups.md`
- `06 Infrastructure/Live Controls.md`
- `08 Current State/Book Evolution/_index.md` (fixes the H1 dangling wikilink)

Created (generated, `generated: true` frontmatter + DO-NOT-EDIT banner):
- `06 Infrastructure/Scheduled Automation.md` (86 tasks; via `render_scheduled_automation.py`)

Edited in place (targeted wording fixes / dated annexes, history preserved):
- `03 Pipeline/Pipeline Operations Workflow.md` (ASCII book-trigger ≥25 → valid pool + note)
- `03 Pipeline/Q17 Live Burn-In DXZ.md` (4 residual 14-day/min-lot lines → evidence-based §10)
- `01 Identity/Business Model.md` (internal 60d≥0.80 hard target → §15 evidence annex)
- `06 Infrastructure/Mission Control.md` (Phase-D-landed annex)
- `06 Infrastructure/Background Automation and Scheduled Tasks.md` (task-count drift annex)

## Contracts changed

**None.** No gate threshold, verdict semantic, qualification predicate, JSON config token, or
Python function signature was changed. The one JSON edit attempted
(`gate_manifest.v4.draft.json` book-trigger wording) was **reverted** because its bytes are
sha256-pinned by `test_gate_manifest`; it stays as the frozen historical proposal.

## Tests + result

`python -X utf8 -m pytest tools/strategy_farm/tests/test_no_obsolete_rule_wording.py
test_render_scheduled_automation.py test_gate_manifest.py test_mission_control_v2_data.py
test_operator_surfaces_rebaseline.py test_path25_red_team.py -q`
→ **64 passed, 2 skipped, 5 warnings** (warnings pre-existing, unrelated DeprecationWarnings).

New contracts covered: obsolete-objective-wording guard (6 cases across 5 surfaces);
scheduled-automation render (determinism, timestamp isolation, counts, AI-spend callout,
purpose fallback, cell escaping — 6 cases).

## Vault lint before/after (recorded)

Before: FAIL, 11 (9 gate-token FP + 1 broken wikilink + 1 GER40.DWX in OWNER.md). After: FAIL,
but **non-deterministic** over the cloud-synced Drive (three runs: 11 / ~30 / 3935 failures;
proof and analysis in the drift report). Deterministic facts: my broken-wikilink fix is stable;
this slice added **zero** new failures (none of the 4 new pages appears in any failure list); in
the largest run all 3935 failures are inside `09 Strategy Wiki/generated/*` (0 outside). The
remaining failures are generated Strategy-Wiki projections + a decision-record symbol mention +
priority-label lint false-positives — all out of this slice's scope and routed in the drift
report.

## Rollback

- Repo: `git checkout` the two modified files; delete the seven new files. No runtime behaviour
  changes (the render_cockpit fix touches a non-rendered function; the generator is new and
  invoked only on demand).
- Vault: created pages can be deleted; edited pages restored from Drive version history (all
  edits are targeted string replacements or append-only dated annexes). The generated
  `Scheduled Automation.md` re-renders from the generator.

## NOT done (with reasons)

- `gate_manifest.v4.draft.json` book-trigger wording — byte-pinned frozen proposal; active
  v4.json is authoritative + superseded-labelled. (Attempted, reverted.)
- `build_backup_retention_manifest.py` `PATH_TO_25` naming — `path_to_25_pair_count` output key
  is consumed downstream; rename belongs to the retention slice.
- Per-EA `SPEC.md` "min-lot / Q13" rows — bulk generated; SPEC template generator slice.
- Generated `09 Strategy Wiki/generated/*` legacy-symbol + broken-link lint failures — generated
  artifacts + Drive-sync race; wiki-sync generator / governance-lint owner.
- `OWNER.md` GER40.DWX — subject of an OWNER decision (record, not drift).
- Vault `12 ToDo/09_Research_Sourcing.md:45` "(HR16)" parenthetical — low-value cross-ref;
  canonical supersession is on the Hard Rules page.

## Commands for the orchestrator

- Refresh the scheduled-automation page any time:
  `python -X utf8 tools/strategy_farm/render_scheduled_automation.py`
  (optional: add a `QM_*` scheduled task that runs it — installer NOT written here; the task
  says write installers only, and this is a low-frequency doc refresh, so left to OWNER/orch).
- Re-run the §11 guard: `python -X utf8 -m pytest tools/strategy_farm/tests/test_no_obsolete_rule_wording.py -q`.
- Vault lint (run against a fully-synced Drive or a local snapshot):
  `python -X utf8 "G:/My Drive/QuantMechanica - Company Reference/00 Governance/lint_company_reference.py"`.
