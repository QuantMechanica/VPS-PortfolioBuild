# QM5_1257 GBPUSD/USDJPY Q02 priority advance

Date: 2026-08-13 (Europe/Berlin)
Branch: `agents/board-advisor`
Outcome: existing exact FX basket row promoted in place; no duplicate enqueue

## Decision

The frozen sign-aware 66-pair scan is fully mechanized: its relationship audit
accounts for all 66 pairs. The two published anchors do not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.
- Neither anchor has an open Q02 `ONINIT` or `NO_HISTORY` blocker.

The mission's existing-card fallback therefore applies. The selected exact
relationship is frozen scan rank 58, `GBPUSD.DWX` / `USDJPY.DWX`, already
implemented as pair slot 8 in approved `QM5_1257_lemishko-fx-cointpair`.
It is the highest-ranked scan relationship that lacked a terminal exact logical
Q02 verdict when the relationship audit was committed.

## Q02 advance

Work item `d4cd660c-c81a-41d3-8a4c-ad21d3319816` was updated in place under the
global Factory mutation lock. A consistent SQLite backup was written before
the transaction. The compare-and-swap required the exact EA, logical symbol,
Q02 phase, pending/unclaimed state, attempt zero, prior payload, and prior
timestamp.

| Field | Before | After |
|---|---:|---:|
| Open exact pending/active rows | 1 | 1 |
| `priority_track` | absent | `true` |
| Canonical pending rank | 100 | 15 |
| Status | pending | pending |
| Attempt count | 0 | 0 |
| Claimed by | null | null |

Audit event `347668` (`priority_track_set`) records that no alpha or pipeline
verdict changed and no duplicate work item was created. The lock released
normally. Backup:
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1257_gbpusd_usdjpy_priority_20260812T225025Z.sqlite`.

The row remains behind fourteen older canonical priority items. No targeted
Factory-ON bypass, timestamp falsification, terminal reservation, dispatch
tick, or manual tester launch was used to jump those rows.

## Structural contract

- Source: Lemishko, Landi, and Caicedo-Llano (2024), *Cointegration-Based
  Strategies in Forex Pairs Trading*, SSRN 4771108.
- Card: G0 `APPROVED`, R1-R4 PASS.
- Logical basket: `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`.
- Host/traded legs: `GBPUSD.DWX` and `USDJPY.DWX`; H1 host with completed D1/H1
  formation history.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Mechanics: deterministic structural cointegration/OLS residual reversion;
  no ML, grid, martingale, averaging down, online beta refit, or rescue filter.

The scan evidence is adverse (DEV net Sharpe -0.104, OOS net Sharpe -0.420,
16 OOS state changes, and an approximately 77-D1-bar half-life). Q02 remains a
one-shot cadence/economics gate; failure retires this binding and does not
authorize parameter rescue.

## Verification

- Strategy Card schema/ML lint: PASS.
- V5 build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260812_224906.json`.
- Symbol scope: `BASKET_OK`, zero violations.
- Basket regressions: 59 passed.
- The build validator rewrote 44 legacy setfile hash headers as a validation
  side effect. Every rewrite was restored to the preflight Git content; no
  setfile or live-labeled artifact remains changed.
- Capacity samples immediately before and after the mutation found zero running
  factory terminals against paced launch maximum one. The unrelated FTMO
  terminal was observed only to exclude it and was not controlled.

Machine-readable evidence:
`artifacts/qm5_1257_gbpusd_usdjpy_q02_priority_20260812T225025Z.json`.

## Safety

No portfolio gate, `portfolio_admission`, portfolio KPI, Q08 contribution,
T_Live manifest, T_Live terminal, AutoTrading state, live setfile, or tester
process was changed.
