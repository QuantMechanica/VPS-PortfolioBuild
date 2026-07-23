# Proposed Issue — QM5_12969 Card/Runtime Contract Repair

Date: 2026-07-17

Owner decision: required before fresh Q03

Deployment: prohibited

AutoTrading: unchanged

## Why this issue exists

QM5_12969 is the first FTMO target-book candidate with a fresh deterministic Q02 and current-cost PASS. Promotion must nevertheless stop because the approved research contract and the executed implementation disagree on a load-bearing risk rule.

## Evidence already complete

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12969_usdjpy-gotobi-nakane-fix.md`
- Card rule: no fixed price stop; hard time exit plus framework kill controls.
- Runtime contract: `SPEC.md`, the canonical setfile, and the MQ5 all use `strategy_risk_stop_pips=120`.
- Tested binary: SHA-256 `8cdfcf40a86d532d255c025cd797a0c8e84e184b8a54885c70996cfe2a3ae646`.
- Frozen binary copy: `artifacts/ftmo_rebuild_2026-07-17/binaries/QM5_12969_usdjpy-gotobi-nakane-fix__8cdfcf40.ex5`.
- Q02 binding: `artifacts/ftmo_rebuild_2026-07-17/qm5_12969_q02_binding_20260717.json`, `BOUND_PASS`.
- Q02 metrics: two identical Model-4 runs, 2017-2022, 213 trades, PF 1.57, net 6,062.13, drawdown 1.89%.
- Current FTMO cost result: PF 1.421371, net 4,559.80, PASS.
- 2x commission-and-swap stress: PF 1.364687, net 4,024.11, PASS.

The FTMO cost snapshot used USD/JPY contract size 100,000, flat commission USD 5 per lot round trip, long swap +1.75 points, short swap -19.26 points, three digits, as returned by the official FTMO symbol API on 2026-07-17.

## Additional contract corrections

The approved card says the strategy is intraday and therefore has zero swap. The actual 02:00-JST to 09:55-JST hold crosses broker rollover in the tested mapping; the report reconstruction observed 321 rollover units. The card must not retain the zero-swap claim.

The card expects roughly 68 trades per year. The current Q02 produced 213 trades over six calendar years, roughly 35.5 per year. The difference must be explained by the gotobi roll/holiday logic before challenge admission.

## Recommended decision

OWNER should ratify the 120-pip stop after Quality-Business and Quality-Tech review, as an implementation-only catastrophic safety overlay rather than part of the source alpha. The approved card, embedded EA card, SPEC, and setfile must then say the same thing. Risk sizing and FTMO-loss containment favor a bounded catastrophic stop over an intentionally unbounded price loss.

For prospective Q03, authorize exactly one safety-sensitivity axis:

```text
strategy_risk_stop_pips = [60, 90, 120, 150, 180, 240, 360]
```

Entry time, exit time, gotobi calendar rule, direction, symbol, and holiday logic remain locked. The stop sweep must be judged as robustness/falsification, not used to select the highest-return cell. Default remains 120 only if it lies inside a passing contiguous plateau and pre-holdout review confirms the safety interpretation.

If reviewers reject the safety overlay, Development must remove the stop from MQ5/SPEC/setfiles and regenerate Q02. It is not acceptable to retain the current Q02 while declaring that a different no-stop strategy was tested.

## Q03 execution blockers after the decision

- Create and hash a QM5_12969-specific prospective grid specification.
- Reconcile the old legacy Q03 sibling in the farm DB; the current prospective runner does not update DB lineage itself.
- Reserve one exclusive T1-T5 slot. At audit time every T1-T5 slot had an active DB work item.
- Run `q03_plateau_runner.py --plan` first; start the real 14-run minimum only after plan PASS.
- Bind all later evidence to the frozen EX5 hash. Do not recompile after qualification because MetaEditor EX5 output is not byte-deterministic across compiles.

## Requested terminal verdict

`APPROVE_120_PIP_SAFETY_OVERLAY_AND_Q03_AXIS`, `REMOVE_STOP_AND_RETEST`, or `REJECT_CANDIDATE`.
