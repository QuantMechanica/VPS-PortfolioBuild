# QuantMechanica - OHLC Daily Squeeze Reversal
## EA-specific implementation specification v1.0

**Status:** Implementation package  
**Date:** 2026-09-07  
**Scope:** Only this EA. Generic QuantMechanica design rules live in the shared design-system files.

---

## 1. Final naming

| Purpose | Final value |
|---|---|
| Master brand | `QuantMechanica` |
| Commercial EA name | `QuantMechanica - OHLC Daily Squeeze Reversal` |
| Strategy Console title | `OHLC Daily Squeeze Reversal` |
| Platform module label | `STRATEGY CONSOLE` |
| Timeframe label | `D1` |
| Main source file | `QuantMechanica_OHLC_Daily_Squeeze_Reversal_D1.mq5` |
| Web slug | `ohlc-daily-squeeze-reversal-d1` |
| Internal short code | `QM-ODSR-D1` |
| Broker trade-comment base | `QM OHLC Squeeze` |
| State-file prefix | `QM_ODSR_D1_State` |
| Version | `1.00` |
| Brand line | `Systematic. Tested openly.` |
| Footer | `© QuantMechanica` |

There is **no AXIOM codename**. A second product name is not introduced unless QuantMechanica later has a real multi-product suite that requires one.

All customer-facing identity constants are centralized in:

`QM_OHLCDailySqueezeReversal_Config.mqh`

Do not duplicate these strings across the EA.

---

## 2. Exact Strategy Console content

### Primary state
The console shows only the current operational state, context and next event.

Examples:
- `WAITING FOR SETUP` / `Building session range`
- `WAITING FOR TRIGGER` / `Range locked · BOTH`
- `TRADE BLOCKED` / concise blocking reason
- `POSITION ACTIVE`
- `SYSTEM ERROR` only for real exceptional states

A separate `SETUP` section is intentionally **not** used.

### Filter Gate
Only gates that actually exist in this EA are displayed:

1. `News`
2. `Pattern`
3. `Session`
4. `Range`

The layout is two-column and follows:

`Label · concise detail   STATE`

Examples:
- `News · Active (no events)   PASS`
- `Pattern · Blacklist Mode   PASS`
- `Session · Trading open   PASS`
- `Range · Valid   PASS`

This EA does **not** show fake `Spread`, `HMM` or `Context` gates. `PriceActionContextFilter.mqh` and `HiddenMarkovFilter.mqh` were included in the old main EA but were never configured; those unused top-level includes are removed from the renamed EA.

### Risk
The exact EA displays:
- `Next trade`
- `Open exposure`
- `Stop basis`

`Open exposure` is calculated to the actual stop loss with `OrderCalcProfit`, so the amount is account-currency and broker-contract aware across FX, metals and CFDs.

The final visual mockup showed a `Daily DD` line. This exact EA currently has **no enforced daily-drawdown governor in its trade-admission path**, so the implementation does not pretend that a 3% limit exists. Until a real governor is integrated and enforced, `Stop basis` is shown instead.

### Live
The LIVE section is state-adaptive:
- hidden when there is no live exposure;
- shown when there is an active position and/or actionable pending order.

No fixed `Position 1/2/3` or `Order 1/2/3` empty slots are rendered.

### Performance
One restrained strip:
- Today: trade count + net P/L
- Week: trade count + net P/L

History scanning is cached and is not performed on every tick.

---

## 3. Exact visualization inputs

The renamed EA exposes the following customer-facing visualization inputs:

```text
InpUseVisualization
InpDashboardMode        FULL / COMPACT / MINIMAL
InpVisualScale          80-150
InpShowActiveRange
InpShowStrategyLevels
InpShowTradeLevels
InpShowTradeMarkers
InpShowHistoricalSetups
InpHistoryDays
```

There is **no Debug mode**.

The `View` button in the panel cycles:
`FULL -> COMPACT -> MINIMAL -> FULL`.

Trading parameters remain normal MetaTrader inputs. Display controls never modify strategy logic.

---

## 4. Exact chart rules

Default chart presentation:
- white background;
- grid off;
- default volumes off;
- bullish candles `#0E9F7A`;
- bearish candles `#F0545E`;
- current-price line Signal Blue `#3B6CF6`;
- active range with very light blue fill;
- direct labels for Range High, Range Low, Buy Trigger and Sell Trigger;
- active Entry / SL / TP only when a trade exists.

No EMA, Bollinger Bands, session shading, ICT/SMC/SMT, FVG, BOS/CHOCH or liquidity markers are displayed unless a future tested strategy/filter actually consumes those features.

---

## 5. Performance and logic corrections included with the visual migration

These changes are deliberately included because a premium UI must not make visual backtests slower or cause filters to be evaluated differently merely for display.

### OnTick reduction
- Dashboard repainting is no longer performed from the hot tick path.
- Active-trade visual synchronization is no longer looped on every tick.
- Position/order recounting is handled on timer and trade events.
- Range preview rendering is handled on timer.

### Incremental range preview
The visual preview no longer rescans the complete elapsed M1 range every few seconds. The first preview initializes the high/low; subsequent timer updates start at the last processed M1 bar and re-read that bar for intrabar accuracy.

### Pattern filter evaluation
The previous strategy code called `CFilterManager::CheckAll()` before its “check pattern once per day” cache and then called `CheckAll()` again on the first decision. That made the intended pattern cache ineffective.

The implementation now:
- evaluates `News Filter` as time-sensitive logic on entry decisions;
- evaluates `Pattern Filter` once per trading day and caches directional permissions;
- uses the cached result thereafter;
- records both evaluations through `UpdateStats()`.

This preserves the intended daily pattern logic while removing repeated D1 `CopyRates` work.

### Filter telemetry
`IFilter::UpdateStats()` now also caches:
- the last `FilterResult`;
- the last evaluation time.

The dashboard reads this cached result. It does **not** call `Check()` merely to render UI.

---

## 6. Files specific to this EA

### Exact-EA source
`mql5/Experts/QuantMechanica_OHLC_Daily_Squeeze_Reversal_D1.mq5`

### Exact-EA identity / presentation adapter
`mql5/Include/QM_OHLCDailySqueezeReversal_Config.mqh`

This is the single source of truth requested for EA-specific naming, dashboard copy and exact dashboard composition.

### Patched existing strategy/framework files
- `TimeRangeBreakoutStrategy.mqh`
- `IFilter.mqh`
- `IVisualization.mqh`
- `StandardVisualization.mqh`

### New reusable QuantMechanica files
- `QMDesignTokens.mqh`
- `QMDashboardModel.mqh`
- `QMStrategyConsole.mqh`

---

## 7. Existing files that remain required and unchanged

The package includes the following unchanged local compile dependencies for convenience:
- `IStrategy.mqh`
- `PatternFilter.mqh`
- `Patterns.mqh`
- `NewsFilter.mqh`
- `SymbolCache.mqh`

They are included so the delivered EA folder is easier to compile as a project; they are **not** claimed as design-system changes.

Keep any other existing execution/reporting modules referenced by your broader project. Do not delete unrelated modules simply because they are not part of the visualization migration.

---

## 8. Compile / verification status

The source package has been statically checked for balanced braces/parentheses and cross-file function signatures. The current environment does not contain MetaEditor, so it has **not** been compiled to EX5 here.

Before merging into the production branch:
1. copy the files into a test clone of the EA;
2. compile `QuantMechanica_OHLC_Daily_Squeeze_Reversal_D1.mq5` in MetaEditor;
3. resolve any broker/build-specific compiler differences without changing the design contract;
4. run visual backtests on EURUSD, XAUUSD and US100;
5. compare trade counts and trading results with the pre-visual-migration version under identical non-visual settings;
6. separately verify the intended pattern-cache correction, because that fixes an existing repeated-evaluation issue and may expose behavior that the old code unintentionally produced.

---

## 9. Non-negotiable rule

**Visibility != Logic.**

No dashboard mode, chart overlay, scale value, label or website presentation control may change:
- entry rules;
- exit rules;
- filter state;
- risk state;
- position sizing;
- order execution.
