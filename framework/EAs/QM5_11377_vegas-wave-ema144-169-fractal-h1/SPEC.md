# QM5_11377_vegas-wave-ema144-169-fractal-h1 — Strategy Spec

**EA ID:** QM5_11377
**Slug:** `vegas-wave-ema144-169-fractal-h1`
**Source:** `c2622cef-77e4-5653-b39e-8ae8f69221d3` (see `strategy-seeds/sources/c2622cef-77e4-5653-b39e-8ae8f69221d3/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EMA(144) and EMA(169) form a "Vegas tunnel" on H1 — this stack is the TREND
STATE. A trade is armed only when the last closed bar breaks clear of the tunnel:
LONG state when the bar CLOSES ABOVE EMA(169), SHORT state when it CLOSES BELOW
EMA(144). The single entry EVENT is a freshly-confirmed Williams fractal. In the
LONG state, a DOWN fractal (a local low with `side` higher lows on each side)
triggers a BUY STOP placed one pip above that fractal bar's high; in the SHORT
state, an UP fractal triggers a SELL STOP one pip below that fractal bar's low.
The pivot is evaluated at the bar `side`+1 back so its right-hand confirming bars
already exist, giving exactly one event per bar (no two-cross-same-bar zero-trade
trap). The pending order expires after 4 H1 candles if not triggered. Stop loss
is the opposite EMA boundary at placement (EMA169 for long, EMA144 for short),
capped at 30 pips. Take profit is ATR(14) × 5 from the entry; the stop is moved
to break-even once price travels ATR(14) × 3 in favour. Trading is restricted to
broker hours 08:00–19:00 (London + NY).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 144 | 100-200 | Vegas tunnel fast EMA; SHORT-side boundary |
| `strategy_ema_slow_period` | 169 | 120-220 | Vegas tunnel slow EMA; LONG-side boundary |
| `strategy_fractal_side_bars` | 2 | 2-3 | Williams fractal bars required on each side |
| `strategy_atr_period` | 14 | 7-21 | ATR period for TP and break-even distances |
| `strategy_tp_atr_mult` | 5.0 | 2.0-6.0 | Take-profit distance = mult × ATR (runner target) |
| `strategy_be_atr_mult` | 3.0 | 2.0-5.0 | Move SL to break-even after price moves mult × ATR |
| `strategy_entry_buffer_pips` | 1.0 | 0.5-3.0 | Stop-trigger offset beyond the fractal extreme (pips) |
| `strategy_sl_max_pips` | 30.0 | 15-50 | P2 cap on the EMA-boundary stop distance (pips) |
| `strategy_pending_bars` | 4 | 2-8 | Cancel the pending stop order after N H1 candles |
| `strategy_session_start_hr` | 8 | 0-23 | Session open, broker hour (inclusive) |
| `strategy_session_end_hr` | 19 | 0-23 | Session close, broker hour (exclusive) |
| `strategy_spread_cap_pips` | 20.0 | 5-40 | Block only a genuinely wide spread (pips); fail-open on zero |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary; deep liquidity, clean H1 tunnel/fractal structure
- `GBPUSD.DWX` — primary; trending major with reliable session breakouts
- `USDJPY.DWX` — secondary; JPY pip-scaling handled via digit-aware pip size
- `GBPJPY.DWX` — secondary; high-volatility cross suits the ATR runner target

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the EMA(144/169) tunnel and pip-scaled
  buffers are calibrated to FX majors, not index point structure.

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
| Trades / year / symbol | `~60` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `moderate; trend-following with capped 30-pip stops` |
| Regime preference | `breakout` |
| Win rate target (qualitative) | `low-medium (asymmetric ATR×5 runner)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c2622cef-77e4-5653-b39e-8ae8f69221d3`
**Source type:** `forum`
**Pointer:** `Anonymous ("Vegas"), "Forex Strategy Vegas Wave", ForexFactory ~2004-2006 / local PDF archive [[sources/dropbox-forex-pdf-archive]]`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11377_vegas-wave-ema144-169-fractal-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | pending central-step compile |
