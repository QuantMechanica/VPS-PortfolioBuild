# Documentation Drift Report — 2026-09-15 (master §69)

**Authority:** OWNER directive §69 (documentation drift report) + follow-up §10/§11 under
OWNER-DEC-CBE-20260915. **Slice:** `i3_old_rules_sweep_docs`.

What drifted, what was fixed, what remains — for company documentation (repo docs + Company
Reference vault) against the real system on 2026-09-15. Companions:
`OLD_RULES_SWEEP_2026-09-15.md` (+ `.csv`) — the §11 obsolete-rule sweep;
`../../DOCUMENTATION_COMPLETENESS_MATRIX_2026-09-15.md` — the §10 item-by-item matrix.

## What drifted (found this slice, beyond the earlier b3/b4 slices)

| # | Drift | Where | Real system | Fix |
|---|---|---|---|---|
| 1 | Book-trigger ASCII diagram still asserted "≥25 qualifizierte Kandidaten" as the trigger | vault `03 Pipeline/Pipeline Operations Workflow.md:41` | `book_build_guard.py` triggers on a non-empty valid pool (≥1) + OWNER order | line → "gültiger qualifizierter Pool (≥1)" + superseded note after the code fence |
| 2 | Q17 residual "14 days" / "min-lot" wording (b4 fixed the header/tables but missed the kill-switch intro, cadence row, "After Q13 PASS" heading, min-lot→size-up line) | vault `03 Pipeline/Q17 Live Burn-In DXZ.md:69,87,103,105` | Q17 = evidence-based live introduction (§10); no fixed 14-day / min-lot default | 4 lines → evidence-based observation window (§10), Q15 allocation |
| 3 | Internal FTMO hard target `P(Phase-1-Pass in 60 Tagen) ≥ 0,80` stated as a current "Anspruch" | vault `01 Identity/Business Model.md:40` | §15: FUND_SCORE / first-passage remain evidence, not eternal hard targets; probability > speed; `ftmo_fitness.py` time-to-target = SECONDARY | superseded annex (§15) |
| 4 | Dead cockpit function still carried the "Weg zu 25" objective heading | repo `render_cockpit_v2.py:1384` (`_render_path_to_25`, not rendered) | objective abolished (§3); pool is a diagnostic | relabelled to "Qualifizierungs-Pool (Diagnostik)" + supersession comment |
| 5 | Autonomous-loop prompt declared HR16 "exactly ONE active source … cannot violate" | repo `prompts/autonomous_loop.md:253` (consumed by `autonomous_wake.ps1` / `scheduled_task_autonomous_wake.xml`) | §24: HR16 no longer absolute — Controlled Parallelism | rewrote the boundary to Controlled Parallelism (§24) |
| 6 | Scheduled-automation page recorded **78** tasks (2026-08-21), missing the Kimi + Book-Evolution tasks | vault `06 Infrastructure/Background Automation and Scheduled Tasks.md` | live `Get-ScheduledTask QM_*` = **86** (78 enabled / 8 disabled) | dated annex + new **generated** page `Scheduled Automation.md` (`render_scheduled_automation.py`) as the live inventory |
| 7 | Weekly-recomposition page linked a non-existent Book-Evolution index (H1 dangling wikilink) | vault `04 Processes/Weekly Book Recomposition.md:6` → `[[../08 Current State/Book Evolution/_index]]` | weekly packages live at `D:/QM/reports/book_evolution/<ISO-week>/` | created `08 Current State/Book Evolution/_index.md` (documents the runtime output path; fixes the link) |

## What was created (was MISSING)

- `06 Infrastructure/Backups.md` — vault + farm-state + report/log/tester-cache retention, tasks
  and repo scripts, evidence-survival watch, restore rules.
- `06 Infrastructure/Live Controls.md` — T_Live / FTMO / factory start+watchdog scripts and
  tasks; AutoTrading = OWNER-only; no `T_Live_OFF` script (off is OWNER via MT5); Q17 evidence
  introduction.
- `06 Infrastructure/Scheduled Automation.md` — **generated** (frontmatter `generated: true`,
  DO-NOT-EDIT banner) full `QM_*` inventory + purpose, refreshed by
  `tools/strategy_farm/render_scheduled_automation.py`.
- `08 Current State/Book Evolution/_index.md` — weekly-package index (fixes drift #7).

## What was updated in place (dated annex, no history deletion)

- `06 Infrastructure/Mission Control.md` — "Phase D LANDED 2026-09-15" annex (Book-Evolution
  primary view + read-models + generator relabels + the new regression guard).
- `06 Infrastructure/Background Automation and Scheduled Tasks.md` — task-count drift annex.

## Vault lint — before / after (and a material caveat)

Command: `python -X utf8 "G:/My Drive/QuantMechanica - Company Reference/00 Governance/lint_company_reference.py"`.

| Run | Result | Failures | Breakdown |
|---|---|---|---|
| **Before** (start of slice) | FAIL | 11 | 9 "old gate token in active page", 1 broken wikilink (Weekly Book Recomposition → Book Evolution index), 1 legacy symbol (GER40.DWX in `12 ToDo/AI ToDos/OWNER.md`) |
| **After run A** | FAIL | ~30 | 0 gate-token, 0 broken-wikilink; ~28 legacy-symbol in `09 Strategy Wiki/generated/REJECTED/*` (GER40.DWX) + 1 DRAFT (US500.DWX) + OWNER.md GER40.DWX |
| **After run B (final)** | FAIL | 3935 | 3535 broken wikilinks + ~400 legacy-symbol — **all 3935 inside `09 Strategy Wiki/generated/*`; 0 outside it** |

**The lint is non-deterministic over this vault** because the Company Reference is a
cloud-synced Google Drive mount and the large generated `09 Strategy Wiki/` tree streams in and
out during the lint's `rglob`. Proof: within one run, `OWNER.md` was flagged for `GER40.DWX`
(late `check_symbols`) but NOT for its still-present `P0` token (early
`check_forbidden_active_terms`) — the file's bytes changed between the two passes. Three runs
minutes apart returned 11 / ~30 / 3935 failures. Deterministic, in-scope facts:

- **My broken-wikilink fix is stable** — "Weekly Book Recomposition" no longer appears in any
  failure list once `Book Evolution/_index.md` exists.
- **This slice introduced zero new lint failures** — none of the four new pages
  (`Scheduled Automation`, `Backups`, `Live Controls`, `Book Evolution/_index`) appears in any
  failure list.
- Every failure in the largest run is inside `09 Strategy Wiki/generated/*` (0 outside).

## What remains (out of this slice's scope — routed, not silently dropped)

1. **Generated Strategy-Wiki lint noise** — the wiki-sync generator emits REJECTED/DRAFT
   projection nodes that (a) carry the source card's legacy symbol (`GER40.DWX`/`US500.DWX`) and
   (b) cross-link to nodes not all present on a partially-synced Drive. These are generated
   artifacts (never hand-edited) and belong to the **wiki-sync generator slice** (annotate/skip
   legacy symbols; make link resolution robust) or the source cards. **Do not hand-fix.**
2. **Vault lint over a cloud-synced Drive is not a reliable gate.** Recommend the governance
   owner run the lint against a local snapshot (or after Drive is fully synced), and/or:
   - relax the `old gate token` regex so priority labels `P0`–`P3` are not false-positives
     (current false hits: `OWNER.md`, `Codex.md`, dated 08-notes — all priority/coverage labels,
     not pipeline gates);
   - scope `check_symbols` to exclude/annotate legacy symbols in `09 Strategy Wiki/generated/`
     REJECTED/DRAFT projections (a rejected card's projection should show its real symbol).
3. **`GER40.DWX` in `12 ToDo/AI ToDos/OWNER.md`** is the *subject* of an OWNER decision (rename
   the two cards to `GDAXI.DWX`) — a record, not wording drift; left intact.
4. **`build_backup_retention_manifest.py` `PATH_TO_25` naming** — the `path_to_25_pair_count`
   JSON key is consumed downstream; rename belongs to the retention slice.
5. **Per-EA `SPEC.md` "min-lot / Q13" rows** — bulk generated; belongs to the SPEC template
   generator.

None of the remaining items is a hand-written current-guidance drift; all are generated
artifacts, records, or lint-tooling scope. The company documentation a new competent agent
reads (COMPANY / RESEARCH / FACTORY / PORTFOLIOS / FTMO / OPERATIONS) now matches the real
system.
