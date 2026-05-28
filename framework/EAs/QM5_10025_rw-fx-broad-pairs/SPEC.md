# QM5_10025 rw-fx-broad-pairs

## Strategy Logic

Robot Wealth FX Broad Pairs Trading is a broad FX mean-reversion pairs strategy. Each H4 chart symbol is treated as the host leg. At monthly rebalance, the EA compares the host symbol against the approved FX universe, estimates a rolling OLS hedge ratio over 252 H4 bars, and keeps the highest-correlation partner that passes the mechanical filters.

Entry uses the spread:

`spread = log(host_close) - beta * log(partner_close)`

The EA computes a z-score over 120 closed H4 bars. If z-score is above `+2.0`, it shorts the spread by selling the host leg and buying the beta-weighted partner leg. If z-score is below `-2.0`, it buys the spread by buying the host leg and selling the beta-weighted partner leg. It opens one spread at a time for the selected host/partner pair.

Exit occurs when absolute z-score reaches the configured exit band, when the spread reaches the hard stop band, or when the 15-bar time stop has elapsed without at least 25 percent z-score improvement. The framework Friday close can also close positions.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `qm_ea_id` | `10025` | fixed | V5 EA identifier. |
| `qm_magic_slot_offset` | `0` | setfile slot | Symbol slot seed used by framework magic resolution. |
| `RISK_PERCENT` | `0.0` | `0.0+` | Live risk input, visible but inactive in backtest setfiles. |
| `RISK_FIXED` | `1000.0` | `0.0+` | Backtest fixed dollar risk per spread sleeve. |
| `PORTFOLIO_WEIGHT` | `1.0` | `0.0..1.0` | Portfolio sleeve weight applied by the framework risk model. |
| `qm_news_temporal` | `QM_NEWS_TEMPORAL_PRE30_POST30` | enum | Temporal news blackout mode. |
| `qm_news_compliance` | `QM_NEWS_COMPLIANCE_DXZ` | enum | Compliance overlay for news filtering. |
| `qm_news_stale_max_hours` | `336` | positive int | Maximum news-calendar age before setup failure. |
| `qm_news_min_impact` | `high` | `low/medium/high` | Minimum impact level used by news filtering. |
| `qm_news_mode_legacy` | `QM_NEWS_OFF` | enum | Legacy news input retained for framework compatibility. |
| `qm_friday_close_enabled` | `true` | bool | Enables framework Friday close. |
| `qm_friday_close_hour_broker` | `21` | `0..23` | Broker hour for forced Friday close. |
| `qm_stress_reject_probability` | `0.0` | `0.0..1.0` | Q06 stress rejection probability; zero outside stress phases. |
| `strategy_formation_bars` | `252` | `>=60` | H4 bars for OLS hedge ratio, correlation, and stationarity proxy. |
| `strategy_zscore_bars` | `120` | `>=20` | H4 bars for spread z-score mean and standard deviation. |
| `strategy_min_corr` | `0.70` | `0.0..1.0` | Minimum rolling return correlation for monthly pair selection. |
| `strategy_adf_t_max` | `-1.30` | negative double | Deterministic ADF-style stationarity proxy threshold. |
| `strategy_entry_z` | `2.0` | positive double | Absolute z-score threshold for entry. |
| `strategy_exit_z` | `0.0` | `>=0.0` | Absolute z-score threshold for mean-reversion exit. |
| `strategy_spread_stop_z` | `3.0` | positive double | Hard spread stop in z-score units. |
| `strategy_atr_period` | `14` | positive int | H4 ATR period for per-leg emergency stop. |
| `strategy_atr_sl_mult` | `2.0` | positive double | ATR multiplier for per-leg emergency stop. |
| `strategy_time_stop_bars` | `15` | positive int | Maximum H4 bars before improvement test. |
| `strategy_min_improve_frac` | `0.25` | `0.0..1.0` | Required z-score improvement by time stop. |
| `strategy_max_spread_points` | `50` | positive int | Maximum broker spread in points for each basket symbol. |

## Symbol Universe

The approved P2 basket is:

`EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCHF.DWX`, `USDCAD.DWX`, `USDJPY.DWX`

The EA explicitly does not trade non-card symbols. Other DWX FX crosses, indices, metals, and energy symbols are outside this card's R3 basket.

## Timeframe

Base timeframe is H4. All formation, z-score, ATR stop, monthly rebalance, entry, and exit logic uses closed H4 bars. The smoke and P2 setfiles are generated on H4.

## Expected Behaviour

Expected trade frequency from the card is about 45 trades per year per pair-symbol. Typical holds are mean-reversion holds up to 15 H4 bars unless the z-score exits sooner. The strategy prefers correlated, stationary FX pair regimes and is expected to degrade when correlation falls below 0.50.

## Source Citation

Source ID: `dcbac84f-6ecf-5d21-9630-50faa69306ec`

Citation: Robot Wealth, "Index of Strategies", FX Broad Pairs Trading section, https://robotwealth.com/index-of-strategies/

## Risk Model

Backtests use fixed risk with `RISK_FIXED = 1000.0` and `RISK_PERCENT = 0.0` per HR4. Live promotion uses percent risk via deploy manifest with `RISK_PERCENT = 0.5` and `RISK_FIXED = 0.0`. Position sizing is delegated to the V5 framework risk helpers.

## Implementation Notes

The Strategy Card requires true two-leg spread execution. The EA uses the local V5 basket order helper for the partner leg while retaining the five strategy hooks and framework guards. The card calls for ADF p-value `< 0.10`; the EA implements a deterministic ADF-style t-statistic proxy because there is no framework ADF helper.
