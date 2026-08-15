# XTI/XNG Thursday Relative-Value — G0 Decision

Date: 2026-08-15

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-15_xtixng_thursday_relative_value_source_approval.md` at
commit `0e47c6be8`.

## Candidate

- EA: `QM5_41014_xtixng-thu-rv`, allocated after this decision by the
  deterministic registry command
- slug: `xtixng-thu-rv`
- Strategy ID: `MEEK-HOELSCHER-XTIXNG-THU-2026_S01`
- Source ID: `MEEK-HOELSCHER-XTIXNG-THU-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, BUY
- paired slot 1: `XNGUSD.DWX`, D1, SELL
- registered magics: slot 0 `410140000`, slot 1 `410140001`
- driver: source-reported Thursday WTI-minus-natural-gas return differential
- lifecycle: genuine Thursday attachment, equal-notional/joint-risk package,
  Thursday 21:00 flatten, atomic malformed-package repair

## Source Decision

The approved packet is
`strategy-seeds/sources/MEEK-HOELSCHER-XTIXNG-THU-2026/source.md`. It binds
one translation to the completely reviewed Meek and Hoelscher paper packet.

WTI Table 2 supplies near-zero Thursday coefficients in the source's four
asymmetric-variance models. Natural-gas Table 6 supplies negative Thursday
coefficients of roughly 13-14 basis points, each significant at the reported
10% or 5% level. The authors do not test the two-leg differential, its
covariance, equal-notional sizing, Darwinex CFDs, combined fixed risk, costs,
or the QM book. No efficacy or decorrelation claim transfers.

## Locked Rule

1. Attach only within five minutes of a genuine broker Thursday D1 bar whose
   completed host predecessor is Wednesday and whose XTI/XNG current bars are
   exactly synchronized.
2. Persist the Monday-anchored week attempt before every fallible gate and
   never retry the week.
3. Open one package only: BUY XTI slot 0 and SELL XNG slot 1.
4. Split one `RISK_FIXED=1000` package budget across frozen
   `3.5 * ATR(20,D1)` stops and target equal absolute USD notionals within 15%.
5. Roll back the first leg if the second fails. Flatten every orphaned,
   duplicated, same-sided, wrong-symbol, wrong-magic, or materially imbalanced
   package.
6. Close both legs at broker Thursday hour 21. First-non-Thursday and
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

The canonical pre-card checker scanned 4,501 registry rows and 597 root cards
and returned no exact hit. Its sole fuzzy result was lexical
`xtixng-ecm-rv`, a 252-D1 OLS error-correction system. The expected post-draft
exact hit is the candidate card itself.

Manual review separates Friday long-XTI/short-XNG (`QM5_20110`), opposite
Monday short-XTI/long-XNG (`QM5_20016`), outright XNG Thursday
(`QM5_12819`), price-state XTI/XNG baskets, and incumbent cumulative-RSI
commodity logic. The candidate's Thursday source coefficient pair, joint
budget, equal-notional target, and atomic lifecycle form the new logical
object.

Verdict: `CLEAN_THURSDAY_XTI_XNG_SOURCE_DIFFERENTIAL_AFTER_MANUAL_REVIEW`.

## Allocation And Kill Boundary

The deterministic registry command allocated `QM5_41014` after this decision
from the global next-ID sequence; no ID was inferred or hand-edited. Expected cadence is
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
