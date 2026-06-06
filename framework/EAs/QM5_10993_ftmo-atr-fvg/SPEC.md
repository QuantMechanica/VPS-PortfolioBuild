# QM5_10993_ftmo-atr-fvg — Strategy Spec

**EA ID:** QM5_10993
**Slug:** `ftmo-atr-fvg`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (FTMO Academy, "ATR: Technical Indicator", 2025)
**Author of this spec:** Claude
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades a volatility-expansion breakout that is re-entered on a Fair Value
Gap (FVG) pullback. On each closed M30 bar it requires the trend to agree with
EMA(100): a long needs the prior close above EMA(100), a short needs it below.
Volatility must be expanding — ATR(14) on the signal bar must sit above its
50-bar median. It then builds an ATR-offset channel from the 20 bars before the
recent impulse: `atr_high_ref = highest_high + 0.25*ATR` and
`atr_low_ref = lowest_low - 0.25*ATR`. A breakout is confirmed when a candle in
the last 6 bars closes beyond that reference (above for longs, below for shorts)
and that candle's range does not exceed 2.5*ATR. Within the impulse the EA finds
the most recent three-bar FVG (bullish gap = `low[k] > high[k+2]`, bearish gap =
`high[k] < low[k+2]`) whose height is at least 0.20*ATR. The trade fires on the
first pullback that dips into the gap's midpoint and closes back on the breakout
side of the midpoint (so it does not close back inside the prior range). The stop
is 1.5*ATR from entry, extended to the far FVG boundary when that is farther. The
take-profit is 2.0R. A position also exits when, after reaching +1.5R, a bar
closes back through EMA(20) against the trade, or after 32 bars have elapsed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | PERIOD_M30 | M15-H1 | Base signal timeframe. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for volatility/stop. |
| `strategy_ema_period` | 100 | 20-300 | Trend-filter EMA period. |
| `strategy_atr_median_lookback` | 50 | 10-200 | Bars for the ATR-median expansion test. |
| `strategy_channel_lookback` | 20 | 5-100 | Bars for the prior high/low channel. |
| `strategy_atr_ref_mult` | 0.25 | 0.0-2.0 | ATR offset added to the channel edge. |
| `strategy_breakout_lookback` | 6 | 1-20 | Impulse window scanned for the breakout candle. |
| `strategy_breakout_range_atr_max` | 2.5 | 0.5-5.0 | Reject breakout candle if range > this × ATR. |
| `strategy_fvg_lookback` | 8 | 3-30 | Depth of the FVG scan inside the impulse. |
| `strategy_fvg_min_atr` | 0.20 | 0.0-2.0 | Reject FVG if height < this × ATR. |
| `strategy_sl_atr_mult` | 1.5 | 0.5-5.0 | Stop distance as a multiple of ATR. |
| `strategy_tp_r_multiple` | 2.0 | 0.5-10.0 | Take-profit as a multiple of risk (R). |
| `strategy_runner_ema_period` | 20 | 5-100 | EMA for the runner exit. |
| `strategy_runner_after_r` | 1.5 | 0.0-10.0 | R reached before the runner exit arms. |
| `strategy_time_exit_bars` | 32 | 1-500 | Force-close a trade after this many bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquid FX major with clean ATR-expansion impulses on M30.
- `GBPUSD.DWX` — high-volatility FX major where breakout/FVG retests are frequent.
- `XAUUSD.DWX` — gold; strong volatility-expansion regimes suit the ATR channel.
- `GDAXI.DWX` — DAX 40 index; the card's "GER40" mapped to the matrix symbol GDAXI.DWX.

**Explicitly NOT for:**
- `GER40.DWX` — card-stated alias is not in `dwx_symbol_matrix.csv`; ported to GDAXI.DWX.
- Any non-`.DWX` broker alias — no tick data; registry/backtest use verified `.DWX` only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | `hours (intraday up to the 32-bar M30 cap, ~16h)` |
| Expected drawdown profile | `controlled; 1.5*ATR stop, 2R target, runner + time exits` |
| Regime preference | `volatility-expansion / breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `forum` (FTMO Academy lesson article)
**Pointer:** `https://academy.ftmo.com/lesson/atr-technical-indicator/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10993_ftmo-atr-fvg.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-07 | Initial build from card | a0b15257-b90f-4be8-acf0-be72f9545e50 |
