# QM5_12778 FX cointegration RAM-guard stop

Recorded: 2026-09-02T16:34:30Z (18:34 Europe/Berlin)

Branch: `agents/board-advisor`

Observation base: `aacd0232cdb563ccd1aefc3964ccb5a97f073c6c`

## Outcome

The fixed 66-pair FX frontier remains fully mechanized, both preferred anchor
baskets remain beyond Q02, and the selected existing AUDUSD/EURJPY continuation
already has exactly one priority-bound diagnostic row. CPU was below the
mission's 97% ceiling, but the allowed T1-T5 lane was blocked by its governed
RAM claim guard. No tester, duplicate enqueue, priority rewrite, or manual claim
was forced.

The concrete fallback remains `QM5_12778`, a structural, low-frequency D1
AUDUSD/EURJPY cointegration basket. Its work item
`24acc5d4-3e34-526e-a7a8-12640a2e759f` was observed pending, unclaimed, attempt
zero, and priority-bound. Leaving that exact row in place is the only
non-duplicate continuation while capacity drains.

## Frontier and preferred-anchor check

The controlling study is
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 study tested all
66 unordered FX relationships. The latest complete ownership reconciliation
records 123 approved cointegration/coint identities, 123 matching EA
directories, and zero approved unbuilt identities. A new scan-derived card or
basket would duplicate governed coverage.

The preferred Q02-repair condition remains absent:

| EA | Relationship | Canonical state |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS (`e4890d77`), Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS (`76cb11ee`), Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker.

## Existing forex continuation

`QM5_12778_edgelab-audusd-eurjpy-cointegration` remains an approved, built,
two-leg market-neutral basket with a checked-in `basket_manifest.json`. The
sealed mechanics are fixed-beta log spread, 60-bar closed-D1 z-score, entry
outside 2.0, exit inside 0.5, and atomic package cleanup. It uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and no ML, grid, martingale, averaging, or
pyramiding.

The existing row is:

| Field | Value |
| --- | --- |
| Work item | `24acc5d4-3e34-526e-a7a8-12640a2e759f` |
| Phase | `Q09_NEWS` diagnostic, non-admission |
| Host | `AUDUSD.DWX`, D1 |
| State | pending, unclaimed, attempt 0, verdict null |
| Priority | true since `2026-09-02T14:31:41Z` |
| Allowed terminals | T1-T5 only |

The MQ5, EX5, basket manifest, and logical RISK_FIXED setfile hashes were
unchanged from the priority handoff. No card or package rewrite was needed.

## Binding resource guard

The initial five CPU samples were `70.023%`, `69.426%`, `50.138%`, `66.214%`,
and `50.893%` (average `61.339%`, maximum `70.023%`). A drain recheck sampled
`62.914%`, `55.043%`, `73.356%`, `61.431%`, and `52.188%` (average `60.986%`,
maximum `73.356%`). Both windows were below the 97% CPU ceiling.

At the recheck only `1.367 GB` of physical RAM was available. In the permitted
lane, T2 and T5 were occupied; T1, T3, and T4 were idle but their worker logs
showed active RAM hysteresis at restart thresholds of 12 GB, 20 GB, and 20 GB,
respectively. Bypassing those guards would violate paced-fleet admission and
risk destabilizing the six already-running factory tests.

## Safety and continuation

No Strategy Card, EA source/binary, setfile, basket manifest, registry, magic
row, runtime queue row, terminal, or AutoTrading state changed. No
portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, or live/deploy surface was touched.

On the next paced wake, re-read the exact row and take a fresh CPU/RAM window.
Let the ordinary worker claim it only after one permitted lane satisfies its
configured RAM hysteresis and both CPU measures remain strictly below 97%.
Do not enqueue, reprioritize, or manually claim a duplicate.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12778_ram_ceiling_stop_20260902T163430Z_board_advisor.json`.
