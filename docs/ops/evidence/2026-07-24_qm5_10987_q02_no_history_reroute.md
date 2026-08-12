# QM5_10987 EURUSD Q02 NO_HISTORY reroute

## Selection and claim

- Farm coordination task: `4ade2c39-8224-4588-b8aa-5379a31a4814`.
- EA: `QM5_10987_ftmo-kc-pb`.
- Diverse carrier: `EURUSD.DWX`, H1.
- Failed Q02 row: `0aa1d4e5-7943-4b89-bc5c-0a2def8b69b6`.
- Approved card:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10987_ftmo-kc-pb.md`
  (`g0_status=APPROVED`, R1-R4 PASS).
- There was no pending or active Q02/Q03 sibling when the repair row was
  inserted.

## Diagnosis

All three attempts on T10 failed before EA initialization with
`NO_HISTORY`, `BARS_ZERO`, `EMPTY_EXPERT`, `EMPTY_SYMBOL`,
`M0_1970_PERIOD`, and `HISTORY_CONTEXT_INVALID`. The generated INIs used
Model 4, `EURUSD.DWX`, H1, and the valid 2022-07-01 through 2022-12-31
window. Repository and deployed EX5 hashes matched during the failed run, so
stale deployment was ruled out.

`cache_audit.py --ea QM5_10987` confirms source history for 2017-2026 and
tester-cache coverage for the exact 2022 half-year window on T1, T3, T4, T5,
T6, T8, and T9. The absence is therefore local to the failed T10 tester
context, not a strategy verdict and not a missing farm-wide dataset.

## Repair and Q02 handoff

- Recompiled the unchanged MQ5 with `compile_one.ps1 -Strict`.
- Result: PASS, zero errors and zero warnings.
- Compile log:
  `framework/build/compile/20260723_234842/QM5_10987_ftmo-kc-pb.compile.log`.
- Refreshed EX5 SHA-256:
  `CC398EBAAED1E6C05D542D27E9951662911DF192BB97EE9A02B39A831062474B`.
- Confirmed the canonical EURUSD setfile retains `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, H1, and Model 4 dispatch.
- Pre-write DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_10987_requeue_20260724T014939.sqlite`.
- New Q02 row: `5cbce9a7-18c0-4eed-ac5b-e32fcdf936c6`.
- Queue state: pending, unclaimed, attempt 0, priority tracked.
- Routing: avoid T10; documented warm-cache targets are T1/T3/T4/T5/T6/T8/T9.

No manual backtest was launched because the paced fleet owns Q02 CPU. No
portfolio gate, T_Live path, deploy manifest, AutoTrading state, or live
manifest was touched.
