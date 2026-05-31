# QM5_10538_mql5-morse - Strategy Spec

**EA ID:** QM5_10538
**Slug:** `mql5-morse`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates closed H1 candles and converts each candle into a binary digit: bullish candles are `1`, bearish candles are `0`, and doji candles are ignored by producing no signal. When the most recent 3 to 5 closed candles match the selected pattern string, the EA opens one position for this symbol and magic. The default variant continues in the direction of the final matched candle; the exposed reversal input trades against that final candle for the card's exhaustion variant. Each trade uses an ATR(14) stop, a 1.5R take profit, and a time stop after 8 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pattern` | `1110` | binary string length 3-5 | Closed-candle bullish/bearish sequence to match before entry. |
| `strategy_reversal_mode` | `false` | `false`/`true` | `false` continues with the final candle direction; `true` reverses against it. |
| `strategy_atr_period` | `14` | `1+` | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | `1.50` | `>0` | ATR multiple for stop-loss distance. |
| `strategy_tp_rr` | `1.50` | `>0` | Take-profit reward/risk multiple. |
| `strategy_time_stop_bars` | `8` | `0+` | Number of H1 bars after which an open trade is closed; `0` disables the time stop. |
| `strategy_max_spread_points` | `0` | `0+` | Optional spread ceiling in points; `0` disables the strategy-level spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major FX pair with OHLC and ATR data for the candle pattern.
- `GBPUSD.DWX` - Major FX pair with OHLC and ATR data for the candle pattern.
- `USDJPY.DWX` - Major FX pair with OHLC and ATR data for the candle pattern.
- `XAUUSD.DWX` - Liquid metal symbol with OHLC and ATR data for the candle pattern.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - The build only registers the card's R3 DWX-testable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | `up to 8 H1 bars` |
| Expected drawdown profile | Fixed ATR-risk trades with one active position per symbol and no averaging. |
| Regime preference | Candlestick pattern continuation or reversal after short bullish/bearish sequences. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/18066`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10538_mql5-morse.md`

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
| v1 | 2026-05-29 | Initial build from card | 4d6f3258-4089-42d6-8246-b01398be44a1 |
