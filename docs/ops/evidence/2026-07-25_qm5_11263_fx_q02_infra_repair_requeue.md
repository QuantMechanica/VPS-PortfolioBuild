# QM5_11263 FX Q02 infrastructure repair and requeue

Date: 2026-07-25  
Branch: `agents/board-advisor`  
Farm claim: `9b529028-ac29-40f7-b88a-0635946fed9f`

## Outcome

`QM5_11263_qt-dual-thrust / EURUSD.DWX / Q02` was re-enqueued as work item
`2bba81cf-f6f5-47b6-a4ec-f8becd01098a`. The pending item is steered away from
T1 and T6, the two terminals evidenced in this lineage with terminal-local
history failures.

## Diagnosis

The failed source work item was
`8395f5cc-4094-4573-b29c-ff2fd03f6c06`. Its evidence reported
`NO_HISTORY;BARS_ZERO;INCOMPLETE_RUNS` after three empty report shells on T1.
The source binary and deployed binary matched, the setfile matched, and all
artifacts remained stable during the run. The same EA build passed Q02 on
GBPUSD.DWX (`85b75307-6056-43aa-bb59-c9524c1bb4cb`), while the EURUSD.DWX
prescreen had also passed before the full-history attempt failed. This
separates a terminal history-cache fault from an EA logic or stale-binary
fault.

## Verification and repair

- Strict compile: PASS, 0 errors, 0 warnings.
- Compile evidence: `D:\QM\reports\compile\20260725_183111\summary.csv`.
- Rebuilt EX5 SHA-256:
  `1e375839ff0f33f2edd44d703cf7f30aaea2c35d710054747a5034572eb5c068`.
- Queue state: exactly one new pending EURUSD.DWX Q02 row was inserted after
  an atomic no-open-row collision check.
- Queue steering: `avoid_terminals=["T1","T6"]`.
- Risk contract remains the canonical `RISK_FIXED` backtest setfile.

No manual smoke/backtest was launched. No T_Live, AutoTrading, portfolio
gate, deploy manifest, or live setfile was touched.
