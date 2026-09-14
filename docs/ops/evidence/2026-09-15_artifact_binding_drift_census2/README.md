# pending_artifact_binding_drift — census #2 & governed dry-run rebind plan (2026-09-15)

Second, refreshed census of `pending_artifact_binding_drift`, superseding the
`docs/ops/evidence/2026-09-13_artifact_binding_drift/` plan. This is a **read-only
dry-run**: no DB writes, no git operations, no farm script ran in `--apply`. The
per-row rebind proposals live in the sibling `plan.json`; the raw governed
enumeration is `census.json`.

## How this was produced

`python -X utf8 tools/strategy_farm/pending_artifact_binding_census.py` (the
existing read-only enumerator, mode=ro, `busy_timeout=30s`) → `census.json`. That
tool mirrors the dispatch preflight hash comparison exactly and is the canonical
governed read-path; `plan.json` is a rendering of its rows into the
`qm.artifact-binding-drift-repair-plan.v1` shape used on 09-13, enriched with the
per-binding predecessor→successor SHAs and the cause-cluster split. No dedicated
`--dry-run` rebind tool was run: `farmctl requalify-q02` operates one row at a
time and requires a per-row `--expected-current-ex5-sha256`; the plan embeds those
commands (dry-run first) exactly as the 09-13 plan did, for orchestrator REVIEW.

## Census (live DB, 2026-09-15)

| metric | value |
|---|---|
| bound pending rows checked | 506 |
| drifted rows | **42** |
| mismatched bindings | **81** |
| class_counts | `{"CONTENT_CHANGED": 81}` |
| disposition_counts | `{"GOVERNED_BUILD_SUCCESSOR_REQUIRED": 42}` |
| held / free | 39 / 3 |

Cause clusters: **C1 = 0**, C2A = 35, C2B = 7.

## What changed since 2026-09-13

1. **C1 (WINSWEEP/OPT_CENSUS false positive) is gone — 0 rows.** On 09-13 the
   check reported 354 drifted rows / 707 bindings, of which 632 bindings / 316
   rows were the C1 path-derivation false positive (all `QM5_41405`, byte-exact
   payload SHAs against the real EA dir). The derivation fix documented in
   `2026-09-13_artifact_binding_drift/FIX.md` (resolve ex5/mq5 by ea_id the way
   the runner does) has landed, so those 632 false MISSING bindings no longer
   appear. Every one of the 81 remaining bindings is a genuine `CONTENT_CHANGED`
   drift on a real EA — there are **no MISSING and no LINE_ENDINGS_ONLY** rows.

2. **The genuine drift grew from 38 rows / 75 bindings (the 09-13 post-fix
   snapshot in FIX.md) to 42 rows / 81 bindings.** The additional drift is the
   same class: mq5 / setfile / ex5 that were regenerated and committed (or, for
   7 rows, edited in the working tree) after the pending row pinned its SHA.

3. **C2B is still the same open decision (7 rows).** These carry a setfile binding
   whose on-disk bytes are an **uncommitted** working-tree edit from the
   in-progress `s20260912-001` setfile regen wave (430 `framework/EAs/**/sets/*.set`
   are modified in the tree; 7 back a drifted binding). This census did **not**
   touch those files — commit-or-revert of that wave remains an orchestrator
   decision that gates any setfile rebind for these rows.

4. **3 rows are FREE (not held) and at INFRA_FAIL-burn risk** — all `QM5_10706`
   (mq5 bindings, phases Q12 / Q14):
   `64604d7a…` (Q14), `00f26e21…` (Q12), `9ca7760d…` (Q12). A claim would raise
   the mq5/identity mismatch in preflight and burn the row to `INFRA_FAIL`.
   Recommend parking them first with `governed_work_item_hold.py apply --hold-code
   ARTIFACT_BINDING_CONTENT_CHANGED` before the governed successor is decided.

## Per-row plan (`plan.json`)

Each row carries: `id`, `ea`, `phase`, `symbol`, `kind` (mq5/setfile/ex5 or a
`+`-join), `class`, `held`/`hold_code`/`free`, `cause_cluster`, `disposition`,
a `bindings[]` list (per binding: `role`, `path`, `classification`,
`pinned_sha256_predecessor`, `on_disk_sha256_successor`, `derivation`), a
`proposed_action`, and the dry-run `command`.

## Decision points for the orchestrator (unchanged in kind from 09-13)

1. **C2A ex5/mq5 rows (35):** confirm the on-disk binary is the intended rebuilt
   EA (rebind via `requalify-q02`, dry-run first, GELB) vs a recompile being
   required (ROT → OWNER) before any rebind.
2. **C2B (7 rows):** decide commit-or-revert of the `s20260912-001` setfile regen
   wave before any setfile rebind. This diagnosis did not touch those files.
3. **FREE rows (3 × QM5_10706):** park first to stop the INFRA_FAIL burn.

## Reproduce

```
python -X utf8 tools/strategy_farm/pending_artifact_binding_census.py \
  --output docs/ops/evidence/2026-09-15_artifact_binding_drift_census2/census.json
```

Nothing here was applied. `plan.json` is for REVIEW before any governed apply step.
