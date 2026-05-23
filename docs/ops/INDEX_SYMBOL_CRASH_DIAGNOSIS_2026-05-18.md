# Index Symbol MT5 Tester Crash Diagnosis - 2026-05-18

## Problem

MT5 tester runs for custom Darwinex index symbols repeatedly failed without a report file:

- `GDAXI.DWX`
- `NDX.DWX`
- `SP500.DWX`
- `UK100.DWX`
- `WS30.DWX`

Observed pattern: `terminal64.exe` started, died after roughly 1-2 minutes, and the wrapper later classified the work item as `REPORT_MISSING` / `METATESTER_HUNG` or incomplete because no report was written. Forex DWX symbols kept running cleanly.

## Diagnosis Evidence

Historic index PASS rows exist, proving index symbols are not categorically unusable:

```text
d8647254-159f-4080-af65-e6efc4fcf52c QM5_1049 GDAXI.DWX 2026-05-16T21:54:30.072130Z
ed5352de-7e52-42e8-94df-0be2dd65ea78 QM5_1049 UK100.DWX 2026-05-16T21:54:30.079149Z
45381e21-9009-444e-907f-3ce15d7c8f71 QM5_1049 WS30.DWX 2026-05-16T21:54:30.085165Z
```

Those historic rows only retained ablation metadata in `payload_json`; the old raw report directories were not available for a direct raw-artifact comparison.

A current clustered NDX failure showed five simultaneous work items for the same EA and symbol:

```text
3eed51bb-5b5f-4876-93d2-39e7f2a897c5 QM5_1056 NDX.DWX T1
4c39639d-67e7-452c-941f-bc19b2361bc8 QM5_1056 NDX.DWX T2
95a8bf3d-1bd3-49f3-917a-b6ac4d94fcf7 QM5_1056 NDX.DWX T3
0eae0801-c44c-4607-a4a2-7f2675cb02b4 QM5_1056 NDX.DWX T4
678d5de6-6aa2-4903-a9c1-15d5a9860a27 QM5_1056 NDX.DWX T5
```

All five shared `started_at_iso=2026-05-18T12:29:17+00:00` and failed with `run_smoke_fail:REPORT_MISSING;INCOMPLETE_RUNS`. One representative payload had `exit_code=10053`, `report_size_bytes=0`, and expected report path:

```text
D:\QM\mt5\T1\QM5_1056_NDX_DWX_20260518_122918_run_01.htm
```

The failing `tester.ini` already had the custom/offline-safe flags expected for a custom symbol run:

```ini
Symbol=NDX.DWX
Period=D1
Model=4
Optimization=0
FromDate=2024.01.01
ToDate=2024.12.31
UseLocal=1
ShutdownTerminal=1
```

That makes the missing-flag hypothesis unlikely.

MT5 tester logs also showed later `NDX.DWX` runs entering the test and placing trades, including real tick availability from 2018-07-02 and normal 2024 trade lines. That argues against global tick-data corruption and against an EA `OnInit` crash for all index runs.

Terminal logs showed the failing cluster launched at the same local second across the fleet:

```text
T1 14:29:19 ... 3eed...\QM5_1056\20260518_122918\raw\run_01\tester.ini
T2 14:29:19 ... 4c39639d...\QM5_1056\20260518_122918\raw\run_01\tester.ini
T4 14:29:19 ... 0eae0801...\QM5_1056\20260518_122918\raw\run_01\tester.ini
T5 14:29:19 ... 678d5de6...\QM5_1056\20260518_122918\raw\run_01\tester.ini
```

## Root Cause

Most likely root cause: MT5 custom-symbol history or tick-cache contention when several testers hit DWX index symbols at the same time.

Rejected or lower-probability causes:

- Custom-symbol INI mode: rejected because the failing INI already used `UseLocal=1` and `Optimization=0`.
- Tick-data corruption: unlikely because later NDX runs could start and trade.
- EA-specific symbol logic crash: unlikely because the same EA/symbol was seen past tester initialization in MT5 logs.
- History-cache lock/contention: supported by five terminals launching the same index symbol in the same second and all producing report-missing failures.

## Fix Applied

`tools/strategy_farm/farmctl.py` now serializes the known DWX index symbols at dispatch time:

- `GDAXI.DWX`
- `NDX.DWX`
- `SP500.DWX`
- `UK100.DWX`
- `WS30.DWX`

If any one of these symbols is already active or has been claimed in the current dispatch tick, later pending index-symbol work items are left pending with action `deferred_index_symbol_lock`. Non-index symbols continue to use the remaining free terminals.

This is intentionally pump-side. It avoids changing live work items and avoids changing the MT5 tester INI when the captured INI was already correct.

## Verification

Added a unit test covering mixed pending work:

- `NDX.DWX` is claimed first.
- `GDAXI.DWX` remains pending under the index-symbol lock.
- `EURUSD.DWX` is still claimed in the same tick, preserving non-index parallelism.

No pending or active production work items were edited. No T6 live action was taken.

## Addendum: Per-Symbol Dispatch Lock

The first dispatch fix serialized all known DWX index symbols farmwide. That was more conservative than the observed root cause required.

The failing cluster was five simultaneous MT5 testers for the same symbol (`NDX.DWX`) across different terminals. Different custom symbols use different local history/cache files, so `NDX.DWX` on one terminal, `SP500.DWX` on another, and `GDAXI.DWX` on a third should not contend for the same symbol cache.

Dispatch now serializes by normalized `symbol` for all work items:

- If `NDX.DWX` is already active or has been claimed in the current dispatch tick, another pending `NDX.DWX` item remains pending with `reason='symbol_already_active_on_other_terminal'`.
- Different index symbols can be claimed in parallel.
- The same duplicate-symbol protection also applies to non-index symbols such as `EURUSD.DWX`.

This keeps the crash guard on the identified cache-lock conflict while allowing safe parallelism across different symbols.
