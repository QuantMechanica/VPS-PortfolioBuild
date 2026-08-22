# MNT-022 FTMO trial arms — terminal evidence audit and no-go input

Date: 2026-08-22

Router task: `750001ab-d641-40f4-9bb6-3f1bae17eb43` (priority 73)

Branch: `agents/board-advisor`

Scope: evidence only; no purchase, live-account contact, portfolio construction,
factory action, terminal launch, or compile

## Outcome

**OWNER input: `NO_GO_INPUT`; task acceptance is not met.**

The three named checks now have written, identity-bound outcomes, but they do
not constitute a green trial package:

1. The sealed joint replay is `PASS` only for rung J0. Rung J1 is
   `SETUP_BLOCKED`, and V2 rung J2 is `INVALID` with no evidence.
2. The paired estimator is complete as a research model, but its binding
   receipt says `paid_challenge: NO_GO`, `strict_qualification: UNVERIFIED`, and
   `money_gate: SETUP_DATA_MISSING`.
3. The current governor-parity oracle is green: 34/34 tests passed.

QM5_20181 also remains in a real, identity-bound Q03 `INFRA_FAIL`. The exact
`OnInit()` branch cannot be recovered from the retained run because its tester
journal is absent. The ticket forbids the compile and terminal actions required
to create a new binary/run, and the only pending joint rows remain under an
active, non-releasing OWNER isolation hold. No untested source change or hold
release was invented to make the ticket appear complete.

This is a no-go input for the OWNER, not a go decision. Challenge purchase and
all live actions remain unauthorized.

## Arm ledger

### QM5_20181 current Q03 arm

Work item `50ada76a-321d-4749-a4ec-c3ad424bc9e6` is terminal
`done / INFRA_FAIL` with reason
`run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`.

Its row binds:

- EX5 SHA-256:
  `29505736e5abdaffeed84e44528f20f22ba2c30f633828a7f4d1bd9939176b86`
- MQ5 SHA-256:
  `952a9484c91634ae0ccf4ef28b5904784df71c41e6ca664792970a497a1d37a0`
- set SHA-256:
  `891c63fffd4b05a59c68cb760238925ba053bb99b59223e0268dbcf19f39f660`
- expert/symbol/period/window:
  `QM\\QM5_20181_ftmo-joint-multisym-timer`, `USDJPY.DWX`, `H1`,
  `2018.07.02..2025.12.31`
- evidence:
  `D:\QM\reports\work_items\50ada76a-321d-4749-a4ec-c3ad424bc9e6\QM5_20181\20260805_045921\summary.json`
- evidence SHA-256:
  `68a508468c31b6abf393a40239603c0e33bbfaf0810602369e05b7f7bdb377bb`

The current canonical MQ5, EX5, and set still hash to those same three values.
The retained run directory contains `summary.json`, `report.htm`, and
`tester.ini`, but not the referenced `raw/run_01/20260805.log`. Static input
inspection excludes the explicit backtest, fixed-risk, prop-off, stress-zero,
evidence-ID, host, and registry values as obvious mismatches. Without the
journal, the remaining `OnInit()` branches (framework initialization,
satellite history warmup, runtime account currency, V2 identity configuration,
or timer registration) cannot be distinguished honestly.

### Sealed joint replay

The immutable V2 stage-0 receipt is a real `PASS`:

- receipt:
  `D:\QM\strategy_farm\artifacts\ftmo_book3_v2_full_lifecycle_20260730_a02\runtime\fidelity_stage0_40573cd720d5_receipt.json`
- receipt SHA-256:
  `00a7fb68582d91a0efb93d711b6a413fd108a24d341f0669815a14dc0725f1a7`
- J0 work item: `407f23c8-b759-5fa8-b264-13f0e13589a6`
- standalone work item: `1e9a2b35-e92b-585f-9bf4-b8dee0a95c27`
- binary SHA-256:
  `d806f314abd1c903b8fd9d9acce0103e97cfaa054d1dc96f61e8362d08018924`
- result: 1,143 joint trades, 1,143 standalone trades, 1,143 exact matches,
  match rate `1.0`, zero unmatched, full-lifecycle actual-money basis

Stage 1 is a written `SETUP_BLOCKED` outcome, not a missing check:

- receipt:
  `D:\QM\strategy_farm\artifacts\ftmo_book3_v2_full_lifecycle_20260730_a02\runtime\fidelity_stage1_40573cd720d5_receipt.json`
- receipt SHA-256:
  `b3fa3b23f973e22925bab1a6c035bcbddefee3faf84021eec3d50c2a06e3bc43`
- error: `joint runner receipt success is not true`
- J1 runner receipt SHA-256:
  `bbe6a50c1772a4d7e27166af0d0ebf381f46a34d80e66891055739cd537fd82d`

The J1 work item `8707b075-536e-5b1f-b2a6-6bcd26f2a9a3` itself finished
`done / PASS`, but the isolated runner correctly records `success: false`.
Every runner check passed except `post_run_stream_valid`: the supposed post-run
trade stream was byte-identical to and no newer than the J0 pre-run stream, so
the coordinated trade/equity harvest aborted before publication. A work-item
PASS is therefore not promoted into a fidelity PASS.

V2 J2 work item `e98e8b96-2e92-59a2-aa8e-15f4140c1289` is
`failed / INVALID` with no evidence. Legacy J1/J2 rows
`824ca951-5d8d-58c7-adc3-c5b810c5587c` and
`a0d6400a-4f31-5855-a876-e6192e961ecd` remain pending, unclaimed, and covered
by active `FTMO_BOOK3_Q02_ISOLATED_ONLY` holds with
`release_on_restart = 0`. They were not released or mutated.

### Paired estimator

The latest sealed evaluator receipt is:

- path:
  `D:\QM\strategy_farm\artifacts\ftmo_book3_v2_full_lifecycle_20260730_a02\standalone_diagnostic_f8593cd4b\evaluation_receipt.json`
- receipt SHA-256:
  `303857750a452c538cfad41ea1026b78b717f92d949cc4abc8594c4a1ddb5b38`
- manifest SHA-256:
  `fdd26cc9d794c8420ab2f2914aa147f60dc3bdc3a7c4df8bd3c05d2ad91081ab`
- status:
  `RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED`
- input integrity and native-stream reconciliation: `PASS`
- shared-account model: `COMPLETE_RESEARCH_ONLY`
- strict qualification: `UNVERIFIED`
- money gate: `SETUP_DATA_MISSING`
- paid challenge: `NO_GO`
- deployment, factory action, money gate, and purchase authorization: all
  `false`

The descriptive research model used three independently bound standalone arms
at fixed risk USD 1,000 each. Its in-sample-only block bootstrap ran 25,000
paths. Under the internal-policy end-of-day surrogate it reports 44.896% two-
phase completion and 33.456% any official breach. Those estimates are expressly
not gate-eligible: the temporal slice was not selection-sealed, M15 plus Q08 MAE
is not event-complete, and the internal simultaneous-risk/governor behavior is
not proven.

A current-checkout rerun was attempted with the sealed manifest and a new
canonical output path. The evaluator refused before creating output with
`manifest:staging_snapshot_already_exists`. This preserves the create-only
seal; recreating or editing the manifest would produce a different evidence
identity and was not done.

### Slot-2 evidence: QM5_13108 versus QM5_13301

The two Q08 outcomes are independently bound and support only an evidence
preference, not an authorized swap:

| Candidate | Q08 work item | EX5 SHA-256 | Aggregate SHA-256 | Real result |
|---|---|---|---|---|
| QM5_13108 / XTIUSD.DWX | `37894f9c-0a12-4e40-ac36-ba1fc8e56b88` | `325759dd17cb3ac77ed771f67cef1b5026b7fd943a57e69c38f3872b2cc6e9b4` | `d14c037354450f296679e991a81b71af942a1dcfac1594641701812b4a4cc830` | `FAIL_SOFT`, 548 trades; PBO and three other sub-gates `EDGE_SOFT` |
| QM5_13301 / GDAXI.DWX | `a3538dc4-e7bc-4285-ba2b-6d0858cb3f60` | `64d71b745fade2134967cd1373b39a359f22cadc94933ba8f71c177ff44edc87` | `f84453bcb9fac3474f11324f57381e92894b9063aa736adda6ac2676b9fdc17c` | `PASS`, 551 trades; PBO `PASS` |

Both rows record dispatch-time verification and an exact match between the
frozen and staged EX5 hashes. On this evidence, QM5_13301 is the stronger
alternative for a future, separately authorized qualification exercise.
Nothing here selects it into a book or changes a portfolio registry.

### Governor parity

Current-checkout verification:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_governor_parity_oracle.py -q
34 passed in 1.30s
```

The broader static/replay/evaluator regression selection also passed:

```text
python -m pytest \
  tools/strategy_farm/tests/test_qm5_20181_ftmo_evidence_v2_static.py \
  tools/strategy_farm/tests/test_qm5_20181_13108_parity_static.py \
  tools/strategy_farm/tests/test_qm5_20181_10145_parity_static.py \
  tools/strategy_farm/tests/test_compare_joint_replay.py \
  tools/strategy_farm/tests/test_ftmo_book3_standalone_evaluator.py \
  tools/strategy_farm/tests/test_ftmo_governor_parity_oracle.py -q
156 passed in 32.16s
```

These are code-contract checks, not pipeline verdicts.

## Structural money-evidence gap

`docs/ops/evidence/2026-07-29_ftmo_book3_v2_producer_setup_block.md`
records that QM5_20181 deliberately emits `coverage_complete: false` because
host-tick plus one-second timer observations cannot prove non-host subsecond
equity minima. The required external event-complete replay producer is still a
remaining implementation. The estimator therefore correctly hard-codes all
money/deployment/factory authorizations false and reports
`event_complete_joint_equity_trace_missing`.

That gap cannot be repaired by relabelling timer data, weakening the adapter,
or treating the favourable research estimates as money evidence.

## Acceptance assessment and next authority

The ticket's required end state is not present:

- Q03 is identity-bound but remains `INFRA_FAIL`.
- sealed replay is green only at J0, setup-blocked at J1, and absent at J2.
- paired estimation is complete only as a non-gate research model and returns
  `NO_GO`.
- governor parity is green.
- QM5_13301 is the stronger measured alternative to QM5_13108, but no
  selection or book construction is authorized.

The next executable engineering step needs a separate authority that permits a
new immutable compile/run vintage and isolated terminal execution while
preserving the OWNER holds. It should first add branch-identifying `OnInit()`
diagnostics, prove the new binary, rerun the J1/J2 ladder with fresh atomic
streams, and then build/validate the external event-complete replay producer.
Until that evidence exists, the honest OWNER input remains **NO-GO**.

## Safety record

- no factory state or scheduled task changed;
- no terminal or MetaEditor process started;
- no EA compiled or deployed;
- no hold or work-item state changed;
- no live scope, AutoTrading, or challenge account touched;
- no portfolio registry or book membership changed.
