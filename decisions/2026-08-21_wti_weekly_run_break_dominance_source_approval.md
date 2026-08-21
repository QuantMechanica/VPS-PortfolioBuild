# WTI Completed-Week Run-Break Dominance - Source Approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch on 2026-08-21. The mission
requires one new, non-duplicate, structural low-frequency commodity edge with
reputable-source criteria and `RISK_FIXED` backtests; explicitly permits a
structural `XTIUSD` trend edge; and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-wrunbreak-dom`
- proposed strategy ID: `MOP-WTI-WRUNBREAK-DOM-2026_S01`
- proposed source ID: `MOP-WTI-WRUNBREAK-DOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: two older adjacent completed broker-week log returns share a strict
  sign and the newest completed-week return has the opposite sign and strictly
  exceeds both older moves combined
- action: follow the newest return, which is also the strict sign of the
  cumulative three-week return, for one broker week
- lifecycle: one persisted attempt per broker week and first-later-week flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The governed record below was read completely before this approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   which records a complete-paper review and durable retrieval identity for
   Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`.

The bounded child extraction is
`strategy-seeds/sources/MOP-WTI-WRUNBREAK-DOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, and include
WTI crude oil in their commodity universe. Their tested formation and holding
horizons are monthly. They do not test a WTI-only weekly horizon, a two-week
same-sign run followed by an opposed break, or the combined-erasure condition.
Those are predeclared QM timing hypotheses. No source return, density, cost,
CFD equivalence, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of its executable open, reconstruct exactly four
   consecutive completed broker-week-end closes.
3. Compute three adjacent, non-overlapping weekly log returns in chronological
   order. Require the two older returns to have the same strict sign and the
   newest return to have the opposite strict sign. Require the absolute newest
   return to be strictly larger than the sum of the two older absolute
   returns. Follow the newest return: two positive weeks followed by a
   dominant negative week sell; two negative weeks followed by a dominant
   positive week buy. Zero, equality, another path, or failed combined
   dominance consumes the week flat.
4. Persist the exact Monday week-anchor attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker week.
5. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap spread at 1,500 points.
6. Close on the first tick of a later broker week or after ten calendar days.
   Never trail, partially close, scale in, grid, martingale, pyramid, or add an
   external runtime dependency.

The strict combined-erasure condition proves that the cumulative return
`r_oldest + r_middle + r_newest` has the newest return's sign. The position is
therefore a filtered own-return continuation trade, not a fade of the newest
opposed week.

## Non-Duplicate Decision

The canonical checker scanned 4,569 registry rows and 625 root cards and
returned `CLEAN`, with no exact or fuzzy match. Manual review separates:

- `QM5_41065_wti-wflip-mom`, which follows every two-week sign handoff without
  a second older same-sign week or combined-erasure proof;
- `QM5_41069_wti-wpull-trend`, which follows the older trend after one
  strictly smaller newest counterweek, while this candidate requires the
  newest counterweek to dominate two older same-sign moves combined and
  follows the newest sign;
- `QM5_41068_wti-waccel-mom` and `QM5_41070_wti-wdecel-mom`, which require the
  newest two weekly returns to share a sign, while this candidate requires the
  newest return to oppose both older returns;
- `QM5_41071_wti-wresume-dom` and `QM5_41072_wti-wcounter-dom`, which require
  an outer/opposed-middle/restored-outer topology rather than a two-week run
  followed by one opposed newest break;
- `QM5_41073_wti-woutside-settle`, which uses completed weekly highs and lows
  plus settlement location rather than close-to-close combined erasure;
- `QM5_41074_wti-wstreak3-mom`, which requires three same-sign weeks; and
- `QM5_13050_xti-1w-rev-vol`, which fades a single high-volatility weekly
  return rather than following a dominant three-week-net break.

The exact WTI carrier, four week-end closes, three chronological return
intervals, older-pair sign equality, opposed newest return, strict newest-over-
summed-older dominance, newest/net-sign direction, consumed weekly attempt,
and full-week ownership are jointly load-bearing. Verdict:
`CLEAN_WTI_TWO_WEEK_RUN_DOMINANT_BREAK_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_PATH_TRANSLATION_RISK`: named authors, peer-reviewed
  JFE paper, DOI, complete-read evidence, durable retrieval identity, explicit
  WTI membership, and the untested weekly path disclosed.
- R2 `PASS`: exact week anchors, endpoints, chronological state, strict
  combined erasure, side, attempt, risk, stop, spread, and lifecycle are
  locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed-price arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Portfolio Claim Boundary

The candidate carries direct WTI physical-energy price risk outside the
certified XAU/SP500/NDX/XNG book and differs mechanically from certified
`QM5_12567`'s long-only two-day cumulative-RSI2 pullback. Carrier and mechanic
difference do not prove low correlation. Q09 alone may establish realized
portfolio overlap; this approval makes no decorrelation or admission claim.

## Kill And Safety Boundary

Expected cadence is approximately two to six completed positions per full
post-warm-up year. Q02 must retire below two trades per year, at zero trades or
nonpositive governed economics, or on any week-anchor, endpoint, sign,
combined-erasure, direction, attempt, risk, lifecycle, or determinism defect.
No weak result may be rescued by accepting equality, weakening the sum
condition, removing an older week, changing direction or hold, or adding a
threshold, volatility, volume, calendar, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
