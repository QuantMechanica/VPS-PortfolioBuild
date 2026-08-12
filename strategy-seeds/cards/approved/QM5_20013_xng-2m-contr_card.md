---
copy_of: strategy-seeds/cards/xng-2m-contr_card.md
strategy_id: MISHRA-SMYTH-XNG-2M-2016_S01
source_id: MISHRA-SMYTH-XNG-PRED-2016
ea_id: QM5_20013
slug: xng-2m-contr
status: APPROVED
g0_status: APPROVED
created: 2026-07-20
created_by: Research
last_updated: 2026-07-20
source_citation: "Mishra, V. and Smyth, R. (2016), Are Natural Gas Spot and Futures Prices Predictable?, Economic Modelling 54, 178-186, DOI 10.1016/j.econmod.2015.12.034."
source_citations:
  - type: academic_paper
    citation: "Mishra, V. and Smyth, R. (2016). Are Natural Gas Spot and Futures Prices Predictable? Economic Modelling, 54, 178-186."
    location: "Trading simulation on printed p. 18 and Table 10 on printed p. 34; DOI https://doi.org/10.1016/j.econmod.2015.12.034"
    quality_tier: A
    role: primary
markets: [commodities, energy, natural_gas]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Six fixed bimonthly decisions per complete year; normally six renewed packages, subject to exact equality, missing history, spread, or a prior stop in the same period."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_futures_basis, low_frequency]
---

# Approved Card Copy - QM5_20013_xng-2m-contr

The canonical approved card is
`strategy-seeds/cards/xng-2m-contr_card.md`. Approval covers exactly the
Mishra-Smyth unconditional two-month sign contrarian: compare the most recent
completed month-end close with the completed month-end close two months
earlier, buy after a decline, sell after a rise, and retain the prior position
on exact equality.

The source does not specify a bucket epoch. Approval locks Jan-Feb, Mar-Apr,
May-Jun, Jul-Aug, Sep-Oct and Nov-Dec broker-calendar periods before testing.
It also permits an observable non-equality package renewal, a frozen ATR hard
stop, 70-day stale guard and restart-safe one-package-per-period enforcement as
V5 portability/risk additions.

Approval is limited to one `XNGUSD.DWX` D1 RISK_FIXED backtest carrier. The
paper's zero-cost simulation, spot/futures-to-CFD basis, roll/financing,
realized efficacy and correlation to the certified book remain binding risks.
No live artifact, AutoTrading action, portfolio admission or portfolio-gate
change is approved.

## Hypothesis

Natural-gas prices can mean-revert at a fixed two-month horizon. The source
tests that hypothesis with an unconditional opposite-sign state rather than an
oscillator, magnitude threshold, volatility filter or fitted mean.

## 4. Entry Rules

- `XNGUSD.DWX` D1 only, on the first D1 bar of odd broker months.
- Reconstruct completed month ends `C0,C1,C2` from bounded D1 history.
- `C0 < C2` buys; `C0 > C2` sells; exact equality creates no new order.
- Close the previous package before a non-equality renewal.
- Require valid history/ATR/spread and no current-period entry.
- Initial stop is `4.0 * ATR(20)`; V5 fixed-risk sizing is authoritative.

## 5. Exit Rules

- Renew at each valid non-equality two-month boundary.
- Carry the prior state on exact equality, subject to the V5 stale override.
- Close at 70 calendar days or at the broker hard stop.
- No intraperiod target, trailing stop or break-even move.

## 6. Filters (No-Trade Module)

- Exact XNG/D1/slot-0 and locked-parameter guards.
- Bounded history, valid price/ATR and maximum 3000-point spread.
- Framework kill switch and entry-news policy remain active.

## 7. Trade Management Rules

- One position per magic and one entry package per bimonthly period.
- Deal history prevents restart or post-stop same-period re-entry.
- No stacking, scale-in, grid, martingale, pyramiding, adaptive fit, external
  runtime feed, banned indicator or ML.
- Friday close is disabled for the source's fixed two-month horizon.

## Risk

Q02 uses only `RISK_FIXED=1000`, `RISK_PERCENT=0` and one XNG D1 backtest
setfile. The paper assumes zero costs and does not establish this CFD carrier's
risk-adjusted returns, drawdown or book orthogonality. No live or portfolio
mutation is authorized.

## Pipeline Status

- Q01 PASS on 2026-07-20: strict compile 0 errors/0 warnings; build check 0
  failures/0 warnings.
- Q02 pending and unclaimed: work item
  `5b880ae3-30d8-47ea-9708-dd21a699933d` for `XNGUSD.DWX` D1.
- Evidence:
  `docs/ops/evidence/2026-07-20_qm5_20013_xng_2m_contr_q02_enqueue.md`.
