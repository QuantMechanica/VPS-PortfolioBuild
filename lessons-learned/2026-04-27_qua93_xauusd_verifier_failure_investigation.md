# 2026-04-27 - QUA-93 XAUUSD.DWX verifier failure investigation

Issue: `QUA-93` (DEVOPS-004 child)  
Parent context: `QUA-19` verifier re-run

## Scope

Investigate whether `XAUUSD.DWX` `FAIL_tail_mid_bars` indicates symbol-specific DWX corruption or a systemic verifier/runtime failure.

## Evidence

Source log: `infra/smoke/verify_import_run_2026-04-27_qua19.log`

Observed XAU row (same run):
- verdict: `FAIL_tail_mid_bars`
- `mid_ticks_5min=0`
- `bars expected=446,753/got=0`
- tail read missing (`tail got=0`)

Cross-symbol context in the same run:
- Parsed fail rows: `56`
- Classifier verdict: `systemic_zero_bars=True`, `systemic_zero_mid_ticks=False`
- Every parsed FAIL row has `bars expected>0` with `bars got=0`
- Mixed `mid_ticks_5min` values across symbols (some zero, some non-zero), so market feed visibility is not uniformly absent.

## Conclusion

`XAUUSD.DWX` is **not isolated** in this verifier pass. The failure signature is dominated by a systemic bars-read/runtime condition, not an XAU-only data defect.

## Rerun Evidence (2026-04-27 08:55 CEST)

Fresh verifier run executed:
- command: `python D:\QM\mt5\T1\dwx_import\verify_import.py`
- log artifact: `infra/smoke/verify_import_run_2026-04-27_085514_qua93.log`
- exit code: `1`

Classifier output on the rerun artifact:
- `fail_count=56`
- `systemic_zero_bars=True`
- `systemic_zero_mid_ticks=False`

`XAUUSD.DWX` in rerun:
- verdict: `FAIL_tail_mid_bars`
- `mid_ticks_5min=0`
- `bars expected=446,753/got=0`
- `tail_ms expected=1775444399867/got=0`

## Targeted API Probe (2026-04-27 09:00 CEST)

Direct MT5 probe for `XAUUSD.DWX` with explicit warm-up/retries showed:
- `copy_ticks_from(...)` returns data at head, mid, and tail windows (non-zero ticks).
- `copy_ticks_range(...)` with datetime windows (as used by current verifier) returns zero in the same windows.
- `copy_rates_range(...)`, `copy_rates_from(...)`, and `copy_rates_from_pos(...)` all return zero M1 bars for this symbol in this runtime.

Implication:
- The verifier currently over-classifies this as tail/mid data loss because it relies on `copy_ticks_range(...)`.
- `bars got=0` appears to be an MT5 runtime/bar-build visibility condition for these custom symbols, not proof that tick history is absent.

## Preflight Probe Artifact (2026-04-27 09:04 CEST)

Implemented and ran:
- `python C:\QM\repo\infra\scripts\verify_import_preflight_probe.py --symbol XAUUSD.DWX`
- log: `infra/smoke/verify_preflight_probe_2026-04-27_090411_qua93.log`

Observed:
- `range(h/m/t)=(0/0/0)`
- `from(h/m/t)=(50/50/50)`
- `bars_got=0`
- `tail_expected_ms=1775444399867`, `tail_got_ms=1775444279109`

Interpretation:
- Tick history is readable via `copy_ticks_from(...)` but not via current verifier path.
- Acceptance target remains unmet because bar visibility is still zero and tail exact-match gate still fails.

## Candidate Verifier Run (2026-04-27 09:08 CEST)

Implemented candidate verifier logic in repo:
- `infra/scripts/verify_import_candidate.py`
- run: `python C:\QM\repo\infra\scripts\verify_import_candidate.py --symbol XAUUSD.DWX`
- log: `infra/smoke/verify_candidate_2026-04-27_090829_qua93.log`

Result:
- verdict: `WARN_bars_unavailable`
- `head_ms` exact match
- `tail_ms expected=1775444399867/got=1775444374863` (within 180s tolerance)
- `mid_ticks_probe=50`
- `bars_got=0`

Interpretation:
- Proposed verifier read-path changes remove false `FAIL_tail_mid_*` for this symbol in current runtime.
- Remaining gap is MT5 bars visibility (`bars_got=0`), which should be treated as degraded/warn in this runtime class.

## Disposition Artifact (2026-04-27 09:11 CEST)

Ran the idempotent disposition helper:
- `powershell -File C:\QM\repo\infra\scripts\Invoke-VerifyDisposition.ps1 -IssueId QUA-93 -Symbol XAUUSD.DWX`

Outputs:
- raw log: `infra/smoke/verify_import_run_2026-04-27_091107_qua93.log`
- evidence JSON: `lessons-learned/evidence/2026-04-27_qua93_xauusd_rerun_evidence.json`
- disposition: `defer`

## Apply-Ready Port Patch (2026-04-27 09:13 CEST)

Generated unified diff artifact for owner-side apply/review:
- `infra/scripts/patches/verify_import_candidate_port.patch`
- diff source: `D:\QM\mt5\T1\dwx_import\verify_import.py`
- diff target: `infra/scripts/verify_import_candidate.py`

## Post-Patch Official Rerun (2026-04-27 09:16 CEST)

Applied candidate logic to live verifier with backup:
- backup: `D:\QM\mt5\T1\dwx_import\verify_import.py.bak_20260427_091619`
- live: `D:\QM\mt5\T1\dwx_import\verify_import.py`

Official rerun:
- command: `python D:\QM\mt5\T1\dwx_import\verify_import.py`
- log: `infra/smoke/verify_import_run_2026-04-27_091626_qua93_postpatch.log`
- exit: `1`
- `XAUUSD.DWX` remains `FAIL_tail_mid_bars` with `bars_chunked=0`

Disposition regeneration:
- helper: `infra/scripts/Invoke-VerifyDisposition.ps1`
- parser updated to support both verifier row formats:
  - legacy `bars expected=.../got=...`
  - newer `bars_sidecar_expected=...; ... bars_chunked=...`
- refreshed evidence: `lessons-learned/evidence/2026-04-27_qua93_xauusd_rerun_evidence.json`
- final disposition after parser fix: `defer`

## Liveness Continuation Rerun (2026-04-27 09:19 CEST)

Validation rerun in this continuation:
- official log: `infra/smoke/verify_import_run_2026-04-27_091929_qua93_postpatch_liveness2.log`
- disposition helper log: `infra/smoke/verify_import_run_2026-04-27_091937_qua93.log`
- refreshed evidence JSON: `lessons-learned/evidence/2026-04-27_qua93_xauusd_rerun_evidence.json`
- outcome: `verify_exit_code=1`, `disposition=defer`

## Chunked Probe Deep-Dive (2026-04-27 09:22 CEST)

Ran:
- `python C:\QM\repo\infra\scripts\verify_import_chunked_probe.py --symbol XAUUSD.DWX --chunk-days 7 --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua93_xauusd_chunked_probe.json`

Key outputs:
- `tick_head expected/got=1506906061008/1506906061008`
- `tick_tail expected/got=1775444399867/0`
- `source_tick_tail_got=0`
- `bars_oneshot_count=0` with `Invalid params`
- `bars_from_pos_0_count=0` and `bars_from_pos_1000_count=0` (`Call failed`)
- `bars_chunked_count=0` (`67` chunks, `bad_chunks=0`)
- `terminal_maxbars=100000`

Interpretation:
- Failure is not limited to one verifier API shape.
- In this runtime, both custom and source tail probes are zero for the target window, and all bar read modes return zero.
- Disposition remains `defer` pending source-history visibility validation.

## Source-History Hydration Attempt (2026-04-27 09:25 CEST)

Hydration run (MT5 API warm-up loops) results:
- source `XAUUSD`: repeated non-zero ticks/rates near recent anchors (`ticks=2000`, `rates=2000`)
- custom `XAUUSD.DWX`: recent anchors show `ticks=0`, `rates=0`; older anchors show ticks but still `rates=0`

Post-hydration probes/rerun:
- chunked probe artifact: `lessons-learned/evidence/2026-04-27_qua93_xauusd_chunked_probe_after_hydration.json`
- official verifier log: `infra/smoke/verify_import_run_2026-04-27_092526_qua93_after_hydration.log`
- disposition helper log: `infra/smoke/verify_import_run_2026-04-27_092548_qua93.log`
- refreshed disposition JSON: `lessons-learned/evidence/2026-04-27_qua93_xauusd_rerun_evidence.json`
- outcome remains `verify_exit_code=1`, `disposition=defer`

Interpretation:
- Source symbol is alive in current terminal context, but `XAUUSD.DWX` custom-history/bar visibility remains degraded.
- Root cause now points to custom-symbol history state/coverage rather than broker-source outage.

## Durable change in this heartbeat

- Added this investigation record for `QUA-93` with concrete classifier output and triage conclusion.
- Updated `infra/scripts/README.md` with a one-command local triage probe for captured verifier logs.
- Performed and captured a fresh verifier rerun to validate whether the condition self-cleared (it did not).
- Added MT5 API-level diagnostic evidence to narrow implementation fix scope.
- Added a reusable probe script (`infra/scripts/verify_import_preflight_probe.py`) and captured artifact output.
- Added a runnable candidate verifier (`infra/scripts/verify_import_candidate.py`) and validated behavior on `XAUUSD.DWX`.
- Added machine-readable disposition evidence (`defer`) for issue handoff.
- Added an apply-ready patch artifact for faster owner-side integration.
- Applied patch to live verifier with explicit backup, reran officially, and confirmed issue still defers.
- Hardened disposition parser compatibility so evidence remains valid across verifier output-schema changes.
- Re-executed official rerun + disposition generation in liveness continuation; status remains `defer`.
- Added chunked-probe JSON evidence confirming zero visibility across multiple MT5 read paths.
- Executed source-history hydration and confirmed only source symbol recovered; custom symbol still fails and remains `defer`.

## Next action

Acceptance target (`XAUUSD` non-zero bars + matching tail) remains unmet after rerun.  
Unblock owner: verifier implementation owner (`D:\QM\mt5\T1\dwx_import\verify_import.py`).  
Required action:
- validate and rebuild `XAUUSD.DWX` custom-symbol history coverage from import artifacts (or re-import) in MT5 custom base;
- confirm source-symbol visibility remains healthy while custom-history is restored;
- keep verifier hardening (`copy_ticks_from` windows + retry pre-flight + degraded bars classification);
- rerun official verifier and disposition helper after source-history visibility is restored/confirmed.
