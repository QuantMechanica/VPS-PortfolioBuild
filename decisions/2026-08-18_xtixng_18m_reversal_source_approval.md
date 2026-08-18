# XTI/XNG 18-Month Cross-Sectional Reversal - Source Approval

Date: 2026-08-18

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if the tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requests one new structural,
low-frequency commodity or energy sleeve that adds genuinely different
exposure to the certified XAU/SP500/NDX/XNG book, requires reputable-source
criteria and `RISK_FIXED` backtests, and forbids live and portfolio-gate
mutation.

## Candidate Identity

- proposed slug: `energy-rev18`
- proposed strategy ID: `BIANCHI-MOMREV-2015_XTI_XNG_S04`
- proposed source ID: `BIANCHI-XTIXNG-REV18-2026`
- logical carrier: exact `XTIUSD.DWX` host plus exact `XNGUSD.DWX` companion,
  D1, one simultaneous long/short package on slots 0 and 1
- decision clock: first tradable XTI D1 bar of each genuine broker month
- state: synchronized completed 18-month log returns for XTI and XNG
- direction: buy the 18-month loser and short the 18-month winner
- lifecycle: renew at the next broker-month boundary and repair only a stale
  or orphaned survivor

The deterministic registry process owns the EA ID. This record neither
reserves nor predicts an ID.

## Approved Source Basis

The bounded source-of-record packet
`strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md` was read completely
before this decision. It records a complete review of the 59-page accepted
manuscript for Bianchi, Drew, and Fan (2015), "Combining Momentum with Reversal
in Commodity Futures," *Journal of Banking & Finance* 59, 423-444, DOI
`10.1016/j.jbankfin.2015.07.006`.

The source documents reversal of commodity momentum profits over months 12
through 30 after formation and uses an overlapping 18-month reversal rank in
its preferred `Mom12-Ctr18` double sort. WTI crude oil and natural gas are
explicit constituents of the source commodity universes.

The pure two-energy-leg reversal rule is an explicit QM falsification
translation. The paper does not test a two-contract energy-only rank, a pure
18-month portfolio without its 12-month first sort, Darwinex continuous CFDs,
equal stop-risk legs, ATR hard stops, a durable broker-month attempt ledger,
or this execution lifecycle. No source return, significance, density, cost,
drawdown, neutrality, correlation, or diversification result transfers.

## Locked Mechanic

On the first tradable `XTIUSD.DWX` D1 bar of each genuine broker month:

1. Close or repair any prior-month owned package before entry-only gates.
2. Persist the current `yyyymm` attempt before history, signal, news, spread,
   quote, ATR, sizing, or order gates; never retry that month.
3. Reconstruct synchronized completed month-end closes for XTI and XNG at the
   current boundary and exactly 18 completed broker months earlier. Every
   endpoint must precede the decision month and be no more than ten calendar
   days before its boundary.
4. Compute `r_xti = ln(xti_end / xti_start)` and
   `r_xng = ln(xng_end / xng_start)` from the synchronized boundaries.
5. If `r_xti < r_xng - 1e-12`, buy XTI and sell XNG. If
   `r_xti > r_xng + 1e-12`, sell XTI and buy XNG. Consume the month flat
   inside the inclusive tie band.
6. Split one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
   package equally across the two hard-stop risks. Signal magnitude never
   changes either leg's risk.
7. Freeze a `3.5 * ATR(20,D1)` broker hard stop independently on each leg,
   use no targets, cap XTI spread at 1,500 points and XNG spread at 3,000
   points, and compensate immediately if the second leg fails.
8. Close both legs at the first later broker-month boundary. A 35-calendar-
   day stale guard and immediate orphan repair are safety-only exits.
9. Disable framework Friday flatten so the source-aligned monthly package can
   span weekends. Never retry, scale in, pyramid, grid, martingale, or retain
   one leg intentionally.

The exact two-energy carrier, synchronized 18-month endpoints, pure reversal
rank, tie convention, equal fixed stop-risk, paired lifecycle, durable monthly
attempt, and no-12-month-signal rule are load-bearing. No momentum gate,
z-score, ratio level, weekday/event condition, inventory input, carry proxy,
or optimizer-selected filter is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_TRANSLATION_RISK`: named authors, peer-reviewed *Journal of
  Banking & Finance* publication, DOI, open accepted manuscript, and durable
  complete-read record. The pure two-energy carrier is disclosed as a narrow
  translation of the paper's 18-month reversal information object.
- R2 `PASS`: synchronized endpoints, fixed horizon, rank, tie, attempt, risk,
  stops, paired compensation, and monthly exits are deterministic.
- R3 `PASS_WITH_HISTORY_AND_BASKET_RISK`: registered `XTIUSD.DWX` and
  `XNGUSD.DWX` D1 history supplies every runtime field. Q01 must prove uniform
  energy session-label normalization, and Q02 must evaluate the logical
  basket rather than standalone legs.
- R4 `PASS`: timestamps, OHLC, logarithms, comparisons, ATR risk plumbing,
  quotes, positions, deal history, and terminal state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,543 EA-registry rows and 625
root-card files. It found no exact slug or strategy-ID duplicate. Its expected
source-family fuzzy hit requires and receives this manual resolution:

- `QM5_13120_energy-momrev` first ranks XTI/XNG on 12-month momentum and opens
  only when that rank contradicts the 18-month reversal rank. This candidate
  never reads a 12-month state and trades every valid non-tied 18-month rank.
- `QM5_20202_xauxag-rev18` isolates the same source information object on the
  XAU/XAG metal carrier. This candidate uses the distinct XTI/XNG energy
  carrier and its physical, basis, gap, spread, and correlation risks.
- `QM5_12733_xti-xng-xmom` follows the 126-D1 relative winner; this candidate
  uses a much longer completed-month horizon and takes the opposite side.
- `QM5_12840_xti-xng-rspread` fades a short-window return-spread z-score; this
  candidate uses no ratio, residual, mean, standard deviation, or thresholded
  spread level.
- `QM5_20110`, `QM5_20016`, `QM5_41014`, `QM5_41015`, and `QM5_41018` are
  weekday-relative-value packages, not an unconditional monthly 18-month
  reversal rank.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG oscillator
  pullback, not a paired long-horizon energy reversal package.

Verdict:
`CLEAN_XTI_XNG_PURE_SYNCHRONIZED_18_MONTH_REVERSAL_MONTHLY_BASKET_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately eleven to twelve completed packages per
full post-warm-up year. Q02 retires on zero trades, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
stale endpoints, current-month leakage, a 12-month or spread-level gate,
wrong reversal direction, late or repeated entry, orphan persistence,
nondeterminism, invalid fixed-risk mode, or unusable synchronized history. A
weak result may not be rescued by changing horizon, direction, carrier,
adding momentum, seasonality, inventory, event, carry, volatility, or
price-action filters, or optimizing the tie threshold.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; neutrality claims; and correlation waivers. Q02 may be
enqueued once only if the exact-path tester count and host CPU are below the
governed ceilings. At the ceiling, stop before queue mutation and record a
non-live handoff.

