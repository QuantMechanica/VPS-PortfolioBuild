# QM5_20238 FX cointegration Q04 priority handoff

Date: 2026-08-30 UTC (`2026-08-30T21:21:03Z`); 23:21
Europe/Berlin

Branch: `agents/board-advisor`

Status: the existing USDCAD/EURJPY logical basket was advanced in place at
Q04. No Card, EA, setfile, manifest, queue row, verdict, tester, terminal, or
portfolio-gate object was created or changed.

## Outcome

The exact pending Q04 row for
`QM5_20238_USDCAD_EURJPY_COINTEGRATION_D1`, work item
`fcc4268d-4966-4ea6-ba14-4b684fe41a28`, now carries the governed priority
handoff. A payload preimage CAS preserved its pending, unclaimed, attempt-zero
state and original `updated_at`. Canonical pending rank improved from 7,465 to
1,566 inside the transaction. Audit event `380891` records the mutation, and
exactly one matching open Q04 row remains; no duplicate was enqueued.

The immediately preceding rank-55 `QM5_20232` Q04 row remains one position
ahead at canonical rank 1,565, so this handoff preserved frontier order.

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

`QM5_20238` is the frozen rank-57 USDCAD/EURJPY D1 relationship. It trades
`USDCAD.DWX` and `EURJPY.DWX` with fixed beta `-0.243266890557`;
`USDJPY.DWX` is conversion-history-only and receives no order or magic slot.
The package is structural and low-frequency: there is no learned model,
adaptive refit, banned indicator, grid, martingale, or runtime external-data
dependency.

The canonical logical-basket setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The Card schema lint, manifest JSON,
and those risk bindings passed fresh static checks. Source, binary, and setfile
hashes match the sealed predecessor rows:

| Phase | Work item | Result |
|---|---|---|
| Q02 | `888ccfcc-f0fe-4095-a162-9b47b0401e51` | PASS |
| Q03 | `dc7cadb3-f1f3-40a7-b6dc-d9b38b208223` | PASS |
| Q04 | `fcc4268d-4966-4ea6-ba14-4b684fe41a28` | pending, prioritized in place |

The original scan evidence is adverse: DEV net Sharpe `-0.006562`, OOS net
Sharpe `-0.403385`, OOS return `-2.696283%`, 13 OOS state changes, and a
`66.784`-bar half-life. Q04 remains a one-shot falsification gate. This handoff
does not authorize a refit, new filter, or rescue after a terminal economic
failure.

## Guarded queue mutation

The transaction changed only the exact row's `payload_json`, adding
`priority_track=true`, reason
`board_advisor_fx_fallback_rank57_q04_after_q03_pass`, and bounded handoff
provenance. It used the shared factory mutation lock plus exact ID, payload
hash, pending/unclaimed/attempt-zero, verdict, and `updated_at` predicates.
Status, claim, attempt count, verdict, and `updated_at` did not change.

The preimage payload SHA-256 was
`31fb060764121de4c5b38d37f7da45365b5ab0a8fb6e14317093ed214364750e`;
the postimage is
`b019e9df6ae41c28e1b9753e255b4b5bc2c17d3f34de43d0d8d752708050b61b`.
There are no active holds, supersession relations, or quarantine rows on the
target. The reversible journal is
`D:/QM/reports/state/qm5_20238_q04_priority_20260830T212103Z.journal.json`
(SHA-256
`fafa7ceeea0dae1f5bde99ddab2b8c4812c6c61b510e10d9f8923ba1db0701aa`,
state `COMMITTED`). Its revert guard permits restoration only while the current
payload still matches the recorded postimage hash.

## Capacity and paced handoff

The preflight CPU samples were `74%`, `78%`, `76%`, `69%`, and `77%`; average
CPU was `74.8%` and maximum CPU was `78%`. The apply-time samples were `94%`,
`77%`, `79%`, `70%`, and `86%`; average CPU was `81.2%` and maximum CPU was
`94%`. Both windows remained below the 97% hard ceiling.

The serialized basket lane remains occupied by `QM5_20224` Q05 work item
`482013fe-c135-4c9a-84ab-ab08727472d8` on T4. No manual dispatch, terminal
control, or backtest was started. `QM5_20238` remains pending behind
`QM5_20232` for the paced worker after the lane clears.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading state, or live/deploy
manifest was touched. The unrelated shared-worktree edits to
`QM5_41229_wti-samecal-trimean5.mq5` and `compile_work_items.py` were preserved
and excluded from this handoff.

Machine-readable evidence is
`artifacts/qm5_20238_q04_priority_20260830T212103Z_board_advisor.json`.
