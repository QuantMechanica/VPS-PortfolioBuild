# QM5_41426 WTI Refinery-Ramp Weekly Close-Location Continuation - Build And Q02 Handoff

Date: 2026-09-10

## Outcome

A new structural direct-WTI sleeve was source-approved, dedup-reviewed,
allocated, built, compiled, and handed to one paced Q02 row.

- Identity: QM5_41426 / `wti-reframp-wclv-cont`
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `414260000`
- Signal: during April-July, buy when the newest completed WTI week has a
  positive parent-close return and closes strictly in its upper tercile
- Exit: first processed tick of the next normalized broker week
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen 3.5 ATR hard stop
- Compile work item: `aa47bbdd-7e86-4cb1-bcef-40487423dec0`
- Q02 work item: `2ad0e7b6-fe21-4ce6-8bf9-4a501cc6b6ce`, pending

## Source And Non-Duplicate Boundary

The approved source record combines official U.S. Energy Information
Administration refinery-maintenance and utilization-ramp context with the
peer-reviewed Moskowitz-Ooi-Pedersen WTI momentum lineage. Neither source
establishes this exact weekly long-only WTI CFD conjunction.

The canonical scan covered 4,906 registry rows and 1,516 repository cards,
found no exact identity, and surfaced three fuzzy family neighbors for manual
resolution. `QM5_41080` is year-round and symmetric with outer-fifth close
locations; `QM5_41081` trades XNG; `QM5_41422` uses a one-week open-to-close
sign only in April-May. This build instead requires two adjacent completed
week packages, parent-close to newest-close continuation, a strict upper-
tercile close, and an April-July ramp calendar. Opening gaps can make the
`QM5_41422` and `QM5_41426` return signs disagree.

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
  `b6a4a943b9d9bfd5010a9fd5b08c67424e9c30670c50f374870c4c8d244f83b4`.
- EX5 SHA-256:
  `51aef8c3665f7487d7c1d4f601185e6e57e897c6b9fcb29298f84a21f1029550`.
- Required-symbol-bound Q02 setfile SHA-256:
  `14d661493f68981ea98c42634617f765b0559730ce85761a7e6051c23accb7f9`.

The build-check's three warnings concern optional card inferences and do not
change its PASS verdict.

## Capacity Admission And Queue Result

The final five-sample whole-host CPU window was 70.48%, 74.01%, 74.17%,
66.02%, and 60.61%: average 69.06%, maximum 74.17%. Both remained strictly
below the binding 97% ceiling. The hash-bound first-Q02 dry run returned
`ELIGIBLE`; exactly one Q02 row was then enqueued and confirmed pending. No
manual tester or dispatch command was run.

## Safety Boundary

No optimization, live/demo/shadow/stress preset, terminal control, AutoTrading,
`T_Live`, deploy/live manifest, portfolio gate, portfolio admission,
correlation waiver, or decorrelation claim was touched.
