# Q00 Decision - QM5_41094 XNG Weekly Body-Dominance Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-21_xng_weekly_body_dominance_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41094_xng-wbody-dominance-mom_card.md`.

## Identity

- EA ID: `QM5_41094`, allocated atomically by the governed registry allocator
  and committed at `7f96a75e4`;
- slug: `xng-wbody-dominance-mom`;
- strategy ID: `MOP-XNG-WBODY-DOMINANCE-MOM-2026_S01`;
- source ID: `MOP-XNG-WBODY-DOMINANCE-MOM-2026`;
- source authorization: `dde254814`;
- bounded source extraction: `e9ef00eee`;
- host: exact `XNGUSD.DWX`, D1, slot zero, planned magic `410940000`; and
- mechanic: follow the immediately completed natural-gas weekly aggregate
  body's direction for one broker week only when its absolute open-to-close
  body is strictly greater than two-thirds of the weekly high-low range.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits. The canonical `farmctl.py
approve-card` command returned `approved=true` for `QM5_41094` after its
registered custom-history admission check and stamped the declared frequency,
PF prior, drawdown prior, and Q00 reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_BODY_TRANSLATION_RISK`: one canonical child source
  records a named-author, peer-reviewed JFE DOI lineage, complete-paper read,
  durable source/PDF hashes, and explicit natural-gas membership. The weekly
  aggregate body translation is disclosed and no source performance result
  transfers.
- R2 `PASS`: uniform label normalization, first-week clock, one exact
  immediately completed weekly OHLC package, three-to-five-session bounds,
  first open, final close, strict `3*body > 2*range`, equality-flat behavior,
  body direction, durable attempt, fixed risk, stop, spread, and lifecycle
  are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, label, density, cost, fill, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamp, OHLC aggregation, arithmetic,
  comparison, ATR, quote, position, deal-history, and terminal-state logic
  only; one position per magic and no trained output, external feed, adaptive
  PnL rule, grid, martingale, scale-in, or pyramid.

## Duplicate review

Before allocation, the fail-closed canonical checker scanned 4,583
EA-registry identities and 1,263 repository cards. Its configured optional
Strategy-Wiki root was unavailable and remained an explicit input error. The
checker therefore did not emit `CLEAN`; it surfaced the WTI body-dominance
carrier sibling plus two looser weekly-OHLC relatives for manual review.

After allocation, the same checker scanned 4,584 registry rows and returned
the expected exact self-hit on `QM5_41094`. No second registry identity owns
the slug or strategy ID. Repository-wide exact and semantic search found no
pre-existing XNG EA with the complete signal and lifecycle.

Manual family review separates the candidate from:

- `QM5_41092_wti-wbody-dominance-mom`, which applies the same falsifiable
  auction rule to exact WTI. The approved candidate is an independently
  falsified natural-gas carrier with different history, gap/roll behavior,
  volatility, seasonality, 3,000-point spread contract, and return stream.
  It is not a second identity on WTI.
- `QM5_41081_xng-wclose-location-mom`, which requires a parent-to-newest close
  direction plus the newest close in its own outer fifth and never makes the
  newest weekly open or body share load-bearing;
- `QM5_41067_xng-wflip-mom`, which requires a return-sign flip across two
  completed weeks rather than one dominant-body package;
- `QM5_41063_xng-week-nr7-brk`, which ranks seven completed ranges and waits
  for a later current-week breakout rather than deciding at the boundary;
- generic marubozu/candlestick builds whose bar period, carrier set, body
  threshold, wick/trend filters, targets, and lifecycle differ; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG
  cumulative-RSI2 pullback under a slow mean, not a symmetric oscillator-free
  weekly continuation rule.

The exact XNG carrier, immediately completed normalized Monday-anchored
weekly OHLC, three-to-five sessions, strict `3*body > 2*range`, own-body sign,
threshold-equality-flat behavior, first-new-week entry, durable attempt,
fixed risk, 3,000-point spread ceiling, and next-week exit are jointly
load-bearing. Verdict:
`NO_EXACT_XNG_DUPLICATE_CARRIER_SIBLING_AND_SIGNAL_FAMILIES_MANUALLY_DISTINCT`.

## Approved build contract

Development may build exactly the approved card with:

- exact XNG D1 slot zero and governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- the exact immediately completed weekly OHLC package containing three to
  five unique valid sessions at the prior Monday anchor;
- `week_open` from the chronological first session, `week_close` from the
  chronological final session, and aggregate high/low extrema;
- BUY only when `3*abs(close-open) > 2*(high-low)` and `close > open`;
- SELL only when the same strict share holds and `close < open`;
- threshold equality, body equality, malformed history, invalid geometry, or
  a nonadjacent package flat;
- one persistent normalized Monday-anchor attempt recorded before fallible
  gates;
- one `RISK_FIXED=1000` position with a frozen `3.5 * ATR(20,D1)` hard stop,
  no target, and a 3,000-point XNG entry-spread ceiling;
- both news axes and Friday close OFF; and
- first-tick next-week exit plus a ten-calendar-day stale repair.

There is no authorized parent comparison, return-size threshold, separate
wick gate, close-location rule, range rank, current-week signal price, moving
average, oscillator, volatility regime, volume, event, inventory, external
data, dynamic management, retry, or signal-strength sizing. Changing any
load-bearing item requires a new card identity and full Q00/Q01 cycle. Q02
failure cannot authorize an in-place signal rescue.

## Pipeline and safety boundary

Approval permits Q01 build, instrumentation, strict compile, static/reference
tests, canonical `RISK_FIXED` backtest setfile, and one paced non-live Q02
handoff. It does not prove the edge, waive Q02 activity/economic gates,
establish decorrelation, admit the EA to the portfolio, or authorize live use.

No manual tester run, live/demo/shadow/stress/optimization preset,
AutoTrading action, terminal control, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, correlation waiver, or
after-result parameter selection is authorized.
