# QM5_12761_eia-xng-stor-idbrk - Strategy Spec

**EA ID:** QM5_12761
**Slug:** `eia-xng-stor-idbrk`
**Source:** `EIA-XNG-STOR-IDBRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. It uses the EIA Weekly Natural Gas Storage Report only as a
recurring official event structure. On each new D1 bar it checks whether the
prior two completed bars formed a likely storage-report event bar followed by
an inside compression bar. If so, the EA caches that setup range and enters
only if live price breaks above or below the cached range with SMA
confirmation.

This is not a duplicate of existing XNG builds. `QM5_12584` follows large
storage-report reaction bars, `QM5_12744` fades stretched storage-report bars,
`QM5_12725` trades pre-storage positioning, and the other XNG EIA sleeves are
seasonality/weather/storage-season windows. This EA waits for post-event range
compression and trades the following breakout.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for event-size filter and hard stop |
| `strategy_trend_period` | 50 | 40-63 | D1 SMA trend confirmation and exit |
| `strategy_min_event_range_atr` | 0.90 | 0.75-1.10 | Minimum storage event-bar range in ATRs |
| `strategy_inside_max_range_ratio` | 0.70 | 0.60-0.80 | Max setup range relative to event range |
| `strategy_setup_max_atr` | 0.85 | 0.70-1.00 | Max setup range relative to ATR |
| `strategy_break_buffer_points` | 30 | 20-50 | Breakout buffer beyond setup high/low |
| `strategy_atr_sl_mult` | 3.00 | 2.5-3.5 | Stop distance multiplier |
| `strategy_max_hold_days` | 3 | 2-5 | Calendar-day time exit |
| `strategy_setup_valid_days` | 3 | 2-4 | Cached setup expiry |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: setup formation is `QM_IsNewBar()` gated. Live breakout checks
  use cached D1 levels and current bid/ask only.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-12.
- Typical hold: one to three calendar days, segmented by Friday close.
- Regime preference: natural-gas storage-week compression followed by short
  range expansion.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Natural Gas Storage Report",
URL https://www.eia.gov/naturalgas/storage/. Supplemental release schedule:
https://www.eia.gov/naturalgas/schedule/. Sources are used only for structural
lineage; the EA uses Darwinex MT5 OHLC at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate is
touched by this build.
