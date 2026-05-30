# QM5_1173 qp-eafe-spy-sma-spread

## Source Card

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1173_qp-eafe-spy-sma-spread.md`
- Source: Quantpedia, "Systematic Allocation in International Equity Regimes"
- Status: G0 APPROVED

## Strategy Mapping

- Timeframe: `MN1`
- Host chart: EAFE proxy leg only
- Slot `0`: `GDAXI.DWX` versus `SP500.DWX`
- Slot `1`: `UK100.DWX` versus `SP500.DWX`
- Spread index: cumulative monthly log return differential, EAFE proxy minus US proxy.
- Signal: if closed-month spread is above or equal to SMA, hold long EAFE and short US; otherwise hold short EAFE and long US.
- Rebalance: monthly, once per newly closed monthly bar.
- Exit/reversal: close and reverse both legs when the monthly SMA state changes.
- Missing data: close both legs when configured by `strategy_close_on_missing_data`.
- Risk: total spread risk is split equally across both legs.

## Risk And Stops

- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live default: `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- Per-leg emergency stop: `strategy_leg_atr_stop_mult * MN1 ATR`.
- Strategy spread stop: close both legs when adverse spread move exceeds `strategy_spread_atr_stop_mult * monthly spread ATR`.

## V5 Alignment

- Uses V5 framework inputs and lifecycle.
- Uses `QM_Magic(ea_id, strategy_pair_slot)` for pair magic.
- Uses Darwinex `.DWX` symbols only in build/test artifacts.
- No ML, grid, martingale, external API, or pipeline phase execution.

## Notes

`SP500.DWX` is the US proxy specified by the card. Live promotion needs deploy-time symbol routing validation because both legs must be tradable in the target terminal.
