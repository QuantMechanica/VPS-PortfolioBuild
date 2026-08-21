# Filesystem Inventory (DRY-RUN) — QM-TODO-20260820-004

Date: 2026-08-21
Router task: 7dc80bad (state left for orchestrator to close)
Programme: `G:\My Drive\QuantMechanica - Company Reference\12 ToDo\06_Computer_Dateisystem_Aufraeumen.md`
(Erstinventur 2026-08-20 / Ziel-Dateisystem)

## Scope

Deliver a reusable, **read-only, DRY-RUN** filesystem inventory tool + one live run +
pytest. NO deletions performed or scheduled. The tool only `os.scandir()`s and `stat()`s;
it never opens file contents, never hashes, never moves/writes/deletes anything.

## What was built

- `tools/ops/filesystem_inventory.py` — the inventory tool.
- `tools/ops/test_filesystem_inventory.py` — 22 pytest cases (classifier + truncation +
  backup restore-status + no-descend flags + fail-safe).

### Classification (pure function `classify(path)`)

Explicit, most-specific-first path-prefix table (`RULES`), matched case-insensitively on a
normalized forward-slash path. Emits per node:

- **CLASS**: `active_runtime | canonical_evidence | generated_report | backup |
  scratch_or_temp | deploy | unknown`
- **OWNER**: `factory | pipeline | live | ops | unknown`
- **RETENTION** (suggestion only): `keep | archive | candidate_for_cleanup_review |
  never_touch`
- backup nodes additionally get **restore_status** (sidecar existence + newest backup).

**Fail-safe (verified by test):** an unmatched path falls to
`unknown / unknown / candidate_for_cleanup_review` — surfaced for review, never silently
`keep`, never `never_touch`, and there is **no delete/cleanup-now retention value at all**
(the most aggressive suggestion the tool can emit is "review").

### Safety / performance behaviours (all test-covered)

- **HARD-SKIP `C:\QM\mt5\T_Live`**: recorded as `never_touch`, `size unknown` (-1), not
  enumerated, not descended. Verified in the live run (see below).
- **Factory terminals** (`D:\QM\mt5\T1..T10`, `DEV*`, `FTMO_STREAM*`): `never_touch`,
  shallow immediate-level size only, internals not descended.
- **Junctions / reparse points** skipped via `st_file_attributes & 0x400`
  (`FILE_ATTRIBUTE_REPARSE_POINT`), not followed.
- **Per-root cap 200 000 entries**; on hit the walk stops descending and records an
  **explicit truncation note** (no silent caps). Partial sizes are flagged as partial.
- Report depth default 4 (deeper subtree bytes still roll up into ancestor totals).
- No hashing of large files — backup sidecars are only *checked for existence*.

## Live run (measured)

Command: `python tools/ops/filesystem_inventory.py`
Output dir: `D:\QM\reports\state\filesystem_inventory\20260821T141316Z\`
Files: `inventory.json` (~24 MB), `inventory_summary.md` (~19 KB)
Total wall time: **8.78 s** (target < 15 min).

| root | exists | entries | truncated | elapsed |
|---|---|---|---|---|
| `C:\QM` | yes | 200,000 | **YES** | 4.85s |
| `D:\QM\data` | yes | 56,001 | no | 0.26s |
| `D:\QM\reports` | yes | 200,000 | **YES** | 1.86s |
| `D:\QM\exports` | yes | 134 | no | 0.0s |
| `D:\QM\strategy_farm` | yes | 106,870 | no | 1.81s |
| `G:\My Drive\QM_Backups` | yes | 4 | no | 0.0s |

`C:\QM` and `D:\QM\reports` hit the 200k cap — their totals are explicitly marked partial
in both JSON (`truncated:true`, `truncation_note`) and the markdown roots table. This is
the contracted behaviour, not a silent cap. (An earlier full-fidelity run is also on disk
at `...\20260821T141133Z\`.)

### Notable measured facts (evidence, not claims)

- **T_Live hard-skip fired:** node `C:\QM\mt5\T_Live` = `never_touch`, `descended=False`,
  `size_bytes=-1`, note "contents never inventoried".
- **Largest active runtime:** `D:\QM\strategy_farm` 141.5 GB / 68,658 files; dominated by
  `artifacts\q09_live_news_backfill_20260805` (109.1 GB) — the live-book news backfill
  chain (do not displace).
- **Backup restore-status:**
  - `G:\My Drive\QM_Backups\hyonix_backup_2026-08-19.zip` (62 MB) — SHA256 sidecar
    **present** (all_have_sidecar=True), newest backup 2026-08-19.
  - `G:\My Drive\QM_Backups\git_bundles\...unpushed-delta...bundle` — **no sidecar** (⚠).
  - `D:\QM\strategy_farm\state\backups` — 31 sqlite snapshots, **no sidecars** (⚠) sitting
    directly beside live state (matches the programme's "aktive DB neben Backups" finding).
- **Unknown / needs-review (155 nodes):** `C:\QM` top-level (127.8 GB) and the
  `C:\QM\mt5\DXZ_Truth_*` truth/reference terminals (~116 GB total) are unmapped and
  correctly surfaced for review — the fail-safe, not a delete order. A follow-up rule for
  the DXZ_Truth_* terminals (they are custom-history reference terminals, live-adjacent)
  would move them out of "unknown"; left as review here deliberately.

### Retention rollup (emitted nodes, latest run)

| retention | node count |
|---|---|
| keep | 22,472 |
| archive | 9,943 |
| candidate_for_cleanup_review | 14,783 |
| never_touch | 1 (T_Live) |

## Tests

```
python -m pytest tools/ops/test_filesystem_inventory.py -q
22 passed in 0.30s
```

Coverage: known-prefix classification, most-specific-prefix-wins
(`state/backups` beats `state`), **unknown→review fail-safe**, retention-enum-has-no-delete,
T_Live never_touch+no-descend, factory-terminal no-descend, backup sidecar detection
(present + missing + all-present), truncation note emitted / not emitted, report-depth
limits emitted nodes but not aggregation, missing-root marked.

## Rollback

Pure additive: two new files under `tools/ops/`, output only under
`D:\QM\reports\state\filesystem_inventory\<ts>\`. No existing file, verdict, report,
registry, or config touched. Rollback = delete the two new tool files and the output
directories; nothing else is affected.

## Not done / deferred (for orchestrator)

- Classification rules for `C:\QM\mt5\DXZ_Truth_*` and `C:\QM` top-level misc (currently
  correctly `unknown`→review). One-line follow-up if desired.
- Actual retention *actions* are explicitly out of scope (ROT-adjacent: deletion needs
  OWNER review per the programme's "erst simulieren, dann Owner-reviewen, erst danach
  löschen"). This deliverable is the simulate/inventory step only.
