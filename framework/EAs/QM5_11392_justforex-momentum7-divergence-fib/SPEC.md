# QM5_11392_justforex-momentum7-divergence-fib - Strategy Spec

**EA ID:** QM5_11392
**Slug:** `justforex-momentum7-divergence-fib`
**Source:** `9909fee4-3d9d-56ad-b4cf-cea631d7873e` (see `sources/dropbox-forex-pdf-archive`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades H4 momentum divergence on FX symbols. A long setup requires two confirmed N-bar swing lows where price makes a lower low and Momentum(7) makes a higher low; entry occurs when Momentum(7) breaks above the highest Momentum value between those lows, with RSI(7) above 20 when the RSI filter is enabled. A short setup mirrors this logic on swing highs, requiring price to make a higher high, Momentum(7) to make a lower high, and Momentum(7) to break below the trough between the highs while RSI(7) is below 80. Stops are placed 5 pips beyond the newer swing extreme and capped at 40 pips; TP1 is the 161.8% Fibonacci extension, half the position is closed at TP1, and the remainder trails using the second-to-last bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_mom_period` | 7 | 5-10 planned P3 sweep | Momentum period used for divergence and pivot break. |
| `strategy_rsi_period` | 7 | 7 fixed in card | RSI confirmation period. |
| `strategy_use_rsi_filter` | true | true/false | Enables the optional RSI confirmation filter from the card. |
| `strategy_rsi_long_floor` | 20.0 | 0-100 | Long entries require RSI above this level. |
| `strategy_rsi_short_ceil` | 80.0 | 0-100 | Short entries require RSI below this level. |
| `strategy_fractal_n` | 3 | 2-3 planned P3 sweep | N-bar fractal half-width for swing detection. |
| `strategy_pivot_lookback` | 60 | 20-120 | Maximum closed-bar window for finding the last two swings. |
| `strategy_fib_tp_ext` | 1.618 | 0.618-3.236 | Final broker TP extension multiple, implemented as TP2. |
| `strategy_sl_buffer_pips` | 5 | 1-20 | Stop-loss padding beyond the most recent swing extreme. |
| `strategy_sl_cap_pips` | 40 | 1-80 | Maximum H4 stop distance for P2. |
| `strategy_spread_pct_of_stop` | 25.0 | 0-100 | Blocks only genuinely wide spreads relative to capped stop distance. |
| `strategy_partial_pct_tp1` | 50.0 | 1-99 | Percentage of position to close at TP1. |
| `strategy_trail_buffer_pips` | 10 | 1-40 | Buffer beyond the second-to-last bar for post-TP1 trailing. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed H4 FX major with available DWX history.
- `GBPUSD.DWX` - card-listed H4 FX major with available DWX history.
- `USDJPY.DWX` - card-listed H4 FX major with available DWX history.

**Explicitly NOT for:**
- `SP500.DWX` - index market, not part of the card's FX divergence basket.
- `NDX.DWX` - index market, not part of the card's FX divergence basket.
- `WS30.DWX` - index market, not part of the card's FX divergence basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` in this build; card notes D1 only as a P3 variant |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | `not specified in card; expected to span multiple H4 bars until Fib target, trailing stop, or structural stop` |
| Expected drawdown profile | `not specified in card; swing-stop risk capped at 40 pips for H4 P2` |
| Regime preference | `momentum divergence reversal after exhaustion swing` |
| Win rate target (qualitative) | `not specified in card` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9909fee4-3d9d-56ad-b4cf-cea631d7873e`
**Source type:** `local PDF archive`
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\pdfcoffee.com_forex-momentum-strategy-pdf-free.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11392_justforex-momentum7-divergence-fib.md`

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
| v1 | 2026-06-26 | Initial build from card | 30b8b3da-42f6-4c31-ba2e-d0fa8eb360cb |
