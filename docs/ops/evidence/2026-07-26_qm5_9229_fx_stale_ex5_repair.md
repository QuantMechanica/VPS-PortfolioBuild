# QM5_9229 FX stale-EX5 repair and Q02 re-enqueue

- Timestamp: 2026-07-26 01:02 Europe/Berlin
- Branch: `agents/board-advisor`
- EA: `QM5_9229_mql5-dem-div`
- Scope: Q02 infrastructure recovery only; no strategy or setfile changes

## Diagnosis

The farm retained two unclaimed Q02 work items for `EURUSD.DWX` and
`GBPUSD.DWX`, while older attempts recorded `ex5_missing`. The source and
RISK_FIXED backtest setfiles were present, but the checked-in EX5 predated the
current framework/include state.

## Repair

Recompiled the existing approved EA in place:

```text
pwsh -File framework/scripts/compile_one.ps1 -EALabel QM5_9229_mql5-dem-div
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
compile_one.log=C:\QM\repo\framework\build\compile\20260726_010221\QM5_9229_mql5-dem-div.compile.log
```

The refreshed binary SHA-256 is:

```text
0f6043a77bea455f841d6f86f8a3d7fcf7795ddd7dd7586fc4e5c61bed9e44c1
```

The two existing pending Q02 rows were refreshed in the farm DB with immutable
MQ5, EX5, and setfile hashes and this evidence path. No MT5 backtest was started
by this repair.
