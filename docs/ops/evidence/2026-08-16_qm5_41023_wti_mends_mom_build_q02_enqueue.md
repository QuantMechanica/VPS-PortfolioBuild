# QM5_41023 WTI Boundary-Segment Momentum Build And Q02 Enqueue

Date: 2026-08-16

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 ENQUEUED`

## Candidate And Claim Boundary

`QM5_41023_wti-mends-mom` is an exact-`XTIUSD.DWX`, D1, low-frequency
structural continuation candidate. On the first executable bar of a new broker
month it reconstructs the immediately prior month, computes the opening return
`log(PriorMonthFifthClose / PriorPriorMonthEndClose)` and closing return
`log(PriorMonthEndClose / PriorMonthSixthFromEndClose)`, and enters only when
both non-overlapping segment signs agree. The position has a frozen
`3.5 * ATR(20,D1)` risk stop, no target, and closes on the first tick of the
sixth D1 bar in the entry month.

This is a direct crude-oil carrier and a different information object from the
certified XAU/SP500/NDX/XNG book. It does not establish realized
decorrelation, certification, or portfolio admission; Q09 alone may establish
correlation after the baseline survives its earlier gates.

The lineage is the fully reviewed, peer-reviewed Moskowitz, Ooi, and Pedersen
(2012) JFE paper. The paper supplies the own-return continuation family and
explicit WTI membership, but not the two boundary segments. Their exact
indexes, agreement gate, month clock, CFD carrier, risk, and lifecycle are
disclosed QM falsification choices; no source performance transfers.

## Approval, Allocation, And Deduplication

- Source approval: `75f0881c0ff35cb1ad8744d9b086f4606cbe64ec`.
- Deterministic allocation of `QM5_41023`:
  `496b59a7e1af0f0d2045394228e397076d12b9b3`.
- Strategy Card and OWNER G0 approval:
  `5e2c619557b7e7f4eb21fa757e758ab104f13113`.
- V5 implementation and Q01 seal:
  `95fbf9f4ee483ff352759cbd86ba8c8cdc79fc16`.
- The canonical dedup checker scanned 4,510 registry rows and 606 root cards,
  found no exact match, and raised the expected `wti-mdual-mom` and
  `wti-mclose-mom` family neighbors.
- Manual review also separated `QM5_41013_wti-mopen-mom`,
  `QM5_20187_wti-tsmom1m`, `QM5_13049_xti-1w-mom-vol`, and
  `QM5_12567_cum-rsi2-commodity` by information object and lifecycle.
- Verdict:
  `CLEAN_WTI_DISJOINT_PRIOR_MONTH_BOUNDARY_SEGMENT_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Backtest preset:
  `framework/EAs/QM5_41023_wti-mends-mom/sets/QM5_41023_wti-mends-mom_XTIUSD.DWX_D1_backtest.set`.
- Locked risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; both news axes and Friday close OFF.
- Reference suite: 10 tests PASS, covering exact opening/closing endpoint
  selection, middle-path exclusion, long/short/agreement/equality states,
  minimum month length, non-overlap, label normalization, timing, invalid
  prices/order, and sixth-bar/stale exits.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings. Log:
  `framework/build/compile/20260816_124841/QM5_41023_wti-mends-mom.compile.log`.
- Strict targeted build check: PASS, 0 failures, 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_124841.json`.
- Static P1: PASS:
  `D:/QM/reports/pipeline/QM5_41023/P1/P1_QM5_41023_result.json`.
- Magic row: `41023,wti-mends-mom,0,XTIUSD.DWX,410230000`; regenerated
  resolver retained 16,072 rows with zero drops.
- The separate repo-wide historical registry audit remains red on unrelated
  legacy missing/mismatched EA rows. The target-specific strict build gate has
  zero registry, compile, setfile, forbidden-code, or schema findings; no
  unrelated registry row was changed.

## Capacity And Target-Only Queue Mutation

The first read-only path-anchored capacity sample at
`2026-08-16T12:52:41.7413937Z` found 4 of the 7 allowed T1-T10 tester
terminals. The immediate pre-apply sample at
`2026-08-16T12:52:58.1135204Z` found 3 of 7, so the CPU ceiling did not bind.
`T_Live` was explicitly excluded from both samples.

Dry run:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41023 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

Applied once:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41023 --symbols XTIUSD.DWX --max-part2-per-run 0
APPLY=True
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The canonical farm DB contained exactly one matching Q02 row at the read-only
observation time:

- work item: `255bc16d-bce6-4311-b84e-45ffe6b79038`;
- phase/kind: `Q02` / `backtest`;
- symbol: `XTIUSD.DWX`;
- created: `2026-08-16T12:52:58+00:00`;
- observed status: `pending`, unclaimed;
- attempt count: `0`; verdict: unset.

The post-enqueue read-only process sample at
`2026-08-16T12:53:02.5258101Z` remained 3 of 7. The queue report is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json` and its SHA-256 is
`fd25c4e9daa8352a6074db5e0817fcc2f207c00ea7de10b57049f3919cf96dc3`.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `98bb6d49df8a97fea29244859df588375713f153d4e080b9f83127dbd3171619` |
| G0 decision | `6d0d77f0e5152ccd236c043fabc2c14d40d6bccab0ea8b02cd0b1824df70a413` |
| governed source packet | `e0bb223973fe31ca4aba92c0219095ced61517e675cc96c1ca209f163536dae9` |
| all three synchronized card copies | `a4ba09bd8fa37906d48da87c3a7e20b8b7a245d057c961de7119adda4561adb4` |
| MQ5 source | `bcf2b0671d56f55e286d10e625d3d6551df2ff3df1b72a8ade4a8d80c26ed000` |
| compiled EX5 | `af0643ab2bf268e8c398f199f272435f4e3e09b659f9df599ebc7968a0d25cd0` |
| fixed-risk setfile | `52ed85d7adbb70e151eb53787b246a74fb9e793e2ed05919e45bd14adad5ef45` |
| reference test | `2bc0e2621f00aa41437f04147405e04cd4b20804555b8001ed334d6b438f0905` |
| strict build-check report | `59e13e99a587e67f134423da15c2b07f1fd89d9e00161000183b5f5f2cd13411` |
| static P1 result | `add9a9638f818f2176b97f749ae47587772a428d9ea61452fd13d2abefb7c736` |

## Safety And Handoff

No manual tester run, pipeline phase runner, dispatcher tick, terminal start or
stop, AutoTrading action, `T_Live` action, live/demo/shadow/stress preset,
portfolio-gate edit, portfolio admission, deploy manifest, or `T_Live`
manifest was performed. Q02 must retire below five completed positions per
full post-warm-up year, on zero trades, overlapping/wrong segment mechanics,
nondeterminism, or nonpositive governed economics. This receipt records an
enqueue, not a Q02 verdict or certification.
