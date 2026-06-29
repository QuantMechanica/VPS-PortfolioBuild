# QM5_12769_eia-xng-lng-brk - Strategy Spec

**EA ID:** QM5_12769
**Slug:** `eia-xng-lng-brk`
**Source:** `EIA-XNG-LNG-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural natural-gas sleeve on
`XNGUSD.DWX`. EIA source material is used only as structural lineage: LNG
exports are a price-relevant demand component for U.S. natural gas, but the EA
does not ingest export data or any external feed at runtime.

On each new D1 bar, the EA checks whether the prior completed D1 bar occurred
in a fixed LNG-demand month bucket and closed above a prior channel high after
range compression. The signal also requires a close above a rising SMA. Entries
are long-only and capped at one per calendar month.

This is not a duplicate of existing XNG builds. It is not `QM5_12567`
cumulative-RSI commodity pullback logic, not an EIA storage report event
strategy, not a freeze/hurricane/weather sleeve, and not a broad monthly
seasonal allocation. The distinguishing rule is LNG-demand-month upside channel
breakout after pre-breakout compression.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for compression, signal-range cap, and hard stop |
| `strategy_trend_period` | 63 | 50-84 | D1 SMA trend confirmation and exit |
| `strategy_sma_slope_shift` | 10 | 5-15 | Bars back for SMA slope confirmation |
| `strategy_breakout_lookback` | 55 | 42-70 | Prior D1 high channel for entry breakout |
| `strategy_exit_channel` | 12 | 8-18 | Prior D1 low channel for exit failure |
| `strategy_compression_lookback` | 20 | 14-30 | Prior bars averaged for compression filter |
| `strategy_compression_atr_mult` | 0.90 | 0.75-1.05 | Max prior average range in ATR units |
| `strategy_break_buffer_points` | 20 | 10-40 | Close breakout buffer beyond channel high |
| `strategy_max_signal_range_atr` | 2.40 | 2.0-3.0 | Max signal-bar range in ATR units |
| `strategy_atr_sl_mult` | 3.25 | 2.75-3.75 | Stop distance multiplier |
| `strategy_max_hold_days` | 18 | 12-28 | Calendar-day time exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: entries are `QM_IsNewBar()` gated. Exits are evaluated on tick
  against the last completed D1 bar plus max-hold time.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-9.
- Typical hold: several days to three weeks, segmented by Friday close.
- Regime preference: structural natural-gas demand months where price breaks
  higher from compressed D1 ranges.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Natural gas explained: factors
affecting natural gas prices",
https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php.
Supplemental EIA Today in Energy LNG/Henry Hub sources:
https://www.eia.gov/todayinenergy/detail.php?id=64004 and
https://www.eia.gov/todayinenergy/detail.php?id=67004. Sources are used only
for structural lineage; the EA uses Darwinex MT5 OHLC at runtime.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate is
touched by this build.
