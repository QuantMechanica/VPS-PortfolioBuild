# D2c Flat 0.75% Risk Recheck - 2026-06-28

Scope: read-only recheck of the D2c 13-sleeve live book after OWNER clarified that the
`RISK_PERCENT=0.7500`, `PORTFOLIO_WEIGHT=1.0` setfile policy was intentional.

## Framework Semantics

`QM_RiskSizerRiskMoney()` computes:

```text
risk_money = equity * (RISK_PERCENT / 100) * PORTFOLIO_WEIGHT
```

Therefore the current live slot setfiles express a true flat per-trade policy:

```text
0.7500% * 1.0 = 0.7500% account risk per EA trade
```

This is below the framework per-trade cap of 1%.

## Recheck Results

Basis:

- Book: `C:\QM\deploy\GoLive_D2c_13sleeve_2026-06-28\manifest_d2c_13sleeve_2026-06-28.json`
- Streams: `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades`
- Capital: `$100,000`
- Backtest stream scale: `RISK_FIXED=$1000`, approximately 1% risk/trade
- Monte Carlo: 3,000 runs, 20-day blocks, seed 42

| policy | all-open risk | observed DD | MC-p95 DD | net profit | worst day |
|---|---:|---:|---:|---:|---:|
| Current manifest KPI weights (`w`) | 1.00% | 0.51% | 0.90% | $6,659.76 | -0.16% |
| Risk-parity actual 2% total (`2*w`) | 2.00% | 1.02% | 1.74% | $13,319.52 | -0.32% |
| Flat 0.10% per EA | 1.30% | 3.95% | 4.58% | $11,772.95 | -0.49% |
| Flat 0.125% per EA | 1.625% | 4.91% | 5.66% | $14,716.19 | -0.61% |
| Flat 0.15% per EA | 1.95% | 5.87% | 6.76% | $17,659.43 | -0.73% |
| Flat 0.225% per EA | 2.925% | 8.70% | 9.91% | $26,489.14 | -1.10% |
| Flat 0.25% per EA | 3.25% | 9.63% | 10.91% | $29,432.38 | -1.22% |
| Flat 0.50% per EA | 6.50% | 18.52% | 20.06% | $58,864.75 | -2.45% |
| Flat 0.75% per EA | 9.75% | 26.75% | 28.57% | $88,297.13 | -3.67% |

## Interpretation

The current live setfiles are internally consistent with a deliberate flat 0.75% per-trade
policy, but that policy is not consistent with the D2c manifest's low-drawdown portfolio cap.

Under the available Q08 evidence, flat 0.75% per EA is a high-risk portfolio setting:

- It stacks to 9.75% if all 13 sleeves have an open position.
- The historical path reaches 26.75% drawdown.
- The MC-p95 drawdown reaches 28.57%.
- Sharpe drops materially versus the risk-parity book because equal per-trade risk lets higher
  volatility / higher activity sleeves dominate the portfolio.

Flat sizing can be kept, but the flat value should be selected against the portfolio DD cap:

- For a 6% MC-p95 cap, flat risk is around 0.125% per EA.
- For a 10% MC-p95 cap, flat risk is around 0.225% per EA.

## Open Artifact Issue

The D2c manifest still records inverse-vol/risk-parity `set_file_expectation` values. If flat
per-trade risk is the OWNER-approved policy, the manifest and go-live validator should represent
that explicitly as a flat-risk policy rather than treating the live setfiles as accidental drift.
