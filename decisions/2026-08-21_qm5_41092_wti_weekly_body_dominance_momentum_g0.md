# Q00 Decision - QM5_41092 WTI Weekly Body-Dominance Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-21_wti_weekly_body_dominance_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41092_wti-wbody-dominance-mom_card.md`.

## Identity

- EA ID: `QM5_41092`, allocated atomically by the governed registry allocator
  and committed at `1a02d01dd`;
- slug: `wti-wbody-dominance-mom`;
- strategy ID: `MOP-WTI-WBODY-DOMINANCE-MOM-2026_S01`;
- source ID: `MOP-WTI-WBODY-DOMINANCE-MOM-2026`;
- source authorization: `06f2ed136`;
- bounded source extraction: `069b4af00`;
- host: exact `XTIUSD.DWX`, D1, slot zero, planned magic `410920000`; and
- mechanic: follow the immediately completed WTI week's own open-to-close
  direction for one week only when its absolute real body is strictly greater
  than two-thirds of its complete high-low range.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits. The canonical `farmctl.py
approve-card` command returned `approved=true` for `QM5_41092` after its
registered custom-history admission check and stamped the declared frequency,
PF prior, drawdown prior, and Q00 reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_BODY_TRANSLATION_RISK`: the sole bounded child source
  has a named-author, peer-reviewed JFE parent with DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership. Weekly OHLC
  aggregation and the strict two-thirds body-share rule are disclosed as an
  untested QM translation.
- R2 `PASS`: uniform label normalization, first-week clock, one exact
  immediately completed OHLC package, three-to-five-session bounds, strict
  integer body-share inequality, own-body side, equality-flat behavior,
  durable attempt, fixed risk, stop, spread, and lifecycle are mechanical.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history and MT5 state provide
  every runtime input. Q02 owns history, energy-label, density, cost, fill,
  and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, OHLC aggregation, arithmetic,
  comparison, ATR, quote, position, deal-history, and terminal-state logic
  only; no trained output, external feed, adaptive PnL rule, grid, martingale,
  scale-in, or pyramid.

## Duplicate review

Before allocation, the fail-closed canonical checker used the actual Company
Reference Wiki root plus complete author and mechanic fields. It scanned 4,581
EA-registry identities, 1,254 repository cards, and 45 Wiki strategy nodes and
returned `CLEAN`, with no exact or fuzzy match.

After deterministic allocation and card creation, the same checker scanned
4,582 registry rows and 1,255 cards. Its only exact hit was the newly allocated
`QM5_41092` row itself for the exact slug and strategy ID. No second EA ID,
second card, or Wiki identity matched. That expected self-hit is evidence that
the allocation is now visible, not evidence of a pre-existing strategy.

Manual review separates the candidate from:

- `QM5_41080_wti-wclose-location-mom`, which uses parent-close to newest-close
  return and an outer-fifth close location rather than own open/close body
  share;
- `QM5_41087_wti-wr4-close-mom`, which ranks four ranges and requires a
  compressed week;
- `QM5_41089_wti-wrange-migrate-mom`, which compares both high and low across
  two weeks;
- `QM5_41090_wti-wmid-overlap-mom`, which compares two range midpoints and
  excludes opens and closes;
- `QM5_41091_wti-winside-body-mom`, which requires parent containment and has
  no minimum own-body share;
- `QM5_9413_mql5-paq-marubozu`, which uses individual H1 bars, a 90% body,
  separate wick limits, ATR/EMA filters, a target, and dynamic exits across a
  different multi-symbol identity; and
- certified `QM5_12567`, a long-only two-day XNG cumulative-RSI2 pullback on a
  different carrier.

The exact WTI carrier, one immediate Monday-anchored completed weekly package,
three-to-five sessions, strict `3*abs(close-open) > 2*(high-low)`, own-body
side, threshold-equality-flat rule, first-new-week entry, durable attempt,
fixed risk, and next-week exit are jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_WEEK_STRICT_TWO_THIRDS_BODY_DOMINANCE_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- the exact immediately completed weekly OHLC package containing three to
  five unique valid sessions;
- strict body dominance `3 * abs(week_close - week_open) >
  2 * (week_high - week_low)`;
- BUY only when the qualifying completed body is positive and SELL only when
  it is negative;
- threshold equality, body equality, malformed history, invalid geometry, or
  a nonadjacent anchor flat;
- one persistent normalized Monday-anchor attempt recorded before fallible
  gates;
- one `RISK_FIXED=1000` position with a frozen `3.5 * ATR(20,D1)` hard stop,
  no target, and a 1,500-point entry-spread ceiling;
- both news axes and Friday close OFF;
- first-tick next-week exit plus a ten-calendar-day stale repair; and
- no parent geometry, current-week signal price, retry, separate wick rule,
  return threshold, close-location, range rank, moving average, volatility
  regime, event, inventory, external data, dynamic management, or signal-
  strength sizing.

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
