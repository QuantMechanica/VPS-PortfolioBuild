# QM5_41477 — Visualization Spec (Design-2 family)

Derived from the H-CW integration pattern (`QM5_41475_cash-window-index-continuation-h1`)
via the shared `QM_ChartPanelCompare` / `QM_ChartTheme` / `QM_ChartUI` includes in
`framework/include/QM/`. No renderer code is copied; the EA only fills a
`QM_ConsoleSnapshot`.

## Renderer

- Class: `CQMChartPanelCompare` (`QM_ChartPanelCompare.mqh`), design `QM_DESIGN_2`.
- Modes: Full / Compact / Minimal (`qm_dashboard_mode`, switchable in-chart without restart).
- Identity: strategy name derived from the registered source filename
  (`QM41477_ConsoleStrategyName`), magic = `QM_FrameworkMagic()`.
- Lifecycle: initialized in `OnInit` only when `MQL_TESTER==0 && MQL_OPTIMIZATION==0`
  (the panel never runs under non-visual backtest); refreshed on the 5s timer;
  `InvalidatePerformance()` on `OnTradeTransaction`; recovery via `OnChartEvent`.

## Panel content (snapshot mapping)

| UI element | Source |
|---|---|
| Header | strategy name, `_Symbol`, M15 timeframe, environment, v5.0 |
| Next-event line | countdown to the next M15 evaluation; in position: "Time stop in N bars \| flat by HH:MM UTC" |
| Execution gate | terminal + trade permission checks |
| News gate | card blackout cache (`g_fxmr_news_cache_blocked`), Disabled when `news_blackout_minutes==0` |
| Kill-switch gate | `g_qm_ks_halted` |
| Session gate | UTC minute vs the two windows / lunch-gap flat / day flat (WAIT outside windows, BLOCK at/after flat) |
| Friday gate | UTC Friday cutoff state |
| Shock gate | `g_fxmr_shock_london` / `g_fxmr_shock_ny` (per-window first-bar shock) |
| Daily breaker gate | `g_fxmr_breaker_day_hit` |
| Weekly breaker gate | `g_fxmr_breaker_week_hit` |
| Spread gate | warmup day count and 20-day median spread (points) |
| Capacity gate | family positions / `max_positions_total` |
| Day-trades gate | `g_fxmr_trades_today` / `max_trades_per_day` |
| Risk lines | next-trade risk (% \| money) via framework risk globals; card risk basis (live %, stop buffer x, TP R) |
| Active range | the stretch window: bars 2..stretch_bars+1 span (time range + high/low labels) |
| State | WAITING_SETUP (default / entry taken this window / day cap reached) / POSITION_ACTIVE (with countdown) / BLOCKED (breaker hit) |

## Drawing notes (card-mandated visuals)

- **Session windows**: the session gate renders the current window (London / NY),
  the lunch-gap flat and the day-flat state; `strategy_*_hour_utc` / flat-minute
  inputs define them (UTC via QM_DSTAware).
- **Stretch markers**: the active range draws the stretch-extreme band
  (`g_fxmr_stretch_low`..`g_fxmr_stretch_high`) of the candidate window —
  this is the stop-anchor structure (markers render via the panel's range
  channel when `qm_show_active_range`).
- **EMA**: `strategy_ema_period` M15 EMA — the reclaim reference; the strategy
  reads it via `QM_EMA` on closed bars (panel shows the EMA-period in the risk
  basis lines).
- **Entry / stop / TP**: levels render through the framework's strategy/trade
  level channels (`qm_show_strategy_levels`, `qm_show_trade_levels`) from the
  position's SL/TP set at entry (stretch extreme +/- buffer; target_r x stop).
- **Time-stop**: the in-position next-event line counts down `time_stop_bars`
  remaining bars.
- **Breaker state**: the daily/weekly breaker gates render Armed / Hit (-1.0% /
  -2.0%); when hit the state flips to BLOCKED with the reason.

## Data discipline

- The panel is a read-only projection of state the strategy already computed:
  breakers, spread median, per-window shock, blackout cache, stretch window and
  day counters are all updated on new M15 bars by the strategy module; the
  timer refresh performs no heavy work (no `CopyRates`, no `HistorySelect`,
  bounded O(1) scans of position lists only).
- News verdicts rendered are observations, never grants: the panel holds no
  trade-permission logic.
