# QM5_20232 FX cointegration Q04 apply-time CPU stop

Date: 2026-08-30 UTC (`2026-08-30T18:20:06.4130098Z`); 20:20
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `d137148a78d634d17110854456aa8c91d71c2c06`

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
66-pair coverage audit has no uncovered relationship, while the current
approved-card census has 120 unique cointegration/coint EA IDs and a matching
EA directory for all 120. There is no approved unbuilt FX cointegration Card,
so creating another Card, EA, or Q02 row would be duplicate work or would
weaken the reputable-source criterion.

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

After the stop, the Q04 payload SHA-256 was still
`2180408573c2962324c33aa415469db14c6d55f3a2e8127d934ee1d310e46bba`
and the row still had zero `fx_cointegration_q04_priority_handoff` events.
The factory mutation lock was absent. The adverse scan evidence remains sealed
and this is still a one-shot pipeline falsification, not permission to refit
or rescue the mechanics.

## Binding apply-time capacity result

An initial five-sample window at `18:15:35Z` was clear: average CPU was
`89.523192%` and maximum CPU was `92.188309%`. The mandatory apply-time window
then measured `99.415876%`, `100.000000%`, `100.000000%`, `100.000000%`, and
`98.735677%`. Average CPU was `99.630311%` and maximum CPU was `100.000000%`.
Both exceeded the explicit 97% ceiling.

The guarded command exited before its Python mutation path ran, so it did not
acquire the global lock, open a write transaction, create a row journal,
update the payload, insert an event, or dispatch a worker. This later
apply-time spike is new evidence relative to the preceding `17:02:20Z` stop;
it is not a duplicate queue action.

At the observation boundary the farm had ten active database rows. The single
active serialized basket remained `QM5_20233` Q03 work item
`f9ccf272-d66e-4a68-b332-76133baab427` on T2. A preceding path-anchored scan
observed factory terminals on T2, T4, T5, T6, T9, and T10. That basket and all
terminals were left untouched. `T_Live` and the unrelated FTMO terminal were
observed only to exclude them.

## Safety and continuation

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading state, or live/deploy
manifest was touched. Existing unrelated shared-worktree changes were
preserved.

Machine-readable evidence is in
`artifacts/qm5_20232_q04_hard_cpu_stop_20260830T182006Z_board_advisor.json`.

On a later paced wake, take both a fresh preflight CPU window and a fresh
apply-time window. Only if average and maximum are strictly below 97% may the
existing exact Q04 row be revalidated and priority-bound in place under the
factory mutation lock. Do not enqueue or dispatch a duplicate, do not launch
a concurrent basket, and retire the sleeve on a terminal Q04 economic
failure.
