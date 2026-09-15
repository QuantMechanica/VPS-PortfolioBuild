# Adversarial review — slice `h1_live_sleeve_pnl_attribution`

Reviewer: Claude (adversarial). Date: 2026-09-15. Mode: READ-ONLY except this file.
Directive 3 §33 / §43H / §44 (`owner_directive_3_max_factory_utilization_verbatim.md`).
Patch: `.../scratchpad/patches_d3/h1_live_sleeve_pnl_attribution.patch` (1633 lines, read in full).

## Verdict: ACCEPT_WITH_FIXES

Real, deterministic, idempotent, read-only, honest about EVIDENCE_MISSING. No RED boundary
crossed. `git apply --check` clean, tests pass, numbers independently reproduced. Two disclosed
methodology imperfections and one statistical caveat are worth tightening but do not block.

## What I verified

- **`git apply --check` against HEAD → exit 0** (no conflicts).
- **Runtime artifact real:** `D:/QM/reports/state/live_sleeve_attribution.json` (45159 bytes),
  schema `qm.live-sleeve-attribution/v1`, status PRESENT, 24 sleeves, 103 closed positions,
  correlation PRESENT (n_days 54, 120 pairs = C(16,2)).
- **Source is a genuine read-only text export:** `C:/QM/mt5/T_Live/.../QM/journal/live_deals_normalized.csv`
  (262 lines = 261 deals + header; matches `deals_parsed 261`). Tool never decodes `.dat`, never
  attaches a script, never writes T_Live. `authorization` block all-false.
- **Internal reconciliation exact:** 24 sleeves −938.17 + manual magic-0 −1539.50 = book −2477.67
  (recomputed independently from the CSV; matches byte-for-byte).
- **Book realized −2477.67 is a real, correctly-windowed figure:** I re-derived from the raw CSV
  that the 103 positions closed on/after 2026-07-24 net exactly −2477.67; the 22 positions closed
  before inception net +1856.30 and are correctly excluded. Not an artifact, not invented.
- **Manual magic-0 −1539.50 is one real straddling position** (pos 3169151197: IN −2.75 / OUT
  −1536.75, both 2026-07-27). Correctly isolated from `sleeves[]`; the recompose/ROI/wiki consumers
  read `sleeves[]`, so this non-strategy loss never contaminates per-sleeve attribution. Honestly
  flagged to OWNER in the report as >60% of the book loss and not any sleeve's fault.
- **Determinism/idempotency proven:** two runs from the implementer worktree with a fixed
  `--generated-at-utc` produced byte-identical output (`diff` → IDENTICAL); book net −2477.67 both runs.
- **Honest gaps:** per-sleeve `floating_pnl = EVIDENCE_MISSING` (AccountMonitor exports book-level
  floating only) with the correct OWNER-only remediation (extend `QM_AccountMonitor.mq5`, no AI seat
  attaches a script); correlation `EVIDENCE_MISSING` below n_days 20; dark sleeves treated as no-data
  not zero-return (8 dark, incl. known 12778/12969/13117). unmapped_magics [].
- **Wiring symbols exist:** `frozen_snapshot.py` already defines `_sha256_file`, `_file_pointer`,
  imports `shutil`; `external_roi` has `op._registry_ea_key`, `ORIGIN_VALUES`, `_read_json`,
  `_file_fingerprint`; `strategy_wiki_sync` has `normalize_ea_key`, `parse_frontmatter`, `CLASS_*`.
- **Tests:** `pytest` on live_sleeve_attribution + external_roi + strategy_wiki_sync + recompose_engine
  + book_evolution_runner → 51 passed (implementer's 56 includes 2 more files).

## RED-boundary sweep — none crossed

- **T_Live/AutoTrading/deployment/purchase:** read-only CSV parse only; authorization all-false. No toggle, no order, no script attach, no `.dat` decode. OK.
- **Integrity gates / verdict semantics:** unchanged. Blend rule keeps backtest PRIMARY; live is
  confirmatory (`LIVE_CONFIRMATORY_ACTIVE` at n_days≥20) and explicitly never overrides a gate verdict.
- **Economic thresholds (§30):** none changed. No PF/activity/selection threshold touched, so the
  §30 counterfactual procedure is not triggered. New constant `LIVE_BLEND_MIN_DAYS=20` is a
  statistical-usability floor on a new signal, not a modification of an existing selection gate.
- **Farm DB writes:** none. Tool writes only its own read-model file; reads pointer/CSV/snapshot read-only.
- **Scheduler starvation / double-claim:** none. Adds one entry to `book_evolution_runner._default_state_builds`
  (alongside existing universe_map / research_roi); no claim logic, no new scheduled task, no worker-concurrency change.
- **Sealed/dated artifacts edited in place:** none. All new files (LIVE_SLEEVE_PNL_ATTRIBUTION.md is a
  required §44 deliverable); no dated decision mutated.
- **Secrets:** none. Account id 4000090541 already appears in the task/CLAUDE.md; no tokens/keys/passwords.
- **Provider grants / unbounded recovery:** none.
- **Regression guard on load_snapshot:** the new frozen-attribution sha check is guarded on
  `frozen_input_path`/`frozen_input_sha256` presence, so old snapshots and the FTMO venue (which
  never adds attribution) are unaffected; the frozen copy is byte-for-byte so the hash matches.
  `test_recompose_engine` passes.

## Minor (non-blocking) fixes

1. **`contribution_to_book_return` denominator mismatch.** Numerator is book-window-scoped (positions
   closed ≥ 2026-07-24) but denominator `book_base_equity` = first account deposit (100000 @ 2026-04-24),
   not equity at DXZ book inception (~101856 @ 2026-07-24, since pre-inception trading netted +1856.30).
   The headline `realized_return_pct −2.4777%` is therefore ~1.8% relative-off (true book return ≈ −2.43%).
   Disclosed in the doc ("base = first deposit"), so honest, but the base should be book-inception equity
   for a DXZ-book return. Low materiality.
2. **Correlation on sparse daily series.** Pairs are emitted with non-zero Pearson even at `overlap_days`
   0–1 (mean-subtraction artifact of a mostly-zero daily series). The gate is `n_days≥20` only; consumers
   do not additionally gate on `overlap_days`. The field is exposed so this is transparent, but a future
   consumer weighting live correlation should require a minimum overlap. Not consumed for selection today.
3. **Report headline live values already drifted.** Report states equity 99376.10 / floating −13.28;
   the committed runtime file (regenerated 20:00Z) shows 99376.9 / −12.48. These are live moving values,
   not invented; the load-bearing realized figures (−2477.67 / DD 3376.52) are stable and reconcile.

## Note

`book_totals.realized_pnl`/`realized_return_pct` (account-level) correctly include the manual −1539.50;
per-sleeve `contribution_to_book_return` divides by `book_base_equity` not by the book total, so the manual
trade does not distort per-sleeve contributions. This is the right design and is disclosed.
