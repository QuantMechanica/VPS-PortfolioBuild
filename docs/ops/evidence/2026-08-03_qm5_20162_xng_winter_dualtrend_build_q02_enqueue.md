# QM5_20162 XNG Winter Dual-Trend Build And Q02 Evidence

Date: 2026-08-03 (Europe/Berlin)

## Outcome

- EA: `QM5_20162_xng-winter-dualtrend`
- Strategy ID: `EIA-MOP-XNG-WINTER-DUALTREND-2026_S01`
- Carrier: `XNGUSD.DWX`, D1
- Result: the previously approved but unbuilt candidate was completed, passed
  Q01, and was enqueued exactly once on the priority Q02 track.
- Q02 verdict: `FAIL` / `MIN_TRADES_NOT_MET`. The real MT5 baseline produced
  11 trades against the governed minimum of 25. No rescue or requeue was
  attempted, so this candidate is not certified or admitted to the portfolio.

## Locked Edge And Non-Duplicate Boundary

On each genuine new D1 bar, the EA consumes the bar before every entry gate.
It buys `XNGUSD.DWX` only from November through March when the completed close
is above SMA(21), SMA(21) is above SMA(84), and both averages are above their
values five completed bars earlier. It uses a frozen `3.5 * ATR(20)` hard
stop, exits on season or trend invalidation or after 35 calendar days, and
retains the framework Friday close at 21:00 broker time. There is no
oscillator, ML, grid, martingale, scale-in, or external runtime data.

The mechanic is structurally distinct from:

- `QM5_12567`, which buys short-horizon cumulative-RSI pullbacks;
- `QM5_12702`, which uses a monthly winter decision and one SMA;
- `QM5_20063` and `QM5_20204`, which use unconditional monthly return signs;
  and
- `QM5_20164`, whose same-family season is the disjoint May-September window.

The exact slug and strategy ID already mapped to the canonical `QM5_20162`
allocation. The work therefore completed that committed-but-unbuilt candidate
without allocating a duplicate ID or parameter variant.

## Source And Approval Evidence

- Governed composite packet:
  `strategy-seeds/sources/EIA-MOP-XNG-WINTER-DUALTREND-2026/source.md`.
- U.S. Energy Information Administration, “Natural gas use features two
  seasonal peaks per year” (2015): complete governed extraction at
  `strategy-seeds/sources/706222b7-2d60-5fdb-8dab-d722d3c96f92/source.md`.
- Moskowitz, Ooi, and Pedersen, “Time Series Momentum,” *Journal of Financial
  Economics* 104(2), DOI `10.1016/j.jfineco.2011.11.003`: complete governed
  review at `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.
- Durable build-resumption decision:
  `decisions/2026-08-03_qm5_20162_xng_winter_dualtrend_build_resume.md`.

The sources support winter natural-gas seasonality and own-return persistence.
The exact 21/84-D1 stack, five-bar slopes, CFD carrier, ATR stop, and Friday
segmentation remain falsifiable QM implementation hypotheses.

## Allocation And Build Evidence

- EA ID: `20162`; XNG slot-0 magic: `201620000`.
- Binary/setfile artifact commit: `7b3fe72c1`.
- Card/source/SPEC build commit: `48da75d13`.
- MQ5 SHA256:
  `19281a04b73cd0e61007721860b35d95706cabe3d55d01d742ff71752c778c3d`.
- EX5 SHA256:
  `20bc93d63a5561651b79f28de8951c8c3fc1db52dd40e79c5066dec3115f6695`.
- Setfile SHA256:
  `e153a90b486e9cc7bdb875cad031d4a3082dbfc27fd14168b844da25228052ca`.
- Canonical backtest setfile:
  `framework/EAs/QM5_20162_xng-winter-dualtrend/sets/QM5_20162_xng-winter-dualtrend_XNGUSD.DWX_D1_backtest.set`.
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; both news axes and legacy news mode are OFF.

Validation results:

- Strategy-card schema lint: PASS.
- G0 decision lint: PASS.
- SPEC validation: PASS.
- Magic resolution and scoped registry/build guard: PASS.
- Strict compile: PASS, 0 errors and 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260803_102722/QM5_20162_xng-winter-dualtrend.compile.log`.
- Strict V5 build check: PASS, 0 failures and 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260803_102721.json`.

## Q02 Queue And Result Evidence

- The scoped dry run selected one never-tested priority row and no stranded or
  deferred rows.
- The first apply correctly failed closed while the scheduled pump held
  `D:/QM/strategy_farm/state/FACTORY_MUTATION.lock`.
- The successful apply used the repository's unchanged
  `FactoryMutationLock`. An in-memory waiter acquired that same lock after 240
  attempts and 25.625 seconds, then found 2 of 7 path-anchored factory
  terminals while still holding it. It did not delete, replace, or bypass the
  lock.
- Canonical command body:
  `python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20162 --symbols XNGUSD.DWX --queue-ceiling 7000 --max-part2-per-run 0`.
- Apply inserted one part-1 row, zero part-2 rows, and zero deferred promotions.
- Work item: `8ef419db-6ccf-4804-894a-7a4da78fa2bc`, created
  `2026-08-03T10:47:30+00:00`, Q02 / `XNGUSD.DWX` / D1, attempt 0,
  `priority_track=true`.
- T10 claimed the item and ran the unchanged binary and setfile. The source and
  deployed hashes matched before and after the run.
- Result evidence:
  `D:/QM/reports/work_items/8ef419db-6ccf-4804-894a-7a4da78fa2bc/QM5_20162/20260803_104740/summary.json`.
- Test window: `2018.07.02` through `2022.12.31`; 11 trades; profit factor
  1.44; net profit 560.84; drawdown 2.46%. The sole failure class was
  `MIN_TRADES_NOT_MET` because 11 was below the required 25.

The card explicitly retires a baseline below five completed trades per year.
This result is therefore recorded as a clean strategy failure rather than
being widened, tuned, or requeued.

## Safety Boundary

- No manual MT5 test or pipeline phase was launched; the paced fleet owned the
  Q02 execution after enqueue.
- The backtest CPU ceiling was not reached.
- AutoTrading was not toggled and `T_Live` was not accessed or changed.
- No live/demo/shadow setfile or deploy artifact was created.
- The portfolio gate and T_Live manifest were not touched.
