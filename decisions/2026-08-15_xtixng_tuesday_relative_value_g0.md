# XTI/XNG Tuesday Relative-Value — G0 Decision

Date: 2026-08-15

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-15_xtixng_tuesday_relative_value_source_approval.md` at
commit `a2bb28671`.

## Candidate

- EA: `QM5_41015_xtixng-tue-rv`, allocated after source approval by the
  deterministic registry command
- slug: `xtixng-tue-rv`
- Strategy ID: `MEEK-HOELSCHER-XTIXNG-TUE-2026_S01`
- Source ID: `MEEK-HOELSCHER-XTIXNG-TUE-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, SELL
- paired slot 1: `XNGUSD.DWX`, D1, BUY
- planned magics: slot 0 `410150000`, slot 1 `410150001`
- driver: source-reported Tuesday natural-gas-minus-WTI return differential
- lifecycle: genuine Tuesday attachment, equal-notional/joint-risk package,
  Tuesday 21:00 flatten, atomic malformed-package repair

## Source Decision

The approved packet is
`strategy-seeds/sources/MEEK-HOELSCHER-XTIXNG-TUE-2026/source.md`. It binds
one translation to the completely reviewed Meek and Hoelscher paper packet.

Across the source's four asymmetric-variance models, WTI Table 2 supplies
Tuesday coefficients from `-0.000348` to `+0.000001`, none significant.
Natural-gas Table 6 supplies positive Tuesday coefficients from `+0.001508`
to `+0.001857`, each significant at the reported 10% or 5% level. The raw
long-XNG/short-WTI coefficient differential is approximately 16-22 basis
points. The authors do not test the two-leg package, covariance, equal-
notional sizing, Darwinex CFDs, combined fixed risk, costs, or the QM book.
No efficacy or decorrelation claim transfers.

## Locked Rule

1. Attach only within five minutes of a genuine broker Tuesday D1 bar whose
   completed host predecessor is Monday and whose XTI/XNG current bars are
   exactly synchronized.
2. Persist the Monday-anchored week attempt before every fallible gate and
   never retry the week.
3. Open one package only: SELL XTI slot 0 and BUY XNG slot 1.
4. Split one `RISK_FIXED=1000` package budget across frozen
   `3.5 * ATR(20,D1)` stops and target equal absolute USD notionals within 15%.
5. Roll back the first leg if the second fails. Flatten every orphaned,
   duplicated, same-sided, wrong-symbol, wrong-magic, or materially imbalanced
   package.
6. Close both legs at broker Tuesday hour 21. First-non-Tuesday and
   three-calendar-day closes are stale repairs.
7. Use fixed spread ceilings, no target, no scale-in, and no external runtime
   source or event feed.

The weekday, directions, synchronized two-leg object, joint risk/equal-
notional sizing, repair contract, and same-session lifecycle are locked.

## Reputable-Source Criteria

- R1 `PASS`: peer-reviewed open paper, DOI, complete-paper evidence, and exact
  table inputs with translation distance disclosed.
- R2 `PASS`: clock, directions, attempt, synchronization, sizing, stops,
  spreads, atomic repair, and exits are fixed.
- R3 `PASS`: registered native XTI/XNG D1 routes supply all runtime inputs.
- R4 `PASS`: deterministic native arithmetic only, without a runtime
  econometric model, trained output, banned signal indicator, external feed,
  grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,502 registry rows and 598 root cards
and returned no exact hit. Manual review separates its two fuzzy siblings:

- `QM5_41014_xtixng-thu-rv` owns the opposite long-XTI/short-XNG Thursday
  coefficient package;
- `QM5_20237_xtixng-ecm-rv` owns a rolling 252-D1 OLS error-correction state;
- `QM5_20016_xti-xng-mon-rv` owns Monday's short-XTI/long-XNG return clock and
  normally closes at Tuesday's first tick;
- `QM5_12610_wti-tue-fade` and `QM5_12818_xng-tue-prem` are standalone legs
  without the combined risk, equal-notional, or atomic package contract; and
- price-state XTI/XNG ratio, momentum, seasonal, carry, and volatility systems
  do not own this one-session source-coefficient differential.

Verdict: `CLEAN_TUESDAY_XTI_XNG_SOURCE_DIFFERENTIAL_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

The deterministic registry command allocated `QM5_41015` from the global
next-ID sequence; no ID was inferred or hand-edited. Expected cadence is
approximately 45-52 logical packages per year. Q02 must retire on zero
packages, below five/year, wrong-day or unsynchronized entry, malformed
composition, material notional imbalance, or nonpositive governed economics.
Q09 alone may establish realized book correlation.

## Safety Boundary

Create exactly one logical-basket `XTIUSD.DWX` D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision
excludes manual backtests; live, demo, shadow, stress, and optimization
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio-gate
edits; portfolio admission; and correlation waivers. Enqueue once, but do not
dispatch or control a tester when the factory resource ceiling is binding.
