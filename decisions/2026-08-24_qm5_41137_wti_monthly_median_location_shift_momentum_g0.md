# QM5_41137 WTI Two-Completed-Month Median-Location Shift Momentum - G0 Decision

Date: 2026-08-24

Decision: `APPROVED`

## Authority and scope

The OWNER commodity/energy portfolio instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency commodity
edge, specifically including a WTI trend or seasonality carrier. It requires
reputable-source criteria, `RISK_FIXED` backtest configuration, committed
non-duplicate work, and one paced Q02 enqueue. It excludes `T_Live`,
AutoTrading, portfolio-gate, and T_Live-manifest changes.

This decision approves
`strategy-seeds/cards/approved/QM5_41137_wti-mmedian-shift-mom_card.md` for one
branch-only non-live build, strict Q01 validation, and one paced non-live Q02
handoff if the factory CPU ceiling permits.

## Identity

- EA: `QM5_41137_wti-mmedian-shift-mom`
- strategy ID: `MOP-WTI-MMEDIAN-SHIFT-MOM-2026_S01`
- source ID: `MOP-WTI-MMEDIAN-SHIFT-MOM-2026`
- symbol/slot/magic: `XTIUSD.DWX` / 0 / `411370000`
- timeframe: D1
- decision clock: first executable bar of a new normalized broker month

The numeric identity is fixed for deterministic registry reservation. Build
work may start only after the EA identity and slot-zero magic survive the
governed registry/resolver allocation.

## Approved source boundary

Source intake was approved before extraction at commit `6ebf566fb` in
`decisions/2026-08-24_wti_monthly_median_location_shift_momentum_source_approval.md`.
The bounded source packet is
`strategy-seeds/sources/MOP-WTI-MMEDIAN-SHIFT-MOM-2026/source.md`, SHA-256
`A53AB707037B46005D8F9AA37810B0284CA1DEE2F6453C4D34C07D26B56EC090`,
committed at `3772df384`.

The parent is Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum,"
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. Its governed packet preserves a complete
23-page author-hosted published-PDF read, retrieval receipt, durable PDF hash,
and explicit WTI membership.

The paper supports own-price monthly continuation and a symmetric long/short
monthly carrier. It does not test two daily log-price distributions, ordinary
sample medians, strict continuation after their location shift, the Darwinex
continuous CFD, broker-month labels, fixed cash risk, ATR stop, spread
ceiling, restart ledger, or lifecycle. Those are disclosed QM translations.
No source efficacy or correlation result transfers.

## Locked rule

On the first executable D1 bar of a new normalized broker month:

1. Choose one uniform energy-label convention: raw broker date or a uniform
   `+1` day correction when the current D1 label is exactly one day behind
   broker date. Reject mixed, colliding, weekend-ending, or other offsets.
2. Persist the normalized decision `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order submission. Permit no retry.
3. Within 70 completed D1 bars, select every close in the immediately
   completed normalized calendar month and its consecutive parent month.
   Require exact adjacency, 17-23 unique sessions per month, strict chronology,
   positive finite closes, and no current-month observation.
4. Transform each close independently to its natural logarithm. Sort each
   monthly log-price sample independently ascending without rounding.
5. For an odd sample, select exact center index `n/2`. For an even sample,
   average exact indexes `n/2-1` and `n/2`. Reject invalid arithmetic.
6. Buy WTI when the newest median is strictly above the parent median; sell
   when strictly below; consume equality or any invalid state flat. No
   endpoint, daily return, range, or magnitude gates or scales the trade.
7. Open at most one slot-zero WTI position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no take-profit, and a 1,500-point spread
   ceiling.
8. Close on the first tick of a later normalized broker month. Forty calendar
   days is stale repair only. Flatten malformed, duplicate, wrong-symbol,
   wrong-magic, or stopless owned exposure immediately.

Both news axes and Friday close are OFF. No fitted model, oscillator, moving
average, external feed, adaptive threshold, target, trail, break-even move,
partial close, opposite-signal exit, scale-in, pyramid, grid, or martingale is
authorized.

## Reputable-source criteria

- R1 `PASS_WITH_MONTHLY_MEDIAN_LOCATION_TRANSLATION_RISK`: named-author,
  peer-reviewed JFE paper with DOI, complete-read evidence, durable PDF hash,
  and explicit WTI membership; exact two-sample median proxy disclosed as
  untested.
- R2 `PASS`: clock, label convention, adjacent months, observation bounds,
  log-price transform, independent sorts, odd/even medians, strict direction,
  attempt, risk, stop, spread, and lifecycle are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  WTI D1 history and MT5 state provide every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, arithmetic,
  comparison, ATR, and execution state only; no trained or prohibited signal,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The pre-allocation canonical checker returned `CLEAN` across 4,636 registry
identities, 1,304 cards, and 45 Strategy Wiki nodes. Evidence is
`artifacts/qm5_wti_mmedian_shift_mom_preallocation_dedup_20260824.json`.

Manual review separates one-month endpoint momentum, monthly high/low range
migration, the within-one-month daily-return median, the median of twelve
monthly returns, historical same-calendar seasonality, the contrarian two-leg
XAU/XAG median-shift basket, and certified XNG cumulative-RSI pullback. The
approved card uniquely compares independent ordinary daily log-price medians
from the two newest completed WTI months and follows the strict shift.

Verdict:
`CLEAN_WTI_TWO_COMPLETED_MONTH_DAILY_LOG_PRICE_MEDIAN_LOCATION_SHIFT_MOMENTUM`.

## Risk and kill boundary

Every valid strict median displacement can qualify, giving a pre-result
density prior near twelve decisions per year. Q02 must retire the candidate at
zero trades, below five completed positions in any full post-warm-up year,
with nonpositive governed economics, or on any label, month, sample, log-
price, sort, median, side, attempt, risk, lifecycle, or determinism defect.

Direct WTI exposure is economically different from the certified XAU,
SP500, NDX, and XNG book, but G0 does not assert realized independence. Q09
alone may accept or reject portfolio correlation. Do not change sample
membership, log transform, median formula, direction, carrier, stop, risk,
hold, or add endpoint agreement, range, weekday, event, seasonal, volatility,
external, or prior-result state to rescue failure.

## Safety boundary

Create one exact `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, or optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; and correlation waivers. If the paced factory CPU ceiling is binding
before enqueue, stop without starting, stopping, reserving, reaping, or
reprioritizing any terminal.
