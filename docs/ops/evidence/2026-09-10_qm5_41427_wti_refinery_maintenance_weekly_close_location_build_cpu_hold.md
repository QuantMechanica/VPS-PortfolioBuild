# QM5_41427 WTI Refinery-Maintenance Weekly Close-Location Continuation - Build And CPU Hold

Date: 2026-09-10

## Outcome

A new structural direct-WTI sleeve was source-approved, dedup-reviewed,
allocated, built, and compiled. Q02 was not enqueued because the binding
whole-host CPU admission ceiling was exceeded.

- Identity: QM5_41427 / `wti-refmaint-wclv-cont`
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `414270000`
- Signal: during February/March/September/October, sell when the newest
  completed WTI week has a negative parent-close return and closes strictly in
  its lower tercile
- Exit: first processed tick of the next normalized broker week
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen 3.5 ATR hard stop
- Compile work item: `6cb23d9a-5764-4445-9d4e-99d324e29009`, `COMPILE_OK`
- Q02 work item: none created

## Source And Non-Duplicate Boundary

The approved source record combines official U.S. Energy Information
Administration refinery-maintenance context with the peer-reviewed
Moskowitz-Ooi-Pedersen WTI momentum lineage. Neither source establishes this
exact weekly short-only WTI CFD conjunction.

The canonical scan covered 4,907 registry rows and 1,517 repository cards,
found no exact identity, and surfaced four fuzzy family neighbors for manual
resolution. `QM5_41421` uses one completed week's open-to-close sign without
range location. This build instead requires two adjacent completed week
packages, parent-close to newest-close continuation, and a strict lower-
tercile close. Opening gaps can make those return signs disagree. `QM5_41426`
is April-July positive/upper-tercile long; `QM5_41080` is year-round symmetric
outer-fifth; `QM5_41081` trades XNG.

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
  `ae41d20e10f5d7e959ef2b4e4bf87d0ccbd7b5075d8e6ecc570d7cd1cbc9a407`.
- EX5 SHA-256:
  `a1dd0a3f79eb79a454e3c223ce73063361b6f8de53c2748558634856613df6b3`.
- Required-symbol-bound setfile SHA-256 after build-hash binding:
  `bcc559efb24f896377a7acd84fa9abb6982e9ba634db513cc2f69e219c4e8723`.

The build-check's three warnings concern optional card inferences and do not
change its PASS verdict.

## Capacity Admission And Stop

The final five-sample whole-host CPU window was 98.83%, 98.73%, 97.85%,
99.12%, and 100.00%: average 98.91%, maximum 100.00%. Both the average and
maximum failed the exclusive 97% ceiling. Per the OWNER mission, processing
stopped here. No Q02 intake dry run or apply was executed, no Q02 row was
created, and no manual tester or dispatch command was run.

## Safety Boundary

No optimization, live/demo/shadow/stress preset, terminal control,
AutoTrading, `T_Live`, deploy/live manifest, portfolio gate, portfolio
admission, correlation waiver, or decorrelation claim was touched.
