# QM5_41210 XAU/XAG Same-Calendar One-Standard-Error Relative Seasonality - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41210_xauxag-samecal-tstat_card.md` and
only the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41210`
- slug: `xauxag-samecal-tstat`
- strategy ID: `KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026_S01`
- source ID: `KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- logical basket: `QM5_41210_XAU_XAG_SAMECAL_TSTAT_D1`
- intended magics: `412100000`, `412100001`

The atomic `farmctl reserve-ea-ids` allocator reserved row `41210` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded packet is
`strategy-seeds/sources/KELOHARJU-RCORE-XAUXAG-SAMECAL-TSTAT-2026/source.md`,
SHA-256
`1E9A4E5353EAD5900A0B449276D180DF95C4D104D9347E31E0BA8C0126176929`.
Its durable source approval is
`decisions/2026-08-30_xauxag_same_calendar_tscore_source_approval.md`,
committed before extraction as `ba45caf7c`; the complete bounded extraction
was committed as `1b4994396` before this card decision.

R1 is `PASS_WITH_COMPOSITE_STATISTIC_PAIR_AND_CFD_TRANSLATION_RISK`.
Complete-read, DOI-bearing peer-reviewed trading lineages support recurring
same-calendar commodity information and the governed XAU/XAG monthly
cross-sectional carrier. Commit-pinned primary software fixes the one-sample
mean, sample-variance, standard-error, and score arithmetic. The exact paired
CFD conjunction and fixed threshold are untested. No performance, density,
significance, cost, hedge, CFD-equivalence, or decorrelation result transfers.

## Mechanical Decision

R2 is `PASS`. At each genuine normalized broker-month D1 transition, the card:

1. repairs malformed exposure, closes a surviving prior-month package, and
   consumes the new month before every fallible entry gate;
2. reconstructs synchronized completed XAU and XAG log returns for the
   upcoming calendar month in exact years `Y-1..Y-10`, skipping missing older
   years without substitution and requiring at least five valid pairs;
3. forms `d=r_xau-r_xag`, the arithmetic mean, sample variance with
   denominator `n-1`, standard error `sqrt(variance/n)`, and finite score
   `t=mean/standard_error`;
4. buys XAU/sells XAG only above `+1.0+1e-10`, sells XAU/buys XAG only below
   `-1.0-1e-10`, and consumes every other state flat;
5. splits one `RISK_FIXED=1000` package into equal fixed-risk halves with
   frozen `3.5*ATR(20,D1)` per-leg hard stops and no targets;
6. repairs partial, orphaned, same-direction, duplicate, stopless, or otherwise
   malformed composition immediately; and
7. closes on the next genuine broker-month boundary or after 40 days.

Both news axes, legacy news, and Friday close are OFF. Nonnegative modeled
spread is admitted only through 1,500 XAU points and 3,000 XAG points;
positive finite non-crossed quotes remain mandatory. There is no parameter
sweep, p-value, raw-mean fallback, Huber/rank fallback, current-month signal,
contrarian flip, magnitude sizing, target, trail, partial exit, scale-in, grid,
martingale, or pyramid.

## Data And Determinism

R3 is `PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`.
Registered XAU/XAG D1 histories, broker time, quotes, contract metadata,
positions, deals, and terminal-global attempt state provide every runtime
field. Q02 must prove usable synchronized history, label mapping, density,
fills, two-leg costs, and continuous-CFD behavior.

R4 is `PASS`. The signal uses dates, completed prices, logarithms, ordinary
sums/products, `n-1` sample variance, square root, and comparisons; ATR is
bounded risk plumbing. No trained output, banned signal indicator, external
runtime feed, adaptive PnL fit, scale-in, grid, martingale, or pyramid exists.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xauxag_samecal_tstat_preallocation_dedup_20260830.json`,
SHA-256
`D53CD7B7F36D978F85F4552DE095C3D357A09B9783E74D4BA3C60E60CE74AB80`,
found no exact identity across 4,709 registry rows, 1,355 card files, and 45
Strategy Wiki nodes. It surfaced only the expected raw-mean fuzzy neighbor.

Manual family review separates the executable identity:

- `QM5_20186` follows every nonzero same-calendar arithmetic mean; this card
  scales that mean by sample standard error and abstains inside a fixed band.
- `QM5_41203` uses signed absolute ranks and discards metric distance.
- `QM5_41206` follows an iterative Huber location without `n-1` variance or
  a mean-standard-error gate.
- `QM5_21517` fades a just-completed relative seasonal surprise instead of
  forecasting the upcoming month from matching-calendar observations.
- Existing ratio, OLS/CADF residual, recent-window momentum, channel, session,
  and correlation-break baskets use different information objects.

The locked fixed vector makes the raw mean, signed-rank score, and Huber
location positive while this score remains inside `[-1,+1]`; all three
siblings take long-XAU/short-XAG exposure and this card stays flat. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_SAMECAL_RELATIVE_MEAN_STANDARD_ERROR_GATE_MONTHLY_BASKET`.

## Portfolio Intent And Falsification

This is a confidence-gated, opposite-leg precious-metals relative-value
stream, not another outright XAU strategy. Its prior-year matching-calendar
sample, dispersion gate, shared-risk package, and monthly lifecycle differ
from the certified directional XAU stream. That does not prove low factor or
portfolio correlation; unchanged Q09 alone owns realized overlap.

Q02 retires on zero packages, fewer than five completed packages in any full
post-warm-up year, nonpositive governed economics, or any clock, label,
endpoint, synchronization, sample, mean, variance, standard-error, score,
side, attempt, atomicity, fixed-risk, stop, spread, lifecycle, or determinism
defect. No sample, threshold, statistic, side, stop, hold, spread, or gate may
change after results to rescue the lineage.

## Authorized Scope

This approval permits only:

- deterministic magic allocation for exact slots 0 and 1;
- one branch-only V5 EA build;
- one exact D1 logical-basket `RISK_FIXED` backtest setfile and manifest;
- strict compile and Q01 validation; and
- one paced logical-basket Q02 enqueue if active factory CPU remains below the
  hard ceiling.

It does not permit a manual backtest, component-leg Q02 rows, terminal
control, live/demo/shadow/stress/optimization setfiles, `T_Live`, AutoTrading,
deploy or live manifests, portfolio-gate mutation, portfolio admission, or a
correlation waiver.

## Card Binding

The approved card SHA-256 at decision time is
`0E3F7D4A928858AC50798FE2027087483872C18EB8F1DBCCA02C04C2645EF7D1`.
Any mechanical change requires a new governed successor decision; later
editorial pipeline evidence must not alter the execution contract.
