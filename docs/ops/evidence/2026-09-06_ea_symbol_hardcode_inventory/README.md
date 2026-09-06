# EA symbol hard-code guard and migration inventory

Date: 2026-09-06  
Task: `4d3b27f6-b3e7-407f-b41d-5957a8998fb6`  
State: REVIEW  
OWNER rule: a trading/universe symbol is `_Symbol` or an input; multi-symbol EAs
declare one input per registry slot.

## Verdict

REVIEW_READY. `framework/scripts/build_check.ps1` now consumes the file-based
`tools/strategy_farm/ea_symbol_literal_inventory.py` predicate and emits
`EA_SYMBOL_HARDCODED`.

- A trading-logic symbol literal in a new MQL file fails the build.
- A trading-logic symbol literal in an MQL file that existed at cutover commit
  `bb584c73239c5bd9f7ba98d2bf5863bafa8cfe48` warns for ordered migration.
- A symbol input default, generated registry/slot table, or registry include is reported
  as allowed. The QM5_1537 SHA-bound 37-slot identity table is structurally classified
  as a generated slot table; this is not permission for trading logic to read foreign
  literal symbols.
- The same scanner and regex produce build-check decisions and the durable corpus
  inventory, preventing a separate audit regex from drifting.

No gate-bound inventory EX5, terminal setting, AutoTrading state, `T_Live`, account,
calendar CSV, news staleness ceiling, or Q verdict was changed by this work.

## Pre-enable corpus calibration

Full machine-readable inventory: `inventory.json`.

| Measure | Count |
|---|---:|
| MQL sources scanned | 4,078 |
| sources containing exact broker-symbol literals | 1,365 |
| literal occurrences | 22,813 |
| generated slot-table occurrences | 37 |
| registry-include occurrences | 18,114 |
| symbol-input defaults | 194 |
| existing trading-logic literals (WARN) | 4,468 |
| new-source trading-logic literals (FAIL) | 0 in current corpus |
| sources with any non-chart market-data call | 831 |
| sources with `SymbolSelect` or `CopyRates` on non-`_Symbol`/non-`NULL` | 677 |

The original estimate was approximately 1,324 literal-bearing sources and approximately
658 `SymbolSelect`/`CopyRates` sources. The reproducible 2026-09-06 corpus is larger:
1,365 and 677 respectively. The guard therefore cannot safely hard-fail the inherited
corpus; the cutover distinction is required.

## Priority inventory

The JSON lists these rows before the general fleet.

| Cohort | Result | Required action |
|---|---|---|
| FTMO M13: 10706, 11421, 11422, 11910 | chart-symbol-only | no symbol migration found; retain `_Symbol` |
| FTMO M13: 13054 | one inherited `XTIUSD.DWX` trading literal | replace with chart/input alias on next governed identity |
| FTMO M13: 20048 | one inherited `XTIUSD.DWX` trading literal | replace with chart/input alias on next governed identity |
| FTMO M13: 1537 | 37 generated slot-table literals, allowed; no foreign market-data call | host calendar alias input is already implemented; preserve SHA contract |
| FTMO M13: 21505 | two inherited `XAGUSD.DWX` trading literals | replace with chart/input alias on next governed identity |
| DXZ live book: 12778 | multi-symbol, 14 non-chart calls, 8 literals | migrate two strategy slots first among live-book sources |
| DXZ live book: 1556 | one non-chart call, no literal | document/validate its resolved variable against registry slot |
| DXZ live book: 13117 | multi-symbol, 14 non-chart calls, 6 literals | migrate two strategy inputs and slot validation |
| 41372 XTI/XNG | multi-symbol, 34 non-chart calls; one input default plus three inherited literals | make XTI and XNG explicit slot inputs; validate broker aliases independently |

Other live-book rows in the priority roster are currently classified chart-symbol-only.
This is source-shape inventory, not pipeline evidence and not a deployment verdict.

## QM5_1537 first migration

Precursor commit `dcaeca68f5` added `strategy_calendar_symbol`, routes host-row and
selected-row matching through `QM1537_HostSymbol()`, and preserves the SHA-bound calendar
contract. The FTMO preset binds `strategy_calendar_symbol=XAGUSD.DWX`, while actual
orders/price reads remain on the plain FTMO chart `_Symbol` (`XAGUSD`). Independent checks
in this cycle confirmed:

- repository MQ5 SHA-256 `01aeae9e51837151d60bae26dc8c31b336f247a08e4e41367285439020dafb04`;
- calendar include SHA-256 `ab52e1c874be131947e47161796eb941cb794d597de0a845674466b1b2726b9f`;
- calendar CSV SHA-256 remains `401e0d91e2428dab4abff17c1df651f1c7bc716b7160b71a06d1a3eca9b5288b`;
- artifact-only FTMO compile log: `Result: 0 errors, 0 warnings`;
- artifact EX5 SHA-256 `e34e0194bfb4a804526ecb45572b05148ea083ac3d0f01536a9f7b9216e3ea40`;
- reviewed live-trial preset has `RISK_FIXED=0`, `RISK_PERCENT=0.3125`,
  `qm_news_stale_max_hours=336`, and `strategy_calendar_symbol=XAGUSD.DWX`;
- existing install receipt is
  `docs/ops/evidence/2026-09-06_ftmo_1537_calendar_symbol_input/install_receipt.json`.

The source change creates a new identity. Factory/gate-bound binaries remain untouched;
any pipeline use starts again at Q02. The existing OWNER-authorized FTMO demo receipt is
evidence of the artifact/install action already performed before this guard review, not
authorization to modify another terminal.

## OWNER migration order

1. Treat QM5_1537 as the canary and start its new source/binary identity at Q02. Do not
   inherit old pipeline verdicts.
2. Repair FTMO M13 inherited literals in 13054, 20048 and 21505, one EA identity at a
   time; 10706/11421/11422/11910 remain chart-symbol-only unless deeper review finds an
   indirect alias defect.
3. Migrate live-book multi-symbol sources 12778, 13117 and 1556. Do not replace their
   gate-bound EX5 files until new identities pass the governed route and OWNER/Claude
   closes deployment.
4. Repair 41372 as a two-slot XTI/XNG input pattern, using the registry `(ea_id, slot)`
   rows as magic authority and explicit broker aliases for `XTIUSD`/`USOIL` and
   `XNGUSD` where needed.
5. Drain the remaining 677 core multi-symbol sources by deployed relevance, then
   profitable/Q-advanced state, then the unbuilt backlog. Existing warnings are a
   migration queue, never permission to ship a newly hard-coded EA.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_ea_symbol_literal_inventory.py -q
2 passed

PowerShell parser: build_check_parse=PASS

QM5_1537 scanner scope:
2 sources; 37 literals; all 37 generated_slot_table/ALLOW;
0 non-chart market-data sources; 0 FAIL/WARN
```

The synthetic test commits an old violating EA, then adds a new violating EA. It proves
the old exact literal is `WARN`, the new exact literal is `FAIL`, an input default is
`ALLOW`, a marked generated table is `ALLOW`, and the non-chart `CopyRates` call is
inventoried. A direct full `build_check.ps1` invocation was intentionally refused by
the live-factory compile guard because terminal workers were active; no terminal or
backtest was interrupted. The scanner, JSON integration path, PowerShell syntax and
task-specific MQL artifact were verified independently.
