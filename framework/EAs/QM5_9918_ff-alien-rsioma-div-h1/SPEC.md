# QM5_9918_ff-alien-rsioma-div-h1 — Strategy Spec

**EA ID:** QM5_9918
**Slug:** `ff-alien-rsioma-div-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed H1 bar the EA scans the last 60 bars for two confirmed fractal pivots (3 bars each side, applied to close prices). A long setup is active when the more recent price pivot is a lower low while the RSI-14 at that pivot is a higher low (divergence), both RSI readings are below 45, at least one is below 30, and the DDS Stochastic (8,3,3) also shows a higher low or a bullish cross within 5 bars. The confirmation Stochastic (21,10,10) %K must be rising and ADX (21) must not have been declining for more than 4 consecutive bars. Entry fires at the next H1 open after RSI crosses back above 30 or DDS %K crosses above %D. Stop loss is placed below the recent fractal Low minus 0.35 ATR; take profit is at 1.8R. The trade also exits if RSI crosses back below 50 after reaching 0.8R profit, if DDS crosses against the trade before 0.8R, or if 18 H1 bars elapse. Short setup mirrors all conditions.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 8-21 | RSI period (RSIOMA proxy) |
| `strategy_dds_k` | 8 | 5-14 | DDS Stochastic K period |
| `strategy_dds_d` | 3 | 2-5 | DDS Stochastic D period |
| `strategy_dds_slow` | 3 | 2-5 | DDS Stochastic slow period |
| `strategy_stoch_k` | 21 | 10-34 | Confirmation Stochastic K |
| `strategy_stoch_d` | 10 | 5-14 | Confirmation Stochastic D |
| `strategy_stoch_slow` | 10 | 5-14 | Confirmation Stochastic slow |
| `strategy_adx_period` | 21 | 14-28 | ADX period |
| `strategy_atr_period` | 14 | 10-20 | ATR period |
| `strategy_fractal_n` | 3 | 2-5 | Fractal bars each side |
| `strategy_min_pivot_bars` | 12 | 8-20 | Minimum bars between pivots |
| `strategy_max_pivot_bars` | 60 | 40-80 | Maximum bars between pivots |
| `strategy_rsi_os_zone` | 45.0 | 35-50 | RSI oversold zone threshold (long) |
| `strategy_rsi_extreme` | 30.0 | 20-35 | RSI extreme low threshold (long) |
| `strategy_rsi_ob_zone` | 55.0 | 50-65 | RSI overbought zone threshold (short) |
| `strategy_rsi_extreme_hi` | 70.0 | 65-80 | RSI extreme high threshold (short) |
| `strategy_dds_window` | 5 | 3-8 | DDS cross confirmation window |
| `strategy_adx_fall_bars` | 4 | 2-6 | ADX consecutive decline cap |
| `strategy_sl_atr_buf` | 0.35 | 0.2-0.6 | SL buffer in ATR from pivot extreme |
| `strategy_sl_min_atr` | 0.8 | 0.5-1.5 | Minimum SL distance in ATR |
| `strategy_sl_max_atr` | 3.0 | 2.0-5.0 | Maximum SL distance in ATR |
| `strategy_tp_r` | 1.8 | 1.2-3.0 | Take profit in R multiples |
| `strategy_exit_r` | 0.8 | 0.5-1.2 | Profit threshold to enable RSI-50 exit |
| `strategy_time_stop_bars` | 18 | 12-30 | Time stop in H1 bars |
| `strategy_spread_atr_max` | 0.15 | 0.1-0.25 | Max spread as fraction of ATR |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Liquid major FX pair; suitable H1 oscillator divergence range
- `GBPUSD.DWX` — Liquid major FX pair with similar structural momentum profile
- `AUDUSD.DWX` — Risk-correlated FX pair; RSI divergence reliable at H1 during Asia-London overlap
- `XAUUSD.DWX` — Gold; strong oscillator divergence patterns at H1 due to momentum-exhaustion cycles

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500) — higher volatility makes fixed RSI zone thresholds unreliable without recalibration

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
| Trades / year / symbol | ~28 |
| Typical hold time | 6-18 hours (median ~12 H1 bars) |
| Expected drawdown profile | Moderate pullback-trade DD; 1.8R TP limits per-trade loss to 1R |
| Regime preference | mean-revert / momentum-exhaustion |
| Win rate target (qualitative) | medium (targeting ~45-55% with 1.8R RR) |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** forexalien, "Alien's Extraterrestrial Visual Systems", ForexFactory 2013-2026, https://www.forexfactory.com/thread/463573-aliens-extraterrestrial-visual-systems
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9918_ff-alien-rsioma-div-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | ba27aafe-cda6-4d36-87fe-d238e4b69aee |
