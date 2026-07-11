# QM5_11112 Diverse-FX Q02 Infrastructure Recovery

## Outcome

`QM5_11112_sr-lines-fade` now has a current, strict-clean binary and one
collision-guarded EURUSD H1 Q02 work item. A bounded 2024 Model-4 smoke passed
with 32 trades, no OnInit failure, and a valid real-tick marker. The farm claim
is `PIPELINE`; work item `5f08fb95-cf8b-4378-b8eb-6aec56005367` is pending.

## Why This EA

- Higher-count ten-FX candidates were not claimable: they lacked authorized
  allocation, already had a repair/handoff, had open Q02 work, or retained a
  competing farm task.
- This approved H1 sleeve adds three FX carriers (`EURUSD`, `GBPUSD`,
  `USDJPY`) alongside XAU, uses deterministic fractal/ATR market structure,
  and has traceable public source code in EarnForex's
  `Support-and-Resistance-Lines` repository.
- Before the claim it had 48 terminal Q02 `INFRA_FAIL` rows, zero economic Q02
  verdicts, no open Q02 row, no Q03-or-later row, and no nonterminal agent task.

The atomic claim used agent task
`66870ba5-b818-4507-b727-7ed41e61a532` and backup
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11112_q02_repair_claim_20260711T100321Z.sqlite`.

## Diagnosis And Repair

The retained EX5 was built on 2026-06-17, before the framework's 2026-07-06
`QM_EntryRequest` constructor repair. This EA also omitted explicit
`symbol_slot` and `expiration_seconds` assignment. Consequently, an entry
signal could pass stack garbage into magic resolution even though the four
registry rows and setfile slots were correct.

The package repair now:

- zero-initializes each request and explicitly selects the setfile's magic slot;
- keeps management and hard exits active through entry-only spread/news blocks;
- advances structural levels on every closed bar; and
- rejects normalized targets that land on the wrong side of entry.

All four backtest setfiles retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
slots 0-3. Their build hashes were refreshed. No shared framework or registry
file was changed.

| Check | Result |
|---|---|
| EA build guard | PASS |
| SPEC validator | PASS |
| Strict build check | PASS, 0 failures, 0 warnings |
| Strict compile | PASS, 0 errors, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260711_100532.json` |
| Clean-snapshot compile log | `D:/QM/reports/compile/20260711_1006_qm5_11112_clean/QM5_11112_sr-lines-fade.compile.log` |
| MQ5 SHA-256 | `1FC704D37C56AB045D1916E0A830A425D5EE97895371E619BE255076E11A0BB3` |
| EX5 SHA-256 | `93FD99666C7D803ABE026381DAD41D1DFC0FB14AD029CBF0264408F4606F8120` |

The final EX5 was compiled from a detached HEAD framework snapshot plus the
repaired source. Relative QM includes prevented another agent's unrelated,
uncommitted include edit from entering the binary.

## Runtime And Q02 Handoff

The sole smoke invocation used T1, EURUSD.DWX H1, 2024, Model 4,
`RISK_FIXED=1000`, and a build-smoke minimum of one trade. It completed in 56
seconds with 32 trades and no infrastructure reason class. Summary:
`D:/QM/reports/smoke/QM5_11112/20260711_100916/summary.json`.

This is not a profitability claim. The one-year smoke had PF 0.32, net profit
`-9861.08`, and 13.20% maximal equity drawdown. Q02 owns the economic verdict.
Only EURUSD was queued so the farm can reject the sleeve cheaply if the
multi-year evidence confirms that weakness; the other three carriers were not
flooded into the queue.

At enqueue time `FACTORY_OFF.flag` was present, so the pending row will wait for
the owner-controlled factory restart. The queue backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11112_q02_enqueue_20260711T101138Z.sqlite`.

## CPU And Safety Boundary

Before smoke there were three DB-active rows and one `metatester64` process, so
the backtest CPU ceiling was not reached. The single run passed; no retry was
made and no orphaned T1 process remained.

No `T_Live` file, AutoTrading state, portfolio gate, or live manifest was
touched.

Machine-readable evidence:
`artifacts/qm5_11112_fx_q02_infra_repair_requeue_20260711.json`.
