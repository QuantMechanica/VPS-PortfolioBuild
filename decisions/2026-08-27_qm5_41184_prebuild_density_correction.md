# QM5_41184 Pre-Build Density Correction

Date: 2026-08-27

Decision: `APPROVED_PREBUILD_CORRECTION` for the single locked label-run
boundary in `QM5_41184_wti-mww-runs-shift-tr`.

## Timing And Evidence Boundary

The defect was found by exhaustive rank-label enumeration after G0 approval
and before compilation, Q01, Q02 enqueue, any tester run, or any market-result
observation. No price data, performance statistic, or downstream gate result
was used.

Durable exact-enumeration receipt:
`artifacts/qm5_41184_prebuild_runs_density_enumeration_20260827.json`, SHA-256
`46DE2EA549E7B01EB2ECB26B7FBC78EEFB31A94EC01FB5B882310A760BB0C400`.

## Defect

The approved source packet transcribed the balanced five/five exact run table
incorrectly. The correct counts for runs two through ten are:

```text
R:      2  3  4  5  6  7  8  9 10
count:  2  8 32 48 72 48 32  8  2
```

Therefore the original `R<=5` boundary admits `90/252` label orders, not
`114/252`, and implies only `12*90/252 = 4.2857` decisions/year. That fails
the already-binding minimum prior of five completed trades in every full
post-warm-up year.

## Correction

Lock the only Q02 baseline at `R<=6`. It admits `162/252 = 9/14` orders,
split by label reflection into 81 BUY and 81 SELL rank states. Its pre-market
density prior is `12*9/14 = 54/7`, approximately `7.7143` decisions/year.

For balanced sample sizes of five and five, six is the null expected run
count. Here it is an inclusive structural clustering boundary, not a
statistical critical value or significance claim. There is no sweep,
alternative threshold, conditional fallback, or optimization surface.

The governed source packet changed from committed SHA-256
`90486EA94D449BB207D1625000A1200CDE3F1B0B7D4B05C712F4D1A1E03C9806` to
corrected SHA-256
`AB4B8ADE3D3E4B4CA1B7AE6D9ADE98DD69AD30BC5D5CEDEC0EC6F9D073795FB6`.
The card, source approval, G0 decision, SPEC, source, setfile, implementation,
and reference suite must all lock the corrected value.

## Duplicate And Rescue Adjudication

The pre-allocation dedup receipt tested the same fixed five/five pooled-label
runs and median-direction mechanic family with the superseded numeric
boundary. Changing only the inclusive fixed boundary before any result does
not collapse this mechanic into chronological median runs, a maximum signed
ECDF gap, Mann-Whitney wins, Pettitt change points, or the certified XNG RSI
pullback. The `CLEAN` family adjudication remains applicable, with the final
identity suffix updated from `LE5` to `LE6`.

This correction makes a predeclared feasibility floor truthful. It does not
authorize a post-result rescue. Any Q02 density or economics failure under
`R<=6` retires the candidate without changing the endpoint count, block size,
boundary, side, carrier, risk, stop, hold, or filters.
