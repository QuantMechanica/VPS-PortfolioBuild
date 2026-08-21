# G0 Decision - QM5_41088 XAU/XAG Weekly Close-Location Divergence Reversion

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch, bounded by
`decisions/2026-08-21_xauxag_weekly_close_location_divergence_reversion_source_approval.md`
at commit `2b66172a6`.

Approved card:
`strategy-seeds/cards/approved/QM5_41088_xauxag-wclv-div-rv_card.md`.

## Identity

- EA ID: `QM5_41088`, atomically allocated at commit `14ed68e12`
- slug: `xauxag-wclv-div-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026_S01`
- host: exact `XAUUSD.DWX`, D1, slot 0, planned magic `410880000`
- companion: exact `XAGUSD.DWX`, D1, slot 1, planned magic `410880001`
- mechanic: require one metal to finish the immediately completed broker week
  strictly in its own upper range tercile and the other strictly in its own
  lower range tercile, then sell the upper-location leg and buy the lower-
  location leg as an equal-notional one-week package
- source packet:
  `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026/source.md`

## Deterministic Gates

- `skill_card_schema_lint.py` and `skill_g0_card_lint.py` must pass before
  build, with no missing section or forbidden-token hit.
- canonical pre-allocation `research_dedup_check.py`: `CLEAN` across 4,577
  registry rows, 625 root cards, and zero external vault nodes.
- post-card dedup may identify only this candidate card, as expected.
- registered native carriers: `XAUUSD.DWX` and `XAGUSD.DWX`, D1.
- fixed backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Reputable-Source Review

- R1 `PASS_WITH_WEEKLY_CLOSE_LOCATION_TRANSLATION_RISK`: the bounded packet
  preserves a named peer-reviewed DOI and official exchange carrier evidence
  while labeling the weekly opposite-tercile fade as an untested QM
  translation.
- R2 `PASS`: week clock, exact anchor, synchronized session set, per-leg OHLC,
  CLV orientation, strict tercile state, contrarian side, attempt, aggregate
  risk, equal notional, stops, spreads, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 histories and framework state provide every runtime input. Q02 owns
  alignment, fills, costs, density, and continuous-CFD basis falsification.
- R4 `PASS`: deterministic timestamps, completed OHLC, division, comparison,
  ATR, quotes, and native trade state only. No banned signal, trained output,
  external runtime feed, grid, martingale, scale-in, or pyramid is authorized.

## Non-Duplicate Review

The candidate is not a renamed or parameter-only sibling:

- `QM5_41083` uses opposite signed per-leg weekly returns; this card ignores
  open-to-close return sign and uses independent high-low close locations.
- `QM5_41079` ranks the newest ratio close against prior ratio closes; this
  card neither computes nor ranks ratio levels.
- `QM5_41086` requires same-sign weekly returns with magnitude dispersion;
  this card uses no return signs or magnitudes.
- `QM5_41060` ranks weekly relative ranges and waits for a current-week
  breakout; this card enters a first-bar completed-state fade.
- `QM5_41062` uses opposed weekend gaps, not weekly auction locations.
- `QM5_12567` is a long-only two-day XNG oscillator pullback on another
  energy market.

The exact XAU/XAG carrier, one synchronized completed-week OHLC package,
strict opposite outer-tercile per-leg close locations, contrarian package,
persisted weekly attempt, and next-week lifecycle are jointly load-bearing.
Verdict:
`CLEAN_XAUXAG_COMPLETED_WEEK_OPPOSITE_LEG_CLOSE_LOCATION_TERCILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Risk And Lifecycle Contract

- one paired package and one consumed attempt per Monday-anchored broker week;
- attempt persisted before history, signal, spread, quote, ATR, sizing, news,
  or order gates;
- target 1:1 absolute entry notional with at most 20 percent lot-step mismatch;
- combined normalized stop risk capped at one `RISK_FIXED=1000` budget;
- frozen `3.5*ATR(20,D1)` hard stop on each leg, no target, and XAU/XAG spread
  ceilings of 1,500/500 points;
- both news axes OFF and Friday close OFF;
- first-later-week close with ten-calendar-day stale repair; and
- no retry, scale-in, grid, martingale, pyramid, trail, break-even move,
  partial close, hedge overlay, or reversal.

## Portfolio And Falsification Boundary

The paired carrier suppresses some common precious-metal direction and uses a
weekly relative auction-location driver rather than the book's outright XAU,
SP500, NDX, or XNG signals, but this does not prove neutrality or low portfolio
correlation. Q09 alone owns realized overlap, and portfolio admission remains
manual.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, any label/anchor/OHLC/CLV/
threshold/direction/attempt/lifecycle defect, or nondeterminism. A weak result
may not be rescued by moving a tercile boundary, accepting equality, reversing
the side, changing the hold, or adding ratio, trend, calendar, volatility,
volume, moving-average, external-data, or fitted-beta logic.

## Approved Build Contract

Development may build exactly the approved card after active magic allocation
with:

- exact XAU D1 host slot 0 and XAG D1 companion slot 1 under governed magics
  and one logical basket manifest;
- first-new-week-bar entry within 180 elapsed raw-session minutes;
- every synchronized positive D1 OHLC pair from the immediately preceding
  Monday-anchored broker week, exactly three to five unique sessions;
- independently aggregated per-leg high, low, and final close, strict positive
  ranges, strict opposite outer-tercile CLVs, and contrarian package side;
- one persistent Monday-anchor attempt recorded before fallible gates;
- one aggregate `RISK_FIXED=1000` budget, equal absolute notional target,
  frozen `3.5*ATR(20,D1)` hard stops, no target, and fixed spread ceilings;
- both news axes and Friday close OFF, next-week closure, and ten-day stale
  guard; and
- deterministic mechanic tests, strict compile, set/registry checks, basket
  manifest validation, and static Q01 validation before Q02 handoff.

No fitted center or hedge ratio, ratio level, return-sign gate, current-week
price, oscillator, trend/calendar/volatility filter, retry, external data,
parameter sweep, target, trail, scale-in, grid, martingale, or after-result
rescue is approved.

## Authorization Boundary

G0 authorizes one branch-only V5 EA directory, deterministic slot-zero and
slot-one magic allocation, one locked `RISK_FIXED` D1 logical-basket setfile,
strict compile/Q01 validation, and one paced target-only Q02 enqueue only if
exact-path tester and whole-host CPU ceilings are below their limits.

It does not authorize a manual backtest, terminal dispatch or control, live,
demo, shadow, stress, optimization, AutoTrading, `T_Live`, deploy or T_Live
manifest edits, portfolio-gate edits, portfolio admission, a decorrelation
claim, or a correlation waiver. If the CPU ceiling is binding, stop before
queue mutation and record the non-live handoff.
