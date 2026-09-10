# QM5_41425 WTI Refinery-Restart Negative-Week Reversion - Build And Q02 Handoff

Date: 2026-09-10

## Outcome

A new structural direct-WTI sleeve was source-approved, dedup-reviewed,
allocated, built, compiled, and handed to one paced Q02 row.

- Identity: QM5_41425 / `wti-refrestart-negweek-fade`
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `414250000`
- Signal: in April-May, buy after one strictly negative completed WTI week
  and exit at the next broker week
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen 3.5 ATR hard stop
- Compile work item: `4516a5b1-296f-4d60-ae2b-0169fe8b484f`
- Q02 work item: `e6c263cb-c853-4551-a95f-f90b91f82186`, pending

## Source And Non-Duplicate Boundary

The approved source record combines official U.S. Energy Information
Administration refinery-maintenance and pre-summer utilization context with
Yang-Goncu-Pantelous academic commodity-reversal lineage. Neither source
establishes this exact weekly long-only WTI CFD rule.

The canonical scan covered 4,905 registry rows and 1,515 repository cards,
found no exact identity, and surfaced two fuzzy family neighbors for manual
resolution. `QM5_41422` admits only a strictly positive week as continuation;
this card admits only a strictly negative week as reversion, making their entry
states mutually exclusive. `QM5_41392` trades XNG with a different calendar and
two-sided logic.

## Deterministic Build Evidence

- Card schema lint: PASS; prohibited-ML hits 0.
- Reference suite: 12/12 PASS.
- PACER input-pin audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- The locked guard compares only strategy inputs, `qm_ea_id`,
  `qm_magic_slot_offset`, and fixed-risk mode. RNG/news/Friday-close inputs are
  not equality-pinned; stress rejection is range/finiteness-only.
- Governed compile: `COMPILE_OK`, zero compiler errors/warnings, strict
  build-check PASS.
- MQ5 SHA-256:
  `fbe6ac4897206414f59c284927ded6e409f61b0e91ba3c7b03112c701b5e2bae`.
- EX5 SHA-256:
  `2de15c79e9a5fa62133fa611d6bb248c7dd1e7df825836beb23db311d3ceacca`.
- Required-symbol-bound Q02 setfile SHA-256:
  `7d43dcd706f4b4357abdb2c5d0888d3f5aa2b9ca5b54e05c3d7913e724864cdb`.

The governed setfile generator emitted a blank `strategy_symbol`; it was
restored to the approved `XTIUSD.DWX` binding after compile without changing
the MQ5 or EX5. The build-check's three warnings concern optional card
inferences and do not change its PASS verdict.

## Capacity Admission And Queue Result

The final five-sample whole-host CPU window was 47.27%, 51.47%, 60.26%,
72.97%, and 77.16%: average 61.83%, maximum 77.16%. Both remained strictly
below the binding 97% ceiling. The hash-bound first-Q02 dry run returned
`ELIGIBLE`; exactly one Q02 row was then enqueued. No manual tester or dispatch
command was run.

## Safety Boundary

No optimization, live/demo/shadow/stress preset, terminal control, AutoTrading,
`T_Live`, deploy/live manifest, portfolio gate, portfolio admission,
correlation waiver, or decorrelation claim was touched.
