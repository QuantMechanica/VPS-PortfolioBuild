# QM5_1090 aa-dualmom-pairs SPEC

## Strategy Logic

Alpha Architect pairwise dual momentum. On the first D1 bar after a month changes, the EA compares the configured symbol with its paired asset using 12 completed monthly closes. The symbol with the higher 12-month total return is the relative-momentum winner. The EA goes long only if the chart symbol is that winner and its own 12-month total return is positive. If the winner's return is not positive, the sleeve stays in cash.

Exit is monthly only. An open position is closed on the monthly rebalance if the chart symbol is no longer the pair winner or if its 12-month return is no longer positive.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| qm_ea_id | 1090 | fixed | V5 EA identifier. |
| qm_magic_slot_offset | 0 | registry slot | Symbol slot from magic_numbers.csv; setfile generator fills this per symbol. |
| RISK_PERCENT | 0.0 | >= 0 | Live risk input, inactive in backtest setfiles. |
| RISK_FIXED | 1000.0 | > 0 | Backtest fixed risk in USD. |
| PORTFOLIO_WEIGHT | 1.0 | > 0 | Framework portfolio weighting. |
| strategy_momentum_months | 12 | >= 1 | Completed monthly closes used for relative and absolute momentum. |
| strategy_atr_period | 14 | >= 1 | ATR period for the build-default stop. |
| strategy_atr_sl_mult | 3.0 | > 0 | ATR multiple for stop placement and risk sizing. |
| strategy_monthly_only | true | bool | Keeps entry and exit decisions on monthly rebalance cadence. |

## Symbol Universe

Registered R3 pair basket:

| Pair | Slots |
|---|---|
| SP500.DWX / GDAXI.DWX | 0 / 1 |
| NDX.DWX / WS30.DWX | 2 / 3 |
| XAUUSD.DWX / XTIUSD.DWX | 4 / 5 |
| EURUSD.DWX / USDJPY.DWX | 6 / 7 |

The EA does not trade symbols outside these registered pairs.

## Timeframe

Base execution timeframe: D1. Signal data: completed MN1 closes. The first D1 bar after a month change acts as the monthly rebalance event.

## Expected Behaviour

Expected cadence is about 12 monthly decisions per symbol per year, with fewer actual trades because cash mode is possible and existing winners can remain held across rebalance dates. The strategy prefers persistent relative and absolute momentum regimes.

## Source Citation

Alpha Architect, Wesley Gray, PhD, "A Tactical Asset Allocation Horserace Between Two Thoroughbreds", 2015-02-13. Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1090_aa-dualmom-pairs.md`.

## Risk Model

Backtest setfiles use V5 Fixed Risk with `RISK_FIXED=1000` and `RISK_PERCENT=0`. Live promotion uses percent risk only after the owner-approved live workflow, conventionally `RISK_PERCENT=0.5`.
