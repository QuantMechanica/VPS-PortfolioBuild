# G0 Decision - QM5_41037 XNG Monthly Public/Session Flow Divergence

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_xng_monthly_flow_divergence_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41037_xng-mflow-div_card.md`.

## Identity

- EA ID: `QM5_41037`, allocated by the deterministic registry sequence
- slug: `xng-mflow-div`
- strategy ID: `WILLIAMS-MOP-XNG-MFLOWDIV-2026_S01`
- carrier: exact `XNGUSD.DWX`, D1, symbol slot 0
- mechanic: at the first genuine D1 boundary of a new broker month,
  decompose every completed prior-month interval into close-to-open and
  open-to-close log flow; require strict component opposition; follow the
  session-flow sign; hold until the next broker month

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: the card cites a complete
  OWNER-supplied Tier-A Williams extraction for public/professional flow and a
  complete-read peer-reviewed JFE paper for natural-gas carrier and monthly-
  hold lineage. Neither source validates the conjunction; the card transfers
  no performance claim.
- R2 `PASS`: exact month identity, normalized labels, all completed endpoints,
  strict opposition, session-following direction, return reconciliation,
  attempt persistence, entry grace, fixed risk, hard stop, spread ceiling,
  month rollover, and stale repair are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered `XNGUSD.DWX` D1 OHLC, quotes,
  broker calendar, positions, deal history, and terminal state are sufficient.
  The registry marks XNG's session offset as inferred from measured XTI, so
  Q02 owns label behavior and no individual bar may be repaired.
- R4 `PASS`: the signal is closed-form calendar and log-return arithmetic. No
  trained output, banned signal indicator, grid, martingale, scale-in, or
  pyramid is present.

## Duplicate Review

The canonical checker reported no exact duplicate and two WTI monthly-flow
fuzzy family matches. The approved execution identity remains distinct:

- `QM5_41035_wti-mflow-div` carries the same information-clock rule on WTI;
  this candidate is the OWNER-permitted second-XNG carrier with independent
  route, magic, risk, fills, and results;
- `QM5_20204_xng-tsmom1m` follows every nonzero month total, while this card
  rejects agreement and follows session flow during opposition;
- `QM5_20054_xng-1m-contr` fades every nonzero month total, while this card
  does not use total-return direction;
- `QM5_21504_xng-flowrev` and `QM5_21520_xng-flow-mom` are weekly return rules
  gated by tick-volume tails, while this card is monthly and uses no volume;
  and
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day RSI(2) pullback above
  SMA(200), not a symmetric information-clock divergence state.

Verdict:
`CLEAN_XNG_MONTHLY_PUBLIC_SESSION_FLOW_DIVERGENCE_AFTER_CARRIER_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- one exact `XNGUSD.DWX` D1 host and position, magic slot 0;
- same-day or uniform `+1`-day D1 label normalization only;
- first-new-month decision within 180 minutes and one durable `yyyymm`
  attempt persisted before every fallible gate;
- 15-25 completed immediately prior-month sessions plus one preceding
  month-end anchor;
- strict opposite component signs and `1e-10` telescoping reconciliation;
- BUY only for positive session/negative overnight flow and SELL only for
  negative session/positive overnight flow;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` in the sole
  backtest setfile;
- a frozen `3.5 * ATR(20,D1)` hard stop, no target, and 3,000-point spread
  ceiling;
- framework Friday close disabled, next-month rollover exit, and 40-day stale
  repair; and
- deterministic reference tests, strict compile, build checks, and static
  Q01 validation before any Q02 handoff.

No magnitude threshold, volume gate, season, weekday, volatility signal gate,
moving line, crossover, external runtime input, retry, scale-in, grid,
martingale, pyramid, optimization surface, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue if the exact-path
capacity check is below the governed tester ceiling. It does not authorize a
manual tester dispatch or any tester control.

Expected cadence is approximately five to eight completed positions per full
post-warm-up year. Q02 must retire the identity on zero trades, fewer than
five per year, nonpositive governed economics, wrong endpoints/month identity,
component agreement entry, wrong direction, failed reconciliation, current-
bar leakage, late/repeated entry, invalid risk mode, wrong lifecycle, or
nondeterminism. Q09 alone may establish realized decorrelation from the
certified XAU/SP500/NDX/XNG book; no correlation waiver is permitted.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, and correlation waivers.

