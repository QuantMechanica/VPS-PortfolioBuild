# QM5_20232 FX cointegration Q04 hard CPU stop

Date: 2026-08-30 UTC (`2026-08-30T19:00:59.4638743Z`); 21:00
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `7a5a27b7153292339cf1ac6fd42aecf426fde118`

Status: stopped at the explicit backtest CPU ceiling before acquiring the
factory mutation lock or changing the exact rank-55 Q04 row. No Card, EA,
work-item identity, payload, status, verdict, claim, tester, or terminal was
created or changed.

## Governed frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 study
tested all 66 FX relationships and admitted only two under the published
criterion of positive DEV Sharpe, OOS net Sharpe above 0.8, and at least four
OOS trades:

| EA | Pair | Canonical state |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor is blocked at Q02 by `ONINIT` or `NO_HISTORY`. The committed
66-pair coverage audit has no uncovered relationship, and the immediately
preceding approved-card census has 120 unique cointegration/coint EA IDs with
a matching EA directory for all 120. There is no approved unbuilt FX
cointegration Card, so the Strategy Card extraction and EA-build skill gates
remain closed rather than creating duplicate work or weakening the
reputable-source criterion.

## Exact existing fallback preserved

The dependency-complete fallback remains the structural fixed-beta D1 basket
`QM5_20232_USDCHF_NZDUSD_COINTEGRATION_D1`, trading `USDCHF.DWX` and
`NZDUSD.DWX`. Its sealed package remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, with no adaptive refit, ML, or
banned indicator.

Its exact lineage remains:

| Phase | Work item | State |
|---|---|---|
| Q02 | `ca72ac7d-162c-4c54-b2e4-d7765c15efeb` | done / PASS |
| Q03 | `73d11c4c-0542-4828-9631-1954799a87a5` | done / PASS |
| Q04 | `bfad4436-ae19-4b7d-a7cf-1c02a0324d67` | pending, unclaimed, attempt zero, unprioritized |

The Q04 payload SHA-256 is still
`2180408573c2962324c33aa415469db14c6d55f3a2e8127d934ee1d310e46bba`,
with zero `fx_cointegration_q04_priority_handoff` events. There is exactly one
open matching Q04 row, no active hold, quarantine, or supersession relation,
and no factory mutation lock. Its canonical queue rank was 7,592 of 9,759
eligible pending rows at the read-only observation boundary.

The adverse scan evidence remains sealed: DEV net Sharpe `0.035539`, OOS net
Sharpe `-0.387376`, OOS return `-3.267369%`, 16 OOS state changes, fixed beta
`-0.270458913`, and a `108.268`-D1-bar half-life. This stays a one-shot
pipeline falsification, not permission to refit, add a filter, or rescue a
failed economic gate.

## Binding capacity result

Five fresh one-second whole-host CPU samples were `87.733464%`, `98.053910%`,
`93.360070%`, `95.117691%`, and `76.186396%`. Average CPU was `90.090306%`;
maximum CPU was `98.053910%`. The mission ceiling binds when either measure
reaches 97%, so the maximum required an immediate stop before any lock or
database action.

At the later `19:02:08Z` process snapshot, the factory tester roster had
rotated to T2 and T8, with ten unique terminal workers and no orphaned tester
process. The database read observed five active rows. The serialized basket
lane remained occupied by `QM5_20233` Q03 work item
`f9ccf272-d66e-4a68-b332-76133baab427` on T2; it was not interrupted or
mutated. `T_Live` and the unrelated FTMO terminal were observation-only.

## Non-duplicate delta and safety boundary

This observation is later than the `2026-08-30T18:20:06Z` receipt. The tester
roster rotated from T2/T4/T5/T6/T9/T10 to T2/T8 and the database active-row
count fell from ten to five, but the fresh maximum still crossed the ceiling.
The exact QM5_20232 Q04 row remained byte-identical and unprioritized; no
duplicate work item or pipeline action was created.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading state, or live/deploy
manifest was touched. Existing unrelated shared-worktree changes were
preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/qm5_20232_q04_hard_cpu_stop_20260830T190059Z_board_advisor.json`.

On a later paced wake, take a fresh five-sample CPU window and a second
apply-time window. Only when average and maximum are both strictly below 97%
may the existing exact Q04 row be revalidated and priority-bound in place
under the factory mutation lock. Do not enqueue or dispatch a duplicate, do
not launch a concurrent basket, and retire the sleeve on a terminal Q04
economic failure.
