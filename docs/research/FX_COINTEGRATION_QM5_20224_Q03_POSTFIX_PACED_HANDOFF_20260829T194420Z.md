# QM5_20224 FX cointegration Q03 post-fix paced handoff

Date: 2026-08-29 UTC (`2026-08-29T19:44:20Z`); 21:44 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `b5e5e4076a0aac2e2280d9c86b04f8b28774843d`

Status: the existing EURUSD/EURJPY basket is the first pending FX pair in the
serialized multisymbol order, and the retry-session liveness repair is resident
in every worker currently able to claim it. The row remains correctly paced
behind seven legitimate Q04 baskets. A contemporaneous five-sample CPU window
hit the explicit ceiling, so this mission turn stopped without dispatch. No
duplicate Card, EA, work item, queue mutation, manual dispatch, tester,
terminal, or portfolio object was created.

## Outcome

The frozen 66-pair source frontier has no unbuilt governed relationship left.
The mission fallback therefore remains scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`.

The exact Q03 work item `3c74eb04-7e19-4aa0-8dcf-3f004faaa946` is pending,
unclaimed, at attempt zero, and unverdict. It retains
`priority_track=true` with reason `board_advisor_fx_fallback_rank46_q03` and
payload SHA-256
`b9e8294d644b5d450601ea7eb7456e83165716f52e6b4a5cabf4e8f95eb484b4`.
Exactly one open row exists for this EA, logical symbol, and phase. Q04 work
item `a525cd8f-4c29-4752-b1af-3c43288f259e` was not promoted ahead of Q03.

This handoff closes the remaining activation uncertainty after the false-reap
repair. Commit `611fbac6c904bd9d800a72f42eb1e3b0be802b4b` teaches Q02/Q03 liveness to
honor a newer UUID-bound retry-session marker before the retry emits its first
percentage line. Eight of ten current terminal workers were created after that
commit. The two older workers, T1 and T9, are bound to existing Q10 runs and
cannot claim this basket. Every idle worker and the current multisymbol
claimant runs the post-fix generation; T6's worker was created at
`2026-08-29T21:40:26.108960+02:00`.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3 hard
criterion selected only two relationships from the original 66-pair scan:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current logical-basket Q02 `ONINIT` or `NO_HISTORY`
blocker. Historical invalid per-leg attempts do not supersede their later
logical-basket PASS rows.

The committed coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships with zero uncovered. Creating another Card
or EA would duplicate governed coverage or relax the published source
criterion, so the strategy-card extraction and EA-build gates remained closed.

## Selected existing sleeve

`QM5_20224` trades `EURUSD.DWX` and `EURJPY.DWX` on D1 with frozen beta
`-0.236324029`; `USDJPY.DWX` is conversion-history-only. Its source evidence is
adverse by construction: DEV net Sharpe `0.473267`, OOS net Sharpe `-0.118543`,
OOS return `-1.026394%`, 17 OOS state changes, and a `137.788`-D1-bar
half-life. The contract permits one pipeline falsification, not refitting,
filtering, or rescue tuning.

The approved source/build package remains sealed:

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical backtest setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Card schema/ML lint passed with no ML hits or missing sections. The logical
setfile remains low-frequency D1 with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No ML, adaptive refit, banned indicator, grid,
martingale, pyramiding, or portfolio feedback is present.

Canonical lineage:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, priority-bound,
  unclaimed, attempt zero, no verdict.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and deliberately not
  advanced before Q03 PASS.

## Deterministic paced order

At `2026-08-29T19:44:19.984977Z`, the canonical pending query contained 5,251
rows. The selected Q03 row ranked 1,877 globally and eighth among 492 pending
multisymbol rows. The seven predecessors are all legitimate XAU/XAG Q04 rows;
there is no FX pair ahead of it.

The serialized lane is currently owned by
`QM5_41077_XAU_XAG_WRETR_RV_D1`, Q04 work item
`e3545f05-449b-4ac2-8f9b-034d5483ae38`, on T6. It was the preceding
multisymbol rank-one row and moved active normally. The earlier lane occupant,
`QM5_41075`, completed Q04 `PASS_SOFT` and then terminalized Q05 `FAIL`, so the
current ordering is a real frontier delta rather than a repeated snapshot.

Promoting the target over its seven older Q04 predecessors, manually starting
a second basket, or prioritizing its Q04 successor would violate the paced
claim contract. No such action was taken.

## Capacity stop and safety boundary

The direct final five one-second CPU samples were `70.019122%`, `67.301395%`,
`69.159239%`, `75.005431%`, and `69.749632%`. Average CPU was `70.246964%`
and maximum CPU was `75.005431%`, both below the explicit `97%` ceiling. Free
physical RAM was `40.026932 GB`, above the 12 GB multisymbol floor, and commit
headroom was `88.034725 GB`, above the 48 GB floor.

However, the current branch also contains the contemporaneous capacity receipt
from commit `e265084b69fc03e6f44458b5afc74846a75c1fc9`. Its window at
`2026-08-29T19:42:08.437802Z` sampled `91.801813%`, `91.826435%`,
`97.949429%`, `96.306108%`, and `96.004264%`. Maximum CPU exceeded the 97%
hard ceiling. The later clear window does not erase an observed binding window
within this mission turn: the requested stop rule applies, and no dispatch or
backtest was started.

This run did not create, change, or control any portfolio gate,
`portfolio_admission`, portfolio `_kpi`, `_q08_contribution`, Q08 state,
T_Live, AutoTrading, live/deploy manifest, Card, EA source, EX5, setfile,
basket manifest, registry, magic row, resolver, queue row, priority, claim,
status, verdict, reservation, worker, terminal, smoke, or backtest. Background
worker rotations and farm progress were observed read-only. Existing unrelated
shared-worktree changes were preserved and excluded from this commit.

Machine-readable evidence:
`artifacts/qm5_20224_q03_postfix_paced_handoff_20260829T194420Z_board_advisor.json`.

## Continuation condition

This turn is stopped at the observed CPU ceiling. On a later paced wake, take a
fresh five-sample CPU window first. Only if both average and maximum are
strictly below 97% should the active basket and seven older Q04 predecessors
continue to drain toward the same exact QM5_20224 Q03 row. Do not enqueue
Q02/Q03 again or promote Q04 before a canonical Q03 PASS.
