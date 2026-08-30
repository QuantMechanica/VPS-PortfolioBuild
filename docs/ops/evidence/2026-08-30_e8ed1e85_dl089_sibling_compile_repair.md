# DL-089 measurement sibling Q01 repair — e8ed1e85

Date: 2026-08-30  
Router task: `e8ed1e85-a8db-4345-9785-2e0ccf1f6997`  
Branch: `agents/board-advisor`

## Outcome

Both OWNER-approved DL-089 measurement siblings now have append-only,
current-source Q01 receipts with `COMPILE_OK`, compiler `0 errors / 0 warnings`,
build-check PASS, empty failure classes, and EX5 bytes matching their receipts.
No pipeline verdict is asserted by this document.

| EA | Successful row | MQ5 SHA-256 | EX5 SHA-256 | Result |
|---|---|---|---|---|
| `QM5_41195_aa-vol-sma10-opt` | `7b107d43-261d-4cd6-9c91-280e056a9bf9` | `d2a6d1e45ba2b397316fe02c48a2c4c03869386535a55e44650e0a113416b183` | `8a456d03ea2b8922dad124c39c6fb8602d0fb1226832fe2d2a51ea16bf84bc4d` | `COMPILE_OK`, Q01 PASS, 0e/0w |
| `QM5_41196_qs-kama-trend-xau-opt` | `57e3a1e7-f8ab-4a4c-9ddb-7f29fdee0acb` | `b56522fa57bc82c84df92488c8ca5f3c0afd52c65524ce0b57ec03db46525df9` | `ecf5caa23c40813604025a0257a95bac3e424a08abe59da5b7d5dfd5fb9d70e4` | `COMPILE_OK`, Q01 PASS, 0e/0w |

Canonical compiler evidence:

- `D:/QM/reports/work_items/7b107d43-261d-4cd6-9c91-280e056a9bf9/QM5_41195/COMPILE_EA/compile_evidence.json`
- `D:/QM/reports/work_items/57e3a1e7-f8ab-4a4c-9ddb-7f29fdee0acb/QM5_41196/COMPILE_EA/compile_evidence.json`

## Source repairs

The changes are framework-conformance repairs, not strategy changes:

- Both siblings replace raw `iTime` pattern-reference reads with a cached
  closed-D1 timestamp populated by `QM_ReadBar`, following the reviewed
  QM5_41194 pattern.
- Both already call `QM_FrameworkTrackOpenPositionMae()` at the start of
  `OnTick`; that Q08 sampling hook remains intact.
- QM5_41195 restores its omitted EA-local monthly-sleeve include through a
  thin forwarding include to the governed QM5_1537 loader. This fixes the
  actual MetaEditor `file not found` error without duplicating or changing the
  parent mechanics.
- QM5_41196 adds an explicit `ArraySize(closes)` fail-fast proof for the KAMA
  loop index. The first repaired build compiled at 0e/0w but correctly remained
  failed because Q01 still reported `EA_INDICATOR_BUFFER_UNBOUNDED`; the
  index-specific successor clears that check.

Risk and news contracts remain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`qm_news_stale_max_hours=336`.

## Exact authority and append-only setfiles

The existing ceremony authority remains valid only for its original task. A
second exact authority was added for this repair task:

`router_ops_issue:e8ed1e85-a8db-4345-9785-2e0ccf1f6997`

It accepts only the two named labels. Tests prove that another task ID and the
QM5_41194 label do not pass. The build checker independently enforces the same
authority, label set, and task-specific path. The retry for QM5_41196 uses a
second append-only directory because its first repair setfile was already
bound into a failed immutable receipt.

Historical top-level setfiles remain byte-identical:

| EA | Historical setfile SHA-256 before and after |
|---|---|
| QM5_41195 / XAGUSD.DWX | `b7614116188c58acf23d7117faa5ea1382009cb69f1318c48b844722b3c1a421` |
| QM5_41196 / XAUUSD.DWX | `3eb4146cd6de8592357189cd2134a3a0781fd727dcce92a92848e4f99b8f540b` |

Successful current setfile bindings are append-only and match the receipts:

| EA | Task-specific setfile SHA-256 after binding |
|---|---|
| QM5_41195 | `c35518386e9bb9001cc61413fd8fcad3aeda172dcc3db59898d9d61b6cd1d45a` |
| QM5_41196 | `e74d10377d282a3e2a0af553fab5a583f0e76558d0df58a0a63b5a317a66a6d1` |

## Attempt ledger

No historical row was rewritten:

| EA | Row | Durable disposition |
|---|---|---|
| QM5_41195 | `a7b55e40-6fa0-4f75-a7d8-018e5731216b` | Original ceremony failure: compile error, raw series call |
| QM5_41195 | `772421a8-e7df-4e1e-b8da-30a9cdd8a82b` | Failed closed at candidate recheck in a resident worker that had loaded the pre-extension authority code |
| QM5_41195 | `7b107d43-261d-4cd6-9c91-280e056a9bf9` | `COMPILE_OK`, Q01 PASS, 0e/0w |
| QM5_41196 | `ca019c2d-ff8e-4384-a116-ccdb8348c9c2` | Original ceremony compiled 0e/0w but failed raw series and buffer checks |
| QM5_41196 | `a64d8664-3c86-4fe4-9ece-ba4f0243aab0` | Compiled 0e/0w; failed only the remaining mechanical buffer proof |
| QM5_41196 | `57e3a1e7-f8ab-4a4c-9ddb-7f29fdee0acb` | `COMPILE_OK`, Q01 PASS, 0e/0w |

Release receipts are retained beside this document. Their hashes are:

| Receipt | SHA-256 |
|---|---|
| `2026-08-30_e8ed1e85_QM5_41195_compile_release.json` | `3770fbb6537d0b13f7fc5122935773d875a24fd5ce64cfd418392b5d8d02e5d0` |
| `2026-08-30_e8ed1e85_QM5_41195_compile_release_dry_run.json` | `f450bbb9c78fa6524edca075818cfb06d7c04fd5742c55cdd154d77479357bc3` |
| `2026-08-30_e8ed1e85_QM5_41195_compile_release_retry.json` | `0c53332dc3e686b70ab65cfaaf2a06db95ccdad07c9267fcecd6deaeed6ed8d6` |
| `2026-08-30_e8ed1e85_QM5_41196_compile_release.json` | `bf27e82b60f4a03fe52d06c1c2e28743c40ec66b4ac64354db1f5be819b8e28a` |
| `2026-08-30_e8ed1e85_QM5_41196_compile_release_dry_run.json` | `e9e3115b00bee54a3dbe836f2981573880fd49ef91c113688d830d687be33222` |
| `2026-08-30_e8ed1e85_QM5_41196_compile_release_retry.json` | `a92d699e4927c0b5b97f96de83cab4a120fd576f7797ec1c863768bc9feb1e01` |

The QM5_41195 retry release stdout was interrupted after its database commit;
the reconstruction receipt cites canonical event `380706` and the exact backup
without asserting fields that were not observed.

## DL-089 Q12 prerequisite dry-run

The governed service was run without `--apply` for exactly:

- `c41e2606-3af1-5766-9bb7-18de8a763a18` — QM5_1537 / XAGUSD.DWX
- `99e7e9db-d9a7-514c-b78d-c14e98ebec5d` — QM5_21507 / XAUUSD.DWX

Receipt: `2026-08-30_e8ed1e85_dl089_sibling_compile_repair_dry_run.json`,
SHA-256 `617a0089e637f08e1a9c01054860ba6c3e09af23e41865e1a1fce343deea754d`.

The dry-run made no mutation and materialized no Q12 cells. It reports:

| Q12 declaration | Measurement Q02 prerequisite | State |
|---|---|---|
| QM5_1537 / XAGUSD.DWX | `b7b3a702-7619-54a5-a164-b7e897b63ac2` / QM5_41195 | `done / INFRA_FAIL`; declaration deferred |
| QM5_21507 / XAUUSD.DWX | `df3a1f1c-4024-556f-88fa-e78821779be8` / QM5_41196 | `pending`; no cell materialized |

These are prerequisites, not pipeline verdicts. This task does not retry the
failed Q02 or claim the pending Q02.

## Verification

- Exact build hardening analysis for QM5_41196 after the index guard: zero
  failures and zero warnings.
- `test_compile_work_items.py` plus `test_gen_setfile.py`: 41 passed.
- Focused task/label authority tests: 2 passed.
- `validate_build_guardrails.py` on both sources and all task-current presets:
  PASS with zero findings.
- Python compilation and PowerShell parser checks: PASS.
- A broader pre-existing `QM5_411*` census test still reports 47 unrelated
  legacy buffer findings; the exact QM5_41196 analyzer is clean.
- SQLite work-item history is append-only; no terminal was started manually,
  no active test was interrupted, and neither AutoTrading nor T_Live was
  changed.

Implementation commits: `7424e41cf`, `e95c77b8e`.

Verdict: `PASS_BOTH_Q01_COMPILE_OK_Q12_PREREQUISITES_REPORTED`.
