# QM5_9722_ff-thv-6lights-m1 - Strategy Spec

**EA ID:** QM5_9722
**Slug:** ff-thv-6lights-m1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades completed M1 bars when all six THV lights agree in one direction. The six lights are the fast and slow TRIX histogram signs on M1, M5, and M15; long entries require all six green, both M1 lights green, price above Coral and the Ichimoku cloud, and a rising M5 fast TRIX histogram. Short entries mirror the same rules with red lights, price below Coral/cloud, and falling M5 fast TRIX.

Signals are rejected after the third same-direction six-light signal since the last opposite six-light flip, when the closed M1 bar is abnormally large, when spread exceeds 12 percent of ATR(14), or after the symbol has exceeded 90 percent of ADR(14). Stop loss uses the wider of the recent 10-bar M1 swing and 1.0 ATR(14); take profit is the closer of 1.2R and 10 pips. Exits occur when the trade-direction light count drops below 4, M1 closes back across Coral, or the position has been held for 18 M1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_trix_period | 6 | 2-100 | Fast TRIX period for the fast THV light on each timeframe. |
| strategy_slow_trix_period | 9 | 2-150 | Slow TRIX period for the slow THV light on each timeframe. |
| strategy_trix_signal_period | 3 | 1-50 | EMA period used to convert TRIX into histogram direction. |
| strategy_coral_period | 34 | 2-200 | Coral/T3 smoothing period used for side filter and exit cross. |
| strategy_coral_factor | 0.4 | 0.0-1.0 | Tillson T3 volume factor used for the Coral approximation. |
| strategy_cloud_tenkan | 9 | 1-100 | Ichimoku Tenkan period for the THV cloud proxy. |
| strategy_cloud_kijun | 26 | 1-150 | Ichimoku Kijun period and cloud displacement. |
| strategy_cloud_senkou | 52 | 1-250 | Ichimoku Senkou B period. |
| strategy_atr_period | 14 | 2-100 | ATR period for abnormal-bar, spread, and stop-distance checks. |
| strategy_abnormal_bar_atr_mult | 2.2 | 0.1-10.0 | Reject M1 signal bars larger than this multiple of ATR. |
| strategy_spread_atr_ratio | 0.12 | 0.0-1.0 | Maximum modeled spread as a fraction of ATR; zero spread is allowed. |
| strategy_adr_days | 14 | 1-100 | ADR lookback in D1 bars. |
| strategy_adr_max_fraction | 0.90 | 0.0-2.0 | Reject entries once current D1 range exceeds this ADR fraction. |
| strategy_swing_lookback | 10 | 1-100 | M1 bars used for recent swing low/high stop placement. |
| strategy_tp_rr | 1.2 | 0.1-10.0 | Reward/risk TP candidate. |
| strategy_tp_fixed_pips | 10 | 1-500 | Fixed-pip TP candidate; the closer of fixed TP and RR TP is used. |
| strategy_max_hold_m1_bars | 18 | 1-500 | Time stop in M1 bars. |
| strategy_session_start_hour | 10 | 0-23 | Broker-hour start for London plus early New York entry window. |
| strategy_session_end_hour | 20 | 0-23 | Broker-hour end for London plus early New York entry window. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major and native DWX symbol.
- GBPUSD.DWX - card-listed FX major and native DWX symbol.
- AUDUSD.DWX - card-listed FX major and native DWX symbol.
- XAUUSD.DWX - card-listed gold symbol and native DWX custom symbol.

**Explicitly NOT for:**
- Index `.DWX` symbols - the approved R3 basket is FX/metals, not index CFDs.
- Energy `.DWX` symbols - not named by the card and not part of the THV ForexFactory basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | M1, M5, and M15 TRIX histograms; M1 Coral/T3; M1 Ichimoku cloud; D1 ADR |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | Up to 18 minutes by card time stop; TP/SL can close earlier. |
| Expected drawdown profile | Scalping profile with many short holds and ATR/swing-defined per-trade risk. |
| Regime preference | Intraday momentum continuation during London and early New York. |
| Win rate target (qualitative) | Medium to high, due to closer 10-pip-or-1.2R target and strict six-light confirmation. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** Cobra / MissPips, THV system final edition - 6 lights method, ForexFactory, 2009-2010, https://www.forexfactory.com/thread/127271-thv-system-final-edition
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9722_ff-thv-6lights-m1.md`

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
| v1 | 2026-06-20 | Initial build from card | 48854cb6-16e4-49bf-b022-7e8d9ff62bf7 |
