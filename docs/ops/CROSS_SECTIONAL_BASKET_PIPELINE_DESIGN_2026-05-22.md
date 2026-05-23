# Cross-Sectional Basket Pipeline Design - 2026-05-22

Task: `30d7b0fe-c14f-455f-a7ae-e372ae530950`

Applies to:

- `QM5_10717_edgelab-xsec-fx-momentum`
- `QM5_10718_edgelab-regime-filtered-carry`

Charter constraint: Edge Lab, Direction 1. The design must remain FTMO + DXZ compatible: <=5% daily DD, <=10% total DD, mandatory news blackout, swing horizon, no HFT, no martingale/grid, deterministic mechanical EA, no ML in EA.

## Decision

Represent each cross-sectional FX EA as one logical basket instrument, not as isolated per-symbol work.

Canonical logical symbol:

```text
FX8_BASKET_D1
```

Canonical host chart for MT5 execution:

```text
EURUSD.DWX / D1
```

The EA attaches to the host chart, then reads the full FX basket with `CopyRates()` for the other basket symbols. It opens and closes real positions on the selected DWX pairs from that one run. The host chart is only an execution anchor; it is not the market under test.

Do not fan out Q02+ into one isolated backtest per traded pair for these EAs. A per-symbol fanout would break the strategy because each isolated run would lack the full cross-section needed to rank currencies and choose legs.

## Build Contract

The EA must ship with a basket manifest next to the source:

```text
framework/EAs/<ea_dir>/basket_manifest.json
```

Required fields:

```json
{
  "logical_symbol": "FX8_BASKET_D1",
  "host_symbol": "EURUSD.DWX",
  "host_timeframe": "D1",
  "basket_symbols": [
    "EURUSD.DWX",
    "GBPUSD.DWX",
    "AUDUSD.DWX",
    "NZDUSD.DWX",
    "USDJPY.DWX",
    "USDCHF.DWX",
    "USDCAD.DWX",
    "EURGBP.DWX",
    "EURJPY.DWX",
    "EURCHF.DWX",
    "EURAUD.DWX",
    "EURNZD.DWX",
    "EURCAD.DWX",
    "GBPJPY.DWX",
    "GBPCHF.DWX",
    "GBPAUD.DWX",
    "GBPNZD.DWX",
    "GBPCAD.DWX",
    "AUDJPY.DWX",
    "AUDCHF.DWX",
    "AUDNZD.DWX",
    "AUDCAD.DWX",
    "NZDJPY.DWX",
    "NZDCHF.DWX",
    "NZDCAD.DWX",
    "CADJPY.DWX",
    "CADCHF.DWX",
    "CHFJPY.DWX"
  ],
  "currencies": ["USD", "EUR", "GBP", "JPY", "CHF", "AUD", "NZD", "CAD"]
}
```

The setfile is generated for the host symbol only:

```text
framework/EAs/<ea_dir>/sets/<ea_dir>_FX8_BASKET_D1_D1_backtest.set
```

The setfile should still declare the host chart internally where the MT5 runner needs a real symbol/timeframe, but all operator-facing evidence should report `FX8_BASKET_D1` as the tested instrument.

## Q00 Through Q14 Representation

Q00:

- Card review must mark the EA as `portfolio_scope: basket`.
- Q00/build review must require `basket_manifest.json`.
- For `QM5_10718`, Q00 must pin the carry-signal source before build: broker swap-rate proxy preferred; static policy-rate table only if explicitly documented.

Q01:

- Build validation remains unchanged except for one additional static check: basket EAs must have `basket_manifest.json` and must not use a per-symbol fallback that silently ranks only the host symbol.
- Compile, forbidden-technique scan, magic checks, setfile checks, and deployment checks remain normal.

Q02:

- Queue exactly one baseline work item per basket EA:
  - `symbol = FX8_BASKET_D1`
  - `host_symbol = EURUSD.DWX`
  - `timeframe = D1`
  - `basket_manifest = framework/EAs/<ea_dir>/basket_manifest.json`
- The runner invokes MT5 on `EURUSD.DWX / D1`, but the evidence row and report row use `FX8_BASKET_D1`.
- The EA writes a per-run basket evidence file containing selected legs, ranks, exposure by currency, gross/net exposure, and pair-level PnL.

Q03:

- Parameter sweep is a variant sweep, not a per-symbol sweep.
- Allowed dimensions must be predeclared in the card family, for example `lookback_days = 21/63` or `regime_filter = vol_median/vol_plus_trend`.
- Do not introduce broad optimizer freedom.

Q04:

- Cross-sectional robustness is evaluated across time slices and rank-construction variants, not isolated pair fanout.
- Required evidence:
  - basket-level expectancy and drawdown,
  - per-leg contribution table,
  - currency exposure table,
  - turnover and cost burden,
  - long/short side attribution.
- For `QM5_10717`, Q04 must compare the intended rank direction with the inverted long-bottom/short-top falsification variant.
- For `QM5_10718`, Q04 must compare filtered carry with naked carry.

Q05:

- Walk-forward keeps the same logical symbol and host chart.
- Training/selection windows may choose only predeclared variant members; no re-optimization of broad lookback/filter grids.

Q06:

- Stress testing applies spread, swap, slippage, and execution-cost perturbations to the basket as a whole.
- Pair-level costs must be included because leg turnover is part of the edge.

Q07:

- Calibrated noise keeps the same basket composition and host chart.
- Noise is applied to fills/costs and, where supported, bar paths for all basket symbols consistently within the run.

Q08:

- Crisis slices are evaluated at basket-equity level plus per-leg attribution.
- For Direction 1, Q08 is not optional: momentum crash risk and carry crash risk are the central falsification hazards.
- The gate verdict remains unchanged; the input evidence changes from many isolated symbol reports to one basket report with richer attribution.

Q09:

- Multi-seed repeats the logical basket run, preserving the same manifest and host symbol.
- Seeds vary runner stochastic elements only; they do not change the basket universe or add ML/model fitting.

Q10:

- Statistical validation uses basket-level return series.
- Required side evidence: per-leg return distribution and correlation of long and short books, so a single lucky pair cannot masquerade as a basket edge.

Q11:

- News impact uses the same mandatory blackout rule from the Edge Lab charter.
- Evidence must show no entries inside restricted windows and must attribute PnL around high-impact events at basket level and pair level.
- For `QM5_10718`, red-regime flat-out behavior around event volatility must be visible in the evidence.

Q12:

- Portfolio construction treats the whole EA as one sleeve with one equity curve, not 28 independent symbols.
- Pair-level exposure remains an internal risk report.

Q13:

- Operational readiness verifies that live deployment can attach one EA to the host chart and trade the selected basket pairs without duplicate instances.
- The manifest must define the one allowed host chart. Do not deploy one instance per pair.

Q14:

- Live burn-in remains a single-sleeve basket burn-in.
- AutoTrading remains an OWNER/LIVEOPS action only; this design note does not authorize live enabling.

## Evidence Files

Each run should produce, beside the normal report artifacts:

```text
basket_manifest_used.json
basket_rank_history.csv
basket_selected_legs.csv
basket_currency_exposure.csv
basket_pair_pnl.csv
basket_gate_summary.json
```

Minimum `basket_gate_summary.json` fields:

```json
{
  "logical_symbol": "FX8_BASKET_D1",
  "host_symbol": "EURUSD.DWX",
  "host_timeframe": "D1",
  "basket_symbol_count": 28,
  "currency_count": 8,
  "news_blackout_enabled": true,
  "max_daily_drawdown_pct": null,
  "max_total_drawdown_pct": null,
  "gross_exposure_max": null,
  "net_currency_exposure_max": null,
  "turnover_trades": null,
  "pair_level_cost_total": null
}
```

## Required Pipeline Wiring

Add a basket-aware queue branch that detects `basket_manifest.json` during Q01/Q02 enqueue and creates one logical-symbol work item instead of expanding the card universe into per-symbol work items.

The runner must pass the real host symbol/timeframe to MT5 while preserving the logical symbol in queue/report identity. This can be implemented without changing gate verdict semantics: the same verdict classifiers consume the same kind of performance metrics, but the report has one basket row plus attribution files instead of many isolated symbol rows.

## Non-Goals

- Do not loosen Q04, Q08, or Q11 thresholds.
- Do not add a portfolio-specific pass exception.
- Do not run isolated per-pair Q02 rows for these EAs.
- Do not deploy one live instance per pair.
- Do not add ML, optimizer-mined ranks, grid/martingale behavior, or news-window trading.

## Verification Performed

- Read active charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`.
- Read active profitability note: `docs/ops/PROFITABILITY_TRACK_2026-05-21.md`.
- Read cards:
  - `D:/QM/strategy_farm/artifacts/cards_review/QM5_10717_edgelab-xsec-fx-momentum.md`
  - `D:/QM/strategy_farm/artifacts/cards_review/QM5_10718_edgelab-regime-filtered-carry.md`
- Read thesis source: `docs/research/EDGE_THESES_CROSS_SECTIONAL_2026-05-22.md`.
- Confirmed Q-series display mapping in `tools/strategy_farm/phase_ids.py`.

## Verdict

`BASKET_PIPELINE_DESIGN_READY`

Codex can build `QM5_10717` and `QM5_10718` against this design by implementing each as a single host-chart EA with full-basket reads, a required manifest, one logical-symbol Q02 work item, and basket-level evidence for Q04/Q08/Q11.
