# G0 Decision - QM5_41035 WTI Monthly Public/Session Flow Divergence

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_wti_monthly_flow_divergence_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41035_wti-mflow-div_card.md`.

## Identity

- EA ID: `QM5_41035`, allocated by the deterministic registry command
- slug: `wti-mflow-div`
- strategy ID: `WILLIAMS-MOP-WTI-MFLOWDIV-2026_S01`
- carrier: exact `XTIUSD.DWX`, D1, symbol slot 0
- mechanic: at the first genuine D1 boundary of a new broker month, decompose
  every completed prior-month interval into close-to-open and open-to-close
  log flow; require strict component opposition; follow session-flow sign; hold
  until the next broker month

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: the card cites a complete
  OWNER-supplied Tier-A Williams extraction for public/professional flow and a
  complete-read peer-reviewed JFE paper for WTI carrier and monthly-hold
  lineage. Neither source validates the conjunction; the card transfers no
  performance claim.
- R2 `PASS`: exact month identity, normalized labels, all completed endpoints,
  strict opposition, session-following direction, return reconciliation,
  attempt persistence, entry grace, fixed risk, hard stop, spread ceiling,
  month rollover, and stale repair are mechanical.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC, quotes, broker calendar,
  positions, deal history, and terminal state are sufficient. No external
  runtime feed is required.
- R4 `PASS`: the signal is closed-form calendar and log-return arithmetic.
  No trained output, banned signal indicator, grid, martingale, scale-in, or
  pyramid is present.

## Duplicate Review

The canonical checker reported no exact duplicate and three fuzzy family
neighbors. The approved execution identity remains distinct:

- unlike `QM5_41034_wti-mflow-agree`, it is flat on agreement months and
  trades only strict opposition;
- unlike `QM5_41032_wti-flow-div`, its formation and hold units are complete
  broker months rather than exact Monday-Friday weeks;
- unlike `QM5_41033_wti-flow-dom`, it follows session flow rather than the
  reconciled total/dominant component and can oppose the completed-month total;
- unlike `QM5_20187_wti-tsmom1m`, it rejects agreement states and never uses
  total-flow sign for direction; and
- unlike `QM5_12567_cum-rsi2-commodity`, it is symmetric, structural, and has
  no oscillator entry.

Verdict:
`CLEAN_WTI_MONTHLY_PUBLIC_SESSION_FLOW_DIVERGENCE_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- one exact `XTIUSD.DWX` D1 host and position, magic slot 0;
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
- a frozen `3.5 * ATR(20,D1)` hard stop, no target, and 1,500-point spread
  ceiling;
- framework Friday close disabled, next-month rollover exit, and 40-day stale
  repair; and
- deterministic reference tests, strict compile, build checks, and static Q01
  validation before any Q02 handoff.

No magnitude threshold, total-flow direction, season, weekday, volatility
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

