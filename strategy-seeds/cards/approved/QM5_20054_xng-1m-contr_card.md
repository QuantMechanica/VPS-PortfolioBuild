---
strategy_id: MISHRA-SMYTH-XNG-1M-2016_S02
source_id: MISHRA-SMYTH-XNG-PRED-2016
ea_id: QM5_20054
slug: xng-1m-contr
status: APPROVED
created: 2026-07-23
created_by: Research+Development
last_updated: 2026-07-23
g0_status: APPROVED
source_citation: "Mishra, V. and Smyth, R. (2016), Are Natural Gas Spot and Futures Prices Predictable?, Economic Modelling 54, 178-186, DOI 10.1016/j.econmod.2015.12.034."
source_citations:
  - type: academic_paper
    citation: "Mishra, V. and Smyth, R. (2016). Are Natural Gas Spot and Futures Prices Predictable? Economic Modelling, 54, 178-186."
    location: "Trading simulation on printed p. 18 and Table 10 on printed p. 34; DOI https://doi.org/10.1016/j.econmod.2015.12.034; complete author manuscript linked in the source packet"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MISHRA-SMYTH-XNG-PRED-2016]]"
concepts:
  - "[[concepts/commodity-mean-reversion]]"
  - "[[concepts/fixed-horizon-contrarian]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/atr]]"
strategy_type_flags: [mean-reversion, time-stop, symmetric-long-short, atr-hard-stop]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Twelve fixed monthly decisions per complete year; normally twelve renewed packages, subject to exact equality, missing history, spread, or a prior stop in the same period."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify the source-defined unconditional one-month XNG sign fade on the DWX CFD carrier; the paper assumes zero costs and does not establish CFD basis, risk-adjusted efficacy, drawdown, or correlation to the certified book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_futures_basis, low_frequency]
g0_approval_reasoning: "APPROVED under the 2026-07-23 OWNER commodity-sleeve mission: R1 peer-reviewed single-source lineage; R2 source-tested fixed one-month contrarian sign rule at every broker-month boundary; R3 registered XNG D1 carrier and twelve decisions/year; R4 deterministic, ML-free and one position per magic."
---

# XNG One-Month Unconditional Contrarian State

## Hypothesis

Natural-gas spot and futures prices can mean-revert at a fixed one-month
horizon. Mishra and Smyth test that structural hypothesis with the simplest
possible state rule: after a one-month fall, hold long for the next one-month
period; after a rise, hold short. This card ports that sparse rule to the
continuous `XNGUSD.DWX` CFD to provide an energy sleeve whose horizon and
mechanic are different from the certified short-horizon XNG oscillator.

## Source And Evidence Boundary

The sole lineage is Mishra and Smyth (2016), "Are Natural Gas Spot and Futures
Prices Predictable?", *Economic Modelling* 54, 178-186, DOI
https://doi.org/10.1016/j.econmod.2015.12.034. The complete author manuscript
states the trading rule on printed page 18 and reports the simulation on page
34. It studies EIA Henry Hub spot and one- through four-month futures series,
not a Darwinex CFD.

The source assumes full investment, zero transaction costs and commissions.
It supplies no significance test, volatility adjustment, drawdown, roll,
margin or short-financing model for Table 10. Its unusually strong one-month
sample result is explicitly treated as sample-specific risk, not an expected
performance claim. `expected_pf: 1.01` is only a conservative queue prior.

## Concept And Non-Duplicate Decision

Lock broker-calendar periods to Jan-Feb, Mar-Apr, May-Jun, Jul-Aug, Sep-Oct and
Nov-Dec. On the first tradable D1 bar of each broker month, reconstruct
the latest two completed month-end closes:

`C0 = just-completed month`, `C1 = one month earlier`.

- BUY when `C0 < C1`, fading the just-completed one-month decline.
- SELL when `C0 > C1`, fading the just-completed one-month rise.
- On exact equality, retain the prior position; if flat, remain flat.

For non-equality, close the old fixed-period package before opening the new
target, including when the direction repeats. The source does not state the
calendar epoch or implementation turnover for same-direction states; the
monthly anchor and observable package renewal are frozen ex-ante portability
decisions, not fitted parameters.

No exact or mechanic duplicate exists. The nearest XNG builds use RSI(2),
four-week six-percent events, six-month 20-percent overextension, or a weekly
volatility percentile. `QM5_13139_energy-cv-rank` shares a monthly clock but
ranks XTI against XNG on a 36-month coefficient of variation. None implements
an unconditional one-month XNG time-series sign fade.

## Markets And Timeframe

- Target: `XNGUSD.DWX` only, D1, magic slot 0.
- Decision: first tradable D1 bar of every broker month.
- Expected cadence: twelve decisions/packages per complete year; Q02 is
  authoritative and stop-outs without same-period re-entry can reduce entries.
- Backtest risk only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: MT5 D1 closes, ATR, spread, calendar, deal and position state.

## Rules

The following entry, exit, filter and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Evaluate only at the first new D1 bar of Jan, Mar, May, Jul, Sep or Nov.
- Reconstruct two distinct completed broker-month closes from a bounded D1
  scan and compare `C0` strictly with `C2`; `C1` is retained only to prove that
  the endpoints span two distinct completed months.
- BUY for `C0 < C1`; SELL for `C0 > C1`; equality creates no new order.
- Before a non-equality entry, the preceding period's package is closed.
- Require valid history/prices/ATR, acceptable spread, no open current-period
  package and no earlier entry deal in the current monthly period.
- Place a frozen `4.0 * ATR(20)` D1 hard stop; no take-profit.

## 5. Exit Rules

- At a valid non-equality boundary, liquidate the prior package before renewal,
  even when the new target has the same direction.
- On exact equality, retain the prior position as the source states; the V5
  40-day stale guard remains a safety override.
- Close at 40 calendar days as a fail-safe or at the broker hard stop.
- No intraperiod signal, target, trail, break-even move or discretionary exit.

## 6. Filters (No-Trade Module)

- Exact `XNGUSD.DWX`, D1, slot-0 host guard.
- Locked one-month holding period and monthly epoch; parameter, history,
  price, arithmetic, ATR and spread checks fail closed.
- Zero modeled `.DWX` spread is valid; a spread above 3000 points blocks entry.
- Framework kill switch and entry-news compliance remain authoritative.

## 7. Trade Management Rules

- One position per magic and at most one entry package per monthly period.
- Current-period position/deal history blocks restart or post-stop re-entry.
- No scale-in, stacking, partial close, grid, martingale, pyramiding, adaptive
  fit, external feed, banned indicator or ML.
- Friday close is disabled to preserve the fixed one-month holding horizon.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_holding_months` | 1 | [1] | source-selected fixed holding/trading frequency |
| `strategy_history_bars` | 120 | [120] | bounded D1 month-end reconstruction |
| `strategy_rebalance_month_parity` | 0 | [0] | every broker-month boundary |
| `strategy_atr_period` | 20 | [20] | V5 frozen hard-stop estimate |
| `strategy_atr_sl_mult` | 4.0 | [4.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale safety override |
| `strategy_max_spread_points` | 3000 | [3000] | XNG entry spread cap |

All signal and cadence parameters are locked for Q02. Changing the epoch,
horizon, adding a threshold/filter or making the signal adaptive requires a
new card rather than an optimization of this source extraction.

## Kill Criteria

- Retire at Q02 if realized cadence is below five completed trades per year.
- Fail on zero trades, invalid month-end reconstruction, repeated `OnInit`
  failure, nondeterministic reruns, risk-mode mismatch or unacceptable PF/DD.
- Do not rescue failure with a shorter horizon, magnitude threshold, RSI,
  trend/volatility filter, alternate epoch or relaxed risk contract.
- Treat futures/spot-to-CFD basis and realized book correlation as
  falsification risks, never as waiver grounds.

## Strategy Allowability Check

- [x] R1 reputable: one peer-reviewed paper with DOI, institutional record and
  complete author manuscript.
- [x] R2 mechanical: fixed endpoints, opposite sign, equality state, epoch,
  renewal, ATR stop and stale guard.
- [x] R3 testable: registered `XNGUSD.DWX` D1 carrier and twelve decisions/year.
- [x] R4 compliant: no ML, banned indicator, external runtime feed, adaptive
  fit, stacking, grid, martingale or pyramiding.
- [x] Exact and mechanic dedup searches are clean.

## Framework Alignment

- no_trade: exact symbol/timeframe/slot and locked-parameter guards.
- trade_entry: source-defined opposite sign of the completed one-month move,
  with one frozen V5 ATR hard stop.
- trade_management: fixed-period renewal plus 40-day stale safety override.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` and broker stop.

## Risk And Safety Boundary

This build may create one RISK_FIXED XNG backtest setfile only. It must not
create or modify a live setfile, T_Live, AutoTrading, a deploy/T_Live manifest,
portfolio admission, portfolio KPI code or the portfolio gate. Orthogonality
to the certified book remains unproven until the later correlation gate.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-20 | initial source-backed XNG one-month contrarian build | Q02 | Q01 PASS; Q02 pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-20 | APPROVED under OWNER commodity-sleeve mission | this card |
| Q01 Build Validation | 2026-07-20 | PASS: strict compile 0/0; build check 0 failures/0 warnings | `artifacts/qm5_20054_build_result.json` |
| Q02 Baseline Screening | 2026-07-20 | pending, unclaimed; work item `5b880ae3-30d8-47ea-9708-dd21a699933d` | `docs/ops/evidence/2026-07-20_qm5_20054_xng_2m_contr_q02_enqueue.md` |
