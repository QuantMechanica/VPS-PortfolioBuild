# Q09 REQUAL-8 pair 6 governed build recorded; review pending

- Recorded: `2026-09-01T09:08Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Build commit: `6c023a6985461f95601503da0c45397624245585`
- Checkpoint: `PAIR6_BUILD_RECORDED_REVIEW_PENDING`

## Outcome

Pair 6's governed build is complete and recorded. The approved recovery card
was implemented as a faithful identity port of parent
`QM5_10939_grimes-context-pb` to successor
`QM5_41220_grimes-context-pb-requal8` for `GBPUSD.DWX H4`. The build uses the
current V5 framework, the `QM5_41194` bounded series-access repair pattern, and
the Q08 MAE-first management hook required by the manifest handoff.

Compilation ran only through the canonical `COMPILE_EA` queue. The resident
worker returned `COMPILE_OK`; build-check passed and MetaEditor reported zero
errors and zero warnings. The governed build result was then recorded against
the exact child build task, which is now `done`.

No Q02 row was created. Automatic Q02 enqueue was explicitly suppressed with
reason `q09_requal8_review_required_before_q02`; the exact Q02 row count for
`QM5_41220` is zero. No independent review task was created manually. Pair 6's
manifest hold remains active pending the normal independent review, Q02 seed,
and subsequent manifest-controlled release. Pairs 7-8 remain behind the serial
boundary and were not built or enqueued in this cycle.

No terminal was started manually, no active T1-T10 test was interrupted, and
neither AutoTrading nor `T_Live` was changed. The protected `QM5_41162`
`OPT_CENSUS` program was not targeted. This is build evidence only and asserts
no pipeline verdict.

## Authority and identity bindings

- Recovery card:
  `D:/QM/strategy_farm/artifacts/cards_review/QM5_41220_grimes-context-pb-requal8.md`
- Recovery-card SHA-256:
  `0019d8c64b6379252606a4cb9109242e0ced53da80546b820287cc32ed479511`
- Card state: `g0_status: APPROVED`
- Source authority:
  `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_10939`
- Active registry binding: `41220,grimes-context-pb-requal8`
- Active magic binding: slot 0, `GBPUSD.DWX`, `412200000`
- Pair-6 manifest hold:
  `9639a773-b913-40a2-b12f-128a027aec98` /
  `Q09_AWAITING_SEALED_PLAN`, verified `active=1`
- Parent MQ5 SHA-256:
  `619331975f50ef4a4c0a97b7feaa091d9d37a311502390387ea3a90441fdead9`
- Parent EX5 SHA-256:
  `812fc52a90f0dba0282aa2fecb3a0b3640c18386ac3e2ab7e3b80765a3970278`
- Parent `GBPUSD.DWX H4` setfile SHA-256:
  `dc7c216b85598642b35cff10f52cd84dedb3ac069dc3a41695176e9362a9acba`

## Governed build and compile evidence

- Build task: `e4782ee4-9fb4-4c3e-b9d5-9f9cd2ee3b8f`, `done`
- Build result:
  `D:/QM/strategy_farm/artifacts/builds/e4782ee4-9fb4-4c3e-b9d5-9f9cd2ee3b8f.json`
- Build-result SHA-256:
  `c5cd142c6d3493e5d3b20288020313773c5327b249666d3b6eb184cb5ff1e2e5`
- Compile work item: `ae18a45e-c0f7-4434-9ae4-d00811ebcc12`
- Compile state/verdict: `done/COMPILE_OK`
- Compile release evidence:
  `docs/ops/evidence/2026-09-01_1b57e398_q09_requal8_pair6_compile_release.json`
- Compile evidence:
  `D:/QM/reports/work_items/ae18a45e-c0f7-4434-9ae4-d00811ebcc12/QM5_41220/COMPILE_EA/compile_evidence.json`
- Compile-evidence SHA-256:
  `eb94df7f58c8d4b8086c4483d5cc6528d4c12db6779fc4930ab5eae26e4e266c`
- Compiler result: `PASS`, zero errors, zero warnings
- Build-check result: `PASS`
- Compile source SHA-256:
  `a7dd265ed7d3a2b91bf8937451093e2285a1720b87406292e0ff4589f7ac6942`
- EX5 SHA-256:
  `497d824a7b630d9d2cc261bb8283f31af9cb8087e20be60922a5b5e52c38c431`

The compile work item's rollout hold was released only by the governed,
single-item release-on-restart ceremony. Its release evidence binds the router
task, manifest hash, and child build task. This compile-specific hold is
distinct from the still-active pair-6 Q09 manifest hold.

## Built artifacts

- MQ5:
  `framework/EAs/QM5_41220_grimes-context-pb-requal8/QM5_41220_grimes-context-pb-requal8.mq5`
  - SHA-256:
    `a7dd265ed7d3a2b91bf8937451093e2285a1720b87406292e0ff4589f7ac6942`
- EX5:
  `framework/EAs/QM5_41220_grimes-context-pb-requal8/QM5_41220_grimes-context-pb-requal8.ex5`
  - SHA-256:
    `497d824a7b630d9d2cc261bb8283f31af9cb8087e20be60922a5b5e52c38c431`
- SPEC:
  `framework/EAs/QM5_41220_grimes-context-pb-requal8/SPEC.md`
  - SHA-256:
    `4b0dfc703793ac1f3b0dbad51cc5667d453dc8269c852b5a3864a0c4a140b24e`
- Backtest set:
  `framework/EAs/QM5_41220_grimes-context-pb-requal8/sets/QM5_41220_grimes-context-pb-requal8_GBPUSD.DWX_H4_backtest.set`
  - SHA-256:
    `045e25d62924212fa7e2d2ef3b29bfc9fec94b5cef7949854430390ed37b6cbf`

The build is committed on `agents/board-advisor` as
`6c023a6985461f95601503da0c45397624245585`. Only the six pair-6 build and
compile-release artifacts were included in that commit; unrelated dirty-tree
state was left untouched.

## Focused verification

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`.
- `validate_build_guardrails.py`: MQ5 and setfile `PASS`, zero findings.
- `build_gate_hardening.py`: zero failures; only the expected recovery-card
  location warnings because the approved card resides in runtime
  `cards_review`.
- MetaEditor compile: `PASS`, zero errors, zero warnings.
- EA ID literal count: one.
- Parent-global references: zero.
- `QM_IsNewBar` call count: one.
- Raw indicator calls: zero.
- ML usage: zero.
- MAE management executes before the account-level entry kill gate.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- News-calendar fail-closed ceiling is
  `qm_news_stale_max_hours=336`.

One build-scope smoke attempt requested the managed `any` terminal and was
refused before launch with resolver status `no_capacity`. Immediate slot
inspection found four running terminal processes, active tester-owned T6/T8
slots, and live terminal workers T1-T10. The smoke therefore remains
`deferred_p2_smoke`; it was not retried, no source was weakened, and no active
test was displaced. The recorded build payload retains `fail_code: smoke_failed`
together with the controller's explicit
`framework_error_during_build_smoke_treated_as_done` waiver and
`needs_p2_smoke_via_pump=true`; this does not alter the independently verified
`COMPILE_OK` result.

## Serial-chain state

- Pair 6 build task: `done`.
- Pair 6 compile work item: exactly one, `done/COMPILE_OK`.
- Pair 6 Q02 work items: zero.
- Pair 6 manifest hold: active.
- Pair 6 independent review: pending normal controller/router handling.
- Pair 7 source/EX5: absent; protected parent program untouched.
- Pair 8 source/EX5: absent.

The next authorized step is independent review. Only an approved review may
authorize the manifest's append-only Q02 seed, and only a verified seed may
precede release of pair 6's exact hold.

## Verdict

`PAIR6_BUILD_RECORDED_REVIEW_PENDING`: the manifest-bound Pair 6 EA is built,
guardrail-clean, compiled through `COMPILE_EA`, and recorded; Q02 remains
suppressed and the pair-6 hold remains active pending independent review.
