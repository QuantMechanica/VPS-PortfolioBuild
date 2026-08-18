# G0 Decision - QM5_41060 XAU/XAG Weekly NR7 Breakout

Date: 2026-08-18

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-18_xauxag_weekly_nr7_breakout_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41060_xauxag-week-nr7-brk_card.md`.

## Identity

- EA ID: `QM5_41060`, allocated deterministically at commit `a3990582c`
- slug: `xauxag-week-nr7-brk`
- strategy ID: `CRABEL-CME-XAUXAG-WEEKNR7-2026_S01`
- source approval commit: `039a955c7`
- magic allocation commit: `ff939abf9`
- host: exact `XAUUSD.DWX`, D1, slot 0, magic `410600000`
- companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410600001`
- mechanic: strict complete-week ratio NR7 followed by a fresh next-week
  synchronized completed-close break and Friday-flat opposing package

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_PORT_RISK`: named-author/publisher NR7 trading-book
  lineage plus CME exchange ratio research, with the untested cross-market
  conjunction disclosed.
- R2 `PASS`: synchronized close ratio, complete weeks, seven-week sample,
  strict range comparison, fresh cross, side, durable attempt, equal-notional
  aggregate risk, hard stops, spreads, and lifecycle are mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered XAU/XAG D1
  histories and active slot magics supply every runtime input. Q02 owns history
  alignment, paired fills, lot granularity, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamp, logarithm, extrema, ATR risk plumbing,
  quote, position, deal, and terminal state only; no banned signal, external
  runtime feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The canonical checker scanned 4,547 registry rows and 625 root cards and
returned `CLEAN`. Manual review distinguishes the continuous 120-D1 ratio
channel in `QM5_12724`, the outside-then-inside fade in `QM5_20265`, the
monthly robust memory statistic in `QM5_20249`, and the prior-week relative-
flow fades in `QM5_41040` / `QM5_41057`. None requires a strict complete-week
ratio NR7 plus a fresh next-week inside-to-outside close cross and Friday-flat
continuation package.

Verdict: `CLEAN_WEEKLY_RATIO_NR7_EXPANSION_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XAU host/XAG companion D1 slots and registered magics;
- synchronized completed close ratios grouped by broker Monday key;
- the immediately prior exact complete Monday-Friday week plus six older valid
  complete comparison weeks within a fixed 120-bar buffer;
- positive finite weekly ranges and a strict prior-week minimum across seven;
- Tuesday-Friday new-bar evaluation, 180-minute grace, and a fresh
  inside-to-outside next-week close cross only;
- one persistent broker-week attempt recorded before fallible execution gates;
- one-to-one absolute notional target within 20 percent lot-step tolerance and
  combined normalized stop risk no greater than one `RISK_FIXED=1000` budget;
- frozen `3.0*ATR(20,D1)` hard stops, no targets, and 1,500-point per-leg
  spread ceilings;
- both news axes OFF, Friday close ON at broker 21, later-week repair, and an
  eight-day stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No weekly high/low proxy, intrabar trigger, continuous channel fallback,
mean-reversion side, incomplete immediate prior week, non-strict range tie,
stale outside close, signal retry, external data, standalone leg, parameter
sweep, target, trailing stop, scale-in, grid, martingale, or after-result rescue
is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical-basket
`RISK_FIXED` backtest set, strict Q01, and one paced target-only Q02 enqueue only
if exact-path tester count and host CPU are below governed ceilings. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero trades, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong week/sample state,
stale or wrong-side cross, repeated attempt, malformed basket, invalid risk
mode, wrong lifecycle, or nondeterminism. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
