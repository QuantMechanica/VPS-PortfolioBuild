# G0 Decision - QM5_41061 WTI Completed-Week NR7 Expansion

Date: 2026-08-18

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-18_wti_completed_week_nr7_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41061_wti-week-nr7-brk_card.md`.

## Identity

- EA ID: `QM5_41061`, allocated deterministically at commit `3a5984317`
- slug: `wti-week-nr7-brk`
- strategy ID: `CRABEL-WTI-WEEKNR7-2026_S01`
- source approval commit: `908ee9cc8`
- magic allocation commit: `49d8151ce`
- host: exact `XTIUSD.DWX`, D1, slot 0, magic `410610000`
- mechanic: strict normalized complete-week WTI NR7 followed by a next-week
  completed-close escape in the continuation direction and Friday-flat hold

## Gate Findings

- R1 `PASS_WITH_TIME_AGGREGATION_RISK`: a named-author/publisher systematic
  trading book supplies narrow-range/expansion lineage, with the untested
  weekly continuous-CFD translation disclosed.
- R2 `PASS`: uniform label normalization, complete weeks, seven-week sample,
  strict high-low range comparison, completed-close break, side, durable
  attempt, fixed risk, hard stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native WTI D1
  history and the active slot-zero magic supply every runtime input. Q02 owns
  label, history, fill, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamp, OHLC, extrema, ATR risk plumbing, quote,
  position, deal, and terminal state only; no banned signal, external runtime
  feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The canonical checker scanned 4,548 registry rows and 625 root cards, found no
exact identity, and surfaced only the expected fuzzy match to the weekly WTI
opening-range family. Manual review separates the single-D1 NR7 setup in
`QM5_13096`, the current-week first-D1 opening box in `QM5_12965`, the
parent/inside-week relation in `QM5_13075`, the two-metal synchronized close-
ratio basket in `QM5_41060`, and the XNG cumulative-RSI pullback in
`QM5_12567`.

None requires an outright WTI full high-low range over the immediately prior
complete Monday-Friday week, strict comparison with six older complete weeks,
and only the next week's first completed-close escape with one attempt and
Friday-flat lifecycle. Verdict:
`CLEAN_WTI_COMPLETE_WEEK_NR7_NEXT_WEEK_EXPANSION_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and registered magic;
- one uniform raw or `+1`-day energy-label convention applied to all bars;
- the immediately prior exact complete Monday-Friday week plus six older valid
  complete comparison weeks within a fixed 90-bar buffer;
- positive finite full high-low ranges and a strict prior-week minimum;
- Tuesday-Friday new-bar evaluation, 180-minute grace, and only the latest
  completed current-week close beyond the prior extrema;
- one persistent broker-week attempt recorded before fallible execution gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close ON at broker 21, later-week repair, and an
  eight-day stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No daily setup fallback, opening-range fallback, inside-week requirement,
incomplete immediate prior week, non-strict range tie, current-bar or intrabar
trigger, mean-reversion side, signal retry, external data, parameter sweep,
target, trailing stop, scale-in, grid, martingale, or after-result rescue is
approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one WTI D1 `RISK_FIXED`
backtest set, strict Q01, and one paced target-only Q02 enqueue only if exact-
path tester count and host CPU are below governed ceilings. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong label/week/sample
state, wrong-side or stale close, repeated attempt, invalid risk mode, missing
stop, wrong Friday lifecycle, or nondeterminism. Q09 alone may establish
realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
