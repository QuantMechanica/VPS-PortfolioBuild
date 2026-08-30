# Q09 eight-pair requalification precondition review

Date: 2026-08-30

Router task: `f5db48cc-d11e-476e-8470-b5f0caebab65`

OWNER decision: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829` (`YES`)

## Outcome

`REVIEW_REQUIRED_PRECONDITIONS`. No requalification row was enqueued and no
hold, verdict, evidence, registry, source, setfile, compile row, or optimization
cell was changed.

The authorized objective is clear, but its executable manifest is incomplete:

1. The sealed analysis `08f928e7` records the eight qualitative blockers and
   says to rebuild/requalify, repair/new-candidate, or requalify from the last
   valid gate. It does **not** identify the exact last-authentic work-item ID for
   any of the eight pairs.
2. The router task requires E1/E2-v6 new identity from Q02 where source/setfile
   lineage broke, but neither the decision, payload, nor sealed analysis states
   which exact pairs cross that boundary.
3. No replacement EA IDs or magic rows are allocated in the task. The recovery
   card directory contains only three unrelated cards (`QM5_1650` twice and
   `QM5_11456`); none maps to the eight pairs.
4. Choosing an anchor, classifying same-identity versus new-identity, or
   inventing a replacement ID would be a pipeline/identity decision, not an
   implementation detail. Partial seeding would also violate the acceptance
   requirement of exactly eight chains and eight decision-bound hold releases.

## Exact live scope verified

All eight named holds remain active under the exact
`Q09_AWAITING_SEALED_PLAN` code:

| Hold | Pair | State |
|---|---|---|
| `aa80274f-fb46-4432-b47e-6fb2bf28c9a2` | QM5_13128 / NDX.DWX | pending, active hold |
| `1cff016c-d25c-4723-a892-6bc53bfafa0b` | QM5_12989 / XAUUSD.DWX | pending, active hold |
| `57d8bacd-2805-45a6-ac51-156e22bb3a65` | QM5_10815 / GDAXI.DWX | pending, active hold |
| `2604a1f0-4f58-4597-89ef-432af9093131` | QM5_1567 / EURUSD.DWX | pending, active hold |
| `7bbeef66-becf-4bd3-aa5c-1d00bde262d8` | QM5_12567 / XAUUSD.DWX | pending, active hold |
| `9639a773-b913-40a2-b12f-128a027aec98` | QM5_10939 / GBPUSD.DWX | pending, active hold |
| `30584122-b7b3-41eb-8e1a-b03517554d4d` | QM5_11421 / EURUSD.DWX | pending, active hold |
| `08fe4173-07d9-47e1-97e9-a76b1159ad94` | QM5_11476 / USDJPY.DWX | pending, active hold |

The canonical sealed analysis describes them as follows:

| Pair | Sealed blocker/disposition text |
|---|---|
| QM5_13128 / NDX | current source/closure differs from Q08 vintage; full rebuild/requalification |
| QM5_12989 / XAUUSD | current setfile/source differs from Q08 vintage; full rebuild/requalification |
| QM5_10815 / GDAXI | bound historical Q08 evidence file missing; rebuild/requalification |
| QM5_1567 / EURUSD | current-identity chain incomplete; full rebuild/requalification |
| QM5_12567 / XAUUSD | recovery Q08 invalid perturbation neighborhood; repair/new candidate |
| QM5_10939 / GBPUSD | recovery Q08 degenerate baseline; repair/new candidate |
| QM5_11421 / EURUSD | recovery Q08 invalid/infra outcome; repair/new candidate |
| QM5_11476 / USDJPY | no authentic Q07 predecessor; requalify from last valid gate or retire |

Those phrases leave multiple mechanically different, valid-looking actions
(same-identity append-only rerun, new-identity Q02 restart, or new candidate).
The task explicitly forbids this agent from making that classification.

## Capacity and protected-program observations

- The live `COMPILE_EA` queue contained 37 pending rows at preflight. Any new
  binary must still use that queue; no direct compile is authorized.
- The protected `QM5_41162` EUR `OPT_CENSUS` program has one active cell and a
  large pending matrix. No row in that program, its parent QM5_11421 lineage,
  or its measurement evidence was touched.
- The eight holds remain fail-closed; none was released merely because OWNER
  approved a future requalification track.

## Bound evidence

| Artifact | SHA-256 |
|---|---|
| `docs/ops/evidence/2026-08-29_q09_aged_sealed_plan_hold_recovery.md` | `02c20a773191077bea0fedde4b80f07f2767f122d29389f99eaa57d387dac0c5` |
| `tools/strategy_farm/config/owner_decision_execution.v1.json` | `d1a2b045437b8017523ce7e8e1cdd3c76fbea0ec43b618a996ebeb22d73af4e0` |
| `framework/registry/ea_id_registry.csv` | `ce79ff95924f23a13d07d1570757ea8175417e5195ac103bb0e851ce2d07fa5c` |
| `framework/registry/magic_numbers.csv` | `332d236e7f7e587cb84da6d06e6d28533b859e86dbe6a42e094b62650ba56154` |

## Required executable manifest

Before this task can be applied, publish one decision-bound table with exactly
eight rows and these fields:

- full held work-item ID;
- full last-authentic anchor work-item ID and gate;
- action: `SAME_IDENTITY_APPEND_ONLY` or `NEW_IDENTITY_FROM_Q02`;
- for new identity: already-reserved EA ID, slug, exact active magic row, and
  recovery-card/source path;
- expected current MQ5/EX5/setfile/include-closure hashes;
- the exact successor phase and canonical enqueue command contract;
- decision-bound hold release note.

That manifest must also state that the QM5_11421 requalification cannot mutate,
supersede, cancel, reprioritize, or reuse any QM5_41162 `OPT_CENSUS` row.

Verdict: `REVIEW_REQUIRED_PRECONDITIONS`; eight holds retained, zero chains
invented, and protected optimization work unchanged.
