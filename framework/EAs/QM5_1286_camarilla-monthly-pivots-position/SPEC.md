# QM5_1286_camarilla-monthly-pivots-position — Strategy Spec

**EA ID:** QM5_1286
**Slug:** `camarilla-monthly-pivots-position`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Position-scale Camarilla pivot strategy. At each calendar-month rollover the EA
computes Camarilla levels from the just-closed month's high/low/close
(`H3/H4/L3/L4` and the mid-pivot `P`) and latches ONE of two mutually-exclusive
modes for the whole month based on `range_ratio = month_range / (ATR(20,D1) * 20)`.
If `range_ratio < 0.80` it runs Mode A (Outer Fade): go long when a D1 bar closes
at/below `L3` (short at/above `H3`), targeting the mid-pivot `P`, with a stop just
beyond the outer pivot (`L4 - 0.5*ATR` / `H4 + 0.5*ATR`). If `range_ratio >= 0.80`
it runs Mode B (Outer Break): go long when a D1 bar closes above `H4` (short below
`L4`), initial stop at the inner broken level (`H3` / `L3`), no fixed target — a
Chandelier ATR(20,D1)*3.0 trail engages once price is +1*ATR past entry and a
close beyond the opposite outer pivot invalidates the trend. Both modes: one entry
per symbol per month; Mode A also closes at month-end rollover; a hard 3-calendar-
month time-stop closes any position. All reads are D1-native (the .DWX tester
yields no MN1 bars); the monthly OHLC is aggregated from D1 bars and month
rollover is detected via `QM_CalendarPeriodKey(PERIOD_MN1)`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 5-100 | ATR period on D1 used for range-ratio, Mode A stop buffer, and the Mode B trail |
| `strategy_atr_month_mult` | 20.0 | 5.0-40.0 | Monthly-scale baseline = ATR(period,D1) * this (denominator of range_ratio) |
| `strategy_break_ratio` | 0.80 | 0.30-1.50 | range_ratio >= this selects Mode B (break); below selects Mode A (fade) |
| `strategy_skip_ratio` | 0.50 | 0.10-0.90 | Skip the month (no trades) if range_ratio is below this (degenerate month) |
| `strategy_sl_atr_buffer` | 0.50 | 0.0-3.0 | Mode A stop buffer beyond L4/H4, in ATR units |
| `strategy_chandelier_mult` | 3.00 | 1.0-6.0 | Mode B Chandelier trailing stop distance = ATR(period,D1) * this |
| `strategy_trail_engage_mult` | 1.00 | 0.0-3.0 | Mode B trail engages once price is +ATR*this past entry |
| `strategy_time_stop_months` | 3 | 1-12 | Hard time-stop: close any open position after N calendar months from entry |
| `strategy_max_spread_points` | 50 | 0-1000 | Block a genuinely wide spread only (points); .DWX models 0 spread (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; clean monthly ranges for Camarilla levels
- `GBPUSD.DWX` — liquid FX major with pronounced monthly trends (Mode B)
- `USDJPY.DWX` — FX major; monthly mean-reversion + breakout both present
- `AUDUSD.DWX` — commodity FX major; distinct monthly regime behaviour
- `XAUUSD.DWX` — gold; strong monthly trend/breakout character (Mode B fit)
- `NDX.DWX` — Nasdaq 100 index CFD; monthly momentum continuation
- `WS30.DWX` — Dow 30 index CFD; monthly range/break structure
- `GDAXI.DWX` — DAX 40 index CFD; EU index with clean monthly pivots
- `UK100.DWX` — FTSE 100 index CFD; EU index, monthly range trading

**Explicitly NOT for:**
- Ultra-low-liquidity exotics / synthetic symbols — monthly pivots need a
  reliable, gap-clean D1 series (all nine registered symbols qualify).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Monthly pivots aggregated D1-native via `QM_CalendarPeriodKey(PERIOD_MN1)`; ATR(20) on D1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~5` |
| Typical hold time | `days to weeks` (Mode A intra-month; Mode B up to 3 months) |
| Expected drawdown profile | `~22% max DD; position-scale, one position per symbol` |
| Regime preference | `mean-revert (Mode A, low-vol months) + breakout (Mode B, high-vol months)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/` — ForexFactory Camarilla Equation community cluster (monthly-anchoring variant); underlying formula Nick Stott, *Stocks & Commodities* 1989.
**R1–R4 verdict (Q00):** R1 TIER_C / R2–R4 PASS — R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_1286_camarilla-monthly-pivots-position.md`

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
| v1 | 2026-08-10 | Initial build from card | 7c9876b2-de27-43bf-8553-8b5543f5c589 |
