# QM5_9463_gh-macd-zero — Strategy Spec

**EA ID:** QM5_9463
**Slug:** `gh-macd-zero`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On every closed H1 bar the EA computes the MACD histogram (main line minus signal line) using standard defaults (fast 12, slow 26, signal 9, close price). A long trade opens when the histogram crosses above zero: the prior closed bar had histogram ≤ 0 and the current closed bar has histogram > 0. A short trade opens when the histogram crosses below zero: prior bar ≥ 0 and current bar < 0. One position per magic is enforced by the framework. The position closes when the MACD signal line crosses back past the main line (signal > main for longs, signal < main for shorts). Stop-loss is placed at entry price ± ATR(14) × 2.0; no take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 2–200 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 2–500 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 1–100 | MACD signal line period |
| `strategy_atr_period` | 14 | 1–100 | ATR period for stop-loss sizing |
| `strategy_atr_sl_mult` | 2.0 | 0.5–10.0 | ATR multiplier applied to stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; H1 MACD zero-cross captures intraday momentum trends
- `GBPUSD.DWX` — correlated major FX pair; similar liquidity profile to EURUSD
- `XAUUSD.DWX` — gold; trending commodity with reliable MACD momentum signals
- `GDAXI.DWX` — DAX 40 index; substituted for card-listed GER40.DWX which is absent from the DWX symbol matrix; GDAXI.DWX is the canonical DAX symbol

**Explicitly NOT for:**
- `GER40.DWX` — not in dwx_symbol_matrix.csv; ported to GDAXI.DWX (see open_questions)

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
| Trades / year / symbol | ~45 |
| Typical hold time | hours to 1-3 days |
| Expected drawdown profile | moderate; ATR-based SL limits single-trade loss |
| Regime preference | momentum / trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub repository
**Pointer:** https://github.com/pipbolt/experts/blob/master/experts/MACD-EA.mq5
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9463_gh-macd-zero.md`

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
| v1 | 2026-06-11 | Initial build from card | 9ee4f2f4-322e-41f6-821d-fbbed9ab0af3 |
