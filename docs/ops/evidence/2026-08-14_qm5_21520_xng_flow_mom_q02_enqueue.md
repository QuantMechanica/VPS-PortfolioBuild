# QM5_21520 XNG quiet-flow momentum — Q02 enqueue

Date: 2026-08-14

Branch: `agents/board-advisor`

Owner: Codex

## Edge built

- EA: `QM5_21520_xng-flow-mom`
- Strategy ID: `ZHAO-ST-MOMREV-2026_XNG_S04`
- Host: `XNGUSD.DWX`, D1, slot 0, magic `215200000`
- Signal: at the first D1 bar of a new broker week, rank the latest completed
  five-D1 native tick-volume sum against 40 earlier, non-overlapping five-bar
  sums. Follow the same five-D1 close-return sign only when the rank is at or
  below 25%; otherwise consume the week flat.
- Exit: frozen `2.5 * ATR(14,D1)` hard stop, five completed D1 bars, or
  framework Friday close; no take-profit or signal exit.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Source and claim boundary

Zhao, Ding, Yu, and Kang (2026), "Momentum and Reversal on the Short-Term
Horizon: Evidence from Commodity Markets," SSRN 6425598, DOI
`10.2139/ssrn.6425598`, supplies the weekly residual-component momentum
direction. Its decomposition uses investor positions and does not specify
this tick-volume proxy, XNG carrier, percentile, stop, hold, costs, results,
or portfolio correlation.

The governed source record is bounded to accessible metadata and
abstract/methodology summaries. The deterministic source router returned
`PERMISSION_REQUIRED` / `DEFERRED:SOURCE_POLICY` for the SSRN URL. No proxy,
authentication, or access-control workaround was attempted. Low native MT5
tick volume is explicitly an unproven, falsifiable proxy.

## Non-duplicate boundary

- `QM5_12567` is long-only cumulative-RSI pullback plus slow trend.
- `QM5_13101` requires a return-magnitude shock and low realized-volatility
  rank and permits an opposite-return exit.
- `QM5_21504` admits the upper native-volume tail and reverses; `QM5_21520`
  admits only the disjoint lower tail and continues.
- `QM5_21505` is a preallocated but unbuilt silver carrier and supplies no XNG
  implementation or pipeline evidence.

The canonical checker found no exact slug or strategy-ID collision. Expected
source-family fuzzy hits were reviewed before allocation. Verdict:
`CLEAN_XNG_WEEKLY_QUIET_FLOW_MOMENTUM_AFTER_SOURCE_FAMILY_REVIEW`.

## Artifacts

- Card: `strategy-seeds/cards/xng-flow-mom_card.md`
- Approved card:
  `strategy-seeds/cards/approved/QM5_21520_xng-flow-mom_card.md`
- Source packet:
  `strategy-seeds/sources/ZHAO-XNG-QUIETFLOW-2026/source.md`
- G0 decision:
  `decisions/2026-08-14_qm5_21520_xng_flow_mom_g0.md`
- EA:
  `framework/EAs/QM5_21520_xng-flow-mom/QM5_21520_xng-flow-mom.mq5`
- EX5:
  `framework/EAs/QM5_21520_xng-flow-mom/QM5_21520_xng-flow-mom.ex5`
- Q02 setfile:
  `framework/EAs/QM5_21520_xng-flow-mom/sets/QM5_21520_xng-flow-mom_XNGUSD.DWX_D1_backtest.set`
- Build record: `artifacts/qm5_21520_build_result.json`

## Q01 validation

- Card schema/ML-ban lint: PASS on root, approved, and EA-doc copies.
- SPEC schema: PASS, 1/1.
- Deterministic arithmetic reference: PASS, 6/6. It covers the exact 25%
  admission boundary, above-cap rejection, positive/negative continuation,
  conservative tie behavior, disjoint windows, and exact history length.
- Symbol scope: `SINGLE_SYMBOL_OK`, 0 violations.
- Build guardrails: PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log:
    `C:\QM\repo\framework\build\compile\20260814_120842\QM5_21520_xng-flow-mom.compile.log`
  - EX5 size: 377128 bytes.
- Framework build check: PASS, 0 failures, 0 warnings.
  - Report:
    `D:\QM\reports\framework\21\build_check_20260814_120920.json`.
- P1 artifact: PASS.
  - Report:
    `D:\QM\reports\pipeline\QM5_21520\P1\P1_QM5_21520_result.json`.
- EX5 SHA-256:
  `c175286f41907d5bbe0bf89c3777424fa28ca688f1b4a2b1d590fc8e2316a776`.

The regenerated resolver kept all 15,955 active magic rows, dropped zero,
and binds slot 0 to `215200000`.

## Q02 queue

The CPU check before enqueue found one active factory terminal (`T6`) out of
ten and three total `terminal64` processes including non-factory terminals.
The pending queue was 1,026 against the sweep ceiling of 7,000, so the ceiling
was not binding.

A targeted governed never-tested sweep for `QM5_21520` created exactly one
priority item and was read back before handoff:

- Work item: `981d76d7-dcb8-4ef0-a891-03dc8f6edaa3`
- Phase/kind: `Q02` / `backtest`
- Symbol/timeframe: `XNGUSD.DWX` / D1
- Status at verification: `pending`, attempt count 0, unclaimed
- Created UTC: `2026-08-14T12:12:26+00:00`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`

No terminal was started, stopped, reserved, released, reaped, or manually
dispatched by this build. The paced fleet owns the first tester run.

## Safety

No live trading, AutoTrading toggle, `T_Live` file, deploy/T_Live manifest,
portfolio gate, portfolio admission, correlation waiver, or portfolio KPI
file was touched.
