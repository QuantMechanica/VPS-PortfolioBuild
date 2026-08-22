# Q00 Decision - QM5_41101 XNG Weekly Auction-Range Migration Momentum

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_xng_weekly_range_migration_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41101_xng-wrange-migrate-mom_card.md`.

## Identity

- EA ID: `QM5_41101`, allocated atomically by the governed registry allocator
  and committed at `3a094005d`;
- slug: `xng-wrange-migrate-mom`;
- strategy ID: `MOP-XNG-WRANGE-MIGRATE-MOM-2026_S01`;
- source ID: `MOP-XNG-WRANGE-MIGRATE-MOM-2026`;
- source authorization: `9169ec306`;
- bounded source extraction: `45d597e8a`;
- host: exact `XNGUSD.DWX`, D1, slot 0, planned magic `411010000`; and
- mechanic: follow strict same-direction migration of both endpoints of the
  immediately completed weekly XNG auction range versus its parent week.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-ML hits. The canonical `farmctl.py
approve-card` command returned `approved=true` for `QM5_41101`, after the
registered custom-history admission check, and stamped the declared frequency,
PF prior, drawdown prior, and Q00 reasoning into the card.

The PF and drawdown numbers are conservative build-ordering estimates only.
They are not gate evidence, expected-performance promises, or substitutes for
Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_RANGE_STATE_TRANSLATION_RISK`: the sole bounded child
  source has named authors, a peer-reviewed JFE parent with DOI, complete-paper
  evidence, durable retrieval hash, and explicit natural-gas membership.
  Weekly range migration is disclosed as an untested QM translation.
- R2 `PASS`: uniform label normalization, first-week clock, two exact
  consecutive completed weekly OHLC packages, three-to-five-session bounds,
  strict endpoint comparisons, mixed/equality-flat behavior, direction,
  durable attempt, fixed risk, stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, energy-label, density, cost, fill, and continuous-CFD
  falsification.
- R4 `PASS`: deterministic timestamp, OHLC, comparison, ATR, quote, position,
  deal-history, and terminal-state logic only; no trained model, banned
  signal, external feed, grid, martingale, scale-in, or pyramid.

## Duplicate review

The fail-closed pre-allocation checker scanned 4,590 EA-registry identities,
1,269 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and returned the expected fuzzy WTI carrier sibling. The post-allocation scan
found only the newly reserved `QM5_41101` slug and strategy ID as exact hits.
Manual semantic review separates the candidate from:

- `QM5_41089_wti-wrange-migrate-mom`, the separately falsifiable WTI carrier
  sibling from which no result or execution evidence transfers;
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG
  cumulative-RSI2 pullback beneath a slow trend filter;
- `QM5_41081_xng-wclose-location-mom`, which uses return sign and own-range
  close location;
- `QM5_41094_xng-wbody-dominance-mom`, which uses one weekly open-close body
  share;
- XNG NR7 and Monday-range systems that rank ranges or wait for current-week
  breakouts; and
- `QM5_10596_mql5-highlow`, a configurable multi-H4-bar star/flip system, not
  a completed-week XNG auction package.

The exact XNG carrier, two immediate consecutive completed Monday-anchored
weekly packages, three-to-five sessions each, strict `HH+HL` long / `LH+LL`
short state, equality/inside/outside/mixed flat rule, first-new-week entry,
durable attempt, fixed risk, and next-week exit are jointly load-bearing.
Verdict:
`CLEAN_XNG_COMPLETED_WEEK_TWO_ENDPOINT_AUCTION_RANGE_MIGRATION_CONTINUATION_AFTER_CARRIER_AND_FAMILY_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact XNG D1 slot zero and a governed magic allocation;
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

Approval authorizes the branch-only non-live build, one exact XNG D1
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
