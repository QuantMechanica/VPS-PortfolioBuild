# QM5_41085 Q01 PASS and Q02 capacity-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41085_xauxag-wdaybreadth-rv`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural commodity sleeve

`QM5_41085` is a low-frequency XAU/XAG relative-value basket on exact
`XAUUSD.DWX` and `XAGUSD.DWX` D1. At the first tradable bar of a new broker
week, it reconstructs the final synchronized ratio close of the parent week
and exactly five synchronized closes in the immediately completed week. It
counts the five adjacent gold-minus-silver relative-return signs and fades
the relative move only when at least four components share one strict sign
and the complete weekly net has that same sign.

Positive breadth plus a positive net sells XAU and buys XAG; negative breadth
plus a negative net buys XAU and sells XAG. Zero counts toward neither side.
The two legs target equal absolute USD notionals within 20 percent and share
one aggregate `RISK_FIXED=1000` frozen-stop budget. The normal exit is the
next broker-week boundary, with a ten-day stale repair.

The identity differs from rolling ratio-center/regression/tail models,
completed-week final-close ranking, individual-metal weekly divergence,
session/overnight flow decomposition, and multi-week ratio paths. It is also
mechanically unrelated to the certified single-symbol long-only XNG
two-day cumulative-RSI2 pullback. Mechanical distinction is a diversification
hypothesis only; Q09 alone may establish realized portfolio correlation.

## Reputable source and governance trail

The bounded source packet cites Karsten Schweikert (2018), "Are gold and
silver cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, DOI
`10.1016/j.jbankfin.2017.11.010`, and CME Group's official gold/silver-ratio
spread definition. The packet explicitly treats the exact five-session daily
breadth fade as an untested QM translation; no source return, density, CFD
equivalence, neutrality, cost, or correlation result transfers.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `25a9c6356` |
| deterministic EA-ID reservation | `648639751` |
| G0-approved card | `a28b27bad` |
| two-slot magic allocation and resolver | `921bdc457` |
| fixed-risk basket setfile | `ea17c7ac7` |
| implementation and Q01 build | `060bdc931` |
| strict compile summary | `D:/QM/reports/compile/20260821_061039/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_061103.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41085/P1/P1_QM5_41085_result.json` |

The pump's governed artifact commit `ea17c7ac7` captured the newly generated
41085 setfile alongside seven concurrent factory setfile updates. This lane
did not stage, edit, or revert those unrelated paths.

## Q01 evidence

- canonical pre-allocation dedup: CLEAN across 4,572 registry rows and 625
  root cards, followed by manual family review;
- deterministic reference suite: 10 tests passed;
- build prerequisite guard, card schema, prohibited-ML, G0, and spec-document
  lints: PASS;
- strict MetaEditor compile: PASS, 0 errors, 0 warnings;
- targeted strict V5 build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- MQ5 SHA-256: `4686F6F313FF5EBCD6CE0739A2C3C3054963F20DC7D4AC8418728FDC61FB781E`;
- EX5 SHA-256: `8324CA4C21B11337FB55BCC48B4AF9B81EEA09CFAB7B786FCDC47C2A1D3F6650`;
- setfile byte SHA-256: `E155B6F2FEA98E8ADF159A467C4F39971ECC614F72C204A75CE0A7BE1C0E042C`;
- normalized set build hash: `2d15f0460f8698a8c76104c105e51edfacae47201af017e2bb319877913eef59`;
- strict build-report SHA-256: `F30AFAFC68442152D009A3B3DC229D8A6491119C3D34F3A387EAC0DBFE3E38FE`;
- static P1-report SHA-256: `5B4809B2321906FE6BE3AAA85250495F615050D10F72F1D260D0A2DC9C69403F`.

The sole preset is one D1 logical-basket backtest set with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No manual tester or smoke backtest ran.

## Q02 target preflight

The supported target view had no existing work item:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_41085
count=0
```

The non-mutating target-only preview selected exactly one fresh baseline row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41085 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

The preview carried no `--apply` flag and made no queue mutation.
A final read-only target reconciliation after the capacity census still
returned `count=0`.

## Binding capacity stop

At `2026-08-21T06:13:12Z`, the canonical read-only `farmctl mt5-slots`
inventory reported eight running governed research terminals against the
paced ceiling of seven: `T1`, `T2`, `T3`, `T4`, `T6`, `T8`, `T9`, and `T10`.
It reported no duplicate terminal workers and no orphaned terminal processes.
The separate `T_Live` and FTMO processes were observed only so they could be
excluded; neither was accessed or changed.

Because the terminal-count admission ceiling already exceeded the allowed
maximum, it bound before the whole-host CPU probe. Per the mission stop rule,
this lane issued no target-only apply command, dispatcher tick, terminal
reservation or control, requeue, priority change, cancellation, manual
tester, or backtest.

## Safe handoff

After governed research occupancy falls below seven, repeat the exact target
work-item query, target-only preview, terminal census, and fresh whole-host
CPU sample before using the target-only `--apply` path for `QM5_41085`. Do not
broaden the sweep or create a duplicate.

This record does not authorize AutoTrading, `T_Live`, deploy/T_Live manifest
changes, portfolio-gate changes, portfolio admission, a correlation waiver,
or live use. Q02 must retire the identity on zero packages, fewer than five
completed packages per full post-warm-up year, nonpositive governed
economics, or any hard-rule violation.

Machine-readable evidence:
`artifacts/qm5_41085_q02_cpu_ceiling_stop_20260821T061312Z_board_advisor.json`.
