# QM5_10025 USDJPY-host market-neutral FX Q02 priority advance

Date: 2026-09-01 UTC

Branch: `agents/board-advisor`

Outcome: one existing Q02 row promoted in place; no duplicate enqueue and no
tester launch.

## Frontier and fallback decision

The controlling 66-relationship scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. The latest durable
census records 123 approved cointegration identities, 123 matching EA
directories, and no unbuilt identity. Creating another scan-derived Card or EA
would therefore be duplicate work.

The preferred anchors do not need Q02 repair:

| EA | Pair | Current lineage |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has an open Q02 `ONINIT` or `NO_HISTORY` blocker. The mission's
existing-card fallback therefore applies.

The selected package is `QM5_10025_rw-fx-broad-pairs`, an already approved and
built H4 market-neutral FX spread sleeve. It selects one partner monthly from
seven registered FX majors, freezes the OLS hedge ratio, and opens both legs
with beta-weighted package risk. The Card expects about six round trips per
host-year. It uses deterministic correlation, ADF-proxy, OLS-residual, and
z-score rules; it has no ML, grid, martingale, or PnL-adaptive mechanic.

The manifest intentionally has no synthetic logical symbol. Each of the seven
registered hosts is a physical Q02 identity because the monthly partner is
selected at runtime. Creating a synthetic logical row would violate that
governed manifest shape. The existing USDJPY-host canary was therefore the
smallest valid unit to advance.

## Zero-trade recovery classification

The prior USDCHF result triggered the `qm-zero-trades-recovery` workflow. The
execution identity is bound to the same MQ5 and EX5 that remain current. Its
second run produced a valid model-4 H4 report over 2018-07-02 through
2022-12-31, with no `OnInit` failure and zero trades. The first run's empty
report was correctly classified `BARS_ZERO` and was not used as strategy
evidence.

This is not a cohort-wide setup failure: the same bound build produced six
real trades on NZDUSD over the same governed window. The retained USDCHF
summary records eight logger events, but the referenced logger sample has
since been pruned, so an entry-only event count cannot be reconstructed. The
zero outcome remains symbol-specific pending another bound observation; no
threshold, filter, pair universe, stop, or other strategy mechanic was changed.

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| `QM5_10025` | USDCHF H4, 2018-07-02/2022-12-31, model 4 | Valid symbol-specific no-qualifier outcome after harness/setup passed; no shared defect established | None; advance the already-enqueued USDJPY host canary | Existing strict build remains hash-identical and passed 0 errors/0 warnings | Unknown; sample pruned (8 total logger events in summary) | 0 on USDCHF; 6 on same-build NZDUSD proof | USDJPY Q02 economics/cadence, then all downstream cost/OOS gates |

The correct status is **trade-capable**, not Q02 PASS and not successful
strategy.

## Exact Q02 advance

Under the global Factory mutation lock, a consistent SQLite backup passed
`PRAGMA quick_check`. An exact compare-and-swap then changed only the target
payload and inserted audit event `381272` (`priority_track_set`). The row's age
timestamp was preserved.

| Field | Before | After |
|---|---:|---:|
| Work item | `050dd2ea-e9d0-475f-b5ad-40c2206867ff` | same |
| Open exact Q02 rows | 1 | 1 |
| Status | pending | pending |
| Attempt count | 0 | 0 |
| Claimed by | null | null |
| `priority_track` | absent | `true` |
| Canonical pending rank | 8,282 | 1,423 |

The reason is
`board_advisor_fx_existing_market_neutral_q02_after_exhausted_66_pair_frontier`.
No work item was inserted, no historical verdict was changed, and no manual
dispatch tick was run.

The rollback journal is
`D:/QM/reports/state/qm5_10025_usdjpy_q02_priority_20260901T031756Z.journal.json`
(SHA-256
`ef384b8c35f6d3ab3dc443306d216696724387c41e9d0607f79c0c158df008c1`).
The online backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_10025_usdjpy_priority_20260901T031756Z.sqlite`
(SHA-256
`fe791d06d4a0c1523039199b090de60fefc7c83853390858b8fc11b5feab7b1f`).

## Contract and validation

The selected USDJPY H4 setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, and registered magic slot 6 (`100250006`). Artifact
bindings are unchanged:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `fd0a18d8710dc8bd0d089ab34b9c881de65e971f0916ba540b34c53b2aa120ff` |
| EX5 | `9bf2691d4af0a57d553711c37ffceadb513b303e710a25f455c8f2e211eecfcc` |
| Basket manifest | `98237a88f0634810f187a63c6d4585950aac4d5b8f21c157d23f88533691daa0` |
| USDJPY setfile | `2d8a1ba1871c229d00b49458dcbd6dbd152d24c170d76404bace39cdea3be53c` |

Static validation results:

- build prerequisite guard: PASS (EA registry, all magic rows, directory);
- build guardrails: PASS across 8 files with zero findings;
- symbol scope: `BASKET_OK`, zero violations;
- SPEC validator: PASS; and
- basket-manifest/work-item tests: 65 passed.

The legacy approved Card does not use the modern `Hypothesis`, `Rules`, and
`Risk` heading names, so the new-card schema linter reports those headings as
missing while reporting no ML hits. This is recorded as a non-gating legacy
format advisory because no new Card was extracted or approved in this unit.

One existing fleet-wide scheduler test also fails:
`test_age_credit_eventually_outranks_fresh_priority_q02` currently observes the
fresh priority row before the aged FIFO row. Five other priority tests pass.
This unit did not change canonical scheduling policy; the failure is preserved
for the fleet owner rather than silently broadened into a scheduler rewrite.

## Capacity and safety

Immediately before the mutation, five factory terminals (`T1`, `T4`, `T6`,
`T7`, and `T8`) were running against paced launch maximum 1. T8 held the
serialized multisymbol lane for Q03 work item
`f9ccf272-d66e-4a68-b332-76133baab427`. A five-sample host CPU window averaged
89.06% and peaked at 92.6%, below the explicit 97% hard threshold. Queue-only
promotion was safe; launching another tester was not.

No portfolio gate, `portfolio_admission`, portfolio KPI, Q08 contribution,
T_Live manifest, T_Live terminal, AutoTrading state, live setfile, Strategy
Card, EA source, EX5, basket manifest, setfile, registry, or historical verdict
was changed. Pre-existing unrelated worktree changes were preserved.

Machine-readable evidence is
`artifacts/qm5_10025_usdjpy_q02_priority_20260901T031756Z_board_advisor.json`.
