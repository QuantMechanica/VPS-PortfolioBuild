# QM5_1537 monthly sleeve calendar refresh

Status: **PROPOSED — NOT REGISTERED**
Authority: task registration requires a separate CEO release.

## Purpose

Stage one append-only XAG host row on the first trading day of each month. The
ranking remains the governed 37-symbol, 252-return, top-three contract with
canonical slot-order tie-break and the first XAG D1 bar of the month as the
evaluation time.

## Schedule proposal

Run at 05:30 Europe/Berlin on days 1–3, but proceed only on the first trading
day for which the native XAG D1 month bar exists. The proposed scheduler
definition is
`tools/strategy_farm/config/qm1537_monthly_sleeve_refresh.task.json`.

## Staging procedure

1. Confirm the dedicated `T_Export` lane is idle and configured for
   `Darwinex-Live`. Defer if it is active. Never inspect or mutate `T_Live` or
   T1–T10.
2. Use the reviewed `qm1537_native_d1_export.py` wrapper. It compiles the
   read-only exporter, launches only its exact governed T_Export config with
   `Enabled=0`, `AllowLiveTrading=0`, and `AllowDllImport=0`, then terminates
   only the path/config/creation-bound process it owns.
3. Require exactly 37 exports, strictly increasing timestamps, finite positive
   OHLC, at least 270 D1 bars per symbol, and a current-month first D1 bar.
4. Run `build_monthly_sleeve_calendar.py` with the prior calendar as
   `--append-v1`, the new immutable receipt as `--native-export-receipt`,
   `--host-symbol XAGUSD.DWX`, and identical from/to month keys for the new
   month. The prior calendar must remain an exact byte prefix.
5. Verify the calendar SHA, unchanged ranking-contract SHA, native bundle SHA,
   unique XAG host/month key, `valid_count=37`, and the per-row source sidecar.
6. Produce a new preset filename and install-candidate receipt. Preserve every
   prior calendar, preset, manifest, source declaration, and binary.
7. Stop in REVIEW. OWNER review and re-attach are required because the pinned
   calendar identity changed. An agent never toggles AutoTrading.

On any defect, publish a failure receipt and retain the prior fail-closed
configuration. Never weaken the news freshness ceiling or any Q gate.
