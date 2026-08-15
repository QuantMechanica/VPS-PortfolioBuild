# XTI/XNG Wednesday Relative Value - G0 Decision

Date: 2026-08-16

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-16_xtixng_wednesday_relative_value_source_approval.md` at
commit `53ddb9b4b`.

## Candidate

- EA: `QM5_41018_xtixng-wed-rv`, allocated by the deterministic registry
  command after source approval and semantic dedup review
- slug: `xtixng-wed-rv`
- strategy ID: `LI-BOROWSKI-XTIXNG-WED-2026_S01`
- source ID: `LI-BOROWSKI-XTIXNG-WED-2026`
- host slot 0: `XTIUSD.DWX`, D1, BUY, planned magic `410180000`
- paired slot 1: `XNGUSD.DWX`, D1, SELL, planned magic `410180001`
- lifecycle: one synchronized, jointly risked, approximately equal-notional
  Wednesday package with atomic rollback and repair

## Source Decision

The approved packet is
`strategy-seeds/sources/LI-BOROWSKI-XTIXNG-WED-2026/source.md`. Li et al.
(2022) supply the positive WTI Wednesday direction; Borowski (2016) supplies
the negative natural-gas Wednesday direction. Meek and Hoelscher (2023) are
explicit adverse modern evidence because their natural-gas Wednesday sign is
positive and insignificant.

The two directional parents use different samples and do not test the pair.
No source return, significance, covariance, cost, CFD equivalence, neutrality,
decorrelation, or portfolio result transfers.

## Locked Rule

1. Admit decisions only on an actual broker Wednesday D1 bar whose immediately
   prior completed host bar is Tuesday, whose current XTI/XNG D1 timestamps
   match, and whose first observed tick is within five minutes of D1 open.
2. Persist one Monday-anchored broker-week attempt before every fallible gate
   and never retry the week.
3. BUY slot 0 `XTIUSD.DWX` and SELL slot 1 `XNGUSD.DWX`; neither component is
   authorized alone.
4. Use one aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0` package budget,
   frozen `3.5 * ATR(20,D1)` hard stops, no targets, and 2,500-point spread
   caps on both legs.
5. Jointly solve rounded volumes for approximately 1:1 absolute USD notionals
   within ten-percent relative tolerance while keeping aggregate stop loss
   inside the package budget. Signal magnitude never scales risk.
6. Roll back immediately on a partial open. Repair any orphaned, duplicated,
   wrong-symbol, wrong-magic, same-sided, or materially imbalanced package
   before entry-only gates.
7. Close the package at broker Wednesday 21:00; first-non-Wednesday D1 and
   three-calendar-day checks are stale repairs. Friday close remains enabled
   at broker 21, and both news axes remain OFF.

The weekday, prior-Tuesday continuity, directions, synchronized bars, weekly
attempt, combined risk, equal-notional tolerance, atomicity, stops, spread
caps, and lifecycle are locked.

## Reputable-Source Criteria

- R1 `PASS_WITH_CONFLICTING_MODERN_EVIDENCE`: named peer-reviewed sources,
  DOI identities, complete bounded/complete-paper receipts, and explicit
  adverse replication, multiple-testing, and time-variation risks.
- R2 `PASS`: all signal, sizing, attempt, package, stop, spread, repair, and
  exit decisions are deterministic and frozen.
- R3 `PASS`: registered synchronized XTI/XNG D1 history supplies all runtime
  inputs and an existing logical-basket path.
- R4 `PASS`: deterministic native arithmetic and framework state only,
  without trained output, banned signal methods, external feeds, grid,
  martingale, scale-in, or pyramid.

Both deterministic card linters returned `status: ok` before this decision.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,505 registry rows and 601 root cards,
finding no exact identity and three expected fuzzy family hits. Manual review
separates:

- standalone Wednesday XTI long and XNG short components, which have no joint
  budget, package invariant, atomic rollback/repair, or paired return stream;
- the Thursday package, which shares directions but owns a disjoint source
  coefficient and session;
- the Tuesday package, which owns a different session and opposite direction;
- Monday and Friday packages, which own different weekday clocks; and
- the rolling XTI/XNG error-correction basket, which has no fixed weekday
  decision.

Verdict:
`CLEAN_WEDNESDAY_XTI_XNG_JOINT_PACKAGE_WITH_KNOWN_COMPONENT_OVERLAP`.

## Allocation And Kill Boundary

The atomic `farmctl reserve-ea-ids` command allocated `QM5_41018`; no ID was
inferred or hand-edited. Expected cadence is approximately 45-52 completed
packages/year. Q02 must retire on zero trades, below five/year, wrong weekday
or directions, missing prior-Tuesday continuity, repeated attempts, partial
or imbalanced exposure, invalid risk mode, or nonpositive governed economics.
Q09 alone may establish realized portfolio correlation.

## Safety Boundary

Create exactly one logical-basket D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision
excludes manual backtests; live, demo, shadow, stress, and optimization
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio-gate
edits; portfolio admission; and correlation waivers. Enqueue Q02 once, but do
not dispatch or control a tester when the factory resource ceiling is binding.
