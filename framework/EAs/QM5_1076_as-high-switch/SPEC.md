# QM5_1076_as-high-switch SPEC

## Source
- Approved card: `docs/strategy_card.md`
- Strategy: Allocate Smartly / Meb Faber 12-Month High Switch
- EA id: `1076`
- Slug: `as-high-switch`

## V5 Mapping
- No-Trade: block symbols outside the declared six-symbol DWX universe and block non-D1 charts.
- Entry: on the first D1 bar of a new month, evaluate the just-closed month-end close. Enter long if that close is within `strategy_high_buffer_pct` of the highest month-end close across the current plus prior `strategy_month_lookback - 1` month ends.
- Trade Management: no intramonth management beyond the initial ATR catastrophic stop required for framework risk sizing.
- Trade Close: on month-end rebalance, close the position if the symbol is no longer within the 12-month-high buffer.

## Universe And Slots
| Slot | Symbol | Sleeve |
|---:|---|---|
| 0 | SP500.DWX | US equity, backtest-only per card R3 note |
| 1 | NDX.DWX | US equity live-validation proxy |
| 2 | WS30.DWX | US equity live-validation proxy |
| 3 | GDAXI.DWX | International/index proxy |
| 4 | XAUUSD.DWX | Gold sleeve |
| 5 | XTIUSD.DWX | Commodity proxy |

## Parameters
- `strategy_month_lookback = 12`
- `strategy_high_buffer_pct = 5.0`
- `PORTFOLIO_WEIGHT = 0.2` in canonical backtest setfiles, matching five equal risky sleeves.
- `qm_friday_close_enabled = false` because the card holds monthly and does not require weekly flattening.

## Known Port Boundary
The original defensive asset sleeve is not directly implemented as an MT5 position. Failed risky sleeves remain flat/cash in this single-symbol port. The card's SP500.DWX live promotion note remains binding: SP500.DWX-only evidence is not deployable without parallel validation on NDX.DWX or WS30.DWX.
