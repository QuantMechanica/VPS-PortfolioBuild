# FX Cointegration Frontier / CPU-Ceiling Stop - 2026-07-20

## Mission decision

No duplicate FX cointegration card or work item was created. The strict
66-pair anchors are not blocked at Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`, and
  terminal Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS` and terminal Q04
  `FAIL`.

All 16 approved EdgeLab cards whose filename contains `cointegration` already
have matching EA directories. The 2026-07-09 frontier audit also records the
July 6 extension pairs as built and past Q02. Creating another card from those
results would therefore duplicate existing work.

## Existing FX sleeve frontier

`QM5_12778` AUDUSD/EURJPY remains the nearest market-neutral FX cointegration
sleeve to certification. Its database state is already `Q12_REVIEW_READY`.
Advancing it further would enter manual review / portfolio admission scope,
which this mission explicitly excludes.

## Paced-fleet ceiling

Read-only snapshot of
`D:/QM/strategy_farm/state/farm_state.sqlite` at approximately 2026-07-20
19:58 UTC:

- active: 8
- pending: 3,514
- active terminals: T2, T3, T4, T6, T7, T8, T9, T10
- active phases: Q02 (2), Q03 (2), Q04 (3), Q08 (1)

The fleet is saturated. In accordance with the mission's CPU-ceiling rule, no
manual MT5 run and no additional queue row was launched.

## Guardrails observed

- No `T_Live`, AutoTrading, or deploy-manifest change.
- No portfolio admission, portfolio KPI, or Q08-contribution change.
- No strategy, setfile, registry, or framework change.
- Existing unrelated dirty DEV2 files were left untouched.

