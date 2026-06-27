# QM5_10147 DWX Spread Guard Q02 Requeue

Date: 2026-06-27
Agent: codex-board-advisor
Branch: agents/board-advisor

## Scope

- EA: `QM5_10147_tii-momentum`
- Instrument focus: diverse D1 FX stage-one slice
- Farm DB lease: `manual_repair:QM5_10147:Q02`
- Constraint boundary: no portfolio gate change, no T_Live or AutoTrading change

## Diagnosis

`build_check.ps1` flagged `BUILD_CHECK_DWX_ADVISORY_DWX_SPREAD_FAILCLOSED` on
`QM5_10147_tii-momentum.mq5:157`. The EA treated `ask == bid` as invalid:

```mql5
if(bid <= 0.0 || ask <= bid || atr <= 0.0)
```

Darwinex `.DWX` tester symbols can model zero spread (`ask == bid`), so the
guard could block valid tester bars. The existing Q02 history for this EA was
stuck at infrastructure failure only, with no active or pending rows before this
repair.

## Fix

Changed the guard to reject only invalid prices, crossed quotes, or missing ATR:

```mql5
if(bid <= 0.0 || ask <= 0.0 || ask < bid || atr <= 0.0)
```

Rebuilt via:

```powershell
pwsh -File C:/QM/repo/framework/scripts/build_check.ps1 -EALabel QM5_10147_tii-momentum
```

Result: `build_check.result=PASS`, `failures=0`. The `.DWX` spread warning is
gone. Remaining warnings are framework-include advisory warnings, not EA-source
spread-gate failures.

Compiled artifact SHA256:

```text
DCB983FFBE16A850BACC83117A9C1CB5AD4B97282FEA6004FD425D798DEABD5C
```

## Requeue

Reset three latest failed Q02 work items to `pending`, `attempt_count=0`:

| Symbol | Work item |
| --- | --- |
| EURUSD.DWX | `77ac62a0-895a-4c53-96cb-ec7d4c687a53` |
| GBPUSD.DWX | `550c3290-64d4-483a-9d6f-66726eb16c66` |
| USDJPY.DWX | `d1fa3615-7bde-4f84-805c-4646dbe4d642` |

Post-update farm view summary: `Q02_pending=3`, `Q02_failed_INFRA_FAIL=441`.
