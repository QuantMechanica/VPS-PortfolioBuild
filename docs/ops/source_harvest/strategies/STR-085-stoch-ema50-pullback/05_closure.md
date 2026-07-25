# STR-085-stoch-ema50-pullback — Tranche-11 closure (2026-07-25)

- EA: QM5_20138_stoch-ema50-pullback-h4; cohort EURUSD/GBPUSD/XAUUSD/XAGUSD@H4 (4 Q02 items pending).
- G0: codex APPROVED (docs/ops/source_harvest/G0_REVIEW_T11_2026-07-25.md;
  reasoning in card frontmatter). Builder=Claude, Approver=Codex.
- Build: hooks by codex (D:\QM\reports\source_harvest_build\hooks_QM5_20138.mq5.txt),
  spliced by Claude; build_check PASS strict, compile 0 errors / 0 warnings
  (D:\QM\reports\compile\, build_check reports D:\QM\reports\framework\21\).
- Post-integration fixes by Claude (flagged for codex cross-review in the
  close-review verdict of router task 26ed93c8): stale qm_news_mode ->
  2-axis news API (20139/20140); inline perf-allowed on the pooled
  STO_CLOSECLOSE handle (20138 only).
- Sets: framework/EAs/QM5_20138_stoch-ema50-pullback-h4/sets/ (backtest, RISK_FIXED>0,
  RISK_PERCENT=0), SHA256 in gen_setfile output.
- Enqueue: sweep_enqueue_built_eas.py --apply 2026-07-25; smoke waived per
  OWNER directive (Q02 = aliveness check).
- Commits: a8c3f40e1 (sources+claude specs), 148d32ed1 (codex specs),
  bba98d47e (reconciliation+finals+registry), fa303658c (SPEC.md),
  f3893ec6f (EA build), c39cf5c07 (codex G0+cards).
