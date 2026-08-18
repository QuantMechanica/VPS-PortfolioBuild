# G0 Decision - QM5_41059 WTI Same-Calendar Hit-Rate Seasonality

Date: 2026-08-18

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-18_wti_same_calendar_hit_rate_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41059_wti-samecal-hit_card.md`.

## Identity

- EA ID: `QM5_41059`, allocated deterministically at commit `36a5d38ba`
- slug: `wti-samecal-hit`
- strategy ID: `KELOHARJU-PAPAILIAS-WTI-SAMECALHIT-2026_S01`
- source approval commit: `cd8ab88a1`
- magic allocation commit: `4c1f158e8`
- carrier: exact `XTIUSD.DWX`, D1, slot 0, magic `410590000`
- mechanic: strict majority of five to ten binary return signs from prior
  occurrences of the same named calendar month, renewed monthly

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: two named-author peer-reviewed
  finance sources with DOI, complete-read records, explicit WTI membership,
  and the matching-month/sign-frequency conjunction disclosed as untested.
- R2 `PASS`: historical month endpoints, years, sample bounds, binary map,
  equal weighting, strict-majority boundary, consumed attempt, fixed risk,
  hard stop, spread cap, and monthly lifecycle are mechanical.
- R3 `PASS_WITH_HISTORY_AND_SESSION_LABEL_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state supply every runtime input. The 2017
  history start makes the five-year floor binding, and energy D1 labels must
  normalize uniformly.
- R4 `PASS`: deterministic timestamp, calendar, logarithm, binary count, and
  execution arithmetic only; no trained output, banned signal, external
  runtime feed, grid, martingale, scale-in, hedge, or pyramid.

## Duplicate Review

The canonical checker scanned 4,546 registry rows and 625 cards and returned
`CLEAN`. Manual review distinguishes the arithmetic same-calendar mean in
`QM5_20099`, ordered-magnitude median in `QM5_41055`, recent twelve-month sign
state in `QM5_13150`, same-calendar/recent-sign conjunction in `QM5_20251`,
and fixed-month seasonal systems. None counts binary signs across prior
occurrences of the named month and trades their strict majority.

Verdict:
`CLEAN_WTI_SAME_CALENDAR_POSITIVE_RETURN_FREQUENCY_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 and magic `410590000`;
- native same-day or one uniform `+1` energy-label normalization;
- genuine first broker-month D1 boundary and one durable `yyyymm` attempt
  persisted before every fallible entry gate;
- exact matching-month returns for years `Y-1` through `Y-10`, requiring five
  to ten valid completed endpoint pairs and no replacement years;
- non-negative returns mapped to one, negative returns to zero, equal-weight
  positive frequency, BUY above `0.5`, SELL below, and exact tie flat;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` backtest set;
- one frozen `3.5 * ATR(20,D1)` hard stop, no target, and 1,500-point spread
  ceiling;
- both news axes OFF, Friday close OFF, next-month renewal, and 35-day stale
  guard; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-month price, return magnitude, mean/median fallback, month
selection, recent-trend conjunction, inventory, event, curve, volume,
volatility signal, oscillator, external runtime input, retry, scale-in, grid,
martingale, hedge, pyramid, optimization surface, or after-result rescue is
approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only if exact-path
tester count and host CPU are below governed ceilings. It does not authorize a
manual tester dispatch or terminal control.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong endpoints, current-
month leakage, wrong binary map or count, wrong majority, late/repeated entry,
wrong lifecycle, nondeterminism, invalid risk mode, or insufficient history.
Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
