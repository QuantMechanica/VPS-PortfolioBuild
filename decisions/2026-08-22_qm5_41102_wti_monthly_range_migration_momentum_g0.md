# Q00 Decision - QM5_41102 WTI Monthly Auction-Range Migration Momentum

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_wti_monthly_range_migration_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41102_wti-mrange-migrate-mom_card.md`.

## Identity

- EA ID: `QM5_41102`, allocated atomically by the governed registry allocator
  and committed at `80c632b08`;
- slug: `wti-mrange-migrate-mom`;
- strategy ID: `MOP-WTI-MRANGE-MIGRATE-MOM-2026_S01`;
- source ID: `MOP-WTI-MRANGE-MIGRATE-MOM-2026`;
- source authorization: `e74e9ab06`;
- bounded source extraction: `6cb14504c`;
- host: exact `XTIUSD.DWX`, D1, slot 0, planned magic `411020000`; and
- mechanic: follow strict same-direction migration of both endpoints of the
  immediately completed WTI monthly auction range versus its parent month.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41102`, after the registered custom-history admission
check, and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF and drawdown numbers are conservative build-ordering estimates only.
They are not gate evidence, expected-performance promises, or substitutes for
Q02.

## Gate findings

- R1 `PASS_WITH_MONTHLY_RANGE_STATE_TRANSLATION_RISK`: the sole bounded child
  source has named authors, a peer-reviewed JFE parent with DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership. Monthly
  high/low range migration is disclosed as an untested QM translation.
- R2 `PASS`: uniform label normalization, first-month clock, two exact
  consecutive completed monthly high/low packages, 17-to-23-session bounds,
  strict endpoint comparisons, mixed/equality-flat behavior, direction,
  durable attempt, fixed risk, stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, energy-label, density, cost, fill, and continuous-CFD falsification.
- R4 `PASS`: deterministic timestamp, OHLC, comparison, ATR, quote, position,
  deal-history, and terminal-state logic only; no trained model, banned
  signal, external feed, grid, martingale, scale-in, or pyramid.

## Duplicate review

The fail-closed pre-allocation checker scanned 4,591 EA-registry identities,
1,270 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and returned the expected fuzzy weekly family. The post-allocation scan
checked 4,592 registry identities, 1,271 cards, and 45 Wiki nodes and found
only the newly reserved `QM5_41102` slug and strategy ID as exact hits. Manual
semantic review separates the candidate from:

- `QM5_41089_wti-wrange-migrate-mom`, whose two completed broker-week
  packages, weekly decisions, and one-week lifecycle differ from this card's
  complete calendar-month aggregation and next-month ownership;
- `QM5_41101_xng-wrange-migrate-mom`, the weekly natural-gas carrier sibling;
- `QM5_20187_wti-tsmom1m`, which reads two month-end closes and trades their
  return sign;
- `QM5_20008_wti-month-ch3`, which compares one month-end close with three
  earlier month-end closes;
- `QM5_41064_wti-mflip-mom`, which requires an adjacent monthly return-sign
  change;
- weekly settlement, midpoint, and close-breakout families; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG
  cumulative-RSI2 pullback under a slow trend filter.

The exact WTI carrier, two immediate consecutive completed broker-calendar
monthly high/low packages, 17-to-23 sessions each, strict `HH+HL` long /
`LH+LL` short state, equality/inside/outside/mixed flat rule, first-new-month
entry, durable attempt, fixed risk, and next-month exit are jointly
load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_TWO_ENDPOINT_AUCTION_RANGE_MIGRATION_CONTINUATION_AFTER_HORIZON_AND_FAMILY_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact XTI D1 slot zero and a governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- the immediately completed monthly high/low package and its exact parent,
  each containing 17 through 23 unique completed sessions;
- BUY only on strict newest `high > parent high` and `low > parent low`;
- SELL only on strict newest `high < parent high` and `low < parent low`;
- every equality, inside, outside, one-endpoint, malformed, or nonconsecutive
  state flat;
- one persistent `yyyymm` attempt recorded before fallible gates;
- one `RISK_FIXED=1000` position with frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-month signal price, open/close/return/range-width/CLV filter,
threshold distance, season, weekday, moving average, volatility or volume
gate, event/inventory input, external data, retry, pending entry, target,
trail, scale-in, grid, martingale, pyramid, hedge, or after-result rescue is
approved.

## Pipeline and safety boundary

Approval authorizes the branch-only non-live build, one exact XTI D1
`RISK_FIXED` backtest set, strict Q01, and one paced target-only Q02 enqueue
only if the governed terminal and host-CPU ceilings permit it. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong label/month/session
or OHLC state, entry at equality or a mixed/inside/outside state, wrong side,
current-month leakage, repeated attempt, invalid risk mode, missing stop,
wrong month lifecycle, or nondeterminism. Q09 alone may establish realized
book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or `T_Live` manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
