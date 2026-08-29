# QM5_20223 FX cointegration Q04 priority handoff

Date: 2026-08-29 UTC (`2026-08-29T11:26:54Z`); 13:26 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `412c4e1c5376748439e41bab1087c222f8a01439`

Status: the existing GBPUSD/EURGBP logical basket was advanced in place at
Q04. No Card, EA, setfile, manifest, queue row, verdict, tester, terminal, or
portfolio-gate object was created or changed.

## Outcome

The governed 66-pair source frontier contains no unbuilt relationship left to
mechanize, so the mission fallback applies. The unique existing Q04 row for
`QM5_20223_GBPUSD_EURGBP_COINTEGRATION_D1`, work item
`2dec6a14-1816-41df-b0c7-ab440244705d`, now carries
`priority_track=true` with reason
`board_advisor_fx_fallback_rank44_q04`.

The exact-ID payload CAS preserved the row's pending, unclaimed, attempt-zero,
unverdict state and its original `updated_at`. Canonical pending rank improved
from 3212 to 1928 while the pending population remained 5,374. Audit event
`380381` records the mutation. Exactly one matching open Q04 row remains; no
duplicate was enqueued.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published hard
criterion selected only the two established relationships:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current logical-basket Q02 `ONINIT` or `NO_HISTORY`
blocker. The committed sign-aware coverage artifact
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships with zero uncovered. A fresh broader census
found 119 approved Cards containing `cointegration` or `coint`, all 119 with a
matching EA directory and zero unbuilt.

Rank 40 `QM5_20219` was already priority-bound at Q04. Ranks 41
`QM5_12765`, 42 `QM5_20220`, and 43 `QM5_12766` have terminal Q04 FAIL
verdicts. Rank 44 is therefore the next recorded nonterminal relationship
whose existing Q04 successor had not yet been priority-bound.

## Selected existing sleeve

`QM5_20223` trades `GBPUSD.DWX` and `EURGBP.DWX` on D1 with a frozen negative
beta. The negative coefficient makes a long residual package long-long and a
short residual package short-short; "market-neutral" is limited to the fitted
two-series residual, not zero currency or carry exposure.

The OWNER-approved Card treats the frozen scan evidence as adverse: DEV net
Sharpe `-0.078883`, OOS net Sharpe `-0.098985`, OOS return `-0.844505%`, 17
OOS state changes, beta `-0.399228065`, and half-life `149.505` D1 bars. This
is a one-shot pipeline falsification, not permission to refit, add a filter,
or rescue a failed gate.

The current package remains identical to its sealed Q03 lineage:

| Binding | SHA-256 |
|---|---|
| Approved Card | `cc6b8ac3e6aeef188d7895ffc1e760f4678bac1f3abdd5542787057502f1888b` |
| MQ5 | `2b07affb65a30a82d19ed2afdae8bf6a180dabf383d95e49ae847c129e9d4887` |
| EX5 | `7c0b1ed6777ed6622af451a7e8658284c7a1100635fad64fd929925b5d2ea751` |
| Basket manifest | `dc51a81594bd9928aa97297b65a02db38c4d02364152d7cf70930444db765959` |
| Logical setfile | `ee8fcdc593cd6b75670f4f0ccbb2e1665a3414743f525d7efde6cca3850ffa6d` |

Card schema/ML lint passed. The logical backtest setfile remains low-frequency
D1 with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The
approved Card and EA use structural fixed-beta cointegration logic: no machine
learning, adaptive refit, banned indicator, grid, martingale, or portfolio
feedback was introduced.

The live-factory guard correctly refused an unnecessary ad-hoc build-check
attempt with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; it was not retried. The
sealed Q03 evidence independently reverified stable source, binary, and setfile
identities.

Sealed lineage:

- Q02 `696ed8f9-476b-4238-ac17-cf9a0f68e0e8`: PASS.
- Q03 `93b27e8e-3da7-4f75-a71f-e1a2e80d83e9`: PASS; two identical runs, 146
  trades, PF `0.80`, 4.59% drawdown, and net profit `-4087.18` per run. Q03
  proves deterministic execution, not economics.
- Q04 `2dec6a14-1816-41df-b0c7-ab440244705d`: pending,
  `priority_track=true` after this handoff.

## Guarded queue mutation

The mutation changed only `payload_json.priority_track`, its reason, and a
bounded handoff provenance object. It used the exact work-item ID and complete
payload preimage plus pending/unclaimed/attempt-zero predicates. The row had no
active hold, supersede relation, or poison-pill quarantine.

The first bounded lock attempt observed a legitimate live holder for 45
seconds and aborted with no mutation. The successful attempt acquired the next
normal lock gap, committed one row and one audit event, verified the postimage,
and released the lock cleanly.

The reversible preimage/postimage journal is
`D:/QM/reports/state/qm5_20223_q04_priority_20260829T112654Z.journal.json`
(SHA-256
`fe13b35bdab28d397e2833a84980f884f08532c06e14f7d968e1c0707007b508`,
state `COMMITTED`). Its revert guard permits restoration only while the current
payload still matches the recorded postimage and the row remains pending,
unclaimed, and at attempt zero.

## Capacity and paced-fleet handoff

The five CPU samples taken while holding the mutation boundary were `68.87%`,
`74.39%`, `58.30%`, `71.19%`, and `75.80%`. Average CPU was `69.71%` and
maximum CPU was `75.80%`, both strictly below the explicit 97% ceiling. A
post-action window averaged `64.95%` with an `81.22%` maximum.

No multisymbol work item was active at apply time. No manual dispatch, tester,
reservation, or terminal action was started; the row remains pending for the
deterministic paced worker.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live, AutoTrading, live/deploy manifest, or Q08 state
was touched. Unrelated shared-worktree changes were preserved and excluded
from this commit.

Machine-readable evidence:
`artifacts/qm5_20223_q04_priority_20260829T112654Z_board_advisor.json`.
