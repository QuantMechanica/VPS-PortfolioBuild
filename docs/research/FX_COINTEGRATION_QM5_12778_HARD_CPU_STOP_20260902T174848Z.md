# QM5_12778 FX cointegration hard CPU stop

Recorded: 2026-09-02T17:48:48.490Z (19:48 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `e01791a1af15d11f35659ece8bc6fa124e053a53`

## Outcome

The fixed 66-pair FX cointegration frontier remains fully mechanized, both
preferred anchor baskets remain beyond Q02, and the selected existing forex
continuation already has exactly one priority-bound diagnostic row. A fresh
five-sample CPU window crossed the mission's explicit 97% ceiling, so this wake
stopped without a tester launch, manual claim, duplicate enqueue, priority
rewrite, compile, or backtest.

The concrete fallback remains `QM5_12778`, the structural D1 AUDUSD/EURJPY
cointegration basket. Work item
`24acc5d4-3e34-526e-a7a8-12640a2e759f` was observed pending, unclaimed, attempt
zero, verdict-null, and already priority-bound. The row was left unchanged for
the ordinary paced worker after capacity drains.

## Frontier and anchor check

The controlling study is
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 study tested all
66 unordered relationships. The latest complete reconciliation records 123
approved cointegration/coint identities, 123 matching EA directories, and zero
approved unbuilt identities. Creating another scan-derived card, EA, manifest,
or Q02 row would duplicate governed coverage.

The preferred repair condition remains absent:

| EA | Relationship | Canonical state |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS (`e4890d77`), Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS (`76cb11ee`), Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker.

## Existing forex continuation

`QM5_12778_edgelab-audusd-eurjpy-cointegration` remains an OWNER-approved,
built two-leg market-neutral basket with a checked-in `basket_manifest.json`.
Its sealed mechanics are fixed-beta log spread, a 60-bar closed-D1 z-score,
entry outside 2.0, exit inside 0.5, and broken-package cleanup. The canonical
backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`; the EA uses no ML,
grid, martingale, averaging, or pyramiding.

The exact open diagnostic row was:

| Field | Value |
| --- | --- |
| Work item | `24acc5d4-3e34-526e-a7a8-12640a2e759f` |
| Phase | `Q09_NEWS` diagnostic, non-admission |
| Host | `AUDUSD.DWX`, D1 |
| State | pending, unclaimed, attempt 0, verdict null |
| Priority | true since `2026-09-02T14:31:41Z` |
| Allowed terminals | T1-T5 only |

The MQ5, EX5, basket manifest, and logical RISK_FIXED setfile hashes matched the
prior priority handoff exactly. No package or execution binding changed.

## Binding capacity stop

The fresh five one-second whole-host CPU samples were `90.449%`, `82.553%`,
`84.084%`, `71.631%`, and `71.297%` during the initial preflight, then the
execution-decision window measured `99.865%` average with a `100.000%` maximum.
The latter window binds because both values are at least the 97% hard ceiling.
Physical RAM had recovered to `30.945 GB` free, so CPU alone caused the stop.

The immediately preceding supported `farmctl mt5-slots` census found governed
tester activity on T1, T2, T3, T4, T6, T7, T8, T9, and T10. T5 had a resident
worker but no tester process. `T_Live` and an FTMO terminal were observed only
for exclusion; neither was controlled or modified. No active process,
reservation, or worker was interrupted.

## Safety and continuation

No Strategy Card, EA source/binary, setfile, basket manifest, registry, magic
row, work item, priority mark, terminal, or AutoTrading state changed. No
portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, or live/deploy surface was touched.

On the next paced wake, re-read the exact row and take a fresh CPU/RAM window.
Let the ordinary worker claim the existing row only when both CPU measures are
strictly below 97% and a permitted lane passes its own resource guard. Do not
enqueue, reprioritize, or manually claim a duplicate.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12778_hard_cpu_stop_20260902T174848Z_board_advisor.json`.
