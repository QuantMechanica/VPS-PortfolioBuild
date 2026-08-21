# G0 Decision - QM5_41087 WTI Weekly WR4 Close Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch, bounded by
`decisions/2026-08-21_wti_weekly_wr4_close_momentum_source_approval.md` at
commit `40d5669ac`.

Approved card:
`strategy-seeds/cards/approved/QM5_41087_wti-wr4-close-mom_card.md`.

## Identity

- EA ID: `QM5_41087`, atomically allocated at commit `3a6d5930f`
- slug: `wti-wr4-close-mom`
- strategy ID: `CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026_S01`
- carrier: exact `XTIUSD.DWX`, D1, slot 0, planned magic `410870000`
- mechanic: require the immediately completed broker week to have the strict
  widest full range of the last four completed weeks, then follow its own
  open-to-close direction only when its close is in the matching outer
  quartile of that same week's range
- source packet:
  `strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`

## Deterministic Gates

- `skill_card_schema_lint.py` and `skill_g0_card_lint.py` must pass before
  build, with no missing section or forbidden-token hit.
- canonical pre-allocation `research_dedup_check.py`: `CLEAN` across 4,574
  registry rows, 625 root cards, and zero external vault nodes.
- post-card dedup may identify only this candidate card, as expected.
- registered native carrier: `XTIUSD.DWX`, D1.
- fixed backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Reputable-Source Review

- R1 `PASS_WITH_WEEKLY_WR4_TRANSLATION_RISK`: the bounded packet preserves a
  complete-read peer-reviewed time-series-momentum source that explicitly
  includes WTI and a reputable Crabel range-expansion book lineage. It labels
  the exact weekly WR4/body/CLV conjunction as an untested QM translation.
- R2 `PASS`: week clock, four exact anchors, session bounds, weekly OHLC
  endpoints, strict range rank, direction, CLV thresholds, equality, attempt,
  stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_LABEL_AND_CFD_BASIS_RISK`: exact registered WTI D1 history and
  native framework state provide every runtime input. Q02 owns history,
  holiday-week, label, density, roll/basis, and cost falsification.
- R4 `PASS`: deterministic timestamps, completed OHLC, logarithm, comparison,
  ATR, quotes, and native trade state only. No banned signal, trained output,
  external runtime feed, grid, martingale, scale-in, or pyramid is authorized.

## Non-Duplicate Review

The candidate is not a renamed or parameter-only sibling:

- `QM5_41080` uses two completed weeks, parent-close-to-new-close return sign,
  and 0.80/0.20 close location; it has no range rank.
- `QM5_41073` requires an exact outside week and close beyond the parent's
  range; it has no four-week range rank.
- `QM5_41061` requires a narrowest-of-seven prior week and waits for a
  current-week breakout, the opposite volatility state and a later clock.
- `QM5_13075` uses inside-week containment followed by a later breakout.
- `QM5_12965` defines a current-week opening range rather than ranking
  completed weekly ranges.
- `QM5_12567` is a long-only two-day XNG oscillator pullback on another market.

The exact WTI carrier, four consecutive completed-week packages, newest-week
strict widest-of-four range state, own-week body/outer-quartile agreement,
persisted weekly attempt, and next-week lifecycle are jointly load-bearing.
Verdict:
`CLEAN_WTI_COMPLETED_WEEK_WR4_OWN_BODY_OUTER_QUARTILE_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Risk And Lifecycle Contract

- one position and one consumed attempt per Monday-anchored broker week;
- attempt persisted before history, signal, spread, quote, ATR, sizing, news,
  or order gates;
- frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread cap;
- fixed stop risk of 1,000 account-currency units;
- both news axes OFF and Friday close OFF;
- first-later-week close with ten-calendar-day stale repair; and
- no retry, scale-in, grid, martingale, pyramid, trail, break-even move,
  partial close, hedge, or reversal.

## Portfolio And Falsification Boundary

The WTI carrier supplies direct crude-oil exposure outside the current
index/metal/XNG book, but a different market does not prove low portfolio
correlation. Q09 alone owns realized portfolio overlap, and portfolio
admission remains manual.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, any label/anchor/OHLC/rank/
direction/CLV/attempt/lifecycle defect, or nondeterminism. A weak result may
not be rescued by reducing the four-week lookback, accepting ties, moving the
quartile thresholds, reversing the side, changing the hold, or adding a
calendar, volatility, volume, moving-average, inventory, or external-data
filter.

## Authorization Boundary

G0 authorizes one branch-only V5 EA directory, deterministic slot-zero magic
allocation, one locked `RISK_FIXED` D1 setfile, strict compile/Q01 validation,
and one paced target-only Q02 enqueue only if exact-path tester and whole-host
CPU ceilings are below their limits.

It does not authorize a manual backtest, terminal dispatch or control, live,
demo, shadow, stress, optimization, AutoTrading, `T_Live`, deploy or T_Live
manifest edits, portfolio-gate edits, portfolio admission, a decorrelation
claim, or a correlation waiver. If the CPU ceiling is binding, stop before
queue mutation and record the non-live handoff.

