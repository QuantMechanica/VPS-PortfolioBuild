# QM5_2132_pring-kst-histogram-h4 — Strategy Spec

**EA ID:** QM5_2132
**Slug:** pring-kst-histogram-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades Martin Pring's Know-Sure-Thing histogram on closed H4 bars. It computes four smoothed ROC components, combines them as `KST = 1*SROC1 + 2*SROC2 + 3*SROC3 + 4*SROC4`, subtracts a 9-bar SMA signal line, and trades either confirmed histogram zero-crosses or histogram/price divergence. Long trades require D1 close above EMA(50); shorts require D1 close below EMA(50). Exits occur on the opposite histogram cross, opposite divergence, ATR trailing after a 2 ATR favourable move, framework Friday close, or a 120-H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_roc1_period | 10 | >=1 | First ROC lookback. |
| strategy_roc2_period | 15 | >=1 | Second ROC lookback. |
| strategy_roc3_period | 20 | >=1 | Third ROC lookback. |
| strategy_roc4_period | 30 | >=1 | Fourth ROC lookback. |
| strategy_smooth1_period | 10 | >=1 | SMA smoothing for ROC1. |
| strategy_smooth2_period | 10 | >=1 | SMA smoothing for ROC2. |
| strategy_smooth3_period | 10 | >=1 | SMA smoothing for ROC3. |
| strategy_smooth4_period | 15 | >=1 | SMA smoothing for ROC4. |
| strategy_weight1 | 1.0 | >0 | KST weight for smoothed ROC1. |
| strategy_weight2 | 2.0 | >0 | KST weight for smoothed ROC2. |
| strategy_weight3 | 3.0 | >0 | KST weight for smoothed ROC3. |
| strategy_weight4 | 4.0 | >0 | KST weight for smoothed ROC4. |
| strategy_signal_period | 9 | >=1 | SMA period for the KST signal line. |
| strategy_divergence_window | 20 | >=6 | Window for histogram/price divergence. |
| strategy_min_peak_separation | 5 | >=1 | Minimum H4 bars between divergence extrema. |
| strategy_atr_period | 20 | >=1 | ATR period for stops, spread cap, and trailing. |
| strategy_initial_atr_mult | 0.5 | >0 | Initial stop offset from entry bar high/low. |
| strategy_trail_atr_mult | 3.0 | >0 | ATR trailing stop distance. |
| strategy_trail_trigger_atr | 2.0 | >0 | Favourable move before ATR trailing starts. |
| strategy_d1_ema_period | 50 | >=1 | D1 EMA regime filter. |
| strategy_hist_std_period | 50 | >=2 | Histogram standard-deviation window. |
| strategy_cross_std_mult | 0.05 | >=0 | Minimum zero-cross magnitude as a share of histogram standard deviation. |
| strategy_hist_noise_mult | 0.30 | >=0 | Minimum absolute histogram size as a share of histogram standard deviation. |
| strategy_rearm_bars | 60 | >=0 | Bars suppressing same-direction divergence after a same-direction zero-cross. |
| strategy_cooldown_bars | 5 | >=0 | H4 bars to wait after an exit before re-entry. |
| strategy_max_hold_h4_bars | 120 | >=1 | Time-stop in H4 bars. |
| strategy_warmup_h4_bars | 200 | >=1 | Minimum H4 history before signals are valid. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX — FX major explicitly listed by the card as price-only portable.
- GBPUSD.DWX — FX major explicitly listed by the card as price-only portable.
- USDJPY.DWX — FX major explicitly listed by the card as price-only portable.
- XAUUSD.DWX — gold CFD explicitly listed by the card as price-only portable.
- XTIUSD.DWX — crude oil CFD explicitly listed by the card as price-only portable.
- NDX.DWX — Nasdaq 100 index listed in the card's portable index basket.
- WS30.DWX — Dow 30 index listed in the card's portable index basket.
- GDAXI.DWX — DAX index listed in the card's portable global index basket.
- UK100.DWX — FTSE 100 index listed in the card's portable global index basket.
- SP500.DWX — S&P 500 custom symbol listed by the card; backtest-only T6 caveat remains outside Q01.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — unavailable to the DWX tester.
- Volume-dependent instruments or feeds — the card is price-only and this EA reads no external volume or macro data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(50) regime filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | 20-40% longer than KST cross trades; capped at 120 H4 bars |
| Expected drawdown profile | Momentum-reversal drawdowns during choppy histogram noise and false divergence clusters |
| Regime preference | Oscillator trend-reversal with D1 regime alignment |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum plus book references
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_2132_pring-kst-histogram-h4.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_2132_pring-kst-histogram-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | c76577a8-c5f6-4e78-84b6-2fa46edd191d |
