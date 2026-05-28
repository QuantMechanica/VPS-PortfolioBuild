# QM5_10447_mql5-bbands-rsi - Strategy Spec

**EA ID:** QM5_10447
**Slug:** `mql5-bbands-rsi`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades a Bollinger Band and RSI mean-reversion sequence on EURUSD H1. A long setup exists when RSI is below 30 and price has touched the lower Bollinger Band within the configured search depth, then a closed candle crosses back above the middle Bollinger Band. A short setup mirrors this with RSI above 70, a touch of the upper Bollinger Band, and a closed candle crossing below the middle band. Initial take profit is placed at the opposite outer Bollinger Band, and the stop is placed beyond the recent local high or low with a configured indent.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bands_period` | 20 | 2-200 | Bollinger Band averaging period. |
| `strategy_bands_deviation` | 2.0 | 0.1-5.0 | Standard-deviation multiplier for the Bollinger Bands. |
| `strategy_rsi_period` | 14 | 2-100 | RSI averaging period. |
| `strategy_rsi_oversold` | 30.0 | 1-49 | RSI threshold for long setup. |
| `strategy_rsi_overbought` | 70.0 | 51-99 | RSI threshold for short setup. |
| `strategy_highlow_indent_pips` | 20 | 1-200 | Stop indent beyond the recent local low or high. |
| `strategy_depth_search` | 10 | 1-100 | Number of closed bars searched for the RSI/Bollinger setup. |
| `strategy_max_spread_points` | 30 | 0-500 | Maximum spread in points; 0 disables the strategy spread gate. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the approved card and source optimization example specify EURUSD H1, and the DWX matrix contains this FX symbol.

**Explicitly NOT for:**
- `SP500.DWX` - the card is a EURUSD FX strategy, not an index basket.
- `NDX.DWX` - the card does not authorize cross-asset expansion at build time.

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
| Trades / year / symbol | `70` |
| Typical hold time | `hours` |
| Expected drawdown profile | Mean-reversion drawdowns may cluster when price trends through the outer band. |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/21032` and `artifacts/cards_approved/QM5_10447_mql5-bbands-rsi.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10447_mql5-bbands-rsi.md`

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
| v1 | 2026-05-28 | Initial build from card | 2461a18a-0ab2-4886-9490-a9bcacf01c1e |
