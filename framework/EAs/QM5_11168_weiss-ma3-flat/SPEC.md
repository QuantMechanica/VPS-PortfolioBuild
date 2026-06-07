# QM5_11168_weiss-ma3-flat — Strategy Spec

**EA ID:** QM5_11168
**Slug:** weiss-ma3-flat
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It enters long when SMA(9) is above SMA(26) and SMA(26) is above SMA(52), and enters short when SMA(9) is below SMA(26) and SMA(26) is below SMA(52). Long positions close when either SMA(9) falls below SMA(26) or SMA(26) falls below SMA(52); short positions close when either SMA(9) rises above SMA(26) or SMA(26) rises above SMA(52). The source has no profit target or fixed stop, so the EA uses only the card-authorized catastrophic protective stop at 3 * ATR(20,D1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_sma_period | 9 | >=1 | Fast completed-bar SMA period. |
| strategy_mid_sma_period | 26 | >=1 | Middle completed-bar SMA period. |
| strategy_slow_sma_period | 52 | >=1 | Slow completed-bar SMA period. |
| strategy_atr_period | 20 | >=1 | D1 ATR period used for the catastrophic protective stop. |
| strategy_atr_sl_mult | 3.0 | >0 | ATR multiplier for the protective stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX — card-listed D1 FX target with DWX OHLC history.
- USDJPY.DWX — card-listed D1 FX target with DWX OHLC history.
- XAUUSD.DWX — card-listed D1 metals target with DWX OHLC history.
- XTIUSD.DWX — card-listed D1 energy target with DWX OHLC history.
- SP500.DWX — card-listed S&P 500 target; valid for backtest-only custom-symbol testing.

**Explicitly NOT for:**
- SPY.DWX — unavailable DWX symbol; SP500.DWX is the canonical available S&P 500 custom symbol.
- SPX500.DWX — unavailable DWX symbol; SP500.DWX is the canonical available S&P 500 custom symbol.
- ES.DWX — unavailable DWX symbol; SP500.DWX is the canonical available S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework closed-bar entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Not explicitly specified in card; hold until D1 SMA stack breaks. |
| Expected drawdown profile | Trend-following drawdowns from whipsaws during flat or choppy markets. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |
| Expected trade frequency | Daily 9/26/52 SMA neutral trend follower; Weissman reports 65-84 trades per asset over 10 years, so use 8 trades/year/symbol conservatively. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis, Wiley, 2005, Chapter 3, pp. 53-54, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11168_weiss-ma3-flat.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-07 | Initial build from card | 30759998-e303-4e70-8cb9-72ce4a16621c |
