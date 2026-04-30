## Status: registry split-brain reconciled; worldcup moved to ea_id 1005

- Updated canonical allocation file `framework/registry/ea_id_registry.csv` to resolve divergent snapshots.
- Preserved `1003` for `davey-baseline-3bar` (`SRC01_S03`) and assigned `1005` to `davey-worldcup` (`SRC01_S05`).
- Added missing `1004` allocation for `davey-es-breakout` (`SRC01_S04`) so the sequence is collision-free.

### Resulting active map

- `1001` `breakout-atr`
- `1002` `davey-eu-night`
- `1003` `davey-baseline-3bar`
- `1004` `davey-es-breakout`
- `1005` `davey-worldcup`

### Verification

- `Import-Csv framework/registry/ea_id_registry.csv | Group-Object ea_id | ? Count -gt 1` returns no rows (no duplicate `ea_id`).

### Next action

- Development/CTO follow-up EAs for `SRC01_S04` and `SRC01_S05` must use the reconciled ids (`1004`, `1005`) in folder/file naming and `qm_ea_id` inputs.

---

## Continuation Update (resume run)

- Renamed worldcup EA artifact in `C:\QM\worktrees\cto`:
  - Directory: `QM5_1003_davey_worldcup` -> `QM5_1005_davey_worldcup`
  - Source: `QM5_1003_davey_worldcup.mq5` -> `QM5_1005_davey_worldcup.mq5`
  - Binary: `QM5_1003_davey_worldcup.ex5` -> `QM5_1005_davey_worldcup.ex5`
- Updated embedded identifiers in the EA source:
  - Header description now `QM5_1005`
  - `ea_id` input now `1005`
  - INIT log tag now `QM5_1005_davey_worldcup`
- Normalized `ea_id_registry.csv` across all three worktrees to byte-identical canonical content by copying the main repo registry file.

### Cross-worktree parity proof

- SHA256 `framework/registry/ea_id_registry.csv`:
  - `C:\QM\repo`: `BB1EB9D4DB3B56466C18BC78E9A5C7F51125A4AF303C5DF4804C700D376D498F`
  - `C:\QM\worktrees\cto`: `BB1EB9D4DB3B56466C18BC78E9A5C7F51125A4AF303C5DF4804C700D376D498F`
  - `C:\QM\worktrees\qua-296-cto`: `BB1EB9D4DB3B56466C18BC78E9A5C7F51125A4AF303C5DF4804C700D376D498F`

### Targeted checks

- No duplicate `ea_id` values in any reconciled registry snapshot.
- Worldcup EA source now contains no `QM5_1003` / `ea_id=1003` references.
- Magic implication for slot `0`: `QM_Magic(1005,0)` -> `10050000` (per hard-rule formula `ea_id*10000 + symbol_slot`).
