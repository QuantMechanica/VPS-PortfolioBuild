# QM5_41428 WTI Refinery-Ramp Weekly Close-Location Reversion - Build And Q02

Date: 2026-09-10

## Outcome

A new structural direct-WTI sleeve was source-approved, dedup-reviewed,
allocated, built, compiled, and admitted to one fixed-risk Q02 canary.

- Identity: QM5_41428 / `wti-reframp-wclv-fade`
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `414280000`
- Signal: during April-July, buy after a negative two-week parent-close return
  whose newest completed week closes strictly in its lower tercile
- Exit: first processed tick of the next normalized broker week
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, frozen 3.5 ATR hard stop
- Compile work item: `acf9dfe5-606c-460c-aceb-624b832e64a1`, `COMPILE_OK`
- Q02 work item: `2edd794c-cb9e-4ed5-827a-d67223c8bd02`, pending

## Source And Non-Duplicate Boundary

The source record combines committed complete-read official EIA refinery-ramp
context with the Yang-Goncu-Pantelous commodity-futures reversal lineage.
Fresh generic URL routing returned `DEFERRED:SOURCE_POLICY`, so no blocked page
text was used. Neither source establishes this exact weekly WTI CFD rule.

The canonical scan covered 4,908 registry rows and 1,518 repository cards,
found no exact identity, and surfaced only `QM5_41426` as a fuzzy neighbor.
That EA buys positive/upper-tercile states as continuation; this one buys
negative/lower-tercile states as reversion, so their admitted states are
mutually exclusive. `QM5_41425` is April-May and uses one week open-to-close
without range confirmation; opening gaps can make its sign disagree.

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
  `210dbf42624570c4bd948813e6f55a88b43f301aabfc51e7a865b921d53da82c`.
- EX5 SHA-256:
  `7475afb0a0c61cb3be916ef0a3c914a0a59b72ffc75cc58e8550bd0485c5df35`.
- Q02-bound setfile SHA-256:
  `e211604ecb311893c3298f436f461ac9fe3a96471c9a807467d1f2afac0e8fb4`.

The build-check's three warnings concern optional card inferences and do not
change its PASS verdict.

## Capacity And Queue Admission

Five current whole-host CPU samples were 56.25%, 87.14%, 75.59%, 61.62%, and
62.02%: average 68.52%, maximum 87.14%, below the exclusive 97% ceiling. The
first Q02 apply found the shared mutation lock actively held and made no
change. After waiting without touching the lock, the exact retry appended one
pending Q02 row and its receipt.

## Safety Boundary

No optimization, live/demo/shadow/stress preset, terminal control,
AutoTrading, `T_Live`, deploy/live manifest, portfolio gate, portfolio
admission, correlation waiver, or decorrelation claim was touched.
