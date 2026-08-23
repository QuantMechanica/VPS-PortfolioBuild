# Factory Lifecycle Gate-Contract Binding (2026-08-23)

**Ticket:** `rb-factory-contract-bind` · **Branch:** `rb-factory-contract-bind`
**Author:** Claude (fork) · **Scope:** additive gate-contract provenance on the factory
runtime-activation path. No gate thresholds, verdicts, DB, or T_Live touched (ROT).

## Objective

Make the factory lifecycle scripts record which gate contract they run under. The
runtime-activation decision that gates `Factory_ON` now binds the active default gate
manifest (schema version, repo-relative path, sha256, activation state), the validator
fail-closes on a sha mismatch (older decisions grandfathered), and both `Factory_ON` /
`Factory_OFF` echo the contract line at their start windows.

Active contract at implementation time:
`tools/strategy_farm/config/gate_manifest.v3.json` — `schema=qm.gate-manifest/v3`,
`sha256=988f9dea709bb71de5d7b6bce3c02ea02417cd63f447767853281c8f5f8fc6ce`, `state=ACTIVE`.

## What changed

### 1. `tools/strategy_farm/build_runtime_activation_decision.py` (additive)
- `import gate_manifest` (`:26`).
- `_gate_contract_binding()` (`:236`) loads the active default manifest and returns
  `{schema_version, manifest_path, sha256, activation_state}`, with `manifest_path`
  computed repo-relative (`tools/strategy_farm/config/gate_manifest.v3.json`) from the
  module location so it is stable under any repo root. Fail-closed: a load/relative-path
  failure raises a classified `DecisionBuildError` (PRECONDITION exit).
- The block is written into the decision payload at `:466`
  (`payload["gate_contract"] = _gate_contract_binding()`). All pre-existing payload fields
  are unchanged; only a new top-level key is appended, so the sidecar (a sha256 over the
  full decision bytes) simply covers the new block.
- The builder summary now reports `gate_contract_sha256` / `gate_contract_schema_version`
  (`:525`-`:526`).

### 2. `tools/strategy_farm/factory_runtime_activation.py` (fail-closed validation)
- `GATE_CONTRACT_KEYS` (`:32`); `import logging` + module logger.
- Top-level exact-key check made additive: `gate_contract` is permitted only when present
  (`:396`), so grandfathered decisions still pass and a present block must be exact.
- `_load_default_gate_manifest()` (`:284`) lazily imports `gate_manifest` and fail-closes
  (`RuntimeActivationError`) on any loader failure.
- `_validate_gate_contract()` (`:303`): missing block -> `logger.warning(...)` and pass
  (grandfathered); present block -> exact key set, valid sha256 shape, and its sha256 /
  schema_version / activation_state must equal the active default manifest, else
  `RuntimeActivationError` (refuse activation).
- Called at `:563`; surfaced in the validator result as `gate_contract` (`:582`).

### 3. `tools/strategy_farm/factory_runtime_activation.v1.schema.json`
- Added an optional `gate_contract` `$def`/property (not in `required`), keeping
  `additionalProperties:false` valid for both grandfathered and bound decisions.

### 4. `tools/strategy_farm/Factory_ON.ps1` (fail-closed preflight)
- `Write-GateContractLine` (`:477`) runs `python -c` against `gate_manifest`, extracts one
  framed `QM_GATE_CONTRACT_V1:` record, and echoes
  `GATE_CONTRACT schema=<v> sha256=<...> state=<ACTIVE>`. Same fail-closed pattern as the
  other python preflights (`EAP=Continue` for PS5.1, exit-code/record-count/JSON checks,
  `throw` on failure). Invoked in the read-only preflight block (`:1271`).

### 5. `tools/strategy_farm/Factory_OFF.ps1` (informational, never blocking)
- At the OFF banner / drain start (`:694`), the same `GATE_CONTRACT` line is echoed inside
  a `try/catch`; any failure prints `GATE_CONTRACT unavailable (informational; OFF
  continues)` and the drain proceeds.

### 6. Tests
- `tools/strategy_farm/tests/test_build_runtime_activation_decision.py`:
  `test_builder_binds_active_gate_contract_into_payload` — payload contains an exact
  `gate_contract` block matching the active manifest, flows through candidate + published
  self-verification, and the sidecar binds the full bytes.
- `tools/strategy_farm/tests/test_factory_runtime_activation.py`:
  `test_missing_gate_contract_block_is_grandfathered_with_warning` (missing block passes +
  warns), `test_matching_gate_contract_block_passes_and_is_reported`,
  `test_gate_contract_sha_mismatch_refuses_activation` (mismatch refuses),
  `test_gate_contract_block_rejects_extra_key`.

## Test output

`C:/Python311/python.exe -m pytest test_build_runtime_activation_decision.py
test_factory_runtime_activation.py test_gate_manifest.py -q`:

```
48 passed, 1 skipped in 59.34s
```

(The single skip is a pre-existing conditional skip in the suite, unrelated to this
change.) Both PowerShell scripts parse clean via
`[System.Management.Automation.Language.Parser]::ParseFile` (0 errors).

## Risks / notes

- Additive-only: existing decision fields are byte-unchanged; only a new top-level key is
  appended. Any runtime-activation decision minted before this change is grandfathered
  (validator warns, does not refuse).
- The `Factory_ON` echo is a genuine fail-closed preflight: if `gate_manifest` cannot be
  read, ON aborts before mutation. `Factory_OFF` is informational and never blocks a drain.
- No gate topology, thresholds, verdicts, DB, or T_Live were touched. The manifest content
  itself is unchanged; this only records its identity onto the activation path.

## Rollback

`git revert` of the single ticket commit restores the prior byte-for-byte behavior
(builder omits `gate_contract`, validator has no gate-contract branch, both scripts drop
the echo). No data migration is required because the field is additive and older decisions
are already treated as valid.
