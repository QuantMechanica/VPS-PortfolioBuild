# Exact EA Changes - QuantMechanica OHLC Daily Squeeze Reversal v1.0

This file lists only changes that belong to the concrete EA delivered in this package.  
Generic brand/design rules live in the shared QuantMechanica guideline and generic `QM*.mqh` files.

## 1. Renamed EA

Old main source:
- `QuantRangePRO.mq5`

New main source:
- `QuantMechanica_OHLC_Daily_Squeeze_Reversal_D1.mq5`

Customer-facing commercial name:
- `QuantMechanica - OHLC Daily Squeeze Reversal`

Strategy Console title:
- `OHLC Daily Squeeze Reversal · D1`

Internal short code:
- `QM-ODSR-D1`

Web slug:
- `ohlc-daily-squeeze-reversal-d1`

Trade comment base:
- `QM OHLC Squeeze`

State-file prefix:
- `QM_ODSR_D1_State`

Version:
- `1.00`

All of these values are centralized in:
- `QM_OHLCDailySqueezeReversal_Config.mqh`

## 2. Exact dashboard content

### Filter Gate
This EA renders only filters/gates that actually participate in its logic:
- News
- Pattern
- Session
- Range

The old unused top-level `PriceActionContextFilter` and `HiddenMarkovFilter` includes are removed from the renamed main EA because they were not configured as active filters.

No artificial Spread/HMM/Context gates are shown.

### Risk
This EA renders:
- Next trade
- Open exposure
- Stop basis

`Daily DD` is not shown because the current EA does not enforce a daily-drawdown governor in trade admission. It must only be reintroduced after a real governor exists.

### Live
The live section is hidden while no live position or actionable pending order exists.

### Performance
Today/week data is cached and refreshed outside the hot tick path.

## 3. Visualization inputs added

- `InpUseVisualization`
- `InpDashboardMode`
- `InpVisualScale`
- `InpShowActiveRange`
- `InpShowStrategyLevels`
- `InpShowTradeLevels`
- `InpShowTradeMarkers`
- `InpShowHistoricalSetups`
- `InpHistoryDays`

There is no Debug mode.

## 4. Chart behavior changed

Default visual presentation:
- white background;
- grid off;
- default volumes off;
- QuantMechanica candle colors;
- Signal Blue current-price line;
- active range box;
- direct Range High/Low labels;
- direct Buy/Sell Trigger labels;
- Entry/SL/TP only when exposure exists.

No decorative indicators or ICT/SMC/SMT elements are added.

## 5. OnTick / tester performance changes

- Dashboard rendering removed from the hot tick path.
- Active-trade visualization synchronization removed from the hot tick path.
- Position/order recounting handled by timer/trade events.
- Range preview handled on timer and updated incrementally.
- Today/week history scan cached.
- Visualization is still fully bypassed during optimization.
- UI reads cached filter results and never re-runs filters only for display.

## 6. Pattern filter evaluation correction

The previous strategy performed `CFilterManager::CheckAll()` before the intended daily pattern cache and could therefore evaluate the Pattern Filter repeatedly.

The implementation now:
- evaluates News as time-sensitive entry logic;
- evaluates Pattern once per trading day;
- caches directional Pattern permissions;
- records the real result through `UpdateStats()`;
- exposes the cached result to the dashboard.

This is an intentional correction of an existing ineffective cache, not a visual-only change.

## 7. Exact-EA file ownership

### EA-specific
- `mql5/Experts/QuantMechanica_OHLC_Daily_Squeeze_Reversal_D1.mq5`
- `mql5/Include/QM_OHLCDailySqueezeReversal_Config.mqh`

### Generic QuantMechanica visual framework
- `mql5/Include/QMDesignTokens.mqh`
- `mql5/Include/QMDashboardModel.mqh`
- `mql5/Include/QMStrategyConsole.mqh`

### Patched shared project files
- `mql5/Include/StandardVisualization.mqh`
- `mql5/Include/IVisualization.mqh`
- `mql5/Include/IFilter.mqh`
- `mql5/Include/TimeRangeBreakoutStrategy.mqh`

### Included unchanged compile dependencies
- `mql5/Include/SymbolCache.mqh`
- `mql5/Include/Patterns.mqh`
- `mql5/Include/PatternFilter.mqh`
- `mql5/Include/NewsFilter.mqh`
- `mql5/Include/IStrategy.mqh`

## 8. Required validation before production

This environment has no MetaEditor/MQL5 compiler. Static structure/signature checks were performed, but the delivered source has not been compiled to EX5 here.

Before production:
1. Compile the renamed EA in MetaEditor.
2. Run a baseline vs new-version backtest with identical strategy inputs.
3. Confirm trade-result parity for visual-only changes.
4. Separately validate the intentional Pattern-cache correction.
5. Test EURUSD, XAUUSD and US100.
6. Test FULL/COMPACT/MINIMAL modes and multiple display scales.
7. Confirm optimization still bypasses all visualization work.

## 9. Rule of record

`Visibility != Logic`

No display mode, overlay, chart preference or scale control may alter entry, exit, filter, risk or execution behavior.
