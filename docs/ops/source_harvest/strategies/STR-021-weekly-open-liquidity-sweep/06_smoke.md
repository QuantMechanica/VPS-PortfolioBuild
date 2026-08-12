# STR-021 / QM5_20098 — Build smoke record (2026-07-24)

## Verdict: **PASS** (fixed build; XAUUSD.DWX M15 2024, T5, `-MinTrades 1 -SmokeMode`)

T5 is defective for indicator-handle EAs (see STR-097 `06_smoke.md`), but
QM5_20098 uses no indicator handles (pure closed-bar CopyRates price action),
and a POSITIVE result is valid evidence regardless: the trades demonstrably
happened, the full framework stack ran.

## Smoke 1 — original build 67d9a3d24 (PASS with defect)

`D:\QM\reports\smoke\QM5_20098\20260724_123426\` — 516 trades, deterministic
across both runs, real-tick marker set. Exposed a management defect:
**653,089 rejected TP modifies** (`10016 Invalid stops`, per-tick retry) from
positions whose 2R target was traded through before the deferred TP could be
attached — 519 MB structured log per run, and those positions ran without
their intended 2R exit (economic distortion, not just log noise).
515 successful TP attaches (one per normal trade) confirmed the base logic.

## Fix (see 03_reconciliation.md / 04_spec_final.md amendments 2026-07-24)

Attained-target close (`STRATEGY_EXIT reason=rr_target_attained_pre_tp`) +
per-M15-bar retry pacing for rejected TP modifies. build_check PASS,
strict compile 0 errors / 0 warnings.

## Smoke 2 — fixed build (PASS, clean)

`D:\QM\reports\smoke\QM5_20098\20260724_124929\` — **542 trades**, deterministic
(runs identical), logger volume **2,838 events / 1.0 MB** (down from 1,308,902 /
519 MB). PF 0.95 / net −16,146 / DD 33.7% on the smoke year — economics are
Q02+'s judgment, not the build gate's.

## Factory note

The factory had already picked up the registry-swept Q02 items with the OLD
binary before this fix landed: XAGUSD.DWX Q02 PASS (12:26Z) → Q04 FAIL
(12:42Z). Both verdicts are old-binary evidence; XAGUSD Q02 was requeued
in place after the fix commit so the pipeline re-judges the corrected EA
(see `docs/ops/evidence/2026-07-24_qm5_20098_xagusd_q02_requeue_tp_fix.md`).
XAUUSD.DWX Q02 was still pending and dispatches the fixed binary automatically.

Realized frequency finding: 516–542 fills/yr vs the 8–25/yr spec estimate —
per-side re-arming within the week is mechanically spec-conformant; flagged
for the Q02+ economic gates and codex build-closure review.
