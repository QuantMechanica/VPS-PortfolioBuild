# QM5_1073 as-vaa-breadth SPEC

## Strategy Logic

Allocate Smartly / Keller-Keuning Vigilant Asset Allocation breadth momentum port.
On the first D1 bar after a month changes, the EA evaluates completed MN1
closes for every offensive proxy:

- SP500.DWX
- NDX.DWX
- WS30.DWX
- GDAXI.DWX

For each proxy it computes:

`12 * (p0 / p1 - 1) + 4 * (p0 / p3 - 1) + 2 * (p0 / p6 - 1) + (p0 / p12 - 1)`

`p0` is the last completed monthly close. `p1`, `p3`, `p6`, and `p12` are the
completed monthly closes one, three, six, and twelve months before `p0`.

If all offensive proxies score above `strategy_score_floor`, the EA selects
the offensive proxy with the highest score. Only the chart attached to that
symbol opens a long position. If one or more offensive proxies fail the
breadth test, the sleeve stays flat/cash by default. `strategy_use_defensive_proxy`
can enable XAUUSD.DWX as a single approved crisis-proxy variant, but the
canonical backtest setfiles leave it disabled.

Exit is monthly only. An open long is closed on a rebalance date when the chart
symbol is no longer the selected proxy or when breadth moves to cash.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| qm_ea_id | 1073 | fixed | V5 EA identifier. |
| qm_magic_slot_offset | 0 | registry slot | Symbol slot from magic_numbers.csv. |
| RISK_PERCENT | 0.0 | >= 0 | Live risk input, inactive in backtest setfiles. |
| RISK_FIXED | 1000.0 | > 0 | Backtest fixed risk in USD. |
| PORTFOLIO_WEIGHT | 1.0 | > 0 | Framework portfolio weighting. |
| strategy_min_monthly_bars | 14 | >= 14 | Required MN1 history for 12-month score. |
| strategy_score_floor | 0.0 | any | Breadth threshold for positive momentum. |
| strategy_use_defensive_proxy | false | bool | Enables XAUUSD.DWX risk-off proxy instead of flat cash. |
| strategy_atr_period | 20 | >= 1 | ATR period for framework stop placement. |
| strategy_atr_sl_mult | 4.0 | > 0 | ATR multiple for stop placement and risk sizing. |
| strategy_take_profit_rr | 0.0 | >= 0 | Optional RR take-profit; 0 disables. |
| strategy_max_spread_points | 5000 | >= 0 | Entry no-trade spread guard. |

## Symbol Universe

| Slot | Symbol | Role |
|---:|---|---|
| 0 | SP500.DWX | Offensive US equity proxy |
| 1 | NDX.DWX | Offensive US growth equity proxy |
| 2 | WS30.DWX | Offensive US large-cap proxy |
| 3 | GDAXI.DWX | Offensive foreign equity / EU proxy |
| 4 | XAUUSD.DWX | Optional defensive proxy, disabled by default |

The EA refuses to trade if the chart symbol and `qm_magic_slot_offset` do not
match this table.

## Timeframe

Base execution timeframe: D1. Signal data: completed MN1 closes. The first D1
bar after a month change acts as the monthly rebalance event.

## Source Citation

Approved card:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1073_as-vaa-breadth.md`.
Source references in the card cite Allocate Smartly's VAA article and Keller
and Keuning (2017), "Breadth Momentum and Vigilant Asset Allocation", SSRN id
3002624.

## Risk Model

Backtest setfiles use V5 Fixed Risk with `RISK_FIXED=1000` and
`RISK_PERCENT=0`. Live promotion uses percent risk only after owner-approved
deployment packaging. Friday close is disabled because the card's holding rule
is monthly rotation rather than weekly liquidation.
