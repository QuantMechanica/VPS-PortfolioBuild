# QM5_13119 framework repair and Q02 requeue

Recorded 2026-07-11 on `agents/board-advisor`.

## Outcome

QM5_13119 USDJPY/EURAUD is clean-built again and has a distinct repaired-binary
Q02 work item: `77ec9572-e064-44bd-a756-51647aa383b9`. It is pending while
`FACTORY_OFF.flag` remains present; it was not dispatched.

The prior real-tick Q02 work item
`f8767f2f-4bcb-4b32-b857-cf9063b1c935` remains in the farm as `done/PASS` for
audit, but is classified `PASS_SUPERSEDED` for promotion because its binary
predated this framework repair. That run completed once with 136 trades, PF
1.06, net +954.43, and 2.91% maximum drawdown, with no ONINIT or log-bomb
failure. Its canonical summary is
`D:/QM/reports/work_items/f8767f2f-4bcb-4b32-b857-cf9063b1c935/QM5_13119/20260711_043425/summary.json`.

## Why this existing sleeve was advanced

The two original scan anchors are not stuck at Q02: QM5_12532 and QM5_12533
both have logical-basket Q02 PASS evidence. The sign-aware scan extension has
seven strict rows, and all seven already have builds: QM5_12978, QM5_12533,
QM5_12532, QM5_13003, QM5_13106, QM5_13117, and QM5_13119. Creating another
"next-best" card would therefore duplicate or weaken the approved scan. The
mission's fallback—advance an existing forex card—applies.

The selection remains grounded in Ernest P. Chan's published cointegration
method and the reproducible 66-pair research under
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

## Repair

Mechanical review `f78a8047-8437-4964-a9ba-7d170bfe9596` found that the
USDJPY logical host bypassed the mandatory V5 trade-manager entry path. The
repair now:

- treats only USDJPY.DWX as the logical host;
- opens USDJPY through reachable `QM_TM_OpenPosition`;
- retains `QM_BasketOpenPosition` for the EURAUD companion;
- normalizes both legs to one `RISK_FIXED=1000` package split in
  `1:abs(beta)` weight, then restores the prior global risk context; and
- declares and warms EURUSD.DWX after the tester requested it for USD
  account-P/L conversion, alongside the existing AUDUSD.DWX risk-conversion
  dependency. Neither conversion symbol is traded.

No beta, z-score window, threshold, direction, filter, or exit rule changed.
No ML, banned indicator, grid, martingale, or adaptive refit was introduced.

## Verification

- Strict clean-worktree compile: PASS, 0 errors, 0 warnings;
  `D:/QM/reports/compile/20260711_050605/summary.csv`.
- Scoped build check: PASS, 0 failures, 0 warnings;
  `D:/QM/reports/framework/21/build_check_20260711_050630.json`.
- Basket regression tests: 17 passed.
- Symbol scope: `BASKET_OK`, 0 violations.
- SPEC validation: PASS.
- EX5 SHA-256:
  `a3988df814790762be229b84e3483ae460128f6e6a056a673a74edd544834a5e`.
- Setfile contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; build hash
  `f081167251a3130fe084abde2191f61cd658e378033f19b61c9d6fa1f8f1941d`.

The farm database passed `PRAGMA integrity_check`. Its online pre-rework backup
is
`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13119_build_rework_20260711T051004Z.sqlite`.
At handoff there were no T1-T5 terminal or tester processes. No T_Live,
AutoTrading, live manifest, portfolio gate, portfolio-admission, KPI, or Q08
contribution file was touched.

Machine-readable evidence:
`artifacts/qm5_13119_framework_repair_q02_requeue_20260711.json`.
