# QM5_20232 FX cointegration Q04 hard CPU stop

Date: 2026-08-30 UTC (`2026-08-30T15:55:16Z`); 17:55 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `b54e1840cc23565e65ffa13a8ddbcc24bc21aa3a`

Status: stopped at the explicit backtest CPU ceiling before the existing
rank-55 Q04 row could be priority-bound. No Card, EA, queue row, payload,
status, verdict, claim, tester, or terminal was created or changed.

## Governed frontier decision

The OWNER-requested source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 study
tested all 66 FX relationships and admitted only two under the published
criterion of positive DEV Sharpe, OOS net Sharpe above 0.8, and at least four
OOS trades:

| EA | Pair | Canonical state |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor is blocked at Q02 by `ONINIT` or `NO_HISTORY`. The committed
66-pair coverage audit has no uncovered relationship, and the latest approved
Card census has no unbuilt FX-cointegration Card. Creating another Card, EA,
or Q02 row would duplicate governed coverage or weaken the reputable-source
criterion, so the Card-extraction and EA-build gates remained closed.

Ranks 46 (`QM5_20224`) and 50 (`QM5_20228`) already have exact pending Q04
rows priority-bound in place. Ranks 51 through 54 are already represented by
dedicated builds with terminal or later funnel histories. The next untouched,
dependency-complete relationship is therefore rank 55,
`QM5_20232_USDCHF_NZDUSD_COINTEGRATION_D1`.

## Existing forex successor verified

QM5_20232 is an OWNER-approved, structural fixed-beta D1 basket trading
`USDCHF.DWX` and `NZDUSD.DWX`. It has no conversion-only symbol. The sealed
setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; its two active magic rows match the traded legs. Card
schema/ML lint returned `ok` with no ML hits or missing sections.

The exact lineage is:

| Phase | Work item | State |
|---|---|---|
| Q02 | `ca72ac7d-162c-4c54-b2e4-d7765c15efeb` | done / PASS |
| Q03 | `73d11c4c-0542-4828-9631-1954799a87a5` | done / PASS |
| Q04 | `bfad4436-ae19-4b7d-a7cf-1c02a0324d67` | pending, unclaimed, attempt zero, unprioritized |

Q03 ran twice over 2018-07-02 through 2022-12-31. Both runs returned 132
trades, PF `0.62`, net profit `-5346.43`, drawdown `6958.14` (`6.94%`), and
no OnInit failure. That is a deterministic Q03 PASS, not an economic PASS;
Q04 remains the required falsification gate.

The Card preserves the adverse scan evidence: DEV net Sharpe `0.035539`, OOS
net Sharpe `-0.387376`, OOS return `-3.267369%`, 16 OOS state changes, fixed
beta `-0.270458913`, and a `108.268`-D1-bar half-life. A terminal Q04 failure
retires this exact sleeve and does not authorize a filter, refit, or rescue.

| Binding | SHA-256 |
|---|---|
| Approved Card | `8f95bd82d91957b794949298ebbc4d65f06bf91a71f6e7ebe38331dd7e405001` |
| MQ5 | `c262de17327305ff33f01bab3ff41a09c1d1bd1ca2d0ef9cd3c7200b95d14be0` |
| EX5 | `1d9378dfc38df19e2f51f6e623c5a3fb3c8511f2b72acc8fd37b8f84a8c9bdbc` |
| Basket manifest | `728679e87475089e5ead200bd2d63fbf462fd3780af753911619f5e4593c0fe0` |
| Logical backtest setfile | `5e08262b87977127392e2e0f322233cb0c6de4c343555cc9823d43dd47fd4d46` |

## Fail-closed apply sequence

The exact Q04 row had no active hold, quarantine, supersession, prior
priority event, claim, verdict, or payload drift. Its preimage SHA-256 was
`2180408573c2962324c33aa415469db14c6d55f3a2e8127d934ee1d310e46bba`.

The first guarded apply attempt found the canonical factory mutation lock
busy and failed closed before opening a database transaction or journal. Once
the lock cleared, the row was re-read and remained byte-identical. No retry
mutation was attempted until a fresh CPU window completed.

That mandatory retry window was `99.708084%`, `94.061453%`, `92.777822%`,
`87.605248%`, and `92.485011%`. Average CPU was `93.327524%`; maximum CPU was
`99.708084%`. The maximum exceeded the explicit 97% ceiling, so the run
stopped before reacquiring the lock or touching the queue.

The serialized basket lane was occupied at preflight by QM5_20233 Q03 work
item `f9ccf272-d66e-4a68-b332-76133baab427` on T2. It was not interrupted or
mutated, and QM5_20232 was not dispatched.

## Safety boundary and continuation

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading state, or live/deploy
manifest was touched. No strategy logic, Card, MQ5, EX5, setfile, basket
manifest, registry, magic row, work-item identity, payload, priority, claim,
status, attempt, or verdict changed. Existing unrelated shared-worktree
changes were preserved.

Machine-readable evidence is in
`artifacts/qm5_20232_q04_hard_cpu_stop_20260830T155516Z_board_advisor.json`.

On a later paced wake, take a fresh five-sample CPU window. Only when average
and maximum are both strictly below 97% may the exact Q04 row be revalidated
and priority-bound in place under the factory mutation lock. Do not enqueue or
dispatch a duplicate.
