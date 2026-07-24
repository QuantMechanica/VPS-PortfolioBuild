# STR-021 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_weekly-open-liquidity-sweep` · exec TF: M15 · Symbols (slots 0–1):
XAUUSD.DWX, XAGUSD.DWX. Base: `EA_Skeleton.mq5`. Uses ONE pending limit order max
(framework pending-guard P0.5 covers duplicates).

## Inputs

```
input bool   strategy_vol_confirm_enabled = false; // p.25: volume = confirmation only (default OFF)
input double strategy_vol_mult            = 2.0;   // if enabled: tick_vol >= mult * SMA(tick_vol, lookback)
input int    strategy_vol_lookback       = 96;
input double strategy_rr_ratio           = 2.0;    // TP = fill +/- rr * R (R from ACTUAL fill vs SL)
```

## State machine (per side; file-scope; rebuilt on init by replaying closed M15
bars of the CURRENT broker week — restart-safe)

```
enum SideState { IDLE, SWEPT, CONFIRMED_PENDING };
struct SideCtx { SideState st; double ob_high, ob_low; datetime ob_time; ulong ticket; };
static SideCtx g_long, g_short;
static double  g_weekly_open; static datetime g_week_start;
static double  g_prev_d1_low, g_prev_d1_high;  // previous CLOSED D1 bar extremes
```

- New broker week (W1 bar time change): reset both sides to IDLE, cancel own
  pending (log `STRATEGY_REBALANCE_DONE reason=week_rollover`), set
  `g_weekly_open = iOpen(_Symbol, PERIOD_W1, 0)`.
- Each new D1 bar: refresh `g_prev_d1_low/high` from D1 shift 1.
- Each new closed M15 bar (shift 1 = bar b), LONG side:
  - IDLE→SWEPT when `Low[b] < g_weekly_open && Low[b] < g_prev_d1_low`
    (sell-side liquidity taken below the level).
  - In SWEPT: OB candidate = bar with `Close<Open && High < g_weekly_open`
    (formed at/after the sweep bar); if `strategy_vol_confirm_enabled`, also
    `tick_volume >= mult*SMA(tick_volume,lookback)`; zero-range bars rejected.
    Newest candidate replaces older (store ob_high/ob_low/ob_time).
  - SWEPT→CONFIRMED_PENDING when a bar closes `> ob_high` with a valid OB:
    place BUY LIMIT @ `ob_high`, `SL = ob_low − 1 tick`,
    TP = 0 at placement (computed at FILL: `TP = fill + rr*(fill−SL)`, set via
    position modify on first management pass after fill). Stops-level violation →
    SKIP (log `SETUP_CONFIG_INVALID reason=stops_level`), state back to SWEPT.
  - In CONFIRMED_PENDING: cancel own pending + revert to SWEPT if an M15 close
    `< ob_low` (invalidation) — log `TM_REMOVE_PENDING reason=ob_invalidated`.
- SHORT side mirrors exactly (High > weekly_open && High > prev_d1_high; bullish
  OB with Low > weekly_open; sell limit at ob_low; SL = ob_high + 1 tick).
- Cross-side exclusivity: while ANY own pending or position exists, the other
  side may progress its state machine but must NOT place orders.

## Hooks

1. **NoTradeFilter:** block on warmup (<2 closed W1 bars, <2 D1, <`vol_lookback+5`
   M15), invalid week/D1 data, or symbol trade-disabled. Framework handles
   news/Friday/KS.
2. **EntrySignal:** implements the state machine ORDER PLACEMENT via the
   framework pending-order path (buy/sell limit with absolute SL; TP deferred to
   fill). Only transitions on new closed M15 bars. No market entries.
3. **ManageOpenPosition:** first pass after fill: if TP==0 → set
   `TP = fill ± rr*(|fill−SL|)` (modify once; log `TM_*`). No trailing, no BE.
4. **ExitSignal:** false (SL/TP server-side; Friday-close framework).
5. **NewsFilterHook:** framework default.

## Errors / logging

Replay-on-init: iterate closed M15 bars since week start to rebuild states
(deterministic; no files). Order-send/modify failures: framework retry path; log
and remain in prior state. `STRATEGY_ENTRY` payload {side, weekly_open,
prev_d1_extreme, ob_high, ob_low, sweep_time}; pending cancels logged.

## Compliance mapping

Standard Q01 checklist. Broker-time W1/D1 anchors (UTC fidelity note in card).
Friday-close ON. Frequency est. 8–25 fills/yr/symbol — Q02-floor watch flagged.
