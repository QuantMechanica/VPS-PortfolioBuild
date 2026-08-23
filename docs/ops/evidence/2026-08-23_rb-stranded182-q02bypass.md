# rb-stranded182-q02bypass evidence — 2026-08-23

## Scope and authority

Ticket: `rb-stranded182-q02bypass`.

The OWNER decision records “alle drei genehmigt” and explicitly approves both the
182-pair `INFRA_FAIL` → `INVALID` disposition and closure of the
`STALE_BUILD_RESULT_AUTO_Q02_BYPASS` hold while retaining the fail-closed snapshot
guard (`decisions/2026-08-23_owner_decisions_evening_batch_2.md:10`). The reviewed
census identifies the 182 `DETERMINISTIC_NO_SUMMARY` pairs at
`docs/ops/evidence/2026-08-22_factory_blockers_census.md:33-60` and the exact stale
hold at `:155-160`. The rebaseline directive requires append-only handling and says
existing verdicts/reports are never overwritten (vault directive `03 Pipeline/Pipeline
Rebaseline Directive 2026-08-23.md:85`). No gate threshold or criterion was changed.

## A — OWNER-DEC-STRANDED-182

### Dry-run and exact row record

The existing tool's help and census section 1 were read before execution. The governed
mode added at `tools/strategy_farm/classify_summary_missing.py:607` freezes the health
cohort SQL (`:83`), uses the documented deterministic tie-break
`updated_at DESC, created_at ASC, id ASC` (`:291`), and refuses any count other than the
OWNER-approved 182. Apply is hash-bound and append-only (`:381-462`) under the shared
factory mutation lock (`:395`).

Command:

```text
python tools/strategy_farm/classify_summary_missing.py --db D:/QM/strategy_farm/state/farm_state.sqlite --owner-decision OWNER-DEC-STRANDED-182 --expected-pairs 182 --dry-run --plan-out D:/QM/reports/state/rb-stranded182_q02_invalid_plan_20260823.json
```

Result: `pair_count=182`. The complete exact source-row list, pair identities, payload
hashes, and deterministic destination IDs is recorded in:

- Plan: `D:\QM\reports\state\rb-stranded182_q02_invalid_plan_20260823.json`
- Plan SHA-256: `b0be3c307145cedae393f38c9a6687fc31cf7b3a3a7c57dac0bfff9956c24548`
- Target-list SHA-256: `93b7319a4f50f825c89f4874b189f92f03cd67df278eae9b2850e2a9a36f4de5`

The dry-run performed no database writes. Its reviewed plan hash was supplied verbatim
to apply:

```text
python tools/strategy_farm/classify_summary_missing.py --db D:/QM/strategy_farm/state/farm_state.sqlite --owner-decision OWNER-DEC-STRANDED-182 --apply --plan D:/QM/reports/state/rb-stranded182_q02_invalid_plan_20260823.json --expected-plan-sha256 b0be3c307145cedae393f38c9a6687fc31cf7b3a3a7c57dac0bfff9956c24548 --receipt-out D:/QM/reports/state/rb-stranded182_q02_invalid_receipt_20260823.json
```

Apply result: `inserted_count=182`, `historical_verdict_rows_updated=0`, exit 0.

- Receipt: `D:\QM\reports\state\rb-stranded182_q02_invalid_receipt_20260823.json`
- Receipt SHA-256: `23dba7c83e1af73ad35ce0c734ada61af751216422a7dcb7c44125e2c0bfbb95`

Read-only post-query (`file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`) returned:

```json
{
  "quick_check": "ok",
  "source_rows_preserved": 182,
  "owner_invalid_rows": 182,
  "owner_events": 182
}
```

No backtest was enqueued: every appended row is terminal `status=failed`,
`verdict=INVALID`, and its payload records `backtest_enqueued=false`. Historical
`INFRA_FAIL` verdicts were not updated.

### Health before/after

Before (`farmctl health`, `checked_at=2026-08-23T17:34:01Z`):

```text
q02_stranded_exhausted_pairs status=FAIL value=270 detail="270 Q02 EA/symbol pairs have no non-infra terminal disposition, no queued successor, and >= 12 INFRA_FAIL rows"
```

After (`python tools/strategy_farm/farmctl.py health`, exit 0,
`checked_at=2026-08-23T17:55:23Z`):

```text
q02_stranded_exhausted_pairs status=FAIL value=88 detail="88 Q02 EA/symbol pairs have no non-infra terminal disposition, no queued successor, and >= 12 INFRA_FAIL rows"
```

The exact reduction is 182. The remaining 88 pairs are outside this OWNER decision and
therefore remain fail-closed; they were not modified.

## B — OWNER-DEC-Q02-BYPASS-88ba4560

The exact closure utility validates the OWNER artifact, held row, recovery lineage,
expected EX5 hash, and stable PASS/OK summary in read-only mode
(`tools/strategy_farm/close_q02_bypass_hold.py:66`). Apply takes the shared mutation
lock and an online SQLite snapshot (`:153`), performs an exact compare-and-swap hold
deactivation (`:181`), and appends a transition-ledger row plus event (`:200-211`). It
never deletes the hold or changes the held work-item verdict.

Before closure, the public-snapshot guard exited 3:

```json
{"active_incident_hold_count":1,"active_incident_holds":[{"hold_code":"STALE_BUILD_RESULT_AUTO_Q02_BYPASS","work_item_id":"88ba4560-fd7f-456f-903f-f4982d8f9cf3"}],"publication_allowed":false,"valid":true}
```

The active hold was created `2026-07-29T09:54:40+00:00` for
`QM5_20172/XTIUSD.DWX`; the held Q02 row is
`BLOCKED_STALE_BUILD_RESULT`. Dry-run bound closure to recovery work item
`bf7b7bfe-4dd3-4a11-8904-1a6b081717b0`, whose summary is PASS/OK with 94 trades,
stable expert binary, and required EX5 SHA-256
`0e01ada7d9f9711e70a20f032f5f0a6e5bb63adb3b5f6d26f1f295202412a2d5`.

Commands:

```text
python tools/strategy_farm/close_q02_bypass_hold.py --db D:/QM/strategy_farm/state/farm_state.sqlite dry-run --disposition-out D:/QM/reports/state/rb_q02_bypass_88ba4560_disposition_20260823.json
python tools/strategy_farm/close_q02_bypass_hold.py --db D:/QM/strategy_farm/state/farm_state.sqlite apply --disposition D:/QM/reports/state/rb_q02_bypass_88ba4560_disposition_20260823.json --expected-disposition-sha256 41b1c6477dca3fd15f8525201c46ca4cd3caef9306acdeb12c45f38e53fb86e0 --receipt-out D:/QM/reports/state/rb_q02_bypass_88ba4560_receipt_20260823.json --snapshot-path D:/QM/reports/state/farm_state_pre_q02_bypass_close_20260823.sqlite
```

Artifacts:

- Disposition: `D:\QM\reports\state\rb_q02_bypass_88ba4560_disposition_20260823.json`, SHA-256 `41b1c6477dca3fd15f8525201c46ca4cd3caef9306acdeb12c45f38e53fb86e0`
- Receipt: `D:\QM\reports\state\rb_q02_bypass_88ba4560_receipt_20260823.json`, SHA-256 `b032f7a6e51aa64c4300088e8bdd6f787a844a08b373670c3a4fa64390eaa0ad`
- Pre-close online snapshot: `D:\QM\reports\state\farm_state_pre_q02_bypass_close_20260823.sqlite`, SHA-256 `6a5e56ee52026b8f91f342baf032856ecd9a12bf00ae9e6f39ceb46588cc3d94`

Read-only post-query returned `PRAGMA quick_check=ok`, `active=0`,
`released_at=2026-08-23T17:55:43+00:00`, one
`release_q02_bypass_hold` ledger row, one `q02_bypass_hold_closed` event, and zero
deleted rows.

After closure, the unchanged guard exited 0:

```json
{"active_incident_hold_count":0,"active_incident_holds":[],"publication_allowed":true,"valid":true}
```

## Public snapshot read-only export

The first `-DryRun` found a PowerShell 5.1 adapter-property defect: an ordered gate map
was enumerated as `Count/Keys/...` and rejected as `Invalid pipeline.by_gate_v4.Count`.
`Get-ObjectKeys` now enumerates dictionary keys explicitly
(`scripts/export_public_snapshot.ps1:54,98`) without changing the existing Q00-Q17 or
nonnegative validation criteria. The exporter remained fail-closed until this was fixed.

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/export_public_snapshot.ps1 -RepoRoot C:\QM\worktrees\rb-stranded182-q02bypass -PublicDataDir C:\QM\worktrees\rb-stranded182-q02bypass\public-data -PipelineStatePath D:\QM\reports\state\pipeline_state.json -DryRun
```

Final result: exit 0; rendered Q00-Q17, 3,840 strategy archive items and 16 roadmap
items; emitted `[DryRun] Skipping git + Netlify.` (`scripts/export_public_snapshot.ps1:346-351`).
No public-data file was written or staged.

## Tests

Targeted module tests before the exporter compatibility fix:

```text
python -m pytest -q tools/strategy_farm/tests/test_stranded182_q02_bypass.py tools/strategy_farm/tests/test_summary_missing_classification.py tools/strategy_farm/tests/test_public_snapshot_incident_guard.py
36 passed in 2.74s
```

Exporter regression after the fix (`tools/strategy_farm/tests/test_stranded182_q02_bypass.py:166`):

```text
python -m pytest -q tools/strategy_farm/tests/test_stranded182_q02_bypass.py
3 passed in 2.58s
```

Final touched-module regression run (after switching the classifier to the repository's
shared identity-safe mutation-lock implementation):

```text
python -m pytest -q tools/strategy_farm/tests/test_stranded182_q02_bypass.py tools/strategy_farm/tests/test_summary_missing_classification.py tools/strategy_farm/tests/test_public_snapshot_incident_guard.py
37 passed in 5.25s
```

Existing exporter/operator integration tests:

```text
python -m pytest -q tools/strategy_farm/tests/test_operator_surfaces_rebaseline.py tools/strategy_farm/tests/test_factory_quiescence.py tools/strategy_farm/tests/test_pipeline_state_installer.py
23 passed in 4.81s
```

The append-only classification and hold-close tests are at
`tools/strategy_farm/tests/test_stranded182_q02_bypass.py:33,84`.

The requested complete suite was also run:

```text
python -m pytest -q tools/strategy_farm/tests
317 failed, 4180 passed, 4 skipped, 2 warnings, 42 subtests passed in 1494.47s (0:24:54)
```

The full-suite failures are pre-existing/shared-environment failures spread across
untouched areas (including `agent_router`, Q09/Q10/Q14-Q16, registry, target dossiers,
task notifier, and terminal-worker process fixtures); concurrent repository-wide pytest
processes were active on the host during this run. No test in the three ticket/touched
module files failed, and the isolated final run above is clean.

`python -m py_compile` passed for `classify_summary_missing.py`,
`close_q02_bypass_hold.py`, and `public_snapshot_incident_guard.py`.

## Rollback / recovery

- Stranded dispositions: never delete or rewrite the 182 source or disposition rows.
  If the classification must be reversed, obtain OWNER approval and append an explicit
  superseding disposition referencing the plan and receipt hashes.
- Hold: do not restore the whole snapshot over a moving live database. A rollback must
  be a new OWNER-approved compare-and-swap reactivation of this exact hold with appended
  ledger/event evidence. The online snapshot is emergency/forensic recovery material.
- Exporter compatibility code: revert the ticket commit; the dry-run changed no public
  snapshot data.

No `T_Live` path was touched, AutoTrading/factory state was not toggled, no backtest was
enqueued or deleted, no historical verdict was overwritten, and no gate threshold or
criterion changed.

### Known representation caveat

The applied 182 rows have the authoritative terminal columns `status=failed` and
`verdict=INVALID`, but a final read-only integrity review found that the applied version
of the tool populated the auxiliary SH-1 cache columns as
`verdict_taxonomy_stored=infra`, `clean_status_stored=invalid`. Query result:
`total=182, taxonomy_ok=0, clean_status_ok=0`. The clean view and the health predicate
derive from the authoritative status/verdict and therefore report the intended INVALID
disposition, but SH-1 validation will report these cache rows as drift.

The committed implementation and regression test now emit/require the contract-correct
cache pair `invalid/failed`. The live rows were deliberately not updated a second time:
that would violate this ticket's explicit single-mutation, append-only boundary. Repair
of the auxiliary caches requires a separate OWNER-authorized, receipt-bound correction;
it must not rewrite the verdict or delete/reinsert any disposition row.
