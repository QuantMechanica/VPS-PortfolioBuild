# QM5_41429 WTI Refinery-Maintenance Weekly Close-Location Reversion - Build And Q02

Date: 2026-09-11

## Outcome

A new structural direct-WTI sleeve was source-approved, dedup-reviewed,
allocated, built, compiled, and admitted to one fixed-risk Q02 canary.

- Identity: QM5_41429 / `wti-refmaint-wclv-fade`
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `414290000`
- Signal: during February/March/September/October, sell after a positive two-
  week parent-close return whose newest completed week closes strictly in its
  upper tercile
- Exit: first processed tick of the next normalized broker week
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen 3.5 ATR hard stop
- Compile work item: `31aace23-ddf2-4237-8cab-4efe6372e5e7`, `COMPILE_OK`
- Q02 work item: `7a185f4e-ff2c-492d-925b-cba0b805f84e`, pending

## Source And Non-Duplicate Boundary

The source record combines committed complete-read official EIA refinery-
maintenance context with Yang-Goncu-Pantelous commodity-futures reversal
lineage. Neither source establishes this exact weekly WTI CFD rule.

The canonical scan covered 4,909 registry rows and 1,519 repository cards,
found no exact identity, and surfaced three fuzzy neighbors. `QM5_41427`
sells negative/lower-tercile continuation, a mutually exclusive state.
`QM5_41424` uses one week open-to-close without range confirmation, so gaps
can change the endpoint sign. `QM5_41428` trades April-July and buys a
negative/lower-tercile state.

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
  `f4bda38ab5585347da9e5a8d7457db982b3f0bac8628a355af06c0257e25755d`.
- EX5 SHA-256:
  `adb35e5d674d1a9c4b2125bfef38fa9ab6335a1a17f43ebd0739da0ef9fa90fa`.
- Q02-bound setfile SHA-256:
  `28851e34ae1bd85ddbc2a6eba025f15ee0af43de9e26b2eb7c83dff3d41ae27b`.

The build-check's three warnings concern optional card inferences and do not
change its PASS verdict.

## Capacity And Queue Admission

Five current whole-host CPU samples were 51%, 59%, 50%, 45%, and 45%:
average 50%, maximum 59%, below the exclusive 97% ceiling. The first Q02 apply
found the shared mutation lock actively held and made no change. After waiting
without touching the lock, the exact retry appended one pending Q02 row and
its receipt.

## Safety Boundary

No manual backtest, optimization, live/demo/shadow/stress preset, terminal
control, AutoTrading, `T_Live`, deploy/live manifest, portfolio gate,
portfolio admission, correlation waiver, or decorrelation claim was touched.
