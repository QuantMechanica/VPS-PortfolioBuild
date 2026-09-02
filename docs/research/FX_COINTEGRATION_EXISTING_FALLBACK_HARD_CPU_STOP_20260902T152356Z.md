# FX cointegration existing-fallback hard CPU stop

Recorded: 2026-09-02T15:23:56Z (17:23 Europe/Berlin)

Branch: `agents/board-advisor`

Observation base: `52ead9256050ee088c145063f2395c41da6c999f`

## Outcome

The fixed 66-pair frontier still has no reputable unbuilt identity, both preferred anchors remain beyond Q02, and the strongest clean existing FX continuation already has one priority-bound diagnostic row. A fresh CPU window crossed the explicit 97% ceiling, so this wake stopped without an enqueue, priority rewrite, dispatch, compile, or backtest.

The concrete fallback is `QM5_12778`, the structural AUDUSD/EURJPY D1 cointegration basket. Its exact `Q09_NEWS` diagnostic row remains pending once, unclaimed, attempt zero, and priority-bound. Creating or rewriting another row would be duplicate work.

## Frontier and anchor reconciliation

The controlling study is `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 scan tested all 66 unordered FX relationships. The latest complete ownership reconciliation records 123 approved cointegration/coint identities, 123 matching EA directories, and zero approved unbuilt identities.

The mission's preferred Q02 repair condition is absent:

| EA | Relationship | Canonical state |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS (`e4890d77`), Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS (`76cb11ee`), Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. Building another scan-derived card or basket would duplicate governed coverage.

## Existing forex continuation

`QM5_12778_edgelab-audusd-eurjpy-cointegration` remains a built, approved, two-leg market-neutral basket with a checked-in `basket_manifest.json`. Its card cites Ernest P. Chan's cointegration method and the reproducible in-house FX scan. The sealed mechanics remain structural and low frequency: fixed-beta log spread, 60-bar D1 z-score, entry outside 2.0, exit inside 0.5, and package cleanup. There is no ML, grid, martingale, averaging, or pyramiding.

The existing work item is:

| Field | Value |
| --- | --- |
| Work item | `24acc5d4-3e34-526e-a7a8-12640a2e759f` |
| Phase | `Q09_NEWS` diagnostic, non-admission |
| Host | `AUDUSD.DWX`, D1 |
| State | pending, unclaimed, attempt 0, verdict null |
| Priority | already true since `2026-09-02T14:31:41Z` |
| Backtest risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

Other admissible FX Q02 continuations (`QM5_12507`, `QM5_12512`, `QM5_10717`, `QM5_10718`, and `QM5_36006`) were also already priority-bound. No duplicate queue mutation was made.

## Binding CPU stop

The five one-second whole-host CPU samples were `85.843%`, `86.579%`, `99.612%`, `93.754%`, and `85.060%`. Their average was `90.170%` and their maximum was `99.612%`.

The ceiling binds when either measure is at least 97%; the maximum therefore triggered the mission's hard stop. No compile, tester launch, terminal reservation, dispatch tick, queue mutation, or backtest followed.

## Safety and continuation

No Strategy Card, EA source/binary, setfile, basket manifest, registry, magic row, runtime queue row, terminal, or AutoTrading state changed. No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate, T_Live-manifest, or live/deploy surface was touched.

On the next paced wake, re-read the frontier and exact `QM5_12778` row, then take a fresh five-sample CPU window. Continue only if both average and maximum are strictly below 97%. Do not enqueue or reprioritize a duplicate.

Machine-readable companion: `artifacts/fx_cointegration_existing_fallback_hard_cpu_stop_20260902T152356Z_board_advisor.json`.
