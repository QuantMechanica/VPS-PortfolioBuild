# QM5_10024 rw-fx-comm-basket

## Strategy Logic

The EA mechanises the approved Robot Wealth FX commodity basket mean-reversion card on D1 bars. It reads AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, and AUDNZD.DWX, builds a frozen-weight log spread, and computes a 60-bar z-score.

Default spread:

```text
spread = 1.0 * log(AUDUSD) + 1.0 * log(NZDUSD) - 1.0 * log(USDCAD) - 1.0 * log(AUDNZD)
```

When z-score is above +2.0, the basket is treated as rich and each leg trades opposite its hedge-weight sign. When z-score is below -2.0, the basket is treated as cheap and each leg trades with its hedge-weight sign. The V5 runner executes one chart symbol per run, so each registered symbol receives its own slot and trades its basket leg from the same shared spread signal.

Exit occurs when the cached spread z-score is back inside +/-0.50, when the position has been held for 20 trading days, or when the z-score reaches the card's catastrophic basket threshold of 2.5 standard deviations. Each leg also has a 2.0 * ATR(14,D1) platform stop.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback` | 60 | >=10 | D1 bars used for spread z-score mean and standard deviation. |
| `strategy_z_entry` | 2.0 | >0 | Absolute z-score threshold for basket entry. |
| `strategy_z_exit` | 0.50 | >=0 | Absolute z-score threshold for mean-reversion exit. |
| `strategy_time_stop_days` | 20 | >=0 | Maximum calendar-day hold before strategy exit. |
| `strategy_atr_period` | 14 | >0 | ATR period for platform SL. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple for platform SL. |
| `strategy_catastrophe_sigma` | 2.5 | >0 | Basket-level catastrophic z-score exit threshold. |
| `strategy_max_spread_points` | 40 | >=0 | Max current spread points allowed on each basket leg. |
| `strategy_weight_audusd` | 1.0 | fixed/sweep | Frozen hedge weight for AUDUSD.DWX. |
| `strategy_weight_nzdusd` | 1.0 | fixed/sweep | Frozen hedge weight for NZDUSD.DWX. |
| `strategy_weight_usdcad` | -1.0 | fixed/sweep | Frozen hedge weight for USDCAD.DWX. |
| `strategy_weight_audnzd` | -1.0 | fixed/sweep | Frozen hedge weight for AUDNZD.DWX. |

## Symbol Universe

Registered symbols are AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, and AUDNZD.DWX. The EA intentionally rejects any chart symbol outside that four-leg basket and rejects a chart whose `qm_magic_slot_offset` does not match the registered symbol slot.

## Timeframe

Base timeframe is D1. The EA rejects non-D1 tester periods because the card specifies daily close evaluation and a 60 D1 bar z-score.

## Expected Behaviour

The approved card estimates roughly 35 trades per year per symbol. This is a mean-reversion/stat-arb sleeve and should trade during dislocations in the commodity-currency basket, with typical holds up to 20 trading days unless the z-score normalises sooner.

## Source Citation

Source ID: `dcbac84f-6ecf-5d21-9630-50faa69306ec`.

Robot Wealth, "Index of Strategies" FX Commodity basket section, plus Kris Longmore's Robot Wealth posts on mean reversion and cointegration.

## Risk Model

Backtests use fixed risk with `RISK_FIXED=1000` and `RISK_PERCENT=0`. Live deployment uses percent risk through a separate manifest/setfile with `RISK_PERCENT=0.5` and `RISK_FIXED=0`, subject to OWNER approval.
