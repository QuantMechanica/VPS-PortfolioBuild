# QM5_9412_mql5-paq-engulf — Strategy Spec

**EA ID:** QM5_9412
**Slug:** `mql5-paq-engulf`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed H1 bar the EA compares the last two bars for a body-engulfing reversal pattern. A bullish engulfing fires when the prior bar is bearish, the current bar's body is larger, the current bar opens at or within the prior body, and closes above the prior open — while the current close is at or below EMA(20), confirming a mean-reversion setup below the average. A bearish engulfing mirrors this above EMA(20). The EA enters at market, places a stop beyond the two-bar pattern's extreme plus 0.25×ATR(14), and targets 2× the risk distance. Positions exit at TP, SL, a time stop of 24 H1 bars, an opposite engulfing pattern, or when price closes back through EMA(20) in the adverse direction after first crossing it favourably.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 20 | 10–50 | EMA period for mean-reversion context filter |
| `strategy_atr_period` | 14 | 7–21 | ATR period for SL buffer and range noise filter |
| `strategy_sl_atr_mult` | 0.25 | 0.1–1.0 | ATR multiplier applied beyond pattern extreme for SL |
| `strategy_tp_rr` | 2.0 | 1.0–4.0 | Risk:reward ratio for TP (2R default) |
| `strategy_range_filter` | 0.5 | 0.2–1.0 | Minimum current-bar range as fraction of ATR (noise guard) |
| `strategy_max_hold_bars` | 24 | 8–72 | Maximum hold duration in H1 bars before time stop fires |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — high-liquidity major FX pair; clean engulfing patterns on H1 with tight spreads
- `GBPUSD.DWX` — high-volatility major FX; frequent engulfing reversals at EMA levels
- `USDJPY.DWX` — major FX pair with strong trend-then-reverse cycles suitable for engulfing mean-reversion
- `XAUUSD.DWX` — gold exhibits strong engulfing reversals around key moving-average levels on H1

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/GDAXI) — not included in card's target universe; FX/gold engulfing semantics differ from index internals

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
| Trades / year / symbol | ~60 |
| Typical hold time | 2–12 hours (2R hit or time stop at 24H) |
| Expected drawdown profile | Moderate; mean-reversion with EMA context limits directional bias |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 24): Price Action Quantification Analysis Tool", MQL5 Articles, 2025-05-22, https://www.mql5.com/en/articles/18207
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9412_mql5-paq-engulf.md`

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
| v1 | 2026-06-10 | Initial build from card | e3d064ec-0a6b-4cdd-8a4c-003af3a5bd96 |
