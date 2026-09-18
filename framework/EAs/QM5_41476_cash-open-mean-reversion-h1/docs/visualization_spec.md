# QM5_41476 — Visualization Spec (Design-2 family)

Derived from `QM5_41475_cash-window-index-continuation-h1` (the sibling H-CW
build) via the shared `QM_ChartPanelCompare` / `QM_ChartTheme` / `QM_ChartUI`
includes in `framework/include/QM/`. No renderer code is copied; the EA only
fills a `QM_ConsoleSnapshot`.

## Renderer

- Class: `CQMChartPanelCompare` (`QM_ChartPanelCompare.mqh`), design `QM_DESIGN_2`.
- Modes: Full / Compact / Minimal (`qm_dashboard_mode`, switchable in-chart without restart).
- Identity: strategy name derived from the registered source filename
  (`QM41476_ConsoleStrategyName`), magic = `QM_FrameworkMagic()`.
- Lifecycle: initialized in `OnInit` only when `MQL_TESTER==0 && MQL_OPTIMIZATION==0`
  (the panel never runs under non-visual backtest); refreshed on the 5s timer;
  `InvalidatePerformance()` on `OnTradeTransaction`; recovery via `OnChartEvent`.

## Panel content (snapshot mapping)

| UI element | Source |
|---|---|
| Header | strategy name, `_Symbol`, H1 timeframe, environment, v5.0 |
| Next-event line | countdown to the next H1 evaluation; in position: "Time stop in N bars \| flat by 20:00 UTC" |
| Execution gate | terminal + trade permission checks |
| News gate | card blackout cache (`g_hmr_news_cache_blocked`), Disabled when `news_blackout_minutes==0` |
| Kill-switch gate | `g_qm_ks_halted` |
| Session gate | UTC hour vs entry window / flat window (WAIT outside the window, BLOCK at/after flatten) |
| Friday gate | UTC Friday cutoff state |
| Shock gate | `g_hmr_shock_blocked` (first session bar range shock) |
| Daily breaker gate | `g_hmr_breaker_day_hit` |
| Weekly breaker gate | `g_hmr_breaker_week_hit` |
| Spread gate | warmup day count and 20-day median spread (points) |
| Capacity gate | family positions / `max_positions_total` |
| Risk lines | next-trade risk (% \| money) via framework risk globals; card risk basis (live %, ATR stop x, min RR) |
| Active range | today's opening range: session start .. start+N hours, high/low labels + midpoint appended to the low label |
| State | WAITING_SETUP (default) / POSITION_ACTIVE (with countdown) / BLOCKED (breaker hit) / "entry taken today" note |

## Chart drawing (qm_show_* strategy/trade levels)

- Opening range: active-range band (session start .. start+N hours between
  `g_hmr_or_high` / `g_hmr_or_low`), rendered by the shared panel from the
  snapshot range fields.
- Failed-breakout zone: the pierce buffer bands beyond the range extremes
  (range extreme +/- `strategy_breakout_buffer_atr` x ATR) — visible as the
  space outside the active range band; a filled bar there that closes back
  inside is the trigger candle.
- EMA: the strategy's `strategy_ema_period` EMA is a standard indicator the
  operator attaches to the chart; the panel does not redraw it.
- Entry / stop / TP: `qm_show_trade_levels` + `qm_show_strategy_levels` draw
  the position's open price, hard stop (failed extreme +/- 1.0 ATR) and the
  opening-range midpoint target from the deal/position record.
- Time-stop countdown: the next-event line shows "Time stop in N bars | flat
  by 20:00 UTC" while a position is active.
- Breakers: the daily/weekly breaker gates show Armed/Hit state; when hit the
  panel state flips to BLOCKED with the reason text.

## Data discipline

- The panel is a read-only projection of state the strategy already computed:
  breakers, spread median, shock, blackout and the opening range are all
  updated on new H1 bars by the strategy module; the timer refresh performs
  no heavy work (no `CopyRates`, no `HistorySelect`, bounded O(1) scans of
  position lists only).
- News verdicts rendered are observations, never grants: the panel holds no
  trade-permission logic.
