# Q00 Decision - QM5_41095 WTI Weekly Excursion-Imbalance Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-21_wti_weekly_excursion_imbalance_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41095_wti-wexcursion-imbalance-mom_card.md`.

## Identity

- EA ID: `QM5_41095`, allocated atomically by the governed registry allocator
  and committed at `07d849d910374fc8277463cf1c40840294abc8ac`;
- slug: `wti-wexcursion-imbalance-mom`;
- strategy ID: `MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026_S01`;
- source ID: `MOP-WTI-WEXCURSION-IMBALANCE-MOM-2026`;
- source authorization: `0f68d9807facdfbc1baa232c7c941cdc35533f9e`;
- bounded source extraction: `12e5ede4e9839238c11df8f844cd33fc7d884337`;
- host: exact `XTIUSD.DWX`, D1, slot zero, planned magic `410950000`; and
- mechanic: follow an immediately completed WTI weekly aggregate only when
  one directional excursion from its first-session open is strictly greater
  than twice the other and its final close agrees with that direction.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits. The canonical `farmctl.py
approve-card` command returned `approved=true` for `QM5_41095` after its
registered custom-history admission check and stamped the declared frequency,
PF prior, drawdown prior, and Q00 reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_EXCURSION_TRANSLATION_RISK`: one canonical child source
  records a named-author, peer-reviewed JFE DOI lineage, complete-paper read,
  durable source/PDF hashes, and explicit WTI membership. The weekly
  open-centred excursion translation is disclosed and no source performance
  result transfers.
- R2 `PASS`: uniform label normalization, first-week clock, one exact
  immediately completed weekly OHLC package, three-to-five-session bounds,
  first open, aggregate extremes, final close, strict two-to-one inequality,
  settlement agreement, equality/disagreement-flat behavior, durable attempt,
  fixed risk, stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, label, density, cost, fill, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, OHLC aggregation, arithmetic,
  comparison, ATR, quote, position, deal-history, and terminal-state logic
  only; one position per magic and no trained output, external feed, adaptive
  PnL rule, grid, martingale, scale-in, or pyramid.

## Duplicate review

Before allocation, the fail-closed canonical checker scanned 4,584 EA-registry
identities and 1,264 repository cards. Its configured optional Strategy-Wiki
root was unavailable and remained an explicit input error. The checker
therefore did not emit `CLEAN`; it surfaced the WTI body-dominance and range-
migration relatives for manual review.

After allocation, the same checker scanned 4,585 registry rows and returned
the expected exact self-hit on `QM5_41095`. No second registry identity owns
the slug or strategy ID. Repository-wide exact and semantic search found no
pre-existing WTI EA with the complete signal and lifecycle.

Manual family review separates the candidate from:

- `QM5_41092_wti-wbody-dominance-mom`, whose load-bearing inequality is
  `3*abs(close-open) > 2*(high-low)`. The approved candidate instead compares
  `high-open` with `open-low`; close magnitude is irrelevant beyond sign
  agreement.
- `QM5_41089_wti-wrange-migrate-mom`, which compares aggregate high and low
  across two completed weeks. The candidate is invariant to the parent week.
- `QM5_41080_wti-wclose-location-mom`, which requires a parent-to-newest close
  return plus an outer-fifth close. The candidate has no parent return or
  close-location threshold.
- `QM5_41093_wti-wclose-breakout-mom`, which requires a newest close outside a
  prior completed-week closing channel. The candidate reads no prior channel.
- `QM5_41073_wti-woutside-settle`, which requires outside-parent geometry and
  settlement beyond a parent extreme. The candidate uses one weekly package.
- generic candlestick builds whose bar period, carrier set, body/wick/trend
  filters, targets, and lifecycle differ; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG
  cumulative-RSI2 pullback under a slow mean, not a symmetric oscillator-free
  direct-WTI weekly continuation rule.

The exact WTI carrier, immediately completed normalized Monday-anchored
weekly OHLC, three-to-five sessions, strict `U > 2*D` or `D > 2*U` rule,
matching settlement sign, equality/disagreement-flat behavior, first-new-week
entry, durable attempt, fixed risk, 1,500-point spread ceiling, and next-week
exit are jointly load-bearing. Verdict:
`NO_EXACT_WTI_WEEKLY_EXCURSION_IMBALANCE_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- the exact immediately completed weekly OHLC package containing three to
  five unique valid sessions at the prior Monday anchor;
- `O` from the chronological first session, `C` from the final session, and
  aggregate `H`/`L` extrema;
- BUY only when `H-O > 2*(O-L)` and `C > O`;
- SELL only when `O-L > 2*(H-O)` and `C < O`;
- ratio equality, close/open equality, excursion/settlement disagreement,
  malformed history, invalid geometry, or a nonadjacent package flat;
- one persistent normalized Monday-anchor attempt recorded before fallible
  gates;
- one `RISK_FIXED=1000` position with a frozen `3.5 * ATR(20,D1)` hard stop,
  no target, and a 1,500-point WTI entry-spread ceiling;
- both news axes and Friday close OFF; and
- first-tick next-week exit plus a ten-calendar-day stale repair.

There is no authorized parent comparison, body-share threshold, wick gate,
close-location rule, return channel, range rank, current-week signal price,
moving average, oscillator, volatility regime, volume, event, inventory,
external data, dynamic management, retry, or signal-strength sizing. Changing
any load-bearing item requires a new card identity and full Q00/Q01 cycle.
Q02 failure cannot authorize an in-place signal rescue.

## Pipeline and safety boundary

Approval permits Q01 build, instrumentation, strict compile, static/reference
tests, canonical `RISK_FIXED` backtest setfile, and one paced non-live Q02
handoff. It does not prove the edge, waive Q02 activity/economic gates,
establish decorrelation, admit the EA to the portfolio, or authorize live use.

No manual tester run, live/demo/shadow/stress/optimization preset,
AutoTrading action, terminal control, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, correlation waiver, or
after-result parameter selection is authorized.
