# QM5_11518_carter-t-ema5-100-mtf-m15-h1 — Strategy Spec

**EA ID:** QM5_11518
**Slug:** `carter-t-ema5-100-mtf-m15-h1`
**Source:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf` (see `strategy-seeds/sources/carter-thomas-20-forex-trend-following-systems/`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

Multi-timeframe trend following system using the EMA(5) and EMA(100) pair across H1 and M15 timeframes.
- **Trend Filter**: On H1 closed bar (Shift 1), EMA(5) > EMA(100) defines a bullish higher-timeframe trend regime; EMA(5) < EMA(100) defines a bearish regime.
- **Entry Trigger**: On M15 closed bar, enter BUY when EMA(5) crosses above EMA(100) within the bullish H1 regime. Enter SELL when EMA(5) crosses below EMA(100) within the bearish H1 regime.
- **Exits**: Fixed 15-pip Stop Loss and 30-pip Take Profit (1:2.0 Risk-to-Reward ratio).
- **Filters**: Max spread cap of 12 pips and standard Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 5 | 3-20 | Fast EMA period for MTF filter and entry |
| `strategy_slow_ema_period` | 100 | 50-200 | Slow EMA baseline trend period |
| `strategy_sl_pips` | 15 | 10-30 | Fixed Stop Loss in pips |
| `strategy_tp_pips` | 30 | 20-60 | Fixed Take Profit in pips |
| `strategy_max_spread_pips` | 12 | 5-20 | Max allowable spread filter in pips |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Source-specified primary liquid forex major
- `GBPUSD.DWX` — Liquid forex major with strong MTF trend responsiveness

**Explicitly NOT for:**
- Any symbol not registered in `magic_numbers.csv` for this EA (bound fail-closed by framework symbol guard).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1` (EMA 5 and EMA 100 trend regime filter) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 15 |
| Typical hold time | 2 to 8 hours |
| Expected drawdown profile | Bounded by fixed 15-pip stop loss and fixed risk per trade |
| Regime preference | Intraday momentum aligned with multi-hour higher timeframe trend |
| Win rate target (qualitative) | Medium (45% - 55% with 1:2 R:R) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Source type:** Book (Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #15, 2014)
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11518_carter-t-ema5-100-mtf-m15-h1.md`
**R1–R4 verdict (Q00):** PASS per approved card `QM5_11518_carter-t-ema5-100-mtf-m15-h1.md`

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
| v1 | 2026-08-23 | Initial mechanical build from approved card | Task d0f1e256-7e79-48ed-ac9b-ecdde5128a35 |
