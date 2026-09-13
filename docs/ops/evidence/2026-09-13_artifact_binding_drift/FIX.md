# pending_artifact_binding_drift — false-positive fix (2026-09-13)

Fix for the WINSWEEP/OPT_CENSUS false positive diagnosed in `README.md` (cluster
C1). The health check and its census helper derived the ex5/mq5 paths from the set
file's grandparent directory. OPT_CENSUS PRESCREEN/WINSWEEP cells keep their set
files under `D:\QM\strategy_farm\artifacts\opt_census\<program>\setfiles\`, so the
derivation invented a nonexistent `framework/EAs/WINSWEEP_.../*.ex5` and reported
every such cell (all `QM5_41405`) as MISSING ex5+mq5 — even though the payload
SHAs match the real `framework/EAs/QM5_41405_balke-clock-audit-opt/*` byte-exactly
and the dispatch runner resolves the binary by ea_id.

## Change

Resolve ex5/mq5 the way `terminal_worker._dispatch_ex5_requirement` does:

1. Honour an explicit payload `expected_ex5_path` / `expected_mq5_path`.
2. Otherwise resolve the EA dir by ea_id — payload `ea_dir_name` hint, then
   `farmctl._ea_dir_from_setfile_path` (set file anchored under `<ea_dir>/sets`),
   then `farmctl._preferred_ea_dir` (ea_id glob + registry disambiguation),
   mirrored root-parametrized in the census helper for testability.
3. Fall back to the set-file-relative grandparent derivation only when the set
   file lives under `framework/EAs`.

A binding is never reported MISSING when the payload SHA matches a file found
through the runner's own resolution. Real drift classes (CONTENT_CHANGED, truly
MISSING) are unchanged. Each mismatch now carries a `derivation` field
(`ea_id_resolution` / `expected_path` / `setfile_relative` / `work_item_setfile`)
for auditability. The check's output format (status, value, classes, sample-line
format, thresholds) is unchanged.

## Files

- `tools/strategy_farm/pending_artifact_binding_census.py` — runner-mirroring
  resolver (`resolve_artifact_paths` + `_resolve_ea_dir` / `_preferred_ea_dir` /
  `_ea_dir_from_setfile_path` / registry helpers), `derivation` in findings.
- `tools/strategy_farm/health.py` — `_pending_binding_artifact_paths` delegates to
  the census resolver; `chk_pending_artifact_binding_drift` records `derivation`.
- `tools/strategy_farm/tests/test_pending_artifact_binding_census.py` — added:
  OPT_CENSUS ea_id resolution (no mismatch), CONTENT_CHANGED via ea_id, MISSING
  via ea_id, `expected_ex5_path` derivation assertion.

## Tests

```
python -X utf8 -m pytest tools/strategy_farm/tests/test_pending_artifact_binding_census.py \
  tools/strategy_farm/tests/test_health_pending_artifact_binding_drift.py -q
# 8 passed
```

## Live check — before / after

`python -X utf8 tools/strategy_farm/farmctl.py health` → `pending_artifact_binding_drift`:

| | status | value | classes | rows |
|---|---|---|---|---|
| BEFORE | FAIL | 683 | `{"CONTENT_CHANGED": 75, "MISSING": 608}` | 342 |
| AFTER  | FAIL | 75  | `{"CONTENT_CHANGED": 75}` | 38 |

Census helper (`pending_artifact_binding_census.py`), same run window:

| | bound rows | drifted rows | mismatched | classes |
|---|---|---|---|---|
| BEFORE | 799 | 343 | 685 | `{"CONTENT_CHANGED": 75, "MISSING": 610}` |
| AFTER  | 791 | 38  | 75  | `{"CONTENT_CHANGED": 75}` |

All 608–610 WINSWEEP MISSING false positives cleared; the 75 genuine
CONTENT_CHANGED drifts (real EAs regenerated after binding) are preserved, so the
check correctly stays FAIL on the residual real drift. Small count deltas between
the two BEFORE samples reflect the factory actively clearing WINSWEEP cells during
the run; class shape matches the diagnosis snapshot (707 / 632 MISSING).

Live derivation distribution after the fix (evidence the audit field is populated):
`{(mq5, ea_id_resolution): 31, (setfile, work_item_setfile): 31,
(ex5, ea_id_resolution): 12, (ex5, expected_path): 1}`.

## Rollback

```
git revert --no-commit <commit>   # or, for the two production files only:
git checkout <prev> -- tools/strategy_farm/health.py \
  tools/strategy_farm/pending_artifact_binding_census.py
```

Reverting `health.py` + `pending_artifact_binding_census.py` restores the prior
derivation exactly (the test additions are additive and independent). No DB, gate,
claim, or verdict logic was touched; the fix is read-path only.
