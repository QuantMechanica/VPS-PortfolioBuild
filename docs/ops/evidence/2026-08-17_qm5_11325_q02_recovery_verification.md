# QM5_11325 repaired EURUSD Q02 recovery verification

Date: 2026-08-17

Branch: `agents/board-advisor`

Router task: `5b5d4eab-2033-4eab-8a41-79d44b634934`

Outcome: `Q02_PASS_VERIFIED_NO_DUPLICATE_ENQUEUE`

## Scope

This task was routed as an append-only EURUSD Q02 canary after the repaired
`QM5_11325_tc-m5-9-ema50-100-macd-partial-exit` initialization contract. The
task was recovered after the earlier board-advisor lease expired. The exact
successor had already been appended by the earlier governed slot, so this
cycle performed read-only postcondition verification and did not create a
duplicate work item.

## Queue lineage

- Preserved predecessor: `6b0dc37c-437f-4804-9f1a-6ef944160a14`, terminal
  `Q02 / INFRA_FAIL` with `ONINIT_FAILED;INCOMPLETE_RUNS`.
- Append-only successor: `cc39009e-3d44-4f0a-a945-e96c59eafa22`.
- Successor identity: `QM5_11325`, `EURUSD.DWX`, `M5`, Q02.
- Successor state at verification: `done / PASS`, unclaimed, attempt count 0.
- The EA now has 37 Q02 rows: 36 preserved `INFRA_FAIL` rows and this one
  repaired-binary `PASS` row.

The original enqueue and pre-mutation backup are recorded in
`docs/ops/evidence/2026-08-17_qm5_11325_q02_canary_cpu_ceiling_stop.md` and
`artifacts/qm5_11325_fx_q02_canary_enqueue_20260817T102154Z_board_advisor.json`
at commit `ef83de159bd19d3b66e0e13a57fdbdd2a33dfb37`.

## Pipeline evidence

Canonical summary:

`D:\QM\reports\work_items\cc39009e-3d44-4f0a-a945-e96c59eafa22\QM5_11325\20260817_105355\summary.json`

Summary SHA-256:
`87f5f459e91e0929e3cc624f78781aafa2bedcef16f148231b3cf38d4d9e9321`.

The summary records:

- `result=PASS`, `reason_classes=[OK]`, and one deterministic attempted run;
- `oninit_failure_detected=false` and `non_ok_attempts=0`;
- 1,862 trades on the 2018-07-02 through 2022-12-31 real-tick window;
- stable source/deployed EX5 and setfile identities during the run;
- news-calendar status `OK` with `max_age_hours=336`.

This is a Q02 infrastructure/smoke verdict only. The report's economic metrics
are not promoted or reinterpreted here, and no deeper-phase or profitability
verdict is inferred.

## Immutable bindings and guardrails

| Artifact | SHA-256 |
|---|---|
| Current EX5 | `2bf875d2a303fe36dbae9c8a51d85c9ae44bdbe28c8099c25a4a2596b8d6c171` |
| EURUSD backtest setfile | `c90f9aa80ebe8710354eeaae5eb71ae0988c287f0e7a7f3516a647faee5e103c` |

The setfile remains sealed to `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, and numeric news modes `0/0/0`. No news staleness limit,
EA source, compiled binary, setfile, registry, historical work item, terminal,
T_Live path, AutoTrading state, portfolio gate, or deploy manifest was changed
by this verification cycle.
