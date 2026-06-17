# QM5_11101_mp-value-break — Strategy Spec

**EA ID:** QM5_11101
**Slug:** `mp-value-break`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex MarketProfile GitHub)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Prior-session Market Profile value-area breakout (continuation) on M30. The Market
Profile is built from the symbol's OWN intraday M30 bars over the prior completed
broker-time day (tick-volume TPO/price-histogram proxy, bounded and deterministic,
recomputed once per new broker-day on the closed-bar gate — no external profile
feed). From that histogram the EA derives the prior-session POC (highest-volume
bucket) and the 70% value area (VAH/VAL expanded symmetrically around the POC).

Long when a completed M30 bar closes at least `0.10 * ATR(14)` ABOVE the prior VAH;
short when it closes the same buffer BELOW the prior VAL. No entry before the first
two completed M30 bars of the session, and at most one entry per value-area side per
session. Stop loss sits at the opposite value-area edge (long → prior VAL, short →
prior VAH), capped at `2.5 * ATR` from entry. Exit on close back inside the value
area (POC/median failure), on an opposite value-area break, or after 8 M30 bars
(time stop), whichever comes first. Sessions are skipped when the prior value-area
width is below `0.75 * ATR` or above `4.0 * ATR`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_value_area_pct` | 70.0 | 60-80 | Value-area coverage percent (EarnForex default 70) |
| `strategy_va_bucket_ticks` | 5 | 1-50 | Price-bucket size in symbol ticks (histogram granularity) |
| `strategy_va_max_buckets` | 2000 | 200-5000 | Hard cap on histogram buckets (bounded-loop guard) |
| `strategy_atr_period` | 14 | 7-28 | M30 ATR period for buffer/stop/width filter |
| `strategy_breakout_buffer_atr` | 0.10 | 0.05-0.40 | Min break beyond VAH/VAL in ATR (card 0.10) |
| `strategy_sl_cap_atr` | 2.5 | 1.5-3.5 | SL cap from entry in ATR (card P2 2.5) |
| `strategy_tp_rr` | 3.0 | 1.5-5.0 | Structural TP as R-multiple of capped SL distance |
| `strategy_va_min_atr` | 0.75 | 0.5-1.5 | Skip session if VA width < this * ATR (card 0.75) |
| `strategy_va_max_atr` | 4.0 | 2.0-6.0 | Skip session if VA width > this * ATR (card 4.0) |
| `strategy_min_session_bars` | 2 | 1-6 | No entry before first N completed M30 bars of session |
| `strategy_max_hold_bars` | 8 | 4-16 | Time-stop after N completed M30 bars (card 8) |
| `strategy_session_start_hour` | 9 | 0-23 | Session start, BROKER time (~London 08:00 UTC) |
| `strategy_session_end_hour` | 22 | 0-23 | Session end, BROKER time (through NY) |
| `strategy_spread_pct_of_stop` | 25.0 | 10-100 | Skip only genuinely wide spread (% of stop distance) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity FX major; clean intraday value areas, frequent VA breaks.
- `GBPUSD.DWX` — volatile FX major; well-defined London/NY value areas suit breakouts.
- `XAUUSD.DWX` — gold; strong intraday trends that extend cleanly beyond prior VA.
- `GDAXI.DWX` — DAX 40 index CFD; session-driven value areas, continuation-friendly.

**Explicitly NOT for:**
- Monthly/weekly-only instruments — this is an intraday M30 session strategy.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — no tick data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `none` (prior-day profile built from same-symbol M30 bars) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~35` |
| Typical hold time | `up to 8 M30 bars (~4h), intraday` |
| Expected drawdown profile | `moderate; breakout failures stopped at opposite VA edge / time` |
| Regime preference | `breakout / volatility-expansion (continuation out of value)` |
| Win rate target (qualitative) | `low/medium (breakout continuation, capped losses)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum/repo` (EarnForex MarketProfile MQL5 indicator + README)
**Pointer:** `https://github.com/EarnForex/MarketProfile`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11101_mp-value-break.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor worktree |
