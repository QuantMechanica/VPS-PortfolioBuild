# QM5_10907 diverse-FX Q02 infrastructure repair and requeue

## Outcome

`QM5_10907_carter-ema60-pb` has a current framework-linked binary, explicit
fixed-risk backtest inputs, and one pending Q02 work item on each approved
instrument: `EURUSD.DWX` and `GBPUSD.DWX`. The two latest terminal
`INFRA_FAIL` rows were reopened in place; no duplicate work items were added.

This is one funnel-throughput recovery for a structural, low-frequency H1 FX
strategy. The approved card estimates 20 trades per year per symbol and cites
Thomas Carter's *20 Forex Trading Strategies*, Strategy 6, pages 14-15. The
signal, stop, target, and exit rules were not changed.

## Selection and claim

The higher-priority approved build candidate
`QM5_13211_mulham-tgif-weekly-fade` was not buildable under the current build
contract: the authoritative schema and G0 card linters reject its legacy card,
and it has no active magic rows. The build-only skill does not authorize
repairing an approved research contract during Development, so the mission
moved to the diverse Q02 infrastructure lane.

- Farm claim: `agent_tasks.id=4e717aa2-4fc5-4d62-93aa-4db775f0e10b`
- Lease: `manual:codex:agents/board-advisor:QM5_10907:q02-infra-recovery`
- Claim-time collision guard: no pending/active Q02-Q03 row, competing agent
  task, or competing lease for this EA
- Pre-claim backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_10907_claim_20260720T033046Z.sqlite`

## Diagnosis

The farm held 24 Q02 rows for this EA: all 24 were terminal infrastructure
failures, with no economic verdict and no downstream work. Retained report
`D:/QM/reports/work_items/0641b9dc-1274-4d37-a0f7-b687c4dd16ab/QM5_10907/20260622_165946/summary.json`
records `ONINIT_FAILED;INCOMPLETE_RUNS`, zero bars, and zero trades. Its HTML
input table proves that Q02 launched with `qm_ea_id=9999` and slot 1, although
the active registry assigns EA 10907 / GBPUSD slot 1 / magic 109070001.

The checked-in MQ5 default had already been corrected to `10907`, but both
canonical setfiles still omitted `qm_ea_id` and every strategy input. Their
build hashes were `pending`, and the checked-in EX5 dated from June 21. The
package could therefore continue to inherit the stale `9999` tester value.

## Repair

Both setfiles were regenerated with the standard generator. They now bind:

- `qm_ea_id=10907`
- registered slots 0 (`EURUSD.DWX`) and 1 (`GBPUSD.DWX`)
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- the six approved strategy defaults: EMA 5/15/60, five slope bars, 30-pip
  stop, and 50-pip target

The MQ5 was aligned with the current framework corset: Friday close,
management, and rule-based exits execute before the entry-only news gate, and
the entry request is zero-initialized. The EMA60 touch remains a single
closed-bar `CopyRates` read with an explicit performance exception. The EA was
then rebuilt against the current V5 includes.

Current hashes:

- MQ5 SHA256: `8A8D900942D5CCE33F6EC1C9074DD3E2F18C462C84B4A2AD982A54685FBA1426`
- EX5 SHA256: `FE4990FC26A128E870C69CBF0023D05D7316BB52512E68992B28698364A49BAF`

## Validation

| Check | Result |
|---|---|
| SPEC validation | PASS |
| Build guardrails | PASS, no findings |
| Symbol scope | `SINGLE_SYMBOL_OK`, no leaks |
| Active magic rows | PASS: 109070000 / 109070001 |
| Strict compile | PASS, 0 errors, 0 warnings |
| Strict build check | PASS, 0 failures, 0 warnings |
| Compile log | `C:/QM/repo/framework/build/compile/20260720_033339/QM5_10907_carter-ema60-pb.compile.log` |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260720_033339.json` |

No smoke or backtest was launched. The live slot scan already showed seven
backtest jobs, the paced-fleet CPU ceiling, so runtime validation is deferred
to Q02.

## Q02 handoff

| Symbol | Existing work item | State |
|---|---|---|
| `EURUSD.DWX` | `a012dfad-e627-4d1a-a40f-683864036a38` | `pending`, attempt 0, unclaimed |
| `GBPUSD.DWX` | `b13f8816-dfba-4b24-89ad-02de4b7bd889` | `pending`, attempt 0, unclaimed |

The reset transaction required the exact prior `failed / INFRA_FAIL /
unclaimed` states, the live farm claim, and zero open Q02-Q03 duplicates. Its
consistent pre-write backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_10907_fx_q02_requeue_20260720T033645Z.sqlite`.
The two empty stale report roots were archived with the same timestamp before
the rows were reset.

Dispatch was not invoked. No `T_Live` file or process, AutoTrading setting,
portfolio gate, or T_Live manifest was touched.
