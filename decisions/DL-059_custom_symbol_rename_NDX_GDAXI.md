---
name: DL-059 — Custom symbol rename NDXm/GDAXIm → NDX/GDAXI
description: Rename V5 target custom symbols from "NDXm.DWX"/"GDAXIm.DWX" to "NDX.DWX"/"GDAXI.DWX" so the .DWX-suffix-stripped name matches the DarwinexZero live broker symbol. The "m" suffix was a Tick Data Suite filename artifact, not the broker name.
type: decision-log
authority: OWNER 2026-05-06 explicit directive
date: 2026-05-06
supersedes: nothing — corrects a naming inconsistency that surfaced during the Tuesday TDS re-import.
related: DL-054 (G1 data access), DL-058 (no-recovery), QUA-737 (cleanup), QUA-684/D2 (bar compilation), the partial-data .hcc gap we are about to fill via TDS.
---

## What changed

**Target symbol rename** (the name in MT5 Custom Symbol storage, in setfiles, in registries, in P2/P3/.../P10 reports):

| Before | After |
|---|---|
| `NDXm.DWX` | `NDX.DWX` |
| `GDAXIm.DWX` | `GDAXI.DWX` |

## Why

OWNER clarification 2026-05-06: DarwinexZero live broker labels these instruments as `NDX` and `GDAXI`. The `m` suffix exists only in Tick Data Suite filenames (e.g. `NDXm_GMT+2_US-DST.csv`). When an EA promotes from P10 burn-in to live trading, it must reference the broker's name. Carrying the `m` artifact through the pipeline means a rename on the deploy boundary — which is exactly the kind of error-prone surgery DL-038 hard rules are meant to prevent.

The fix is upstream: align target name with the broker now, before anything reaches P10.

## Source / Target mapping (post-rename)

The TDS source CSVs continue to ship under `NDXm`/`GDAXIm` filenames. `verify_import.py::SOURCE_OVERRIDES` is updated to reverse the mapping — given target `NDX`, source is `NDXm`; given target `GDAXI`, source is `GDAXIm`. Both `prepare_import.py` and `Compile_Custom_Bars_QM_v2.mq5` consume the target name (`.DWX`-suffixed) and resolve source via the override map, so no other code paths need changes.

## Files updated

Active config (renamed/edited):

- `framework/EAs/QM5_1003_davey_baseline_3bar/sets/*_GDAXIm.DWX_*.set` → `..._GDAXI.DWX_...`
- Same rename for QM5_1004, QM5_1017, QM5_SRC04_S03 (8 setfiles total: 4 NDXm + 4 GDAXIm)
- `framework/EAs/QM5_*/P2_baseline_matrix_manifest.json` (3 files)
- `framework/EAs/QM5_1017_chan_pairs_stat_arb/sets/*_GDAXI.DWX_*.set` and `*_NDX.DWX_*.set` (`pair_symbol_*` parameters inside pair-trade strategy)
- `framework/registry/magic_numbers.csv` (26 cells, ea_ids 1001–1017)
- `framework/registry/dwx_symbol_matrix.csv` (8 occurrences)
- `framework/scripts/mt5/Compile_Custom_Bars_QM.mq5`, `Compile_Custom_Bars_QM_v2.mq5` (g_symbols list, both v1 and v2)
- `D:\QM\mt5\T1\dwx_import\verify_import.py` SOURCE_OVERRIDES (reversed: target NDX → source NDXm, target GDAXI → source GDAXIm)
- `D:\QM\mt5\T1\MQL5\Scripts\Compile_Custom_Bars_QM_v2.mq5` (live MT5 copy, g_symbols)

Historical / immutable (NOT renamed):

- All `docs/ops/QUA-*` reports — frozen audit trail, retains the name that was in effect at the time the report was written.
- `decisions/2026-05-05_zero_trade_QM5_1017_NDXm.DWX.md` — historical decision log titled with the old name.
- `framework/EAs/.../QUA-743_P2_LATEST_SYMBOL_VERDICTS_2026-05-06.csv` — captured verdict snapshot.

## MT5 storage migration (deferred to import time)

Storage folders `D:\QM\mt5\T1\bases\Custom\history\NDXm.DWX\` and `\ticks\NDXm.DWX\` (and the `GDAXIm.DWX` siblings) are NOT renamed in this DL. Reasoning:

1. The T1 folders currently hold the broken / partial historical data we are about to replace via TDS re-import + `Compile_Custom_Bars_QM_v2 MinBarsToSkip=0`.
2. Post-rename, the import lands as `NDX.DWX` / `GDAXI.DWX` per the new target name.
3. The legacy `NDXm.DWX` / `GDAXIm.DWX` folders become orphans on T1; cleanup happens after we verify the new folders compile cleanly:
   - `verify_import.py` confirms `NDX.DWX` / `GDAXI.DWX` PASS
   - Then delete `NDXm.DWX` / `GDAXIm.DWX` legacy dirs (T1 first, robocopy excludes them on T2..T5 propagation)

This sequencing avoids a window in which the rename is half-done and the matrix dispatcher cannot find either the old or new folder.

## Acceptance

- [ ] Repo grep for `NDXm\.DWX|GDAXIm\.DWX` outside `docs/ops/` and `decisions/` returns empty (already verified — only `QUA-743_*` historical CSV remains).
- [ ] After TDS-driven re-import: `bases/Custom/history/NDX.DWX/{2017..2024}.hcc` ≥ 1 MB each, same for `GDAXI.DWX`.
- [ ] After T1 → T2..T5 propagation: same `.hcc` topology on every factory terminal.
- [ ] First P2 run after rename: 0 INVALID rows for NDX.DWX / GDAXI.DWX.
