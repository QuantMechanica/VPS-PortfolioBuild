# Q13 parameter budget contract — Option M (sealed, activation OFF)

- Contract ID: `OWNER-DEC-Q13-BUDGET-CONTRACT-20260827-OPTION-M`
- OWNER authority: `OWNER-DEC-Q13-BUDGET-OPTION-M-20260827`
- OWNER receipt:
  `decisions/2026-08-27_owner_q13_budget_option_m.md`
- Receipt SHA-256:
  `f9d854c373edacd07668bad225447090f8d346aa368fb07d6606eec7cb32d929`
- Source draft: task `550db748-239c-4596-9efc-ffd50fc73224`,
  `docs/ops/evidence/550db748_q13_budget_contract_draft_2026-08-27.md`
- Source-draft SHA-256:
  `1190d4685b59da14db09f3d82217e313b42e318cfd837a795d5f9e449307ef75`
- Machine contract:
  `tools/strategy_farm/config/q13_budget_contract_option_m.v1.json`
- Machine-contract SHA-256:
  `1b38b18eac1995de63460286035c06612357ed1c18d7c1383096b27554060f1b`

## Sealed budget

Option M applies per Q13 admission and `(EA, Symbol)` lineage:

| Limit | Sealed value |
|---|---:|
| Parameters | maximum 3 |
| Candidate values per parameter | maximum 5, parent included |
| Cumulative new Q13 DSR trials | maximum +12 |
| Physical Q13 cells | maximum 114 |
| Terminal-hours per pair | maximum 13.68 |
| Terminal-hours for 25 pairs | 342 |

The physical-cell formula remains:

```text
declared_trial_increment = sum(V_i - 1)
physical_Q13_cells       = 7 * (1 + sum(V_i)) + 2
terminal_hours           = physical_Q13_cells * 7.2 / 60
```

There is no full parameter cross. One parameter is varied per cell; every
other numeric input stays at the parent value and the Q12 filter is frozen.

## Required declaration

Before any non-zero parameter run, the declaration must be hash-sealed and
bind Q11/Q12 evidence, parent build/set/include hashes, Q12 filter freeze,
2019..2025 selection years, `return_to_maxdd`, the fixed consistency rule,
and the trial ledger before/increment/after values. Every parameter must state:

- exact input name/type, parent and ordered distinct values;
- technical bounds and interaction constraints;
- pre-result mechanical hypothesis and expected effect/plateau;
- measurable refutation criterion;
- the fixed frequency check: at least 10 distinct entry-trading days per
  scored year, partial years pro rata, evaluated before performance selection.

Missing fields, source/hash drift, ledger inconsistency, or any exceeded limit
is fail-closed. Repeated admissions cannot evade the +12 limit: the declaration
must carry cumulative Q13-lineage trial increments before and after.

## Activation and no-change semantics

This document seals the budget but does not activate parameter declarations.
The separate admission flag is:

```text
QM_ENABLE_Q13_OPTION_M_DECLARATIONS
```

Its default is OFF. No pipeline call site or queue writer is added by the
sealing ticket. `parameter_count=0` remains valid and the existing
`NO_PARAMETER_CHANGE` behavior remains unchanged until a separately reviewed
activation and a genuine hash-valid declaration exist.

The validator is
`tools/strategy_farm/q13_declaration_validator.py` (implementation SHA-256 at
sealing: `88593640dbbe0754bad9a8f7a4c8a76456be37014ce5aece1bbca8670a2967fd`).
It performs offline validation only; it cannot enqueue, edit the trial ledger,
or write a Q13 verdict.

## Change rule

This contract is append-only. A higher budget, altered selection/frequency
rule, activation, or new parameter semantics require a dated successor with a
new OWNER decision. Existing Q13 rows and DL-089 are not amended by this file.
