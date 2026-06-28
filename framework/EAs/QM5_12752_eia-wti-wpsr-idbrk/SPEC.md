# QM5_12752_eia-wti-wpsr-idbrk - Strategy Spec

**EA ID:** QM5_12752
**Slug:** `eia-wti-wpsr-idbrk`
**Source:** `EIA-WTI-WPSR-IDBRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`. It
uses the EIA Weekly Petroleum Status Report only as a recurring calendar
structure. On each new D1 bar it checks whether the prior two completed bars
formed a WPSR event bar followed by an inside consolidation bar. If so, the EA
caches that inside-bar range and enters only if live price breaks above or
below that cached range during the next D1 bar.

This is not a duplicate of the existing WPSR builds: `QM5_12592` trades before
the report, `QM5_12579` follows the event-day reaction immediately, and
`QM5_12590` fades event-day exhaustion. This build waits for a post-event
inside bar and trades the following breakout.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for event-size filter and hard stop |
| `strategy_trend_period` | 50 | 34-84 | D1 SMA trend confirmation and exit |
| `strategy_min_event_range_atr` | 1.00 | 0.80-1.25 | Minimum WPSR event-bar range in ATRs |
| `strategy_inside_max_range_ratio` | 0.75 | 0.60-0.90 | Max setup range relative to event range |
| `strategy_setup_max_atr` | 0.90 | 0.70-1.10 | Max setup range relative to ATR |
| `strategy_break_buffer_points` | 20 | 10-40 | Breakout buffer beyond setup high/low |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | Stop distance multiplier |
| `strategy_max_hold_days` | 3 | 2-5 | Calendar-day time exit |
| `strategy_setup_valid_days` | 3 | 1-3 | Cached setup expiry |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: setup formation is `QM_IsNewBar()` gated. Live breakout checks
  use cached D1 levels and current bid/ask only.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-14.
- Typical hold: one to three calendar days, segmented by Friday close.
- Regime preference: WTI post-inventory-event consolidation followed by
  short-term range expansion.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Petroleum Status Report", URL
https://www.eia.gov/petroleum/supply/weekly/. Supplemental release schedule:
https://www.eia.gov/petroleum/supply/weekly/schedule.php. Sources are used only
for structural lineage; the EA uses Darwinex MT5 OHLC at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate is
touched by this build.
