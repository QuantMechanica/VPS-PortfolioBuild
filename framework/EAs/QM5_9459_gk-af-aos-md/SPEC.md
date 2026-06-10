# QM5_9459_gk-af-aos-md — Strategy Spec

**EA ID:** QM5_9459
**Slug:** `gk-af-aos-md`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed M30 bar, compute a double-EMA of normalised bar body direction (Average Force) and the Andean Oscillator exponential variance decomposition (bull/bear components). Enter LONG when Average Force crosses from negative to positive, Andean bull component exceeds bear, MACD(100,200,1) is positive and rising bar-over-bar. Enter SHORT on the mirror conditions. Hold to 1R TP, opposite-signal exit, or 80-bar time stop. Stop loss is placed below/above the 7-bar swing low/high plus a 60-point buffer.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_af_period` | 20 | 5–50 | Average Force primary EMA period |
| `strategy_af_smooth` | 9 | 3–20 | Average Force secondary smoothing EMA period |
| `strategy_aos_period` | 50 | 20–100 | Andean Oscillator exponential variance period |
| `strategy_aos_sig_period` | 9 | 3–20 | Andean Oscillator signal EMA period |
| `strategy_md_fast` | 100 | 50–150 | MACD fast EMA period |
| `strategy_md_slow` | 200 | 100–300 | MACD slow EMA period |
| `strategy_sl_lookback` | 7 | 3–20 | Bars back for swing stop low/high |
| `strategy_sl_dev_pts` | 60.0 | 10–150 | Extra buffer beyond swing in _Point units |
| `strategy_tp_coef` | 1.0 | 0.5–3.0 | TP distance as multiple of SL distance |
| `strategy_time_exit_bars` | 80 | 20–200 | Forced exit after N M30 bars (~40 hours) |

---

## 3. Symbol Universe

**Designed for:**
- `NZDCAD.DWX` — FX cross with moderate volatility; card primary symbol
- `EURUSD.DWX` — Most liquid FX major; OHLC-derived indicators well-calibrated
- `AUDUSD.DWX` — Risk-correlated FX pair; momentum continuation fits commodity-currency dynamics
- `USDCAD.DWX` — Oil-correlated; momentum patterns align with commodity cycles

**Explicitly NOT for:**
- Indices — strategy calibrated to FX pip structure; equity-index spreads and overnight gaps are incompatible without parameter recalibration

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~60 |
| Typical hold time | 2–40 hours (1–80 M30 bars) |
| Expected drawdown profile | Moderate; swing stop + 1R TP keeps risk-reward symmetrical |
| Regime preference | momentum-continuation |
| Win rate target (qualitative) | medium (~50%) with 1:1 R:R target |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub / forum
**Pointer:** `geraked/metatrader5` — `Experts/AFAOSMD.mq5`, commit d3eb29c382acf715727d5cd6a0414151e821fc2d
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9459_gk-af-aos-md.md`

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
| v1 | 2026-06-11 | Initial build from card | 7e890638-0100-4548-8d4e-e49c4f5fd5a0 |
