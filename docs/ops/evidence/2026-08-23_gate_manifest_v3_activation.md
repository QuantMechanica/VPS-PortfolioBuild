# Gate Manifest v3 — activation evidence

Date: 2026-08-23

Task: `OPS-GATE-MANIFEST-V3-ACTIVATE` (priority 94)

Authority: OWNER chat approval 2026-08-23 that Claude may activate Gate Manifest
v3 after a green review. Prerequisites satisfied:

- Claude-Review `d5c13a08` — APPROVED 2026-08-23 (v3 candidate review).
- `OPS-Q10-REALIGN-E1-E2` review `9b40ff25` — APPROVED 2026-08-23 (prerequisite).

Disposition: **ACTIVATED** — `gate_manifest.v3.json` is now the default manifest;
its activation guard is `state=ACTIVE` and records both review refs. v2 remains a
loadable fixture. No gate criteria, thresholds, verdicts, seeds, or windows were
changed; no verdict rows were mutated; no backtest work was enqueued; Factory was
not toggled and no EA was recompiled.

## Diff table — every changed file

| File | Change |
|---|---|
| `tools/strategy_farm/config/gate_manifest.v3.json` | `activation_guard` flipped `READ_INERT`→`ACTIVE`, `default_manifest_switch` `false`→`true`, added `activated_by=CLAUDE`, `activated_at=2026-08-23`, `review_refs=["9b40ff25","d5c13a08"]`. No gate/topology/criteria bytes changed. |
| `tools/strategy_farm/gate_manifest.py` | `SCHEMA_VERSION` default `v2`→`v3`; `DEFAULT_MANIFEST` `v2`→`v3`; added `V2_MANIFEST`, `ACTIVATION_REVIEW_REFS`, `ACTIVATION_STATES` constants; added fail-closed `_validate_v3_activation_guard` (READ_INERT can never be default; ACTIVE requires switch=true, approver, activated_at, and BOTH review refs); `_validate_v3_topology` and `load_gate_manifest` now thread an `is_default` flag; added `GateManifest` accessors `baseline_stage`, `baseline_reuse_policy`, `baseline_missing_binding_action`, `q16_dependencies`, `portfolio_routes`, `portfolio_route(optimized=)`, `activation_state` so downstream code can query the Q10A/Q16 dependency roles and the Q11 routing rule. |
| `tools/strategy_farm/schemas/gate_manifest.v3.schema.json` | `activation_guard` schema changed from a `READ_INERT` `const` to a closed object schema requiring the ACTIVE fields, `default_manifest_switch=true`, `activated_by`/`activated_at` consts, and a `review_refs` array that must contain both `9b40ff25` and `d5c13a08`. |
| `tools/strategy_farm/tests/test_gate_manifest.py` | Updated default-contract assertions to v3/ACTIVE; pinned the v1/v2 frozen-topology and v2-fail-closed tests to `V2_MANIFEST`; retargeted the duplicate-key test to the v3 `pipeline_version`; changed the drift test's activation mutation to a missing-ref case; added `test_v3_loader_exposes_q11_routing_and_q16_dependencies` and `test_v3_activation_guard_fail_closed_invariants`. |

## Item-by-item outcome vs. goal

1. **activation_guard ACTIVE + fail-closed** — DONE. Manifest is ACTIVE with both
   review refs. Loader enforces (both directions): a READ_INERT manifest can never
   be the default (rejected on the default path and forbidden to set the switch);
   an ACTIVE manifest must have `default_manifest_switch=true`, an approver equal to
   `requires_approver`, an `activated_at`, and BOTH review refs present.
2. **Defaults switched to v3** — DONE. `DEFAULT_MANIFEST = V3_MANIFEST`,
   `SCHEMA_VERSION = qm.gate-manifest/v3`. Confirmed `load_gate_manifest()` returns
   the v3 contract; v2 still loads via `V2_MANIFEST`.
3. **Q10A/Q16 dependency + Q11 routing** — LOADER EXPOSURE DONE; runtime enqueue
   rebinding DEFERRED (see Deviations). The v3 dependency contract (roles
   `BASELINE_FULL_RUN`/Q10A and `INCUMBENT_Q10`/Q10, the Q10A reuse policy
   `REUSE_ONLY_HASH_BOUND_FULL_HISTORY_Q08_BASELINE` /
   `REQUIRE_Q10A_BASELINE_RUN`, and the Q11 routing rule Q10=non-optimized,
   Q16=optimized) is now queryable through the loader.
4. **Naming surfaces** — DONE (automatic). `phase_ids` loads the default manifest at
   import, so `PHASE_NAME`/`phase_label` now resolve v3 names. `render_cockpit.py`,
   `render_cockpit_v2.py`, `mission_control_v2_data.py`,
   `dashboards/render_dashboards.py` (cockpit, strategies archive, EA detail) and
   `website_archive_contract.py` all resolve gate/phase names through
   `phase_ids` / the manifest loader — verified no hardcoded v2 name table drives
   the displayed gate name (the only literal gate strings are the fixed Q09 FTMO
   panel headers and code comments).
5. **Tests** — Full `tools/strategy_farm/tests` suite run; see result below.
6. **Evidence doc** — this file.

## Deviation — item 3 runtime enqueue rebinding deferred

The goal for item 3 also described binding new dependency roles `Q10A_BASELINE`
(from a hash-bound Q08 baseline) and `Q10_INCUMBENT` into `work_item_dependencies`
on the enqueue-head-to-head path. I implemented the loader-side exposure of that
contract but deliberately did **not** rewire the runtime evaluator/enqueue, for
these reasons:

- The running Q16 evaluator is the DL-084 sealed parent/challenger head-to-head
  (`framework/scripts/q16_head_to_head.py`). `farmctl.enqueue_head_to_head` binds
  exactly two dependencies today: `PARENT_LINEAGE` and `CHALLENGER_Q10`. There is
  **no Q08 baseline artifact wired into the enqueue inputs**, so binding a
  `Q10A_BASELINE` from a hash-bound Q08 baseline would require adding a new gate
  input and deciding which lineage supplies the reusable baseline — a change to
  what Q16 compares, i.e. gate semantics, not activation/wiring.
- The `work_item_dependencies` table constrains `dependency_role` with a CHECK that
  enumerates the allowed roles (`Q08_INPUT`, `Q09_NEWS`, `Q09_PORTFOLIO`,
  `Q14_ADMISSION`, `PARENT_LINEAGE`, `CHALLENGER_Q10`, …). Adding
  `Q10A_BASELINE`/`Q10_INCUMBENT` requires a DB schema migration (CHECK-constraint
  change), which is beyond activation and would change gate storage semantics.
- OWNER decision E3 (`decisions/2026-08-22_owner_pipeline_realignment_q09_q11.md`)
  and the reviewed proposal explicitly scope the v3 change as **"no v3 runtime
  activation in this change"** — the Q10A/Q16 binding is a topology/contract
  description in the manifest, with runtime rebinding a later reviewed change.

Per the task's own instruction to stop rather than guess on gate semantics, the
runtime rebinding of `enqueue_head_to_head` (new roles + Q08-baseline sourcing +
DB CHECK migration) is left for a dedicated, separately reviewed change. The
loader now exposes the full v3 contract so that follow-on work can consume it
without re-deriving the topology.

## Verification

- `python -c` loader smoke test: default manifest = `qm.gate-manifest/v3`,
  `activation_state=ACTIVE`, `DEFAULT_MANIFEST.name=gate_manifest.v3.json`; v3
  names for Q09/Q10/Q11/Q16 resolve; `portfolio_route(optimized=False)=Q10`,
  `portfolio_route(optimized=True)=Q16`; `q16_dependencies` =
  `[(BASELINE_FULL_RUN,Q10A),(INCUMBENT_Q10,Q10)]`; v2 still loads.
- Fail-closed loader checks confirmed to raise: READ_INERT+switch, ACTIVE missing
  a review ref, ACTIVE switch=false, invalid state, and READ_INERT loaded on the
  default path.
- Draft 2020-12 schema validation (PowerShell `Test-Json`):
  `gate_manifest.v3.json | Test-Json -Schema gate_manifest.v3.schema.json` → `True`.
- `git diff --check` on all four changed files → exit 0 (only Git LF/CRLF notices;
  worktree files remain LF, no whitespace/EOL churn).
- Full suite: `python -m pytest tools/strategy_farm/tests -q` → run 1 (-x): 458 passed, 14 subtests, 1 failed = pre-existing `test_codex_session_supervisor::test_supervisor_resumes_after_unexpected_child_exit` (cp1252 UnicodeDecodeError on umlaut prompt, unrelated to gate manifest; reproduced in isolation); `test_gate_manifest.py`: 16 passed, 1 skipped.
  The Python `jsonschema` package is absent in this environment, so the optional
  `test_v3_json_schema_validates_candidate_when_jsonschema_is_available` skips; the
  PowerShell `Test-Json` run above provides the equivalent schema-validation
  evidence.

## Artifact hashes

Before:

- `gate_manifest.v3.json`: `90ef1463d73d9020538d65f67164a63fb3d9ae30ba51b121b908ee84dff1e508`
- `gate_manifest.py`: `6c217fc89f50626682dffb5ca0a7f7758f896fec483077dd6fa759228d0cde32`

After:

- `gate_manifest.v3.json`: `9927e0ff9f29418d908bb84cb2bfc2e91cea8ee7e9e5c1a7e55fb43a9edf1861`
- `gate_manifest.py`: `a95dcdc6be817fd566bd94439d8e275883000e4707b5649fba1c3d21a6ef6db1`
- `gate_manifest.v3.schema.json`: `4f581a2f648a8176d1371f0bea36a0f55fbc5907a9df0a917415b15b4b19a553`

## Non-actions

No `work_items`/`agent_tasks`/verdict row was created or mutated; no backtest was
enqueued; no registry, setfile, EA, EX5, report, threshold, verdict, terminal,
T_Live preset, deployment pointer, challenge state, or AutoTrading state was
touched. Factory_OFF was not run and no recompile was triggered.
