# Q00 Decision - QM5_41091 WTI Weekly Inside-Range Body Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-21_wti_weekly_inside_body_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41091_wti-winside-body-mom_card.md`.

## Identity

- EA ID: `QM5_41091`, allocated atomically by the governed registry allocator
  and committed at `df65b49a4`;
- slug: `wti-winside-body-mom`;
- strategy ID: `MOP-WTI-WINSIDE-BODY-MOM-2026_S01`;
- source ID: `MOP-WTI-WINSIDE-BODY-MOM-2026`;
- source authorization: `9f47d0a0d`;
- bounded source extraction: `70ab22cd8`;
- host: exact `XTIUSD.DWX`, D1, slot zero, planned magic `410910000`; and
- mechanic: follow the contained completed week's own open-to-close direction
  for one week only when its aggregate high and low are both strictly inside
  those of its consecutive parent week.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits. The canonical `farmctl.py
approve-card` command returned `approved=true` for `QM5_41091` after its
registered custom-history admission check and stamped the declared frequency,
PF prior, drawdown prior, and Q00 reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_INSIDE_BODY_TRANSLATION_RISK`: the sole bounded child
  source has a named-author, peer-reviewed JFE parent with DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership. Strict
  weekly containment and contained-week body continuation are disclosed as an
  untested QM translation.
- R2 `PASS`: uniform label normalization, first-week clock, two exact
  consecutive completed OHLC packages, three-to-five-session bounds, strict
  full containment, strict own-body sign, equality/non-inside-flat behavior,
  direction, durable attempt, fixed risk, stop, spread, and lifecycle are
  mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, energy-label, density, cost, fill, and futures-to-CFD
  falsification.
- R4 `PASS`: deterministic timestamp, OHLC aggregation, arithmetic,
  comparison, ATR, quote, position, deal-history, and terminal-state logic
  only; no trained output, external feed, adaptive PnL rule, grid,
  martingale, scale-in, or pyramid.

## Duplicate review

Before allocation, the fail-closed canonical checker used the actual Company
Reference Wiki root plus complete author and mechanic fields. It scanned 4,580
EA-registry identities, 1,253 repository cards, and 45 Wiki nodes and returned
`CLEAN`, with no exact or fuzzy match.

Manual review separates the candidate from:

- `QM5_13075_xti-inweek-brk`, which waits for a current-week close beyond an
  inside-week extreme and adds SMA, ATR-range, close-location, target, and
  failed-breakout gates;
- `QM5_41061_wti-week-nr7-brk`, which ranks seven weekly ranges and waits for
  a current-week breakout;
- `QM5_41073_wti-woutside-settle`, which requires the opposite range geometry
  plus parent-extreme settlement and close-location confirmation;
- `QM5_41089_wti-wrange-migrate-mom`, which requires both range endpoints to
  migrate in one direction and explicitly rejects inside geometry;
- `QM5_41090_wti-wmid-overlap-mom`, which accepts any positive overlap,
  compares only high/low midpoints, and excludes opens and closes;
- `QM5_41080_wti-wclose-location-mom`, which uses parent-close to newest-close
  return plus an outer-fifth close-location threshold; and
- certified `QM5_12567`, a long-only two-day XNG cumulative-RSI2 pullback on a
  different carrier.

The exact WTI carrier, two immediate consecutive Monday-anchored completed
weekly packages, three-to-five sessions each, strict full containment,
contained-week own open-to-close sign, equality/non-inside-flat rules,
first-new-week entry, durable attempt, fixed risk, and next-week exit are
jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_STRICT_INSIDE_WEEK_OWN_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- the immediately completed weekly OHLC package and its exact parent, each
  containing three to five unique completed sessions;
- strict containment `new_high < parent_high && new_low > parent_low`;
- BUY only when the contained week's final close is strictly above its
  first-session open;
- SELL only when it is strictly below;
- endpoint equality, body equality, non-inside geometry, malformed history,
  or nonconsecutive states flat;
- one persistent Monday-anchor attempt recorded before fallible gates;
- one `RISK_FIXED=1000` position with a frozen `3.5 * ATR(20,D1)` hard stop,
  no target, and a 1,500-point entry-spread ceiling;
- both news axes and Friday close OFF;
- first-tick next-week exit plus a ten-calendar-day stale repair; and
- no current-week signal price, retry, threshold, rank, midpoint,
  close-location, moving-average, volatility-regime, event, inventory,
  external data, dynamic management, or signal-strength sizing.

Changing any load-bearing item requires a new card identity and full Q00/Q01
cycle. Q02 failure cannot authorize an in-place signal rescue.

## Pipeline and safety boundary

Approval permits Q01 build, instrumentation, strict compile, static/reference
tests, canonical `RISK_FIXED` backtest setfile, and one paced non-live Q02
handoff. It does not prove the edge, waive the Q02 activity/economic gates,
establish decorrelation, admit the EA to the portfolio, or authorize live use.

No manual tester run, live/demo/shadow/stress/optimization preset,
AutoTrading action, terminal control, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, correlation waiver, or
after-result parameter selection is authorized.
