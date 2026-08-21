# Q00 Decision - QM5_41099 WTI Weekly Close-Turn Recovery Momentum

Date: 2026-08-22

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_wti_weekly_close_turn_momentum_source_approval.md`
at commit `854ef19f5`.

Approved card:
`strategy-seeds/cards/approved/QM5_41099_wti-wclose-turn-mom_card.md`.

## Identity

- EA ID: `QM5_41099`, allocated atomically by the governed registry allocator
  at commit `ca6b87716`;
- slug: `wti-wclose-turn-mom`;
- strategy ID: `BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026_S01`;
- source ID: `BIANCHI-MOP-WTI-WCLOSE-TURN-MOM-2026`;
- source authorization: `854ef19f5`;
- bounded source extraction: `89a28ed62`;
- host: exact `XTIUSD.DWX`, D1, slot zero, planned magic `410990000`; and
- mechanic: follow a completed WTI week only when every chronological session
  close forms one strict interior trough or peak and the final close fully
  recovers beyond the first close in the matching direction.

## Deterministic approval result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits.
`framework/scripts/skill_g0_card_lint.py` returned `status=ok`, with no missing
fields. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41099` after its registered custom-history admission
check and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate findings

- R1 `PASS_WITH_WEEKLY_CLOSE_PATH_TRANSLATION_RISK`: the bounded source uses
  two named-author, peer-reviewed DOI papers with complete manuscript reads
  and explicit WTI membership. The exact single-turn/full-recovery weekly
  close path is untested and no source result transfers.
- R2 `PASS`: uniform label normalization, first-week clock, one immediately
  completed three-to-five-session package, every chronological close, strict
  monotone legs, one interior turn, full endpoint recovery, durable attempt,
  fixed risk, stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input. Q02 owns
  history, label, density, cost, fill, and futures-to-CFD falsification.
- R4 `PASS`: deterministic timestamps, completed closes, comparisons, ATR,
  quotes, positions, deal history, and terminal state only; no trained output,
  external feed, adaptive PnL rule, grid, martingale, scale-in, or pyramid.

## Duplicate review

Before allocation, the fail-closed canonical checker scanned 4,588 EA-
registry rows and 1,267 repository cards. It found no exact or fuzzy match.
Its configured optional Strategy-Wiki root was unavailable, so the result
remained `INPUT_ERROR_FAIL_CLOSED` rather than a false clean verdict.

After allocation, the checker scanned 4,589 registry rows and returned only
the expected exact self-hit on `QM5_41099`. No second registry identity owns
the slug or strategy ID. Repository-wide exact and semantic search found no
pre-existing WTI EA with the complete signal and lifecycle.

Manual family review separates the candidate from:

- `QM5_41098_wti-wextreme-sequence-mom`, which orders the sessions carrying
  the weekly high and low and confirms with weekly open-to-close direction.
  The candidate ignores open/high/low and requires every chronological close
  to form a strict single-turn recovery path.
- `QM5_41084_wti-wdaybreadth-mom`, which counts adjacent daily-return signs
  in an exact five-session week and uses a parent-to-final return. The
  candidate has no sign count or parent close and rejects every multi-turn
  path regardless of sign breadth.
- `QM5_41092_wti-wbody-dominance-mom`, which compares aggregate body share
  with the weekly range. The candidate reads neither the weekly open nor
  high-low range and has no body threshold.
- `QM5_41095_wti-wexcursion-imbalance-mom` and
  `QM5_41096_wti-wexcursion-reject-rv`, which compare high/open and open/low
  excursions at a strict ratio. The candidate is invariant to opens and
  intraday extremes.
- `QM5_41065`, `QM5_41068` through `QM5_41072`, `QM5_41074`, and
  `QM5_41082`, which classify several completed week-end returns. The
  candidate classifies one completed week's within-week session-close path.
- `QM5_41029`, `QM5_41032`, and `QM5_41033`, which decompose overnight and
  intraday flow. The candidate reads no opens and performs no gap/body
  decomposition.
- `QM5_9361_mql5-ichi-kumo-bounce`, an M30 cloud-touch plus ADX/DI setup, not
  a WTI weekly close-path rule.
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG oscillator
  pullback under a slow mean, not a symmetric oscillator-free direct-WTI
  weekly close-turn recovery.

The exact WTI carrier, immediately completed normalized Monday-anchored
weekly package, three-to-five sessions, every chronological close, exactly one
strict interior turning point, strict monotone legs, final-close recovery
beyond the first close, equality/no-turn/multi-turn/incomplete-recovery-flat
behavior, first-new-week entry, durable attempt, fixed risk, 1,500-point
spread ceiling, and next-week exit are jointly load-bearing. Verdict:
`NO_EXACT_WTI_WEEKLY_CLOSE_TURN_RECOVERY_MOMENTUM_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Approved build contract

Development may build exactly the approved card with:

- exact WTI D1 slot zero and governed magic allocation;
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
  no target, and a 1,500-point WTI entry-spread ceiling;
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
