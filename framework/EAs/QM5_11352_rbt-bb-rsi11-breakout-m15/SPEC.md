# QM5_11352_rbt-bb-rsi11-breakout-m15 — Strategy Spec

**EA ID:** QM5_11352
**Slug:** `rbt-bb-rsi11-breakout-m15`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (see `strategy-seeds/sources/ed246754-1f4d-5bed-8dd3-3b5cbf1b420d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

A Bollinger Band breakout with RSI momentum confirmation on M15 is traded as a
momentum continuation signal, not a reversal. A LONG can fire when current price
is above the BB(20,2) upper band, RSI(11) on the last closed bar is above 70,
ADX(14) is above 20, and Bollinger width is expanding versus the prior closed
bar. The SHORT is the mirror: current price below the BB lower band with RSI(11)
below 30, ADX above 20, and expanding band width. P2 stop placement uses
ATR(14) x 1.0, with the card's fixed 15-pip stop also exposed as an alternate
input; take-profit is the card's fixed 20-pip target. A position is also closed
early if RSI(11) fades back through 50. Trading is restricted to the London+NY
session (13:00-22:00 UTC) with a 5-pip spread cap that fails open on the .DWX
zero-spread tester.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10-50 | Bollinger Bands period |
| `strategy_bb_deviation` | 2.0 | 1.0-3.0 | Bollinger Bands standard-deviation multiple |
| `strategy_rsi_period` | 11 | 8-14 | RSI lookback period |
| `strategy_rsi_long_level` | 70.0 | 60-80 | RSI must exceed this for a LONG breakout |
| `strategy_rsi_short_level` | 30.0 | 20-40 | RSI must be below this for a SHORT breakout |
| `strategy_rsi_exit_level` | 50.0 | 40-60 | RSI fade-to-midline exit threshold |
| `strategy_adx_period` | 14 | 10-20 | ADX period (trend-vs-range filter) |
| `strategy_adx_min` | 20.0 | 15-30 | Require ADX above this (trending) |
| `strategy_use_atr_stop` | true | true/false | Use P2 ATR stop when true; fixed pip stop when false |
| `strategy_atr_period` | 14 | 8-30 | ATR stop period |
| `strategy_atr_sl_mult` | 1.0 | 0.5-3.0 | ATR stop multiplier |
| `strategy_sl_pips` | 15 | 8-40 | Alternate fixed stop distance, pips |
| `strategy_tp_pips` | 20 | 10-60 | Fixed take-profit distance, pips |
| `strategy_spread_cap_pips` | 5.0 | 1-15 | Block only if spread exceeds this many pips |
| `strategy_session_start_utc` | 13 | 0-23 | Session window start hour, UTC (inclusive) |
| `strategy_session_end_utc` | 22 | 0-23 | Session window end hour, UTC (exclusive) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity major; London+NY session aligns with its highest-volatility window.
- `GBPUSD.DWX` — high-range major, responsive to London/NY breakouts.
- `AUDUSD.DWX` — liquid commodity-major; carries breakout follow-through in trend regimes.
- `USDJPY.DWX` — liquid major; pip-scale handled by the 3-digit-aware pip helper.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the card specifies the M15 FX-major basket; pip
  sizing and the 13:00–22:00 UTC session window are calibrated for FX, not indices.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~200` |
| Typical hold time | `minutes to a few hours (intraday M15)` |
| Expected drawdown profile | `breakout strategy — frequent small stops, occasional momentum runs` |
| Regime preference | `breakout / volatility-expansion` |
| Win rate target (qualitative) | `low/medium (RR>1 target offsets sub-50% hit rate)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** `paper` (institutional strategy-collection PDF, RoboForex)
**Pointer:** `strategy-seeds/sources/ed246754-1f4d-5bed-8dd3-3b5cbf1b420d/` (RoboForex "Strategy Bollinger Bands and RSI", M15)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11352_rbt-bb-rsi11-breakout-m15.md`

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
| v1 | 2026-06-20 | Initial build from card | 5218fa99-a4e8-4e9f-b2aa-63befbd9963d |
