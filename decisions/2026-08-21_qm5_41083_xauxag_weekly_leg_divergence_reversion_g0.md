# G0 Decision - QM5_41083 XAU/XAG Completed-Week Leg-Divergence Reversion

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch, bounded by
`decisions/2026-08-21_xauxag_weekly_leg_divergence_reversion_source_approval.md`
at commit `55a658719`.

Approved card:
`strategy-seeds/cards/approved/QM5_41083_xauxag-wlegdiv-rv_card.md`.

## Identity

- EA ID: `QM5_41083`, atomically allocated after 4,570 prior registry rows
- slug: `xauxag-wlegdiv-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-WLEGDIV-RV-2026_S01`
- host: exact `XAUUSD.DWX`, D1, slot 0, magic `410830000`
- companion: exact `XAGUSD.DWX`, D1, slot 1, magic `410830001`
- mechanic: gold and silver must have strictly opposite signed log returns
  across the exact same completed broker week; sell the weekly winner and buy
  the weekly loser as one equal-notional package for one broker week
- source packet:
  `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WLEGDIV-RV-2026/source.md`

## Deterministic Gates

- `skill_card_schema_lint.py`: required before build, no missing sections or
  ML-ban hits permitted.
- `skill_g0_card_lint.py`: required before build, all required fields and
  module sections must be present.
- pre-card `research_dedup_check.py`: `CLEAN`, covering 4,570 registry rows,
  625 root cards, and no external vault nodes.
- post-card dedup may identify only this candidate card, as expected.
- registered native carriers: `XAUUSD.DWX` and `XAGUSD.DWX`, D1.
- fixed backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Reputable-Source Review

- R1 `PASS_WITH_WEEKLY_LEG_STATE_TRANSLATION_RISK`: one bounded child source
  preserves named peer-reviewed DOI and official-exchange lineage while
  disclosing that the weekly individual-leg sign condition is untested.
- R2 `PASS`: consecutive completed weeks, synchronized endpoint selection,
  individual log-return orientation, strict opposite signs, sides, attempt,
  stops, package risk, atomicity, and lifecycle are fully locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: exact registered XAU/XAG
  D1 histories and native framework state provide every runtime input. Q02
  owns history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic price, timestamp, logarithm, comparison, ATR,
  spread, quote, and native trade-state arithmetic only. No trained signal,
  banned indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid is authorized.

## Non-Duplicate Review

The candidate is not a renamed or parameter-only sibling:

- rolling ratio and residual cards estimate a center, dispersion, regression,
  or empirical tail; this card estimates none;
- `QM5_41030` and `QM5_41040` compare session and overnight relative-flow
  components; this card uses only each metal's completed full-week return;
- `QM5_41031` is a thresholded asymmetric one-day gold-lead event; this card
  is symmetric, weekly, and threshold-free;
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify sequences of the
  gold-minus-silver relative return across weeks; they do not require the two
  individual leg returns over one common week to have opposite signs;
- `QM5_41079` ranks daily ratio closes within one week; this card has no
  within-week rank; and
- `QM5_12567` is a single-symbol long-only two-day oscillator pullback on the
  incumbent commodity sleeve.

The exact XAU/XAG carrier, same synchronized weekly interval, strict individual
leg-sign opposition, contrarian relative-winner side, persisted weekly attempt,
equal-notional aggregate-risk package, and next-week lifecycle are jointly
load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_WEEK_LEG_SIGN_DIVERGENCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Risk And Lifecycle Contract

- one logical two-leg package and one consumed attempt per Monday-anchored
  broker week;
- attempt persisted before history, signal, spread, quote, ATR, sizing, news,
  or order gates;
- frozen `3.5 * ATR(20,D1)` per-leg hard stops, no target, XAU 1,500-point and
  XAG 500-point spread caps;
- aggregate-package fixed risk no greater than 1,000 and equal absolute entry
  notional within 20 percent after downward lot rounding;
- both news axes OFF and Friday close OFF;
- first-later-week close with ten-calendar-day stale repair; and
- no retry, one-leg fallback, scale-in, grid, martingale, pyramid, trail,
  break-even move, or partial close.

## Portfolio And Falsification Boundary

The paired intermetal carrier removes common outright direction from the
signal state and is mechanically unlike `QM5_12567`. Equal notional is not
proof of neutrality or low correlation. Q09 alone owns realized portfolio
overlap and any admission decision remains manual.

Q02 must retire on zero trades, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, any label/anchor/endpoint/
sign/direction/attempt/atomicity/lifecycle defect, or nondeterminism. A weak
result may not be rescued by accepting zero or same-sign returns, adding a
magnitude threshold, changing direction or hold, fitting a center or hedge
ratio, or adding a volatility, volume, calendar, or external-data filter.

## Authorization Boundary

G0 authorizes one branch-only V5 EA directory, deterministic slots zero and
one registry allocation, one locked `RISK_FIXED` D1 basket setfile, strict
compile/Q01 validation, and one paced target-only Q02 enqueue only if exact-
path tester and whole-host CPU ceilings are below their limits.

It does not authorize a manual backtest, terminal dispatch or control, live,
demo, shadow, stress, optimization, AutoTrading, `T_Live`, deploy or T_Live
manifest edits, portfolio-gate edits, portfolio admission, a decorrelation
claim, or a correlation waiver. If the CPU ceiling is binding, stop before
queue mutation and record the non-live handoff.
