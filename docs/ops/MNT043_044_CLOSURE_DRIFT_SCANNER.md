# MNT-043/MNT-044 Closure-/Drift-Scanner

Status: implemented as a standalone, read-only maintenance instrument. This
closes the deterministic discovery and append-only re-adjudication mechanism;
it does **not** compile, rerun, deploy, mutate pipeline verdicts, or operate
Factory/T_Live.

## Safety contract

`tools/strategy_farm/mnt_closure_drift.py`:

- opens `farm_state.sqlite` through SQLite URI `mode=ro`, enables
  `PRAGMA query_only=ON`, takes a read transaction, then rolls it back;
- never imports or calls `farmctl`, terminal workers, MT5 runners, Factory
  scripts, deploy scripts, or T_Live tools;
- never updates `work_items`, `portfolio_candidates`, or another runtime table;
- prints the report to stdout unless `--report-out` is explicit;
- writes a report with create-only mode and refuses an existing destination;
- appends re-adjudications only to an external JSONL overlay. Existing bytes are
  validated and retained; every event is SHA-256 chained and duplicate event IDs
  are not appended;
- emits `HOLD_OWNER_REVIEW` for live findings. It performs no automatic live
  removal, replacement, restart, deploy, or AutoTrading action.

FACTORY_OFF is an intentional operating condition for the present closure work,
not something this tool may change.

## Cohorts and lineage

The scan assembles a deterministic union of:

1. every row in `portfolio_candidates`;
2. every Q10 `done/PASS` work item;
3. explicit `--portfolio-manifest` and `--live-manifest` inputs;
4. by default, the runtime live pointer, falling back to
   `tools/strategy_farm/config/live_deployment.json` when the pointer is absent.

Manifest authority is recorded as `SIGNED_RUNTIME`,
`RUNTIME_UNAUTHENTICATED`, `FALLBACK_UNAUTHENTICATED`, or `EXPLICIT`; an
unauthenticated fallback never becomes signed by being readable.

DB memberships recursively follow only the recorded
`payload_json.promoted_from_work_item` chain. `cohort_coverage` distinguishes:

- `BOUND_PASS`: the exact recorded lineage reaches an effective PASS;
- `BOUND_HOLD`: lineage exists, but its evidence is stale/unverified;
- `PAIR_ONLY_UNBOUND`: an EA/symbol row exists but is not in recorded lineage;
- `MISSING`: no PASS row exists for the requested phase;
- `SUBJECT_CLOSURE_HOLD`: a gate row closes but current subject artifacts do not.

An EA/symbol near-match is diagnostic only and can never mint admission.

## Closure and artifact contract

For each subject the scanner resolves and hashes:

- canonical MQ5 source;
- recursively resolved repo-local MQL5 include closure, using repo-relative POSIX
  paths and a canonical aggregate SHA-256;
- canonical and manifest-addressed EX5 files;
- baseline/live setfiles and a canonical input-map digest;
- candidate/Q10 evidence files;
- every recorded hash pin from DB payloads and manifests.

Platform includes such as `Trade/*` are listed separately because their bytes
belong to the compiler installation. An unresolved repo/QM include is a closure
error. mtimes are never used as provenance.

`CLOSED` requires recorded hashes to agree with observed bytes. Existing bytes
without a recorded hash are `UNBOUND`, not PASS. Hash disagreement is `DRIFT`;
missing/unreadable artifacts are `MISSING`.

## Q06/Q07 re-adjudication

Every historical Q06/Q07 `work_items.status='done' AND verdict='PASS'` row is
snapshotted and hashed. The original row is never altered. The scanner assigns
zero or more deterministic reason classes, including the converged MNT-044 set:

- `MISSING_FILE`
- `UNREADABLE`
- `NULL_KPI`
- `ZERO_VARIANCE`
- `PARSE_ERROR_BACKFILL`
- `SEED_AUTH_MISSING`
- `IDENTITY_HASH_MISSING`
- `BINARY_VINTAGE_MISMATCH`

It also exposes scope/verdict/content/setfile/closure mismatch subclasses where
applicable.

Q07 authentication reads the canonical seed registry, requires the exact
aggregate seed set, and for each seed verifies the co-located pair:

1. HARSH seeded set label from that run's `tester.ini`;
2. effective `qm_rng_seed` from that same run's report Inputs region.

It also binds aggregate -> summary hash, summary -> report/tester hashes,
MQ5/EX5/set hashes, current recursive source closure, EA, symbol, and time/run
identity. A path without a recorded hash is not an identity binding.

Effective status precedence is:

1. binary/source/closure drift -> `EVIDENCE_VINTAGE_STALE`;
2. any other reason class -> `PROVENANCE_UNVERIFIED`;
3. no reason -> `PASS`.

Live membership changes only the priority (`P0_LIVE`) and action template
(`HOLD_OWNER_REVIEW`); it never changes T_Live.

## Usage

Read-only scan to stdout:

```powershell
python tools/strategy_farm/mnt_closure_drift.py scan
```

Add explicit staged/portfolio manifests and create a new immutable report:

```powershell
python tools/strategy_farm/mnt_closure_drift.py scan `
  --portfolio-manifest D:\QM\reports\portfolio\portfolio_manifest_sunday_FINAL22_TOTALRISK12_20260726.json `
  --report-out D:\QM\reports\maintenance\mnt043_044_scan_20260729T0830Z.json
```

The parent directory must already exist and the destination must not.

Append proposed states to an external overlay:

```powershell
python tools/strategy_farm/mnt_closure_drift.py append-overlay `
  --report D:\QM\reports\maintenance\mnt043_044_scan_20260729T0830Z.json `
  --overlay D:\QM\reports\maintenance\mnt_adjudication_overlay.jsonl `
  --reviewer OWNER-approved-maintenance-session
```

Read the latest append-only state per work item:

```powershell
python tools/strategy_farm/mnt_closure_drift.py effective-overlay `
  --overlay D:\QM\reports\maintenance\mnt_adjudication_overlay.jsonl
```

Schemas:

- `tools/strategy_farm/schemas/mnt_closure_drift_report_v1.schema.json`
- `tools/strategy_farm/schemas/mnt_adjudication_overlay_event_v1.schema.json`

## Remaining operational closure

The scanner intentionally leaves these actions pending:

1. review and ratify a concrete P0/P1 bill from a retained full report;
2. clean QM5_20096 `TEMP DIAG` in its own source change;
3. produce immutable build manifests binding compiler version, MQ5/include
   closure and staged EX5 SHA for each selected EA;
4. compile outside T_Live, perform static seed/stress/order-path wiring checks,
   and canary the halt channel on tester/demo;
5. create new Q06/Q07 work items bound to the new binary/set/window identity;
6. integrate the effective-overlay reader into admission/dashboard consumers in
   a separate reviewed change; until then the overlay is evidence, not a hidden
   runtime mutation;
7. any T_Live deploy remains a separate OWNER-signed manifest action.
