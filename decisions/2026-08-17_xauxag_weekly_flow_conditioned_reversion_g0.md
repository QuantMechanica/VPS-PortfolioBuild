# G0 Decision - QM5_41040 XAU/XAG Weekly Flow-Conditioned Relative Reversion

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_xauxag_weekly_flow_conditioned_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41040_xauxag-wflow-fade_card.md`.

## Identity

- EA ID: `QM5_41040`, allocated by the canonical atomic registry command
- slug: `xauxag-wflow-fade`
- strategy ID: `WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWFADE-2026_S01`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, slots 0 and 1
- mechanic: on the first genuine synchronized broker Monday, decompose the
  exact completed prior Monday-through-Friday week for both metals into
  close-to-open and open-to-close log flow; subtract silver from gold;
  require strict component opposition and strict session dominance; fade the
  completed relative week with an equal-notional opposite-leg package; close
  both legs on broker Friday

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: the card cites a complete
  OWNER-supplied Tier-A Williams extraction, peer-reviewed gold/silver
  relationship evidence, governed CME carrier evidence, and a complete
  governed weekly endpoint packet. No source validates the conjunction and no
  performance claim transfers.
- R2 `PASS`: exact week identity, cross-symbol synchronization, all completed
  endpoints, relative subtraction, strict opposition, strict session
  dominance, three reconciliation checks, completed-week fade sides, attempt
  persistence, entry grace, aggregate fixed risk, equal-notional sizing, hard
  stops, spread ceilings, paired Friday exit, and stale repair are mechanical.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 OHLC, quotes, broker calendar, positions, deal history, and
  terminal state are sufficient. Q02 must use one synchronized logical-basket
  window and prove both-leg execution.
- R4 `PASS`: the signal is closed-form timestamp, calendar, and log-return
  arithmetic. No trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid is present.

## Duplicate Review

The canonical checker reported no exact duplicate and two fuzzy family
neighbors. The approved execution identity remains distinct:

- unlike `QM5_41030_xauxag-flowdiv`, it admits only session-dominant
  opposition weeks and takes the opposite sides on every admitted state by
  fading the completed relative week rather than following session flow;
- unlike `QM5_41039_xauxag-mflow-div`, it uses one exact week, a Monday
  decision, and Friday flat rather than a complete month and next-month hold;
- unlike ratio z-score, OLS, MAD, quantile, empirical-tail, failed-break,
  run-exhaustion, and seasonal systems, it estimates no relative level,
  center, scale, fitted residual, tail, or long-horizon state;
- unlike monthly XAU/XAG momentum/reversal and fixed weekend systems, it uses
  an exact prior-week information-time decomposition and a Monday-to-Friday
  lifecycle; and
- unlike `QM5_12567_cum-rsi2-commodity`, it is a symmetric logical basket
  with no oscillator entry.

Verdict:
`CLEAN_XAUXAG_WEEKLY_SESSION_DOMINANT_FLOW_CONDITIONED_RELATIVE_FADE_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XAUUSD.DWX` D1 host slot 0 and `XAGUSD.DWX` D1 companion slot 1;
- exact cross-symbol current and six completed D1 timestamps with no label
  shifting, holiday substitution, or per-bar repair;
- first-Monday decision within 180 minutes and one durable `yyyymmdd` attempt
  persisted before every fallible entry gate;
- completed shifts exactly prior Friday through Monday plus preceding Friday
  anchor at calendar offsets 3, 4, 5, 6, 7, and 10;
- gold-minus-silver overnight and session log-flow components, strict
  opposition, strict `abs(session_relative) > abs(overnight_relative)`, and
  `1e-10` per-metal and relative telescoping reconciliation;
- positive completed `week_relative` maps to SELL XAU/BUY XAG and negative
  maps to BUY XAU/SELL XAG;
- one aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
  budget in the sole logical-basket backtest setfile;
- equal absolute USD notional after rounding, at most 20% mismatch, frozen
  `3.0 * ATR(20,D1)` per-leg hard stops, no target, and 1,500-point per-leg
  spread ceilings;
- both news axes OFF, paired broker-Friday 21 exit, framework Friday close as
  fail-safe, later-week repair, and eight-day stale guard; and
- deterministic reference tests, strict compile, basket/set/registry checks,
  and static Q01 validation before any Q02 handoff.

No ratio/residual state, magnitude threshold, dominance-ratio threshold,
month or event selector, volatility signal gate, moving line, crossover,
external runtime input, retry, scale-in, grid, martingale, pyramid,
optimization surface, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical
`RISK_FIXED` backtest setfile, strict Q01, and one paced target-only Q02
enqueue if the exact-path capacity check is below the governed tester ceiling.
It does not authorize a manual tester dispatch or any tester control.

Expected cadence is approximately seven to fifteen completed packages per
full post-warm-up year. Q02 must retire the identity on zero trades, fewer than
five per year, nonpositive governed economics, wrong endpoints/week identity,
component agreement, absent session dominance, wrong fade sides, failed
reconciliation, current-bar leakage, late/repeated entry, invalid risk mode,
excess notional mismatch, orphan survival, wrong lifecycle, or
nondeterminism. Q09 alone may establish realized decorrelation from the
certified XAU/SP500/NDX/XNG book; no correlation waiver is permitted.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, neutrality claims, and correlation waivers.

