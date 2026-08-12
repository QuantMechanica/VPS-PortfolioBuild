# QM5_20013 XNG Two-Month Contrarian - Q01 Build And Q02 Enqueue

Date: 2026-07-20

## Outcome

`QM5_20013_xng-2m-contr` was extracted, approved under the OWNER commodity-
sleeve mission, built under the V5 framework, compiled cleanly and auto-
enqueued to Q02. The work item was not dispatched by this mission.

## Edge And Source

The EA implements the fixed two-month unconditional sign-contrarian rule in
Mishra and Smyth (2016), "Are Natural Gas Spot and Futures Prices
Predictable?", *Economic Modelling* 54, 178-186, DOI
https://doi.org/10.1016/j.econmod.2015.12.034. The complete author manuscript's
printed page 18 defines the trading simulation.

The carrier locks Jan-Feb, Mar-Apr, May-Jun, Jul-Aug, Sep-Oct and Nov-Dec
broker-calendar periods. At each odd-month boundary it buys after a completed
two-month decline and sells after a rise. There is no oscillator, magnitude
threshold, moving-average gate, volatility filter, fitted mean, ML or external
runtime data. Exact equality retains the prior source state. Non-equality
renews the fixed-period package.

Source limitations are explicit: the paper assumes zero costs, supplies no
risk adjustment or drawdown for its trading table, and studies Henry Hub spot
and fixed-maturity futures series rather than `XNGUSD.DWX`. The `4.0*ATR(20)`
hard stop, 70-day stale override, spread cap and restart-safe no-reentry guard
are V5 additions.

## Identity And Artifacts

- EA: `QM5_20013_xng-2m-contr`
- Strategy ID: `MISHRA-SMYTH-XNG-2M-2016_S01`
- Source ID: `MISHRA-SMYTH-XNG-PRED-2016`
- Symbol/timeframe: `XNGUSD.DWX` D1
- Magic: `200130000`, slot 0
- Setfile: `framework/EAs/QM5_20013_xng-2m-contr/sets/QM5_20013_xng-2m-contr_XNGUSD.DWX_D1_backtest.set`
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- Build result: `artifacts/qm5_20013_build_result.json`
- Farm build task: `a63cc1f1-79a2-47f2-b96c-149b0e66ff97`

## Non-Duplicate Boundary

The automated dedup check returned CLEAN and the manual mechanic audit found no
unconditional fixed two-month XNG sign fade. The nearest strategies use a
two-day RSI(2), a four-week six-percent event, a six-month 20-percent event, a
weekly volatility percentile, or a bimonthly XTI/XNG coefficient-of-variation
rank. The source, horizon, trigger and lifecycle are materially different from
the certified `QM5_12567_cum-rsi2-commodity` sleeve.

## Q01 Validation

- Strategy Card schema lint: PASS.
- Approved-card G0 lint: PASS.
- EA build identity guard: PASS.
- SPEC validation: PASS.
- Build guardrails: PASS, zero findings.
- Symbol scope: `SINGLE_SYMBOL_OK`, zero leaks.
- Strict `build_check.ps1`: PASS, 0 failures, 0 warnings.
- Strict `compile_one.ps1`: PASS, 0 errors, 0 warnings.
- EX5: generated at
  `framework/EAs/QM5_20013_xng-2m-contr/QM5_20013_xng-2m-contr.ex5`.
- Resolver registry SHA matches `magic_numbers.csv`:
  `BCE471124A2CAB795E134722BB218FAA6EFDDA8CA03C0950F7A61C01F0178A42`.

## CPU Ceiling And Q02 Handoff

The paced-fleet scan found active MT5 test processes on T2, T6, T7 and T8.
No manual smoke test, backtest, optimization, dispatch tick or worker tick was
started. The build uses the permitted `deferred_p2_smoke` marker so Q02 owns the
first tester execution when fleet capacity is available.

- Work item: `5b880ae3-30d8-47ea-9708-dd21a699933d`
- Phase: Q02
- Status at handoff: `pending`
- Attempt count: 0
- Claimed by: null
- Symbol/timeframe: `XNGUSD.DWX` D1
- Enqueued at: `2026-07-20T02:52:55+00:00`

## Safety

No T_Live file, AutoTrading setting, deploy manifest, T_Live manifest,
portfolio gate, portfolio admission or live setfile was created or modified.
Realized performance and correlation to the certified book remain unproven and
must be decided by later pipeline gates.

