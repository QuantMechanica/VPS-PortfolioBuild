# QM5_41022 WTI Split-Week Momentum Build And Q02 Enqueue

Date: 2026-08-16

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 ENQUEUED`

## Candidate And Claim Boundary

`QM5_41022_wti-wdual-mom` is an exact-`XTIUSD.DWX`, D1, low-frequency
structural continuation candidate. On an eligible broker Monday it reconstructs
the exact prior Friday-through-Friday session sequence, computes the disjoint
opening return `log(PriorTuesdayClose / PrecedingFridayClose)` and closing
return `log(PriorFridayClose / PriorTuesdayClose)`, and enters only when both
signs agree. The position has a frozen `3.5 * ATR(20,D1)` risk stop, no target,
and the framework Friday close at broker hour 21.

This is a direct crude-oil carrier and a different information object from the
certified XAU/SP500/NDX/XNG book. It does not establish realized
decorrelation, certification, or portfolio admission; Q09 alone may establish
correlation after the baseline survives its earlier gates.

The primary lineage is the fully reviewed, peer-reviewed Moskowitz, Ooi, and
Pedersen (2012) JFE paper. Zhao et al. (2026) supplies bounded weekly-commodity
context only; its inaccessible full text and the untested QM translation are
disclosed. The exact split, agreement gate, broker clock, CFD carrier, risk,
and lifecycle are QM choices, not source results.

## Approval, Allocation, And Deduplication

- Source approval: `354986d94dc460275106668af38394d2bcc50691`.
- Deterministic allocation of `QM5_41022`: `4ff30002c2ab2fa9846498f5fa7c16ace8f4eb50`.
- Strategy Card and OWNER G0 approval: `9ac64de237d23146c61f1bf956455122fc3c352d`.
- V5 implementation and Q01 seal: `b00de2104a746e6d8031cc98738f79e9b7a21387`.
- The canonical dedup checker scanned 4,509 registry rows and 605 root cards,
  found no exact match, and raised the expected `wti-wopen-mom` and
  `wti-wclose-mom` family neighbors.
- Manual review also separated `QM5_41021_wti-mdual-mom`,
  `QM5_13049_xti-1w-mom-vol`, `QM5_21521_wti-flow-switch`, weekly-range/ORB
  EAs, and `QM5_12567_cum-rsi2-commodity` by information object, clock, and
  lifecycle.
- Verdict:
  `CLEAN_WTI_DISJOINT_SPLIT_WEEK_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Backtest preset:
  `framework/EAs/QM5_41022_wti-wdual-mom/sets/QM5_41022_wti-wdual-mom_XTIUSD.DWX_D1_backtest.set`.
- Locked risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; both news axes OFF.
- Reference suite: 11 tests PASS, covering exact weekday reconstruction,
  holiday gaps, segment-sign agreement, equality/invalid states, and Monday
  timing.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings. Log:
  `framework/build/compile/20260816_103801/QM5_41022_wti-wdual-mom.compile.log`.
- Strict targeted build check: PASS, 0 failures, 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_103954.json`.
- Static P1: PASS:
  `D:/QM/reports/pipeline/QM5_41022/P1/P1_QM5_41022_result.json`.
- Magic row: `41022,wti-wdual-mom,0,XTIUSD.DWX,410220000`; regenerated
  resolver retained 15,980 rows with zero drops.

## Capacity And Target-Only Queue Mutation

The first read-only capacity sample at `2026-08-16T10:42:49.3318500Z` found
5 of the 7 allowed T1-T10 tester terminals. The immediate pre-apply sample at
`2026-08-16T10:44:37.3038874Z` found 4 of 7, so the CPU ceiling did not bind.
No `T_Live` process was included.

Dry run:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41022 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

Applied once:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41022 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=True
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The canonical farm DB contained exactly one matching Q02 row at the read-only
observation time:

- work item: `ebfa5729-6f34-4366-835d-511f7a1a4c44`;
- phase/kind: `Q02` / `backtest`;
- symbol: `XTIUSD.DWX`;
- created: `2026-08-16T10:44:42+00:00`;
- observed status: `active`, automatically claimed by the paced factory as
  `T4` at `2026-08-16T10:45:00+00:00`;
- attempt count: `0`; verdict: unset.

The post-enqueue read-only process sample at
`2026-08-16T10:45:26.7536168Z` remained 4 of 7. The queue report is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json` and its SHA-256 is
`859beb280f2ac3f7736b3f4354478cacf016a3f7fb6e3d96824fe83ef4dda3d8`.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `8541a31b5debb6dd202be072581b2148a52ee617fc76c642ff7d144fd7f241ff` |
| G0 decision | `8bf389afbdd64868b949c87c8f7c5fa180f4e8237167bd1f0a3590a39e7df4ac` |
| governed source packet | `68948e5745eaa817dd7cb347a236510246d3445af83bf7110ad93e670945bb7b` |
| all three synchronized card copies | `1da97437f76e691d0c39c7ae316c94fba70b49678d02a3b4118154ae2581a636` |
| MQ5 source | `c58af047b58ee64ce1c65130692ee52b33900482942e62ce7f2a89f96bd596dc` |
| compiled EX5 | `cad0ed2b24989d3bad5da3517a3468b175f4e0e02ff1a884416b153a3eac1cd6` |
| fixed-risk setfile | `f87f176714b691ed547be990eeb4330dc98feff56b0257dfabafe10a07235bfe` |
| reference test | `947e01275e151b680f18e0edc80850ea1a42ef9635978cb5e9d0804ccba7c6e2` |
| strict build-check report | `87549d9850f5872590ddb2ceaa42a0cc910d388a904fdac2ea28856891b40c80` |
| static P1 result | `ef8d05f769cc2194df4d7d01a4a65d5c885e90b869a4737101f60fe4fc7db739` |

## Safety And Handoff

No manual tester run, pipeline phase runner, dispatcher tick, terminal start or
stop, AutoTrading action, `T_Live` action, live/demo/shadow/stress preset,
portfolio-gate edit, portfolio admission, deploy manifest, or `T_Live`
manifest was performed. Q02 must retire below five completed positions per
full post-warm-up year, on zero trades, invalid mechanics, nondeterminism, or
nonpositive governed economics. This receipt records an enqueue, not a Q02
verdict or certification.
