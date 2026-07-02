# QM5_12963 WTI Winter Heating-Oil Exhaustion Fade

**EA ID:** QM5_12963
**Slug:** wti-winter-exhaust
**Card:** strategy-seeds/cards/wti-winter-exhaust_card.md

## 1. Strategy Logic

Short-only D1 XTIUSD.DWX winter exhaustion fade. The EA trades only during the
November 1 through February 28 heating-oil shock window. It sells after the
prior closed D1 bar is stretched above SMA(50), has sufficient ATR-normalized
range and body, and closes as a bearish rejection in the lower part of its own
range. The thesis is that winter heating-oil demand shocks can produce sharp
upside moves that sometimes exhaust back toward a slow crude-oil mean.

Exits are deterministic: close on SMA mean reversion, close outside the winter
window, close after the max-hold timeout, or let the hard ATR stop handle adverse
movement. The implementation does not read EIA, weather, inventory, futures
curve, CSV, API, or live external data.

## 2. Parameters

- `strategy_atr_period=20`
- `strategy_mean_period=50`
- `strategy_min_range_atr=0.60`
- `strategy_min_body_ratio=0.25`
- `strategy_reversal_tail_ratio=0.45`
- `strategy_min_stretch_atr=0.60`
- `strategy_atr_sl_mult=2.75`
- `strategy_max_hold_days=7`
- `strategy_winter_start_month=11`
- `strategy_winter_start_day=1`
- `strategy_winter_end_month=2`
- `strategy_winter_end_day=28`
- `strategy_max_spread_points=1000`

## 3. Symbol Universe

- Host and traded symbol: `XTIUSD.DWX`
- Magic slot: 0
- Single-symbol only; no basket legs and no symbol fallback.

## 4. Timeframe

- Host timeframe: D1
- Signal timeframe: D1 closed bars only
- No cross-timeframe reads.

## 5. Expected Behaviour

Expected frequency is approximately 5-12 trades per year before Q02 validates
actual Darwinex history. The EA is low-frequency, short-only, and should remain
flat outside the winter window. It must never pyramid, grid, martingale, partial
close, trail, touch live deployment manifests, or alter portfolio admission.

Non-duplicate boundary: this is not `QM5_12583` winter distillate long breakout,
not `QM5_12748` winter distillate long pullback, and not `QM5_12593`
spring/autumn refinery-turnaround fade. It trades only short-side winter
rejection bars after an upside stretch from the D1 mean.

## 6. Source Citation

Primary source: U.S. Energy Information Administration, "Factors affecting
heating oil prices", Energy Explained,
https://www.eia.gov/energyexplained/heating-oil/factors-affecting-heating-oil-prices.php.

Supplement: U.S. Energy Information Administration, "What drives crude oil
prices: Balance", https://www.eia.gov/finance/markets/crudeoil/balance.php.

The sources provide structural lineage only. No source performance claim is
imported into the card or EA.

## 7. Risk Model

Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Live risk is intentionally not configured by this build.
The hard stop is ATR(20) * 2.75 from entry by default. Friday close remains
enabled through the V5 framework.
