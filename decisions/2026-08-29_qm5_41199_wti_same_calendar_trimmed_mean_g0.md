# QM5_41199 WTI Five-Year Same-Calendar Trimmed-Mean Seasonality - G0 Decision

Date: 2026-08-29

Decision: `APPROVED` for the exact Strategy Card
`strategy-seeds/cards/approved/QM5_41199_wti-samecal-trim5_card.md` and only
the non-live build/Q01/Q02 scope stated there.

Authority: current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`.

## Identity

- EA ID: `QM5_41199`
- slug: `wti-samecal-trim5`
- strategy ID: `KELOHARJU-TRIM-WTI-SAMECAL5-2026_S01`
- source ID: `KELOHARJU-TRIM-WTI-SAMECAL5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- intended magic: `411990000`

The atomic allocator reserved row `41199` in
`framework/registry/ea_id_registry.csv`; slug, strategy ID, and card identity
match exactly.

## Source And Claim Boundary

The bounded source packet is
`strategy-seeds/sources/KELOHARJU-TRIM-WTI-SAMECAL5-2026/source.md`, SHA-256
`A63BA6D42D534EAFECAE8E39C879EE5D41E1938791944525076E680FF05543C8`.
Its durable approval is
`decisions/2026-08-29_wti_same_calendar_trimmed_mean_source_approval.md`,
committed before extraction as `6c4c38322`.

R1 is `PASS_WITH_FIXED_SAMPLE_AND_TRIM_TRANSLATION_RISK`. Complete
peer-reviewed *Journal of Finance* evidence supplies the same-calendar-month
commodity information object, explicit crude-oil membership, and a five-year
history floor. A complete governed peer-reviewed WTI packet supplies fixed
sort/delete/retain/average arithmetic. Neither source tests this exact
five-return trimmed state, standalone continuous CFD, or QM book. No
performance, density, cost, CFD-equivalence, or decorrelation result
transfers.

## Mechanical Decision

R2 is `PASS`. On the first executable tick after each genuine broker-month
transition, the card:

1. consumes the month before every fallible entry gate;
2. reconstructs the completed WTI return for the upcoming calendar month in
   each exact year `Y-1..Y-5` under one uniform D1-label convention;
3. proves the final in-month endpoint with immediately adjacent prior- and
   next-month bars and rejects any missing exact year;
4. sorts all five returns, deletes exactly the minimum and maximum, and
   averages exactly the middle three;
5. follows the strict trimmed-mean sign and consumes the tie band flat; and
6. closes at the next month or after 35 days, with malformed exposure repaired
   immediately.

One `RISK_FIXED=1000` budget is sized against a frozen
`3.5*ATR(20,D1)` hard stop. Both news axes, legacy news mode, and Friday close
are OFF. There is no parameter sweep or result-dependent rescue.

## Data And Determinism

R3 is `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
`XTIUSD.DWX` D1 history, broker time, quotes, contract metadata, positions,
deals, and terminal-persistent attempt state supply every runtime field. Q02
must prove usable exact-year history, density, fills, and economics.

R4 is `PASS`. The signal uses only timestamps, logarithms, sorting, finite
arithmetic, comparisons, and native execution state. It contains no trained
output, banned signal indicator, external runtime feed, grid, martingale,
scale-in, pyramid, or adaptive PnL fit.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_samecal_trim5_preallocation_dedup_20260829.json`, SHA-256
`B21C3BDECE4F7A0A6DCA751095C43FC0B3480DA8DA59CB7629450EE6033AB794`,
found no exact identity across 4,698 registry rows, 1,344 cards, and all 45
Strategy Wiki nodes. Its only fuzzy result was the expected same-calendar WTI
mean neighbor `QM5_20099`.

Manual review establishes functional non-equivalence:

- on `[-.30,-.04,-.03,.08,.09]`, this card buys from the middle-three mean
  `+.003333...`, while the complete mean, ordinary median, and centered
  signed-rank rules all sell;
- on `[-.30,-.04,.01,.02,.03]`, this card sells while the positive-hit and
  median states are favorable;
- `QM5_20270` trims twelve contiguous recent WTI returns and retains eight,
  while this card trims five disjoint same-calendar returns and retains
  three; and
- fixed-month WTI systems and certified XNG pullback `QM5_12567` own different
  information objects, carriers, and clocks.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_MIDDLE_THREE_TRIMMED_MEAN_SIGN_MONTHLY_RENEWAL`.

## Portfolio Intent And Falsification

Direct WTI adds crude-oil exposure absent from the certified directional
XAU/SP500/NDX/XNG book. This economic distinction does not prove low factor or
portfolio correlation; unchanged Q09 alone owns realized overlap.

Q02 retires on zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any label, endpoint,
exact-year, sample, sort, deletion, retained-sum, divisor, side, attempt,
risk, stop, lifecycle, or determinism defect. No carrier, year count, trim,
estimator, direction, stop, hold, spread, or gate may change after results to
rescue the lineage.

## Authorized Scope

This approval permits only:

- deterministic magic allocation for exact slot 0;
- one branch-only V5 EA build;
- one exact D1 `RISK_FIXED` backtest setfile;
- strict compile and Q01 validation; and
- one paced Q02 enqueue if the active factory remains below its CPU ceiling.

It does not permit a manual backtest, terminal control, live/demo/shadow/
stress/optimization setfiles, `T_Live`, AutoTrading, deploy or live manifests,
portfolio-gate mutation, portfolio admission, or a correlation waiver.
