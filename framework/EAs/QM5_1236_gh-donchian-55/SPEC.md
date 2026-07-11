# QM5_1236 GitHub Donchian 55 Breakout

**EA ID:** QM5_1236
**Slug:** `gh-donchian-55`
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1236_gh-donchian-55.md`
**Last revised:** 2026-07-11

## 1. Strategy Logic

The EA trades a completed-bar D1 Donchian trend breakout. It enters long when
the last completed close exceeds the prior 55-day high and enters short when
the close falls below the prior 55-day low. Entries also require ATR(20) to be
above 70% of its 120-day median and the current spread to be no wider than
twice its 60-day median when usable spread history exists.

One position is allowed per symbol and registered magic. The initial hard stop
is 2.5 ATR(20). After profit reaches 1R, the stop can trail to the opposing
20-day channel. A position exits on an opposing 20-day channel break or after
120 D1 bars. All price-window reads use completed bars through the framework's
`QM_ReadBar` and pooled indicator helpers.

## 2. Parameters

| Parameter | Default | Purpose |
|---|---:|---|
| `strategy_entry_channel_days` | 55 | Prior D1 channel used for entry |
| `strategy_exit_channel_days` | 20 | Prior D1 channel used for exit and trailing |
| `strategy_atr_period` | 20 | ATR lookback |
| `strategy_atr_median_days` | 120 | ATR regime baseline |
| `strategy_atr_median_mult` | 0.70 | Minimum ATR relative to its median |
| `strategy_atr_sl_mult` | 2.50 | Initial hard-stop distance |
| `strategy_trail_after_r` | 1.00 | Profit threshold for channel trailing |
| `strategy_max_hold_bars` | 120 | D1 time stop |
| `strategy_min_history_bars` | 120 | Minimum D1 warmup |
| `strategy_spread_median_days` | 60 | Spread baseline |
| `strategy_spread_mult` | 2.00 | Maximum spread relative to baseline |
| `strategy_use_trend_filter` | false | Optional 100/200 SMA direction filter |
| `strategy_fast_sma_period` | 100 | Optional fast SMA |
| `strategy_slow_sma_period` | 200 | Optional slow SMA |

## 3. Symbol Universe

The approved and registered D1 universe is `EURUSD.DWX`, `GBPUSD.DWX`,
`USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`, `XAUUSD.DWX`,
`XTIUSD.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, and `UK100.DWX`.
Each setfile resolves the symbol's active registry slot; no foreign-symbol data
is read. The 2026-07-11 infrastructure recovery prioritizes `NZDUSD.DWX` for
forex diversity.

## 4. Timeframe

The execution and signal timeframe is D1. Signals use completed bars only and
are evaluated once per new D1 bar. There are no cross-timeframe references.

## 5. Expected Behaviour

The approved card estimates about 18 trades per year per symbol. This is a
low-frequency trend sleeve: positions may last weeks or months, losses are
bounded by an ATR hard stop, and there is no grid, martingale, pyramiding, or
machine-learning component.

## 6. Source Citation

The approved card derives the deterministic Donchian 55/20 breakout from the
GitHub algorithmic-trading catalogue at
`https://github.com/topics/algorithmic-trading`. Its G0 review records R1-R4 as
PASS: traceable source lineage, fully mechanical rules, available DWX D1 data,
and no ML.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The framework sizes from the ATR stop distance and the
registered per-symbol magic slot. Live risk is outside this recovery scope;
no live setfile or deployment artifact is created or modified.

## Revision History

| Version | Date | Change |
|---|---|---|
| v1 | 2026-07-11 | Added canonical spec during NZDUSD Q02 infrastructure recovery; documented unchanged approved rules and current framework data access. |
