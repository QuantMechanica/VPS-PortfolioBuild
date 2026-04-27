# 2026-04-27 - QUA-91 WS30.DWX verifier failure investigation

Issue: `QUA-91` (DEVOPS-004 child)  
Parent context: `QUA-19` verifier re-run

## Scope

Investigate whether `WS30.DWX` `FAIL_tail_bars` is a WS30-specific import defect or a systemic verifier/runtime condition.

## Evidence

Source log: `infra/smoke/verify_import_run_2026-04-27_qua19.log`

Observed WS30 row (from the log):
- verdict: `FAIL_tail_bars`
- `mid_ticks_5min=1561` (non-zero)
- `bars expected=445,870/got=0`
- tail gap: ~`7143.924s`

Cross-symbol context in the same run:
- Every FAIL row shows `bars expected>0` with `bars got=0`.
- Multiple symbols have non-zero `mid_ticks_5min` (WS30, UK100, XTIUSD, etc.), so market feed visibility is not uniformly zero.
- This pattern indicates a shared verifier/runtime bars-read path failure rather than a WS30-only data corruption.

## Conclusion

`WS30.DWX` is **not isolated** in this run. The dominant failure mode is systemic (`bars got=0` across the board), with WS30 only one instance in that batch.

## Continuation rerun (2026-04-27 08:53 Europe/Berlin)

Command:

```powershell
python D:\QM\mt5\T1\dwx_import\verify_import.py
```

Evidence log:
- `infra/smoke/verify_import_run_2026-04-27_085347_qua91.log`

WS30 row (unchanged verdict):
- `WS30.DWX` => `FAIL_tail_bars`
- `tail_ms expected/got`: `1775444399667 / 1775437255743` (shortfall ~`7143.924s`)
- `mid_ticks_5min=1561`
- `bars expected/got=445,870/0`

Batch-level diagnostics from the rerun:
- unique FAIL rows: `35`
- `all_fail_bars_zero=True`
- `any_fail_mid_nonzero=True`

Disposition:
- Acceptance target (`WS30` with non-zero bars + matching tail) not met.
- Issue is **blocked on verifier implementation** (bars-read path), not on WS30 symbol feed.

Unblock owner + action:
- **Owner:** verifier implementation owner (DWX verifier/runtime maintainer)
- **Action:** instrument and fix `verify_import.py` bars-read path for custom symbols, then rerun and confirm `WS30.DWX` `bars_got>0` with tail alignment.

## Additional root-cause probe (2026-04-27)

Command:

```powershell
python infra/scripts/probe_verify_rates_span.py --symbol WS30.DWX --chunk-days 20
```

Output summary:
- `oneshot_count=0`
- `oneshot_last_error=(-2, 'Terminal: Invalid params')`
- `chunked_count=99899` with `bad_chunks=0`
- sidecar expected M1 bars: `445,870`

Interpretation:
- The verifier's current **single full-span** `copy_rates_range(...)` call is the primary failure trigger.
- MT5 can return substantial bar data for WS30 when queried in smaller windows.
- This confirms a verifier query-shape bug/limit interaction, not WS30-specific feed absence.

Implementation direction:
- Replace one-shot full-span bar read in `verify_import.py` with chunked reads.
- Gate bar verdict against accessible-history bounds (for example terminal `maxbars`) plus tail/head alignment, instead of requiring full sidecar `m1_count` from one API call.

## WS30-focused verifier-equivalent probe (2026-04-27)

Command:

```powershell
python infra/scripts/verify_import_chunked_probe.py --symbol WS30.DWX --chunk-days 20
```

Result:
- `tick_head expected/got=1530493208796/1530493208796` (head OK)
- `tick_tail expected/got=1775444399667/1775437255743` (tail shortfall `7143.924s`)
- `mid_ticks_5min=1561` (non-zero)
- `bars_oneshot_count=0` with `(-2, 'Terminal: Invalid params')`
- `bars_chunked_count=99900` (`chunks=24`, `bad_chunks=0`)
- `terminal_maxbars=100000`

Disposition refinement:
- `FAIL_bars` in current verifier is a query-shape defect.
- After isolating that defect, WS30 still has a **tail lag** condition.
- QUA-91 should remain **defer/fix** under verifier maintainer until:
  1) verifier bar query is chunked, and
  2) WS30 tail aligns on rerun.

## Source-vs-custom tail parity check (2026-04-27)

Command:

```powershell
python infra/scripts/verify_import_chunked_probe.py --symbol WS30.DWX --chunk-days 20
```

Additional fields:
- `tick_tail expected/got=1775444399667/1775437255743`
- `source_tick_tail_got=1775437256065`
- `custom_minus_source_tail_ms=-322`

Interpretation:
- `WS30.DWX` tail is aligned with broker source `WS30` in the verifier tail window.
- Remaining tail shortfall is against sidecar `expected` timestamp, not against live source symbol.
- This indicates a **global verifier expectation/time-basis issue**, not WS30-specific import corruption.

Final disposition for QUA-91 scope:
- **WS30 symbol-specific corruption hypothesis: cleared.**
- **Outstanding work:** verifier logic fix (global) for bar query shape and expected-tail comparison basis.

## Candidate verifier run (repo-side, non-production)

Command:

```powershell
python infra/scripts/verify_import_candidate.py --symbol WS30.DWX --chunk-days 20
```

Observed verdict:
- `[FAIL_tail] WS30.DWX` (bars no longer failing in candidate logic)

Key diagnostics:
- `bars_sidecar_expected=445,870`
- `bars_one_shot=0` with `(-2, 'Terminal: Invalid params')`
- `bars_chunked=99,900`
- `maxbars=100,000`
- `bars_expected_accessible=100,000`
- `bars_drift=-100` (within candidate tolerance)

Meaning:
- Candidate logic removes false `FAIL_bars` on WS30 and isolates residual `FAIL_tail`.
- Confirms remaining blocker is tail expectation-basis mismatch / source-window lag handling.

## Durable change in this heartbeat

- Added/extended tests for verifier fail-pattern classification in:
  - `infra/scripts/tests/test_dwx_hourly_check_readiness.py`
- Confirmed and documented the automated classifier contract in:
  - `infra/scripts/README.md`

Classifier contract used by `dwx_hourly_check.py`:
- `systemic_zero_bars`: >=10 FAIL rows with `bars expected>0` and `bars got=0`
- `systemic_zero_mid_ticks`: >=10 FAIL rows with `mid_ticks_5min=0`

## Next action

Run the next verifier pass under active market session and capture the same classifier signals. If `systemic_zero_bars` persists, escalate to verifier implementation owner for bars-read-path debugging (not symbol-level DWX repair).
