# QM5_11367_caroline-ayuk-lwma-osma-fractal-d1 — Strategy Spec

**EA ID:** QM5_11367
**Slug:** `caroline-ayuk-lwma-osma-fractal-d1`
**Source:** `e412d487-768d-5e8c-ad95-208ff9ce6094` (see `strategy-seeds/sources/e412d487-768d-5e8c-ad95-208ff9ce6094/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Daily-bar (D1) end-of-day swing system from Caroline Ayuk. The trend STATE is a
two-LWMA stack: a fast LWMA(8) on Close and a slow LWMA(10) on Open with a one-bar
MA-shift. Long state requires the closed bar's Low above the slow LWMA, the fast
LWMA above the slow LWMA, and the OsMA histogram (MACD 12/26/9 main minus signal,
which can be negative) non-negative; short state mirrors. The single trigger EVENT
is either an OsMA zero-cross in the trade direction OR a price break of the last
confirmed Bill Williams fractal (up-fractal for longs, down-fractal for shorts).
Fractals are read only on closed bars (shift >= 3, two bars right of the pivot) so
they are confirmed and non-repainting. On a long signal, if Close is within the
pending threshold (60 pips) of the fast LWMA the EA buys at market on the next bar
open, otherwise it places a BUY STOP at fast-LWMA + 60 pips. The initial stop is
the low of the last down fractal (capped at 80 pips); take-profit is 1.5x the stop
distance. Management moves to breakeven+5 pips after price travels 0.5x SL in
favour, then locks 0.5x SL of profit after 1.0x SL. An opposite setup state closes
the position immediately. One position per symbol per magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lwma_fast_period` | 8 | 4-20 | Fast LWMA period on Close |
| `strategy_lwma_slow_period` | 10 | 6-30 | Slow LWMA period on Open (MA-shift 1) |
| `strategy_macd_fast` | 12 | 5-20 | OsMA fast EMA (MACD fast) |
| `strategy_macd_slow` | 26 | 20-40 | OsMA slow EMA (MACD slow) |
| `strategy_macd_signal` | 9 | 3-15 | OsMA signal EMA (MACD signal) |
| `strategy_entry_pending_pips` | 60 | 30-120 | Market-vs-pending threshold and pending offset from fast LWMA |
| `strategy_sl_max_pips` | 80 | 40-150 | Cap on the fractal-based stop distance |
| `strategy_fractal_scan_bars` | 60 | 20-200 | How many closed bars back to scan for the last fractal |
| `strategy_tp_rr` | 1.5 | 1.0-3.0 | Take-profit as a multiple of the stop distance |
| `strategy_be_trigger_frac` | 0.5 | 0.2-1.0 | Move to breakeven once price moves this fraction of SL in favour |
| `strategy_be_buffer_pips` | 5 | 0-20 | Breakeven offset (BE + this many pips) |
| `strategy_trail_trigger_frac` | 1.0 | 0.5-2.0 | Lock-in once price moves this fraction of SL in favour |
| `strategy_lock_frac` | 0.5 | 0.1-1.0 | Profit locked (fraction of SL) when trailing |
| `strategy_spread_pct_of_stop` | 25.0 | 5-50 | Skip if spread exceeds this percent of the stop budget |
| `strategy_pending_expiry_sec` | 86400 | 3600-604800 | Pending order lifetime (1 D1 bar) |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — card primary; high-volatility major suited to wide D1 swing stops
- `EURUSD.DWX` — most liquid major; clean LWMA trends on D1
- `USDJPY.DWX` — JPY major; pip-scale handled via `QM_StopRulesPipsToPriceDistance`
- `GBPJPY.DWX` — high-range cross; produces clear fractal structure on D1
- `AUDUSD.DWX` — commodity major; complements the USD/JPY exposure for diversification

**Explicitly NOT for:**
- Index / metal CFDs — the 60/80-pip thresholds are FX-pip calibrated; index point scales differ.

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
| Trades / year / symbol | `~25` |
| Typical hold time | `several days (multi-day swing)` |
| Expected drawdown profile | `moderate; wide fractal stops, infrequent trades` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e412d487-768d-5e8c-ad95-208ff9ce6094`
**Source type:** `book`
**Pointer:** Caroline Ayuk, "Proven Forex Trading Money Making Strategy — Just 15 Minutes a Day" (local PDF cited in card frontmatter)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11367_caroline-ayuk-lwma-osma-fractal-d1.md`

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
