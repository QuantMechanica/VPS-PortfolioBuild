# QM5_41126 WTI monthly path-efficiency momentum — CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_41126_wti-mpath-eff-mom`

Outcome: **SOURCE BUILD COMMITTED; CPU CEILING HIT BEFORE GOVERNED COMPILE;
Q01 PENDING; Q02 NOT ENQUEUED**

## New direct-energy edge

QM5_41126 is one low-frequency structural WTI continuation sleeve on exact
`XTIUSD.DWX`, D1. At the first executable D1 bar of a new broker month it
reconstructs the immediately completed month from 17 through 23 D1 closes plus
the adjacent older boundary close. For every chronological daily log return
ending in that completed month it computes:

```text
N = sum(r)
P = sum(abs(r))
E = abs(N) / P
```

It requires finite `P>0`, nonzero `N`, endpoint identity, bounded `E`, and the
inclusive gate `E>=0.20`. Positive `N` buys WTI and negative `N` sells WTI.
The month attempt is persisted before every fallible gate, so a flat or failed
state cannot retry during that broker month.

The approved baseline locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, one position,
a frozen `3.5*ATR(20,D1)` hard stop, no profit target, a 1,500-point spread
cap, news filtering OFF, no Friday close, first-later-month exit, and a
40-calendar-day stale repair. Q02 must retire the baseline below five completed
positions in any full post-warm-up year.

This is a direct crude-oil economic carrier outside the current
XAU/SP500/NDX/XNG book. It is not a claim of profitability or realized
decorrelation; Q09 alone owns portfolio overlap evidence.

## Reputable source and non-duplicate boundary

The bounded packet is
`strategy-seeds/sources/MOP-WTI-MPATH-EFF-MOM-2026/source.md`. Its governed
parent is Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, represented
by the complete 23-page author-hosted paper receipt in
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. The paper explicitly
includes NYMEX WTI and reports a one-month formation/hold commodity portfolio.
The L1 daily-path gate, fixed threshold, Darwinex CFD mapping, execution, and
risk contract are disclosed QM falsification translations, not source results.

The fail-closed pre-allocation checker scanned 4,625 registry identities,
1,294 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`. The
post-allocation receipt scanned 4,626 identities and 1,295 cards and found only
the two expected self-hits for EA 41126.

The mechanic differs from unconditional endpoint momentum, the existing
twelve-month WTI path-efficiency design, monthly L2/RMS coherence, daily sign
breadth, block-vote, and ordered-extreme EAs. It qualifies one immediately
completed month with `abs(sum(r))/sum(abs(r))`, an inclusive `0.20` gate, and
no rolling center, oscillator, rank, vote, sequence, or ML state.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| durable OWNER source approval and pre-allocation dedup | `5d6f31cd203e5aacab8a7fea993abb4eaff3008a` |
| bounded reputable-source extraction | `92feace6722fbf0183d9b35641c5c69f1daa5124` |
| atomic EA-ID reservation | `423a2fb48c1cffe64894a2b966df77cdb3fcca4d` |
| approved G0 card and post-allocation dedup | `839fa13c7d90226db8a392ac0807340e59117257` |
| magic allocation, resolver binding, and local card | `689f1dd0af2b0d2e27855fc10a36b27dd8766193` |
| EA source, SPEC, reference suite, and fixed-risk set | `468b570df0bef85ad1143afd8f4a89da3682ee34` |

Execution identity is slot 0 `XTIUSD.DWX`, D1, magic `411260000`. The governed
allocator added exactly one active magic row and one resolver row, deleted zero
retired rows, and copied the approved card byte-for-byte. Its strict run used
no `--allow-dropped` option; three exact empty legacy-directory identities were
materialized only long enough to preserve pre-existing active resolver rows,
then removed.

## Source-level validation

- Strategy-card schema/prohibited-ML lint: PASS.
- G0 numbered-section contract lint: PASS.
- Registry identity, magic row, resolver binding, exact directory, symbol, and
  strategy binding: PASS.
- Independent deterministic reference suite: 9 tests PASS.
- SPEC validator: PASS.
- Build guardrails: PASS across two checked files with zero findings.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- Approved and EA-local cards are byte-identical at SHA-256
  `6AFE8FE6CF4287D0CF914DDF641C6782812CE3D73DCD585FEAA88AEE2E01DDFB`.
- Scoped whitespace validation: PASS.

The backtest-only set locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Its SHA-256 is
`CCFE418309110B9F30AE7513CB366A58B83B90BAA89FA1ADC0174E51306EFC5A`.
It retains `build_hash: pending` because no compiler output exists.

## Compile and Q01 state

An ad-hoc build-check invocation was refused before compilation by the live
factory guard with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry or bypass
was used. The prescribed governed compile was not enqueued because the fresh
capacity sample below triggered the mission's explicit stop condition.

At handoff, read-only `farmctl work-items --ea QM5_41126` returned zero items,
and `farmctl compile-status QM5_41126_wti-mpath-eff-mom` returned
`NOT_ENQUEUED`. No `.ex5` exists, no build-check result exists, and Q01 remains
pending. No compile PASS is claimed.

## CPU-ceiling stop and Q02 state

Five consecutive whole-host `Processor(_Total)\% Processor Time` samples at
two-second intervals completed at `2026-08-23T06:28:37.7921410Z`:

`98.98, 98.93, 99.28, 95.90, 98.99`

Average CPU was 98.42 percent and maximum CPU was 99.28 percent, above the
paced-fleet ceiling of 97 percent. The sample endpoint saw six
`terminal64.exe` and four `metatester64.exe` processes.

This is the binding stop condition. No governed compile item, Q02 preview, Q02
work item, dispatcher tick, terminal reservation, or manual backtest was
created. Q02 is also gated by the absent strict compile, EX5, final set hash
binding, and Q01 PASS.

## Safe continuation and safety boundary

After sustained whole-host CPU is below 97 percent, enqueue the governed
compile for exactly `QM5_41126_wti-mpath-eff-mom`. Require zero errors and
warnings, a non-empty EX5, build-check PASS, final set hash binding, and Q01
PASS. Then take a fresh capacity sample and enqueue exactly one Q02 row. Do not
change the approved mechanic to manufacture the five-per-year floor.

No AutoTrading action, live/deploy artifact, `T_Live` mutation,
`T_Live`-manifest change, portfolio-gate change, portfolio admission,
correlation waiver, or decorrelation claim occurred.

Machine-readable companion:
`artifacts/qm5_41126_wti_mpath_eff_mom_source_build_q02_cpu_ceiling_handoff_20260823T062837Z_board_advisor.json`.
