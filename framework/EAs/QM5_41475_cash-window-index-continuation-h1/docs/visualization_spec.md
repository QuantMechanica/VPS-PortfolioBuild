# QM5_41475 — Visualization Spec (Design-2 family)

Derived from `QM5_11421_ohlc-daily-squeeze-reversal-d1` (the Design-2 visual
reference) via the shared `QM_ChartPanelCompare` / `QM_ChartTheme` /
`QM_ChartUI` includes in `framework/include/QM/`. No renderer code is copied;
the EA only fills a `QM_ConsoleSnapshot`.

## Renderer

- Class: `CQMChartPanelCompare` (`QM_ChartPanelCompare.mqh`), design `QM_DESIGN_2`.
- Modes: Full / Compact / Minimal (`qm_dashboard_mode`, switchable in-chart without restart).
- Identity: strategy name derived from the registered source filename
  (`QM41475_ConsoleStrategyName`), magic = `QM_FrameworkMagic()`.
- Lifecycle: initialized in `OnInit` only when `MQL_TESTER==0 && MQL_OPTIMIZATION==0`
  (the panel never runs under non-visual backtest); refreshed on the 5s timer;
  `InvalidatePerformance()` on `OnTradeTransaction`; recovery via `OnChartEvent`.

## Panel content (snapshot mapping)

| UI element | Source |
|---|---|
| Header | strategy name, `_Symbol`, H1 timeframe, environment, v5.0 |
| Next-event line | countdown to the next H1 evaluation; in position: "Time stop in N bars \| flat by 20:00 UTC" |
| Execution gate | terminal + trade permission checks |
| News gate | card blackout cache (`g_hcw_news_cache_blocked`), Disabled when `news_blackout_minutes==0` |
| Kill-switch gate | `g_qm_ks_halted` |
| Session gate | UTC hour vs entry window / flat window (WAIT outside the window, BLOCK at/after flatten) |
| Friday gate | UTC Friday cutoff state |
| Shock gate | `g_hcw_shock_blocked` (first session bar range shock) |
| Daily breaker gate | `g_hcw_breaker_day_hit` |
| Weekly breaker gate | `g_hcw_breaker_week_hit` |
| Spread gate | warmup day count and 20-day median spread (points) |
| Capacity gate | family positions / `max_positions_total` |
| Risk lines | next-trade risk (% \| money) via framework risk globals; card risk basis (live %, ATR stop x, TP R) |
| Active range | today's breakout reference: session start .. start+N hours, high/low labels |
| State | WAITING_SETUP (default) / POSITION_ACTIVE (with countdown) / BLOCKED (breaker hit) / "entry taken today" note |

## Data discipline

- The panel is a read-only projection of state the strategy already computed:
  breakers, spread median, shock, blackout and breakout window are all updated
  on new H1 bars by the strategy module; the timer refresh performs no heavy
  work (no `CopyRates`, no `HistorySelect`, bounded O(1) scans of position
  lists only).
- News verdicts rendered are observations, never grants: the panel holds no
  trade-permission logic.
