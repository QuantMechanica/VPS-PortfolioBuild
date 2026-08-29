# QM5_20220 FX cointegration Q04 priority handoff

Date: 2026-08-29 UTC (`2026-08-29T07:26:30Z`); 09:26 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `c1098a6abf366915691376f0088b8b2ab7ef6442`

Status: the existing USDCAD/AUDJPY logical basket was advanced in place at
Q04. No Card, EA, setfile, manifest, new work-item row, verdict, tester,
terminal, or portfolio-gate object was created; only the existing row's
bounded priority payload changed.

## Outcome

The governed 66-pair source frontier contains no unbuilt relationship left to
mechanize. The mission fallback therefore applies. The unique existing Q04 row
for `QM5_20220_USDCAD_AUDJPY_COINTEGRATION_D1`, work item
`0961cfd5-4831-4ef9-bf5b-cab4bfcab089`, was promoted in place with
`priority_track=true` and reason
`board_advisor_fx_fallback_rank42_q04`.

The exact-ID payload CAS preserved the row's pending, unclaimed, attempt-0,
unverdict state and its original `updated_at`. Canonical pending rank improved
from 2104 to 1932. Audit event `380358` records the mutation. Exactly one
matching open Q04 row remains; no duplicate was enqueued.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published hard
criterion selected only the two established relationships:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor is blocked at Q02 by `ONINIT` or `NO_HISTORY`. The committed
sign-aware coverage artifact
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships with zero uncovered, and the durable
approved-card/EA census has zero approved unbuilt cointegration Cards. Creating
another Card would therefore duplicate governed coverage or relax the
published source criterion. The Strategy Card extraction and new-EA build
gates remained closed.

Rank 40 `QM5_20219` already received its own exact Q04 priority handoff earlier
on 2026-08-29 and remains pending once. Rank 41 `QM5_12765` is terminal at Q04
FAIL. Rank 42 is therefore the next recorded nonterminal relationship whose
existing Q04 successor had not yet been priority-bound.

## Selected existing sleeve

`QM5_20220` trades `USDCAD.DWX` and `AUDJPY.DWX` on D1 with a frozen negative
beta. `AUDUSD.DWX` and `USDJPY.DWX` are conversion-history dependencies only
and receive no orders or magic slots.

The approved Card explicitly treats the frozen scan evidence as adverse: DEV
net Sharpe `0.285291`, OOS net Sharpe `-0.060279`, OOS return `-0.374459%`, 15
OOS state changes, beta `-0.186232670`, and half-life `73.380` D1 bars. This is
a one-shot pipeline falsification, not permission to refit, add a filter, or
rescue a failed gate.

The Q03 reproducibility run completed twice with identical results: 136 trades,
PF `0.70`, 7.20% drawdown, and net profit `-5628.03` per run. Q03 proves
deterministic execution; it does not approve the economics. Q04 remains the
economic judge.

The current package remains identical to the sealed Q03 lineage:

| Binding | SHA-256 |
|---|---|
| Approved Card | `701bb4407149aa8992cf5eeb9bd17754f9162bda3d878f25b9e7bd9dac530ec2` |
| MQ5 | `7f5c593178f99f667b9318dc7afd962ca02613b69aeb9f64177f3a5ab884f67d` |
| EX5 | `464b198b76c21106a5cc89b61802855c3deae4f3d3d12fa77a8a0efaf83690ca` |
| Basket manifest | `f018b19daad14c135618c09d23b4f3186e5ff103c904afa8c15b12976fb65203` |
| Logical setfile | `ebce89cfeb15844170f6b7ac558786e7c0d4312543767a4eb8305c6eac39ec09` |

The Card schema lint passed with `g0_status: APPROVED`. The logical backtest
setfile remains low-frequency D1 with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The approved Card and EA use structural fixed-beta
cointegration logic: no machine learning, adaptive refit, banned indicator,
grid, martingale, or portfolio feedback was introduced.

Sealed lineage:

- Q02 `61e7d1af-35a2-48f4-8602-afcf94949118`: PASS.
- Q03 `2e797aa8-42ef-479e-875f-da93436ca528`: PASS.
- Q04 `0961cfd5-4831-4ef9-bf5b-cab4bfcab089`: pending,
  `priority_track=true` after this handoff.

## Guarded queue mutation

The mutation changed only `payload_json.priority_track`, its reason, and a
bounded handoff provenance object. It used the exact work-item ID, exact
preimage payload, pending/unclaimed/attempt-0 predicates, and a one-row CAS.
The row had no active hold, supersede relation, or poison-pill quarantine.

The reversible preimage/postimage journal is
`D:/QM/reports/state/qm5_20220_q04_priority_20260829T072606Z.journal.json`
(SHA-256
`6bb2866471f1a85d9cca6a13f8531a760538cc9742e6e683a918ecdd95b9286d`,
state `COMMITTED`). The factory mutation lock was acquired after an 18.468
second bounded wait and released cleanly.

## Capacity and paced-fleet handoff

The immediate preflight samples averaged `90.292969%` with a `95.019531%`
maximum. The five samples inside the mutation lock averaged `84.632260%` with
a `93.652344%` maximum. Both maxima were below the explicit `97%` backtest CPU
ceiling.

No multisymbol work item was active at apply time. No manual dispatch, tester,
reservation, or terminal action was started; the row remains pending for the
deterministic paced worker.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live, AutoTrading, live/deploy manifest, or Q08 state
was touched. Unrelated shared-worktree changes were preserved and excluded
from this commit.

Machine-readable evidence:
`artifacts/qm5_20220_q04_priority_20260829T072606Z_board_advisor.json`.
