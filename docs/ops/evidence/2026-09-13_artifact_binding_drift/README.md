# pending_artifact_binding_drift — diagnosis & governed repair plan (2026-09-13)

Health check `pending_artifact_binding_drift` = **FAIL**. This is a read-only
diagnosis. No DB writes, no git operations, no tools run in apply mode were
performed to produce it. `plan.json` (sibling file) carries the per-row proposals.

## 1. How the check is computed

`tools/strategy_farm/health.py :: chk_pending_artifact_binding_drift`
(mirrored read-only in `tools/strategy_farm/pending_artifact_binding_census.py`).
For every `work_items` row with `status='pending'` whose payload carries any of
`expected_ex5_sha256` / `expected_mq5_sha256` / `expected_setfile_sha256`, it
hashes the file on disk and compares raw SHA-256 (identical to the worker's
dispatch preflight):

- path derivation (`_pending_binding_artifact_paths`):
  `ea_dir_name = payload['ea_dir_name'] or setfile.parent.parent.name`;
  `ex5 = framework/EAs/<ea_dir_name>/<ea_dir_name>.ex5`, `.mq5` alongside,
  `setfile = row.setfile_path`.
- classification: file unreadable -> **MISSING**; hash equal -> OK; for mq5/setfile
  a match under LF/CRLF conversion -> **LINE_ENDINGS_ONLY**; otherwise
  **CONTENT_CHANGED**. EX5 is binary so every EX5 mismatch is CONTENT_CHANGED.

## 2. Census (own read-only reproduction, live DB, 2026-09-13)

`python -X utf8 tools/strategy_farm/pending_artifact_binding_census.py` (mode=ro):

| metric | value |
|---|---|
| bound pending rows checked | 812 |
| drifted rows | 354 |
| mismatched bindings | 707 |
| CONTENT_CHANGED / MISSING / LINE_ENDINGS_ONLY | 75 / 632 / 0 |
| rows HELD / FREE | 27 / 327 |

Bindings by (role, class): ex5 MISSING 316, mq5 MISSING 316, mq5 CONTENT_CHANGED 31,
setfile CONTENT_CHANGED 31, ex5 CONTENT_CHANGED 13. (Snapshot drifts vs the ticket's
719/360 because WINSWEEP cells clear as the factory runs; class shape is identical.)

## 3. Root-cause clusters

### C1 — WINSWEEP path-derivation FALSE POSITIVE (632 bindings / 316 rows, 89%)
All 316 are `QM5_41405`, phase `OPT_CENSUS`, **FREE**, MISSING ex5+mq5, all deriving
the **same nonexistent** dir `framework/EAs/WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025/`.
Their setfiles live **outside** framework/EAs, at
`D:\QM\strategy_farm\artifacts\opt_census\WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025\setfiles\`,
so `setfile.parent.parent.name` is the synthetic prescreen program, not an EA dir.
Payloads carry `expected_ex5_sha256` / `expected_mq5_sha256` but **no** `expected_ex5_path`.
**Verified**: `expected_ex5_sha256=a85371…` and `expected_mq5_sha256=d3d6fe…` match
`framework/EAs/QM5_41405_balke-clock-audit-opt/*.ex5/.mq5` **exactly**. The runner
resolves the real binary by ea_id (campaign is running fine); only the health/census
path derivation is wrong. **These rows are NOT drifted.** History shows no deleted/
renamed EA dir among any drifted ea_id — MISSING is entirely this artifact, not lost files.

### C2A — committed regeneration, stale binding (31 rows)
Real EAs (QM5_10203, 10593, 10649, 33007, 35005, 10717, 41359-62, …), phases
Q02/Q03/Q04/Q07/Q12/Q14. mq5/setfile/ex5 were regenerated and **committed** after the
row bound its SHAs (e.g. QM5_10593 setfile clean vs HEAD; last touched by
`1ccbdd4ab0 "overnight setfile regen wave" 2026-08-27`). Diff is **not cosmetic**: header
lines change **and** `qm_ea_id=` is added while the whole `qm_filter_news/regime/volatility`
input block is removed — a template/parameter change, so LINE_ENDINGS_ONLY does not apply.

### C2B — uncommitted foreign working-tree setfile edit (7 rows)
299 `framework/EAs/**/sets/*.set` are modified in the working tree (the in-progress
`set_version s20260912-001` regen wave); 7 of them back CONTENT_CHANGED setfile
bindings. **Do not touch these files** — commit-or-revert is an orchestrator decision.

## 4. Claim-time behaviour (what the check protects against)

`terminal_worker.py`: a claimed row runs `_prepare_staged_ex5` -> `_dispatch_ex5_requirement`.
An EX5 mismatch/absence raises `dispatch_ex5_source_sha256_mismatch` / `staged_ex5_missing`
(l.6836-6845); the caller (l.11618) routes to `_fail_work_item_preflight`, which sets
`status='failed', verdict='INFRA_FAIL'` (l.9038). setfile/mq5 SHAs are re-checked in
prestage/identity gates. So **FREE drifted rows are claimed and burned to INFRA_FAIL**
(not silently skipped); **HELD rows are parked** and stay pending. 27 drifted rows are
already parked with purpose-built holds (`ARTIFACT_BINDING_CONTENT_CHANGED`,
`ARTIFACT_BINDING_Q02_REQUALIFICATION_REQUIRED`, `ARTIFACT_BINDING_SETFILE_SUCCESSOR_REQUIRED`, …);
**11 CONTENT_CHANGED rows are FREE and at risk of an INFRA_FAIL burn.**

## 5. Governed repair options (dry-run only; nothing applied)

- **C1 (fix, not data change):** correct the derivation in `health.py` and
  `pending_artifact_binding_census.py` — resolve ex5/mq5 by ea_id (as the runner does),
  or honor `expected_ex5_path`, or skip binary roles when the setfile is outside
  framework/EAs. Codex ticket. Clears 632/707 (89%). **Never** rerun/retire these rows.
- **C2 FREE rows — park first (GREEN):** `governed_work_item_hold.py apply` (backup +
  BEGIN IMMEDIATE; never changes status) with `--hold-code ARTIFACT_BINDING_CONTENT_CHANGED`.
- **C2 setfile-only:** `farmctl requeue-false-invalid-setfile` (append-only successor,
  `--expected-current-ex5-sha256`, dry-run default).
- **C2 with ex5/mq5:** `farmctl requalify-q02` / `rebind-q02` (dry-run default) rebinds a
  Q02 successor to the current disk EX5. **A recompile in active inventory is ROT -> OWNER.**
  `farmctl enqueue-backtest --append-only-rerun-of` rebinds fresh SHAs but cites a
  *terminal* predecessor, so it applies only after a row lands INFRA_FAIL, not to a pending row.
- Q12/Q14 rows: park; phase-specific governed successor (requalify-q02 does not apply).

## 6. Decision points for the orchestrator

1. **C1 is a measurement bug, not lost artifacts** — approve the derivation fix; do not
   enqueue-rerun or retire 316 live WINSWEEP cells.
2. **C2B (7 rows):** decide commit-or-revert of the uncommitted `s20260912-001` .set regen
   wave before any setfile rebind (this diagnosis did not touch those files).
3. **C2A ex5/mq5 rows:** confirm whether the on-disk binary is the intended rebuilt EA
   (rebind, GELB) or a recompile is required (ROT -> OWNER) before rebinding.

## Most valuable action first

Commission the **C1 derivation fix** (Codex): it removes 632/707 false bindings and turns
FAIL(707) into FAIL(75), exposing the real drift — no data mutation, GREEN. Immediately
after, **park the 11 FREE C2 rows** with `governed_work_item_hold.py apply` to stop the
INFRA_FAIL burn while their governed successors are decided.
