# QM5_12778 FX cointegration CPU-ceiling stop

Recorded: 2026-09-02T18:46:00.5909825Z (20:46 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `c46a66f830b55b6e149c7f17473033ec29b1164b`

## Outcome

The frozen 66-pair FX cointegration frontier remains fully mechanized, both
preferred anchors remain beyond Q02, and the selected existing forex
continuation still has one unique priority-bound diagnostic row. All five
fresh CPU samples reached 100%, above the explicit 97% ceiling, so this wake
stopped without a card, build, queue mutation, claim, dispatch, compile, or
backtest.

The non-duplicate continuation remains `QM5_12778`, the structural D1
AUDUSD/EURJPY cointegration basket. Work item
`24acc5d4-3e34-526e-a7a8-12640a2e759f` was freshly observed pending,
unclaimed, attempt zero, verdict-null, and priority-bound. It was left for the
ordinary paced worker after capacity drains.

## Frontier and preferred anchors

The controlling research is
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, which tested all 66
unordered FX relationships. The latest ownership guard records 123 approved
cointegration/coint identities, 123 matching EA directories, and zero approved
unbuilt identities. Another scan-derived card, EA, basket manifest, or Q02 row
would duplicate governed coverage.

Fresh canonical `farmctl work-items` reads confirm that the historical setup
failures on the preferred anchors are not current blockers:

| EA | Relationship | Current terminal path |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS (`e4890d77`), Q04 PASS, then Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS (`76cb11ee`), then Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` repair to perform.

## Existing forex continuation

`QM5_12778_edgelab-audusd-eurjpy-cointegration` remains an approved, built
two-leg market-neutral basket with a checked-in `basket_manifest.json`. Its
sealed mechanics are fixed-beta log spread, 60-bar closed-D1 z-score, entry
outside 2.0, exit inside 0.5, and broken-package cleanup. The logical backtest
setfile still seals `RISK_FIXED=1000` and `RISK_PERCENT=0`; the strategy uses
no ML, banned indicators, grid, martingale, averaging, or pyramiding.

The exact continuation row was:

| Field | Value |
| --- | --- |
| Work item | `24acc5d4-3e34-526e-a7a8-12640a2e759f` |
| Phase | `Q09_NEWS`, diagnostic and non-admission |
| Host | `AUDUSD.DWX`, D1 |
| State | pending, unclaimed, attempt 0, verdict null |
| Priority | `true` since `2026-09-02T14:31:41Z` |
| Fixed-risk contract | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

The payload hash remained
`4b480ef617bc8245b12712f7a933ab24c3524f25852efb7976a1bbbeabe30d04`.
The source, EX5, manifest, and logical-set hashes also match the prior handoff;
no package rewrite was needed.

## Binding capacity stop

The five one-second whole-host CPU samples were `100.000%`, `100.000%`,
`100.000%`, `100.000%`, and `100.000%`. Average and maximum were both
`100.000%`, so the 97% hard ceiling bound. Free physical RAM was 18.668 GB of
63.120 GB; CPU alone was sufficient to stop this wake.

No process, reservation, worker, terminal, or AutoTrading state was changed.
No attempt was made to bypass the paced worker's resource admission.

## Safety and continuation

No Strategy Card, EA source/binary, setfile, basket manifest, registry, magic
row, runtime work item, priority mark, terminal, or AutoTrading state changed.
No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, or live/deploy surface was touched. Pre-existing shared-tree
changes were left unstaged and uncommitted by this wake.

After CPU average and maximum are both strictly below 97%, re-read the exact
Q09_NEWS row and let the ordinary paced worker claim it if still pending. Do
not enqueue, reprioritize, manually claim, or dispatch a duplicate.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12778_cpu_ceiling_stop_20260902T184600Z_board_advisor.json`.
