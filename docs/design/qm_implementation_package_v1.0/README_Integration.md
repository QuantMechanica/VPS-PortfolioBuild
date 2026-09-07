# QuantMechanica Strategy Console - Integration Guide v1.0

## Package layout

```text
mql5/
  Experts/
    QuantMechanica_OHLC_Daily_Squeeze_Reversal_D1.mq5
  Include/
    QMDesignTokens.mqh
    QMDashboardModel.mqh
    QMStrategyConsole.mqh
    QM_OHLCDailySqueezeReversal_Config.mqh
    StandardVisualization.mqh
    IVisualization.mqh
    IFilter.mqh
    TimeRangeBreakoutStrategy.mqh

website/
  quantmechanica-design-tokens.css
  quantmechanica-components.css
  quantmechanica-design-tokens.json

docs/
  QuantMechanica_Design_Guideline_MQL5_Web_v1.0.docx
  QuantMechanica_Design_Guideline_MQL5_Web_v1.0.md
  QuantMechanica_OHLC_Daily_Squeeze_Reversal_EA_Spec_v1.0.md
```

## MQL5 install into the existing project

1. Make a versioned copy of the current EA folder.
2. Replace `IFilter.mqh`, `IVisualization.mqh`, `StandardVisualization.mqh` and `TimeRangeBreakoutStrategy.mqh` with the package versions.
3. Add `QMDesignTokens.mqh`, `QMDashboardModel.mqh`, `QMStrategyConsole.mqh` and `QM_OHLCDailySqueezeReversal_Config.mqh` beside the existing includes.
4. Add the renamed main EA `QuantMechanica_OHLC_Daily_Squeeze_Reversal_D1.mq5`.
5. The package already includes unchanged local compile dependencies (`IStrategy.mqh`, `PatternFilter.mqh`, `Patterns.mqh`, `NewsFilter.mqh`, `SymbolCache.mqh`) for convenience. They are included as project dependencies, not as design changes.
6. Compile the renamed EA in MetaEditor.
7. Do not overwrite the previous production version until trade-result parity and the intentional pattern-cache correction have been validated.

## Website install

Load in this order:

```html
<link rel="stylesheet" href="/styles/quantmechanica-design-tokens.css">
<link rel="stylesheet" href="/styles/quantmechanica-components.css">
```

Use the JSON token file for JavaScript/chart libraries and design tooling.

The website and EA must share the same semantic chart colors:
- candle up: `#0E9F7A`
- candle down: `#F0545E`
- current price/info: `#3B6CF6`
- range border: `#6B8FD8`
- brand green: `#0A8A5B`

## Architecture

`Strategy/filter/risk logic -> QMDashboardSnapshot -> QMStrategyConsole renderer`

The renderer never derives a trading decision from strings. EA-specific content is built in `QM_OHLCDailySqueezeReversal_Config.mqh`; generic renderer/design files stay reusable.

## Performance

- no visualization in optimization;
- dashboard update on timer/trade transaction rather than every tick;
- cached performance summary;
- incremental visual range preview;
- no M1 history scan from trade open on every visual update;
- deterministic object names and update-in-place behavior.
