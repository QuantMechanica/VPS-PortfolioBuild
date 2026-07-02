# QM5_12613_tsmom-3m-commodity-xauusd — Strategy Spec

**EA ID:** QM5_12613
**Slug:** `tsmom-3m-commodity-xauusd`
**Source:** `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59` (see `strategy-seeds/sources/e5a3f925-5a9e-513d-9e70-5c7c70fa0e59/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

On the first D1 bar of each calendar month, the EA computes the sign of the 63-bar (≈3-month) price return: if the most recently closed D1 bar's close is above the close 63 bars prior, the signal is long (+1); otherwise it is short (-1). On a signal change the EA closes the existing opposite position and opens a new position in the new direction; on an unchanged signal it holds (or re-enters if stopped out mid-month). There is no take-profit target; the position is held until the monthly signal reverses or the intra-month ATR stop is hit. The stop is set at entry_price ± ATR(14, D1) × 2.5.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_bars` | 63 | 21–126 | D1 bars for the momentum lookback (≈3 trading months at 63) |
| `strategy_atr_period` | 14 | 7–28 | ATR period used to set the intra-month stop distance |
| `strategy_atr_sl_mult` | 2.5 | 1.5–4.0 | ATR multiplier applied to the stop price |
| `strategy_spread_max_pips` | 30 | 5–100 | Entry blocked if live spread exceeds this pip threshold |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — Gold CFD; exhibits multi-week to multi-month momentum at the 3-month horizon driven by safe-haven flows and dollar directionality; low commission (~$0.4–$6.7/trade) makes monthly rebalancing economically viable

**Explicitly NOT for:**
- FX majors — high commission (~$45/trade) erodes gains from monthly rebalancing at this trade frequency
- Equity indices — momentum at 3-month horizon is less persistent than for commodities per MOP (2012) Table 2

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` + `QM_IsNewCalendarPeriod(PERIOD_MN1)` for monthly rebalance |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~10 |
| Typical hold time | ~20 trading days (1 calendar month); shorter if SL hit |
| Expected drawdown profile | ~18% max DD (per card g0_approval); extended adverse trends cause multi-month drawdowns |
| Regime preference | trend-following; performs best during sustained directional gold moves |
| Win rate target (qualitative) | low–medium (trend-following with small average winner multiple) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59`
**Source type:** paper
**Pointer:** Moskowitz, Ooi & Pedersen (2012). "Time series momentum." *Journal of Financial Economics*, 104(2), 228–250. https://www.aqr.com/insights/research/journal-article/time-series-momentum
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12613_tsmom-3m-commodity-xauusd.md`

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
| v1 | 2026-07-02 | Initial build from card | 64162c54-8861-4c2f-8ef3-9b997d5718f9 |
