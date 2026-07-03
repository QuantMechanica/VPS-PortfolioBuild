# QM5_12994_iea-omr-fade - Strategy Spec

**EA ID:** QM5_12994
**Slug:** `iea-omr-fade`
**Source:** `IEA-OMR-XTI-FADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency WTI monthly information-window sleeve on
`XTIUSD.DWX`. On each new D1 bar it inspects the previous completed D1 bar and
checks whether that bar is inside the IEA Oil Market Report proxy window
between broker-calendar days 10 and 18 of the month.

If that proxy-window bar is an ATR-sized directional shock and closes near its
extreme, the EA fades the move on the next D1 bar. Up shocks are sold; down
shocks are bought. Positions use ATR hard stop, ATR target, max-hold exit,
standard V5 news and Friday close, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_start_day` | 10 | 9-11 | First broker-calendar day eligible for the OMR proxy window |
| `strategy_event_end_day` | 18 | 16-20 | Last broker-calendar day eligible for the OMR proxy window |
| `strategy_atr_period` | 20 | 14-30 | ATR period for event sizing and stop/target |
| `strategy_min_range_atr` | 1.10 | 0.90-1.30 | Minimum event-bar high-low range in ATR units |
| `strategy_min_body_atr` | 0.35 | 0.25-0.50 | Minimum absolute event-bar body in ATR units |
| `strategy_close_location_extreme` | 0.75 | 0.70-0.80 | Close-location threshold for shock exhaustion |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR stop distance |
| `strategy_atr_tp_mult` | 1.5 | 1.0-2.0 | ATR target distance |
| `strategy_max_hold_days` | 4 | 3-6 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-10.
- Typical hold: several D1 bars, capped by stale-position guard.
- Regime preference: mid-month oil-market report shock overreaction.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

International Energy Agency, Oil Market Report (OMR) data product and monthly
analysis pages.

- https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr
- https://www.iea.org/reports/oil-market-report-june-2026

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
