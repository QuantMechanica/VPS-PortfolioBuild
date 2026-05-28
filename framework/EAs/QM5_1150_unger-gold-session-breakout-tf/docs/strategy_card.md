---
ea_id: QM5_1150
slug: unger-gold-session-breakout-tf
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Unger Gold Session Breakout TF - Current-Session High/Low Trend

Local build copy of the APPROVED card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1150_unger-gold-session-breakout-tf.md`.

Universe: `XAUUSD.DWX`. Execution timeframe: `M15`.

The EA waits until the configured gold reference session range build is complete, computes the current-session high and low from session open through `RANGE_BUILD_END`, places a buy-stop above the high and a sell-stop below the low, cancels the unfilled side after a fill, and limits the strategy to one trade per day.

Default mechanics:

| Rule | Value |
|---|---:|
| Range build end | `10:00` New York time |
| Entry cutoff | `14:30` New York time |
| Buffer | `0.05 * ATR(14,M15)` |
| Stop loss | `1.5 * ATR(14,M15)` |
| Take profit | `2.0 * ATR(14,M15)` |
| Minimum range | `0.4 * ATR(14,D1)` |
| Maximum range | `1.5 * ATR(14,D1)` |
| Backtest risk | `RISK_FIXED = 1000` |
| Live risk | `RISK_PERCENT = 0.25` |

FOMC/CPI skip-day intent is mapped to the V5 high-impact skip-day news setting with DXZ compliance. No ML, grid, martingale, or external market-data calls are used.
