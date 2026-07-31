# QM5_20183_gbpusd-chf-coint — Strategy Spec

- **EA ID:** QM5_20183
- **Slug:** gbpusd-chf-coint
- **Source:** claude_cross_asset_discovery_2026-06-09 with Chan SRC02 pair-trade method
- **Last revised:** 2026-07-31

## Strategy logic

Trade the fixed GBPUSD.DWX / USDCHF.DWX D1 spread
`ln(GBPUSD) - beta * ln(USDCHF)` with `beta=-0.651268047`. Score the newest
closed spread against the strictly preceding 60 aligned D1 spreads.

- Enter short spread at `z > 2.0`: short both legs.
- Enter long spread at `z < -2.0`: long both legs.
- Exit both legs at `abs(z) < 0.5`.
- Attach an `ATR(20, D1) * 2.0` hard stop to each leg.
- Roll back partial entry and flatten any orphan leg.

The negative beta is sign-aware: same-direction leg orders partly offset USD
exposure because the two pairs use opposite USD quote orientation.

## Selection evidence

The sign-aware 66-pair rerun ranked GBPUSD/USDCHF seventh by OOS net Sharpe
and first among pairs without a dedicated cointegration card or EA:

| DEV Sharpe | OOS net Sharpe | OOS return | OOS state changes | Beta | Half-life |
|---:|---:|---:|---:|---:|---:|
| -0.374993 | 0.939211 | 5.182890% | 14 | -0.651268047 | 116.976 D1 bars |

The negative DEV result is an explicit instability risk. A terminal economic
failure is not eligible for an unplanned filter or parameter rescue.

## Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_z_lookback_d1 | 60 | Strictly prior D1 spread calibration bars |
| strategy_beta | -0.651268047 | Fixed DEV hedge coefficient |
| strategy_entry_z | 2.0 | Absolute entry threshold |
| strategy_exit_z | 0.5 | Mean-reach exit threshold |
| strategy_atr_period_d1 | 20 | Per-leg ATR period |
| strategy_atr_sl_mult | 2.0 | Per-leg hard-stop multiplier |
| strategy_deviation_points | 20 | Market-order deviation |

## Symbols and risk

- Host: `GBPUSD.DWX`
- Second leg: `USDCHF.DWX`
- Logical symbol: `QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1`
- Timeframe: D1
- Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Live artifacts: not authorized

## Source

- Approved card:
  `strategy-seeds/cards/gbpusd-chf-coint_card.md`
- Method evidence:
  `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- Pair-selection evidence:
  `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- Reproduction:
  `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`
