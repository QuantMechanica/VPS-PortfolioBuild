# DL-026 Portfolio Aggregate DXZ Gate (2026-05-09)

## Context
- OWNER scope amendment (2026-05-09): per-EA DXZ drawdown checks are soft signals.
- Binding compliance before T6 promotion is portfolio-aggregate drawdown against DarwinexZero kill limits.

## Decision
- Keep per-EA `dxz_compliance_gate.py` as evidence/diagnostic only.
- Add `portfolio_aggregate_gate.py` as binding gate target for basket composition and pre-T6 promotion.
- Preserve thresholds in `framework/registry/tester_defaults.json`:
  - `daily_dd = 0.05`
  - `total_dd = 0.20`
- Require correlation reporting (`pearson`) per pair in basket evidence.

## Rationale
- Account kill is triggered on account-level drawdown, not single-EA drawdown.
- Portfolio construction is the explicit risk control mechanism in the amended mission baseline.

## Implementation Notes
- Phase outputs now include `dxz_verdict` as soft-signal column in phase `report.csv` artifacts.
- Portfolio gate emits `BASKET_PASS` / `BASKET_FAIL` and pairwise correlation matrix for review.
