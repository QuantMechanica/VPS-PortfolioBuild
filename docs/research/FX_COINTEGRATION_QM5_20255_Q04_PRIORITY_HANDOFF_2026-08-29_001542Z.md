# QM5_20255 FX cointegration Q04 priority handoff

Date: 2026-08-29 UTC (`2026-08-29T00:15:42Z`); 02:15 Europe/Berlin

Branch: `agents/board-advisor`

Status: the existing USDCHF/EURJPY logical basket was advanced in place at
Q04. No Card, EA, setfile, manifest, queue row, verdict, tester, terminal, or
portfolio-gate object was created or changed.

## Outcome

The governed 66-pair source frontier contains no unbuilt pair left to
mechanize. The mission fallback therefore applies. The unique existing Q04 row
for `QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1`, work item
`265024c2-9c2c-457e-8696-b22b75b7d722`, was promoted in place with
`priority_track=true`.

The exact-ID payload CAS preserved the row's `pending`, unclaimed, attempt-0
state and its original `updated_at`. Canonical pending rank improved from 2139
to 1955. Audit event `380242` records the mutation. Exactly one matching open
Q04 row remains; no duplicate was enqueued.

## Frontier reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published hard
criterion selected only the two established relationships:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor is blocked at Q02. The committed sign-aware coverage artifact
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships, and the approved-card/EA census remains 25
Cards against 25 EA directories with zero approved unbuilt cointegration
Cards. A fresh database-wide Q02 basket audit found 90 FX basket identities;
the 15 without an economic Q02 verdict are broad carry/CSM baskets or an
archived basket, not an unresolved pair-cointegration identity from the scan.

Creating another Card would therefore duplicate governed coverage or relax the
published source criterion. The Strategy Card extraction and new-build gates
remained closed.

## Selected existing sleeve

`QM5_20255` is the frozen rank-64 USDCHF/EURJPY D1 relationship from the same
sign-aware frontier. It trades `USDCHF.DWX` and `EURJPY.DWX`; `USDJPY.DWX` is
declared conversion-history-only in the basket manifest.

The current files remain identical to the sealed Q02 and Q03 PASS lineage:

| Binding | SHA-256 |
|---|---|
| MQ5 | `67ccfbd144462d561db675c706b7dfbea795733f0fc6df5e404e3eae2785cd02` |
| EX5 | `b5dfb19d02b20c8754b9b5a400fe81750a315313580ecee9931a619416846d53` |
| Basket manifest | `090ef3be8e740003541bc911abb691599b28c92aa09efc557086fcc5f4ff5f17` |
| Logical setfile | `b4fb11d85874f8a382c3785c16783761ec791add216a89cb3dee0a8308bf3eec` |

The canonical backtest setfile remains low-frequency D1 with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The approved
Card and EA are structural fixed-beta cointegration logic: no machine learning,
adaptive refit, grid, martingale, or portfolio feedback was introduced.

Sealed lineage:

- Q02 `72ca17ca-f9df-40d5-806d-1d815ee4ea08`: PASS.
- Q03 `d50b8721-4691-4ab3-b0b4-14012ecb6f6a`: PASS.
- Q04 `265024c2-9c2c-457e-8696-b22b75b7d722`: pending,
  `priority_track=true` after this handoff.

## Guarded queue mutation

The mutation changed only `payload_json.priority_track`, its reason, and a
bounded handoff provenance object. It used the exact work-item ID, exact
preimage payload, pending/unclaimed/attempt-0 predicates, and a one-row CAS.
The row had no active hold, supersede relation, or poison-pill quarantine.

The reversible preimage/postimage journal is
`D:/QM/reports/state/qm5_20255_q04_priority_20260829T001542Z.journal.json`
(SHA-256
`a5f25e74740771d42fa0e0f9b93cbe672b239f8e44454b70e0a9cf6289d19ea7`,
state `COMMITTED`). Its revert guard permits restoration only while the current
payload still matches the recorded postimage hash.

An earlier full-database online-copy attempt made no target or event mutation
but was starved by continuous WAL writers. After suspending the exact local
runner, the row was verified unchanged and the incomplete 285,212,672-byte
copy was removed. The successful action used the atomic row journal instead.

## Capacity and paced-fleet handoff

The five CPU samples taken only after both factory and SQLite write admission
were 58.862069%, 44.006157%, 40.276032%, 38.370972%, and 38.110631%.
Average CPU was 43.925172% and maximum CPU was 58.862069%, both strictly below
the 97% ceiling.

A legitimate active multisymbol Q03 claim already occupies the serialized
basket lane: `QM5_20161_XAUUSD_XAGUSD_OLS_D1`, work item
`11cbafc9-5452-45d6-8a11-a81bc33473c1`, on T2. No manual dispatch, tester, or
terminal action was started. `QM5_20255` remains pending for the deterministic
paced worker after that lane clears.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live, AutoTrading, live/deploy manifest, or Q08 state
was touched. Unrelated shared-worktree changes were preserved and excluded
from this commit.

Machine-readable evidence:
`artifacts/qm5_20255_q04_priority_20260829T001542Z_board_advisor.json`.
