# QM5_10993_ftmo-atr-fvg - Strategy Spec

**EA ID:** QM5_10993
**Slug:** `ftmo-atr-fvg`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades M30 volatility expansion breakouts that form a fair value gap. It compares the latest closed bar with a 20-bar ATR-buffered high/low reference channel, requires ATR(14) to be above its prior 50-bar median, and requires price to be on the correct side of EMA(100). After a breakout candle creates a three-bar FVG of at least 0.20 ATR, the EA waits for the first closed-bar pullback into the FVG midpoint while price remains outside the prior range, then enters in the breakout direction. Exits are the broker TP at 2.0R, SL at the farther of 1.5 ATR or the FVG boundary, framework Friday close, or the 32-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_M30` | M30 expected | Signal timeframe from the approved card. |
| `strategy_atr_period` | `14` | 5-50 | ATR period for volatility expansion and stop distance. |
| `strategy_ema_period` | `100` | 20-300 | Trend filter EMA period. |
| `strategy_channel_lookback` | `20` | 5-80 | Prior closed bars used for the ATR reference channel. |
| `strategy_atr_median_bars` | `50` | 5-100 | Prior ATR samples used for the median expansion check. |
| `strategy_channel_atr_buffer` | `0.25` | 0.0-2.0 | ATR buffer added to the channel high and subtracted from the channel low. |
| `strategy_min_fvg_atr_mult` | `0.20` | 0.0-2.0 | Minimum FVG height as a fraction of ATR. |
| `strategy_max_breakout_atr` | `2.50` | 0.5-10.0 | Maximum breakout candle range as a multiple of ATR. |
| `strategy_sl_atr_mult` | `1.50` | 0.5-5.0 | ATR stop multiplier. |
| `strategy_tp_rr` | `2.00` | 0.5-5.0 | Fixed reward-to-risk target. |
| `strategy_time_exit_bars` | `32` | 1-200 | Maximum hold in M30 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with DWX matrix coverage.
- `GBPUSD.DWX` - card-listed liquid FX major with DWX matrix coverage.
- `XAUUSD.DWX` - card-listed gold CFD with DWX matrix coverage.
- `GDAXI.DWX` - verified DWX DAX symbol; used as the canonical matrix equivalent for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- Non-DWX broker aliases - registry and backtest artifacts must use verified `.DWX` symbols only.
- `GER40.DWX` - card-stated alias is not present in the current DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | Up to 32 M30 bars, approximately 16 hours. |
| Expected drawdown profile | Breakout volatility strategy with stop-defined losses and filtered trade frequency. |
| Regime preference | Volatility expansion / breakout. |
| Win rate target (qualitative) | Medium with 2.0R target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** FTMO Academy article
**Pointer:** FTMO Academy, "ATR: Technical Indicator", 2025, https://academy.ftmo.com/lesson/atr-technical-indicator/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10993_ftmo-atr-fvg.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-07 | Initial build from card | a0b15257-b90f-4be8-acf0-be72f9545e50 |
