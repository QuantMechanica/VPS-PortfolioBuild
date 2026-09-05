# Codex model-tier enforce preconditions — round-4 residual findings

- Task: `453b8edf` (Claude lane, decision-bound)
- Date: 2026-09-05
- Base: builds on wf_76cb7101 (`a769c2f5b8`, observe shipped as default)
- Scope: implement the 6 residual round-4 findings + tests, all provably inert
  while `window_enforcement_mode = observe` (the shipped default). `enforce`
  stays OFF until this task is APPROVED; the plan tier is known (Pro 20x,
  `agent_quota_gate.v1.json` `plan_tier = pro_20x`).

Hard-rule posture: read-only on `D:/QM`; the production ledger
`D:/QM/reports/state/codex_model_window_ledger.jsonl` was NOT touched (every
test writes a `tmp_path`); no live account / T_Live surface involved.

## Files changed

- `tools/strategy_farm/agent_router.py` — ITEM 1 (scalpel routing strictness +
  lane-independent router hold for an invalid marker).
- `tools/strategy_farm/run_agent_orchestration_task.py` — ITEM 1 (the
  orchestration lane selector skips a held invalid-marker row, agreeing with
  `route_once`).
- `tools/strategy_farm/codex_model_tiers.py` — ITEM 2/3/4/5 (position-based
  ledger bounds, `allowed_window_enforcement_modes` validation, rotate stat-only
  fast path, future-record rotation guard).
- `tools/strategy_farm/quota_spawn_gate.py` — ITEM 6 (Astra hold precedes the
  OWNER burn bypass in enforce mode).
- `tools/strategy_farm/tests/test_codex_tiers_enforce_preconditions.py` — new
  suite (ITEM 7), 31 tests, one per finding + observe-invariance.

## Findings and fixes

### ITEM 1 — scalpel marker strictness at routing time
`scalpel_routing_capabilities` returned `set()` for a non-JSON-true `scalpel`
value (`"true"`, `1`, `"yes"`), so an invalid-marker row carried no lane
capability and fell to **gemini** — the cheapest lane, which is not in
`quota_spawn_gate.GATED_AGENTS` and never runs the tier contract, so the
`invalid_scalpel_marker` hold never fired and Astra-class work executed silently
on the weakest seat.

Fix (two layers, both routing-only, mode-agnostic):
1. `scalpel_routing_capabilities` now returns the scalpel capability for an
   invalid marker (defence in depth: gemini can never be eligible).
2. `invalid_scalpel_marker_hold()` + a lane-independent hold in `route_once`
   (recorded via `_record_model_window_hold`, reason `invalid_scalpel_marker`,
   code `ROUTER_INVALID_SCALPEL_MARKER`) HELD **before** per-lane gating. The
   codex tier gate only holds the defect on the codex lane, so a claude fallback
   (claude also declares the scalpel capability) would otherwise execute the
   malformed row — the router hold closes that. `_quota_lane_candidates` skips
   the same row so the orchestration selector agrees nothing runs it.

### ITEM 2 — ts-less ledger records could become a permanent charge
`scan_window` counted a JSON-valid record with a missing/unparseable `ts`
conservatively forever, and `rotate_ledger` kept it forever. Fix: bound it by
**append position**. A ts-less line is released once a valid timestamped record
appended AFTER it (higher physical position) has itself left the window — the
append-order anchor `_max_position_at_or_before_cutoff`. Both `scan_window`
(counting) and `rotate_ledger` (pruning) use the same anchor so rotation can
never release a message the count still charges. With no aged timestamped
neighbour the conservative behaviour is preserved (the existing
`test_a_record_without_a_parseable_ts_counts_conservatively` and
`test_rotate_ledger_keeps_records_whose_ts_cannot_be_read` stay green).

### ITEM 3 — corrupt-line bound must not depend on file mtime alone
The D12 bound charged a corrupt line while the FILE mtime was inside the window;
any append refreshed the mtime, so a busy file below the 500-line rotation floor
re-charged its corrupt lines indefinitely. Fix: the bound is now TWO necessary
conditions — (a) mtime inside the window (the coarse anchor for a degenerate
all-corrupt file with no timestamped neighbour, which keeps the existing
`test_corrupt_lines_outside_the_window_are_reported_not_counted` green) AND
(b) not provably older by position (same append-order anchor as ITEM 2). A
corrupt line with an aged valid neighbour after it is released. `rotate_ledger`
now (i) drops a corrupt line only when it is provably older by position (so it
cannot release one the window still counts) and (ii) carries an explicit guard,
symmetric with `scan_window`, that a FUTURE-stamped record is KEPT after a
wall-clock jump — no concrete drop path existed, this makes the invariant
explicit for the refactor.

Trade-off recorded: mtime is retained as ONE of two bounds (needed for the
all-corrupt / no-timestamped-neighbour file); the charge no longer depends on it
alone, which is the permanence class the finding targets.

### ITEM 4 — `allowed_window_enforcement_modes` was never read
The config key existed but nothing consulted it. `validate_matrix` now
fail-closes (`codex_model_matrix_incomplete:...`) when the list is malformed,
when an entry is not a known mode, or when the active `window_enforcement_mode`
(its default included when the field is absent) is not a member. This lets OWNER
pin the list to `["observe"]` to make `enforce` un-loadable until APPROVED. The
shipped list stays `["observe","enforce"]` (NOT tightened here — that is an OWNER
decision) so the config remains loadable in both modes.

### ITEM 5 — `rotate_ledger` had no stat-only fast path
`rotate_ledger` did a full `read_text` + `splitlines` BEFORE the `min_lines`
gate, so every dispatch fully decoded the ledger even in the common
below-threshold case. `_cheap_line_count` now counts `\n` bytes in a raw binary
scan and returns `below_rotation_threshold` without decoding, matching the
docstring's "one stat-sized read and no rewrite" promise. Verified by a test
that monkeypatches `Path.read_text` to raise below the threshold.

### ITEM 6 — burn bypass preceded the Astra hold
In `evaluate_spawn` the OWNER `CODEX_BURN_AUTHORIZED.flag` bypass returned
`allowed=True` before `_codex_tier_block`, so a burn flag spawned a spent-Astra
(scalpel) task instead of holding it — burn overrode the hold-not-downgrade
contract. Fix: `_codex_tier_hold_block` (fires only when the invocation carries
`model_tier_hold` — a spent Astra window or an invalid scalpel marker) is
evaluated BEFORE the burn bypass, **gated to enforce mode**. Ordinary-tier
window refusals (which merely walk down the fallback chain, no hold) stay behind
the burn bypass, so burn still outranks them. Naturally inert in observe:
`select_dispatch` emits no hold from a spent window in observe (it takes the
first entry), and the enforce-mode gate means the reorder is never taken there.

## Observe-mode invariance

- `test_observe_mode_spawn_decisions_are_unchanged_by_this_patch`: a spent Astra
  window in OBSERVE mode still ALLOWS the spawn with the same model
  (`gpt-6-astra`), with or without a burn flag — the ITEM 6 reorder is enforce-
  gated.
- `test_observe_mode_ledger_counts_are_identical_for_well_formed_ledgers`: the
  ITEM 2/3/5 rotate/scan changes never move the count for a well-formed ledger
  (every record carries a real `ts`, so the position bounds never fire) — the
  only ledger shape a real Codex spawn writes.
- ITEM 1 and ITEM 4 are routing / config-validation decisions independent of the
  window enforcement mode; ITEM 1 changes the treatment of a malformed-payload
  DEFECT input only (held instead of misrouted), not any well-formed dispatch.

## Test results (`-p no:cacheprovider`)

16 target suites + the new suite, run together:

```
314 passed in 49.21s
```

Suites: test_agent_router, test_agent_router_canonical_writer_contract,
test_agent_router_sqlite_retry, test_agent_router_stale_release,
test_agent_router_state_exits, test_run_agent_router_task, test_quota_spawn_gate,
test_quota_burn_authorization, test_quota_window_consumers,
test_codex_model_tiers, test_agent_selection_skill_contract,
test_agent_orchestration_lock, test_run_agent_orchestration_heartbeat,
test_build_slippage_ledger_v2, test_tester_memory_ledger,
test_codex_tiers_enforce_preconditions (new, 31 tests).

Adjacent ledger/gate consumers also green: test_news_calendar_blast_radius,
test_oos_2026_confirmation, test_opt_census_dispatch, test_q09_news_runner_v2
(113 passed alongside).

Out of scope — pre-existing, unrelated failure (present at base, not caused by
this task): `test_owner_decision_execution.py::test_execution_contract_covers_
every_bootstrap_decision_and_both_choices` fails on OWNER-decision feed drift
(items like OWNER-DEC-Q02-SPLIT-FIX-20260830 not in the execution contract). It
is a data-drift, not a code regression, and is not touched here.
