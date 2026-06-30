# QM5_12827 Entry Gate Repair And Q02 Queue Evidence

Date: 2026-06-30
Agent: codex:agents/board-advisor
EA: `QM5_12827_cme-gassilver-brk`
Task: `7cea71b0-64df-46d2-910f-8094c6ac2bbc`

## Scope

Repaired the Codex review blocker on the D1 XNG/XAG market-neutral basket. The prior reviewed build was blocked because entry gating used raw `iTime(_Symbol, PERIOD_D1, 0)` in `OnTick` instead of the framework new-bar primitive.

## Change

- Replaced the raw entry timestamp gate with `QM_IsNewBar(_Symbol, PERIOD_D1)`.
- Preserved the configured broker-time entry delay by arming `g_entry_check_pending` on each D1 new bar and consuming it once `Strategy_EntryTimeReady()` passes.
- Left exit/state refresh `iTime` usage unchanged; the failed review explicitly allowed cached D1 timestamps there.

## Verification

- `compile_one.ps1 -EAPath framework/EAs/QM5_12827_cme-gassilver-brk/QM5_12827_cme-gassilver-brk.mq5 -Strict`
  - Result: PASS
  - Errors: 0
  - Warnings: 0
  - Compile log: `C:/QM/repo/framework/build/compile/20260630_170536/QM5_12827_cme-gassilver-brk.compile.log`
- `build_check.ps1 -EALabel QM5_12827_cme-gassilver-brk`
  - Result: PASS
  - Failures: 0
  - Warnings: 16 framework advisory warnings in shared includes
  - Report: `D:/QM/reports/framework/21/build_check_20260630_170602.json`

## Farm Recording

Recorded build result: `D:/QM/strategy_farm/artifacts/builds/7cea71b0-64df-46d2-910f-8094c6ac2bbc.json`

`farmctl record-build` result:

- `recorded`: true
- `new_status`: done
- `smoke_result`: deferred_p2_smoke
- `auto_q02_enqueued.enqueued`: none
- `auto_q02_enqueued.skipped`: existing `Q02` pending work-item `0282fe25` for `QM5_12827_XNG_XAG_BRK_D1`

Current queue state:

- `QM5_12827_XNG_XAG_BRK_D1`
- Phase: `Q02`
- Status: pending
- Work item: `0282fe25-254e-47d1-9d63-7200b334f151`

No `T_Live`, AutoTrading, deploy manifest, or portfolio gate files were touched.
