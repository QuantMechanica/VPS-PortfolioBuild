# QM5_9697_ff-thv-trix-coral-m5 - Strategy Spec

**EA ID:** QM5_9697
**Slug:** ff-thv-trix-coral-m5
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades completed M5 bars from the ForexFactory THV system. A long signal requires the close above the Coral trend line, the Ichimoku-style cloud either above Coral or price above both cloud boundaries, a fast TRIX cross above slow TRIX, both TRIX slopes rising, and no opposite short signal in the prior three closed bars. Shorts mirror the same conditions below Coral and the cloud. Exits occur on an opposite TRIX cross, a close crossing back through Coral, the 1.5R target, stop loss, Friday close, or a 24-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_trix_period | 9 | >=2 | Fast triple-EMA TRIX period. |
| strategy_slow_trix_period | 13 | >=2 | Slow triple-EMA TRIX period. |
| strategy_trix_warmup_bars | 220 | 80-400 enforced | Closed-bar history used to warm up TRIX and Coral state. |
| strategy_coral_period | 60 | >=2 | Coral T3-style trend-line smoothing period. |
| strategy_coral_coeff | 0.40 | 0.00-1.00 | Coral T3-style coefficient. |
| strategy_ichi_tenkan | 9 | >=1 | Tenkan period for the THV cloud boundary proxy. |
| strategy_ichi_kijun | 26 | >=1 | Kijun period and cloud displacement. |
| strategy_ichi_senkou | 52 | >=1 | Senkou Span B period. |
| strategy_no_opposite_bars | 3 | >=0 | Number of prior bars that must be free of the opposite signal. |
| strategy_swing_lookback_bars | 8 | >=1 | Local swing window used for structure stop placement. |
| strategy_atr_period | 14 | >=1 | ATR period for spread filter and volatility stop distance. |
| strategy_atr_sl_mult | 1.10 | >0 | ATR multiple used for the volatility stop. |
| strategy_tp_rr | 1.50 | >0 | Take-profit multiple of initial risk. |
| strategy_time_stop_bars | 24 | >0 | Maximum holding time in M5 bars. |
| strategy_session_start_hour | 7 | 0-23 | Broker-hour start of London plus early New York trading window. |
| strategy_session_end_hour | 17 | 0-23 | Broker-hour end of London plus early New York trading window. |
| strategy_max_spread_atr_pct | 20.0 | >0 | Blocks new entries when spread exceeds this percent of ATR(14,M5). |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX major for THV M5 scalping.
- GBPUSD.DWX - card-listed liquid FX major for THV M5 scalping.
- AUDUSD.DWX - card-listed liquid FX major for THV M5 scalping.
- XAUUSD.DWX - card-listed liquid metal symbol included in the approved P2 basket.

**Explicitly NOT for:**
- SP500.DWX - not part of the approved ForexFactory THV FX/metals card basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_M5) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 95 |
| Typical hold time | Intraday, capped at 24 M5 bars or about 2 hours |
| Expected drawdown profile | Scalping trend-confirmation drawdowns should cluster during choppy sessions and high-spread periods |
| Regime preference | M5 session trend and momentum continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/127271-thv-system-final-edition
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9697_ff-thv-trix-coral-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | 7508912c-9a46-4225-9198-78aa6234579e |
