# QM5_1187 qp-comm-voltarget-mom

## Intent

Build-only V5 implementation of the approved Strategy Card `QM5_1187_qp-comm-voltarget-mom`.

The EA trades a DWX commodity proxy basket using monthly cross-sectional momentum normalized by trailing realized volatility.

## Universe

- `XAUUSD.DWX`
- `XAGUSD.DWX`
- `XTIUSD.DWX`
- `XNGUSD.DWX`
- `XCUUSD.DWX`

## Strategy Mapping

- No-trade: D1 timeframe only, current symbol must be in the approved commodity basket.
- Entry: on month-end closed-bar rebalance, compute 12-month ROC and 63-session annualized realized volatility for each eligible proxy. Score is `ROC12M / max(vol63d, floor_vol)`. Long the current symbol when it ranks in the selected top group.
- Management: no discretionary trailing, break-even, or partial close.
- Exit: at a monthly rebalance, close held symbols that no longer rank in the selected top group.

With the current five-symbol basket, the Card's narrow-universe rule selects top 3. If future approved proxies expand the basket to six or more, the existing input defaults select top 4.

## Risk And Sizing

V5 risk inputs are used unchanged:

- Backtest sets use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live sets use `RISK_FIXED=0`, `RISK_PERCENT=0.25`.
- `PORTFOLIO_WEIGHT=0.33` to approximate equal risk allocation across the top-three selected commodity legs.

An ATR stop is used as the V5 risk-distance contract for lot sizing. It is not a discretionary alpha exit; monthly rebalance remains the strategy exit.

## Registry

- `ea_id=1187`
- Magic formula: `magic = 1187 * 10000 + symbol_slot`
- Slots `0..4` map to the five commodity proxies above.

## Boundaries

No backtests or pipeline phases were run during the build.
