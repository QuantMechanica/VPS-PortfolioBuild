# QM5_11277_blade-m5-ema-zone-scalp — Strategy Spec

**EA ID:** QM5_11277
**Slug:** `blade-m5-ema-zone-scalp`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A trend-pullback scalp on M5 using three EMAs (10/21/50). The EA trades only in
the direction of a sloping EMA(50): long when EMA(10) > EMA(21) > EMA(50) and
EMA(50) is rising versus five bars earlier, short on the mirror condition. The
"zone" is the band between EMA(10) and EMA(21). A long fires on the first closed
bar that freshly retraces into the zone — the prior bar closed above the zone top
and the current bar closes inside the zone at or below its midpoint (mirror for
shorts). The retrace into the zone is the single entry EVENT; the trend stack,
slope, and session are STATES. Stop is placed 5 pips beyond EMA(21) on the
opposite side of the trade; take-profit is a fixed +10 pips; the stop is moved to
break-even once price is +5 pips in profit. Trading is restricted to the London
and New York sessions (UTC windows, broker time converted via QM_BrokerToUTC),
each shrunk by a 30-minute buffer off open and close. Any open position is closed
when both sessions go inactive, and only one position per magic is held at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_zone_fast` | 10 | 5-20 | Fast zone-edge EMA period |
| `strategy_ema_zone_slow` | 21 | 14-34 | Slow zone-edge EMA period and stop anchor |
| `strategy_ema_trend` | 50 | 30-100 | Trend / slope-filter EMA period |
| `strategy_slope_lookback` | 5 | 2-20 | Bars back for the EMA(50) slope proxy |
| `strategy_sl_pips` | 5 | 2-20 | Stop placed this many pips beyond EMA(21) |
| `strategy_tp_pips` | 10 | 4-30 | Fixed take-profit distance in pips |
| `strategy_be_trigger_pips` | 5 | 2-20 | Move SL to break-even at +this many pips |
| `strategy_london_start_utc` | 8 | 0-23 | London session open hour (UTC) |
| `strategy_london_end_utc` | 17 | 0-23 | London session close hour (UTC) |
| `strategy_ny_start_utc` | 13 | 0-23 | New York session open hour (UTC) |
| `strategy_ny_end_utc` | 22 | 0-23 | New York session close hour (UTC) |
| `strategy_session_buffer_min` | 30 | 0-120 | No entries within this many min of open/close |
| `strategy_spread_pct_of_stop` | 50.0 | 1-200 | Block only if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary; deepest M5 liquidity, tightest natural spread for a scalp.
- `GBPUSD.DWX` — major with clean London/NY trends matching the session filter.
- `USDJPY.DWX` — major; 3-digit pip scaling handled by QM_StopRules pip factor.

**Explicitly NOT for:**
- Index / metal CFDs (NDX.DWX, XAUUSD.DWX, …) — a 5/10-pip FX scalp does not
  translate to index point structure; the card's edge is FX-major specific.

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
| Trades / year / symbol | `~200` |
| Typical hold time | `minutes (intraday scalp, closed at session end)` |
| Expected drawdown profile | `frequent small wins/losses; shallow per-trade risk (5-pip stop)` |
| Regime preference | `trend (intraday pullback continuation)` |
| Win rate target (qualitative) | `medium-high (1:2 SL:TP with break-even protection)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book` (archived strategy PDF)
**Pointer:** "The Blade Forex Strategies", ForexSuccessSecrets.com, M5 Scalping System pp.11-25
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11277_blade-m5-ema-zone-scalp.md`

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
