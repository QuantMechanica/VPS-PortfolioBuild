# QM5_41208 XNG Monthly Seasonal-Surprise Reversion - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41208_xng-seas-surprise-rv_card.md` and only
the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41208`
- slug: `xng-seas-surprise-rv`
- strategy ID: `KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026_S01`
- source ID: `KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026`
- host / traded slot 0: exact `XNGUSD.DWX`, D1
- intended magic: `412080000`

The atomic `farmctl reserve-ea-ids` allocator reserved row `41208` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded packet is
`strategy-seeds/sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026/source.md`,
SHA-256
`DAA4C8C70FCFB330F157AC4AC0CBAA3AD13FDC765D184AFFD80F88C588CF09BC`.
Its durable source approval is
`decisions/2026-08-30_xng_seasonal_surprise_reversion_source_approval.md`,
committed before extraction as `c69176b43`; the complete bounded extraction
was committed as `a6cb76267` before this card decision.

R1 is `PASS_WITH_CROSS_SOURCE_CONJUNCTION_AND_CFD_RISK`. The complete-read
peer-reviewed lineages supply recurring same-calendar commodity returns with
explicit natural-gas membership and direct natural-gas fixed-frequency
contrarian evidence. The exact standardized conjunction remains an untested
QM hypothesis, and Mishra-Smyth's sample-specific warning remains binding. No
performance, density, cost, CFD-equivalence, or decorrelation result transfers.

## Mechanical Decision

R2 is `PASS`. At the first genuine normalized broker-month D1 boundary, the
card:

1. repairs malformed exposure, closes a surviving prior-month position, and
   consumes the new month before every fallible entry gate;
2. reconstructs the just-completed XNG monthly log return from completed D1
   endpoints only under one uniform native or `+1` energy-label convention;
3. loads that same calendar month in up to ten earlier years, excludes the
   realized observation, and requires at least five historical returns;
4. computes the arithmetic mean and sample standard deviation with denominator
   `n-1` and rejects nonpositive scale;
5. fades only `surprise_z > +0.50+1e-10` or
   `surprise_z < -0.50-1e-10`, consuming every other state flat;
6. places one `RISK_FIXED=1000` XNG position with a frozen
   `3.5*ATR(20,D1)` hard stop and no target; and
7. closes on the next genuine broker-month boundary or after 40 days.

Both news axes, legacy news, and Friday close are OFF. Nonnegative modeled
`.DWX` spread is admitted only through 3,000 points; positive finite Bid/Ask
and non-crossed quotes remain mandatory. There is no parameter sweep, current-
month signal, unconditional fallback, Huber/median/MAD estimator, magnitude
sizing, target, trail, partial exit, scale-in, grid, martingale, or pyramid.

## Data And Determinism

R3 is `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`. Registered XNG D1
history, broker time, quotes, symbol metadata, positions, deals, and terminal-
global attempt state provide every runtime field. Q02 must prove usable
history, label mapping, density, fills, costs, and continuous-CFD behavior.

R4 is `PASS`. The signal uses dates, completed prices, logarithms, ordinary
sums/products, square root, and comparisons; ATR is bounded risk plumbing. No
trained output, banned signal indicator, external runtime feed, adaptive PnL
fit, scale-in, grid, martingale, or pyramid exists.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xng_seassurprise_rv_preallocation_dedup_20260830.json`, SHA-256
`368080A3C487F6FE8655177D94C8AB6D61D0BC165FAD25B1BEDD7B945EDB121C`,
returned `CLEAN` across 4,707 registry identities, 1,353 card files, and 45
Strategy Wiki nodes.

Manual family review separates the executable identity:

- `QM5_12567` is a two-day RSI pullback under a slow trend, long only, with a
  five-bar hold;
- `QM5_20054` fades every completed-month sign without seasonal expectation,
  scaling, or a flat band;
- `QM5_20100` and `QM5_41205` forecast the upcoming month from historical
  same-calendar mean/Huber location and follow that sign; and
- `QM5_21517` computes a paired XAU-minus-XAG surprise and opens two metals
  legs, never a direct XNG position.

Verdict:
`CLEAN_XNG_STANDARDIZED_SEASONAL_SURPRISE_REVERSION_AFTER_CANONICAL_AND_MANUAL_REVIEW`.

## Portfolio Intent And Falsification

This is a month-scale, seasonally adjusted natural-gas surprise-reversal
stream, not another index or metal strategy and not the incumbent short-
horizon XNG pullback. That mechanical difference does not prove low factor or
portfolio correlation; unchanged Q09 alone owns realized overlap.

Q02 retires on zero positions, fewer than five completed positions in any
full post-warm-up year, nonpositive governed economics, or any clock, label,
endpoint, exclusion, sample, mean, scale, score, side, attempt, fixed-risk,
stop, spread, lifecycle, or determinism defect. No history, threshold,
statistic, side, stop, hold, spread, or gate may change after results to rescue
the lineage.

## Authorized Scope

This approval permits only:

- deterministic magic allocation for exact slot 0;
- one branch-only V5 EA build;
- one exact D1 `RISK_FIXED` backtest setfile;
- strict compile and Q01 validation; and
- one paced `XNGUSD.DWX` Q02 enqueue if active factory CPU remains below the
  hard ceiling.

It does not permit a manual backtest, terminal control, live/demo/shadow/
stress/optimization setfile, `T_Live`, AutoTrading, deploy or live manifest,
portfolio-gate mutation, portfolio admission, or a correlation waiver.

## Card Binding

The approved card SHA-256 at decision time is
`80C7AF151BF3398DB92ED2FF7F8395BC0AEDFDE536ED539F3654522C5B9AC574`.
Any mechanical change requires a new governed successor decision; later
editorial pipeline evidence must not alter the execution contract.
