# QM5_11078 RSIOMA closed-bar hot-path repair — 2026-08-16

## Router binding

- Agent task: `d7d81b1f-8e1b-4f37-8b6b-71706cabc7ec`
- Assigned agent: `codex`
- Priority: `68`
- Review disposition: `REVIEW`
- Implementation commit on `agents/board-advisor`: `5f959fae1`

## Defect and repair

`Strategy_ExitSignal()` recomputed the full RSIOMA EMA history on every tick
while a position was open. The same computation also ran in the entry path.
That made the EA symbol-data dependent and produced repeated Q02 active
timeouts on EURUSD/USDCAD even though USDJPY had completed.

The repair moves `Strategy_UpdateRsiomaState()` behind the existing H4
`QM_IsNewBar()` boundary in `OnTick()`, executes it once for each completed bar,
and lets both exit and entry decisions reuse that state. The threshold,
crossing, lookback, and position-management decisions are unchanged at
closed-bar boundaries.

Changed artifacts:

- `framework/EAs/QM5_11078_rsioma-reversal/QM5_11078_rsioma-reversal.mq5`
- `framework/EAs/QM5_11078_rsioma-reversal/QM5_11078_rsioma-reversal.ex5`
- `framework/EAs/QM5_11078_rsioma-reversal/SPEC.md`
- Four H4 backtest sets for EURUSD, GBPUSD, USDCAD, and USDJPY

The setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`. The build guard
also required the previously implicit default session to be explicit, so each
set now contains `strategy_start_hour=0` and `strategy_end_hour=24`. No stale
news threshold was weakened; the validated maximum remains 336 hours.

## Verification

- Build guardrails: PASS, five files, zero findings.
- MetaEditor strict compile: PASS, `0 errors, 0 warnings`.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260816_005959\QM5_11078_rsioma-reversal.compile.log`
  (SHA-256 `c53c44f965df1feef96d1f0ef6e0ef77861289d6d68085ee45df7233f713fd8e`).
- Framework build check with the compiled binary: PASS, zero failures and zero
  warnings. Report:
  `D:\QM\reports\framework\21\build_check_20260816_010425.json`
  (SHA-256 `69936d2a84e02ddf36058cea391d066cd9f17638bb9414b342c59e9231af54d5`).
- SPEC validation: PASS.
- Static structural assertions: PASS. Entry and exit no longer call the update
  function; `OnTick()` calls it exactly once after the new-bar gate.
- Current MQ5 SHA-256:
  `825d721879f2aead7c1c66899afae568e6dc1994f708e62329cd1b762dae64c0`.
- Current EX5 SHA-256:
  `9afea2a339a2c380a82dadb54cc40e6c23011599e30c53d3a679b0822330485d`.
- EURUSD setfile SHA-256:
  `d1346fd589178209ed3e424143766ee6375ddfa69ceab7d593d9332250b8c72b`.
- USDCAD setfile SHA-256:
  `9ad6dd21308f0a4d042a73b03cbcb4ef85185b77312380fbc6e9ecc1cb87189b`.

## Append-only Q02 reseed

The terminal source row
`562f8bf4-88c6-400f-9a6f-90e3a18462a5` was preserved. It is the EURUSD H4
`INFRA_FAIL`/`ACTIVE_TIMEOUT` row from `2026-08-16T00:38:53Z`, bound to the
prior EX5 SHA-256
`4598106a5015e78b28f4283536ae1041a7de74529eefb27c09a8907e8ff3c676`.
Its runner log was authenticated and hash-bound as rerun evidence (SHA-256
`325b886b56b8aba944953237651ce0aa84627190160e168d31301b8ada623960`).

The governed exact-row enqueue created Q02 work item
`aa23aaed-0933-4f0a-b109-8b82096b8a55`. At creation it was `pending`, carried
`append_only_rerun_of_work_item=562f8bf4-88c6-400f-9a6f-90e3a18462a5`, and
bound the current EX5, MQ5, and EURUSD setfile hashes above. Its payload also
records `risk_fixed=1000`, `risk_percent=0`, and PASS admission against active
Custom-history manifest
`fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`.

No pipeline verdict is asserted here. The new Q02 result remains pipeline-owned.
