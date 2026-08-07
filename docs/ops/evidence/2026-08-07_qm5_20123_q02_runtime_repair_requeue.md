# QM5_20123 Q02 runtime repair and requeue — 2026-08-07

## Outcome

`QM5_20123_dailyopen-h1-basket` is a diverse, structural EURUSD/GBPUSD H1
basket that was built but repeatedly failed to clear Q02 for infrastructure
reasons. Its entry mechanics, fixed-risk sizing, stops, targets, basket
membership, and session rules were preserved. The per-tick runtime hot path was
removed, the EA was rebuilt with strict checks, and the exact repaired binary is
ready for a paced Q02 handoff.

- Repair claim: `c6b0f704-98ee-47ae-a982-c976e9d026d7`
- Legacy build task: `7cc896a1-d2b7-4ad6-a945-f71021c10d4d`
- Claim key: `manual:codex:agents/board-advisor:QM5_20123:q02-infra-repair:20260807T002048Z`
- Pre-claim database backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20123_repair_claim_20260807T002048Z.sqlite`
- Pre-record database backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20123_build_record_20260807T003552Z.sqlite`
- Build-result SHA-256:
  `896de94c9788e1f0ad8cc7d93d9fd3feffb7fa076641e4aadee0d9fa7257df83`
- Q02 work item: `a94a08d9-1b44-4e62-88d9-2e40fb8e7283`

No untouched approved diverse card simultaneously had a complete EA allocation,
complete magic-number allocation, exact `.DWX` coverage, and no existing build
or task. This made the mission's priority-2 recovery path the highest valid unit
of work.

## Failure evidence and diagnosis

The farm database contained 12 historical Q02 rows for `QM5_20123`; all 12 were
`INFRA_FAIL`, with no economic verdict. Nine ended as `ACTIVE_TIMEOUT` after
their full real-tick stage and three ended as transient cold-cache `NO_HISTORY`.
The failed rows were append-only and remain unchanged.

The failed cohort used stable artifacts throughout:

- MQ5 SHA-256:
  `dfc42c8c45df1555e2540ca9fe0439e53c25db1b0b2957ef01911a65d763936b`
- EX5 SHA-256:
  `f12468e513193d8ac90a39efe597beff6888f65bcce24fa061ad30c2f44feaaf`
- setfile SHA-256:
  `569a9c9328749cbc5b8b25ce45a00cfb5a2e3856c826d5ba9bcc030254ab4b7d`

This rules out stale-EX5 drift as the recurring cause. The cold-cache summaries
also recorded no OnInit failure. More importantly, the T3 tester log at
`D:\QM\mt5\T3\Tester\logs\20260806.log` records a completed six-month run:
EURUSD and GBPUSD synchronized, real orders were placed, 44,880,273 ticks were
processed, and the test completed in 27:07. That establishes strategy aliveness
and classifies the isolated `NO_HISTORY` results as transient infrastructure.

The deterministic runtime defect was in the EA lifecycle. The framework calls
`Strategy_NoTradeFilter()` on every real tick before its closed-bar gate. The EA
performed four cross-symbol `SeriesInfoInteger` reads there (H1 and D1 for two
members) and repeatedly scanned positions while flat. On the observed
44.9-million-tick six-month workload, the history checks alone imply about
179.5 million redundant cross-symbol queries. This is consistent with the
multi-terminal full-run timeout pattern and is the repaired hot path.

## Repair

- Moved entry-only member trade-mode and H1/D1 history readiness checks into
  `Strategy_EntrySignal()`, which the framework reaches only after the H1
  closed-bar gate.
- Added zero-position fast paths to basket membership lookup and per-tick open
  position management.
- Reset the close retry latch only when the global position table is empty,
  preserving one-leg-remainder management.
- Added static regression coverage that keeps cross-symbol history reads out of
  `Strategy_NoTradeFilter()` and retains both flat-position fast paths.

The approved daily-open signal, EURUSD/GBPUSD coupling, 10-pip SL/TP, basket
close, news/Friday controls, and risk model were not changed.

## Exact repaired artifacts

- MQ5 SHA-256:
  `8fd328deaaa61eca2d57546f5f36c2a0cb0296d236fb790b2aa492e4687b334f`
- EX5 SHA-256:
  `f096b2ea33aed6ec3612f051363f58bc19ff75135149c401b2974770f273304d`
- RISK_FIXED setfile SHA-256:
  `3c6ab112ed59c95199f6e211fab5e1992a6e6fe62a6a78859d44b142381ff8e4`
- Setfile invariant: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- The active pump deterministically committed the rebuilt EX5 and setfile in
  `c7acb737aada0312f432a95264f42df9cf08f785` while the repair was being
  verified. The source repair is committed separately with this evidence.

## Verification

- `validate_spec_doc.py`: PASS (1/1)
- `validate_build_guardrails.py`: PASS (2 files, no findings)
- strict `build_check.ps1`: PASS, MetaEditor 0 errors / 0 warnings, build check
  0 failures / 0 warnings
- compile log:
  `C:\QM\repo\framework\build\compile\20260807_002635\QM5_20123_dailyopen-h1-basket.compile.log`
- compile summary: `D:\QM\reports\compile\20260807_002635\summary.csv`
- build report:
  `D:\QM\reports\framework\21\build_check_20260807_002634.json`
- `pytest tools/strategy_farm/tests/test_basket_order_helper_static.py -q`:
  12 passed, 2 subtests passed

No manual backtest was launched. Q02 is the CPU-bearing validation, so the
result is deliberately `deferred_p2_smoke`; this repair is compile- and
static-verified, not yet runtime-certified.

## Safety and handoff

Immediately before the handoff, four managed tester terminals were active
(`T1`, `T3`, `T6`, `T8`), below the seven-test CPU ceiling. `FACTORY_OFF.flag`
was absent. The live terminal was observed read-only and excluded from the
managed count.

`record-build` completed the legacy build task and enqueued exactly one Q02
row, with no skip or duplicate. The paced worker claimed attempt 0 on `T10`,
making it the fifth managed test. Its sealed payload binds the exact MQ5, EX5,
and setfile hashes above and starts with the governed six-month H1 prescreen.
The repair ticket is now `PIPELINE`; Q02 remains the runtime authority.

No T_Live files or processes, AutoTrading setting, portfolio gate, or live
manifest were changed.
