# Adversarial Review — slice `i3_old_rules_sweep_docs`

**Reviewer:** Claude (adversarial, read-only). **Date:** 2026-09-15.
**Patch:** `scratchpad/patches_i/i3_old_rules_sweep_docs.patch` (1035 lines).
**Repo HEAD at review:** `4aaedf94dba0fcc8d8ae2b389b4b643101ad43ac`.
**Verdict: ACCEPT.**

## Scope verified

Patch = 10 repo files: 2 modified (`render_cockpit_v2.py`, `prompts/autonomous_loop.md`),
8 new (`render_scheduled_automation.py`, 2 tests, matrix, drift report, sweep md+csv, slice
report). Vault pages are written in place on `G:` (not in the patch, same convention as b4);
verified by direct inspection.

## Blocking checks — all clean

- **`git apply --check` against HEAD `4aaedf94`: CLEAN** (applies with no conflict).
- **No RED touches.** No gate threshold, verdict semantic, qualification predicate, or
  validator-pinned JSON token changed. `gate_manifest.v4.json` / `.draft.json` / schema
  **not touched** (the draft-wording fix was correctly attempted-then-reverted because it is
  sha256-byte-pinned by `test_gate_manifest`). No T_Live / AutoTrading / FTMO-purchase / live
  deployment code. No farm-DB writes. No secrets. No dated/sealed decision file edited in
  place. No hand-written vault page clobbered by a generator. No vault page deleted.
- **HR16 wording relaxation** in `autonomous_loop.md` (prompt) is directive-authorized:
  `owner_directive_verbatim.md` §24 "CONTROLLED PARALLELISM IS EXPRESSLY ALLOWED" supersedes
  absolute HR16; followup §11 names it a sweep target. Change is faithful, not a RED touch.

## Honesty / determinism checks — all pass

- **`render_cockpit_v2.py` fix is on a dead function.** `_render_path_to_25` is defined but
  NOT in the `body` assembly (confirmed at 2182–2188; the comment there documents it is
  retained-for-history only). Two existing tests (`test_path_to_25_metrics.py:292`,
  `test_render_cockpit_v2.py:797`) already assert "Weg zu 25" absent from *rendered* html —
  consistent, because the string never reaches output. The one unmarked source occurrence
  (`:1384`) is exactly what the patch relabels. No behaviour change.
- **New regression test logic is sound.** Greps the 5 named surfaces; the 4 unmodified ones
  (`morning_brief`, `heartbeat_snapshot`, `operator_surfaces`, `path_to_25`) carry only
  supersession-marked or zero occurrences → pass; `render_cockpit_v2` passes after the patch's
  marked relabel. Independent tools/ scan found no unmarked obsolete-objective wording on any
  rendered surface beyond the fixed line.
- **Generator is deterministic & idempotent.** Extracted `render_scheduled_automation.py` and
  ran twice on a fixed JSON → byte-identical output; timestamp is the only wall-clock field and
  is isolated; blank descriptions fall back to `—` (never invented).
- **Generated vault page is real and honest.** `Scheduled Automation.md` frontmatter
  `task_count: 86 / enabled 78 / disabled 8` matches live `Get-ScheduledTask QM_*`
  (independently measured: 86 / 78 / 8). `generated: true` + DO-NOT-EDIT banner present.
- **Created pages exist & are correct kind:** `Backups.md` (hand-written), `Live Controls.md`
  (hand-written; correctly states AutoTrading = OWNER-only Hard Rule),
  `Book Evolution/_index.md`, `Scheduled Automation.md` (generated).
- **Sweep classifications spot-checked against real files** — all accurate:
  `book_build_guard.py` (`MIN_QUALIFIED_PAIRS=25` diagnostic, `MIN_VALID_POOL=1` real trigger),
  `gate_manifest.v4.json:375–384` (legacy token + full supersession note),
  `ftmo_probability_contract.v1.json` (correlation + discrete caps = ADVISORY).
- **In-place vault edits honest, dated, history-preserved.** Pipeline Operations Workflow and
  Business Model both keep the original line and add a dated `[!note] Superseded` annex
  (strikethrough, no deletion), citing the decision record.

## Minor (non-blocking) notes

1. Slice report states "Base HEAD: 8a3ba58fea" but repo HEAD is `4aaedf94`; patch still applies
   clean, so this is cosmetic staleness in the report only.
2. Vault in-place edits (`Q17`, `Mission Control`, `Background Automation`, etc.) live on `G:`,
   outside the patch — not patch-reviewable; spot-checked directly here and found faithful.
3. `AI_SPEND_TASKS` / `PURPOSE_FALLBACK` are hand-curated lists inside the generator; they will
   need maintenance if the task set changes. Transparent, fallback-only, not fabricated.
4. `not_done` items (draft manifest, `PATH_TO_25` JSON key, per-EA SPEC rows, generated
   Strategy-Wiki lint noise) are correctly identified as byte-pinned / downstream-consumed /
   bulk-generated and routed, not silently dropped. Agreed.

## Conclusion

The slice does exactly what it claims, touches nothing in the ROT zone, keeps every
validator-pinned token, and its generator + regression guard are verifiable and honest.
**ACCEPT.**
