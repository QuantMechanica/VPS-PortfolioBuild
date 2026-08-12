---
ea_id: 11592
slug: robo-3candle-fade-h4
source_id: ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
source_title: "RoboForex Strategy Collection — 40+ Mechanical Forex Strategies"
source_author: RoboForex educational team
source_year: 2020
source_citation: "RoboForex Strategy Collection, 2020, p.107, Strategy Three Candles, https://roboforex.com/beginners/analytics/forex-forecast/technical-analysis/"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_status: APPROVED
period: H4
target_symbols: [EURUSD.DWX, GBPUSD.DWX]
expected_trades_per_year_per_symbol: 80
---

# QM5_11592 — RoboForex Three-Candle Fade H4

## Edge thesis

After three consecutive bars each closing higher or lower than the prior bar,
short-term price extension makes a mean reversion plausible. The rule is a
deterministic closed-price structure with no derived entry indicator.

## Entry rules

- Long after three consecutive lower H4 closes.
- Short after three consecutive higher H4 closes.
- Enter on the next H4 bar, one position per symbol and magic.

## Exit and risk rules

- Initial stop: `2.0 * ATR(14,H4)`.
- Initial target: `2.5 * ATR(14,H4)`, preserving the source’s approximate
  `50/40` reward/risk ratio.
- Exit on an opposite three-close run or the framework ATR trail.
- Backtest risk is `RISK_FIXED=1000`; percentage risk is disabled.

## Scope

The approved universe is `EURUSD.DWX` and `GBPUSD.DWX`. The strategy uses no
ML, adaptive parameters, grid, martingale, or external data.
