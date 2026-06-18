# QM5_11336_tc20-h1-11-ema5shift-75ema-bb-rsi14 — Strategy Spec

**EA ID:** QM5_11336
**Slug:** `tc20-h1-11-ema5shift-75ema-bb-rsi14`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On the close of each H1 bar the EA looks for a single trigger: a forward-shifted
EMA(5) (the "5EMA shift=5", read by adding the 5-bar ma-shift to the bar offset)
crossing the EMA(75). An upward cross arms a LONG; a downward cross arms a SHORT.
The cross only becomes a trade when three trend/momentum STATES agree on the last
closed bar: for a long, the close is above EMA(75), above the Bollinger(20,2)
middle band, and RSI(14) is above 50 (mirror for shorts). The single cross EVENT
plus three confirming STATES avoids the two-cross-same-bar zero-trade trap.

Stop-loss is placed 2 pips beyond EMA(75) on the signal bar (card P2
simplification), capped so the stop distance never exceeds 1.5×ATR(14). Take
profit is a fixed multiple (default 2×) of the stop distance. Positions exit only
on stop or target — no discretionary exit. One position per magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 5 | 3-20 | Fast EMA period |
| `strategy_ema_fast_shift` | 5 | 0-20 | Forward ma-shift of the fast EMA (the "shift=5") |
| `strategy_ema_slow_period` | 75 | 30-200 | Slow EMA period — trend level |
| `strategy_bb_period` | 20 | 10-30 | Bollinger period (middle band = SMA) |
| `strategy_bb_deviation` | 2.0 | 1.0-3.0 | Bollinger deviation (state filter) |
| `strategy_rsi_period` | 14 | 7-28 | RSI period |
| `strategy_rsi_level` | 50.0 | 40-60 | RSI momentum threshold |
| `strategy_sl_buffer_pips` | 2.0 | 0-20 | SL distance beyond EMA75, in pips |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the SL cap |
| `strategy_atr_sl_cap_mult` | 1.5 | 0.5-4.0 | SL distance capped at this × ATR |
| `strategy_tp_rr` | 2.0 | 0.5-4.0 | TP = this × SL distance (1× or 2× per card) |
| `strategy_spread_pct_of_stop` | 20.0 | 1-100 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card primary; deep liquidity, tight spreads, clean H1 trends.
- `GBPUSD.DWX` — card P2 basket; trending major with comparable EMA/RSI behaviour.
- `USDJPY.DWX` — card P2 basket; trending major, pip-scale handled via pip_factor.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card is a 1-hour forex strategy; EMA75/BB/RSI
  levels were calibrated on FX majors, not gapless index CFDs.

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
| Trades / year / symbol | `~80` |
| Typical hold time | `hours (intraday to ~1 day on H1)` |
| Expected drawdown profile | `moderate; trend-follow with fixed ATR-capped stop` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Strategy #11 (local PDF: `376863900-20-Forex-Trading-Strategies-Collection.pdf`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11336_tc20-h1-11-ema5shift-75ema-bb-rsi14.md`

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
