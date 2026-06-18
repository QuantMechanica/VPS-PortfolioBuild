# QM5_11425_williams-smash-day-stop-entry-d1 — Strategy Spec

**EA ID:** QM5_11425
**Slug:** `williams-smash-day-stop-entry-d1`
**Source:** `bb9e26af-ebd1-5a26-b1a8-cc4d78835f03` (Larry Williams, Inner Circle Workshop Trading Method)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Trades Larry Williams' "Smash Day" reversal on D1 closed-bar candle geometry. A
Smash Day is a single completed prior bar (shift 1) that expands its range in one
direction relative to the bar before it (shift 2) yet closes against that
expansion within its own body. Buy case: the prior bar made a higher high, higher
low and higher close than its predecessor, but its own body is substantially
bearish (`Open[1] - Close[1] >= 0.33 × (High[1] - Low[1])`) — a bullish trap. On
the next D1 bar the EA arms a BUY STOP at `High[1] + 1 pip`; stop-loss at
`Low[1] - 1 pip`, take-profit at 2× the entry-to-stop risk. The sell case is the
exact mirror (lower high/low/close with a substantially bullish body → SELL STOP
at `Low[1] - 1 pip`). The pending order is day-only and expires after one D1
window if unfilled; each new closed bar cancels the stale level and re-detects
the pattern. All four geometry comparisons reference values inside the two prior
closed bars, so the rule is gapless-safe on .DWX CFDs.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_body_ratio` | 0.33 | 0.25-0.50 | Min body size as a fraction of the bar's range (the "substantial close" threshold) |
| `strategy_entry_buffer_pips` | 1 | 1-5 | Stop-entry offset beyond the prior bar high/low, in pips |
| `strategy_sl_cap_pips` | 80 | 40-120 | Max stop distance from entry (card P2 cap), in pips |
| `strategy_tp_rr` | 2.0 | 1.5-3.0 | Take-profit as a multiple of the entry→SL risk distance |
| `strategy_min_range_pips` | 15 | 5-30 | Skip degenerate small smash bars (min bar[1] range) |
| `strategy_spread_pct_of_stop` | 25.0 | 10-50 | Skip only if spread > this % of the stop distance (fail-open on zero spread) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; clean D1 OHLC, tight spread vs the 25-pip cap.
- `GBPUSD.DWX` — liquid major with wider D1 range, suits the range-expansion pattern.
- `USDJPY.DWX` — liquid major; pip-scaling handled via `QM_StopRulesPipsToPriceDistance`.
- `AUDUSD.DWX` — liquid commodity-linked major; adds reversal-pattern diversification.

**Explicitly NOT for:**
- Index / metal / energy `.DWX` symbols — the card scopes this strategy to the four FX majors above.

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
| Trades / year / symbol | `~30` |
| Typical hold time | `1-5 days` (fixed 2R target or pattern stop) |
| Expected drawdown profile | `moderate; reversal entries with capped 80-pip stops` |
| Regime preference | `reversal / volatility-expansion exhaustion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `bb9e26af-ebd1-5a26-b1a8-cc4d78835f03`
**Source type:** `book`
**Pointer:** Larry Williams, "Inner Circle Workshop Trading Method" (local library record)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11425_williams-smash-day-stop-entry-d1.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
