# QM5_12997_xng-rig-fri-mom - Strategy Spec

**EA ID:** QM5_12997
**Slug:** `xng-rig-fri-mom`
**Source:** `BAKERHUGHES-RIGCOUNT-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency Baker Hughes rig-count release-cadence
momentum sleeve on `XNGUSD.DWX`. On the first new D1 bar of a broker week it
inspects the previous completed D1 bar. If that prior bar was a large final
workday displacement, sized by percent return and ATR, and it closed near the
directional extreme, the EA follows next-bar continuation in the same
direction.

The implementation uses no external runtime data. Baker Hughes supplies the
reputable weekly event cadence and natural-gas drilling-activity scope; MT5
D1 OHLC supplies the deterministic market-response proxy.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_signal_return_pct` | 1.20 | 0.90-1.60 | Minimum absolute final-workday log return in percent |
| `strategy_min_atr_return_mult` | 0.50 | 0.40-0.70 | Minimum absolute return relative to ATR percent |
| `strategy_max_signal_return_pct` | 12.0 | 9.0-16.0 | Maximum accepted absolute signal return |
| `strategy_close_location_min` | 0.62 | 0.58-0.70 | Required close location toward the signal-bar extreme |
| `strategy_signal_min_dow` | 4 | 4-5 | Earliest broker DOW accepted for the final-workday proxy |
| `strategy_atr_period` | 20 | 14-30 | ATR period for sizing and stop distance |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.25 | ATR stop distance |
| `strategy_max_hold_days` | 3 | 2-5 | Calendar-day stale-position exit |
| `strategy_adverse_close_atr_mult` | 0.85 | 0.60-1.10 | Adverse completed-close exit threshold |
| `strategy_max_spread_points` | 2500 | 1500-4000 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-16.
- Typical hold: several D1 bars, capped by stale-position and adverse-close
  guards.
- Regime preference: weekly natural-gas drilling-activity release cadence with
  strong final-workday directional response.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Baker Hughes North America Rig Count and Rig Count FAQ:

- https://rigcount.bakerhughes.com/
- https://bakerhughesrigcount.gcs-web.com/rig-count-faqs

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
