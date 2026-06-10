# QM5_9411_mql5-paq-pinbar — Strategy Spec

**EA ID:** QM5_9411
**Slug:** `mql5-paq-pinbar`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed H1 bar the EA computes the candle body, upper wick, and lower wick. A bullish pin bar is detected when the lower wick exceeds the body by a configurable ratio and the upper wick is less than half the body; a bearish pin bar mirrors this with the upper wick. A context filter requires that the pin-bar low is below the prior 10-bar low or the close is below EMA(20) for a buy; the sell mirror applies above. Entries fire at market on the next tick, with a stop loss placed below the pin-bar low (buy) or above the pin-bar high (sell) offset by 0.25 × ATR(14). Take profit is set at 2R. Positions are closed on a 24-bar time stop, on a subsequent bar closing through EMA(20) against the trade, or on an opposite pin bar signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wick_body_ratio` | 2.0 | 1.0–5.0 | Minimum wick-to-body ratio for pin bar detection |
| `strategy_min_body_pts` | 5 | 1–50 | Minimum candle body in broker points |
| `strategy_atr_period` | 14 | 5–50 | ATR period for stop offset |
| `strategy_sl_atr_mult` | 0.25 | 0.1–1.0 | SL offset as multiple of ATR(14) beyond pin-bar extreme |
| `strategy_tp_rr_mult` | 2.0 | 1.0–5.0 | Take-profit as multiple of risk distance (R) |
| `strategy_context_lookback` | 10 | 5–30 | Prior bars used to derive context high/low |
| `strategy_ema_period` | 20 | 10–50 | EMA period for context filter and exit |
| `strategy_max_hold_bars` | 24 | 6–72 | Maximum hold in bars (1 H1 bar = 1 hour) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — high-liquidity FX pair; pin-bar reversals well-studied on H1
- `GBPUSD.DWX` — volatile GBP pair with frequent wick rejections at key levels
- `USDJPY.DWX` — safe-haven FX pair; large wick rejections at pivots common
- `XAUUSD.DWX` — gold; sharp intraday reversals from ATR-scaled stops work well

**Explicitly NOT for:**
- Index CFDs (NDX, WS30) — card targets FX + gold only; index behaviour not validated

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~50 |
| Typical hold time | 1–24 hours |
| Expected drawdown profile | Moderate drawdown with fixed 2R target capping wins |
| Regime preference | Mean-revert / reversal at structural extremes |
| Win rate target (qualitative) | Low-medium (positive EV from 2R target) |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 24): Price Action Quantification Analysis Tool", MQL5 Articles, 2025-05-22, https://www.mql5.com/en/articles/18207
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9411_mql5-paq-pinbar.md`

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
| v1 | 2026-06-10 | Initial build from card | 9361f306-1edc-4d37-8625-ecfa9f66dfa3 |
