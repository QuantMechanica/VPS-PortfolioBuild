# QM5_20232 FX cointegration Q04 priority handoff

Date: 2026-08-30 UTC (`2026-08-30T20:20:20Z`); 22:20
Europe/Berlin

Branch: `agents/board-advisor`

Status: the existing USDCHF/NZDUSD logical basket was advanced in place at
Q04. No Card, EA, setfile, manifest, queue row, verdict, tester, terminal, or
portfolio-gate object was created or changed.

## Outcome

The exact pending Q04 row for
`QM5_20232_USDCHF_NZDUSD_COINTEGRATION_D1`, work item
`bfad4436-ae19-4b7d-a7cf-1c02a0324d67`, now carries the governed priority
handoff. A payload preimage CAS preserved its pending, unclaimed, attempt-zero
state and its original `updated_at`. Canonical pending rank improved from
7,502 to 1,604 inside the transaction. Audit event `380865` records the
mutation, and exactly one matching open Q04 row remains; no duplicate was
enqueued.

## Why the existing-sleeve fallback applied

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 study
tested all 66 FX relationships and admitted only two under the published
criterion of positive DEV Sharpe, OOS net Sharpe above 0.8, and at least four
OOS trades:

| EA | Pair | Canonical state |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The durable
sign-aware coverage record accounts for all 66 relationships. A fresh census
found 120 approved cointegration Card identities and a matching EA directory
for every one of them, leaving zero approved unbuilt identities. Creating a
new Card or EA would therefore duplicate governed coverage or weaken the
published source criterion, so the mission's existing-forex fallback applied.

## Selected pair and sealed lineage

`QM5_20232` is the frozen rank-55 USDCHF/NZDUSD D1 relationship. It trades
`USDCHF.DWX` and `NZDUSD.DWX` with fixed beta `-0.270458913`. The package is
structural and low-frequency: there is no learned model, adaptive refit,
banned indicator, grid, martingale, or runtime external-data dependency.

The canonical logical-basket setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The Card schema lint, manifest JSON,
and those risk bindings passed fresh static checks. Source, binary, and setfile
hashes match the sealed predecessor rows:

| Phase | Work item | Result |
|---|---|---|
| Q02 | `ca72ac7d-162c-4c54-b2e4-d7765c15efeb` | PASS |
| Q03 | `73d11c4c-0542-4828-9631-1954799a87a5` | PASS |
| Q04 | `bfad4436-ae19-4b7d-a7cf-1c02a0324d67` | pending, prioritized in place |

The original scan evidence is adverse: DEV net Sharpe `0.035539`, OOS net
Sharpe `-0.387376`, OOS return `-3.267369%`, 16 OOS state changes, and a
`108.268`-bar half-life. Q04 remains a one-shot falsification gate. This
handoff does not authorize a refit, new filter, or rescue after a terminal
economic failure.

## Guarded queue mutation

The transaction changed only the exact row's `payload_json`, adding
`priority_track=true`, reason
`board_advisor_fx_fallback_rank55_q04_after_q03_pass`, and bounded handoff
provenance. It used the shared factory mutation lock plus exact ID, payload
hash, pending/unclaimed/attempt-zero, verdict, and `updated_at` predicates.
The status, claim, attempt count, verdict, and `updated_at` did not change.

The preimage payload SHA-256 was
`2180408573c2962324c33aa415469db14c6d55f3a2e8127d934ee1d310e46bba`;
the postimage is
`19d683363105b9b86df75fbbb13cbe4bfe513f93913877c40135cd98eb5a20a3`.
There are no active holds, supersession relations, or quarantine rows on the
target. The reversible journal is
`D:/QM/reports/state/qm5_20232_q04_priority_20260830T202020Z.journal.json`
(SHA-256
`c491e0e63c68ef1a2cf062f8447380c4288c53a425f3016947fb282ab8c17140`,
state `COMMITTED`). Its revert guard permits restoration only while the current
payload still matches the recorded postimage hash.

## Capacity and paced handoff

The apply-time CPU samples were `68.9%`, `72.4%`, `73.8%`, `70.5%`, and
`75.5%`. Average CPU was `72.22%` and maximum CPU was `75.5%`, both below the
97% hard ceiling.

The serialized basket lane was already occupied by `QM5_20224` Q04 work item
`a525cd8f-4c29-4752-b1af-3c43288f259e` on T4. No manual dispatch, terminal
control, or backtest was started. `QM5_20232` remains pending for the paced
worker after the lane clears.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading state, or live/deploy
manifest was touched. The unrelated shared-worktree edit to
`QM5_41229_wti-samecal-trimean5.mq5` was preserved and excluded from this
handoff.

Machine-readable evidence is
`artifacts/qm5_20232_q04_priority_20260830T202020Z_board_advisor.json`.
