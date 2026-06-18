# QM5_11383_blade-m5-ema-zone-scalper — Strategy Spec

**EA ID:** QM5_11383
**Slug:** `blade-m5-ema-zone-scalper`
**Source:** `f4fa8966-3aa0-5df0-9d8f-3872df92309a` (see `strategy-seeds/sources/f4fa8966-3aa0-5df0-9d8f-3872df92309a/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Three-EMA M5 trend-pullback scalp. EMA(50) sets trend direction, EMA(10)/EMA(21)
form a "zone". In a confirmed uptrend (last closed bar's close above EMA(50) and
EMA(50) rising over the slope lookback), the EA waits for price to pull back INTO
the zone: a long fires when the closed bar's LOW dips at/below EMA(10) while its
CLOSE holds at/above EMA(21), AND the prior bar closed above the zone top (a fresh
retrace, so one trend pullback fires exactly once). Shorts are the mirror in a
falling-EMA(50) downtrend (high reaches EMA(10), close holds below EMA(21), prior
close below the zone bottom). Exit is a fixed 10-pip take-profit or a 5-pip stop,
with the stop pulled to break-even once price is +5 pips. Trading is restricted to
the London+NY block (08:00–22:00 GMT, broker time converted via QM_BrokerToUTC);
no Asian session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_zone_fast` | 10 | 5-20 | EMA(10) fast zone edge |
| `strategy_ema_zone_slow` | 21 | 13-34 | EMA(21) slow zone edge / close-hold side |
| `strategy_ema_trend` | 50 | 34-100 | EMA(50) trend + slope filter |
| `strategy_slope_lookback` | 10 | 3-20 | EMA(50) slope proxy: shift 1 vs shift 1+this |
| `strategy_sl_pips` | 5 | 3-10 | Stop loss, fixed pips from entry (P2 cap 10) |
| `strategy_tp_pips` | 10 | 6-15 | Take profit, fixed pips from entry |
| `strategy_be_trigger_pips` | 5 | 3-10 | Move SL to break-even at +this many pips |
| `strategy_session_start_utc` | 8 | 0-23 | London open hour (UTC) |
| `strategy_session_end_utc` | 22 | 0-23 | NY close hour (UTC) |
| `strategy_spread_pct_of_stop` | 50.0 | 10-200 | Skip only if spread > this % of stop distance (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary; tightest spread, ideal for the 10-pip TP scalp (card primary).
- `GBPUSD.DWX` — secondary; liquid London/NY major with similar pip mechanics (card secondary).

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — fixed pip TP/SL is calibrated for 5-digit FX majors, not CFD point scales.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~500` |
| Typical hold time | `minutes (intraday scalp)` |
| Expected drawdown profile | `frequent small wins/losses; tight 5-pip stop, 10-pip target` |
| Regime preference | `trend (pullback continuation)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f4fa8966-3aa0-5df0-9d8f-3872df92309a`
**Source type:** `book` (local PDF)
**Pointer:** `The Blade Forex Strategies — M5 Scalping System (anonymous, ForexSuccessSecrets.com), local PDF archive`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11383_blade-m5-ema-zone-scalper.md`

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
