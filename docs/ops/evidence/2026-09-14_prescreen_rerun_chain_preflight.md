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

---

# Second half: PRESCREEN promotion must forward-walk the same chain

Date: 2026-09-14 · Author: Claude · Scope: authentication plumbing only. No gate
criteria, verdict logic, thresholds, enqueue, or DB writes changed.

## Symptom (promotion side)

With the preflight fixed (above) and all five recovery rows now
`PRESCREEN_MEASURED`, the promotion dry-run still failed:

```
config_sweep.py promote --declaration .../2026-09-12_..._prescreen_dryrun_declaration.json \
  --artifact D:/QM/.../WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025 --keep 0.70 --control 0.10
ConfigSweepError: PRESCREEN matrix incomplete: 62538f30-df4e-5d61-b807-b6099af9d7cf
```

## Root cause

`_promotion_documents` (config_sweep.py) mapped each **sealed-ledger** cell id
straight to a DB row (`SELECT * FROM work_items WHERE id = cell["work_item_id"]`)
and required that row to be `PRESCREEN_MEASURED`. For a cell that went `INFRA_FAIL`
and was re-measured through the append-only rerun chain, the sealed-ledger id
(`62538f30`, 2019:c00) is still `INFRA_FAIL`; the measurement lives at the chain
head (`62538f30 -> c734c260 -> 97f8157d`). The preflight learned to walk that chain
**backward** (candidate -> ledger root); the promotion never learned to walk it
**forward** (ledger root -> live head), so it read the dead root and declared the
matrix incomplete. Same for 2021:c00 (`35a985c0 -> 8810cd45 -> 945e218d`) and the
three single-hop cells 2020:c00, 2019:c01, 2019:c02.

## Change

`tools/strategy_farm/config_sweep.py`:

- **`_authenticated_rerun_hop(amendment, path, *, cell_key, program_id,
  declaration_sha256, ledger_sha256)`** — the single shared chain-walk primitive.
  It authenticates ONE sealed rerun amendment (schema, seal, program/declaration/
  ledger/cell binding, and the `reruns/<rerun_work_item_id>.json` filename
  invariant) and returns `(source_id, rerun_id)`, fail-closed. `authenticate_ledger`
  (backward) now calls it for each hop instead of its inline block — behaviour is
  byte-identical (the file is still opened by `reruns/<source_id>.json` and the
  message is unchanged), and all six preflight tests stay green.
- **`_resolve_rerun_chain_head(reruns_dir, ledger_work_item_id, ...)`** — the
  forward walk. From the sealed-ledger id it repeatedly finds the amendment whose
  `source_work_item_id == current` (authenticated with the shared hop), follows
  `rerun_work_item_id`, and repeats until no amendment sources the current id — that
  id is the head. Bounded at `PRESCREEN_RERUN_MAX_CHAIN_DEPTH = 8`; a branching (one
  source cloned under two reasons) or cyclic chain fails closed; a cell with no
  reruns (or a program with no `reruns/` dir) returns `[ledger_id]`, so
  reruns-free promotion is byte-identical. Amendments for other cells are skipped by
  `cell_key` before authentication, so one cell's chain never depends on another's.
- **`_promotion_documents`** now resolves every cell to its chain head, reads THAT
  row's verdict/evidence (a cell is complete iff the head is `PRESCREEN_MEASURED`),
  and records the resolved chain for audit: each ranking-snapshot observation gains
  `rerun_chain: [ids]`, `ledger_work_item_id`, and `work_item_id` = head; each
  promoted real cell gains `source_prescreen_rerun_chain` and points
  `source_prescreen_work_item_id` at the head (the row actually measured).

Readers deliberately left unchanged, verified in place: `prescreen_report`
(FN/control) reads the amendment's **REAL_TICKS** cells, which cannot be
config-sweep-rerun (`append_only_prescreen_rerun` refuses any row whose
`evidence_class != PRESCREEN`), so they have no PRESCREEN chain to resolve; the
generic `report` is a diagnostic that intentionally shows sealed-ledger-id status
and is not on the verdict/promotion path.

## Tests

`python -X utf8 -m pytest tools/strategy_farm/tests/test_config_sweep.py -q` ->
`16 passed` (13 prior + 3 new; the 3 new build a real full-matrix promotion with
cell[0] measured through a two-hop chain via the production `enqueue -> fail ->
rerun -> fail -> rerun` path):

- `test_prescreen_promotion_two_hop_chain_resolves` — promotion resolves the head;
  snapshot observation carries `work_item_id = hop2` and
  `rerun_chain = [ledger, hop1, hop2]`; the promoted real cell records the head.
- `test_prescreen_promotion_incomplete_chain_head_names_head` — head still pending
  -> `PRESCREEN matrix incomplete: <hop2>` (names the HEAD, not the ledger id).
- `test_prescreen_promotion_tampered_intermediate_fails_closed` — broken seal on
  the intermediate -> `chain amendment binding mismatch` (never skips to the head).

## Real dry-run (no `--apply`)

```
keep_arms=35  control_arms=2  dropped_arms=15  real_cells=259  prescreen_cells=350
```

(50 arms: keep ceil(50*0.70)=35 incl. mandatory control c00; 15 dropped;
control ceil(15*0.10)=2; real_cells (35+2)*7=259.) The five chained cells resolve:

| cell | chain | head | verdict |
|---|---|---|---|
| 2019:c00 | `62538f30 -> c734c260 -> 97f8157d` | `97f8157d` | PRESCREEN_MEASURED |
| 2021:c00 | `35a985c0 -> 8810cd45 -> 945e218d` | `945e218d` | PRESCREEN_MEASURED |
| 2020:c00 | `9fdbcfa4 -> a7be7aa2` | `a7be7aa2` | PRESCREEN_MEASURED |
| 2019:c01 | `d4c790e7 -> b901af93` | `b901af93` | PRESCREEN_MEASURED |
| 2019:c02 | `2a897e8e -> 3a308d3d` | `3a308d3d` | PRESCREEN_MEASURED |

Would-write paths (NOT written — dry-run):
`.../prescreen_promotions/70af71eb7e2670f53cbb665619b2aea4cead4178f0e03478f2623cccff450b98/ranking_snapshot.json`
and `.../promotion_amendment.json`. Confirmed no `prescreen_promotions/` dir was
created and `reruns/` still holds its 7 files.

## Rollback (promotion side)

`git revert` the commit carrying `_authenticated_rerun_hop`,
`_resolve_rerun_chain_head`, the `_promotion_documents` rewrite, and the 3 new
tests. Reverting restores the ledger-id-only promotion reader; no artifact or DB
row is mutated by this change (the dry-run writes nothing), so the amendments and
rows remain valid for a re-fix.
