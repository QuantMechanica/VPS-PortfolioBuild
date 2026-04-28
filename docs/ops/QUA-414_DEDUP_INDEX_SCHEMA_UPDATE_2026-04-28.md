# QUA-414 Dedup Index Schema Update — 2026-04-28

## Action
Aligned matrix schema persistence with issue objective (`dedup_index.json`).

## Implemented
- `framework/scripts/pipeline_dispatcher.py`
  - Added `DEFAULT_DEDUP_INDEX_PATH`.
  - Added `export_phase_matrix_index(state)`.
  - Added `load_dedup_index(path)` / `save_dedup_index(index, path)`.

- `framework/scripts/resolve_backtest_target.py`
  - Added CLI arg `--dedup-index-json` (default `D:\QM\Reports\pipeline\dedup_index.json`).
  - On state-changing events, mirrors current `phase_matrix_index` into dedup index.

## Schema written to `dedup_index.json`
```json
{
  "<ea_id>_<version>_<phase>": {
    "matrix": [{"symbol":"...DWX","terminal":"T1","verdict":null,"evidence":null}],
    "phase_verdict": null,
    "next_strategy_unblocked": null
  }
}
```

## Verification
- `python -m unittest framework/scripts/tests/test_pipeline_dispatcher.py` -> `Ran 21 tests ... OK`
- `python framework/scripts/resolve_backtest_target.py --help` includes `--dedup-index-json`.

## Next Action
- Commit QUA-414 implementation files and publish closeout comment with commit hash/evidence references.
