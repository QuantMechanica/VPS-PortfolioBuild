# Tester-cache purge evidence-retention guard

Date: 2026-08-22  
Router task: `862b3123-40a4-4f65-abea-ddb359c8ed4d`  
Authorization: `OWNER-DEC-EVIDENCE-RETENTION`

## Verdict

PASS — `tester_cache_purge.ps1` now constructs a fail-closed exclusion plan
from every `portfolio_candidates` EA/symbol pair and every sleeve in the
hash-bound OWNER live manifest before any purge-mode deletion. A matching gate
`aggregate.json` or verdict-bearing JSON protects its entire top-level purge
target. An unclassifiable gate artifact is protected conservatively. If the DB,
schema, live-pulse binding, manifest hash/content, or cache scan cannot be
validated, the purge is skipped and exits non-zero.

No existing evidence or tester cache was deleted during implementation or
verification. T_Live was read-only; no terminal, worker, dispatcher, or
AutoTrading state was changed. The PowerShell integration checks used
`-DryRun` only.

## Scope clarification

The existing incident audit (`docs/ops/OQ8_EVIDENCE_LOSS_REPORT.md`) correctly
states that the scheduled tester-cache purge does not target
`D:/QM/reports/work_items`; the historical deletion event there remains
unattributed. The pre-change purge did, however, recursively remove idle
`T1`–`T10/Tester/Agent-*` directories without inspecting JSON evidence inside
them. This change implements the OWNER's defense-in-depth retention rule for
that actual destructive scope and does not rewrite the historical root-cause
finding.

## Before / after

Before:

- Low-water purge enumerated each immediate `Tester/bases/*` child and every
  `Tester/Agent-*` directory.
- Except for active-terminal and path-containment checks, each target reached
  unconditional recursive `Remove-Item`.
- The script did not read `portfolio_candidates`, the live manifest, or gate
  JSON identities; there was no evidence-target exemption and no fail-closed
  source-generation path.

After:

- New `tester_cache_purge_guard.py` opens the farm DB read-only and requires the
  `portfolio_candidates(ea_id,symbol)` schema.
- It reads `live_book_pulse.json`, requires a loaded `LIVE` manifest binding,
  verifies the manifest's SHA-256, requires its approval metadata, and checks
  exact pulse/manifest pair and sleeve-count agreement.
- DB and live pairs are normalized and unioned. Basket register identifiers are
  preserved; their host/chart pairs are independently retained from the live
  manifest.
- Every deletion candidate is scanned. Exact `aggregate.json`, filenames
  containing `verdict`, and any JSON containing a recursive `verdict` key are
  treated as gate evidence. A protected pair match retains the whole candidate
  target; incomplete identity also retains it fail-closed.
- Scan/read/schema/hash errors return structured `ERROR`. PowerShell logs
  `PURGE_SKIP_EVIDENCE_EXCLUSION_ERROR` and exits 3 before BusyScratch or idle
  cache deletion.
- After idle slots stop, the exclusion plan is refreshed before deletion. A
  refresh error skips all idle-cache removal, follows the existing captured
  factory-state restoration path, then exits 3. This closes the scan-to-delete
  race for idle targets.
- With a valid plan and no protected artifact, the existing low-water,
  active-terminal protection, containment, telemetry, and restart behavior is
  unchanged.

## Live read-only measurement

Command:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File C:/QM/repo/tools/strategy_farm/tester_cache_purge.ps1 `
  -Mode IdleCaches -DryRun
```

Observed at `2026-08-22T10:30:55Z`:

- `portfolio_candidate_pairs=38` (41 rows collapse to 38 distinct pairs)
- `live_manifest_pairs=24`
- `protected_union_pairs=40`
- `targets_scanned=21`
- `protected_targets=0` (no gate JSON was present in the current cache targets)
- signed manifest SHA-256
  `8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`
- D: free `129.09 GB`, below the unchanged `150 GB` low-water threshold
- result: dry-run message only; no stop, purge, or restart action

The target count is intentionally live and can change as MT5 agent directories
appear/disappear. Zero current protected targets means the ordinary purge
selection is unchanged today; the fixture tests below prove the exemption when
protected artifacts exist.

## Fail-closed injection

The same DryRun command with a deliberately absent `-FarmDbPath` produced:

```text
PURGE_SKIP_EVIDENCE_EXCLUSION_ERROR reason=farm_db_missing:C:\Windows\Temp\qm_missing_purge_guard_db.sqlite
PURGE_GUARD_EXIT=3
```

The error occurred before any purge branch. No fallback list or purge-forward
behavior exists.

## Focused verification

- PowerShell parser: PASS, zero syntax errors.
- `python -m py_compile tools/strategy_farm/tester_cache_purge_guard.py`: PASS.
- Live helper plan: PASS, 38 DB pairs + 24 live pairs = 40-pair union; current
  signed manifest/pulse hashes match.
- `pytest`:
  `test_tester_cache_purge_guard.py` plus
  `test_factory_watchdog_interactive_heal_static.py`: **8 passed**.

The new tests prove:

1. a DB-candidate `aggregate.json` target is exempt;
2. a live-manifest verdict artifact target is exempt;
3. an unrelated target remains eligible for the unchanged purge path;
4. unclassified gate evidence is retained conservatively;
5. manifest hash drift and missing DB both fail closed; and
6. PowerShell calls the guard before every deletion class, refreshes after
   worker stop, skips protected targets, and retains the ordinary recursive
   deletion statement for non-protected targets.

## Changed files

- `tools/strategy_farm/tester_cache_purge_guard.py`
- `tools/strategy_farm/tester_cache_purge.ps1`
- `tools/strategy_farm/tests/test_tester_cache_purge_guard.py`

The scheduled task definition remains unchanged and continues to invoke the
canonical `C:/QM/repo/tools/strategy_farm/tester_cache_purge.ps1` on its existing
cadence.
