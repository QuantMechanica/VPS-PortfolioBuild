# Q00 Decision - QM5_41098 WTI Weekly Extreme-Sequence Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-21_wti_weekly_extreme_sequence_momentum_source_approval.md`
at commit `e45984a09`.

Approved card:
`strategy-seeds/cards/approved/QM5_41098_wti-wextreme-sequence-mom_card.md`.

## Identity

- EA ID: `QM5_41098`, allocated atomically by the governed registry allocator
  at commit `001defa79`;
- slug: `wti-wextreme-sequence-mom`;
- strategy ID: `MOP-WTI-WEXTREME-SEQUENCE-MOM-2026_S01`;
- source ID: `MOP-WTI-WEXTREME-SEQUENCE-MOM-2026`;
- source authorization: `e45984a09`;
- bounded source extraction: `2b76aa74d`;
- host: exact `XTIUSD.DWX`, D1, slot zero, planned magic `410980000`; and
- mechanic: follow one immediately completed WTI weekly auction only when its
  aggregate high and low each occur on one unique session, their chronological
  order is directional, and the final weekly settlement agrees.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits.
`framework/scripts/skill_g0_card_lint.py` returned `status=ok`, with no missing
fields. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41098` after its registered custom-history admission
check and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_EXTREME_SEQUENCE_TRANSLATION_RISK`: the bounded source
  carries a named-author, peer-reviewed *Journal of Financial Economics* DOI,
  complete published-paper read, durable retrieval hash, and explicit WTI
  membership. The weekly path-state translation is untested and no source
  result transfers.
- R2 `PASS`: uniform label normalization, first-week clock, one immediately
  completed three-to-five-session package, unique aggregate high and low
  sessions, chronological order, matching settlement sign, durable attempt,
  fixed risk, stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, label, density, cost, fill, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamps, OHLC aggregation, equality and integer
  index comparison, ATR, quotes, positions, deal history, and terminal state
  only; no trained output, external feed, adaptive PnL rule, grid, martingale,
  scale-in, or pyramid.

## Duplicate review

Before allocation, the fail-closed canonical checker scanned 4,587 EA-registry
identities and 1,266 repository cards. It found no exact or fuzzy match. Its
configured optional Strategy-Wiki root was unavailable, so the result remained
`INPUT_ERROR_FAIL_CLOSED` rather than a false clean verdict.

After allocation, the checker scanned 4,588 registry rows and returned the
expected exact self-hit on `QM5_41098`. No second registry identity owns the
slug or strategy ID. Repository-wide exact and semantic search found no pre-
existing WTI EA with the complete signal and lifecycle.

Manual family review separates the candidate from:

- `QM5_41095_wti-wexcursion-imbalance-mom`, which compares aggregate
  `high-open` and `open-low` magnitudes at a strict two-to-one threshold. The
  candidate compares no price distance and instead requires unique session
  order for the aggregate weekly extremes.
- `QM5_41096_wti-wexcursion-reject-rv`, which uses the same excursion
  magnitudes and opposing settlement. The candidate ignores excursion
  magnitude and requires order/settlement agreement.
- `QM5_41092_wti-wbody-dominance-mom`, whose load-bearing inequality compares
  absolute weekly body with full range. The candidate has no body threshold.
- `QM5_41084_wti-wdaybreadth-mom`, which counts positive and negative D1
  bodies. The candidate counts none and ignores intermediate opens/closes.
- `QM5_41029`, `QM5_41032`, `QM5_41033`, and monthly relatives, which
  decompose close-to-open and open-to-close flow. The candidate does not.
- `QM5_41073`, `QM5_41080`, `QM5_41089`, and `QM5_41093`, which require a
  parent range, parent return, close location, or closing channel. The
  candidate is invariant to its parent week.
- `QM5_12965_wti-week-orb` and `QM5_13075_xti-inweek-brk`, which wait for a
  current-week breakout. The candidate enters at the boundary using completed
  history only.
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG oscillator
  pullback under a slow mean, not a symmetric oscillator-free direct-WTI
  weekly extreme-sequence trend.

The exact WTI carrier, immediately completed normalized Monday-anchored
weekly package, three-to-five sessions, unique high and low occurrences,
chronological extreme order, matching settlement sign, ambiguous and
disagreement-flat behavior, first-new-week entry, durable attempt, fixed risk,
1,500-point spread ceiling, and next-week exit are jointly load-bearing.
Verdict:
`NO_EXACT_WTI_WEEKLY_EXTREME_SEQUENCE_MOMENTUM_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- the exact immediately completed weekly package containing three to five
  unique valid sessions at the prior Monday anchor;
- `O` from the chronological first session, `C` from the final session, and
  aggregate `H`/`L` extrema;
- exactly one session carrying `H` and exactly one carrying `L`;
- BUY only when the unique low session precedes the unique high session and
  `C > O`;
- SELL only when the unique high session precedes the unique low session and
  `C < O`;
- repeated extremes, same-session extremes, close/open equality,
  order/settlement disagreement, malformed history, invalid geometry, or a
  nonadjacent package flat;
- one persistent normalized Monday-anchor attempt recorded before fallible
  gates;
- one `RISK_FIXED=1000` position with a frozen `3.5 * ATR(20,D1)` hard stop,
  no target, and a 1,500-point WTI entry-spread ceiling;
- both news axes and Friday close OFF; and
- first-tick next-week exit plus a ten-calendar-day stale repair.

There is no authorized price-distance threshold, parent comparison, body-
share threshold, wick gate, close-location rule, return channel, range rank,
current-week signal price, moving average, oscillator, volatility regime,
volume, event, inventory, external data, dynamic management, retry, or
signal-strength sizing. Changing any load-bearing item requires a new card
identity and full Q00/Q01 cycle. Q02 failure cannot authorize an in-place
signal rescue.

## Pipeline and safety boundary

Approval permits Q01 build, instrumentation, compile, static/reference tests,
canonical `RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff. It
does not prove the edge, waive Q02 activity/economic gates, establish
decorrelation, admit the EA to the portfolio, or authorize live use.

No manual tester run, live/demo/shadow/stress/optimization preset,
AutoTrading action, terminal control, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, correlation waiver, or after-
result parameter selection is authorized.
