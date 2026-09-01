# FX basket fleet — QM5_10025 Q02 hard-CPU stop

Date: 2026-09-01 UTC (`2026-09-01T09:47:36Z`); 11:47
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `60317632bac6fe511fea89abe5b21c10e151ade9`

Status: the frozen FX cointegration frontier still has no unbuilt identity,
the requested anchors remain past Q02, and the selected existing structural
FX basket remains queued exactly once. A fresh whole-host CPU window breached
the explicit 97 percent ceiling, so this wake stopped before any build record,
queue mutation, claim, dispatch, tester, or pipeline-verdict action.

## Frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its sign-aware v3 scan
covers all 66 relationships. The latest complete durable census records 123
approved cointegration/coint identities, 123 matching EA directories, and
zero approved unbuilt identities. Creating another scan-derived Card, EA,
manifest, registry allocation, or Q02 row would therefore duplicate governed
coverage or relax the published source criterion.

The preferred anchors have no current Q02 setup repair:

| EA | Relationship | Canonical state |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS; Q04 FAIL |

The Strategy Card extraction and EA-build gates consequently stayed closed.

## Existing-card fallback

The non-duplicate fallback remains `QM5_10025_rw-fx-broad-pairs`, an approved,
built H4 market-neutral FX sleeve. At each monthly formation event, a real FX
host selects one partner from seven registered majors, freezes the OLS hedge
ratio for the month, and trades one beta-weighted two-leg package. The sleeve
is structural: it has no machine learning, banned indicator, grid, martingale,
or adaptive intramonth refit.

Its exact USDJPY-host Q02 row remains ready and unchanged:

| Field | Value |
| --- | --- |
| Work item | `050dd2ea-e9d0-475f-b5ad-40c2206867ff` |
| Host / timeframe | `USDJPY.DWX` / H4 |
| State | pending, unclaimed, attempt 0, no verdict |
| Open exact rows | 1 |
| `priority_track` | `true` |
| Priority reason | `board_advisor_fx_existing_market_neutral_q02_after_exhausted_66_pair_frontier` |
| Payload SHA-256 | `bca99985bb4989d96c0537c81640333870793f2958843797d5357fb6c319a2f8` |

The current artifact hashes still match the prior sealed handoff:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `fd0a18d8710dc8bd0d089ab34b9c881de65e971f0916ba540b34c53b2aa120ff` |
| EX5 | `9bf2691d4af0a57d553711c37ffceadb513b303e710a25f455c8f2e211eecfcc` |
| Basket manifest | `98237a88f0634810f187a63c6d4585950aac4d5b8f21c157d23f88533691daa0` |
| USDJPY backtest setfile | `2d8a1ba1871c229d00b49458dcbd6dbd152d24c170d76404bace39cdea3be53c` |

The setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. SQLite `PRAGMA quick_check` returned `ok`.

## Binding capacity result

Five fresh one-second whole-host CPU samples were `99.903797%`, `99.708957%`,
`91.810115%`, `89.860876%`, and `92.113485%`. Average CPU was `94.679446%`
and maximum CPU was `99.903797%`. The maximum exceeds the explicit 97 percent
ceiling, so the mission's mandatory stop binds even though the average is
below the ceiling.

The serialized multisymbol lane was also occupied by T8 running
`QM5_20206_XAU_XAG_MOMIVOL_D1`, Q03 work item
`c8edc2dc-43f4-4896-a5b0-9047815b0564`. The path-bound T8 terminal was
attributed to that exact active row, with no orphan or duplicate worker in the
supported slot census. No terminal, reservation, worker, or process was
controlled.

## Non-duplicate delta and continuation

This is materially newer than the `2026-09-01T07:22:01Z` receipt. The CPU
window moved from `71.716863%` average / `86.147881%` maximum to
`94.679446%` / `99.903797%`, and the serialized T8 lane advanced from
`QM5_20233` to `QM5_20206`. The target Q02 row and all bound artifacts remain
unchanged, so no duplicate enqueue or repeated priority mutation was made.

On a later paced wake, take a new five-sample CPU window. Only when both the
average and maximum are strictly below 97 percent, and no multisymbol item is
active, may a resident worker claim the existing QM5_10025 row. Do not
enqueue a second row or manually launch a basket tester.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, Q08 state, T_Live manifest or terminal, AutoTrading
state, live setfile, or deploy manifest was touched. Unrelated pre-existing
staged, unstaged, and untracked worktree changes were preserved and excluded
from this receipt.

Machine-readable evidence is
`artifacts/fx_cointegration_qm5_10025_q02_hard_cpu_stop_20260901T094736Z_board_advisor.json`.
