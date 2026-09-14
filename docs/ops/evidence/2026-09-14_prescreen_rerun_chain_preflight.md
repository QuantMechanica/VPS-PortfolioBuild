# PRESCREEN rerun-of-a-rerun blocks the DL-089 lane preflight — chain-walk fix

Date: 2026-09-14 · Author: Claude · Program:
`WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025` (EA `QM5_41405`, `USDJPY.DWX`, H1)
Scope: authentication plumbing only. No gate criteria, verdict logic, thresholds,
enqueue, or DB writes changed.

## Symptom

The QM5_41405 PRESCREEN matrix could not complete (blocking promotion). Five
recovery rows were enqueued 2026-09-14 01:22Z via
`config_sweep.py prescreen-rerun --apply`. Two of them are reruns whose source
was *itself* a rerun, and the worker's DL-089 lane preflight refused them:
`dl089_lane_preflight_status=error`, driving `PROGRAM_PREFLIGHT_SUPPRESSED`; the
failing 2019 cell is the arm `c00` frontier, so the whole arm head-blocked.

## Root cause (evidence)

`config_sweep.authenticate_ledger` (the function the worker calls for
`sweep_engine == "config_sweep"` cells) resolved the rerun's source with a single
direct lookup in the sealed ledger:

```python
source_id = str(rerun.get("source_work_item_id") or "")
target_index = next(
    (index for index, item in enumerate(cells_value)
     if item.get("cell_key") == rerun.get("cell_key")
     and str(item.get("work_item_id") or "") == source_id),
    None,
)
if target_index is None:
    raise ConfigSweepError("PRESCREEN rerun source absent from ledger")
```

The sealed `ledger.json` cells carry the **original** `work_item_id`s. A first
rerun is created from a ledger cell (source ∈ ledger → single hop, resolves). But
when that rerun's own row is INFRA_FAIL again and is itself rerun, the second
rerun's `source_work_item_id` is the *first rerun's id*, which was never a ledger
cell. `target_index is None` → `"PRESCREEN rerun source absent from ledger"`.

Verified lineages (against `ledger.json` + `reruns/*.json`):

| candidate | cell | source | source in ledger? | hops |
|---|---|---|---|---|
| `97f8157d` | 2019:c00 | `c734c260` | no → rerun of `62538f30` (ledger) | 2 |
| `a7be7aa2` | 2020:c00 | `9fdbcfa4` | yes | 1 |
| `945e218d` | 2021:c00 | `8810cd45` | no → rerun of `35a985c0` (ledger) | 2 |
| `b901af93` | 2019:c01 | `d4c790e7` | yes | 1 |
| `3a308d3d` | 2019:c02 | `2a897e8e` | yes | 1 |

## Change

`tools/strategy_farm/config_sweep.py`, `authenticate_ledger` rerun block. When the
candidate's source is not a ledger cell, walk the authenticated amendment chain in
the program's `reruns/` directory: find the amendment whose
`rerun_work_item_id == source`, verify seal + `program_id` + `declaration_sha256`
+ `ledger_sha256` + `cell_key` (and that its `rerun_work_item_id` equals the id
followed) exactly like the direct case, take its `source_work_item_id`, and repeat
until a source that IS a ledger cell is found. Bounded at
`PRESCREEN_RERUN_MAX_CHAIN_DEPTH = 8`; a missing/tampered/cyclic hop fails closed.
The ledger cell's `work_item_id` is replaced with the candidate's rerun id exactly
as before. A source already in the ledger skips the walk entirely, so **single-hop
behaviour is byte-identical** (the loop body never executes).

## Tests

`tools/strategy_farm/tests/test_config_sweep.py` — `13 passed`
(`python -X utf8 -m pytest tools/strategy_farm/tests/test_config_sweep.py -q`).
Existing `test_prescreen_rerun_is_append_only_and_idempotent` (direct rerun
resolves) preserved. Added, each building a real two-hop chain via the production
code path (enqueue → fail → rerun → fail → rerun):

- `test_prescreen_rerun_direct_single_hop_resolves` — direct still passes.
- `test_prescreen_rerun_two_hop_chain_resolves` — two-hop resolves to hop2 id.
- `test_prescreen_rerun_chain_missing_intermediate_fails_closed` — deleted
  intermediate → `absent from ledger`.
- `test_prescreen_rerun_chain_tampered_seal_fails_closed` — broken seal →
  `chain amendment binding mismatch`.
- `test_prescreen_rerun_chain_wrong_cell_key_fails_closed` — re-sealed amendment
  for a different cell → `chain amendment binding mismatch`.
- `test_prescreen_rerun_chain_depth_bound_fails_closed` — self-referential chain →
  `exceeds max depth` (no infinite loop).

## Verification (five real rows)

Read-only, no claim, no writes: pull each pending row's payload from
`farm_state.sqlite` (mode=ro) and call the same `config_sweep.authenticate_ledger`
the worker calls (`terminal_worker.py:10464`).

| candidate | cell | hops | before | after |
|---|---|---|---|---|
| `97f8157d` | 2019:c00 | 2 | ERROR: source absent from ledger | RESOLVED → `97f8157d` |
| `a7be7aa2` | 2020:c00 | 1 | RESOLVED → `a7be7aa2` | RESOLVED → `a7be7aa2` |
| `945e218d` | 2021:c00 | 2 | ERROR: source absent from ledger | RESOLVED → `945e218d` |
| `b901af93` | 2019:c01 | 1 | RESOLVED → `b901af93` | RESOLVED → `b901af93` |
| `3a308d3d` | 2019:c02 | 1 | RESOLVED → `3a308d3d` | RESOLVED → `3a308d3d` |

All five now resolve; each stamps the ledger cell with the candidate's rerun id
(`matches_candidate=True`). The three single-hop rows are unchanged.

## Worker reload requirement

Resident terminal workers import `config_sweep` **in-process** and call it
directly (`terminal_worker.py` ~10459-10464):

```python
if str(payload.get("sweep_engine") or "") == "config_sweep":
    try:
        from tools.strategy_farm import config_sweep
    except ModuleNotFoundError:
        import config_sweep
    ledger_path, ledger = config_sweep.authenticate_ledger(payload)
```

`from … import config_sweep` binds from `sys.modules` and does not re-execute the
file, and the worker is a long-lived `while True:` claim loop
(`terminal_worker.py:7692`). A worker that already imported `config_sweep` keeps
the old code until reloaded. **The fleet needs the orchestrator's staggered idle
reload** to pick up this fix (the established "idle-reload the workers" mechanism).
This is not a subprocess/per-claim invocation, so the fix is not live on running
workers until then.

## Rollback

`git revert` the commit carrying this change (two edits to
`tools/strategy_farm/config_sweep.py`: the `PRESCREEN_RERUN_MAX_CHAIN_DEPTH`
constant and the `authenticate_ledger` chain-walk block) plus the new tests, then
idle-reload the workers. Reverting restores the single-hop-only resolver; the five
rows' amendments and DB rows are untouched by this change and remain valid for a
re-fix.
