# WTI Completed-Week Daily-Sign Breadth Momentum - Source Approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch on 2026-08-21. The mission
requires one new, non-duplicate, structural low-frequency commodity edge with
reputable-source criteria and `RISK_FIXED` backtests; explicitly permits a
structural `XTIUSD` trend edge; and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-wdaybreadth-mom`
- proposed strategy ID: `MOP-WTI-WDAYBREADTH4-MOM-2026_S01`
- proposed source ID: `MOP-WTI-WDAYBREADTH4-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: exactly five completed daily close-to-close returns in the newest
  completed broker week, at least four with one strict sign, and the complete
  weekly net return with that same strict sign
- action: follow the agreed daily-sign breadth and weekly net direction for
  one broker week
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
`strategy-seeds/sources/MOP-WTI-WDAYBREADTH4-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, and include
WTI crude oil in their commodity universe. Their tested formation and holding
horizons are monthly. They do not test a WTI-only weekly horizon, five daily
return signs, a four-of-five breadth threshold, or weekly-net confirmation.
Those are predeclared QM timing hypotheses. No source return, density, cost,
CFD equivalence, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of its executable open, reconstruct the final close of
   the parent completed week and all five chronological D1 closes in the
   immediately completed week. Require exactly five newest-week sessions.
3. Compute the five adjacent, non-overlapping close-to-close log returns from
   the parent final close through the newest completed week's five closes.
   Count strict positive and strict negative returns; zero counts toward
   neither side. Also compute the exact full-week net log return from the
   parent final close to the newest final close.
4. Buy only when at least four of five daily returns are strictly positive and
   the weekly net return is strictly positive. Sell symmetrically when at
   least four are strictly negative and the weekly net is strictly negative.
   A zero, equality, mixed breadth, opposed weekly net, missing endpoint, or
   non-five-session week consumes the week flat.
5. Persist the exact Monday week-anchor attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker week.
6. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap spread at 1,500 points.
7. Close on the first tick of a later broker week or after ten calendar days.
   Never trail, partially close, scale in, grid, martingale, pyramid, or add an
   external runtime dependency.

The daily-sign breadth measures within-week directional participation; the
weekly-net conjunction prevents one opposed daily move from reversing the
formation-period direction. Magnitudes do not otherwise affect eligibility or
position size.

## Non-Duplicate Decision

The canonical checker scanned 4,571 registry rows and 625 root cards and
returned `CLEAN`, with no exact or fuzzy match. Manual review separates:

- `QM5_41080_wti-wclose-location-mom`, which combines one completed weekly
  return sign with the newest week's high-low close location and never counts
  daily return signs;
- `QM5_41020_wti-wclose-mom`, which uses fixed Tuesday and Friday endpoints
  and a partial-next-week lifecycle rather than five daily intervals and a
  full-week hold;
- `QM5_41065` through `QM5_41074` and `QM5_41082`, which classify sequences,
  magnitudes, ranges, or settlement states across completed weeks rather than
  directional breadth inside one week;
- `QM5_41029` through `QM5_41036`, which decompose session and overnight
  flows, while this candidate counts adjacent close-to-close daily signs;
- `QM5_13150_wti-signmom`, `QM5_20244_wti-trend-sign`, and
  `QM5_20273_wti-signrun-tr`, which use twelve completed monthly returns and a
  monthly renewal clock rather than one exact five-session week;
- `QM5_13049_xti-1w-mom-vol`, which gates a five-D1 magnitude return by a
  rolling volatility rank and does not count the five component signs; and
- `QM5_12567_cum-rsi2-commodity`, which is a long-only two-day oscillator
  pullback rather than symmetric weekly WTI continuation.

The exact WTI carrier, parent final close, exactly five newest-week session
closes, five chronological adjacent return signs, strict four-of-five breadth,
same-sign full-week net confirmation, consumed weekly attempt, and next-week
lifecycle are jointly load-bearing. Verdict:
`CLEAN_WTI_EXACT_FIVE_SESSION_DAILY_SIGN_BREADTH_WITH_WEEKLY_NET_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_DAILY_BREADTH_TRANSLATION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit WTI membership, and the untested weekly breadth path
  disclosed.
- R2 `PASS`: exact week anchors, endpoints, interval orientation, session
  count, zero handling, strict breadth and net conjunction, side, attempt,
  risk, stop, spread, and lifecycle are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, holiday-week attrition, and CFD-basis falsification.
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

Expected cadence is approximately ten to twenty completed positions per full
post-warm-up year. Q02 must retire below five completed positions per full
year, at zero trades or nonpositive governed economics, or on any week-anchor,
endpoint, session-count, return-orientation, breadth, weekly-net, direction,
attempt, risk, lifecycle, or determinism defect. No weak result may be rescued
by accepting a four-session week, lowering the breadth threshold, removing the
net confirmation, changing direction or hold, or adding a threshold,
volatility, volume, calendar, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and whole-host CPU checks are below their
ceilings. At the ceiling, stop before queue mutation and record a non-live
handoff.
