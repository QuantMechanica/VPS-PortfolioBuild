# STR-088-4x25ma-mtf-trend — Tranche-12 closure (2026-07-25)

- EA: QM5_20142_mtf-ema25-align-h4; cohort EURUSD/GBPUSD/USDJPY@H4 (3 Q02 items pending).
- G0: codex APPROVED (docs/ops/source_harvest/G0_REVIEW_T12_2026-07-25.md;
  reasoning in card frontmatter). Builder=Claude, Approver=Codex.
- Build: codex hooks (D:\QM\reports\source_harvest_build\hooks_QM5_20142.mq5.txt)
  spliced; OnInit self-test wiring per artifact headers (20143 BB-shift
  causality, 20144 cloud alignment — INIT_FAIL gates); raw-CopyBuffer
  self-tests moved to QM_IndicatorReadBuffer (EA_FRAMEWORK_RAW_COPYBUFFER
  is a hard rule without perf-allowed override — new lesson);
  STRATEGY_STATE registered in event_vocabulary.json.
- build_check strict PASS 0 failures; compile 0 errors x3.
- Sets: 9 backtest sets (RISK_FIXED>0, RISK_PERCENT=0).
- Enqueue: sweep 2026-07-25, 9 Q02 items; smoke waived per OWNER.
- T11 post-integration fixes SIGNED_OFF by codex (G0_REVIEW_T12).
- Commits: 521fc64f8 (sources+claude specs+STR-096 retirement),
  aebbf1d16 (codex specs+096 confirm), 6749bf968 (recon+finals+registry),
  11de967c3 (EA builds), codex G0 commit.
