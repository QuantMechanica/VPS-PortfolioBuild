# FX basket fleet — QM5_10025 Q02 hard-CPU stop

Date: 2026-09-01 UTC (`2026-09-01T16:18:26.4206396Z`); 18:18
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `991ac586df202e86dfde5ad692cb3146198dd2f4`

Status: the frozen FX cointegration frontier still has no unbuilt identity,
both requested anchors remain past Q02, and the one selected existing FX
basket remains queued exactly once. A healthy predecessor advanced materially,
but the final five-sample CPU window breached the explicit 97 percent maximum
ceiling. This wake stopped before any Card, EA, queue, claim, dispatch, tester,
or pipeline-verdict mutation.

## Frontier and anchor decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 scan
tested all 66 FX relationships and admitted only the two positive DEV/OOS
survivors. The durable sign-aware coverage census records 123 approved
cointegration/coint identities, 123 matching EA directories, and zero approved
unbuilt identities. Creating another scan-derived Card, EA, basket manifest,
registry allocation, or Q02 row would duplicate governed coverage or weaken
the published source criterion.

The preferred anchors do not have the Q02 infrastructure blocker named by the
mission:

| EA | Relationship | Canonical state |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The Strategy
Card extraction and EA-build gates therefore remained closed.

## Existing-card fallback remains ready exactly once

The non-duplicate fallback remains `QM5_10025_rw-fx-broad-pairs`, an approved,
built H4 market-neutral FX sleeve. At each monthly formation event, a real FX
host selects one partner from seven registered majors, freezes the OLS hedge
ratio for the month, and trades one beta-weighted two-leg package. It is
structural and contains no machine learning, banned indicator, grid,
martingale, or adaptive intramonth refit.

Its selected USDJPY-host Q02 row is unchanged:

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
hash-stable. The setfile still binds `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. SQLite `PRAGMA quick_check` returned `ok`. No duplicate
enqueue or repeated priority mutation was attempted.

## Serialized predecessor advanced, then capacity bound

The only active multisymbol lane remains T8 work item
`c8edc2dc-43f4-4896-a5b0-9047815b0564`, `QM5_20206_XAU_XAG_MOMIVOL_D1`
Q03. Its second run advanced from 47 percent in the preceding receipt to 79
percent at `2026-09-01T16:16:07.6531607Z`. The terminal and metatester were
responsive and accumulated 1.36 and 4.95 CPU seconds, respectively, over a
fresh five-second interval. The run is healthy, not stale, so taking another
multisymbol item would violate serialized admission.

The canonical active-row count also advanced from nine to eight: seven
`OPT_CENSUS` rows and this one Q03 row remain, while the preceding Q10_NEWS row
is no longer active.

The final five one-second whole-host CPU samples were `97.463740%`,
`96.526395%`, `93.561816%`, `87.331407%`, and `89.464785%`. Average CPU was
`92.869629%`, but maximum CPU was `97.463740%`. The mission ceiling binds when
either measure reaches 97 percent, so the maximum axis mandates an immediate
stop.

## Non-duplicate delta and continuation

This receipt is materially newer than the `2026-09-01T15:05:10Z` stop: the
healthy serialized predecessor progressed from 47 to 79 percent, the active
Q10_NEWS row cleared, and the CPU condition changed from both axes breaching to
only the maximum axis breaching. The target Q02 row and all bound artifacts
remain unchanged, so this wake created no duplicate strategy or queue work.

On a later paced wake, first require the current multisymbol item to reach a
canonical terminal state. Then take a fresh five-sample CPU window. Only when
both average and maximum are strictly below 97 percent may a resident worker
claim the unique QM5_10025 Q02 row. Do not enqueue a second row or manually
launch a basket tester.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, Q08 state, T_Live manifest or terminal, AutoTrading state,
live setfile, or deploy manifest was touched. Unrelated pre-existing staged,
unstaged, and untracked worktree changes were preserved and excluded from this
receipt.

Machine-readable evidence is
`artifacts/fx_cointegration_qm5_10025_q02_hard_cpu_stop_20260901T161826Z_board_advisor.json`.
