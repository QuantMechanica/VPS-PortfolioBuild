# FX Cointegration Frontier Audit - 2026-07-09

## Scope

Mission: grow the V5 book with non-duplicate forex sleeves, preferring
market-neutral FX cointegration baskets from the 66-pair scan and its July 6
extension.

This pass did not create a new Q02 row. The scan-derived frontier is already
built locally, and the remaining failures are downstream strategy/gate verdicts,
not current `ONINIT` or `NO_HISTORY` blockers.

## Checks

- Branch: `agents/board-advisor`.
- Strict scan source: `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.
- Extension scan source:
  `D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/survivors.json`.
- `QM5_12532` AUDUSD/NZDUSD: Q02 `PASS`, Q04 `PASS`, Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY: Q02 `PASS`, Q04 `FAIL`.
- Approved EdgeLab FX cointegration cards under `strategy-seeds/cards/approved`
  all have an EA directory, `.mq5`, `.ex5`, `basket_manifest.json`, and a
  logical `RISK_FIXED` backtest setfile.

## Extension Frontier

The July 6 extension scan's card-worthy or watchlist FX pairs are already built:

| EA | Pair | Current farm state |
|---|---|---|
| `QM5_13024` | AUDCAD/GBPAUD | Q02 `PASS`, Q04 `FAIL` |
| `QM5_13029` | GBPCAD/GBPNZD | Q02 `PASS`, Q03 `PASS`, Q04 `FAIL` |
| `QM5_13058` | AUDCAD/GBPNZD | Q02 `PASS`, Q03 `PASS`, Q04 `FAIL` |
| `QM5_13062` | AUDCAD/EURUSD | Q02 `PASS`, Q03 `PASS`, Q04 `FAIL` |

`AUDCAD/EURUSD` was the formal statistical survivor in the extension scan, but
the scan's own trade check marked it not card-worthy because OOS net Sharpe was
negative and the hedge collapsed between halves; it is nevertheless already
built and past Q02 as `QM5_13062`.

## Existing Forex Sleeve Nearest Certification

`QM5_12778` AUDUSD/EURJPY remains the only FX cointegration sleeve near book
admission in the current DB:

- Q02/Q03/Q04/Q05/Q06/Q07: `PASS`.
- Q08: `FAIL_SOFT` with 195 trades, cost-cushion `PASS`, no
  regime-catastrophe flag.
- Q09_PORTFOLIO: `PASS_PORTFOLIO`, max correlation to book `0.1005`, and
  portfolio Sharpe improved from `2.4320` to `2.4353`.
- `portfolio_candidates` state: `Q12_REVIEW_READY`.

This was already reconciled in
`artifacts/fx_cointegration_qm5_12778_q12_reconciliation_20260708T214849Z.json`;
no portfolio-gate code or live manifest was touched here.

## Guardrails

- No duplicate card was created.
- No duplicate work item was created.
- No manual MT5 backtest was launched.
- No `T_Live`, AutoTrading, deploy manifest, `portfolio_admission`,
  portfolio KPI, or Q08 contribution artifact was touched.
- Existing unrelated dirty worktree files were left untouched.

