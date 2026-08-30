# QM5_20232 FX cointegration Q04 hard CPU stop

Date: 2026-08-30 UTC (`2026-08-30T17:02:20.8619868Z`); 19:02
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `87d83ca4ad7b41d4c2f1ba2840ee5f88c611eb8c`

Status: stopped at the explicit backtest CPU ceiling before acquiring the
factory mutation lock or changing the exact rank-55 Q04 row. No Card, EA,
queue row, payload, status, verdict, claim, tester, or terminal was created or
changed.

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
66-pair coverage audit has no uncovered relationship. A fresh approved-card
census found 120 unique cointegration/coint EA IDs and a matching EA directory
for all 120; there is no approved unbuilt FX cointegration Card. The Strategy
Card extraction and EA build gates therefore remained closed rather than
creating a duplicate or weakening the source criterion.

## Exact existing fallback revalidated

The dependency-complete fallback remains the structural fixed-beta D1 basket
`QM5_20232_USDCHF_NZDUSD_COINTEGRATION_D1`. It trades `USDCHF.DWX` and
`NZDUSD.DWX`, with no conversion-only symbol. Card schema/ML lint returned
`ok`; the two active magic rows match the traded legs. The sealed logical
setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

Its exact lineage is unchanged:

| Phase | Work item | State |
|---|---|---|
| Q02 | `ca72ac7d-162c-4c54-b2e4-d7765c15efeb` | done / PASS |
| Q03 | `73d11c4c-0542-4828-9631-1954799a87a5` | done / PASS |
| Q04 | `bfad4436-ae19-4b7d-a7cf-1c02a0324d67` | pending, unclaimed, attempt zero, unprioritized |

The Q04 row still has payload SHA-256
`2180408573c2962324c33aa415469db14c6d55f3a2e8127d934ee1d310e46bba`.
There is exactly one open matching Q04 row and no prior FX priority-handoff
event for it.

The adverse scan evidence stays sealed: DEV net Sharpe `0.035539`, OOS net
Sharpe `-0.387376`, OOS return `-3.267369%`, 16 OOS state changes, fixed beta
`-0.270458913`, and a `108.268`-D1-bar half-life. This remains a one-shot
falsification; a terminal Q04 failure retires the sleeve and does not authorize
a refit, filter, or rescue.

| Binding | SHA-256 |
|---|---|
| Approved Card | `8f95bd82d91957b794949298ebbc4d65f06bf91a71f6e7ebe38331dd7e405001` |
| MQ5 | `c262de17327305ff33f01bab3ff41a09c1d1bd1ca2d0ef9cd3c7200b95d14be0` |
| EX5 | `1d9378dfc38df19e2f51f6e623c5a3fb3c8511f2b72acc8fd37b8f84a8c9bdbc` |
| Basket manifest | `728679e87475089e5ead200bd2d63fbf462fd3780af753911619f5e4593c0fe0` |
| Logical backtest setfile | `5e08262b87977127392e2e0f322233cb0c6de4c343555cc9823d43dd47fd4d46` |

## Binding capacity result

Five fresh one-second whole-host CPU samples were `97.949663%`, `92.500647%`,
`83.594877%`, `81.169220%`, and `71.398029%`. Average CPU was `85.322487%`;
maximum CPU was `97.949663%`. The mission ceiling binds when either measure
reaches 97%, so the maximum required an immediate stop before any lock or
database action.

At the read-only observation boundary the farm had six active database rows.
The serialized basket lane remained occupied by `QM5_20233` Q03 work item
`f9ccf272-d66e-4a68-b332-76133baab427` on T2. The path-anchored terminal scan
observed factory testers on T1, T2, T4, T5, T9, and T10 with no duplicate
terminal worker. That active basket was not interrupted, and QM5_20232 was not
dispatched.

## Non-duplicate delta and safety boundary

This is a later capacity and factory-state observation than the preceding
`2026-08-30T15:55:16Z` receipt: the branch and tester roster advanced, while
the exact QM5_20232 Q04 row remained byte-identical and unprioritized. The
fresh `97.949663%` maximum independently kept the ceiling binding. No duplicate
work item or pipeline action was created.

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading, and every live/deploy
manifest were untouched. Existing unrelated shared-worktree changes were
preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/qm5_20232_q04_hard_cpu_stop_20260830T170220Z_board_advisor.json`.

On a later paced wake, take a fresh five-sample CPU window. Only when average
and maximum are both strictly below 97% may the existing exact Q04 row be
revalidated and priority-bound in place under the factory mutation lock. Do
not enqueue or dispatch a duplicate.
