# QM5_9248_mql5-atr-reversal - Strategy Spec

**EA ID:** QM5_9248
**Slug:** mql5-atr-reversal
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a reversal after an H1 volatility exhaustion move. ATR(14) on the last closed bar must be at least 2.0 times, and no more than 4.0 times, the median ATR(14) over the prior 100 closed bars. It buys after four closed bars form three consecutive lower closes, and sells after four closed bars form three consecutive higher closes. Long positions exit when the last closed bar recovers above SMA(10), short positions exit when the last closed bar falls below SMA(10), or after 18 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 1+ | ATR period used for exhaustion and stop buffer. |
| strategy_atr_median_bars | 100 | 3+ | Closed-bar sample used to compute the median ATR baseline. |
| strategy_atr_min_mult | 2.0 | 0+ | Minimum ATR multiple versus median ATR required for entry. |
| strategy_atr_max_mult | 4.0 | 0+ | Maximum ATR multiple versus median ATR allowed for entry. |
| strategy_signal_bars | 4 | fixed 4 | Four-bar signal window used for the directional close sequence and structure stop. |
| strategy_stop_atr_mult | 0.4 | 0+ | ATR buffer beyond the four-bar signal high or low for the initial stop. |
| strategy_take_rr | 1.8 | 0+ | Initial take profit as a multiple of initial risk. |
| strategy_sma_exit_period | 10 | 1+ | SMA period for mean-reversion exit. |
| strategy_max_hold_bars | 18 | 1+ | Time stop in H1 bars. |
| strategy_adverse_r_exit | 1.2 | 0+ | Hard strategy close if price moves this many initial R against the position. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURCHF.DWX - card-listed DWX forex cross with standard H1 OHLC and ATR data.
- EURUSD.DWX - card-listed DWX major forex pair with standard H1 OHLC and ATR data.
- XAUUSD.DWX - card-listed DWX metal symbol with standard H1 OHLC and ATR data.

**Explicitly NOT for:**
- Other DWX symbols - not listed in the approved card for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 65 |
| Typical hold time | Intraday to 18 H1 bars |
| Expected drawdown profile | Mean-reversion drawdowns during persistent high-volatility trends. |
| Regime preference | Volatility-exhaustion mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 44): Average True Range (ATR) technical indicator", MQL5 Articles, 2024-10-25, https://www.mql5.com/en/articles/16213
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9248_mql5-atr-reversal.md`

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
| v1 | 2026-06-20 | Initial build from card | d5ae976d-7a4a-4ab6-9f50-981e0b5e1a7a |
