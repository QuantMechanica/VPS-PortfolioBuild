# QM5_41125 XAU/XAG monthly RMS-coherence reversion — CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_41125_xauxag-mrms-coherence-rv`

Outcome: **SOURCE BUILD COMMITTED; CPU CEILING HIT BEFORE GOVERNED COMPILE;
Q01 PENDING; Q02 NOT ENQUEUED**

## New relative-value commodity edge

QM5_41125 is one low-frequency structural gold/silver basket on exact
`XAUUSD.DWX` and `XAGUSD.DWX`, D1. At the first synchronized executable D1
bar of a new broker month it reconstructs the immediately completed month from
17 through 23 paired closes plus the adjacent older synchronized boundary pair.
For every chronological gold-minus-silver log-ratio return ending in the
completed month it computes:

```text
N = sum(r)
Q = sum(r^2)
C = abs(N) / sqrt(n * Q)
```

It requires finite `Q>0`, nonzero `N`, endpoint identity, bounded `C`, and
inclusive `C>=0.16`. Positive `N` is faded with SELL XAU / BUY XAG; negative
`N` is faded with BUY XAU / SELL XAG. The monthly attempt is persisted before
every fallible gate, so a flat or failed state cannot retry.

The approved baseline locks aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
equal target absolute USD notionals, no more than 20% realized notional
mismatch, frozen `3.5*ATR(20,D1)` hard stops, no target, fixed spread caps,
news filtering OFF, no Friday close, next-month exit, and 40-calendar-day
stale repair. Q02 must retire the baseline below five completed packages in
any full post-warm-up year.

The opposite legs are designed to reduce common outright-metal direction, but
this is not a claim of dollar, beta, factor, volatility, or portfolio
neutrality. Q09 alone owns the realized portfolio result.

## Reputable source and non-duplicate boundary

The bounded source packet is
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MRMS-COHERENCE-RV-2026/source.md`.
It preserves Karsten Schweikert (2018), *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`; CME Group's gold/silver
intermarket-spread research; and the complete-read Moskowitz, Ooi, and Pedersen
(2012) *Journal of Financial Economics* path lineage. The daily relative-path
coherence gate, `0.16` threshold, fade direction, CFD mapping, execution, and
risk contract are disclosed QM falsification translations rather than source
results.

The fail-closed pre-allocation checker scanned 4,624 registry identities,
1,293 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`. The post-
allocation receipt found only the two expected self-hits for EA 41125.

The mechanic differs from rolling ratio/OLS/quantile/MAD equilibrium systems,
32-month variance-ratio memory, daily sign breadth, fixed blocks, ordered
extreme states, and the L1 path-efficiency basket. It qualifies one completed
month with the magnitude-sensitive L2 statistic
`abs(sum(r))/sqrt(n*sum(r^2))`. It also differs from the neighboring outright-
WTI coherence build by using a synchronized relative series, contrarian sides,
equal-notional sizing, and atomic two-leg lifecycle.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| durable OWNER source approval and pre-allocation dedup | `d271c56f1c4d4545d3f7ba31f8a0ecaae5ead764` |
| bounded reputable-source extraction | `fad340a24369354f4f562689a8969a4337059612` |
| atomic EA-ID reservation | `eb21ed6be38c4b5bc0683df852b7eb422063f0bc` |
| approved G0 card and post-allocation dedup | `c8649fc7de2a8dc7689e35a02aa5e8d5ae32adc5` |
| magic allocation, resolver binding, and local card | `5d14f791077b31e4c5365a4d434cd49c55b2df42` |
| deterministic card-heading contract alignment | `b8a98c0675717ba94900829df07dc72b4f0ac23d` |
| EA source, SPEC, reference suite, manifest, and fixed-risk set | `715a14a86c63b45666bdfa130ba326e312e466df` |

Execution identity is host slot 0 `XAUUSD.DWX`, magic `411250000`, and
companion slot 1 `XAGUSD.DWX`, magic `411250001`. The governed allocator added
exactly two active registry rows and two resolver rows, deleted zero retired
rows, and copied the approved card byte-for-byte. Its initial strict run failed
closed on three pre-existing active legacy IDs whose EA directories are
absent. A strict rerun temporarily materialized only those three exact empty
directory identities, used no `--allow-dropped` option, preserved all existing
rows, added only 41125, and removed the empty placeholders.

## Source-level validation

- Strategy-card schema/prohibited-ML lint: PASS.
- G0 numbered-section contract lint: PASS.
- Registry ID, two magic rows, resolver identities, exact directory, symbols,
  and strategy binding: PASS.
- Independent deterministic reference suite: 8 tests PASS.
- SPEC validator: PASS.
- Build guardrails: PASS across two checked files with zero findings.
- Symbol-scope validator: `BASKET_OK`, zero violations, manifest symbols exact.
- Basket manifest JSON: PASS.
- Approved and EA-local cards are byte-identical at SHA-256
  `3CD258146A0B10EDA782228C7A6DE34865EFAED823D5AA7FEFA8CE8BF846EFD2`.
- Scoped whitespace validation: PASS.

The sole logical backtest set locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Its SHA-256 is
`437849FB05E9ED00AC64C9071A386B1D15A564186FE762E7EA65E0E5044D0867`.
It retains `build_hash=pending` because no compiler output exists.

## Compile and Q01 state

An ad-hoc build-check invocation was refused before compilation by the live
factory guard with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry or bypass
was used. The prescribed governed compile was not enqueued because the fresh
capacity sample below triggered the mission's stop condition.

At handoff, read-only `farmctl work-items --ea QM5_41125` returned zero items.
No `.ex5` exists, no build-check result exists, and Q01 remains pending. No
compile PASS is claimed.

## CPU-ceiling stop and Q02 state

Five consecutive whole-host `Processor(_Total)\% Processor Time` samples at
two-second intervals completed at `2026-08-23T05:29:01.2848731Z`:

`96.62, 99.91, 99.90, 99.90, 100.00`

Average CPU was 99.27 percent and maximum CPU was 100 percent, above the
paced-fleet ceiling of 97 percent. The sample endpoint saw eight
`terminal64.exe` and six `metatester64.exe` processes.

This is the binding stop condition. No governed compile item, Q02 preview,
Q02 work item, dispatcher tick, terminal reservation, or manual backtest was
created. Q02 is additionally gated by the absent strict compile, EX5, final
set hash binding, and Q01 PASS.

## Safe continuation and safety boundary

After sustained whole-host CPU is below 97 percent, enqueue the governed
compile for exactly `QM5_41125_xauxag-mrms-coherence-rv`. Require zero errors
and warnings, a non-empty EX5, build-check PASS, final set hash binding,
basket-manifest validation, and Q01 PASS. Then take a fresh capacity sample and
enqueue exactly one logical Q02 row. Do not change the approved mechanic to
manufacture the five-per-year floor.

No AutoTrading action, live/deploy artifact, `T_Live` mutation,
`T_Live`-manifest change, portfolio-gate change, portfolio admission,
correlation waiver, neutrality claim, or decorrelation claim occurred.

Machine-readable companion:
`artifacts/qm5_41125_xauxag_mrms_coherence_rv_source_build_q02_cpu_ceiling_handoff_20260823T052901Z_board_advisor.json`.
