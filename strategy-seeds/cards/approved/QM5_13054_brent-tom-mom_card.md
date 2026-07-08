---
ea_id: QM5_13054
slug: brent-tom-mom
type: strategy
strategy_id: VANHEMERT-MOMTOM-2014_XBR
source_id: VANHEMERT-MOMTOM-2014
source_citation: "Van Hemert, Otto. The MOM-TOM Effect: Detecting the Market Impact of CTA Trading. SSRN, 2014; Moskowitz, Ooi and Pedersen, Time Series Momentum, Journal of Financial Economics, 2012."
source_citations:
  - type: working_paper
    citation: "Van Hemert, Otto. The MOM-TOM Effect: Detecting the Market Impact of CTA Trading. SSRN, 2014."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900"
    quality_tier: A-
    role: primary
  - type: journal_article
    citation: "Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen. Time Series Momentum. Journal of Financial Economics, 104(2), 2012."
    location: "https://docs.lhpedersen.com/TimeSeriesMomentum.pdf"
    quality_tier: A
    role: momentum_lineage
  - type: exchange_reference
    citation: "CME Group. Brent Last Day Financial futures product overview."
    location: "https://www.cmegroup.com/markets/energy/crude-oil/brent-last-day-financial.html"
    quality_tier: A
    role: market_context
sources:
  - "[[sources/VANHEMERT-MOMTOM-2014]]"
concepts:
  - "[[concepts/turn-of-month]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/cta-flow-price-pressure]]"
indicators:
  - "[[indicators/momentum-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-anomaly, turn-of-month, time-series-momentum, cta-flow, atr-hard-stop, time-stop, symmetric-long-short, low-frequency, energy]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13054_XBR_TOM_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 Brent turn-of-month momentum package; at most one package per month, approximately 6-12 entries/year after momentum, spread, and framework filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, xbr_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-08: R1 PASS Van Hemert MOM-TOM source plus Moskowitz/Ooi/Pedersen JFE time-series momentum lineage and CME Brent market context; R2 PASS deterministic D1 turn-of-month calendar window, fixed lookback return sign, ATR hard stop/target, window/time exits; R3 PASS XBRUSD.DWX local route used by recent Brent builds, with Q02 validating current history sufficiency; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this is Brent turn-of-month momentum, not WTI TOM, XNG TOM, Brent fixed-month/weekday seasonality, Brent TSMOM, Brent 52-week anchor, Brent/WTI spread, oil-metal ratio, XNG, XAU/XAG, index, or commodity RSI logic."
---

# Brent Turn-Of-Month Momentum

Approved build copy of `strategy-seeds/cards/brent-tom-mom_card.md`.

## hypothesis

Van Hemert's MOM-TOM paper tests whether CTA trend-following flow around the
turn of the month creates temporary price pressure in the direction of existing
momentum. This card ports that structural idea to `XBRUSD.DWX` D1.

## rules

- Host chart: `XBRUSD.DWX` D1.
- Enter only inside the broker-calendar turn-of-month window.
- Trade with the sign of a fixed completed-D1 momentum lookback.
- Exit when the window ends, max-hold expires, Friday close fires, or the ATR
  stop/target is hit.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XBRUSD.DWX` D1
setfile. Live deployment, `T_Live`, AutoTrading, deploy manifests, portfolio
admission, and portfolio-gate edits are out of scope.

## Markets And Timeframe

- Symbol: `XBRUSD.DWX`.
- Period: `D1`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only.

## 4. Entry Rules

- Evaluate only on a new `XBRUSD.DWX` D1 bar.
- Require the active broker date inside the turn-of-month window.
- Enter long when completed-D1 momentum is above the positive threshold.
- Enter short when completed-D1 momentum is below the negative threshold.
- Require no existing `XBRUSD.DWX` position for this EA magic and acceptable
  spread.

## 5. Exit Rules

- ATR hard stop.
- ATR profit target.
- Turn-window exit.
- Max-hold stale-position exit.
- Framework Friday close.

## 6. Filters (No-Trade Module)

- `XBRUSD.DWX` D1 host only.
- Magic slot offset 0 only.
- Valid parameter, history, ATR, price, stop, target, and spread checks.
- No external runtime data, ML, grid, martingale, or pyramiding.

## 7. Trade Management Rules

- One open position per magic/symbol.
- No trailing stop.
- No partial close.
- Strategy management only enforces window and max-hold exits.

## Framework Alignment

- no_trade: XBR/D1 host guard, magic-slot guard, parameter guard, spread cap,
  turn-of-month calendar guard, and valid data checks.
- trade_entry: turn-of-month fixed-lookback D1 momentum direction.
- trade_management: turn-window exit and max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-08 | initial Brent turn-of-month momentum build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | `strategy-seeds/cards/brent-tom-mom_card.md` |
| Q01 Build Validation | 2026-07-08 | PASS | `artifacts/qm5_13054_build_result.json`; `C:/QM/repo/framework/build/compile/20260708_070926/QM5_13054_brent-tom-mom.compile.log`; `D:/QM/reports/framework/21/build_check_20260708_070943.json` |
| Q02 Baseline Screening | 2026-07-08 | QUEUED | `artifacts/qm5_13054_q02_enqueue_20260708.json`; work item `a803f980-7675-46ca-8498-b22d43ed69b4` |
