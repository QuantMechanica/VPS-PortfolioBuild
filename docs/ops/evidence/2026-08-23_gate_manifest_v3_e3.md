# OPS-GATE-MANIFEST-V3-E3 — implementation evidence

Date: 2026-08-23

Task: `d5c13a08-b93d-48b0-8b07-50661d1db6ed` (priority 90)

Authority: OWNER E3 in `decisions/2026-08-22_owner_pipeline_realignment_q09_q11.md`

Disposition: **REVIEW — candidate is intentionally read-inert**

## Outcome

Gate Manifest v3, its closed Draft 2020-12 schema, shared display plumbing, and
explicit Q09 FTMO suitability projection are implemented in the canonical checkout.
The active default remains `gate_manifest.v2.json`; no runtime gate was activated.

The design and Vault mirror proposal, including the gate-by-gate diff and dependency
graph, is `docs/ops/GATE_MANIFEST_V3_PROPOSAL_2026-08-22.md`.

## Q10A adjudication

Source inspection of `framework/scripts/q08_davey/aggregate.py` established that Q08
can emit a fresh full-history baseline with report/summary plus EX5, MQ5, setfile, and
stream hashes. It also established that historical/stream-first paths can lack the
complete `baseline_run` binding. The v3 contract therefore does **conditional reuse**:

- `REUSE_ONLY_HASH_BOUND_FULL_HISTORY_Q08_BASELINE`;
- otherwise `REQUIRE_Q10A_BASELINE_RUN`.

Q10A is display-only evidence metadata and is rejected by the writable phase validator.

## Files in scope

- `tools/strategy_farm/config/gate_manifest.v3.json`
- `tools/strategy_farm/schemas/gate_manifest.v3.schema.json`
- `tools/strategy_farm/gate_manifest.py`
- `tools/strategy_farm/phase_ids.py`
- `tools/strategy_farm/q09_ftmo_recommendation.py`
- `tools/strategy_farm/render_cockpit.py`
- `tools/strategy_farm/mission_control_v2_data.py`
- `tools/strategy_farm/render_cockpit_v2.py`
- `tools/strategy_farm/dashboards/render_dashboards.py`
- focused tests under `tools/strategy_farm/tests/`
- the proposal document named above

## Contract invariants

- Writable phases remain exactly Q00–Q16; Q10A is not writable.
- Gate authority, runner, `next`, legacy aliases, and verdict dimensions match v2.
- Q14 pattern-filter cap is exactly 3 per direction and selection contract is DL-089.
- Q15 stays a DEV-only parameter sweep/freeze description.
- Q16 topology binds both Q10A/Q08 baseline evidence and incumbent Q10.
- Q11 has only the Q10/non-optimized and Q16/optimized entry routes.
- `DEFAULT_MANIFEST` remains v2; activation guard requires E1/E2 review plus Claude.
- No threshold or verdict vocabulary changed.

## FTMO presentation evidence

The new projection delegates every decision to the existing
`evaluate_ftmo_q09_admission` function. Cockpit and Mission Control show aggregate
JA/NEIN counts and reason codes; Strategy Archive EA details show the same decision per
symbol. It is read-only and grants no challenge or deployment authority.

Read-only live DB measurement at implementation time:

| Metric | Count |
|---|---:|
| evaluated completed-Q09 pairs | 31 |
| FTMO geeignet JA | 1 |
| FTMO geeignet NEIN | 30 |
| `FTMO_Q09_EVIDENCE_MISSING` | 29 |
| `FTMO_Q09_NOT_CONFIG_LOCKED` | 1 |
| `FTMO_Q09_ADMITTED` | 1 |

These are presentation counts, not pipeline verdicts.

## Verification

1. Python syntax compilation passed for every changed Python module.
2. Initial focused suite passed: **34 passed, 2 skipped**. The expanded manifest,
   admission, Cockpit, Mission Control, and Strategy Archive regression suite passed:
   **112 passed, 2 skipped**. The skips are optional environment-dependent checks,
   including the Python `jsonschema` package absence.
3. PowerShell Draft 2020-12 schema validation passed:
   `gate_manifest.v3.json | Test-Json -SchemaFile gate_manifest.v3.schema.json` → `True`.
4. Strict loader loaded v3 and rejected mutations to Q08 reuse, Q14 cap, Q16 baseline
   dependency, and the activation guard.
5. Read-only live projection completed with `PRAGMA query_only=ON`.
6. `git diff --check` returned no whitespace errors (only Git line-ending notices).

Artifact hashes after the final verification run:

- `gate_manifest.v3.json`: `90ef1463d73d9020538d65f67164a63fb3d9ae30ba51b121b908ee84dff1e508`
- `gate_manifest.v3.schema.json`: `c6f25032196c065519bdcde6a66144e2524bdf0fade7e568ecbac955b7675fd2`

## Non-actions

No work item was enqueued; no database row, registry, setfile, EA, EX5, report,
threshold, verdict, terminal, T_Live preset, deployment pointer, challenge state, or
AutoTrading state was modified. The unavailable G: Vault mount was not bypassed; Claude
receives the canonical repo proposal for the authorized mirror step.
