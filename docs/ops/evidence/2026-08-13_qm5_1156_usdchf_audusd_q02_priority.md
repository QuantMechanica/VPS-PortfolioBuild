# QM5_1156 USDCHF/AUDUSD Q02 priority advance

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: existing exact FX basket row promoted in place; no duplicate enqueue

## Decision

The frozen sign-aware 66-pair scan is fully mechanized: the deterministic
relationship audit accounts for all 66 pairs. The two published anchors do
not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.
- Neither anchor has an open Q02 `ONINIT` or `NO_HISTORY` blocker.

The mission's existing-card fallback therefore applies. The selected exact
relationship is frozen scan rank 65, `USDCHF.DWX` / `AUDUSD.DWX`, already
implemented as pair slot 12 in approved
`QM5_1156_caldeira-cointegration-pairs-fx`. It was the remaining lower-ranked
scan identity without a terminal exact logical Q02 verdict after rank 58 was
already promoted in commit `2de3ed729`.

## Q02 advance

Work item `415cd6d3-560c-46d8-a9f9-ee4a5b399100` was updated in place under
the global Factory mutation lock. A consistent SQLite backup was written and
passed `PRAGMA quick_check` before the transaction. The compare-and-swap
required the exact EA, logical symbol, Q02 phase, pending/unclaimed state,
attempt zero, prior payload hash, and prior timestamp.

| Field | Before | After |
|---|---:|---:|
| Open exact pending/active rows | 1 | 1 |
| `priority_track` | absent | `true` |
| Canonical pending rank | 101 | 5 |
| Status | pending | pending |
| Attempt count | 0 | 0 |
| Claimed by | null | null |

Audit event `347670` (`priority_track_set`) records that no alpha or pipeline
verdict changed and no duplicate work item was created. The lock released
normally. Backup:
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1156_usdchf_audusd_priority_20260812T234941Z.sqlite`.

The row remains behind four older canonical priority items. No targeted
Factory-ON bypass, timestamp falsification, terminal reservation, dispatch
tick, or manual tester launch was used to jump those rows.

## Structural contract

- Source: Caldeira and Moura (2013), *Selection of a Portfolio of Pairs Based
  on Cointegration: A Statistical Arbitrage Strategy*, SSRN 2196391 and its
  peer-reviewed journal publication.
- Card: G0 `APPROVED`; R1-R4 PASS.
- Logical basket: `QM5_1156_USDCHF_AUDUSD_COINTEGRATION_M30`.
- Host/traded legs: `USDCHF.DWX` and `AUDUSD.DWX`; M30 host execution with
  completed-D1 formation and signal history.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Mechanics: deterministic rolling OLS residual reversion, fixed z-score and
  stationarity gates, divergence/time exits, and package integrity; no ML,
  grid, martingale, averaging down, PnL-adaptive parameters, or rescue filter.

The frozen scan evidence is adverse (DEV net Sharpe `-0.21`, OOS net Sharpe
`-0.66`, OOS return `-5.70%`, and 16 OOS state changes). Q02 remains a
one-shot cadence/economics gate; failure retires this binding and does not
authorize parameter rescue.

## Verification

- Strategy Card schema/ML lint: PASS for the canonical and EA-local approved
  copies.
- Build guardrails: PASS across 23 files with zero findings.
- Symbol scope: `BASKET_OK`, zero violations.
- Basket work-item regressions: 15 passed.
- Existing strict Q01 build evidence remains bound to MQ5 SHA-256
  `c717d4aeb91994c8f59c89938e133defd7757b97fe196d4de0927121cb96d509`
  and EX5 SHA-256
  `b49906e0d11679c2c3522b1d95c7759d5fb59dda5c36bb77e27a71e1a2b2d2f6`.
- Capacity samples immediately before and after the mutation found zero
  running factory terminals against paced launch maximum one. The unrelated
  FTMO terminal was observed only to exclude it and was not controlled.

Machine-readable evidence:
`artifacts/qm5_1156_usdchf_audusd_q02_priority_20260812T234941Z.json`.

## Safety

No portfolio gate, `portfolio_admission`, portfolio KPI, Q08 contribution,
T_Live manifest, T_Live terminal, AutoTrading state, live setfile, or tester
process was changed.
