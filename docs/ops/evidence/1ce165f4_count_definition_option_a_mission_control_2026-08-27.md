# Mission Control — OWNER Option A count definition sealed

- Router task: `1ce165f4-e13b-41f7-9730-e21ea9a612a4`
- Date: 2026-08-27
- Scope: read-only Mission Control / Weg-zu-25 telemetry
- Authority: `decisions/2026-08-27_owner_count_definition_option_a.md`
- Authority SHA-256:
  `d47501ca1f633d49ea2f7213bb107e1cc508a0e0b4b1901af321ec8fbd00fcd2`

## Outcome

Mission Control no longer describes the count as provisional. The sole trigger
definition is now `STRICT_V4_CONTIGUOUS_Q14`: an `(EA, symbol)` pair counts only
when `highest_contiguous_valid_gate=Q14` under canonical v4 evidence. The code
authenticates the exact OWNER decision file before producing the count.

The shared `counting_definition.trigger.count` is the single source for:

- the Mission Control `qualified_pairs` main counter;
- `eta_to_25.qualified_pairs`;
- `eta_to_25.remaining_pairs`; and
- the phase-median capacity diagnostic's already-qualified input.

An explicit invariant aborts rendering if the trigger count diverges from the
contiguous qualified pool. The prior B/C/D alternatives remain visible only as
`diagnostics`, each with `is_trigger=false`; Mission Control labels the whole row
`Sekundärdiagnostik · KEIN Trigger` and each chip `kein Trigger`.

## Live read-only result

The production SQLite model was opened through `mode=ro` with
`PRAGMA query_only=ON`. The observed values were:

| Field | Value |
|---|---:|
| Sealed Option-A trigger count | **0 / 25** |
| Remaining pairs | **25** |
| ETA-to-25 | **58.28 days** |
| Trailing-7d raw Q14 rate | **0.429 pairs/day** |
| Q14 sample | **3** (`LOW`) |
| B — `V4_TERMINAL_ROW_ONLY` (non-trigger diagnostic) | 3 |
| C — `CONTRACT_EQUIVALENT_TERMINAL` (non-trigger diagnostic) | 3 |
| D — `HISTORICAL_Q14_LABEL_INCLUSIVE` (non-trigger diagnostic) | 10 |

The ETA rate may include NO_CHANGE pilots, but those observations affect only
the throughput estimate. They cannot change the sealed numerator or trigger.

## Continuity fixture

The added fixture contains four deliberately different lineages:

1. a complete v4 Q02→Q14 pair — counts;
2. a v4 pair with a Q06 hole but a terminal Q14 row — does not count;
3. a Q12/Q13 NO_CHANGE pilot shape with terminal Q14 — does not count; and
4. a historical v3 row labelled Q14 — does not count.

The fixture proves one trigger pair, 24 remaining, B/C counts of three raw v4
terminal rows, and D count of four historical-label-inclusive rows. Every B/C/D
record is asserted non-trigger. The existing fixture also hashes its SQLite file
before and after model evaluation and proves byte identity.

## Verification

```text
python -m py_compile \
  tools/strategy_farm/path_to_25.py \
  tools/strategy_farm/render_cockpit_v2.py \
  tools/strategy_farm/mission_control_v2_data.py

python -m pytest -q \
  tools/strategy_farm/tests/test_path_to_25_metrics.py \
  tools/strategy_farm/tests/test_render_cockpit_v2.py \
  tools/strategy_farm/tests/test_mission_control_v2_data.py
```

Result: **26 passed, 1 skipped in 3.15s**. `git diff --check` passed for the
explicit task paths. Render assertions prove `Zählung VERSIEGELT`, the decision
reference, `Sekundärdiagnostik · KEIN Trigger`, and the absence of the former
`Zählung PROVISORISCH` label.

No queue, work item, verdict, terminal, T_Live, AutoTrading, or pipeline state
was modified.

## Verdict

`SEALED_OPTION_A_READ_ONLY_PASS` — one OWNER-bound trigger count drives the
main Weg-zu-25 counter and ETA; alternative counts are visibly non-trigger
diagnostics; continuity and render fixtures pass.
