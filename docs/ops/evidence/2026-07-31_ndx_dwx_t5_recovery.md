# NDX.DWX T5 availability and Factory Q02 recovery — 2026-07-31

## Verdict

`PASS` for T5 custom-symbol availability and native Model-4 readability.
`NDX.DWX` was already present on T5 through the fleet's shared Custom-symbol
master; no history propagation or data copy was necessary. The formal
`QM5_20188` Q02 run completed `PASS` through the normal Factory queue.

This is infrastructure and Q02 evidence only. It is not a downstream-gate,
portfolio, deployment, or live-trading authorization.

## Storage and terminal mapping

- `D:/QM/mt5/T5/Bases/Custom` is a Junction whose target is
  `D:/QM/mt5/T1/Bases/Custom`.
- Final inventory at the T5-visible path: 9 annual `.hcc` files,
  `2018.hcc` through `2026.hcc`, totaling 165,198,129 bytes.
- Tick inventory: 97 `.tkc` files with names spanning `201807.tkc` through
  `202607.tkc`, plus `ticks.dat`; 98 files totaling 3,038,565,443 bytes.
- T1 and T5 therefore read the same physical NDX data. A successful native
  read on either terminal validates the shared store seen by T5; it does not
  claim that the Factory was forced to choose T5.

The existing registry schema in `framework/registry/dwx_symbol_matrix.csv`
contains no `validation_status` or validation-date field, so no ad-hoc column
was introduced. This durable record carries the validation result. Broker-time
and DST semantics were not remeasured in this recovery and remain governed by
the existing DWX master definition.

## Root cause

The failed direct T5 tests logged repeated entries such as:

`History 'NDX.DWX' file opening or reading error [32]`

Windows error 32, the shared Junction, concurrent NDX work, and the later
successful serialized read jointly identify a shared-file handle conflict.
The earlier `NO_HISTORY;INCOMPLETE_RUNS` classification described the failed
attempt's symptom; it did not prove that NDX data was absent.

An auxiliary Python/MT5 visibility probe also failed with IPC error
`(-10003, Pipe server didn't answer in 60 sec)` while terminal resources were
busy. It is not used as validation evidence. The native Factory tester result
below is authoritative.

## Factory-only correction

- The direct diagnostic was stopped after the OWNER required Factory-only
  handling. Its temporary control binary was removed and all T1-T10
  reservations held by that diagnostic were released.
- The already-existing work item
  `2a69e9da-4b51-4eb6-9ea6-7ec4213c4fd1` was retained. No duplicate was
  enqueued and no queue priority was changed.
- The Factory's own symbol lock serialized NDX access. It selected T1 for the
  run; terminal selection was not overridden.
- T_Live and AutoTrading were untouched. The Factory was not stopped, and no
  custom-symbol files were copied, replaced, or deleted.

## Formal Factory result

- Gate/result: Q02 `PASS`, reason class `OK`.
- EA/symbol: `QM5_20188_ff-rb-tue-off` / `NDX.DWX`.
- Window: 2021-01-01 through 2022-12-31; H1; Model 4; one requested and one
  successful attempt.
- Terminal: Factory-selected T1, reading the same physical Custom master as T5.
- Metrics: 249 trades, PF 1.09, net profit $12,213.19, drawdown $17,096.62
  (15.29%), final balance $112,213.19.
- Native workload: 183,767,288 ticks, 11,826 generated bars, 0.017 seconds
  environment synchronization, 10:02.613 test time.
- Tick-quality disclosure: the tester reported 15 minutes without real ticks
  among 686,679 minute bars and used every-tick generation for those gaps.
- The Q02 commission group is zero for this Custom-symbol run; downstream cost
  and robustness gates remain necessary.

## Evidence bindings

| Artifact | SHA-256 |
|---|---|
| Factory Q02 `summary.json` | `FCE7010A4A8F9F4E39C79C7FD546C257527F8426F41C8752D7A5989442DED10A` |
| Native MT5 report | `0CA592E344E7B928DBACB7E2880133C0678D9663AC8FB52F24E575681C144608` |
| Logger sample | `A8C52ED7564FB8279745C718FFE33965E417A47644CAEECA6925B8455748E7F5` |
| EA source | `43C1877424048D81B2813C8BD36C28312CFFF942814CBFC52BC652CDA8E4F1AB` |
| EA binary | `7549328E8D077B7A3DEC39803A84C610AEDB7728298CDFD48B650F83C1696A1C` |
| NDX setfile | `68C534684D78E6DB963C4D0D286E2D75DDADE931BEB7188A16C7ECDA56F64510` |

Canonical Factory report directory:

`D:/QM/reports/work_items/2a69e9da-4b51-4eb6-9ea6-7ec4213c4fd1/QM5_20188/20260731_191403/`

## Boundary and next action

This Q02 result closes the NDX availability incident and establishes a positive
preliminary candidate run. It does not replace the frozen 2022-2025
parent-versus-variant comparison and does not make the entire pipeline PASS.
At the 2026-07-31 19:33 UTC queue snapshot, the Factory had automatically
created NDX Q03 (`ce588465-6bdb-4595-a00e-5a3e5a9d47d4`) and NDX Q04
(`53b6706e-bb8e-4dc2-9235-bd47c83eb3af`), both pending. USDJPY Q04 was active,
USDJPY Q03 was pending, and GBPUSD Q04 had completed `FAIL`. The exact frozen
binary should remain in that normal Factory cascade; any later variant must
receive a separate identity and untouched evaluation window.
