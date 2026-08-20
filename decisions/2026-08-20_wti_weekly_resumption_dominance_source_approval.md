# WTI Completed-Week Resumption Dominance - Source Approval

Date: 2026-08-20

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch on 2026-08-20. The mission requires one new,
non-duplicate, structural low-frequency commodity edge with reputable-source
criteria and `RISK_FIXED` backtests; explicitly permits a structural
`XTIUSD` trend edge; and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-wresume-dom`
- proposed strategy ID: `MOP-WTI-WRESUME-DOM-2026_S01`
- proposed source ID: `MOP-WTI-WRESUME-DOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: three immediately preceding, non-overlapping completed broker-week
  log returns have an outer-sign / opposite-middle / resumed-outer-sign path,
  and the newest absolute move is strictly larger than the middle countermove
- action: follow the resumed newest sign for one broker week
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
`strategy-seeds/sources/MOP-WTI-WRESUME-DOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, and include
WTI crude oil in their commodity universe. Their tested formation and holding
horizons are monthly. They do not test a WTI-only weekly horizon, a three-week
resume/counter/resume path, or a newest-versus-counterweek magnitude test.
Those are predeclared QM timing hypotheses. No source return, density, cost,
CFD equivalence, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of its executable open, reconstruct exactly four
   consecutive completed broker-week-end closes.
3. Compute three adjacent, non-overlapping weekly log returns in chronological
   order. BUY only for `positive / negative / positive`; SELL only for
   `negative / positive / negative`. In both cases require the newest absolute
   return to be strictly larger than the middle countermove. Zero, equality,
   an outer-sign mismatch, or a middle return that does not oppose consumes the
   week flat.
4. Persist the exact Monday week-anchor attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker week.
5. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap spread at 1,500 points.
6. Close on the first tick of a later broker week or after ten calendar days.
   Never trail, partially close, scale in, grid, martingale, pyramid, or add an
   external runtime dependency.

## Non-Duplicate Decision

The canonical checker scanned 4,558 registry rows and 625 root cards and
returned `CLEAN`, with no exact or fuzzy match. Manual review separates:

- `QM5_41065_wti-wflip-mom`, which uses only two opposed completed weeks and
  follows every newest sign without a preceding trend anchor or magnitude
  dominance test; this candidate requires a third older week whose sign is
  restored by a newest move that strictly dominates the intervening counterweek;
- `QM5_41069_wti-wpull-trend`, which enters immediately after a strictly
  smaller newest counterweek in the older sign; this candidate waits through
  that counterweek and requires a separate completed resumption week before
  entering;
- `QM5_41068_wti-waccel-mom` and `QM5_41070_wti-wdecel-mom`, which require
  the newest two returns to share a sign; this candidate requires them to be
  opposed and also constrains the third return;
- `QM5_41064_wti-mflip-mom`, which uses completed broker months rather than
  four synchronized week-end closes;
- `QM5_20273_wti-signrun-tr`, which scores a multi-month sign run rather than
  a strict three-week resume/counter/resume path; and
- `QM5_13049_xti-1w-mom-vol` and `QM5_21503_xti-weekly-tsmom-lowvol`, which
  condition one weekly return on a volatility state rather than requiring
  three chronological sign states and countermove dominance.

The exact WTI carrier, four week-end closes, three chronological return
intervals, outer-sign equality, opposed middle sign, strict newest magnitude
dominance, resumed-sign direction, consumed weekly attempt, and full-week
ownership are jointly load-bearing. Verdict:
`CLEAN_WTI_THREE_WEEK_RESUME_COUNTER_RESUME_DOMINANCE_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_RESUMPTION_TRANSLATION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit WTI membership, and the untested weekly path and
  dominance gate disclosed.
- R2 `PASS`: exact week anchors, endpoints, chronological state, side,
  attempt, risk, stop, spread, and lifecycle are locked before testing.
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

Expected cadence is approximately five to ten completed positions per full
post-warm-up year. Q02 must retire below five trades per year, at zero trades
or nonpositive governed economics, or on any week-anchor, endpoint, sign,
magnitude, direction, attempt, risk, lifecycle, or determinism defect. No weak
result may be rescued by accepting equality, removing the oldest-week anchor,
relaxing the opposed-middle state or dominance test, changing direction or
hold, or adding a return threshold, volatility, volume, calendar, or external
state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.

