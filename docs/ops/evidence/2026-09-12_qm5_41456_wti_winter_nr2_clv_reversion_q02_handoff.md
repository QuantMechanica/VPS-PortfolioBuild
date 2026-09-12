# QM5_41456 WTI Winter NR2 Close-Location Reversion — Q01 PASS / Q02 Handoff

Date: 2026-09-12  
Branch: `agents/board-advisor`  
EA: `QM5_41456_wti-winter-nr2-clv-fade`

## Outcome

One new structural low-frequency energy EA was researched, approved, allocated, built, compiled,
and handed to Q02. During the peer-reviewed November-May WTI regime it requires a strict
two-completed-week range contraction, then fades only an outer-quartile newest-week close and
holds through the next week boundary. It is a directional WTI hypothesis, not a decorrelation
claim; unchanged Q09 alone owns the portfolio-correlation conclusion.

## Research And Identity

- Reputable lineage: Burakov, Freidin, and Solovyev (2018) for the WTI November-May regime;
  Yang, Goncu, and Pantelous for commodity-reversal lineage; governed Crabel range-state and
  completed-week construction.
- Canonical scan: no exact identity across 4,937 registry rows and 1,546 repository cards; the
  unavailable external Strategy Wiki root and five fuzzy family matches were recorded.
- Distinct boundary: `QM5_41442` is expansion/CLV fade, `QM5_41447` is contraction/upper-CLV
  continuation, and `QM5_41446` is contraction/body fade. `QM5_41456` alone combines strict
  contraction with symmetric outer-quartile CLV reversion on WTI in November-May.
- G0 and execution contract: `APPROVED` for branch build and non-live pipeline only.

## Build Evidence

- PACER audit before compile enqueue: exit zero; `EA_FRAMEWORK_INPUT_PINNED` hit count zero.
- Reference tests: 12 passed.
- Compile work item: `592cfacb-3683-45e5-aae8-0f524eb05223`, terminal claim T5.
- Compile: `COMPILE_OK`, zero errors, zero warnings.
- Strict build check: PASS with three nonfatal card-inference warnings.
- MQ5 SHA-256: `fb3d0f77eca25813ffb577c2def0d517ebe8af8a4d030f72c7fcb5ed663aa52a`.
- EX5 SHA-256: `dc991dade392ebb6e1679a84b62cb2e8de392785df1d4ae8aa84552048adb531`.

## Q02 Handoff

The exact compile-bound dry run selected `XTIUSD.DWX` D1, verified the active magic row and the
fixed-risk setfile, and returned eligible. Five fresh whole-host CPU samples were 89.2%, 90.8%,
84.9%, 88.9%, and 84.3%; the maximum 90.8% was below the exclusive 97% ceiling.

The deterministic apply created work item `39ecd610-2e9c-4b80-b7a4-f0da802ce21d`. T6 had claimed
the row at handoff. No manual backtest was run.

## Safety Boundary

No portfolio gate or T_Live/deploy manifest was touched. No terminal was controlled, AutoTrading
was not toggled, and no live/demo/shadow/stress/optimization artifact was created.
