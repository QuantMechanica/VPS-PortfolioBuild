---
ea_id: QM5_12775
slug: wti-wed-prem
type: strategy
source_id: MEEK-HOELSCHER-WTI-DOW-2023
source_citation: "Meek, H. and Hoelscher, S. A. Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2023. DOI https://doi.org/10.1080/23322039.2023.2213876; open pointer https://www.econstor.eu/handle/10419/304091"
source_citations:
  - type: peer_reviewed_article
    citation: "Meek, H. and Hoelscher, S. A. Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2023."
    location: "https://doi.org/10.1080/23322039.2023.2213876"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MEEK-HOELSCHER-WTI-DOW-2023]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/wednesday-calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12775_XTI_WED_PREM_D1
period: D1
expected_trade_frequency: "Weekly D1 WTI Wednesday-calendar premium sleeve; estimate 45-52 trades/year after broker holidays and framework filters."
expected_trades_per_year_per_symbol: 48
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-29
expected_pf: 1.08
expected_dd_pct: 17.0
g0_approval_reasoning: "R1 PASS peer-reviewed petroleum day-of-week source; R2 PASS deterministic Wednesday D1 long/next-bar flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# WTI Wednesday Calendar Premium

## Source

- Source: [[sources/MEEK-HOELSCHER-WTI-DOW-2023]]
- Primary citation: Meek, H. and Hoelscher, S. A., "Day-of-the-week effect:
  Petroleum and petroleum products", Cogent Economics and Finance 11(1), 2023,
  DOI https://doi.org/10.1080/23322039.2023.2213876.
- Open repository pointer: https://www.econstor.eu/handle/10419/304091.

## Concept

The peer-reviewed source studies weekday structure across petroleum markets and
documents day-of-week effects in WTI and related petroleum products. This card
isolates an unbuilt mid-week expression for the QM energy sleeve: buy
`XTIUSD.DWX` only on the broker-calendar Wednesday D1 bar and flatten on the
first subsequent D1 bar.

This is deliberately different from:

- `QM5_12596_wti-mon-fade` and `QM5_12610_wti-tue-fade`: short weekday fades,
  not Wednesday long exposure.
- `QM5_12771_wti-thu-prem`: Thursday premium from a separate crude-oil
  seasonality source.
- `QM5_12597_wti-fri-prem` and `QM5_12753_wti-thu-pb-fri-bounce`: Friday
  exposure and a conditional Thursday-pullback setup, not Wednesday.
- WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, CAD/oil, XTI/XNG,
  oil/gold, oil/silver, month-of-year, driving-season, distillate, and
  medium-term momentum/reversal WTI sleeves already in the registry.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, short-horizon pullback,
  ML, grid, or martingale logic.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 45-52 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, broker calendar, broker spread, and ATR
  only. No futures curve, inventory feed, EIA feed, CFTC data, CSV, API,
  analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be Wednesday, using MQL5
  `day_of_week == 3`.
- Entry direction is long only: BUY `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar whose broker-calendar day is not
  Wednesday.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when ATR or broker-calendar state is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_dow
  default: 3
  sweep_range: [3]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used for structural lineage around petroleum day-of-week effects.
No source performance number is imported into QM. The Q02+ pipeline must test
the deterministic Wednesday-long realization on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 17
- expected_trade_frequency: approximately 45-52 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed petroleum DOW article with DOI and
  repository pointer; exactly one `source_id`.
- [x] R2 mechanical: fixed broker-calendar Wednesday, single D1 long entry,
  ATR stop, and next-bar/time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  and one position per magic.
- [x] Non-duplicate: Wednesday long premium is not the existing Monday/Tuesday
  fade, Thursday premium, Friday premium, Thursday-pullback/Friday-bounce,
  WTI event/roll/month/season/trend/reversal, XNG, XAU/XAG, ratio-basket, or
  RSI commodity sleeve.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: Wednesday broker-calendar D1 long entry.
- trade_management: non-Wednesday stale exit and max-hold guard.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural WTI Wednesday calendar-premium card | G0 | APPROVED |
| v1-q02 | 2026-06-29 | strict build PASS and paced-fleet Q02 enqueued | Q02 | PENDING c4736fdd-e17b-4cc2-9cb5-5de45c3ae1fb |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
| Q02 Baseline Screening | 2026-06-29 | QUEUED | work_items/c4736fdd-e17b-4cc2-9cb5-5de45c3ae1fb |
