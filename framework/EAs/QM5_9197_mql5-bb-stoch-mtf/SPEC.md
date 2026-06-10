# QM5_9197_mql5-bb-stoch-mtf — Strategy Spec

**EA ID:** QM5_9197
**Slug:** `mql5-bb-stoch-mtf`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Mean-reversion EA using Bollinger Bands(20, 2.0) and Stochastic(14, 3, 3) across three timeframes (M15, M30, H1). A long signal fires when the last closed M15 bar's close is at or below the lower Bollinger Band on all three timeframes simultaneously, and Stochastic %K is at or below 20 on all three timeframes. A short signal fires on the mirror condition: close at or above the upper band and %K ≥ 80 on M15/M30/H1. Stop loss is placed at the signal bar's low (long) or high (short) minus/plus ATR(14) × 0.5. Take profit targets the M15 Bollinger middle band at entry, capped at 1.5R, whichever is closer. An opposite three-timeframe signal also closes the position early. A minimum gap of 10 M15 bars between same-direction entries prevents signal clustering.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10–50 | Bollinger Bands lookback period |
| `strategy_bb_devs` | 2.0 | 1.5–3.0 | Bollinger Bands standard deviation multiplier |
| `strategy_stoch_k` | 14 | 5–21 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 1–5 | Stochastic %D smoothing |
| `strategy_stoch_slow` | 3 | 1–5 | Stochastic slowing |
| `strategy_stoch_os` | 20.0 | 10–30 | Oversold threshold (long entry when %K ≤ this) |
| `strategy_stoch_ob` | 80.0 | 70–90 | Overbought threshold (short entry when %K ≥ this) |
| `strategy_atr_period` | 14 | 7–21 | ATR period for SL offset |
| `strategy_sl_atr_mult` | 0.5 | 0.3–1.0 | SL offset = bar extreme ± ATR × this |
| `strategy_tp_rr` | 1.5 | 1.0–3.0 | Max reward/risk ratio for TP cap |
| `strategy_min_bar_gap` | 10 | 5–20 | Minimum M15 bars between same-direction signals |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; BB mean-reversion patterns well-documented on M15
- `GBPUSD.DWX` — liquid major FX pair; comparable volatility profile to EURUSD on intraday TFs
- `XAUUSD.DWX` — spot gold; mean-reverting within sessions; high ATR makes BB touches meaningful

**Explicitly NOT for:**
- Index CFDs (NDX.DWX, WS30.DWX) — trending bias conflicts with mean-reversion premise on M15

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | M15, M30, H1 (all three required for confluence) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~50 |
| Typical hold time | 1–8 hours (M15 bars to BB middle band) |
| Expected drawdown profile | Shallow per-trade (SL < 1 ATR from entry), mean-reverting regime |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium (MTF confluence filters false signals) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum/article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 7): Signal Pulse EA", MQL5 Articles, 2025-01-16, https://www.mql5.com/en/articles/16861
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9197_mql5-bb-stoch-mtf.md`

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
| v1 | 2026-06-10 | Initial build from card | 10fc02e4-a7e5-4b5c-a6c6-492bc5963084 |
