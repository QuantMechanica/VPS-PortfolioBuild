# QM5_11169_weiss-ichi3-ma - Strategy Spec

**EA ID:** QM5_11169
**Slug:** weiss-ichi3-ma
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6 (see `strategy-seeds/sources/3005c768-aa91-5daf-9dd7-500d7bfcb7a6/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It enters long when SMA(9) is above SMA(26), SMA(26) is above SMA(52), and both SMA(26) and SMA(52) slope upward versus the prior completed bar. It enters short when the same stack is inverted and both slower averages slope downward. Long positions close when SMA(9) drops below SMA(26) or SMA(26) drops below SMA(52); short positions close when SMA(9) rises above SMA(26) or SMA(26) rises above SMA(52). The only protective stop is a catastrophic stop at the greater of 3 x ATR(20,D1) and the broker minimum stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 9 | 1+ and less than mid period | Fast simple moving average period. |
| `strategy_mid_sma_period` | 26 | Greater than fast and less than slow period | Middle simple moving average period and slope filter. |
| `strategy_slow_sma_period` | 52 | Greater than mid period | Slow simple moving average period and slope filter. |
| `strategy_atr_period` | 20 | 1+ | ATR period for the catastrophic protective stop. |
| `strategy_atr_sl_mult` | 3.0 | Greater than 0 | ATR multiplier for the catastrophic protective stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid forex major with D1 OHLC data.
- `USDJPY.DWX` - Card-listed liquid forex major with D1 OHLC data.
- `XAUUSD.DWX` - Card-listed gold market with D1 OHLC data.
- `XTIUSD.DWX` - Card-listed crude oil market with D1 OHLC data.
- `SP500.DWX` - Card-listed S&P 500 custom symbol; valid for backtest registration with T6 live-routing caveat.

**Explicitly NOT for:**
- Non-DWX symbols - The V5 pipeline requires registered `.DWX` instruments for research and backtest artifacts.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 7 |
| Typical hold time | Several days to multiple weeks, until the SMA stack breaks. |
| Expected drawdown profile | Trend-following drawdowns during sideways or choppy markets. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Wiley, 2005, Chapter 3, pp. 54-55, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11169_weiss-ichi3-ma.md`

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
| v1 | 2026-06-07 | Initial build from card | 10cb21a9-4a62-49a8-bffa-0522935a1a20 |
