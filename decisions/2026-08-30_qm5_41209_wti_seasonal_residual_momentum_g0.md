# QM5_41209 WTI Monthly Seasonal-Residual Momentum - G0 Decision

Date: 2026-08-30

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41209_wti-seas-resid-mom_card.md` and only
the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`.

## Identity

- EA ID: `QM5_41209`
- slug: `wti-seas-resid-mom`
- strategy ID: `KELOHARJU-MOP-WTI-SEASRESMOM-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SEASRESMOM-2026`
- host / traded slot 0: exact `XTIUSD.DWX`, D1
- intended magic: `412090000`

The atomic `farmctl reserve-ea-ids` allocator reserved row `41209` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded packet is
`strategy-seeds/sources/KELOHARJU-MOP-WTI-SEASRESMOM-2026/source.md`, SHA-256
`A8D8FACC8E80381E7E0288C366CABF68432C8A1B9B2F6F053ECD1ED108FCD62F`.
Its durable source approval is
`decisions/2026-08-30_wti_seasonal_residual_momentum_source_approval.md`,
committed before extraction as `a19955cc0`; the complete bounded extraction
was committed as `d5a6cc40c` before this card decision.

R1 is `PASS_WITH_CROSS_SOURCE_CONJUNCTION_AND_CFD_RISK`. Complete-read,
peer-reviewed lineages supply recurring same-calendar commodity returns with
explicit crude-oil membership and own-return continuation with explicit WTI
membership plus a pooled one-month formation / one-month hold test. The exact
standardized residual conjunction remains an untested QM hypothesis. No
performance, density, cost, CFD-equivalence, or decorrelation result transfers.

## Mechanical Decision

R2 is `PASS`. At the first genuine normalized broker-month D1 boundary, the
card:

1. repairs malformed exposure, closes a surviving prior-month position, and
   consumes the new month before every fallible entry gate;
2. reconstructs the just-completed WTI monthly log return from completed D1
   endpoints only under one uniform native or `+1` energy-label convention;
3. loads that same calendar month in up to ten earlier years, excludes the
   realized observation, and requires at least five historical returns;
4. computes the arithmetic mean and sample standard deviation with denominator
   `n-1` and rejects nonpositive scale;
5. follows only `residual_z > +0.50+1e-10` or
   `residual_z < -0.50-1e-10`, consuming every other state flat;
6. places one `RISK_FIXED=1000` WTI position with a frozen
   `3.5*ATR(20,D1)` hard stop and no target; and
7. closes on the next genuine broker-month boundary or after 40 days.

Both news axes, legacy news, and Friday close are OFF. Nonnegative modeled
`.DWX` spread is admitted only through 1,500 points; positive finite Bid/Ask
and non-crossed quotes remain mandatory. There is no parameter sweep, current-
month signal, raw-return or seasonal-direction fallback, contrarian sign flip,
Huber/median/MAD estimator, magnitude sizing, target, trail, partial exit,
scale-in, grid, martingale, or pyramid.

## Data And Determinism

R3 is `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`. Registered WTI D1
history, broker time, quotes, symbol metadata, positions, deals, and terminal-
global attempt state provide every runtime field. Q02 must prove usable
history, label mapping, density, fills, costs, and continuous-CFD behavior.

R4 is `PASS`. The signal uses dates, completed prices, logarithms, ordinary
sums/products, square root, and comparisons; ATR is bounded risk plumbing. No
trained output, banned signal indicator, external runtime feed, adaptive PnL
fit, scale-in, grid, martingale, or pyramid exists.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_seas_resid_mom_preallocation_dedup_20260830.json`, SHA-256
`4944501D083E5940724AC28851921943086D8092DD0FAE63390E049894823FBE`,
returned `CLEAN` across 4,708 registry identities, 1,354 card files, and 45
Strategy Wiki nodes.

Manual family review separates the executable identity:

- `QM5_20187` follows every nonzero raw completed-month WTI return;
- `QM5_20099` forecasts the upcoming same-calendar WTI sign;
- `QM5_20205` trades only agreement between that upcoming sign and the raw
  prior-month sign;
- `QM5_20229` uses a fixed physical-season map after an opposing raw month;
- `QM5_41208` fades an analogous residual on XNG rather than following WTI;
  and
- `QM5_21517` fades a paired XAU/XAG relative residual with two legs.

Verdict:
`CLEAN_WTI_STANDARDIZED_SEASONAL_RESIDUAL_MOMENTUM_AFTER_CANONICAL_AND_MANUAL_REVIEW`.

## Portfolio Intent And Falsification

This is a month-scale, seasonally adjusted WTI residual-momentum stream, not
another index, precious-metal, or incumbent XNG strategy. That mechanical and
carrier difference does not prove low factor or portfolio correlation;
unchanged Q09 alone owns realized overlap.

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
- one paced `XTIUSD.DWX` Q02 enqueue if active factory CPU remains below the
  hard ceiling.

It does not permit a manual backtest, terminal control, live/demo/shadow/
stress/optimization setfile, `T_Live`, AutoTrading, deploy or live manifest,
portfolio-gate mutation, portfolio admission, or a correlation waiver.

## Card Binding

The approved card SHA-256 at decision time is
`BA3D54531F7133D2DA852D54BBA047AAA83AAED20E6507041FC7F2C389755D28`.
Any mechanical change requires a new governed successor decision; later
editorial pipeline evidence must not alter the execution contract.
