# QM5_10962_ftmo-ichi-fib - Strategy Spec

**EA ID:** QM5_10962
**Slug:** ftmo-ichi-fib
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA evaluates the main trend on closed D1 bars and enters from closed H1 bars. It buys when the last D1 impulse is a qualifying swing-low to swing-high move above the D1 Ichimoku cloud, the closed H1 price has pulled back into the 38.2 percent to 61.8 percent Fibonacci retracement zone, H1 price is back above the H1 cloud, and RSI(14) is in the card's long pullback band or has crossed up through 30. It sells the mirrored setup below the clouds after a qualifying swing-high to swing-low impulse. Each trade uses the card's cloud or retracement swing stop with an ATR buffer, a 2.0R target unless the 161.8 percent D1 expansion is a valid closer extension target, RSI early exit, and a 72 H1-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period for impulse, cloud thickness, and stop-distance filters. |
| strategy_ichimoku_tenkan | 9 | 1-100 | Tenkan lookback used for the Ichimoku cloud calculation. |
| strategy_ichimoku_kijun | 26 | 1-200 | Kijun lookback used for the Ichimoku cloud calculation. |
| strategy_ichimoku_senkou_b | 52 | 1-300 | Senkou B lookback used for the Ichimoku cloud calculation. |
| strategy_d1_swing_bars | 20 | 1-60 | Radius used to identify D1 swing highs and lows. |
| strategy_d1_search_bars | 100 | 30-300 | Recent D1 bars searched for the latest qualifying impulse. |
| strategy_retrace_swing_h1_bars | 20 | 1-100 | H1 bars used for the retracement swing stop. |
| strategy_min_impulse_atr_mult | 2.0 | 0.1-10.0 | Minimum D1 impulse size in ATR(14,D1) multiples. |
| strategy_min_cloud_atr_mult | 0.5 | 0.1-5.0 | Minimum D1 cloud thickness in ATR(14,D1) multiples. |
| strategy_fib_retrace_min | 0.382 | 0.0-1.0 | Shallow Fibonacci retracement boundary. |
| strategy_fib_retrace_max | 0.618 | 0.0-1.0 | Deep Fibonacci retracement boundary. |
| strategy_rsi_period | 14 | 2-100 | RSI period on H1 closes. |
| strategy_rsi_long_min | 30.0 | 1-50 | Long-side RSI cross and lower band threshold. |
| strategy_rsi_long_max | 50.0 | 30-70 | Long-side RSI upper pullback-band threshold. |
| strategy_rsi_short_min | 50.0 | 30-70 | Short-side RSI lower pullback-band threshold. |
| strategy_rsi_short_max | 70.0 | 50-99 | Short-side RSI cross and upper band threshold. |
| strategy_rsi_cross_lookback_bars | 3 | 1-10 | H1 bars checked for recent RSI threshold crosses. |
| strategy_sl_atr_buffer_mult | 0.25 | 0.0-5.0 | ATR(14,H1) buffer added beyond the structural/cloud stop. |
| strategy_min_stop_atr_h1_mult | 0.5 | 0.1-10.0 | Minimum planned stop distance in ATR(14,H1) multiples. |
| strategy_max_stop_atr_d1_mult | 2.5 | 0.1-20.0 | Maximum planned stop distance in ATR(14,D1) multiples. |
| strategy_take_profit_r | 2.0 | 0.5-10.0 | Primary take profit in initial-risk multiples. |
| strategy_extension_level | 1.618 | 1.0-5.0 | D1 impulse expansion target level. |
| strategy_extension_max_r | 3.5 | 2.0-10.0 | Maximum extension target distance in initial-risk multiples. |
| strategy_time_exit_h1_bars | 72 | 1-500 | Maximum holding period measured in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURJPY.DWX - liquid JPY cross in the card's R3 P2 basket.
- EURUSD.DWX - liquid major FX pair in the card's R3 P2 basket.
- GBPJPY.DWX - liquid JPY cross in the card's R3 P2 basket.
- XAUUSD.DWX - liquid metal symbol in the card's R3 P2 basket.

**Explicitly NOT for:**
- SP500.DWX - not in this card's FX/metals basket.
- NDX.DWX - not in this card's FX/metals basket.
- WS30.DWX - not in this card's FX/metals basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 impulse, D1 Ichimoku cloud, D1 ATR; H1 Ichimoku cloud, H1 RSI, H1 ATR |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~6 (low-freq swing; revised down from 30 over-claim 2026-06-16) |
| Typical hold time | Up to 72 H1 bars, with earlier SL/TP or RSI exits |
| Expected drawdown profile | Fixed $1,000 backtest risk per trade with structural/cloud stops |
| Regime preference | D1 trend continuation with H1 pullback confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO blog article
**Pointer:** https://ftmo.com/en/blog/top-down-analysis-using-ichimoku-rsi-and-fibonacci/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10962_ftmo-ichi-fib.md`

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
| v1 | 2026-06-06 | Initial build from card | 5577cb04-4334-4047-9239-70259681349a |
