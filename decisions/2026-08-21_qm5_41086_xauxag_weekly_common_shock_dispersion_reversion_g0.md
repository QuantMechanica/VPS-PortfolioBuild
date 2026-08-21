# G0 Decision - QM5_41086 XAU/XAG Weekly Common-Shock Dispersion Reversion

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch, bounded by
`decisions/2026-08-21_xauxag_weekly_common_shock_dispersion_reversion_source_approval.md`
at commit `ff0d62e6d`.

Approved card:
`strategy-seeds/cards/approved/QM5_41086_xauxag-commonshock-rv_card.md`.

## Identity

- EA ID: `QM5_41086`, atomically allocated at commit `c2f395741`
- slug: `xauxag-commonshock-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026_S01`
- host: exact `XAUUSD.DWX`, D1, slot 0, planned magic `410860000`
- companion: exact `XAGUSD.DWX`, D1, slot 1, planned magic `410860001`
- mechanic: require gold and silver to have strict same-sign individual log
  returns over one synchronized completed broker week, then sell the relative
  outperformer and buy the underperformer for one broker week
- source packet:
  `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026/source.md`

## Deterministic Gates

- `skill_card_schema_lint.py`: required before build, with no missing sections
  or forbidden-token hits permitted.
- `skill_g0_card_lint.py`: required before build, with all required fields and
  module sections present.
- pre-card `research_dedup_check.py`: `CLEAN`, covering 4,573 registry rows,
  625 root cards, and no external vault nodes.
- post-card dedup may identify only this candidate card, as expected.
- registered native carriers: `XAUUSD.DWX` and `XAGUSD.DWX`, D1.
- fixed backtest contract: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Reputable-Source Review

- R1 `PASS_WITH_COMMON_SHOCK_TRANSLATION_RISK`: the bounded source preserves
  named peer-reviewed DOI and official-exchange lineage and explicitly marks
  the same-direction completed-week fade as an untested QM translation.
- R2 `PASS`: week anchors, synchronized endpoints, individual return
  orientation, strict sign/equality handling, symmetric sides, attempt, stops,
  package risk, atomicity, spread caps, and lifecycle are locked.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: exact registered XAU/XAG
  D1 histories and native framework state provide every runtime input. Q02
  owns history, holiday-week, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps, completed prices, logarithms,
  comparisons, ATR, quotes, and native trade state only. No trained signal,
  banned indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid is authorized.

## Non-Duplicate Review

The candidate is not a renamed or parameter-only sibling:

- `QM5_41031` is a one-day asymmetric gold-lead event with a 75 bp gold
  threshold and bounded silver response; this card is symmetric, weekly,
  threshold-free, and permits either leg to be the relative outperformer;
- `QM5_41083` admits only opposite-sign individual weekly returns, while this
  card admits only same-sign individual weekly returns, making their state
  spaces disjoint;
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify multiweek paths of
  the gold-minus-silver return; this card uses one return per individual leg;
- `QM5_41057` decomposes close-to-open and open-to-close relative flows; this
  card uses final completed-week endpoints only;
- `QM5_41085` counts five within-week relative-return signs; this card counts
  none and permits synchronized three-to-five-session weeks; and
- rolling ratio/residual cards estimate a center, scale, regression, score,
  or tail; this card estimates none.

The exact paired carrier, consecutive synchronized completed-week endpoints,
strict same-sign individual returns, symmetric relative-outperformer fade,
persisted weekly attempt, equal-notional aggregate-risk package, and next-week
lifecycle are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_SAME_DIRECTION_WEEKLY_COMMON_SHOCK_RELATIVE_OUTPERFORMER_FADE_AFTER_FAMILY_REVIEW`.

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

The paired carrier is designed to remove the common outright metal direction
from the traded package. Same-sign formation and equal-notional opposite legs
do not prove beta neutrality or low book correlation. Q09 alone owns realized
portfolio overlap, and portfolio admission remains manual.

Q02 must retire on zero trades, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, any label/anchor/endpoint/
sign/direction/attempt/atomicity/lifecycle defect, or nondeterminism. A weak
result may not be rescued by accepting mixed signs, adding a magnitude
threshold, changing direction or hold, fitting a center or hedge ratio, or
adding a volatility, volume, calendar, or external-data filter.

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
