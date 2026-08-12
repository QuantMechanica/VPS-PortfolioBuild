# QM5_11592 robo-3candle-fade-h4

**EA ID:** QM5_11592

## 1. Strategy Logic

This per-symbol H4 strategy fades a completed directional run. Three strictly
lower closed-bar closes trigger a long entry; three strictly higher closes
trigger a short entry. It uses only closed OHLC bars and ATR-scaled risk
controls. An opposite three-close run exits the position, while an ATR trail,
hard stop, take profit, central news gate, and framework Friday close provide
the remaining controls.

## 2. Parameters

| Input | Default | Meaning |
|---|---:|---|
| `qm_ea_id` | `11592` | Allocated V5 EA ID. |
| `qm_magic_slot_offset` | per set | `0` for EURUSD and `1` for GBPUSD. |
| `RISK_FIXED` | `1000` | Fixed-dollar risk used by backtest setfiles. |
| `RISK_PERCENT` | `0` | Disabled in backtests. |
| `strategy_run_length` | `3` | Consecutive H4 close comparisons required. |
| `strategy_atr_period` | `14` | ATR lookback for stop, target, and trail. |
| `strategy_sl_atr_mult` | `2.0` | Initial stop distance in ATR units. |
| `strategy_tp_atr_mult` | `2.5` | Initial target distance in ATR units. |
| `strategy_use_atr_trail` | `true` | Enables framework ATR trailing. |
| `strategy_trail_atr_mult` | `2.0` | ATR trail distance. |
| `strategy_use_opposite_exit` | `true` | Enables opposite-run exit. |
| `strategy_spread_pct_of_stop` | `15.0` | Entry spread cap as a percent of stop distance. |

## 3. Symbol Universe

- `EURUSD.DWX`, magic slot `0`.
- `GBPUSD.DWX`, magic slot `1`.

The EA rejects other symbols. It is a per-symbol sleeve, not a logical basket,
so it does not require a `basket_manifest.json`.

## 4. Timeframe

H4 only. Entry and opposite-exit decisions use completed H4 closes. The
framework new-bar gate limits entries to one evaluation per closed bar.

## 5. Expected Behaviour

The approved card declares roughly 60–140 candidate runs per year per symbol,
with one open position per symbol/magic. Actual entries will be lower because
positions, spread, news, and Friday gates suppress overlapping signals.
Mean-reversion losses are expected to cluster in persistent trends.

## 6. Source Citation

RoboForex educational team, *RoboForex Strategy Collection* (2020), page 107,
“Strategy Three Candles.” The governed card records `r1_track_record: PASS`,
`r2_mechanical: PASS`, `r3_data_available: PASS`, and
`r4_ml_forbidden: PASS`.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Stops and targets are fixed multiples of closed-bar ATR;
there is no ML, adaptive sizing, grid, martingale, pyramiding, or external
market-data dependency. This build does not authorize live deployment.
