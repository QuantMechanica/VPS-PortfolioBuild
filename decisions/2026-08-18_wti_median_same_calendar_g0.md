# G0 Decision - QM5_41055 WTI Median Same-Calendar Seasonality

Date: 2026-08-18

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-18_wti_median_same_calendar_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41055_wti-medcal_card.md`.

## Identity

- EA ID: `QM5_41055`, allocated by the deterministic registry at commit
  `084ebfac5`
- slug: `wti-medcal`
- strategy ID: `KELOHARJU-WTI-MEDCAL-2026_S01`
- source approval commit: `5c51e1248`
- magic allocation commit: `25c55d920`
- carrier: exact `XTIUSD.DWX`, D1, slot 0, registered magic `410550000`
- mechanic: on the first D1 bar of a genuine broker month, compute the sample
  median of five to ten exact prior-year returns for that same calendar month,
  trade its absolute sign, and renew at the next broker-month boundary

## Gate Findings

- R1 `PASS_WITH_TRANSLATION_RISK`: named-author, peer-reviewed *Journal of
  Finance* lineage with DOI, a complete-read record, crude oil inside the
  stated futures universe, and the source's five-year history rule. The median
  and standalone CFD reduction are explicit untested QM translations.
- R2 `PASS`: historical month endpoints, years, sample bounds, even/odd median
  convention, sign tolerance, consumed attempt, fixed risk, hard stop, spread
  cap, and monthly lifecycle are mechanical.
- R3 `PASS_WITH_HISTORY_AND_SESSION_LABEL_RISK`: registered native
  `XTIUSD.DWX` D1 OHLC, timestamps, quotes, broker calendar, positions, deal
  history, and terminal state supply every runtime input. Local history starts
  in 2017, making the five-year sample floor binding; native versus prior-day
  energy labels must also normalize uniformly.
- R4 `PASS`: deterministic timestamp, calendar, sorting, logarithm, and
  execution arithmetic only; no trained output, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, hedge, or pyramid.

## Duplicate Review

The canonical pre-allocation checker scanned 4,542 registry rows and 625 card
files and returned `CLEAN`. Manual review confirms:

- `QM5_20099` uses the full-sample arithmetic mean; this candidate uses the
  bounded sample median, and a single extreme year can therefore produce a
  different sign;
- `QM5_20136`, `QM5_20205`, `QM5_20251`, and `QM5_20137` retain the mean and
  add state conjunctions absent here;
- `QM5_13115` and `QM5_20190` require synchronized paired-energy ranks rather
  than one absolute-sign WTI position;
- fixed favorable-month systems do not recompute a prior-year order
  statistic; and
- `QM5_12567` is a daily long-only cumulative-RSI pullback.

Verdict:
`CLEAN_WTI_PRIOR_TEN_YEAR_SAME_CALENDAR_RETURN_MEDIAN_SIGN_MONTHLY_RENEWAL_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 and registered magic `410550000`;
- native same-day or one uniform `+1` calendar-day energy-label normalization,
  with normalized current D1 date equal to broker date;
- first genuine broker-month D1 boundary and one durable `yyyymm` attempt
  persisted before every fallible entry gate;
- exact same-calendar historical years `Y-1` through `Y-10`, with each return
  using the immediately prior D1 close and final in-month D1 close, both
  bounded by adjacent calendar-month identity checks;
- five to ten valid observations, odd/even sample median, and no replacement
  year, full-sample mean, weighting, winsorization, or fallback;
- median above `+1e-12` maps to BUY, below `-1e-12` maps to SELL, and the tie
  band consumes the month flat;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
  ceiling;
- both news axes OFF, framework Friday close OFF, next-month renewal, and a
  35-day stale guard; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-month price or volume, arithmetic-mean fallback, month selection,
recent-trend or prior-return conjunction, inventory, event, curve, volume,
volatility signal, oscillator, external runtime input, retry, scale-in, grid,
martingale, hedge, pyramid, optimization surface, or after-result rescue is
approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if the exact-
path tester count and host CPU are below the governed ceilings. It does not
authorize a manual tester dispatch or tester control.

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong or partial endpoints, current-month
leakage, invalid sample count, wrong median or sign, mean fallback,
late/repeated entry, wrong monthly lifecycle, nondeterminism, invalid risk
mode, or insufficient history. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
