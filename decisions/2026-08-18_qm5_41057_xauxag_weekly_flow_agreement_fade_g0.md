# G0 Decision - QM5_41057 XAU/XAG Weekly Relative-Flow Agreement Fade

Date: 2026-08-18

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-18_xauxag_weekly_flow_agreement_fade_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41057_xauxag-wflow-agree-fade_card.md`.

## Identity

- EA ID: `QM5_41057`, allocated by the deterministic registry at commit
  `a87119911`
- slug: `xauxag-wflow-agree-fade`
- strategy ID: `WILLIAMS-SCHWEIKERT-XAUXAG-WFLOWAGREEFADE-2026_S01`
- source approval commit: `d50ca2929`
- magic allocation commit: `cdb44e1a0`
- carrier: exact `XAUUSD.DWX` D1 host on slot 0 and exact `XAGUSD.DWX` D1
  companion on slot 1, with registered magics `410570000` and `410570001`
- mechanic: reconstruct the exact synchronized prior Monday-through-Friday
  XAU-minus-XAG overnight and session flows, admit only strict same-sign
  components, fade their completed total on Monday, and close the package on
  Friday

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: complete OWNER-supplied Tier-A
  Williams extraction, a named peer-reviewed gold/silver paper with DOI, CME
  carrier research, and complete governed endpoint packets. Their conjunction
  into a weekly agreement fade is explicitly untested and transfers no
  performance claim.
- R2 `PASS`: synchronized calendar sequence, completed endpoints, component
  subtraction, strict agreement, fade sides, reconciliation, durable attempt,
  aggregate fixed risk, hard stops, compensation, and weekly lifecycle are
  fully mechanical.
- R3 `PASS_WITH_DISCLOSED_BASIS_RISK`: registered native XAU/XAG D1 histories
  supply every runtime field. Cross-symbol synchronization and the continuous-
  CFD versus exchange-carrier basis are binding Q01/Q02 conditions.
- R4 `PASS`: deterministic timestamps, completed OHLC, logarithms,
  comparisons, ATR risk plumbing, quotes, positions, deals, and terminal state
  only; no trained output, banned signal indicator, external runtime feed,
  grid, martingale, scale-in, or pyramid.

## Duplicate Review

The canonical pre-allocation checker found no exact identity and only the
expected fuzzy XAU/XAG flow-family neighbors. Manual review confirms:

- `QM5_41030_xauxag-flowdiv` requires strict component opposition and follows
  session flow; this card requires strict component agreement and fades the
  total, making their entry-state sets mutually exclusive;
- `QM5_41040_xauxag-wflow-fade` requires session-dominant component
  opposition before fading; this card admits only agreement, so it cannot
  share a valid signal state;
- `QM5_41039_xauxag-mflow-div` uses a completed broker month, opposition,
  session-following sides, and a next-month lifecycle rather than an exact
  week, Monday fade, and Friday exit;
- ratio, z-score, regression, quantile, tail, failed-break, and seasonal
  systems estimate a relative level or longer-horizon state that this card
  never reads; and
- `QM5_12567_cum-rsi2-commodity` is a standalone long-only XNG daily
  oscillator pullback, not a synchronized market-neutral-style basket.

Verdict:
`CLEAN_XAUXAG_WEEKLY_RELATIVE_FLOW_AGREEMENT_COMPLETED_WEEK_FADE_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XAUUSD.DWX` D1 host, `XAGUSD.DWX` D1 companion, slots 0/1, and
  registered magics `410570000`/`410570001`;
- first executable synchronized D1 tick of a genuine broker Monday, no later
  than 180 minutes after the shared current-day open;
- exact completed prior Friday-through-Monday sessions plus the preceding
  Friday close anchor, with identical timestamps across both metals and no
  holiday substitution;
- five close-to-open and five open-to-close log returns per metal, gold-minus-
  silver subtraction for both components, and endpoint reconciliation within
  `1e-10`;
- admission only when `overnight_relative * session_relative > 0`, followed
  by SELL XAU/BUY XAG when the total is positive and BUY XAU/SELL XAG when it
  is negative;
- no ratio level, fitted center, scale, magnitude threshold, dominance rule,
  volatility signal gate, event, inventory, curve, or optimizer-selected
  filter;
- one logical-basket `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1` D1 backtest setfile;
- equal absolute USD notional target, at most 20% post-rounding mismatch, a
  combined frozen-stop loss no larger than the single package budget, and
  per-leg frozen `3.0 * ATR(20,D1)` hard stops;
- 1,500-point entry spread ceilings on both legs, no target, first-leg
  confirmation, immediate compensation on second-leg failure, and every-tick
  malformed/orphan repair;
- a durable `yyyymmdd` Monday attempt persisted before every fallible gate,
  paired Friday close at broker hour 21, later-week repair, and an eight-day
  stale guard; and
- both news axes OFF, deterministic reference tests, strict compile,
  set/registry checks, and static Q01 validation before Q02 handoff.

No standalone-leg test, retry, scale-in, grid, martingale, pyramid, parameter
sweep, external runtime input, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` logical-
basket backtest setfile, strict Q01, and one paced target-only Q02 enqueue only
if the exact-path tester count and host CPU are below their governed ceilings.
It does not authorize a manual tester dispatch or tester control.

Expected cadence is approximately fifteen to thirty completed packages per
full post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong week identity or endpoints, current-bar
leakage, component opposition, wrong fade sides, late/repeated entry, excess
hedge mismatch, orphan persistence, nondeterminism, invalid risk mode, or
insufficient synchronized history. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation or neutrality claims, and correlation
waivers.
