# STR-141-dual-supertrend-confluence — Tranche-14 closure (2026-07-25) — FINAL harvest tranche

- EA: QM5_20151_dual-supertrend-confluence-h1; cohort EURUSD/GBPUSD/USDJPY/USDCAD/AUDUSD/USDCHF/NZDUSD@H1.
- G0: codex APPROVED (G0_REVIEW_T14; card frontmatter reasoning; codex
  enriched the card bodies with Thesis/Filters sections). Builder=
  Claude, Approver=Codex.
- Build: codex hooks spliced; build_check strict PASS, compile 0/0
  (20150: inline perf-allowed on the pooled STO_CLOSECLOSE handle —
  QM5_20138 precedent).
- Sets: 7 backtest set(s), RISK_FIXED>0/RISK_PERCENT=0.
- Enqueue: DEFERRED per OWNER directive ("erledige alles, ohne die
  Factory einzuschalten"). Post-ON: sweep_enqueue_built_eas.py --apply
  picks up T13 (20146-20148) + T14 (20150-20152) automatically.
- Commits: f344c03cf (sources+claude specs), codex T14 specs commit,
  1f6460ca2 (recon+finals+registry), 0f31d9faf (EA builds), codex G0.
