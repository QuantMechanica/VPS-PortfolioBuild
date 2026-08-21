# Q00 Decision - QM5_41093 WTI Weekly Closing-Breakout Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-21_wti_weekly_closing_breakout_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41093_wti-wclose-breakout-mom_card.md`.

## Identity

- EA ID: `QM5_41093`, allocated atomically by the governed registry allocator
  and committed at `2a20468ce`;
- slug: `wti-wclose-breakout-mom`;
- strategy ID: `MOP-SZAKMARY-WTI-WCLOSE-BRK-2026_S01`;
- source ID: `MOP-SZAKMARY-WTI-WCLOSE-BRK-2026`;
- source authorization: `f0d8fe585`;
- bounded source extraction: `cfaabdb97`;
- host: exact `XTIUSD.DWX`, D1, slot zero, planned magic `410930000`; and
- mechanic: follow the immediately completed WTI week's final-close breakout
  above or below the preceding completed week's aggregate high-low range for
  exactly one broker week.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits. The canonical `farmctl.py
approve-card` command returned `approved=true` for `QM5_41093` after its
registered custom-history admission check and stamped the declared frequency,
PF prior, drawdown prior, and Q00 reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_CHANNEL_TRANSLATION_RISK`: one canonical child source
  records two named-author, peer-reviewed DOI lineages, complete-read evidence,
  explicit WTI membership, and a source-defined completed-extrema channel
  family. The one-parent weekly high-low translation is disclosed and no
  source performance result transfers.
- R2 `PASS`: uniform label normalization, first-week clock, two exact
  consecutive completed OHLC packages, three-to-five-session bounds, parent
  high/low aggregation, newest chronological final close, strict outside-
  range comparisons, equality-flat behavior, durable attempt, fixed risk,
  stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, label, density, cost, fill, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, OHLC aggregation, extrema, comparison,
  ATR, quote, position, deal-history, and terminal-state logic only; one
  position per magic and no trained output, external feed, adaptive PnL rule,
  grid, martingale, scale-in, or pyramid.

## Duplicate review

Before allocation, the fail-closed canonical checker used the actual Company
Reference Wiki root plus complete author and mechanic fields. It scanned 4,582
EA-registry identities, 1,255 repository cards, and 45 Wiki strategy nodes.
It found no exact identity and surfaced five lexical weekly-OHLC relatives.

After deterministic allocation and card creation, the same checker scanned
4,583 registry rows and 1,256 cards. Its exact slug and strategy-ID hit was
the newly allocated `QM5_41093` registry row itself. No second EA ID, card, or
Wiki identity matched. That expected self-hit proves the allocation is visible;
it is not a pre-existing strategy.

Manual family review separates the candidate from:

- `QM5_41091_wti-winside-body-mom`, whose contained newest range is mutually
  exclusive with a final close outside the parent range;
- `QM5_41080_wti-wclose-location-mom`, which uses parent-final return and the
  newest close's own-range location rather than parent extremes;
- `QM5_41081_xng-wclose-location-mom`, which uses a different mechanic and
  the natural-gas carrier;
- `QM5_41073_wti-woutside-settle`, which requires both-sided outside
  expansion, own-body agreement, and own-range outer-quartile settlement;
- `QM5_41089_wti-wrange-migrate-mom`, which compares both range endpoints and
  does not make the newest final close decisive;
- `QM5_41061_wti-week-nr7-brk`, which ranks seven ranges and waits for a
  subsequent in-progress-week close breakout; and
- `QM5_20008_wti-month-ch3`, the source-defined monthly close-only channel
  with three prior month-end closes.

The exact WTI carrier, two consecutive immediately completed Monday-anchored
OHLC packages, three-to-five sessions each, newest chronological final close
versus parent aggregate high/low, strict inequality and equality-flat rule,
boundary entry, durable attempt, fixed risk, and next-week exit are jointly
load-bearing. Verdict:
`NO_EXACT_DUPLICATE_PARENT_WEEK_RANGE_FINAL_CLOSE_BREAKOUT_MANUALLY_DISTINCT`.

## Approved build contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- the exact newest and parent completed weekly OHLC packages, each containing
  three to five unique valid sessions and separated by exact seven-day
  Monday-anchor steps;
- `parent_high` and `parent_low` from the older package and `newest_close`
  from the chronologically final session of the newer package;
- BUY only on strict `newest_close > parent_high` and SELL only on strict
  `newest_close < parent_low`;
- equality, an interior close, malformed history, invalid geometry, or a
  nonadjacent anchor flat;
- one persistent normalized Monday-anchor attempt recorded before fallible
  gates;
- one `RISK_FIXED=1000` position with a frozen `3.5 * ATR(20,D1)` hard stop,
  no target, and a 1,500-point entry-spread ceiling;
- both news axes and Friday close OFF; and
- first-tick next-week exit plus a ten-calendar-day stale repair.

There is no authorized own-body, close-location, opposite-side expansion,
range migration, range rank, current-week signal price, breakout buffer,
moving average, volatility regime, volume, event, inventory, external data,
dynamic management, retry, or signal-strength sizing. Changing any load-
bearing item requires a new card identity and full Q00/Q01 cycle. Q02 failure
cannot authorize an in-place signal rescue.

## Pipeline and safety boundary

Approval permits Q01 build, instrumentation, strict compile, static/reference
tests, canonical `RISK_FIXED` backtest setfile, and one paced non-live Q02
handoff. It does not prove the edge, waive Q02 activity/economic gates,
establish decorrelation, admit the EA to the portfolio, or authorize live use.

No manual tester run, live/demo/shadow/stress/optimization preset,
AutoTrading action, terminal control, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, correlation waiver, or
after-result parameter selection is authorized.
