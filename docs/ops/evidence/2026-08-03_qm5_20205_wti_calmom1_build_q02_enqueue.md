# QM5_20205 WTI Calendar-Momentum Build And Q02 Enqueue Evidence

Date: 2026-08-03 (Europe/Berlin)

## Outcome

- EA: `QM5_20205_wti-calmom1`
- Strategy ID: `KELOHARJU-MOP-WTI-CALMOM1-2026_S01`
- Carrier: `XTIUSD.DWX`, D1
- Result: G0 approved, deterministically allocated, built, Q01 PASS, and one
  non-duplicate priority-track Q02 work item enqueued.
- Portfolio claim boundary: this is a directional WTI candidate with an
  economically different crude-oil return driver from the certified
  XAU/SP500/NDX/XNG book. Realized decorrelation and portfolio admission remain
  unproven and are left to the unchanged downstream gates.

## Locked Edge

At the first D1 bar of a new broker-calendar month, compute (1) the mean WTI
log return for the just-completed calendar-month number over the prior ten
years, requiring five valid same-calendar samples, and (2) the exact
immediately completed broker-calendar-month WTI log return. Buy only when both
signs are positive and sell only when both are negative; disagreement, zero,
or invalid inputs stay flat. A position exits at the next month transition or
after 35 calendar days and carries a `3.5 * ATR(20)` hard stop. The monthly
attempt is consumed, so there is no same-month retry.

This deterministic conjunction is distinct from:

- `QM5_20137_wti-seas-pb`, which trades strict sign disagreement;
- `QM5_20136_wti-caltrend`, which combines the seasonal state with a 63-D1
  trend state;
- the unconditional same-calendar and exact one-month parents; and
- `QM5_12567`, the existing RSI-based XNG pullback edge.

The pre-allocation dedup check returned `CLEAN` after scanning 4,261 registry
rows and 384 cards for the exact slug, strategy ID, author, and mechanic.

## Source And Approval Evidence

- Keloharju, Linnainmaa, and Nyberg, “Return Seasonalities,” *Journal of
  Finance* 71(4), DOI `10.1111/jofi.12398`: completely reviewed governed source
  packet `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`.
- Moskowitz, Ooi, and Pedersen, “Time Series Momentum,” *Journal of Financial
  Economics* 104(2), DOI `10.1016/j.jfineco.2011.11.003`: completely reviewed
  governed source packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.
- Composite claim-boundary packet:
  `strategy-seeds/sources/KELOHARJU-MOP-WTI-CALMOM1-2026/source.md`.
- Durable G0 decision:
  `decisions/2026-08-03_qm5_20205_wti_calmom1_g0.md`.
- Approval commit: `7fa690b79`.

The sources support the two parent effects; their strict WTI sign-agreement
conjunction is a new falsifiable implementation hypothesis, not a published
performance claim.

## Allocation And Build Evidence

- EA ID: `20205`; allocation commit: `6b0f1a829`.
- XTI slot-0 magic: `202050000`.
- Build commit: `6d060c54c`.
- Canonical setfile:
  `framework/EAs/QM5_20205_wti-calmom1/sets/QM5_20205_wti-calmom1_XTIUSD.DWX_D1_backtest.set`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- MQ5 SHA256:
  `a7c4058f96c678562dae91d367eb9eb4265a1748d61581f9b6c7daa55aa6242f`.
- EX5 SHA256:
  `7ef489cc58fe33c14e4cb8ac8416b470ce320e4072e8255c09d5d9fd009c7cad`.
- Setfile SHA256:
  `16d1dc965f8502068ec3555bd4b3d70ad84de3e9bb3a104f8f13fe0a08699b22`.

Validation results:

- Strategy-card schema lint: PASS; no banned/ML indicator hits.
- G0 decision lint: PASS.
- Registry/magic/build guard: PASS.
- Strict compile: PASS, 0 errors and 0 warnings.
- Strict V5 build check: PASS, 0 failures and 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260802_233303.json` and compile log
  `C:/QM/repo/framework/build/compile/20260802_233303/QM5_20205_wti-calmom1.compile.log`.
- P1 build validation: PASS; evidence
  `D:/QM/reports/pipeline/QM5_20205/P1/P1_QM5_20205_result.json`.
- SPEC validation: PASS.
- Magic-resolver tests: 4 passed.

## Q02 Queue Evidence

- Canonical command body:
  `python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20205 --symbols XTIUSD.DWX --max-part2-per-run 0 --apply`.
- The scoped dry run selected exactly one never-tested row and no retry or
  deferred-promotion rows.
- Apply ran while holding the real global factory mutation lock. Lock
  acquisition waited 6.546 seconds over 142 fail-closed attempts; the locked
  path-anchored capacity recheck found 2 of 7 factory terminals. The unchanged
  canonical sweep inserted one row and the real lock reported `released`.
- Work item: `54e53b5e-aa92-4040-97c9-044bdb5cb1c8`.
- Created: `2026-08-02T23:42:25+00:00`.
- Phase/symbol/timeframe: Q02 / `XTIUSD.DWX` / D1.
- Payload: `priority_track=true`; the expected MQ5, EX5, and setfile hashes
  match the hashes above.
- Immediate post-enqueue observation: the paced fleet had claimed the item on
  T2 and reported it `active`; no duplicate row existed.
- The backtest CPU ceiling was not reached.

## Safety Boundary

- No manual MT5 backtest or pipeline phase was launched by this build session;
  execution was left to the paced fleet after enqueue.
- AutoTrading was not toggled and `T_Live` was not accessed or changed.
- No live/demo/shadow setfile or deploy artifact was created.
- The portfolio gate and T_Live manifest were not touched.
