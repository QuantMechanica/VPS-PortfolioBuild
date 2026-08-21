# Q00 Decision - QM5_41100 XNG Weekly Close-Turn Recovery Momentum

Date: 2026-08-22

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_xng_weekly_close_turn_momentum_source_approval.md`
at commit `e0fd6935a`.

Approved card:
`strategy-seeds/cards/approved/QM5_41100_xng-wclose-turn-mom_card.md`.

## Identity

- EA ID: `QM5_41100`, allocated atomically by the governed registry allocator
  at commit `5df526f05`;
- slug: `xng-wclose-turn-mom`;
- strategy ID: `BIANCHI-MOP-XNG-WCLOSE-TURN-MOM-2026_S01`;
- source ID: `BIANCHI-MOP-XNG-WCLOSE-TURN-MOM-2026`;
- source authorization: `e0fd6935a`;
- bounded source extraction: `9b4508ba8`;
- host: exact `XNGUSD.DWX`, D1, slot zero, planned magic `411000000`; and
- mechanic: follow a completed XNG week only when every chronological session
  close forms one strict interior trough or peak and the final close fully
  recovers beyond the first close in the matching direction.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits.
`framework/scripts/skill_g0_card_lint.py` returned `status=ok`, with no missing
fields. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41100` after its registered custom-history admission
check and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_CLOSE_PATH_TRANSLATION_RISK`: the bounded source uses
  two named-author, peer-reviewed DOI papers with complete manuscript reads
  and explicit natural-gas membership. The exact single-turn/full-recovery
  weekly close path is untested and no source result transfers.
- R2 `PASS`: uniform label normalization, first-week clock, one immediately
  completed three-to-five-session package, every chronological close, strict
  monotone legs, one interior turn, full endpoint recovery, durable attempt,
  fixed risk, stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, label, density, cost, fill, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamps, completed closes, comparisons, ATR,
  quotes, positions, deal history, and terminal state only; no trained output,
  banned indicator, external feed, adaptive PnL rule, grid, martingale,
  scale-in, or pyramid.

## Duplicate review

Before allocation, the canonical fail-closed checker scanned 4,589 EA-
registry identities, 1,268 repository cards, and 45 Strategy-Wiki nodes. It
returned the expected fuzzy hit on
`QM5_41099_wti-wclose-turn-mom` and no exact candidate identity. The
machine-readable receipt is
`artifacts/qm5_xng_wclose_turn_mom_preallocation_dedup_20260822.json`.

The fuzzy hit is a separately authorized carrier falsification, not an
in-place WTI revision. The OWNER explicitly permits a second XNG strategy
whose logic differs from `QM5_12567`, and the existing
`QM5_41080`/`QM5_41081` precedent gives predeclared WTI and XNG carriers of
one completed-week mechanic separate identities. Carrier, price path, spread,
density, continuous-CFD basis, and correlation are separately falsified; no
WTI pipeline result transfers.

After allocation, the checker scanned 4,590 registry rows, 1,269 cards, and
45 Strategy-Wiki nodes and returned only the expected exact self identity in
the registry. The receipt is
`artifacts/qm5_xng_wclose_turn_mom_postallocation_dedup_20260822.json`. The
slug and strategy ID both resolve to the single governed row `QM5_41100`.

Manual family review separates the candidate from:

- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day cumulative-
  RSI2 pullback under a slow mean with a five-bar maximum hold. The candidate
  is symmetric, oscillator-free, weekly, and owns a full next-week lifecycle.
- `QM5_41081_xng-wclose-location-mom`, which uses two completed weekly
  packages, a parent-to-new return sign, and the newest week's high-low close
  location. The candidate uses one week's chronological closes only, reads no
  high or low, and requires a strict single-turn/full-recovery path.
- `QM5_41094_xng-wbody-dominance-mom`, which compares aggregate weekly body
  size with high-low range. The candidate reads neither the weekly open nor
  intraday extremes and has no body-share threshold.
- `QM5_41067_xng-wflip-mom`, which classifies two adjacent week-end return
  signs. The candidate classifies the within-week path of one package and
  reads no older weekly return.
- `QM5_41063_xng-week-nr7-brk`, which ranks seven completed weekly ranges and
  waits for a current-week breakout. The candidate ranks nothing and excludes
  current-week prices from its signal.
- `QM5_41099_wti-wclose-turn-mom`, the exact WTI carrier sibling and expected
  fuzzy match. It establishes no XNG efficacy, cost, density, basis, or
  correlation prior.

The exact XNG carrier, immediately completed normalized Monday-anchored
weekly package, three-to-five sessions, every chronological close, exactly one
strict interior turning point, strict monotone legs, final-close recovery
beyond the first close, equality/no-turn/multi-turn/incomplete-recovery-flat
behavior, first-new-week entry, durable attempt, fixed risk, 1,500-point
spread ceiling, and next-week exit are jointly load-bearing. Verdict:
`NO_SECOND_XNG_WEEKLY_CLOSE_TURN_RECOVERY_MOMENTUM_IDENTITY_AFTER_EXPECTED_WTI_CARRIER_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact XNG D1 slot zero and governed magic allocation;
- one uniform raw or `+1`-day energy-label convention applied to the current
  bar and every historical bar;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- the exact immediately completed package containing three to five unique,
  strictly ordered valid sessions at the prior Monday anchor;
- every chronological session close, with no current-week signal input;
- BUY only for one strict interior trough, strictly decreasing closes into
  the trough, strictly increasing closes after it, and a final close above the
  first close;
- SELL only for the exact peak mirror with a final close below the first;
- adjacent equality, no interior turn, more than one turn, an endpoint turn,
  incomplete recovery, malformed history, or a nonadjacent package flat;
- one persistent normalized Monday-anchor attempt recorded before fallible
  gates;
- one `RISK_FIXED=1000` position with a frozen `3.5 * ATR(20,D1)` hard stop,
  no target, and a 1,500-point XNG entry-spread ceiling;
- both news axes and Friday close OFF; and
- first-tick next-week exit plus a ten-calendar-day stale repair.

There is no authorized turn-depth or return threshold, open/high/low signal,
parent comparison, sign-count gate, body-share threshold, excursion ratio,
wick rule, close-location rule, return channel, range rank, moving average,
oscillator, volatility regime, volume, event, inventory, external data,
dynamic management, retry, or signal-strength sizing. Changing any load-
bearing item requires a new card identity and full Q00/Q01 cycle. Q02 failure
cannot authorize an in-place signal rescue.

## Pipeline and safety boundary

Approval permits Q01 build, instrumentation, compile, static/reference tests,
canonical `RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff. It
does not prove the edge, waive Q02 activity/economic gates, establish
decorrelation, admit the EA to the portfolio, or authorize live use.

No manual tester run, live/demo/shadow/stress/optimization preset,
AutoTrading action, terminal control, `T_Live` change, deploy or
`T_Live`-manifest edit, portfolio-gate edit, correlation waiver, or after-
result parameter selection is authorized.
