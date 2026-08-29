# WTI First-Half-of-Month Short - Source Approval

Date: 2026-08-29

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its CPU ceiling.
Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG book, names direct WTI trend/seasonality as an acceptable
missing exposure, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-h1m-short`
- proposed strategy ID: `BOROWSKI-WTI-H1M-2026_S01`
- proposed source ID: `BOROWSKI-WTI-H1M-2026`
- carrier / host: exact `XTIUSD.DWX`, D1, slot 0
- clock: first genuine broker-month D1 boundary
- side: short the first-half window
- lifecycle: close at the first subsequent normalized D1 bar dated 16 or
  later; 20 elapsed calendar days is repair only

The governed allocator owns the EA ID. This source decision neither predicts
nor reserves an ID.

## Approved Source Basis And Claim Boundary

The bounded packet
`strategy-seeds/sources/BOROWSKI-WTI-H2M-2016/source.md`, SHA-256
`F2B5D2DED4DA0D3EED799DE5B56F85A32A0A8305565B97B37604700C231524BC`,
was read completely. Its reproducible read receipt is
`artifacts/qm5_wti_h1m_short_source_provenance_20260829.json`.

It preserves a complete review of Borowski (2016), *Journal of Management and
Financial Sciences*, issue 26, 27-44, especially Section 4.4 and Table 2. The
paper reports a `-0.0148%` average NYMEX crude-oil daily return for calendar
days 1-15 and `-0.0824%` for days 16 through month end over 1983-03-30 to
2016-03-31. The half-to-half difference is not significant (`p=0.5271`).

This approval uses only the reported first-half sign and calendar partition.
The first-session entry, late-attach rule, exact CFD host, fixed cash risk,
ATR stop, spread cap, attempt ledger, and exit repair are transparent QM
translations. No source performance, significance, cost, drawdown, density,
futures/CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-calendar
month transition:

1. Process malformed or stale owned exposure and persist the current broker
   `yyyymm` before history, news, spread, quote, ATR, sizing, margin, or order
   gates. A flat, rejected, failed, stopped, Friday-closed, or restarted
   outcome may not retry in the same month.
2. Require the normalized current D1 day to be no later than 5. A late attach
   consumes the month flat. The first available session need not be calendar
   day 1 after a weekend or market closure.
3. SELL at most one WTI position under `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, sized against one frozen
   `2.75*ATR(20,D1)` broker hard stop. Attach no target and reject a genuinely
   positive spread above 2,500 points.
4. Close on the first observed normalized D1 bar whose broker day is 16 or
   later. A 20-calendar-day close repairs only an exposure that survived the
   ordinary boundary.
5. Immediately flatten duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, invalid-open-time, or stopless owned exposure.

Both news axes and the legacy news mode are OFF. Framework Friday close is ON
at broker hour 21; a Friday close never resets the monthly attempt. There is
no price-direction signal, trend, moving-average entry, oscillator, inventory,
event, curve, volume, optimizer artifact, or external runtime series.

## Reputable-Source Criteria

- R1 `PASS_WITH_NONSIGNIFICANCE_AND_CFD_TRANSLATION_RISK`: complete-read,
  named-author, peer-reviewed Tier-B evidence directly defines the WTI
  calendar partition and first-half negative sign. The weakness and
  non-significance are binding kill risks, not hidden.
- R2 `PASS`: exact host, boundary, late-entry ceiling, side, attempt, risk,
  stop, spread, exit, Friday close, and stale repair are deterministic.
- R3 `PASS_WITH_SESSION_AND_FUTURES_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide all runtime fields. Q02 owns
  broker-label, history, fill, density, and economics validation.
- R4 `PASS`: deterministic calendar arithmetic plus completed-bar ATR risk
  plumbing only; no trained output, banned signal indicator, external feed,
  grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,699 registry identities, 1,345 cards, and all
45 current Strategy Wiki nodes. It found no exact collision and returned only
source-family fuzzy matches. Receipt:
`artifacts/qm5_wti_h1m_short_preallocation_dedup_20260829.json`, SHA-256
`0B3DCBD710F229E0F2342D93E4F8205F2809D73F8C9A3451BB8529CE954314B4`.

Manual review establishes functional non-equivalence:

- `QM5_20021_wti-h2m-short` enters on an actual day-16 bar and owns the
  complementary second half until next month; this candidate owns only the
  first half and must exit before that interval.
- `QM5_20028_wti-dom1-long` is an opposite-side one-session date-1 trade;
  this candidate is short from the first genuine month session through the
  first session dated 16 or later.
- `QM5_20027_wti-dom26-short` owns only one session outside this candidate's
  holding interval.
- the other surfaced Borowski cards trade XNG or weekdays, not this WTI
  half-month interval.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_FIRST_GENUINE_MONTH_BOUNDARY_SHORT_TO_FIRST_DAY_GE_16`.

## Kill And Safety Boundary

Q02 must retire the unchanged candidate at zero trades, below five completed
positions in any full post-warm-up year, with nonpositive governed economics,
or on wrong boundary, late/duplicate entry, wrong side, retry, failure to exit
at the first session dated 16 or later, invalid risk mode, or nondeterminism.
No failed result may be rescued by moving the dates, changing the side, adding
a signal, or altering stop, risk, hold, spread, or retry rules.

Direct WTI adds crude-oil exposure absent from the stated certified book, but
this decision does not prove low factor or portfolio correlation. Unchanged
Q09 alone owns realized overlap. This approval excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
