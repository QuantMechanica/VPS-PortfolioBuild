# QM5_41457 WTI Summer NR2 Positive-Week Reversion — Q01 PASS / Q02 Handoff

Date: 2026-09-12  
Branch: `agents/board-advisor`  
EA: `QM5_41457_wti-summer-nr2-upweek-fade`

## Outcome

One new structural low-frequency energy EA was researched, approved, allocated, built, compiled,
and handed to Q02. During the peer-reviewed June-October negative WTI return leg it requires a
strict two-completed-week range contraction, then shorts only a positive newest completed week
and holds through the next week boundary. It is a directional WTI hypothesis, not a decorrelation
claim; unchanged Q09 alone owns the portfolio-correlation conclusion.

## Research And Identity

- Reputable lineage: Burakov, Freidin, and Solovyev (2018) for the WTI June-October leg; Yang,
  Goncu, and Pantelous for commodity-reversal lineage; governed Crabel range-state and
  completed-week construction.
- Canonical scan: no exact or fuzzy repository identity across 4,938 registry rows and 1,547
  cards; the unavailable external Strategy Wiki root was recorded explicitly.
- Distinct boundary: `QM5_20093` is unconditional summer short exposure,
  `QM5_20213`/`QM5_20214` are generic summer momentum/reversal, `QM5_41446` is a symmetric winter
  NR2 body fade, and `QM5_41456` is a winter NR2 CLV fade.
- G0 and execution contract: `APPROVED` for branch build and non-live pipeline only.

## Build Evidence

- PACER audit before compile enqueue: exit zero; `EA_FRAMEWORK_INPUT_PINNED` hit count zero.
- Reference tests: 10 passed.
- Compile work item: `30f44818-ac75-4fb4-97e2-06130d8066f2`, terminal claim T9.
- Compile: `COMPILE_OK`, zero errors, zero warnings.
- Strict build check: PASS with three nonfatal card-inference warnings.
- MQ5 SHA-256: `96bc38013512bf2f24aa9c33a20dff5825918c2fde5f16c1561d4315b1536bbf`.
- EX5 SHA-256: `74a78c846ea5398ba45230ee0f9d66a31916553e9e4889ab9c8f8f3bf3b7be95`.

## Q02 Handoff

The exact compile-bound dry run selected `XTIUSD.DWX` D1, verified the active magic row and the
fixed-risk setfile, and returned eligible. Five fresh whole-host CPU samples were 85.9%, 73.6%,
82.5%, 69.6%, and 69.1%; the maximum 85.9% was below the exclusive 97% ceiling.

The deterministic apply created work item `898e154f-f42d-4836-b0e2-e37ceb984e77`. T10 had
claimed the row at handoff. No manual backtest was run.

## Safety Boundary

No portfolio gate or T_Live/deploy manifest was touched. No terminal was controlled, AutoTrading
was not toggled, and no live/demo/shadow/stress/optimization artifact was created.
