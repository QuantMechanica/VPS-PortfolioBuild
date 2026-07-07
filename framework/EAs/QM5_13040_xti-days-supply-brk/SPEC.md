# QM5_13040_xti-days-supply-brk - Strategy Spec

**EA ID:** QM5_13040
**Slug:** `xti-days-supply-brk`
**Source:** `EIA-XTI-DAYS-SUPPLY-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI days-of-supply tight-cover breakout on
`XTIUSD.DWX`. It uses the official EIA crude-oil days-of-supply series and
WPSR pages only as source lineage. Runtime uses Darwinex D1 OHLC, ATR, SMA,
spread, and broker calendar state only.

On each new D1 bar the EA inspects the previous completed bar. The bar must be
Wednesday or Thursday in broker time, must be bullish, must close near the top
of its range, must break the prior Donchian high, must sit in the upper part of
the 126-D1 close channel, must reclaim from a short pullback, and must close
above a rising `SMA(50)`. A monthly latch allows only one new entry per
broker-calendar month.

Positions use ATR hard stop, ATR target, max-hold exit, SMA trend-failure exit,
standard V5 news and Friday close handling, and no external runtime data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_report_start_dow` | 3 | fixed | First broker day-of-week for WPSR proxy window |
| `strategy_report_end_dow` | 4 | fixed | Last broker day-of-week for WPSR proxy window |
| `strategy_breakout_lookback` | 55 | 34-84 | Donchian high lookback excluding signal bar |
| `strategy_anchor_lookback` | 126 | 84-189 | Close-channel lookback for tight-cover price proxy |
| `strategy_pullback_lookback` | 5 | 3-8 | Pre-signal pullback reclaim window |
| `strategy_min_pullback_atr` | 0.40 | 0.25-0.65 | Minimum reclaim from pullback low in ATR units |
| `strategy_min_anchor_position` | 0.70 | 0.60-0.80 | Minimum close-channel position |
| `strategy_sma_period` | 50 | 34-84 | D1 trend filter period |
| `strategy_sma_slope_shift` | 10 | 5-15 | Completed D1 bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.55 | 0.40-0.80 | Minimum signal-bar range in ATR units |
| `strategy_min_close_location` | 0.60 | 0.55-0.70 | Minimum close location within signal-bar range |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.50 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.25 | 2.50-4.25 | ATR target distance |
| `strategy_max_hold_days` | 12 | 8-18 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Direction: long only.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA trend failure,
  and max-hold guard.
- Regime preference: WTI tight-stock-cover continuation proxy during weekly
  petroleum information windows.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration crude-oil days-of-supply and weekly
petroleum data pages:

- https://www.eia.gov/dnav/pet/PET_SUM_SNDW_A_EPC0_VSD_DAYS_W.htm
- https://www.eia.gov/petroleum/supply/weekly/

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
