# Q09 REQUAL-8 serial execution — pair 2 governed compile handoff

- Recorded at: `2026-08-30T20:29:10Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER decision: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest: `docs/ops/evidence/2026-08-30_8709bc0f_q09_requal8_manifest.json`
- Manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Serial pair: `QM5_12989 -> QM5_41216`, `XAUUSD.DWX`, `H4`
- Authentic anchor: `543c693f-867d-40af-b07f-35d501e46485`
- Decision-bound hold: `1cff016c-d25c-4723-a892-6bc53bfafa0b`
- Verdict: **PAIR 2 SOURCE/SET PASS; GOVERNED COMPILE ENQUEUED AND ACTIVATION-HELD; NO Q02 SEED; HOLD NOT RELEASED**

## Governed build state

The approved recovery card was materialized as the manifest-reserved identity
`QM5_41216_grimes-nested-pb-v2-requal8`. The implementation is a faithful
identity port of parent `QM5_12989`, with the framework-required series-access,
request-initialization, management reachability, and Q08 MAE-hook hardening.

| Item | Durable value |
|---|---|
| Recovery card | `D:/QM/strategy_farm/artifacts/cards_review/QM5_41216_grimes-nested-pb-v2-requal8.md` (`g0_status: APPROVED`) |
| Build task | `5f5da824-916d-4d37-b12c-0fcb642f5508`, `pending` |
| EA source | `framework/EAs/QM5_41216_grimes-nested-pb-v2-requal8/QM5_41216_grimes-nested-pb-v2-requal8.mq5` |
| Specification | `framework/EAs/QM5_41216_grimes-nested-pb-v2-requal8/SPEC.md` |
| Current MQ5 SHA-256 | `86ca7542f43cbff111adb6fe96fa6e1a1e13e100196cfa57f71365e86b66deb2` |
| Historical bound set | `sets/QM5_41216_grimes-nested-pb-v2-requal8_XAUUSD.DWX_H4_backtest.set` |
| Historical set SHA-256 | `d033c99a70f4a53512835fc828c58900295b185e2dc1b4784ef8180eba2e7c48` |
| Historical declared build hash | `e9e5f61073688b3329ebef7f04cc93eae9d1d099707bde0bf3ed0c1d328792e3` |
| Append-only compile set | `sets/requal8_repair_1b57e398/QM5_41216_grimes-nested-pb-v2-requal8_XAUUSD.DWX_H4_backtest.set` |
| Append-only set SHA-256 | `85b0dbe2b5ca2830e963226a38fc6bea43c36b038d76cbe32eb34f9da4b0d69a` |

Both setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`. The EA retains
`qm_news_stale_max_hours=336`; the fail-closed news-data ceiling was not
weakened.

The deterministic registries were already allocated and remain append-only:

- EA row: `41216,grimes-nested-pb-v2-requal8,...,active`
- magic row: slot `0`, `XAUUSD.DWX`, magic `412160000`, `active`

Task artifacts were committed on `agents/board-advisor` by the scheduled pump
and this cycle's explicit task pathspecs:

- `ab00a4466` — source, SPEC and initial set materialization (pump commit also
  contains its own contemporaneous factory paths);
- `4455e583a` — historical set binding;
- `c9656348d` — append-only governed compile set.

## Focused verification

The final task-local state was clean. Static verification was rerun against the
exact current source and append-only set:

- `framework/scripts/validate_spec_doc.py`: `PASS` (`1 PASS, 0 FAIL`);
- `tools/strategy_farm/validate_build_guardrails.py`: `PASS`, no findings,
  maximum news staleness `336`;
- `tools/strategy_farm/build_gate_hardening.py`: zero failures; only the normal
  undecidable-card warnings because the approved recovery card lives in the
  runtime `cards_review` directory rather than the canonical EA directory;
- source and set hashes recomputed from disk match the compile queue payload.

No smoke, tester run, pipeline phase, pipeline verdict, or review approval is
claimed by this evidence.

## Compile queue boundary

The first ordinary enqueue was correctly refused because the historical
setfile already contained a different immutable build binding. No row was
created. The manifest-authorized append-only sibling-rebind path then created
exactly one governed compile item:

| Item | Current live state |
|---|---|
| Compile work item | `f2ee1f09-1233-4165-b1f1-b828b2d59555` |
| Queue utility | `COMPILE_EA` |
| Source-repair authority | `router_ops_issue:1b57e398-3709-44b3-a53a-21e20fdb5d7b` |
| Build-task binding | `5f5da824-916d-4d37-b12c-0fcb642f5508` |
| Status / attempt | `pending` / `0` |
| Claim / verdict / evidence | `NULL` / `NULL` / `NULL` |
| Activation hold | `COMPILE_EA_WORKER_ROLLOUT_PENDING` |
| Activation state | `AWAITING_REVIEWED_WORKER_ROLLOUT` |

`farmctl.py compile-status` reports one pending, activation-held item and zero
active, compiled, or failed items. There is no governed EX5, bound-set result,
compile evidence, or compile verdict yet. This cycle did not release the
activation hold, reload or restart a worker, start a terminal, or interrupt a
test. The existing queue item must not be duplicated.

## Excluded preflight compile incident

Before the queue item was created, `build_check.ps1` was invoked as a static
preflight. The wrapper unexpectedly called its direct compile helper and
produced an EX5 outside a `COMPILE_EA` work-item claim. That result is not
accepted as governed evidence and is not present in the EA directory.

The newly created binary was moved recoverably to:

`D:/QM/reports/maintenance/20260830_qm5_41216_ungoverned_preflight_compile/QM5_41216_grimes-nested-pb-v2-requal8.ungoverned-preflight.ex5`

Its SHA-256 is
`ac1f368280e31411914b9dfc0a28c02f37ba13f32afe2c99894f33a76a9b5c28`.
The wrapper log remains under
`framework/build/compile/20260830_201707/`, and its generated report is
`D:/QM/reports/framework/21/build_check_20260830_201705.json`. Neither is used
as a compile, review, or pipeline verdict. All subsequent compile handling used
only the governed queue.

## Append-only and serial invariants

The final read-only database census found:

- zero Q02 rows for `QM5_41216`;
- the decision-bound parent hold
  `1cff016c-d25c-4723-a892-6bc53bfafa0b` remains `pending`, unclaimed, with no
  verdict or evidence;
- no pair-2 review task or approval exists because the governed compile has not
  run;
- pairs 3–8 were not started in this cycle;
- no historical work-item row, hold verdict, or evidence artifact was
  overwritten.

Unrelated concurrent changes under `QM5_41229` and
`tools/strategy_farm/compile_work_items.py` were left untouched and excluded
from this task's commits.

## Required continuation

Allow the normal reviewed-worker rollout/release ceremony to consume existing
compile item `f2ee1f09-1233-4165-b1f1-b828b2d59555`; do not enqueue a duplicate
and do not substitute the excluded preflight binary. Continue only after the
queue produces durable `COMPILE_OK` evidence and a bound EX5/set result. Record
the build result, require mechanical Codex review and independent Claude review,
then append exactly one manifest-authorized Q02 seed. Release hold
`1cff016c-d25c-4723-a892-6bc53bfafa0b` only after that seed is verified. Pair 3
must remain untouched until pair 2 completes.

Verdict: `PAIR2_GOVERNED_COMPILE_ENQUEUED_ACTIVATION_HELD`; zero Q02 seeds,
zero hold releases, zero pipeline verdicts, and zero terminal/test disruption.
