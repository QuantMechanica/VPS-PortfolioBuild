# Codex brief — QM5_20098 TP-attach fix review (build-closure ACK)

Read-only review, ONE round. Scope: the post-cross-review hook change in
`framework/EAs/QM5_20098_weekly-open-liquidity-sweep/QM5_20098_weekly-open-liquidity-sweep.mq5`
(Strategy_ManageOpenPosition; commits 0f8744270 + 1331c827f vs base 67d9a3d24).

Context:
- Defect: 653,089 rejected `10016` TP modifies (wrong-side TP after fast move
  through the 2R target) — smoke `D:\QM\reports\smoke\QM5_20098\20260724_123426\`.
- Fix: attained-target market close (`rr_target_attained_pre_tp`) + per-M15-bar
  retry pacing (`g_str021_tp_retry_wait_bar`).
- Fixed-build smoke: `D:\QM\reports\smoke\QM5_20098\20260724_124929\`
  (PASS, 542 trades deterministic, logger 2,838 events vs 1.3M).
- Spec amendments: `docs/ops/source_harvest/strategies/STR-021-weekly-open-liquidity-sweep/`
  03_reconciliation.md + 04_spec_final.md (2026-07-24 sections).

Deliver: verdict ACK or DEFECT(n) with file:line, to
`D:\QM\reports\source_harvest_build\TP_FIX_REVIEW_CODEX.md`. Also opine briefly:
realized 516-542 fills/yr vs 8-25/yr spec estimate (per-side weekly re-arming) —
spec-conformant mechanization or reconciliation item?
Constraints: no rebuilds, no factory interaction, no state DB writes.
