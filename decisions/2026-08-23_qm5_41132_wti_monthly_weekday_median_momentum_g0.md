# QM5_41132 WTI Completed-Month Weekday-Balanced Median Momentum - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

## Authority and scope

The OWNER commodity/energy portfolio instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency commodity
edge, specifically including a WTI trend or seasonality carrier. It requires
reputable-source criteria, `RISK_FIXED` backtest configuration, committed
non-duplicate work, and one paced Q02 enqueue. It excludes `T_Live`,
AutoTrading, portfolio-gate, and T_Live-manifest changes.

This decision approves
`strategy-seeds/cards/approved/QM5_41132_wti-mweekday-med-mom_card.md` for one
branch-only non-live build, strict Q01 validation, and one paced non-live Q02
handoff if the factory CPU ceiling permits.

## Identity

- EA: `QM5_41132_wti-mweekday-med-mom`
- strategy ID: `MOP-MEEK-WTI-MWEEKDAY-MED-2026_S01`
- source ID: `MOP-MEEK-WTI-MWEEKDAY-MED-2026`
- symbol/slot/magic: `XTIUSD.DWX` / 0 / `411320000`
- timeframe: D1
- decision clock: first executable bar of a new normalized broker month

The numeric identity is fixed for deterministic registry reservation. Build
work may start only after the EA identity and slot-zero magic survive the
governed registry/resolver allocation.

## Approved source boundary

Source intake was approved before extraction at commit `1e3af965c` in
`decisions/2026-08-23_wti_monthly_weekday_median_momentum_source_approval.md`.
The bounded source packet is
`strategy-seeds/sources/MOP-MEEK-WTI-MWEEKDAY-MED-2026/source.md`, SHA-256
`B893049C0BA566F78412AE76DB1EE9E5E730119C3FBC53053DF705B7C0EDA57A`,
committed at `4f670d5c0`.

The complete governed parent records were read before approval:

- Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
  Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`; complete 23-page author-hosted published PDF
  receipt and durable PDF hash are preserved.
- Meek and Hoelscher (2023), "Day-of-the-week effect: Petroleum and petroleum
  products," *Cogent Economics & Finance* 11(1), DOI
  `10.1080/23322039.2023.2213876`; the governed record preserves a complete
  review of the 21-page open-access copy.

The first paper supports own-price monthly continuation and explicitly
includes WTI. The second supports ending-weekday heterogeneity in WTI returns.
Neither tests the exact median of weekday-bucket means. That statistic,
Darwinex continuous CFD carrier, broker-month labels, fixed cash risk, ATR
stop, spread ceiling, retry ledger, and lifecycle are disclosed QM
translations. No source efficacy or correlation result transfers.

## Locked rule

On the first executable D1 bar of a new normalized broker month:

1. Choose one uniform energy-label convention: raw broker date or a uniform
   `+1` day correction when the current D1 label is exactly one day behind
   broker date. Reject mixed, colliding, or other offsets.
2. Persist the normalized decision `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order submission. Permit no retry.
3. Within 45 completed D1 bars, select every bar in the immediately preceding
   normalized calendar month plus one adjacent older boundary close. Require
   17-23 month sessions, unique timestamps, strict chronology, positive
   finite closes, and no current-month observation.
4. Form exactly one chronological log return ending on every selected
   month session. Verify its sum equals the direct boundary-to-final log
   return within `1e-10`.
5. Assign each return to the normalized Monday-through-Friday label of its
   ending bar. Reject weekend labels. Require all five buckets and three
   through five observations in every bucket.
6. Compute the arithmetic mean return of each weekday bucket, sort the five
   finite means ascending without rounding, and select exact index two.
7. Buy WTI when that median is strictly positive; sell when strictly
   negative; consume equality or any invalid state flat. The raw month return
   is diagnostic only and neither value scales risk.
8. Open at most one slot-zero WTI position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no take-profit, and a 1,500-point spread
   ceiling.
9. Close on the first tick of a later normalized broker month. Forty calendar
   days is stale repair only. Flatten malformed, duplicate, wrong-symbol,
   wrong-magic, or stopless owned exposure immediately.

Both news axes and Friday close are OFF. No fitted model, oscillator, moving
average, external feed, adaptive threshold, target, trail, break-even move,
partial close, opposite-signal exit, scale-in, pyramid, grid, or martingale is
authorized.

## Reputable-source criteria

- R1 `PASS_WITH_WEEKDAY_BALANCING_TRANSLATION_RISK`: two named-author,
  peer-reviewed papers with DOIs and complete-read evidence; explicit WTI
  membership and weekday heterogeneity; exact median rule disclosed as
  untested.
- R2 `PASS`: clock, label convention, month, boundary, observation bounds,
  returns, endpoint identity, weekdays, bucket counts, means, sort, median,
  direction, attempt, risk, stop, spread, and lifecycle are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  WTI D1 history and MT5 state provide every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, arithmetic, sorting,
  comparison, ATR, and execution state only; no trained or prohibited signal,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The pre-allocation canonical checker returned `CLEAN` across 4,631 registry
identities, 1,299 cards, and 45 Strategy Wiki nodes. Evidence is
`artifacts/qm5_wti_mweekday_med_mom_preallocation_dedup_20260823.json`.

Manual review separates the nearest families:

- `QM5_20187` follows the unpartitioned one-month endpoint.
- `QM5_41111` counts individual daily signs and gates on endpoint agreement.
- `QM5_41115` votes across three consecutive month blocks.
- `QM5_41131` trims individual return extremes before summing.
- `QM5_20269` takes a median across twelve monthly returns.
- `QM5_41055` takes a ten-year same-calendar-month median.
- fixed weekday WTI EAs trade one calendar session rather than balancing all
  five prior-month weekdays.
- certified `QM5_12567` is a short-horizon long-only XNG cumulative-RSI
  pullback.

Verdict:
`CLEAN_WTI_COMPLETED_MONTH_WEEKDAY_BALANCED_MEDIAN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Risk and kill boundary

Every valid nonzero median can qualify, giving a pre-result density prior near
twelve decisions per year. Q02 must retire the candidate at zero trades,
below five completed positions in any full post-warm-up year, with nonpositive
governed economics, or on any label, month, return, partition, bucket count,
mean, median, side, attempt, risk, lifecycle, or determinism defect.

Direct WTI exposure is economically different from the certified XAU,
SP500, NDX, and XNG book, but G0 does not assert realized independence. Q09
alone may accept or reject portfolio correlation. Do not change bucket
membership, weighting, aggregation, direction, carrier, stop, risk, hold, or
add endpoint agreement, event, seasonal, volatility, external, or
prior-result state to rescue failure.

## Safety boundary

Create one exact `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, or optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; and correlation waivers. If the paced factory CPU ceiling is binding
before enqueue, stop without starting, stopping, reserving, reaping, or
reprioritizing any terminal.
