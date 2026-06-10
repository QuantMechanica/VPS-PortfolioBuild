# QM5_9456_gk-3maf — Strategy Spec

**EA ID:** QM5_9456
**Slug:** `gk-3maf`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Computes three EMAs (periods 60, 350, 600) on the last closed M15 bar. A buy signal requires the EMAs to stack bullishly (EMA60 > EMA350 > EMA600), the bar's low to lie above EMA600 but below EMA60 (pullback into the fast MA), and a confirmed Williams lower fractal at bar[2]. The sell mirror requires the bearish EMA stack (EMA600 > EMA350 > EMA60), the bar's high below EMA600 but above EMA60, and a confirmed upper fractal at bar[2]. Stop loss is placed at EMA350 if the low/high remains inside it, otherwise at EMA600. Take profit is 1.5× the SL distance. The trade exits at TP/SL, on an opposite valid 3MAF signal, or after 96 M15 bars (24 h), whichever comes first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma1_period` | 60 | 10–200 | Fast EMA period |
| `strategy_ma2_period` | 350 | 100–600 | Medium EMA period |
| `strategy_ma3_period` | 600 | 200–1000 | Slow EMA period |
| `strategy_tp_coef` | 1.5 | 0.5–5.0 | Take-profit as multiple of SL distance |
| `strategy_time_exit_bars` | 96 | 24–480 | Maximum hold in M15 bars (96 = 24 h) |
| `strategy_min_stop_points` | 100 | 10–500 | Minimum SL distance in points; signals below this are rejected |

---

## 3. Symbol Universe

**Designed for:**
- `USDCAD.DWX` — liquid FX major; original test symbol from source repository
- `EURUSD.DWX` — highest-liquidity FX major; trend-following on M15 established
- `GBPUSD.DWX` — liquid FX major with sufficient M15 trend structure
- `AUDUSD.DWX` — correlated FX major; extends the portfolio basket

**Explicitly NOT for:**
- Index CFDs — EMA600 on M15 requires ~150 h of data; FX majors have deeper history and tighter spreads

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~70 |
| Typical hold time | 1–24 hours (M15 bars × 15 min) |
| Expected drawdown profile | Moderate; filtered by 3-EMA alignment reduces false entries |
| Regime preference | trend-following with pullback confirmation |
| Win rate target (qualitative) | medium (>50% with 1.5R RR) |

---

## 6. Source Citation

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub / open-source MQL5
**Pointer:** Geraked/Rabist, `geraked/metatrader5`, `Experts/3MAF.mq5`, commit `d3eb29c382acf715727d5cd6a0414151e821fc2d`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9456_gk-3maf.md`

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
| v1 | 2026-06-10 | Initial build from card | 89d7c16d-11e2-4dcd-bf1d-d3eb67020659 |
