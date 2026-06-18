# QM5_11340_tc-m5-18-ema20-macd — Strategy Spec

**EA ID:** QM5_11340
**Slug:** `tc-m5-18-ema20-macd`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

M5 continuation setup (Thomas Carter, 20 Forex Trading Strategies, 5 Min System #18).
The EMA(20) reclaim is the single fresh TRIGGER event; the MACD zero-cross is a recency
STATE (recent or current), so the two are never required to coincide on one bar. LONG:
after price has traded below EMA(20) within the prior lookback window, the bar closes
crossing up through EMA(20) (close[2] <= EMA20[2] and close[1] > EMA20[1]) while MACD(12,26,9)
main has crossed up through zero within the last 5 closed bars; a BUY STOP is placed at
EMA(20) + 10 pips, expiring after 3 M5 bars. SHORT is the mirror image. The initial stop
is 20 pips from the entry. After +1R the EA closes 50% of the position, shifts the remainder
to break-even (+1 pip buffer), then trails the remainder 15 pips behind price. MACD main may
be negative — only its sign / zero-cross is used, never a positivity requirement.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 20 | 10-50 | Reclaim EMA period |
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA |
| `strategy_macd_slow` | 26 | 15-40 | MACD slow EMA |
| `strategy_macd_signal` | 9 | 5-15 | MACD signal SMA |
| `strategy_macd_recency_bars` | 5 | 3-8 | MACD zero-cross recency window (P3 sweep: 3/5/8) |
| `strategy_setup_lookback_bars` | 20 | 10-40 | Prior below/above-EMA20 context window |
| `strategy_entry_offset_pips` | 10 | 5-20 | Pending STOP offset from EMA20 |
| `strategy_sl_pips` | 20 | 10-40 | Stop distance from entry |
| `strategy_pending_expiry_bars` | 3 | 1-5 | Cancel unfilled pending after N M5 bars (P3 sweep: 1/3/5) |
| `strategy_partial_rr` | 1.0 | 0.5-2.0 | R multiple at which the partial is taken |
| `strategy_partial_close_pct` | 50.0 | 25-75 | % of position closed at the partial |
| `strategy_be_buffer_pips` | 1 | 0-5 | Break-even buffer applied after the partial |
| `strategy_trail_pips` | 15 | 8-25 | Trail distance on the remainder |
| `strategy_spread_pct_of_stop` | 25.0 | 10-50 | Skip only if spread > this % of stop distance (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; tight spreads suit a 10/20-pip M5 continuation.
- `GBPUSD.DWX` — liquid major with adequate M5 intraday range for the offset/stop scale.
- `AUDUSD.DWX` — liquid major; card's R3 PASS basket.
- `USDJPY.DWX` — liquid major; pip scaling handled via QM_StopRulesPipsToPriceDistance (3-digit).

**Explicitly NOT for:**
- Index/metal `.DWX` symbols — the card's pip offsets are FX-calibrated; index point scales differ.

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
| Trades / year / symbol | `~100` |
| Typical hold time | `minutes to a few hours (M5 intraday continuation)` |
| Expected drawdown profile | `frequent small stops; partial+trail caps individual losers` |
| Regime preference | `trend / breakout-continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #18, pp.44-45 (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11340_tc-m5-18-ema20-macd.md`

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
| v1 | 2026-06-18 | Initial build from card | claude board-advisor |
