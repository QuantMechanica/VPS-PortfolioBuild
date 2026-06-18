# QM5_11002_the5ers-m1-ema-stoch — Strategy Spec

**EA ID:** QM5_11002
**Slug:** `the5ers-m1-ema-stoch`
**Source:** `1d445184-7c47-57da-9856-a123682a932d` (The5ers blog, "1 Minute Scalping Strategy")
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

M1 EMA + Stochastic pullback scalper, both directions, one position per magic.
On each closed M1 bar the EA reads EMA(50)/EMA(100), Stochastic(14,3,3) and ATR(14).
A LONG fires when EMA(50) is above EMA(100) AND an EMA(50)-over-EMA(100) cross-up
occurred within the last 10 closed bars (regime), price has pulled back to the EMA band
(|close[1]-EMA50[1]| <= 0.35*ATR, or the prior-bar low touched the band), and Stochastic
%K crosses up through 20 (the single trigger event). A SHORT is the mirror: EMA(50) below
EMA(100), pullback to the band, %K crosses down through 80. The stop is the farther of the
prior-10-bar structural swing low/high and a 1.0*ATR minimum distance; the take-profit is a
fixed 10 pips. Positions also close on an adverse EMA(50)/EMA(100) recross, a Stochastic %K
recross of the 50 midline, or a 30-bar time-stop. Trades only inside the 07:00-17:00
broker-time London+NY window, skips genuinely wide spreads (>15% of TP), and skips
dead-tick regimes where ATR(14) falls below 0.5x a slow M1 ATR baseline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 50 | 20-100 | Fast EMA period |
| `strategy_ema_slow_period` | 100 | 50-200 | Slow EMA period |
| `strategy_stoch_k` | 14 | 5-21 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 1-5 | Stochastic %D period |
| `strategy_stoch_slow` | 3 | 1-5 | Stochastic slowing |
| `strategy_stoch_lo` | 20.0 | 10-30 | Long trigger: %K crosses up through this |
| `strategy_stoch_hi` | 80.0 | 70-90 | Short trigger: %K crosses down through this |
| `strategy_stoch_mid` | 50.0 | 40-60 | Exit: %K recross of this midline |
| `strategy_cross_lookback` | 10 | 1-30 | Bars to confirm a recent EMA cross-up (long) |
| `strategy_pullback_atr_frac` | 0.35 | 0.1-1.0 | Pullback-zone band width as fraction of ATR |
| `strategy_atr_period` | 14 | 5-30 | ATR period (pullback / SL minimum / floor) |
| `strategy_atr_baseline` | 200 | 50-500 | Slow M1 ATR baseline (median proxy) |
| `strategy_atr_floor_mult` | 0.5 | 0.1-1.0 | Skip if ATR(14) < mult * baseline ATR |
| `strategy_swing_lookback` | 10 | 5-30 | Prior bars for structural swing SL |
| `strategy_sl_atr_min_mult` | 1.0 | 0.5-3.0 | Minimum SL distance = mult * ATR |
| `strategy_tp_pips` | 10 | 8-12 | Fixed take-profit in pips (P3 sweep 8/10/12) |
| `strategy_time_stop_bars` | 30 | 10-60 | Close after N M1 bars if no TP/SL |
| `strategy_session_start_h` | 7 | 0-23 | Liquid-window start (broker time) |
| `strategy_session_end_h` | 17 | 0-23 | Liquid-window end (broker time) |
| `strategy_spread_pct_of_tp` | 15.0 | 5-50 | Skip if spread > this % of TP distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most-liquid FX major; tightest M1 spread, the canonical scalping pair.
- `GBPUSD.DWX` — liquid major with London-session range; fits the 07:00-17:00 window.
- `USDJPY.DWX` — liquid major; JPY pip scaling handled by the framework pip_factor.
- `EURJPY.DWX` — liquid cross with strong London/NY intraday trends.

**Explicitly NOT for:**
- Index / metal / crypto `.DWX` symbols — the source is explicitly forex scalping; the
  pip-based TP and M1 cadence are calibrated to FX-major tick structure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~300` |
| Typical hold time | `minutes (<= 30 M1 bars)` |
| Expected drawdown profile | `frequent small scalps; shallow per-trade DD, spread-sensitive` |
| Regime preference | `trend (pullback continuation in liquid sessions)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** `forum / blog`
**Pointer:** `https://the5ers.com/1-minute-scalping-trading/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11002_the5ers-m1-ema-stoch.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
| v2 | 2026-06-18 | Initial build from card | d9f92d69-dc09-43a2-89cb-84fbd79254ba |
