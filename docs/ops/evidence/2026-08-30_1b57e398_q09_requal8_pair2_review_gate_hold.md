# Q09 REQUAL-8 pair 2 — mandatory-review gate hold

- Recorded at: `2026-08-30T21:11:23Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- Build task: `5f5da824-916d-4d37-b12c-0fcb642f5508`
- EA: `QM5_41216_grimes-nested-pb-v2-requal8`
- OWNER decision: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Verdict: **PAIR 2 BUILD AWAITS MANDATORY REVIEWS; PREMATURE Q02 ROW IS APPEND-ONLY AND GOVERNED-HELD; PARENT HOLD NOT RELEASED**

## Record-build transition

`farmctl.py record-build` accepted the schema-valid pair-2 build result at
`2026-08-30T21:10:30Z`. The build task moved from `pending` to `done`, preserving
the governed compile and `deferred_p2_smoke` capacity receipt.

The command also exposed a control-plane sequencing defect: it immediately
auto-enqueued Q02 work item
`d27038b7-2110-45e0-8a36-ecf116c697d2` for `XAUUSD.DWX/H4` before either the
mechanical Codex review or independent Claude review existed. The output named
the path `record_build_result.auto_q02`. This ordering conflicts with the
approved manifest's review-before-seed contract.

## Fail-closed containment

The new row was detected while still `pending`, `attempt_count=0`,
`claimed_by=NULL`, `verdict=NULL`, and `evidence_path=NULL`. It was not deleted,
reused, or rewritten. The sanctioned governed-hold tool was dry-run first and
then applied against the exact `work_item_id=symbol` target.

| Field | Durable value |
|---|---|
| Work item | `d27038b7-2110-45e0-8a36-ecf116c697d2=XAUUSD.DWX` |
| Phase | `Q02` |
| Hold code | `MANDATORY_BUILD_REVIEW_PENDING` |
| Active / restart release | `1 / 0` |
| Claimable after apply | `false` |
| Apply receipt | `docs/ops/evidence/2026-08-30_1b57e398_q09_requal8_pair2_premature_q02_hold.json` |
| Pre-mutation DB backup | `D:/QM/strategy_farm/state/backups/farm_state_before_governed_hold_20260830T211116Z.sqlite` |
| Backup SHA-256 | `8a78cbd47fcc6df32ebafcfe923ee15119a02c11386aa5f34790c1855bbde862` |

The release condition is exact: release only after a mechanical Codex review
`PASS` and independent Claude final-review `APPROVE` bind build task
`5f5da824-916d-4d37-b12c-0fcb642f5508`. The row must then execute normally and
produce authentic Q02 evidence before the decision-bound parent hold can be
released.

## Current serial boundary

- The prematurely appended Q02 row exists but cannot be claimed while the hold
  is active. It is not a Q02 verdict and no pipeline evidence is claimed.
- Parent hold `1cff016c-d25c-4723-a892-6bc53bfafa0b` remains `pending`,
  unclaimed, without verdict or evidence.
- Pairs `QM5_41217` through `QM5_41222` remain card-only.
- Protected `QM5_41162` `OPT_CENSUS` was not touched.
- No terminal, active tester, worker, or reservation was interrupted.

The router task should remain at the review boundary. Pair 3 must not start
until the reviewers resolve pair 2 and the held Q02 seed reaches an authentic
terminal outcome.

Verdict: `PAIR2_MANDATORY_REVIEW_PENDING_Q02_ROW_GOVERNED_HELD`; one premature
append-only Q02 seed contained before claim, zero Q02 verdicts, zero parent-hold
releases, and zero historical-row deletion.
