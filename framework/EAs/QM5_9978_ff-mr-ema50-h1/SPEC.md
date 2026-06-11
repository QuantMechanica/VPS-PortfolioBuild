# QM5_9978_ff-mr-ema50-h1 - Strategy Spec

**EA ID:** QM5_9978
**Slug:** `ff-mr-ema50-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the ForexFactory Mr EMA50 H1 continuation setup. A long setup requires the bar two bars ago to open at or below EMA(50), the prior bar to be the first open above EMA(50), and that prior open to sit 10-20 pips above EMA(50); the current H1 bar must also open above EMA(50). Shorts mirror the same second-open rule below EMA(50). The EA enters at market on the current H1 bar, uses a fixed 20-pip stop widened only when broker stop-distance rules require it, trails by 8 pips after a 10-pip favorable move, exits on the opposite second-open setup, and applies a 24-bar emergency time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 required by card | Base timeframe for EMA and second-open checks. |
| `strategy_ema_period` | `50` | `>0` | EMA period used for the side transition. |
| `strategy_min_first_open_distance_pips` | `10` | `>0` | Minimum distance from first crossing bar open to EMA50. |
| `strategy_max_first_open_distance_pips` | `20` | `>= min` | Maximum accepted first crossing bar distance from EMA50. |
| `strategy_invalid_distance_pips` | `40` | `>0` | Explicit invalidation threshold from the source card. |
| `strategy_stop_pips` | `20` | `>0` | Initial hard stop in pips before broker minimum widening. |
| `strategy_min_stop_buffer_pips` | `2` | `>=0` | Buffer added above broker minimum stop distance when widening. |
| `strategy_trail_trigger_pips` | `10` | `>0` | Favorable move required before trailing starts. |
| `strategy_trail_distance_pips` | `8` | `>0` | Distance of the trailing stop behind price. |
| `strategy_time_stop_bars` | `24` | `>0` | Maximum H1 holding period before emergency exit. |
| `strategy_max_spread_pips` | `2.5` | `>0` | Maximum entry spread for FX majors. |
| `strategy_max_spread_stop_frac` | `0.08` | `>0` | Maximum spread as a fraction of stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX FX major with H1 OHLC and EMA support.
- `GBPUSD.DWX` - card-listed DWX FX major with H1 OHLC and EMA support.
- `USDJPY.DWX` - card-listed DWX FX major with H1 OHLC and EMA support.
- `AUDUSD.DWX` - card-listed DWX FX major with H1 OHLC and EMA support.

**Explicitly NOT for:**
- Index, metal, energy, and non-listed FX symbols - the approved R3 basket is limited to the four named FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | Minutes to 24 H1 bars; hard cap at 24 bars. |
| Expected drawdown profile | Small fixed-stop losses around 20 pips per trade, with trailing exits once price advances. |
| Regime preference | Trend-continuation after EMA50 side transition. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/317054-introducing-mr-ema50-system`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9978_ff-mr-ema50-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 5ad8e35f-52db-4e10-89e4-2d5de1737933 |
