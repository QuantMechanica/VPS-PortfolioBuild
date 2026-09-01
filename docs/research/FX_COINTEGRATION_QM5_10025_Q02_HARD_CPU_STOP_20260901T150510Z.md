# FX basket fleet — QM5_10025 Q02 hard-CPU stop

Date: 2026-09-01 UTC (`2026-09-01T15:05:10Z`); 17:05
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `fbaa6c3a503630c45dfc09f1238e36194f54187f`

Status: the frozen FX cointegration frontier still has no unbuilt identity,
the two requested anchors remain past Q02, and the selected existing
market-neutral FX sleeve remains queued exactly once. The initial capacity
precheck cleared, but the final admission window breached both axes of the
explicit 97 percent CPU ceiling after seven optimization cells ramped up. This
wake therefore stopped before any Card, build, queue, claim, dispatch, tester,
or pipeline-verdict mutation.

## Frontier and anchor decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its sign-aware v3 scan
covers all 66 relationships. The latest complete durable census records 123
approved cointegration/coint identities, 123 matching EA directories, and
zero approved unbuilt identities. Creating another scan-derived Card, EA,
basket manifest, registry allocation, or Q02 row would duplicate governed
coverage or relax the published source criterion.

The preferred anchors have no current Q02 setup repair:

| EA | Relationship | Canonical state |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has an open Q02 `ONINIT` or `NO_HISTORY` blocker. The Strategy
Card extraction and EA-build preflights consequently stayed closed.

## Existing-card fallback remains ready exactly once

The non-duplicate fallback remains `QM5_10025_rw-fx-broad-pairs`, an approved,
built H4 market-neutral FX sleeve. At each monthly formation event, a real FX
host selects one partner from seven registered majors, freezes the OLS hedge
ratio for the month, and trades one beta-weighted two-leg package. The sleeve
is structural: it has no machine learning, banned indicator, grid, martingale,
or adaptive intramonth refit.

Its exact USDJPY-host Q02 row remains unchanged:

| Field | Value |
| --- | --- |
| Work item | `050dd2ea-e9d0-475f-b5ad-40c2206867ff` |
| Host / timeframe | `USDJPY.DWX` / H4 |
| State | pending, unclaimed, attempt 0, no verdict |
| Open exact rows | 1 |
| `priority_track` | `true` |
| Priority reason | `board_advisor_fx_existing_market_neutral_q02_after_exhausted_66_pair_frontier` |
| Payload SHA-256 | `bca99985bb4989d96c0537c81640333870793f2958843797d5357fb6c319a2f8` |

The sealed MQ5, EX5, basket manifest, and USDJPY backtest setfile remain
hash-stable. The setfile is still `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. SQLite `PRAGMA quick_check` returned `ok`. No duplicate
enqueue or repeated priority mutation was attempted.

## Binding CPU transition

The first five-sample window at `15:01:00Z` was `52.939413%`, `51.386436%`,
`55.108014%`, `56.566415%`, and `56.064795%`: average `54.413015%`, maximum
`56.566415%`. Both axes initially cleared the 97 percent ceiling.

By the final admission window at `15:05:10Z`, seven `OPT_CENSUS` rows had
ramped alongside one Q03 and one Q10_NEWS row. The five CPU samples were
`100.000000%`, `99.522085%`, `99.512112%`, `99.902494%`, and `99.708177%`:
average `99.728974%`, maximum `100.000000%`. Both axes breached the explicit
ceiling, so the mission's mandatory hard stop binds.

The serialized basket lane independently remains occupied by T8 running
`QM5_20206_XAU_XAG_MOMIVOL_D1`, Q03 work item
`c8edc2dc-43f4-4896-a5b0-9047815b0564`. The claim is healthy rather than
stale: run 1 has a report, run 2 is active at 47 percent, the terminal and
tester are responsive, and over five seconds they accumulated `0.859375` and
`4.546875` CPU seconds respectively. Forcing QM5_10025 onto another terminal
would violate the fleet-wide serialized multisymbol admission contract even
without the CPU breach.

## Non-duplicate delta and continuation

This is materially newer than the `2026-09-01T09:47:36Z` receipt. The T8
predecessor advanced into a healthy second run and reached 47 percent; the
farm concurrently expanded to seven active optimization cells; and the final
CPU window now binds on both average and maximum. The target Q02 row and all
bound strategy artifacts remain unchanged, so no duplicate queue or strategy
mutation was created.

On a later paced wake, take a new five-sample CPU window. Only when both
average and maximum are strictly below 97 percent, and no multisymbol item is
active, may a resident worker claim the unique QM5_10025 Q02 row. Do not
enqueue a second row or manually launch a basket tester.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, Q08 state, T_Live manifest or terminal, AutoTrading
state, live setfile, or deploy manifest was touched. Unrelated pre-existing
staged, unstaged, and untracked worktree changes were preserved and excluded
from this receipt.

Machine-readable evidence is
`artifacts/fx_cointegration_qm5_10025_q02_hard_cpu_stop_20260901T150510Z_board_advisor.json`.
