# G0 Decision - QM5_41038 XNG Monthly Opposed-Flow Dominance

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_xng_monthly_opposed_flow_dominance_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41038_xng-mflow-dom_card.md`.

## Identity

- EA ID: `QM5_41038`, allocated by the deterministic registry command
- slug: `xng-mflow-dom`
- strategy ID: `WILLIAMS-MOP-XNG-MFLOWDOM-2026_S01`
- carrier: exact `XNGUSD.DWX`, D1, symbol slot 0
- mechanic: at the first genuine D1 boundary of a new broker month, decompose
  every completed prior-month interval into close-to-open and open-to-close
  log flow; require strict component opposition; follow the sign of the larger
  absolute component; hold until the next broker month

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: the card cites a complete
  OWNER-supplied Tier-A Williams extraction for public/professional flow and a
  complete-read peer-reviewed JFE paper for XNG carrier and monthly-hold
  lineage. Neither source validates the conjunction; the card transfers no
  performance claim.
- R2 `PASS`: exact month identity, normalized labels, all completed endpoints,
  strict opposition, absolute-dominance direction, return reconciliation,
  attempt persistence, entry grace, fixed risk, hard stop, spread ceiling,
  month rollover, and stale repair are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC,
  quotes, broker calendar, positions, deal history, and terminal state are
  sufficient. The route is exercised, while its session-offset registry row
  remains inferred from measured XTI pending an XNG-specific observation.
- R4 `PASS`: the signal is closed-form calendar and log-return arithmetic.
  No trained output, banned signal indicator, grid, martingale, scale-in, or
  pyramid is present.

## Duplicate Review

The canonical checker reported no exact duplicate and five fuzzy family
neighbors. The approved execution identity remains distinct:

- unlike `QM5_41036_wti-mflow-dom`, it trades the exact XNG carrier with its
  own magic, fills, risk, and evidence rather than WTI;
- unlike `QM5_41035_wti-mflow-div`, it follows the larger opposed component
  rather than always following session flow;
- unlike `QM5_41037_xng-mflow-div`, it takes the opposite side when overnight
  flow dominates and is flat on exact magnitude equality;
- unlike `QM5_20204_xng-tsmom1m`, it rejects every agreement month rather
  than trading every nonzero monthly total;
- unlike `QM5_20054_xng-1m-contr`, it follows rather than fades the dominant
  opposed component; and
- unlike `QM5_12567_cum-rsi2-commodity`, it is symmetric, monthly,
  information-clock structural, and has no oscillator entry.

Verdict:
`CLEAN_XNG_MONTHLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- one exact `XNGUSD.DWX` D1 host and position, magic slot 0;
- same-day or uniform `+1`-day D1 label normalization only;
- first-new-month decision within 180 minutes and one durable `yyyymm`
  attempt persisted before every fallible gate;
- 15-25 completed immediately prior-month sessions plus one preceding
  month-end anchor;
- strict opposite component signs and `1e-10` telescoping reconciliation;
- follow session-flow sign when its absolute magnitude is larger and follow
  overnight-flow sign when its absolute magnitude is larger; consume equal
  magnitude flat;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` in the sole
  backtest setfile;
- a frozen `3.5 * ATR(20,D1)` hard stop, no target, and 3,000-point spread
  ceiling;
- framework Friday close disabled, next-month rollover exit, and 40-day stale
  repair; and
- deterministic reference tests, strict compile, build checks, and static Q01
  validation before any Q02 handoff.

No magnitude threshold, season, weekday, volatility
signal gate, moving line, crossover, external runtime input, retry, scale-in,
grid, martingale, pyramid, optimization surface, or after-result rescue is
approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue if the exact-path
capacity check is below the governed tester ceiling. It does not authorize a
manual tester dispatch or any tester control.

Expected cadence is approximately five to eight completed positions per full
post-warm-up year. Q02 must retire the identity on zero trades, fewer than five
per year, nonpositive governed economics, wrong endpoints/month identity,
component agreement entry, wrong direction, failed reconciliation, current-
bar leakage, late/repeated entry, invalid risk mode, wrong lifecycle, or
nondeterminism. Q09 alone may establish realized decorrelation from the
certified XAU/SP500/NDX/XNG book; no correlation waiver is permitted.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, and correlation waivers.

