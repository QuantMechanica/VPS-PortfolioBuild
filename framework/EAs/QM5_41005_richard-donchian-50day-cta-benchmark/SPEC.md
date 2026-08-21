# QM5_41005_richard-donchian-50day-cta-benchmark — Strategy Spec

**EA ID:** QM5_41005
**Slug:** richard-donchian-50day-cta-benchmark
**Source:** richard-donchian-50day-cta-benchmark-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy implements the classic Richard Donchian 50-day CTA trend following benchmark on daily (D1) bars. On each closed D1 bar, the EA checks for a 50-day breakout (highest high or lowest low of the preceding 50 bars). When a long breakout occurs, the EA buys with an ATR-based stop loss at 3.0x ATR(20). When a short breakout occurs, the EA sells with an ATR-based stop loss at 3.0x ATR(20). Open positions are trailed and exited when the price breaches the opposite 20-day Donchian channel.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpEntryLookback` | 50 | 30-80 | Donchian entry breakout lookback bars |
| `InpExitLookback` | 20 | 10-30 | Donchian exit channel lookback bars |
| `InpAtrPeriod` | 20 | 10-30 | ATR period for initial stop loss sizing |
| `InpAtrSlMult` | 3.0 | 1.5-4.0 | ATR multiplier for stop loss placement |
| `InpSpreadAtrMult` | 1.8 | 1.0-3.0 | Maximum allowable spread as multiple of D1 ATR(14) |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` — High-liquidity energy commodity with sustained multi-month trend cycles.
- `XAUUSD.DWX` — Gold commodity with strong trend persistence and macro breakout characteristics.
- `SP500.DWX` — Broad US equity index capturing macroeconomic structural drift and expansions.
- `EURUSD.DWX` — Core G10 FX pair exhibiting multi-quarter trend and monetary divergence regimes.

**Explicitly NOT for:**
- `AUDNZD.DWX` — Mean-reverting cross pair with low trend persistence and high range compression.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | days |
| Expected drawdown profile | Low-to-moderate equity drawdown (<8.0%) with trend-following distribution |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** richard-donchian-50day-cta-benchmark-official-source
**Source type:** paper
**Pointer:** Donchian, R. (1960). High Finance in Copper. Commodities Magazine / CTA Industry Benchmark.
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_41005_richard-donchian-50day-cta-benchmark.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Task 30ceeacd-0647-485a-9886-725af2139d61 |
