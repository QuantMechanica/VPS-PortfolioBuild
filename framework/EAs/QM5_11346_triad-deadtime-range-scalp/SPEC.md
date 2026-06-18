# QM5_11346_triad-deadtime-range-scalp — Strategy Spec

**EA ID:** QM5_11346
**Slug:** `triad-deadtime-range-scalp`
**Source:** `581facd5-aecc-5b86-8121-1eaa3eaf1a45` (see `strategy-seeds/sources/581facd5-aecc-5b86-8121-1eaa3eaf1a45/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A dead-time range mean-reversion fade on H1 forex. During the lowest-liquidity US
hours (3pm-5pm ET — the two H1 bars opening at 15:00 and 16:00 ET) the EA records
a range: `range_high`/`range_low` = the max/min of those two CLOSED bars, and
`range_mid` = (high + low) / 2. The window is located from each bar's TIMESTAMP
converted to US-Eastern time with the DST-aware broker→UTC helpers, never a fixed
wall-clock. From the 5pm-ET arm bar through the 9pm-ET cutoff, on each new closed
H1 bar the EA fades price back toward the midpoint: if the prior close is below
`range_mid` it BUYs, if above it SELLs. Take-profit is `range_mid`; stop-loss is a
fixed 12-pip distance (scale-correct for 5-digit / JPY). Trades are skipped when
the range is degenerate (< 5 pips) or too volatile (> 40 pips). Maximum one trade
per session; any open position is force-closed at/after the 9pm-ET bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_start_et_hour` | 15 | 0-23 | ET bar-open hour of the first dead-time range bar (3pm ET) |
| `strategy_range_bars` | 2 | 1-4 | Number of H1 bars composing the dead-time range |
| `strategy_active_start_et_hour` | 17 | 0-23 | ET hour the fade window arms (5pm ET) |
| `strategy_active_end_et_hour` | 21 | 0-23 | ET hour the session hard-closes (9pm ET) |
| `strategy_sl_pips` | 12 | 5-40 | Fixed stop-loss distance in pips |
| `strategy_min_range_pips` | 5 | 1-20 | Skip session if range width below this (degenerate) |
| `strategy_max_range_pips` | 40 | 20-100 | Skip session if range width above this (too volatile) |
| `strategy_spread_pct_of_stop` | 25.0 | 0-100 | Block entry if spread exceeds this % of the stop distance (fail-open on zero spread) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deepest FX pair; the 3pm-5pm ET dead-time genuinely de-liquidates after the NY equity close, producing mean-reverting ranges.
- `GBPUSD.DWX` — same post-NY dead-time regime; slightly wider ranges suit the 12-pip stop.
- `USDJPY.DWX` — Tokyo not yet open during 3pm-5pm ET, so the window is a true low-liquidity gap; pip scaling handled via `QM_StopRulesPipsToPriceDistance`.

**Explicitly NOT for:**
- Index/metal `.DWX` symbols — the strategy is calibrated to FX intraday liquidity rhythm and pip-based 12-pip stops; index point scales would mis-size the range filters.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~150` |
| Typical hold time | `1-4 hours (intraday, closes by 9pm ET)` |
| Expected drawdown profile | `shallow, frequent small wins/losses at 1:~1 R toward midpoint` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `581facd5-aecc-5b86-8121-1eaa3eaf1a45`
**Source type:** `book`
**Pointer:** Jason Fielder, "Triad Cheat Sheets", Cheat Sheet #1 Strategy #2 — Dead-Time Range Scalping (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11346_triad-deadtime-range-scalp.md`

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
