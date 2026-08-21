# Q00 Decision - QM5_41096 WTI Weekly Excursion-Rejection Reversal

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-21_wti_weekly_excursion_rejection_reversal_source_approval.md`
at commit `adedf0130`.

Approved card:
`strategy-seeds/cards/approved/QM5_41096_wti-wexcursion-reject-rv_card.md`.

## Identity

- EA ID: `QM5_41096`, allocated atomically by the governed registry allocator
  at commit `fb14d7409`;
- slug: `wti-wexcursion-reject-rv`;
- strategy ID: `BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026_S01`;
- source ID: `BIANCHI-YANG-WTI-WEXCURSION-REJECT-RV-2026`;
- source authorization: `adedf0130`;
- bounded source extraction: `937360b9f`;
- host: exact `XTIUSD.DWX`, D1, slot zero, planned magic `410960000`; and
- mechanic: fade an immediately completed WTI weekly aggregate only when one
  open-centred directional excursion is strictly greater than twice the other
  and the final weekly settlement rejects that dominant excursion.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits.
`framework/scripts/skill_g0_card_lint.py` returned `status=ok`, with no missing
fields. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41096` after its registered custom-history admission
check and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_FAILED_AUCTION_TRANSLATION_RISK`: the bounded source
  carries a named-author, peer-reviewed *Journal of Banking & Finance* DOI,
  complete accepted-manuscript read, explicit crude membership, durable
  hashes, and a separately disclosed working-paper supplement. The weekly
  failed-auction translation is untested and no source result transfers.
- R2 `PASS`: uniform label normalization, first-week clock, one immediately
  completed weekly OHLC package, three-to-five-session bounds, first open,
  aggregate extremes, final close, strict two-to-one inequality, opposing
  settlement sign, durable attempt, fixed risk, stop, spread, and lifecycle
  are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, label, density, cost, fill, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamps, OHLC aggregation, arithmetic,
  comparison, ATR, quotes, positions, deal history, and terminal state only;
  no trained output, external feed, adaptive PnL rule, grid, martingale,
  scale-in, or pyramid.

## Duplicate review

Before allocation, the fail-closed canonical checker scanned 4,585 EA-registry
identities and 1,265 repository cards. Its configured optional Strategy-Wiki
root was unavailable and remained an explicit input error. The checker
therefore did not emit `CLEAN`; it surfaced `QM5_41095` for manual review.

After allocation, the same checker scanned 4,586 registry rows and returned
the expected exact self-hit on `QM5_41096`. No second registry identity owns
the slug or strategy ID. Repository-wide exact and semantic search found no
pre-existing WTI EA with the complete signal and lifecycle.

Manual family review separates the candidate from:

- `QM5_41095_wti-wexcursion-imbalance-mom`, whose rule follows `U>2D` only
  when `C>O` and follows `D>2U` only when `C<O`. The approved candidate uses
  the exact mutually exclusive rejection states: SELL on `U>2D and C<O`, and
  BUY on `D>2U and C>O`. Agreement is flat, so no week qualifies both.
- `QM5_41092_wti-wbody-dominance-mom`, whose load-bearing inequality is
  `3*abs(close-open) > 2*(high-low)`. The candidate compares `high-open` with
  `open-low`; close magnitude is irrelevant after the opposing sign is known.
- `QM5_41089_wti-wrange-migrate-mom`, which compares aggregate high and low
  across two completed weeks. The candidate is invariant to the parent week.
- `QM5_41080_wti-wclose-location-mom`, which requires a parent-to-newest close
  return plus an outer-fifth close. The candidate has no parent return or
  close-location threshold.
- `QM5_41093_wti-wclose-breakout-mom`, which requires a newest close outside a
  prior completed-week closing channel. The candidate reads no prior channel.
- `QM5_41073_wti-woutside-settle`, which requires outside-parent geometry and
  settlement beyond a parent extreme. The candidate uses one weekly package.
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG
  cumulative-RSI2 pullback under a slow mean, not a symmetric oscillator-free
  direct-WTI weekly failed-auction reversal.

The exact WTI carrier, immediately completed normalized Monday-anchored
weekly OHLC, three-to-five sessions, strict `U > 2*D` or `D > 2*U` rule,
opposing settlement sign, agreement/equality-flat behavior, first-new-week
entry, durable attempt, fixed risk, 1,500-point spread ceiling, and next-week
exit are jointly load-bearing. Verdict:
`NO_EXACT_WTI_WEEKLY_EXCURSION_REJECTION_REVERSAL_DUPLICATE_AFTER_FAMILY_REVIEW`.

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
- SELL only when `H-O > 2*(O-L)` and `C < O`;
- BUY only when `O-L > 2*(H-O)` and `C > O`;
- ratio equality, close/open equality, excursion/settlement agreement,
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

Approval permits Q01 build, instrumentation, compile, static/reference tests,
canonical `RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff. It
does not prove the edge, waive Q02 activity/economic gates, establish
decorrelation, admit the EA to the portfolio, or authorize live use.

No manual tester run, live/demo/shadow/stress/optimization preset,
AutoTrading action, terminal control, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, correlation waiver, or
after-result parameter selection is authorized.
