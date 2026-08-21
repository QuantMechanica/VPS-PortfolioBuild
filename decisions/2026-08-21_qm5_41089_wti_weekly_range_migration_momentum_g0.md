# G0 Decision - QM5_41089 WTI Weekly Auction-Range Migration Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-21_wti_weekly_range_migration_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41089_wti-wrange-migrate-mom_card.md`.

## Identity

- EA ID: `QM5_41089`, allocated atomically by the governed registry allocator
  and committed at `c3ce76c12`;
- slug: `wti-wrange-migrate-mom`;
- strategy ID: `MOP-WTI-WRANGE-MIGRATE-MOM-2026_S01`;
- source ID: `MOP-WTI-WRANGE-MIGRATE-MOM-2026`;
- source authorization: `801e20b8e`;
- bounded source extraction: `dd28629d1`;
- host: exact `XTIUSD.DWX`, D1, slot 0, planned magic `410890000`; and
- mechanic: follow strict same-direction migration of both endpoints of the
  immediately completed weekly WTI auction range versus its parent week.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-ML hits. The canonical `farmctl.py
approve-card` command returned `approved=true` for `QM5_41089`, after the
registered custom-history admission check, and stamped the declared frequency,
PF prior, drawdown prior, and G0 reasoning into the card.

The PF and drawdown numbers are ordering estimates only. They are not gate
evidence, expected performance promises, or substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_RANGE_STATE_TRANSLATION_RISK`: the sole bounded child
  source has a named-author, peer-reviewed JFE parent with DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership. Weekly range
  migration is disclosed as an untested QM translation.
- R2 `PASS`: uniform label normalization, first-week clock, two exact
  consecutive completed weekly OHLC packages, three-to-five-session bounds,
  strict endpoint comparisons, mixed/equality-flat behavior, direction,
  durable attempt, fixed risk, stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, energy-label, density, cost, fill, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, OHLC, comparison, ATR, quote, position,
  deal-history, and terminal-state logic only; no trained model, banned signal,
  external feed, grid, martingale, scale-in, or pyramid.

## Duplicate review

The canonical pre-allocation checker scanned 4,578 EA-registry identities and
625 root cards and returned `CLEAN`, with no exact or fuzzy match. Manual
semantic review separates the candidate from:

- `QM5_41073_wti-woutside-settle`, whose newest range crosses both parent
  extremes and requires settlement/body/close-location confirmation;
- `QM5_41080_wti-wclose-location-mom`, which uses return sign and own-range
  close location;
- `QM5_41087_wti-wr4-close-mom`, which ranks four weekly widths and requires
  body/close-location agreement;
- WTI NR7, inside-week, and opening-range systems that wait for a current-week
  breakout;
- the WTI weekly return-path family, which classifies completed closes rather
  than aggregate weekly highs and lows;
- `QM5_10596_mql5-highlow`, a configurable multi-H4-bar star/flip system with
  an opposite-star exit, not a completed-week WTI auction package; and
- certified `QM5_12567`, a long-only two-day XNG cumulative-RSI2 pullback on a
  different carrier.

The exact WTI carrier, two immediate consecutive completed Monday-anchored
weekly packages, three-to-five sessions each, strict `HH+HL` long / `LH+LL`
short state, equality/inside/outside/mixed flat rule, first-new-week entry,
durable attempt, fixed risk, and next-week exit are jointly load-bearing.
Verdict:
`CLEAN_WTI_COMPLETED_WEEK_TWO_ENDPOINT_AUCTION_RANGE_MIGRATION_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and a governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- the immediately completed weekly OHLC package and its exact parent, each
  containing three to five unique completed sessions;
- BUY only on strict newest `high > parent high` and `low > parent low`;
- SELL only on strict newest `high < parent high` and `low < parent low`;
- every equality, inside, outside, one-endpoint, malformed, or nonconsecutive
  state flat;
- one persistent Monday-anchor attempt recorded before fallible gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-week closure, and a ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-week signal price, open/close/return/range-width/CLV filter,
threshold distance, season, weekday side, moving average, volatility or volume
gate, event/inventory input, external data, retry, pending entry, target,
trail, scale-in, grid, martingale, pyramid, hedge, or after-result rescue is
approved.

## Pipeline and safety boundary

Approval authorizes the branch-only non-live build, one exact WTI D1
`RISK_FIXED` backtest set, strict Q01, and one paced target-only Q02 enqueue
only if the governed terminal and host-CPU ceilings permit it. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong label/week/session or
OHLC state, entry at equality or a mixed/inside/outside state, wrong side,
current-week leakage, repeated attempt, invalid risk mode, missing stop, wrong
week lifecycle, or nondeterminism. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or `T_Live` manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
