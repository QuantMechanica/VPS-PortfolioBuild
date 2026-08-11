# QM5_12499_dual-thrust — Strategy Spec

**EA ID:** QM5_12499
**Slug:** `dual-thrust`
**Source:** `46758070-d6b1-52ef-a3ee-ffcbffb7bb54` (see `strategy-seeds/sources/46758070-d6b1-52ef-a3ee-ffcbffb7bb54/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Classic Dual Thrust opening-range breakout. During the card's London reference
window (03:00-12:00 EST, tracked in broker time), the EA accumulates the
session's running high and low. When the session ends, that (high, low, close)
triple is pushed into a rolling buffer of the last `range_days` completed
sessions. At the first bar of a fresh session, once enough history exists, the
EA computes `range1 = highest_session_high - lowest_session_close`,
`range2 = highest_session_close - lowest_session_low`, `range =
max(range1, range2)`, then sets `upper = session_open + param * range` and
`lower = session_open - (1-param) * range`. A live ask trading above `upper`
opens a long; a live bid trading below `lower` opens a short (one position at
a time). The opposite threshold being breached while in a position closes it
immediately (reversal), and any open position is flattened once the session
window ends, mirroring the source's end-of-day clear. The source carries no
stop before session close; V5 adds an ATR(D1) hard stop for platform risk.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_days` | 5 | 3-10 | Rolling sessions used to build the breakout range |
| `strategy_range_param` | 0.5 | 0.35-0.65 | K: `upper=open+K*range`, `lower=open-(1-K)*range` |
| `strategy_session_start_hour_est` | 3 | 2-4 | Session open reference, US Eastern hour |
| `strategy_session_end_hour_est` | 12 | 11-13 | Session close/flatten reference, US Eastern hour |
| `strategy_atr_period` | 14 | fixed | ATR(D1) period for the platform-risk hard stop |
| `strategy_atr_stop_mult` | 2.5 | 1.5-3.0 | Stop distance = mult * ATR(D1) |
| `strategy_spread_pct_of_stop` | 15.0 | fixed | Block entries only if spread > this % of the ATR stop distance |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for (card's target list, all present in `dwx_symbol_matrix.csv`):**
- `EURUSD.DWX` — liquid FX major, matches source's GBPUSD-style M1 FX data
- `GBPUSD.DWX` — the source's own reference instrument (London-session breakout)
- `USDJPY.DWX` — liquid FX major, London/NY overlap volatility
- `NDX.DWX` — Nasdaq 100 index CFD, intraday range-expansion behaviour
- `WS30.DWX` — Dow 30 index CFD, intraday range-expansion behaviour

**Explicitly NOT for:**
- Any symbol outside `dwx_symbol_matrix.csv` — card gave an explicit 5-symbol
  target list; no additional porting was needed.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `PERIOD_D1` for the ATR(D1) hard-stop reference only |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default, M1) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~100 (card frontmatter `expected_trades_per_year_per_symbol`) |
| Typical hold time | Intraday (minutes to ~9 hours, session-bounded) |
| Expected drawdown profile | Whipsaw risk in compressed/choppy sessions; ATR stop bounds per-trade loss |
| Regime preference | breakout / range-expansion |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `46758070-d6b1-52ef-a3ee-ffcbffb7bb54`
**Source type:** other (public GitHub repository)
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/Dual%20Thrust%20backtest.py
**R1-R4 verdict (Q00):** all PASS; R1 lineage recorded and R2-R4 PASS per `artifacts/cards_approved/QM5_12499_dual-thrust.md`

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
| v1 | 2026-08-10 | Initial build from card (rebuild-in-place over a stale pre-audit draft that lacked Q08 MAE sampling and used full-D1 range instead of session-window range) | af8c9f43-a179-48fc-8a26-81001e6538f3 |
