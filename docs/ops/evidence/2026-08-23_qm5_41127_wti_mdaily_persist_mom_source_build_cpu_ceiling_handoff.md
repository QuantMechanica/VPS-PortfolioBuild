# QM5_41127 WTI monthly daily-persistence momentum - CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_41127_wti-mdaily-persist-mom`

Outcome: **SOURCE BUILD COMMITTED; CPU CEILING HIT BEFORE GOVERNED COMPILE;
Q01 PENDING; Q02 NOT ENQUEUED**

## New direct-energy edge

QM5_41127 is one low-frequency structural WTI continuation sleeve on exact
`XTIUSD.DWX`, D1. At the first executable D1 bar of a new broker month it
reconstructs the immediately completed month from 17 through 23 D1 closes plus
the adjacent older boundary close. For every chronological daily log return
ending in that month it computes:

```text
N   = sum(r)
mu  = N/n
S   = sum((r-mu)^2)
A   = sum((r[j]-mu)*(r[j-1]-mu)), j=1..n-1
rho = A/S
J   = rho + 1/(n-1)
```

It requires finite `S>0`, endpoint identity, bounded `rho`, and strict `J>0`.
Positive `N` buys WTI and negative `N` sells WTI. The month attempt is
persisted before every fallible gate, so a flat or failed state cannot retry
during that broker month.

The approved baseline locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, one position,
a frozen `3.5*ATR(20,D1)` hard stop, no target, a 1,500-point spread cap, news
filtering OFF, no Friday close, first-later-month exit, and a 40-calendar-day
stale repair. Q02 must retire the baseline below five completed positions in
any full post-warm-up year.

This is a direct crude-oil economic carrier outside the current
XAU/SP500/NDX/XNG book. It is not a claim of profitability or realized
decorrelation; Q09 alone owns portfolio overlap evidence.

## Reputable source and non-duplicate boundary

The bounded packet is
`strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md`.
Its governed parents are Mehlitz and Auer (2024), *The European Journal of
Finance* 30(8), 773-802, DOI `10.1080/1351847X.2023.2220118`, and Moskowitz,
Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. Their packets preserve complete-read
evidence and explicit WTI membership. The within-month D1 horizon, fixed
short-sample neutralization, continuous-CFD mapping, execution, and risk
contract are disclosed QM falsification translations, not source results.

The fail-closed pre-allocation checker scanned 4,626 registry identities,
1,295 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`. The post-
allocation receipt scanned 4,627 identities and 1,296 cards and found only the
two expected registry self-hits for EA 41127.

The mechanic differs from unconditional endpoint momentum, the 32-month q2
robust variance-ratio EA, other multi-month memory horizons, daily sign
breadth, fixed calendar-block votes, ordered extremes, mean/RMS coherence, L1
path efficiency, and XAU/XAG relative baskets. It centers one immediately
completed month of WTI daily returns, multiplies every adjacent pair, applies
the fixed `1/(n-1)` correction, and follows the endpoint only when the score is
strictly positive. It has no fitted threshold, significance state, reversal
matrix, oscillator, rank, vote, sequence, or ML state.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| durable OWNER source approval and pre-allocation dedup | `4a9af0a2452b1f9bb3909b30987c068d07ab1c6b` |
| bounded reputable-source extraction | `75f0006ccc1db22f44c9214fbaa9fcce4c8be951` |
| atomic EA-ID reservation | `11a2fc76be79aacc5ba0ea8cf72ceaeb6e196958` |
| approved G0 card and post-allocation dedup | `1930703f74e99114d73cdf59265b2986eeada2a7` |
| magic allocation, resolver binding, and local card | `777c911a150e0d1d7c8205d591437f95904e9722` |
| EA source, SPEC, reference suite, and fixed-risk set | `713ff394c3b0d05693181e1bdaf55bc1859c2a93` |

Execution identity is slot 0 `XTIUSD.DWX`, D1, magic `411270000`. The governed
allocator added exactly one active magic row and one resolver row, deleted zero
retired rows, and copied the approved card byte-for-byte. Its strict run used
no `--allow-dropped` option; three exact empty legacy-directory identities were
materialized only long enough to preserve pre-existing active resolver rows,
then removed.

## Source-level validation

- Strategy-card schema/prohibited-ML lint: PASS.
- G0 numbered-section contract lint: PASS.
- Build-skill approved-card/registry/directory preflight: PASS.
- Registry identity, magic row, resolver binding, exact directory, symbol, and
  strategy binding: PASS.
- Independent deterministic reference suite: 9 tests PASS.
- SPEC validator: PASS.
- Build guardrails: PASS across two checked files with zero findings.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- Approved and EA-local cards are byte-identical at SHA-256
  `4FF13548996449A6A875200768FDE69BCBBB4F5BE531F3223019E88D60CEAD96`.
- Scoped whitespace validation: PASS after removal of the source-file EOF
  blank line.

The repository-wide registry validator remains red on pre-existing legacy
invalid-ID/slug and orphaned-magic rows. The governed allocator's scoped
before/after invariants passed: one new row, one new resolver binding, zero
retired deletions, and zero status-aware collisions. No legacy registry row
was changed for this mission.

The backtest-only set locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Its SHA-256 is
`C1007FD0612856C378129BFF6DB90DF513BF2C2B96F5C8EC1188AE9D00A2202D`.
It retains `build_hash: pending` because no compiler output exists.

## Compile and Q01 state

Before the capacity sample, read-only `farmctl work-items --ea QM5_41127`
returned zero items and `farmctl compile-status
QM5_41127_wti-mdaily-persist-mom` returned `NOT_ENQUEUED`. No ad-hoc or
governed compiler invocation was attempted.

No `.ex5` exists, no strict build-check result exists, and Q01 remains
pending. No compile PASS is claimed.

## CPU-ceiling stop and Q02 state

Five consecutive whole-host `Processor(_Total)\% Processor Time` samples at
two-second intervals completed at `2026-08-23T07:32:00.2647947Z`:

`100.00, 100.00, 100.00, 100.00, 100.00`

Average and maximum CPU were both 100.00 percent, above the paced-fleet hard
ceiling of 97 percent. The sample endpoint saw ten `terminal64.exe` and six
`metatester64.exe` processes.

This is the binding stop condition. No governed compile item, Q02 preview,
Q02 work item, dispatcher tick, terminal reservation, or manual backtest was
created. Q02 is also gated by the absent strict compile, EX5, final set hash
binding, and Q01 PASS.

## Safe continuation and safety boundary

After sustained whole-host CPU is below 97 percent, enqueue the governed
compiler for exactly `QM5_41127_wti-mdaily-persist-mom`. Require zero errors
and warnings, a non-empty EX5, build-check PASS, final set hash binding, and
Q01 PASS. Then take a fresh capacity sample and enqueue exactly one Q02 row.
Do not change the approved mechanic to manufacture the five-per-year floor.

No AutoTrading action, live/deploy artifact, `T_Live` mutation, T_Live-
manifest change, portfolio-gate change, portfolio admission, correlation
waiver, or decorrelation claim occurred.

Machine-readable companion:
`artifacts/qm5_41127_wti_mdaily_persist_mom_source_build_q02_cpu_ceiling_handoff_20260823T073200Z_board_advisor.json`.
