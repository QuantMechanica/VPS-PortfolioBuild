# Q13 Option M contract + declaration validator evidence

- Router task: `29e50617-d2fe-471b-a011-a11a60a1af1e`
- OWNER decision:
  `decisions/2026-08-27_owner_q13_budget_option_m.md`
- Decision SHA-256:
  `f9d854c373edacd07668bad225447090f8d346aa368fb07d6606eec7cb32d929`
- Sealed human contract:
  `decisions/2026-08-27_q13_budget_contract_option_m_sealed.md`
- Sealed machine contract:
  `tools/strategy_farm/config/q13_budget_contract_option_m.v1.json`
- Machine-contract SHA-256:
  `1b38b18eac1995de63460286035c06612357ed1c18d7c1383096b27554060f1b`
- Executed in canonical checkout `C:/QM/repo` on `agents/board-advisor`.

## Outcome

The OWNER-selected Option M values are encoded exactly: at most 3 parameters,
at most 5 values per parameter including the parent, at most +12 cumulative
new Q13 trials, 114 physical cells, and 13.68 terminal-hours per pair.

`q13_declaration_validator.py` authenticates the byte-pinned machine contract,
the OWNER receipt, the `550db748` source draft, and DL-088 before examining a
declaration. It then fails closed on:

- missing GELB fields (parameter count, hypothesis, refutation criterion, or
  frequency check), missing bindings/hashes, or hash drift;
- more than 3 parameters or 5 values, missing parent controls, duplicate or
  non-numeric candidates, or values outside declared technical bounds;
- a declared trial increment, physical cell count, or terminal-hours value that
  differs from the sealed formula;
- broken before/increment/after trial-ledger arithmetic or a cumulative
  Q13-lineage increment above +12;
- drift from the frozen years, objective, frequency, consistency, Q12-filter,
  or one-parameter-per-cell rules.

For the maximum valid test declaration the validator reports:

| Field | Before | Increment | After/effective |
|---|---:|---:|---:|
| Declared trial ledger | 154 | +12 | 166 |
| Q13-lineage trial increment | 0 | +12 | 12 |
| Physical cells | — | 114 | 114 |
| Terminal-hours/pair | — | 13.68 | 13.68 |

This explicitly exposes ledger growth; no silent trial inflation is possible
through a second admission because the lineage after-value may not exceed 12.

## Flag and operational scope

`QM_ENABLE_Q13_OPTION_M_DECLARATIONS` defaults OFF. Offline structural
validation can report a valid declaration, but `admission_decision()` rejects
it as `Q13_DECLARATIONS_DISABLED` unless the flag is explicitly enabled. No
pipeline caller, queue integration, declaration, work-item mutation, or
parameter cell was created in this ticket. Existing Q13 rows and the current
`parameter_count=0` / `NO_PARAMETER_CHANGE` behavior are untouched. DL-089 was
not edited.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_q13_declaration_validator.py -q
.............. [100%]
14 passed in 0.81s

python -m pytest tools/strategy_farm/tests/test_optimization_fork_service.py \
  tools/strategy_farm/tests/test_optimization_fork_driver.py -q
........... [100%]
11 passed in 3.78s

python -m py_compile tools/strategy_farm/q13_declaration_validator.py
PASS
```

The test matrix covers exact maximum-budget acceptance, zero-parameter
no-change acceptance, default-OFF admission, explicit-flag admission,
incomplete GELB declarations, over-budget parameters/values/lineage,
ledger mismatch, declaration-hash drift, and machine-contract byte drift.

## Activation checklist (not executed)

1. [x] OWNER Option M receipt and source draft byte-pinned.
2. [x] Human and machine contracts added append-only; no existing contract
   rewritten.
3. [x] Offline fail-closed validator and focused/regression tests pass.
4. [x] Admission flag default OFF; no operational call site added.
5. [ ] Orchestrator reviews the declaration schema and evidence.
6. [ ] A first genuine parameter declaration is authored separately and
   validated against real Q11/Q12/build/set/include hashes.
7. [ ] Any activation or enqueue integration receives separate review; it must
   preserve the sealed +12 lineage cap and append-only ledger.

## Verdict

**CONTRACT_AND_VALIDATOR_READY_FOR_REVIEW; FLAG_OFF; NO_Q13_DECLARATION.**
