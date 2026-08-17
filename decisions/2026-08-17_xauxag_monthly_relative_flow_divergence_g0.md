# G0 Decision - QM5_41039 XAU/XAG Monthly Relative-Flow Divergence

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_xauxag_monthly_relative_flow_divergence_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41039_xauxag-mflow-div_card.md`.

## Identity

- EA ID: `QM5_41039`, allocated by the canonical atomic registry command
- slug: `xauxag-mflow-div`
- strategy ID: `WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026_S01`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, slots 0 and 1
- mechanic: at the first genuine synchronized D1 boundary of a new broker
  month, decompose every completed prior-month interval for both metals into
  close-to-open and open-to-close log flow; subtract silver from gold; require
  strict relative-component opposition; follow the session-relative sign with
  an equal-notional opposite-leg package; hold until the next broker month

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: the card cites a complete
  OWNER-supplied Tier-A Williams extraction for the two information-time
  components, a peer-reviewed gold/silver relationship lineage, a
  complete-read peer-reviewed commodity monthly-hold lineage, and governed
  CME carrier evidence. No source validates their conjunction and no
  performance claim transfers.
- R2 `PASS`: exact month identity, cross-symbol synchronization, all completed
  endpoints, relative subtraction, strict opposition, session-following
  sides, three reconciliation checks, attempt persistence, entry grace,
  aggregate fixed risk, equal-notional sizing, hard stops, spread ceilings,
  paired month rollover, and stale repair are mechanical.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC, quotes, broker calendar, positions, deal history, and
  terminal state are sufficient. Q02 must use one synchronized logical-basket
  window.
- R4 `PASS`: the signal is closed-form timestamp, calendar, and log-return
  arithmetic. No trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid is present.

## Duplicate Review

The canonical checker reported no exact duplicate and one fuzzy family
neighbor. The approved execution identity remains distinct:

- unlike `QM5_41030_xauxag-flowdiv`, it uses every session of one completed
  broker month and a next-month renewal, not an exact Monday-Friday week and
  Friday flattening;
- unlike `QM5_41037_xng-mflow-div`, it is a synchronized two-metal relative
  basket rather than a directional XNG position;
- unlike one-, three-, and twelve-month XAU/XAG cross-sectional momentum, it
  admits only opposed close/open information-time components and follows
  session-relative flow, which may differ from the total relative-return sign;
- unlike ratio/residual families, it estimates no ratio level, center, scale,
  regression, quantile, or stationarity state;
- unlike `QM5_41031_xauxag-goldlead`, it uses every prior-month interval and a
  one-month hold rather than one gold-led daily shock and one-session catch-up;
  and
- unlike `QM5_12567_cum-rsi2-commodity`, it is a symmetric logical basket with
  no oscillator entry.

Verdict:
`CLEAN_XAUXAG_MONTHLY_RELATIVE_FLOW_DIVERGENCE_AFTER_CADENCE_CARRIER_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XAUUSD.DWX` D1 host slot 0 and `XAGUSD.DWX` D1 companion slot 1;
- exact cross-symbol timestamps with no label shifting or per-bar repair;
- first-new-month decision within 180 minutes and one durable `yyyymm`
  attempt persisted before every fallible entry gate;
- 15-25 synchronized completed immediately prior-month sessions plus one
  preceding month-end anchor;
- gold-minus-silver overnight and session log-flow components, strict
  opposition, and `1e-10` per-metal and relative telescoping reconciliation;
- positive session-relative flow maps to BUY XAU/SELL XAG and negative
  session-relative flow maps to SELL XAU/BUY XAG;
- one aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
  budget in the sole backtest setfile;
- equal absolute USD notional after rounding, at most 20% mismatch, frozen
  `3.5 * ATR(20,D1)` per-leg hard stops, no target, and 1,500-point per-leg
  spread ceilings;
- framework Friday close disabled, paired next-month rollover exit, and
  40-day stale repair; and
- deterministic reference tests, strict compile, basket/set/registry checks,
  and static Q01 validation before any Q02 handoff.

No ratio/residual state, magnitude threshold, season, weekday, volatility
signal gate, moving line, crossover, external runtime input, retry, scale-in,
grid, martingale, pyramid, optimization surface, or after-result rescue is
approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical
`RISK_FIXED` backtest setfile, strict Q01, and one paced target-only Q02
enqueue if the exact-path capacity check is below the governed tester ceiling.
It does not authorize a manual tester dispatch or any tester control.

Expected cadence is approximately five to eight completed packages per full
post-warm-up year. Q02 must retire the identity on zero trades, fewer than five
per year, nonpositive governed economics, wrong endpoints/month identity,
component agreement entry, wrong sides, failed reconciliation, current-bar
leakage, late/repeated entry, invalid risk mode, excess notional mismatch,
orphan survival, wrong lifecycle, or nondeterminism. Q09 alone may establish
realized decorrelation from the certified XAU/SP500/NDX/XNG book; no
correlation waiver is permitted.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, neutrality claims, and correlation waivers.
