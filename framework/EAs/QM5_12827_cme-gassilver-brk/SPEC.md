# QM5_12827 cme-gassilver-brk SPEC

**EA ID:** QM5_12827
**Slug:** cme-gassilver-brk
**Source Card:** `strategy-seeds/cards/approved/QM5_12827_cme-gassilver-brk_card.md`

## 1. Strategy Logic

The EA trades a two-leg natural-gas/silver relative-value basket on completed
D1 bars. It computes:

`spread = ln(XNGUSD.DWX close) - strategy_beta * ln(XAGUSD.DWX close)`

The prior channel is built from completed D1 spread values excluding the signal
bar itself. A close above the prior channel opens BUY `XNGUSD.DWX` and SELL
`XAGUSD.DWX`. A close below the prior channel opens SELL `XNGUSD.DWX` and BUY
`XAGUSD.DWX`.

Only one basket package can be open per magic set. The EA uses Darwinex MT5
prices, broker spread, ATR, and trade-session state only. It has no external
feeds, ML, grid, martingale, or deploy/live hooks.

## 2. Parameters

- `strategy_channel_lookback_d1`: D1 channel lookback, default 120.
- `strategy_beta`: hedge coefficient in the log spread, default 1.0.
- `strategy_neutral_fraction`: neutral-band fraction for deterministic exits,
  default 0.25.
- `strategy_max_hold_d1`: max completed D1 bars to hold a basket package,
  default 45.
- `strategy_atr_period_d1`: ATR period for hard stops, default 20.
- `strategy_atr_sl_mult`: ATR stop multiple, default 3.0.
- `strategy_xng_max_spread_pts`: XNG entry spread cap, default 2500.
- `strategy_xag_max_spread_pts`: XAG entry spread cap, default 200.
- `strategy_deviation_points`: order slippage/deviation cap, default 20.
- `strategy_entry_hour_broker`: broker-hour entry gate, default 2.
- `strategy_entry_minute_broker`: broker-minute entry gate, default 0.

## 3. Symbol Universe

- Slot 0: `XNGUSD.DWX`, magic `128270000`, host symbol.
- Slot 1: `XAGUSD.DWX`, magic `128270001`, hedge leg.
- Logical basket symbol: `QM5_12827_XNG_XAG_BRK_D1`.

Q02 must evaluate the logical basket using `basket_manifest.json` from the
`XNGUSD.DWX` host setfile. The physical legs are not standalone Q02 rows.

## 4. Timeframe

The strategy runs on D1. Entry and exit state are refreshed from completed D1
bars after the configured broker entry time. The backtest setfile is:

`sets/QM5_12827_cme-gassilver-brk_QM5_12827_XNG_XAG_BRK_D1_D1_backtest.set`

## 5. Expected Behaviour

The EA is expected to produce low-frequency spread packages, approximately
4-9 packages per year before Q02 measurement. It should stay flat when either
leg is already open, either leg is not tradable, inputs are invalid, spreads
exceed configured caps, or the spread remains inside the channel.

Management closes both legs when the spread returns to the neutral band or
when the max-hold timer expires. If one leg is missing, the remaining leg is
closed as a broken package. Framework Friday close remains enabled.

## 6. Source Citation

The source packet is `strategy-seeds/sources/CME-GAS-SILVER-RELVAL-2026/source.md`.
The cited market references are official CME Group product pages for Henry Hub
Natural Gas futures and Silver futures:

- `https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html`
- `https://www.cmegroup.com/markets/metals/precious/silver.html`

## 7. Risk Model

Backtests use the V5 `RISK_FIXED` contract with `RISK_FIXED=1000` and
`RISK_PERCENT=0`. Live risk is not configured by this build. Each basket leg
receives an ATR hard stop, and basket-level exits are deterministic neutral-band,
max-hold, broken-package, and framework Friday-close exits.
