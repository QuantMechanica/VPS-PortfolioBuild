# QM5_12544_katz-macd-divergence-limit-d1 — Strategy Spec

**EA ID:** QM5_12544
**Slug:** `katz-macd-divergence-limit-d1`
**Source:** `katz-encyclopedia-2000-ch7` (see `strategy-seeds/sources/katz-encyclopedia-2000-ch7/`)
**Author of this spec:** Development
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA detects MACD divergence using Katz's algorithmic temporal constraint. Over a 20-bar look-back window, it identifies the deepest price valley (lowest closing price) and the deepest MACD valley. For a valid LONG signal, the MACD valley must occur at least 4 bars before the price valley (the MACD leads the price bottom), the price valley must be 1–6 bars ago (recent, not stale), and the MACD line must have just turned upward on the signal bar. A BUY_LIMIT order is placed at the midpoint of the signal bar's high and low, valid for 2 D1 bars; if unfilled it expires. The exit uses the Katz Standard Exit Strategy: 1×ATR(50) stop loss, 4×ATR(50) profit target, and a 10-bar time stop that closes the position at market if neither SL nor TP has been hit. SHORT is the full mirror: price peak, MACD peak, MACD turns down, SELL_LIMIT at bar midpoint.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 5 | 5–13 | MACD fast EMA period (Katz best-range midpoint) |
| `strategy_macd_slow` | 25 | 20–35 | MACD slow EMA period (Katz best-range midpoint) |
| `strategy_lookback` | 20 | 15–25 | Bars to scan for valley/peak (P3 sweep: 15/20/25) |
| `strategy_temporal_min` | 4 | 3–6 | Min bars MACD valley must precede price valley |
| `strategy_recency_min` | 1 | 1 | Price valley recency lower bound (bars ago) |
| `strategy_recency_max` | 6 | 4–8 | Price valley recency upper bound (bars ago) |
| `strategy_sl_mult` | 1.0 | fixed | SL = entry ± mult × ATR(atr_period) |
| `strategy_tp_mult` | 4.0 | fixed | TP = entry ± mult × ATR(atr_period) |
| `strategy_atr_period` | 50 | fixed | ATR period for SES stop/target (Katz baseline) |
| `strategy_time_exit_bars` | 10 | fixed | Close position after this many D1 bars |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — Gold; most analogous to Katz's best-performing markets (commodities with mean-reverting divergence patterns)
- `NDX.DWX` — Nasdaq 100; liquid US equity index with trending MACD divergence patterns
- `WS30.DWX` — Dow 30; broad US equity index providing diversification vs NDX

**Explicitly NOT for:**
- `SP500.DWX` — Not registered; NDX and WS30 provide equivalent US large-cap exposure
- Forex pairs — insufficient volatility structure for ATR(50) D1 divergence logic

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
| Trades / year / symbol | ~12 |
| Typical hold time | 1–10 days (time stop at bar 10) |
| Expected drawdown profile | ~15% max drawdown; 1×ATR stop limits per-trade risk |
| Regime preference | mean-reversion / oscillator-based pullback |
| Win rate target (qualitative) | low–medium (~44% OOS per Katz) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `katz-encyclopedia-2000-ch7`
**Source type:** book
**Pointer:** `D:/QM/strategy_farm/source_cache/katz-mccormick-encyclopedia-2000.txt`, Ch.7 pp.161-166
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12544_katz-macd-divergence-limit-d1.md`

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
| v1 | 2026-06-13 | Initial build from card | 9f5e7f9d-ce4c-4519-aabf-61ba7fbab64e |
