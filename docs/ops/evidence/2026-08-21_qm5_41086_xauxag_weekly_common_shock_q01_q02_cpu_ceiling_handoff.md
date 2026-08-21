# QM5_41086 Q01 PASS and Q02 CPU-ceiling handoff

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41086_xauxag-commonshock-rv`

Outcome: `Q01 PASS`; `Q02 ENQUEUED_PENDING_CPU_CEILING`

## New structural commodity sleeve

`QM5_41086` is a low-frequency XAU/XAG relative-value basket on exact
`XAUUSD.DWX` and `XAGUSD.DWX` D1. At the first tradable bar of a new broker
week, it reconstructs synchronized week-end close pairs for the two
immediately preceding consecutive broker weeks and computes each metal's log
return over the same completed interval.

It trades only when gold and silver have strict same-sign nonzero returns.
Gold outperformance sells XAU and buys XAG; silver outperformance buys XAU and
sells XAG. Mixed signs, zero, equality within `1e-10`, asynchronous history,
invalid three-to-five-session membership, and late attachment consume the week
flat. The two legs target equal absolute USD notionals within 20 percent and
share one aggregate `RISK_FIXED=1000` frozen-stop budget. Normal exit is the
next broker-week boundary, with a ten-day stale repair.

The same-sign individual-return admission state is disjoint from
`QM5_41083`'s opposite-sign weekly-leg state and differs mechanically from
rolling ratio-center/residual models, multi-week ratio paths, one-session lead,
session-flow decomposition, and exact-five-session daily breadth. It is also
unrelated in logic to the certified single-symbol XNG two-day cumulative-RSI2
pullback. These distinctions are a diversification hypothesis only; Q09 alone
may establish realized portfolio correlation.

## Reputable source and governance trail

The bounded source packet cites Karsten Schweikert (2018), "Are gold and
silver cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, DOI
`10.1016/j.jbankfin.2017.11.010`, and CME Group's official gold/silver-ratio
spread definition. It explicitly identifies the same-direction completed-week
dispersion fade as an untested QM translation; no source return, density, CFD
equivalence, neutrality, cost, or correlation result transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `ff0d62e6d` |
| deterministic EA-ID reservation | `c2f395741` |
| G0-approved card | `f9b95b762` |
| two-slot magic allocation and resolver | `7c5ddaf5c` |
| governed fixed-risk setfile creation | `0c1fde583` |
| implementation and Q01 build | `30f542ccc` |
| strict compile summary | `D:/QM/reports/compile/20260821_064740/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_064937.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41086/P1/P1_QM5_41086_result.json` |

## Q01 evidence

- canonical pre-allocation dedup: CLEAN across 4,573 registry rows and 625
  root cards, followed by manual family review;
- deterministic reference suite: 10 tests passed;
- build prerequisite guard, card schema, prohibited-ML, G0, spec-document,
  basket guardrail, and symbol-scope lints: PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings;
- targeted strict V5 build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- MQ5 SHA-256: `5F7D26905BDEAA6CA25BFDE3AAC9E0890830E63A4BA29E257880CC9EE9128020`;
- EX5 SHA-256: `F8BC3B67FB39D20BA7363D48FC1BB618751CEAD993F95F53C712466DCB85DBB1`;
- setfile byte SHA-256: `1DE92AE41F8C8C52EA982641332D823DB4E161EB44A87413D601C149051F592E`;
- normalized set build hash: `916edd3f0879700f7dc8f530847b1a865a86d5fc31790ba232cecca26b328a8d`;
- strict build-report SHA-256: `9664BCBE86B64C2FDE211A848E99B75C924A9FF2A64C539554AD3375B3CA56A3`;
- static P1-report SHA-256: `1C6F30FD90AD6AB08EE26AE4B348DC89344B7198BCDE3DD04E58EAD02F405F2B`.

The sole preset is one D1 logical-basket backtest set with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No manual tester or smoke backtest ran.

## Q02 target preflight and reconciliation

The initial supported target view had no existing work item:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_41086
count=0
```

The non-mutating target-only preview selected exactly one fresh baseline row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41086 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

The preview carried no `--apply` flag and made no queue mutation by this lane.
During the shared-farm preflight, one Q02 row appeared at
`2026-08-21T06:52:58Z`. Final read-only reconciliation found exactly one row,
so no duplicate was created:

| Field | Value |
|---|---|
| work item | `4859f62b-3a57-449c-b0c0-3cef50fd7806` |
| phase / kind | `Q02` / `backtest` |
| symbol | `QM5_41086_XAU_XAG_COMMONSHOCK_RV_D1` |
| status | `pending` |
| attempts | `0` |
| claimed by | none |

## Binding CPU stop

At `2026-08-21T06:53:07Z`, canonical read-only `farmctl mt5-slots` inventory
reported six running governed research terminals against the paced ceiling of
seven: `T2`, `T4`, `T6`, `T8`, `T9`, and `T10`. It reported no duplicate
terminal workers and no orphaned terminal processes. The separate `T_Live`
and FTMO terminals were observed only so they could be excluded; neither was
accessed or changed.

Because terminal count was below seven, five whole-host
`Win32_Processor.LoadPercentage` samples were taken across 16 logical
processors:

| Sample UTC | CPU |
|---|---:|
| `2026-08-21T06:53:58.7411487Z` | 100% |
| `2026-08-21T06:54:01.8156549Z` | 90% |
| `2026-08-21T06:54:04.8861161Z` | 94% |
| `2026-08-21T06:54:07.9375632Z` | 100% |
| `2026-08-21T06:54:11.0575857Z` | 99% |

Three samples met or exceeded the governed 97 percent hard ceiling. Per the
mission stop rule, this lane issued no target-only apply command, dispatcher
tick, terminal reservation or control, requeue, priority change, cancellation,
manual tester, or backtest. The existing singular pending row is left for the
normal paced fleet.

## Safe handoff

Do not enqueue another row. Let the paced factory claim
`4859f62b-3a57-449c-b0c0-3cef50fd7806` when capacity permits. This record does
not authorize AutoTrading, `T_Live`, deploy/T_Live manifest changes,
portfolio-gate changes, portfolio admission, a correlation waiver, or live
use. Q02 must retire the identity on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, or any
hard-rule violation.

Machine-readable evidence:
`artifacts/qm5_41086_q02_cpu_ceiling_handoff_20260821T065431Z_board_advisor.json`.
