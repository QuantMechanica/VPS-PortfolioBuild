# OPT-5 Q15 Challenger Freeze Validator — Codex Build Evidence

Date: 2026-08-13 (Europe/Berlin)  
Router task: `d82f62db-5c3c-4b75-88b2-607ba918e066`  
Branch: `agents/board-advisor`  
Implementation commit: `413366091`  
Review state requested: REVIEW (builder evidence only; no pipeline verdict)

## Decision scope

The implementation follows DL-084 and
`docs/ops/FACTORY_ADAPTATION_OPTIMIZATION_TRACK_2026-08-12.md`: Q15 is a
development/freeze sidecar after Q14, creates a new EA identity, and seeds the
challenger's unchanged standard Q02 chain. It does not execute MT5 or infer any
Q02+ result.

The active Q14 store was audited read-only on 2026-08-13. All 11 opt-cards use
exactly one numeric parameter and `MAXIMIZE`; the cohort comprises six
`EXIT_SURGERY` and five `VOL_REGIME_FILTER` cards. This matches the validator's
deliberately narrow wave-1 contract (`framework/scripts/q15_freeze_check.py:378-398`).

## Durable implementation

- `framework/scripts/q15_freeze_check.py`
  - source declaration/default/read checks close the dead-input class at
    `:207-235`;
  - EA-ID, slug, active magic rows, magic formula, and full generated-resolver
    equality are checked at `:267-362`;
  - complete declared DEV trials and the independently derived 5% adjacent
    plateau are checked at `:441-558`;
  - parent/challenger bindings, fixed-risk control-OFF set, and byte-identical
    non-empty trade-behavior traces are checked at `:563-647`;
  - the deterministic, read-only plan (parent hashes, Q02 set freeze, Q14 binding,
    addendum, closed ledger, Q15/Q02 IDs and payloads) is built at `:711-919`;
  - canonical-checkout and `FACTORY_OFF.flag` apply guards are at `:968-975`;
  - apply appends the immutable addendum, closed ledger, done Q15 row,
    authenticated Q14 dependency, and one pending Q02 row without dispatch at
    `:1017-1138`.
- `tools/strategy_farm/q09_news_schema.py`
  - schema version 5 admits only the new `Q14_ADMISSION` vocabulary alongside the
    existing roles (`:42`, `:189-203`);
  - the insert trigger requires Q15 `CHALLENGER_SPAWNED` → Q14 `OPT_ELIGIBLE` with
    the same symbol (`:517-523`);
  - the role-check migration copies historical dependency rows byte-for-byte
    (`:766-805`).
- Formal JSON contracts:
  - `tools/strategy_farm/config/opt_card_freeze.v1.schema.json`;
  - `tools/strategy_farm/config/opt_dev_sweep.v1.schema.json`;
  - `tools/strategy_farm/config/q15_default_off_equivalence.v1.schema.json`.
- Builder/operator SOP:
  `docs/ops/Q15_CHALLENGER_BUILD_SOP_2026-08-12.md` defines the router payload
  (`:21`), serial build procedure (`:68`), equivalence artifact (`:99`), DEV
  plateau contract (`:116`), dry-run/apply ceremony (`:138`), and REVIEW-only
  handoff (`:181`).

## Verification evidence

Focused regression command:

```text
python -m pytest \
  tools/strategy_farm/tests/test_q15_freeze_check.py \
  tools/strategy_farm/tests/test_q09_news_schema_v2.py \
  tools/strategy_farm/tests/test_q14_opt_admission.py \
  tools/strategy_farm/tests/test_q16_head_to_head.py \
  tools/strategy_farm/tests/test_optimization_track_manifest_v2.py -q
```

Result: `36 passed in 7.83s`.

The Q15 suite proves deterministic read-only dry run (`test_q15_freeze_check.py:241`),
idempotent apply plus closed ledger/Q14 dependency/single Q02 seed (`:255`), and the
required fail-closed cases:

- parent hash mismatch (`:284`);
- declared-but-unread lever parameter (`:291`);
- missing DEV sweep evidence (`:304`);
- selected value below the adjacent 5% plateau (`:311`);
- wrong backtest risk mode (`:321`);
- missing/noninteractive user-profile paths (`:331`).

All three JSON schema files passed `python -m json.tool`. `git diff --check` passed.
The optional Ruff command was unavailable in this environment (`No module named
ruff`); no Ruff result is claimed.

One read-only production-shape probe ran `_validate_identity` against
`QM5_20288_wti-volnorm-mom` and the full canonical 15,911-row magic resolver. It
returned `QM5_20288`, slug `wti-volnorm-mom`, one active XTIUSD magic row, and
resolver artifact SHA-256
`5f6527c63c0afd1a851c81ab9ac6a0ee60140b43124048f35154c4d1bd8a3996`.
This verifies the fixture-tested resolver parser against the actual generated array
shape.

## Mutation and safety record

- No Q15 `--apply` was run against the live farm; apply behavior was exercised only
  against hermetic temporary SQLite/filesystem fixtures.
- The live farm database and active opt-card directory were read only.
- No terminal was launched, stopped, reserved, or interrupted; no dispatch tick was
  issued.
- T_Live, FTMO, AutoTrading, deploy manifests, live setfiles, and news-calendar
  guards were untouched.
- No live or test risk contract was weakened. Q15 requires
  `RISK_FIXED=1000` and `RISK_PERCENT=0` for parent, control-OFF, and challenger Q02
  sets.
- Concurrent canonical-checkout files and the pre-existing untracked review evidence
  were excluded from commit `413366091` via explicit pathspecs.

## Review verdict proposed

`READY_FOR_CODE_REVIEW: Q15 freeze contract implemented and focused regressions PASS; no live challenger was spawned by this build task.`
