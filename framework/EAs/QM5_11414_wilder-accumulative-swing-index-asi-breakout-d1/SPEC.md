# QM5_11414_wilder-accumulative-swing-index-asi-breakout-d1 — Strategy Spec

**EA ID:** QM5_11414
**Slug:** `wilder-accumulative-swing-index-asi-breakout-d1`
**Source:** `0ab0a479-4a09-5ecc-bb90-6a37148fa78b` (see `strategy-seeds/sources/0ab0a479-4a09-5ecc-bb90-6a37148fa78b/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA computes J. Welles Wilder's Accumulative Swing Index (ASI) deterministically
from closed D1 OHLC bars. For each bar it derives the Swing Index
`SI = 50 * (N/R) * (K/L)` (N, R, K from the standard Wilder recursion; L is a
limit-move proxy = ATR(14) × multiplier) and accumulates SI into a running ASI series
over a bounded window, cached once per closed bar. Local maxima of ASI are High Swing
Points (HSP, with their bar High = HIP); local minima are Low Swing Points (LSP, with
their bar Low = LOP). The single trade EVENT is an ASI level break: go LONG at market
when ASI crosses above the most-recent prior HSP value; go SHORT at market when ASI
crosses below the most-recent prior LSP value. The stop is the structural INDEX-SAR leg
(LONG = most-recent LSP's LOP; SHORT = most-recent HSP's HIP), capped at a pip limit;
take profit is an RR multiple of the realised stop distance. An opposite ASI level break
closes the position defensively. No external data feed — ASI is pure OHLC arithmetic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 7-28 | ATR period feeding the limit-move (L) proxy |
| `strategy_limit_mult` | 5.0 | 3.0-7.0 | L = ATR × mult (Wilder limit-move proxy; P3 sweep 3/5/7) |
| `strategy_asi_window` | 120 | 40-250 | Closed bars over which ASI is accumulated and scanned |
| `strategy_swing_span` | 1 | 1-3 | Bars each side required to confirm an HSP/LSP pivot (P3 sweep 1/2/3) |
| `strategy_sl_cap_pips` | 100 | 30-200 | Max stop distance in pips (card P2 cap = 100) |
| `strategy_tp_rr` | 2.0 | 1.0-4.0 | Take-profit = RR × realised stop distance |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-40.0 | Block entry only if spread exceeds this % of the stop-cap distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major; clean D1 swings suit a slow ASI breakout.
- `GBPUSD.DWX` — liquid major with persistent D1 trends.
- `USDJPY.DWX` — trending major; ASI composite filters intraday noise well.
- `AUDUSD.DWX` — commodity-linked major with multi-day swing behaviour.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card scopes this build to the four FX majors;
  the ATR-based limit-move proxy is calibrated for FX daily ranges.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 |
| Typical hold time | days (multi-day D1 swings) |
| Expected drawdown profile | moderate; structural stop capped at 100 pips |
| Regime preference | trend / breakout (real-swing continuation) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0ab0a479-4a09-5ecc-bb90-6a37148fa78b`
**Source type:** book
**Pointer:** J. Welles Wilder Jr., *New Concepts in Technical Trading Systems* (Trend Research, 1978), Section VIII: Swing Index System.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11414_wilder-accumulative-swing-index-asi-breakout-d1.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor worktree |
