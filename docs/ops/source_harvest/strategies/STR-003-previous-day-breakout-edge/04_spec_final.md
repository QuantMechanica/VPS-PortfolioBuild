# STR-003 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_prevday-breakout-close-edge` · TF H1 · Symbols (slots 0–1):
EURUSD.DWX, GBPUSD.DWX · Base: `framework/templates/EA_Skeleton.mq5`.
Faithful-variant rationale: QM5_10007 (same thread) added unsourced extras
(tiny-range skip, opposite-break + rollover exits) and FAILED Q04; this build
is the bare source baseline: close-confirmed break, next-open entry, fixed
12.5/25, set-and-forget.

## Inputs (group "Strategy")

```
input bool   strategy_sma_filter  = false; // OP: optional; author-pref variant ON via Q03
input int    strategy_sma_period  = 34;
input double strategy_sl_pips     = 12.5;
input double strategy_tp_pips     = 25.0;
input int    strategy_day_anchor_utc_hour = 22; // source: trading day starts 22:00 GMT
```

## State (statics; rebuilt from closed bars — restart-safe)

- `g_h_sma` (iMA H1 SMA34 CLOSE) — created lazily, gated in filter.
- Cyclic-day engine: on each new H1 bar map bar-open (broker time) → UTC via
  the framework broker↔UTC primitive; day_key = floor((utc − 22h)/24h).
  On day_key change: freeze `g_prev_high/low` = max High / min Low over ALL
  closed H1 bars of the previous day_key (bounded backward scan ≤ 40 bars,
  `// perf-allowed`, new-bar-gated); reset `g_long_done/g_short_done=false`.
  Warmup: require a COMPLETE previous cyclic day (≥1 full day of H1 history
  after the first observed day boundary) else no signals.
- Restart: the day scan naturally rebuilds levels; consumed flags rebuilt by
  scanning current-day closed bars for prior qualifying closes (level vs
  close), marking done regardless of whether a trade resulted.
- `g_last_signal_bar` own new-bar dedupe (never QM_IsNewBar).

## Hook 1 — Strategy_NoTradeFilter (TRUE = block)

Block on: `_Period != PERIOD_H1`; param sanity (0≤anchor<24, sl>0, tp>0,
sma>1); symbol trade disabled; H1 warmup (<60 bars); if `strategy_sma_filter`:
SMA handle invalid / BarsCalculated < sma_period+5. No position/consumed/day
checks here.

## Hook 2 — Strategy_EntrySignal

New-bar gate; run day-engine update FIRST (roll/freeze/reset). ZeroMemory +
symbol_slot. Prev-day levels valid? else false.
Raw events on the just-closed bar (shift 1) vs FROZEN levels:
- long event: `Close[1] > prev_high && Close[2] <= prev_high && !g_long_done`
- short event: `Close[1] < prev_low && Close[2] >= prev_low && !g_short_done`
On an event: **consume immediately** (`g_*_done = true`) — before any veto —
then veto in order: own position exists → false; SMA filter (if enabled):
long requires `Close[1] > SMA34[1]` strict (short mirror) → false.
Passed: direction; SL/TP fixed pips from entry via `QM_StopFixedPips` /
`QM_TakeFixedPips`; log STRATEGY_ENTRY {dir, close, level, sma?, day_key}.
(Close[2] guard uses the SAME frozen levels — first-close semantics; a bar
straddling the day roll evaluates against the NEW day's levels only.)

## Hook 3 — Strategy_ManageOpenPosition
Empty (server-side SL/TP are the complete exit). No stop moves.

## Hook 4 — Strategy_ExitSignal
false.

## Hook 5 — Strategy_NewsFilterHook
Framework default.

## Logging / errors

Data failures → skip bar + `SETUP_DATA_MISSING` (dedupe per bar). Stops-level
violation of the 12.5-pip SL → skip + `SETUP_CONFIG_INVALID reason=stops_level`
(consumed stays consumed).

## Compliance mapping

Magic registry; RISK_FIXED backtest / RISK_PERCENT live; ≤1% per trade; news/
Friday/KS framework. Honesty note (card + gate log): thread contains a NEGATIVE
mechanical test (−3R/13mo unfiltered) alongside positive anecdotes — pipeline
evidence only. Frequency est. 100–200 events/yr/symbol pre-veto (floor safe).
