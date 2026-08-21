# G0 Decision - QM5_41090 WTI Weekly Midpoint-Overlap Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-21_wti_weekly_midpoint_overlap_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41090_wti-wmid-overlap-mom_card.md`.

## Identity

- EA ID: `QM5_41090`, allocated atomically by the governed registry allocator
  and committed at `baca6a1bf`;
- slug: `wti-wmid-overlap-mom`;
- strategy ID: `MOP-WTI-WMID-OVERLAP-MOM-2026_S01`;
- source ID: `MOP-WTI-WMID-OVERLAP-MOM-2026`;
- source authorization: `1cd9eafe8`;
- bounded source extraction: `2a07d20bc`;
- host: exact `XTIUSD.DWX`, D1, slot 0, planned magic `410900000`; and
- mechanic: follow strict drift of the arithmetic high/low midpoint between
  two consecutive completed weekly WTI auction ranges only when those ranges
  share a strictly positive price interval.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-ML hits. The canonical `farmctl.py
approve-card` command returned `approved=true` for `QM5_41090`, after the
registered custom-history admission check, and stamped the declared frequency,
PF prior, drawdown prior, and G0 reasoning into the card.

The PF and drawdown numbers are ordering estimates only. They are not gate
evidence, expected performance promises, or substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_AUCTION_MIDPOINT_TRANSLATION_RISK`: the sole bounded
  child source has a named-author, peer-reviewed JFE parent with DOI,
  complete-paper evidence, durable retrieval hash, and explicit WTI
  membership. Weekly high/low-midpoint drift under overlap is disclosed as an
  untested QM translation.
- R2 `PASS`: uniform label normalization, first-week clock, two exact
  consecutive completed weekly high/low packages, three-to-five-session
  bounds, strict positive overlap, strict midpoint comparison, equality and
  non-overlap-flat behavior, direction, durable attempt, fixed risk, stop,
  spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, energy-label, density, cost, fill, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, high/low arithmetic, comparison, ATR,
  quote, position, deal-history, and terminal-state logic only; no trained
  model, banned signal, external feed, grid, martingale, scale-in, or pyramid.

## Duplicate review

Before allocation, the canonical checker included author and complete-mechanic
fields, scanned 4,579 EA-registry identities and 625 root cards, and returned
`CLEAN`, with no exact or fuzzy match. After allocation, an exact repository
identity scan found only the newly allocated `QM5_41090` row and its own card;
the semantic mechanic search found no earlier midpoint/overlap implementation.

The optional Strategy-Wiki repeat scan failed closed because its configured
`G:\My Drive\09 Strategy Wiki\strategies` root was absent. That input error is
retained here rather than restated as a second PASS; it does not erase the
successful pre-allocation scan or the repository-wide exact and semantic
review.

Manual review separates the candidate from:

- `QM5_41089_wti-wrange-migrate-mom`, which requires both weekly endpoints to
  move in the same direction and can accept non-overlapping ranges;
- `QM5_41073_wti-woutside-settle`, which requires an outside week plus
  settlement, body, and close-location confirmation;
- `QM5_41080_wti-wclose-location-mom`, which uses completed closes and
  own-range close location;
- `QM5_41087_wti-wr4-close-mom`, which ranks four weekly widths and requires
  body/close-location agreement;
- WTI NR7, inside-week, and opening-range systems that wait for a current-week
  breakout;
- the WTI weekly return-path family, which classifies closes and returns rather
  than aggregate high/low centers under an overlap state; and
- certified `QM5_12567`, a long-only two-day XNG cumulative-RSI2 pullback on a
  different carrier.

The exact WTI carrier, two immediate consecutive completed Monday-anchored
weekly packages, three-to-five sessions each, strict positive range overlap,
strict arithmetic-midpoint direction, midpoint-equality and non-overlap-flat
rules, first-new-week entry, durable attempt, fixed risk, and next-week exit
are jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_WEEK_OVERLAPPING_AUCTION_MIDPOINT_DRIFT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and a governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- the immediately completed weekly high/low package and its exact parent, each
  containing three to five unique completed sessions;
- strict positive overlap `max(L0,L1) < min(H0,H1)`;
- BUY only when the newest `low + 0.5*(high-low)` midpoint is strictly higher;
- SELL only when it is strictly lower;
- midpoint equality, touch-only/disjoint ranges, malformed history, or
  nonconsecutive states flat;
- one persistent Monday-anchor attempt recorded before fallible gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-week signal price, open/close/return/range-width/CLV filter,
midpoint-displacement threshold, season, weekday side, moving average,
volatility or volume gate, event/inventory input, external data, retry,
pending entry, target, trail, scale-in, grid, martingale, pyramid, hedge, or
after-result rescue is approved.

## Pipeline and safety boundary

Approval authorizes the branch-only non-live build, one exact WTI D1
`RISK_FIXED` backtest set, strict Q01, and one paced target-only Q02 enqueue
only if the governed terminal and host-CPU ceilings permit it. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong label/week/session or
high/low state, entry at midpoint equality or without strict overlap, wrong
side, current-week leakage, repeated attempt, invalid risk mode, missing stop,
wrong week lifecycle, or nondeterminism. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or `T_Live` manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
