# QM5_20219 FX cointegration Q04 priority handoff

Date: 2026-08-29 UTC (`2026-08-29T04:48:32Z`); 06:48 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `1d1441d067bb86a5d7aaed72053bd120f84bb74e`

Status: the existing USDJPY/NZDUSD logical basket was advanced in place at
Q04. No Card, EA, setfile, manifest, queue row, verdict, tester, terminal, or
portfolio-gate object was created or changed.

## Outcome

The governed 66-pair source frontier contains no unbuilt relationship left to
mechanize. The mission fallback therefore applies. The unique existing Q04 row
for `QM5_20219_USDJPY_NZDUSD_COINTEGRATION_D1`, work item
`b721ce82-2d53-46db-b2d0-f20b561a1513`, was promoted in place with
`priority_track=true`.

The exact-ID payload CAS preserved the row's pending, unclaimed, attempt-0
state and its original `updated_at`. Canonical pending rank improved from 2115
to 1960. Audit event `380251` records the mutation. Exactly one matching open
Q04 row remains; no duplicate was enqueued.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published hard
criterion selected only the two established relationships:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor is blocked at Q02. The committed sign-aware coverage artifact
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships with zero uncovered, and the durable
approved-card/EA census has zero approved unbuilt cointegration Cards. Creating
another Card would therefore duplicate governed coverage or relax the
published reputable-source criterion. The Strategy Card extraction and new-EA
build gates remained closed.

The immediately preceding existing fallback, `QM5_20255`, has now completed
Q04 with economic FAIL (`F1 pf=0.771`, `F2 pf=0.837`, `F3 pf=0.437`) and is not
eligible for further progression.

## Selected existing sleeve

`QM5_20219` is the sign-aware scan's rank-40 USDJPY/NZDUSD relationship and the
highest-ranked unfinished relationship with Q02 PASS, Q03 PASS, and exactly one
pending Q04 successor. It trades `USDJPY.DWX` and `NZDUSD.DWX` on D1 with a
frozen negative beta.

The approved Card explicitly treats the scan evidence as weak and adverse:
DEV net Sharpe `0.121916`, OOS net Sharpe `0.050918`, OOS return `0.579866%`,
14 OOS state changes, beta `-0.782302979`, and half-life `206.281` D1 bars.
This is a one-shot pipeline falsification, not permission to refit, add a
filter, or rescue a failed gate.

The current package remains identical to its sealed Q02 and Q03 PASS lineage:

| Binding | SHA-256 |
|---|---|
| Approved Card | `696486d101c7fac2216bb6f6558e78189d833a506c2aea3491fd0b5654ee096b` |
| MQ5 | `a3d9f49b79b5eba8eacc96f63fc74266ac4d3deebd17a35d89510758406fed13` |
| EX5 | `4f9758038a5ddfd2d4ca3ffa21ea22facf73973af9b623d4fc924e61eff1caba` |
| Basket manifest | `f3fb7c93c0bebf8cd86aeae11a2e43e94b4d4bc976a14315092394db992ab54c` |
| Logical setfile | `58bce294bf0ae7d46d398da737b5857e8ec71d985dae202b3f12a54a8a2361bc` |

The logical backtest setfile remains low-frequency D1 with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The approved
Card and EA are structural fixed-beta cointegration logic: no machine
learning, adaptive refit, banned indicator, grid, martingale, or portfolio
feedback was introduced.

Sealed lineage:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PASS.
- Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: pending,
  `priority_track=true` after this handoff.

## Guarded queue mutation

The mutation changed only `payload_json.priority_track`, its reason, and a
bounded handoff provenance object. It used the exact work-item ID, exact
preimage payload, pending/unclaimed/attempt-0 predicates, and a one-row CAS.
The row had no active hold, supersede relation, or poison-pill quarantine.

The reversible preimage/postimage journal is
`D:/QM/reports/state/qm5_20219_q04_priority_20260829T044832Z.journal.json`
(SHA-256
`b39f4bb453aa058d9589726f04a91f79c2e6547387a0cf8957245200ed4b947b`,
state `COMMITTED`). The factory mutation lock was acquired after a 153.235
second bounded wait and released cleanly.

## Capacity and paced-fleet handoff

The five CPU samples taken while holding the mutation boundary were
`51.867402%`, `54.025388%`, `80.675748%`, `53.717659%`, and `53.250331%`.
Average CPU was `58.707306%` and maximum CPU was `80.675748%`, both strictly
below the explicit `97%` ceiling.

No multisymbol work item was active at apply time. No manual dispatch, tester,
reservation, or terminal action was started; the row remains pending for the
deterministic paced worker.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live, AutoTrading, live/deploy manifest, or Q08 state
was touched. Unrelated shared-worktree changes were preserved and excluded
from this commit.

Machine-readable evidence:
`artifacts/qm5_20219_q04_priority_20260829T044832Z_board_advisor.json`.
