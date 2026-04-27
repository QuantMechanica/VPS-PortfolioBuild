# Infra Scripts Notes

## `dwx_hourly_check.py`

- `spec_ok` is now evaluated by one shared helper (`is_symbol_spec_ok`) for both:
  - readiness gate (`spec_bad` aggregation)
  - per-symbol readiness report row (`spec_ok` column)
- Verifier output is parsed by `summarize_verify_failures(...)` to detect systemic
  runtime patterns before opening per-symbol investigations:
  - `systemic_zero_bars`: >= 10 FAIL rows where all have `bars expected > 0` and `got=0`
  - `systemic_zero_mid_ticks`: >= 10 FAIL rows where all have `mid_ticks_5min=0`
  - These are logged as verifier/runtime conditions, not symbol-specific corruption.
  - Parser contract covers real verifier row shapes with leading verdict spacing
    (for example `[ FAIL_tail_bars] XAGUSD.DWX: ...` and
    `[FAIL_tail_mid_bars] XNGUSD.DWX: ...`) and trailing fields.
- One-command triage on a captured verifier log:
  - `python -c "from pathlib import Path;import importlib.util as u;p=Path(r'C:\QM\repo\infra\scripts\dwx_hourly_check.py');s=u.spec_from_file_location('m',p);m=u.module_from_spec(s);s.loader.exec_module(m);t=Path(r'C:\QM\repo\infra\smoke\verify_import_run_2026-04-27_qua19.log').read_text(encoding='utf-8',errors='replace');print(m.summarize_verify_failures(t))"`
- Criterion:
  - `custom.trade_tick_value > 0`
  - `broker.trade_tick_value > 0`
  - `abs(custom.tv - broker.tv) / broker.tv < 0.05`
- Phase-B staging now includes CSV tail-alignment gate:
  - compares tick CSV tail vs M1 CSV tail (`MAX_CSV_TAIL_GAP_HOURS=1.0`)
  - symbols with stale/misaligned tails are deferred and not queued for import
  - already-imported symbols still emit a warning when tails are misaligned
- No `tvp` / `tvl` fields are used for gate decisions.

## `verify_import_preflight_probe.py`

- Non-production helper for targeted verifier investigation on one symbol.
- Compares MT5 read paths directly:
  - `copy_ticks_range(...)` window counts (head/mid/tail)
  - `copy_ticks_from(...)` window counts (head/mid/tail)
  - `copy_rates_range(...)` bar count over sidecar M1 range
- Includes lightweight pre-flight + retries to reduce session/cache timing noise.
- Example:
  - `python C:\QM\repo\infra\scripts\verify_import_preflight_probe.py --symbol XAUUSD.DWX`

## `check_dwx_csv_tail_alignment.py`

- Fast DWX CSV preflight: compares tail timestamp of tick CSV vs M1 CSV.
- Use before `prepare_import.py`/verifier runs to catch stale or internally
  misaligned exports.
- Exit codes:
  - `0`: aligned within threshold
  - `1`: misaligned/stale beyond threshold
  - `2`: missing files
  - `3`: empty tails
- Example:
  - `python C:\QM\repo\infra\scripts\check_dwx_csv_tail_alignment.py --symbol XAUUSD --max-gap-hours 1 --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua93_xauusd_tail_alignment_check.json`

## `verify_import_candidate.py`

- Candidate (non-production) verifier behavior for handoff testing.
- Proposed deltas vs live verifier:
  - mid/tail probes use `copy_ticks_from(...)` windows
  - bounded tail tolerance (`--tail-tolerance-ms`, default `180000`)
  - degraded bars classification (`WARN_bars_unavailable`) when ticks exist but M1 bars API returns zero
- Example:
  - `python C:\QM\repo\infra\scripts\verify_import_candidate.py --symbol XAUUSD.DWX`

## `patches/verify_import_candidate_port.patch`

- Unified diff artifact from live verifier:
  - `D:\QM\mt5\T1\dwx_import\verify_import.py`
  - to candidate logic in `infra/scripts/verify_import_candidate.py`
- Purpose: accelerate owner-side review/apply of tested read-path hardening.
- Generated in this issue heartbeat; regenerate by diffing the same two files when either side changes.

## `probe_verify_rates_span.py`

- Read-only MT5 probe for verifier investigations.
- Compares one-shot `copy_rates_range(...)` across the full sidecar span vs
  chunked `copy_rates_range(...)` windows.
- Also prints a short tail-window sample (`--tail-hours`, default `24`) and
  symbol metadata (`selected/visible/custom/path`) to distinguish range-query
  param issues from "no bars visible" runtime conditions.
- Use to confirm/quantify range-query limits (`Invalid params` / empty results)
  before classifying a symbol as corrupted.
- Default target is `WS30.DWX`; span comes from latest
  `imports\\done\\*_<symbol>.import.txt`.

## `probe_custom_symbol_visibility.py`

- Read-only MT5 probe that compares a custom symbol (for example `XTIUSD.DWX`)
  against its broker/source symbol (for example `XTIUSD`).
- Uses both bars APIs:
  - `copy_rates_range(...)`
  - `copy_rates_from_pos(...)`
- Also captures recent ticks (`copy_ticks_from(...)`) for context.
- Emits `isolated_custom_bars_visibility_failure=true` when:
  - source bars are available, and
  - custom bars are zero/failing in the same session.
- Exit codes:
  - `0`: no isolated custom-bars failure detected
  - `1`: isolated custom-bars visibility failure detected
  - `2`: MT5 init failed
- Example:
  - `python C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py --target XTIUSD.DWX --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe.json`

## `Test-QUA95HandoffIntegrity.ps1`

- Verifies SHA256 integrity for the QUA-95 handoff package files listed in:
  - `docs\ops\QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256`
- Fails (`exit 1`) when any file is missing, a hash mismatches, or manifest rows are malformed.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95HandoffIntegrity.ps1`

## `Write-QUA95BlockedSummary.ps1`

- Renders a concise blocked-status markdown summary from:
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Default output:
  - `docs\ops\QUA-95_BLOCKED_COMMENT_2026-04-27.md`
- Useful for posting/attaching a deterministic issue status comment.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Write-QUA95BlockedSummary.ps1`

## `Update-QUA95BlockerStatus.ps1`

- Refreshes `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json` from latest rerun evidence:
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_rerun_evidence.json`
- Updates symbol verdict, bars/tail fields, disposition, acceptance flag, and check timestamp.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Update-QUA95BlockerStatus.ps1`

## `Install-QUA95BlockerRefreshTask.ps1`

- Idempotently installs a Windows Scheduled Task that runs:
  1. `Invoke-VerifyDisposition.ps1` (`QUA-95`, `XTIUSD.DWX`)
  2. `Update-QUA95BlockerStatus.ps1`
  3. `Write-QUA95BlockedSummary.ps1`
  4. `Test-QUA95HandoffIntegrity.ps1`
- Defaults:
  - task name: `QM_QUA95_BlockerRefresh`
  - interval: `60` minutes
  - principal: `SYSTEM` (highest)
- Preview mode (no task registration):
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95BlockerRefreshTask.ps1 -PreviewOnly`

## `verify_import_chunked_probe.py`

- Read-only verifier mirror for symbol-level deep dive.
- Reuses verifier checks (head/tail/mid/spec) and compares:
  - full-span `copy_rates_range(...)` count
  - position-based `copy_rates_from_pos(...)` counts (pos `0`, `1000`)
  - chunked `copy_rates_range(...)` count
- Prints `terminal_maxbars` so evidence can distinguish:
  - MT5 chart-history cap effects (for example 100k cap), vs
  - genuine zero-bars visibility for a symbol.
- Supports `--json-out <path>` to emit machine-readable probe payloads for
  issue evidence/handoff.

## `verify_import_chunked_probe.py`

- Non-production probe that mirrors `verify_import.py` checks for one symbol.
- Keeps tick checks intact, but compares:
  - one-shot full-span M1 read (current verifier shape)
  - chunked M1 range reads (diagnostic/fix candidate)
- Helps decide whether `FAIL_bars` is query-shape/API-limit related vs data loss.
- Also reports source-vs-custom tail parity (`custom_minus_source_tail_ms`) so
  tail failures can be classified as symbol corruption vs expectation-basis mismatch.

## `verify_import_candidate.py`

- Repo-side candidate replacement for production `verify_import.py`.
- Uses chunked M1 reads + `terminal.maxbars`-aware bar expectations.
- Keeps existing tick/spec checks and outputs one-shot vs chunked bar diagnostics.
- Supports `--tail-basis sidecar|source`:
  - `sidecar`: strict match to archived `tick_last_ms`
  - `source`: compare custom tail to broker source tail in same window (`--tail-tol-ms`)
- Useful handoff artifact to the verifier owner; does not mutate production files.

## `summarize_verify_candidate_log.py`

- Parses `verify_import_candidate.py` log output and reports:
  - total parsed rows
  - unique symbol count
  - verdict distribution for all rows
  - verdict distribution by latest row per symbol
- list of latest `OK` symbols

## `Verify-HandoffIntegrity.ps1`

- Validates SHA256 entries in `docs/ops/QUA-91_WS30_VERIFIER_HANDOFF_2026-04-27.sha256`.
- Outputs per-file `OK/FAIL` plus final `checked`/`failed` counters.

## `Run-QUA91-HandoffChecks.ps1`

- Single entrypoint for QUA-91 closeout checks:
  - runs `Verify-HandoffIntegrity.ps1`
  - runs `summarize_verify_candidate_log.py` against the candidate run log

## `Invoke-VerifyDisposition.ps1`

- Idempotent verifier rerun helper for issue triage.
- Runs `verify_import.py`, captures a timestamped raw log under `infra\\smoke\\`,
  parses FAIL rows, and writes tracked evidence JSON under
  `lessons-learned\\evidence\\`.
- Parser supports both verifier output schemas for bars fields:
  - legacy `bars expected=.../got=...`
  - newer `bars_sidecar_expected=...; ... bars_chunked=...`
- Emits symbol-level disposition:
  - `clear`: `bars_got > 0` and tail timestamps aligned
  - `defer`: systemic zero-bars pattern or symbol bars still zero
  - `fix`: not clear/defer; investigation still in-flight
- Example:
  - `powershell -File C:\QM\repo\infra\scripts\Invoke-VerifyDisposition.ps1 -IssueId QUA-92 -Symbol XAGUSD.DWX`

## `Confirm-DwxRegistryMitigation.ps1`

- Idempotent QUA-69 confirmation helper for the `Fix_DWX_Spec_v3` registry-corruption mitigation.
- Pulls latest T1 terminal log + MQL5 log and checks:
  - successful script close events (`Fix_DWX_Spec_v3 ... closes terminal with code 0`) >= `-MinSuccessfulRuns` (default `3`)
  - throttle markers present (`BATCH|processed=5|sleep_ms=200`)
  - `symbols.custom.dat` exists and is above truncation floor (`-MinSafeBytes`, default `16384`)
- Emits machine-readable evidence JSON:
  - default `C:\QM\repo\lessons-learned\evidence\qua69_registry_mitigation_confirmation.json`
- Optional failure gate:
  - pass `-FailOnInsufficientEvidence` to return exit code `2` when checks fail.
- Example:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Confirm-DwxRegistryMitigation.ps1 -FailOnInsufficientEvidence`
