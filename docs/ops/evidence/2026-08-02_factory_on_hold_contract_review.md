# Generation-aware restart-hold release contract — Codex review

Date: 2026-08-02
Reviewer / implementer: Codex (Sol)
Design author: Claude (R1)
Agreement: **96%**

## Review outcome

The generation-aware design is materially correct and is safer than retaining either the seven-ID source constants or the v1 consumption-table constraint. The OWNER preparation decision is the appropriate single source for the release plan; the runtime decision must carry that plan without operator input; exact equality at the preparation, runtime, lock, and transaction boundaries closes plan-substitution paths. An empty plan should still consume the one-time nonce after proving the active `release_on_restart` set is empty.

Because agreement is at least 90%, implementation is authorized under the brief's protocol, subject to the findings below. This review was completed before implementation edits.

## Adversarial findings incorporated into implementation

1. **Generation repin requires generation-bound identity and preparation-worker metadata updates.** The current maintenance validator still expects decision ID `FACTORY_PREPARATION_20260730_REPAIR_NO_WAIVER`, status `APPROVED_WITH_EXPLICIT_BOUNDARIES`, a nine-terminal preparation cohort, and `t5_quarantine_ratified=true`. Factory_ON carries equivalent preparation-policy checks. Merely changing path/SHA/commit/blob would therefore hard-block the new decision. Implementation will repin those identity values and validate the new decision's exact ten-terminal preparation metadata (`t5_quarantine_ratified=false`, `t5_quarantine_lifted=true`) while leaving the already-authorized exact T1–T10 runtime worker-cohort policy and its enforcement flow unchanged.

2. **Count validation must reject booleans and coercible non-integers.** In Python, `False == 0`; a count-equality-only test would accept a JSON boolean for an empty plan. Structural validators will require an actual integer (not `bool`), non-negative by construction, before comparing it with the plan length. PowerShell will likewise validate the decoded count's integer type rather than silently accepting a coercible string.

3. **Cross-version nonce uniqueness needs an explicit in-transaction lookup.** Separate primary keys cannot enforce uniqueness across v1 and v2. Under the existing `BEGIN IMMEDIATE`, implementation will query only the two literal allowlisted table names, reject a nonce found in either, and then insert into v2. v1 receives no DDL or DML and remains the immutable historical audit table.

4. **The committed 2026-07-31 runtime artifact is intentionally obsolete under the renamed authorization contract.** It contains `release_seven_restart_holds`; after the exact-key rename it must fail closed before it can be reused. The regression test that currently expects only time-window expiry will be updated to assert rejection of this legacy authorization shape; the historical artifact itself will not be edited or replaced.

5. **Empty-array transport needs both typed construction and serialized-shape verification.** A `[string[]]` value will be used in the Factory_ON lock record, and the generated JSON will be parsed back and checked. The zero-length case will additionally require the literal JSON array shape for `restart_hold_ids`, preventing `null`/string scalar representations from reaching Python.

No design issue requires changing OFF-wins precedence, mutation-lock authentication, health-before-release ordering, CAS/ledger semantics, T_Live/FTMO isolation, runtime-decision minting policy, or the exact ten-worker runtime cohort.

## Pinned 2026-08-02 preparation decision

- Relative path: `docs/ops/evidence/2026-08-02_factory_preparation_owner_decision.json`
- SHA-256: `c3c7fc0907ae2963d48cf778900023e99875b3130a81f741ba591c21f9ef3fb3`
- Git commit: `8f8b77b06fed799322536fd60c32f259843b8c69`
- Git blob: `ab804df2de1a4662bd7439ac3094ee7c5dcb6494`
- Canonical 21-task-map SHA-256 (recomputed): `ccfb16110aa5722fdbc72bec361c180a485ae14afe2f3c1c99a9949301e0297f`

## Implementation and verification evidence

Implemented the generation-aware contract across the runtime validator, decision builder, schema/template, maintenance transaction, Factory_ON lock/release checks, and the four required test files.

Key implemented properties:

- The preparation decision is the only source of restart-hold IDs; production code contains no seven-ID plan constant.
- Preparation and runtime plans receive strict list/string/UUID-shape/uniqueness/count validation and exact ordered equality checks at the transport boundaries.
- An empty plan proves that no active `release_on_restart` rows exist, inserts a v2 consumption record with `released_hold_count=0`, and consumes the nonce.
- `factory_runtime_activation_consumptions` (v1) receives no DDL or DML. New records use `factory_runtime_activation_consumptions_v2`, whose count floor is `CHECK(released_hold_count>=0)` and whose UPDATE/DELETE triggers are append-only.
- Nonce reuse is rejected across the literal v1/v2 table allowlist under the existing `BEGIN IMMEDIATE` transaction.
- Factory_ON constructs the lock plan as `[string[]]`, verifies a JSON round trip, and explicitly rejects a zero-length serialization other than `"restart_hold_ids":[]`.
- OFF-wins checks, mutation-lock authentication, health-before-release ordering, per-row CAS, transition-ledger keys, rollback/lock retention, T_Live/FTMO isolation, and the exact T1–T10 runtime cohort remain intact.

### Python compilation

Command:

```text
python -m py_compile tools/strategy_farm/factory_runtime_activation.py tools/strategy_farm/build_runtime_activation_decision.py tools/strategy_farm/maintenance_control.py tools/strategy_farm/tests/test_maintenance_control.py tools/strategy_farm/tests/test_factory_runtime_activation.py tools/strategy_farm/tests/test_build_runtime_activation_decision.py tools/strategy_farm/tests/test_factory_restart_post_start_health.py
```

Exit code: `0` (no stdout or stderr).

### Required full test run

Command:

```text
python -m pytest -q tools/strategy_farm/tests/test_maintenance_control.py tools/strategy_farm/tests/test_factory_runtime_activation.py tools/strategy_farm/tests/test_build_runtime_activation_decision.py tools/strategy_farm/tests/test_factory_restart_post_start_health.py
```

Full output, verbatim:

```text
........................................................................ [ 94%]
....                                                                     [100%]
76 passed in 35.92s
```

No Factory_ON run, runtime-decision minting, production/farm database write, terminal/process start, scheduled-task mutation, T_Live contact, or Factory_ON/OFF state mutation was performed. SQLite mutation tests used pytest-local temporary databases only.

## Deviations from the brief

The contract design was implemented as specified. The two integration adjustments identified during adversarial review were also incorporated: generation-bound OWNER identity/preparation-worker metadata was updated so the new pinned decision can pass without weakening the exact T1–T10 runtime cohort, and the historical 2026-07-31 runtime artifact regression now asserts rejection of its obsolete authorization key rather than reaching only its expiry check. Strict boolean-count rejection was added to close Python's `False == 0` edge.
