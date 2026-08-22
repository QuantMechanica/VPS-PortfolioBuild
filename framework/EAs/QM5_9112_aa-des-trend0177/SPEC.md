# QM5_9112_aa-des-trend0177 — Strategy Spec

**EA ID:** QM5_9112
**Slug:** `aa-des-trend0177`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9112_aa-des-trend0177.md`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The strategy implements Henry Stern's Double Exponential Smoothing (DES) trend-following filter on daily (D1) bars with fixed smoothing constant `alpha = 0.1772`.

On completed D1 bars:
1. First exponential smoothing: $S'_t = \alpha \cdot \text{Close}_t + (1 - \alpha) \cdot S'_{t-1}$
2. Second exponential smoothing: $S''_t = \alpha \cdot S'_t + (1 - \alpha) \cdot S''_{t-1}$
3. DES Linear Trend output: $b_t = \frac{\alpha}{1 - \alpha} (S'_t - S''_t)$
4. Long entry when the DES trend crosses above zero ($b_1 > 0$ and $b_2 \le 0$).
5. Long exit when the DES trend crosses below zero ($b_1 < 0$).
6. Optional short trading if `strategy_enable_shorts` is enabled (default: false, long/cash).
7. Catastrophic / Initial Stop Loss: $3.0 \times \text{ATR}(20, D1)$.
8. Spread guard: skip entry when current spread exceeds $2.5 \times \text{MedianSpreadD1}(20)$.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_alpha` | 0.1772 | locked | DES smoothing constant from source |
| `strategy_atr_period` | 20 | locked | ATR period for initial Stop Loss |
| `strategy_atr_sl_mult` | 3.0 | locked | ATR multiplier for initial Stop Loss |
| `strategy_min_warmup_bars` | 120 | locked | Minimum completed D1 bars before trading |
| `strategy_enable_shorts` | false | true/false | Enable short entries (default: long/cash) |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- Multi-asset D1 trend: FX pairs (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `NZDUSD.DWX`), Indices (`GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX`), Commodities (`XAUUSD.DWX`).

**Explicitly NOT for:** any symbol not registered in `magic_numbers.csv` for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 3 - 8 |
| Cadence note | Long/cash trend-following on D1 |
| Typical hold time | 15 - 60 days |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Trending market environments |
| Win rate target (qualitative) | 35% - 45% (high reward-to-risk) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Pointer:** Henry Stern, "Trend-Following Filters: Part 1/2", 2020-12-29, https://alphaarchitect.com/trend-following-filters-part-1-2/
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9112_aa-des-trend0177.md`

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
| v1 | 2026-08-22 | Initial draft build and spec | Gemini drafting for Codex review |
