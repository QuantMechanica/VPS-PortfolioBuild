# QUA-177 - Step 25 Quality-Tech Framework Review Handoff (2026-04-27)

Status: REJECT (framework not yet ready for first V5 strategy EA build)
Reviewer: CTO (agent `241ccf3c-ab68-40d6-b8eb-e03917795878`)
Scope: `framework/` implementation against `framework/V5_FRAMEWORK_DESIGN.md` Implementation Order step 25.

## Evidence

- Build gate run: `framework/scripts/build_check.ps1 -RepoRoot C:\QM\repo` at 2026-04-27 11:35 UTC.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260427_113512.json` (`status: FAIL`).
- Compile log: `C:\QM\repo\framework\build\compile\20260427_113512\EA_Skeleton.compile.log` (`0 errors, 19 warnings`).
- Design step reference: `framework/V5_FRAMEWORK_DESIGN.md:756` and `framework/V5_FRAMEWORK_DESIGN.md:784`.

## Hard-Rule Snapshot

- [x] Model 4 enforced in smoke harness (`framework/scripts/run_smoke.ps1:18-19`).
- [x] `RISK_FIXED` + `RISK_PERCENT` inputs present in skeleton (`framework/templates/EA_Skeleton.mq5:12-13`).
- [x] Friday Close default enabled (`framework/templates/EA_Skeleton.mq5:20-21`, `framework/include/QM/QM_Common.mqh:115-129`).
- [x] Magic formula enforced in build check (`framework/scripts/build_check.ps1:259`).
- [x] External API + ML import scans present (`framework/scripts/build_check.ps1:512-517`).
- [ ] Compile clean (0 warnings required by review discipline) - FAILED (`EA_Skeleton.compile.log:99`, `build_check_20260427_113512.json`).
- [ ] 4-module boundary complete (No-Trade / Entry / Management / Close) - FAILED (findings #2).
- [ ] Risk ENV enforcement complete (backtest fixed, live/demo/shadow percent) - FAILED (finding #3).

## Findings (ordered by severity)

1. Critical - compile gate not clean (warnings present)
- Evidence:
  - `D:\QM\reports\framework\21\build_check_20260427_113512.json` includes `BUILD_CHECK_STRICT_WARNINGS` failure.
  - `C:\QM\repo\framework\build\compile\20260427_113512\EA_Skeleton.compile.log:99` reports `0 errors, 19 warnings`.
- Violated rule:
  - CTO review checklist requires `Compile check: no warnings` before approval.

2. Critical - 4-module modularity is not fully wired at framework boundary
- Spec requirement:
  - `framework/V5_FRAMEWORK_DESIGN.md:49-53` requires explicit No-Trade / Trade Entry / Trade Management / Trade Close module structure, including `QM_NoTrade.mqh` orchestrator.
- Implementation gap:
  - `framework/include/QM/QM_Common.mqh:6-17` does not include `QM_TradeManagement.mqh` and there is no `QM_NoTrade.mqh` in `framework/include/QM/`.
  - `framework/templates/EA_Skeleton.mq5:48-58` only performs kill-switch/news/friday checks and then a TODO; no explicit management/close module hook call path.
- Violated rule:
  - Hard Rule: "4-Module Modularity per V5".

3. High - Risk ENV enforcement from design is incomplete
- Spec requirement:
  - `framework/V5_FRAMEWORK_DESIGN.md:27` and `framework/V5_FRAMEWORK_DESIGN.md:235-249` require ENV-driven risk-mode validation with hard fail `EA_INPUT_RISK_MODE_MISMATCH`.
- Implementation gap:
  - `framework/include/QM/QM_Common.mqh:34-46` validates only both-zero/both-set and does not parse set-file ENV or enforce ENV-to-mode mapping.
  - `EA_INPUT_RISK_MODE_MISMATCH` constant exists (`framework/include/QM/QM_Errors.mqh:8`) but is not enforced in flow.
- Violated rule:
  - Hard Rule: fixed risk for backtest, percent risk for live (ENV-enforced).

4. Medium - Framework script surface deviates from design contract without ADR note
- Spec requirement:
  - Design lists dedicated `compile_all.ps1` and `validate_setfile.ps1` scripts (`framework/V5_FRAMEWORK_DESIGN.md:134`, `framework/V5_FRAMEWORK_DESIGN.md:137`, `framework/V5_FRAMEWORK_DESIGN.md:711-739`).
- Implementation gap:
  - `framework/scripts/` currently has `brand_report.ps1`, `build_check.ps1`, `compile_one.ps1`, `run_smoke.ps1`, `sync_brand_tokens.ps1`; no `compile_all.ps1` or standalone `validate_setfile.ps1`.
- Impact:
  - Build-check performs set validation internally, but the explicit interface promised in design is missing and undocumented.

## Gate Decision

- Step 25 handoff verdict: REJECT.
- First V5 strategy EA build must remain blocked until findings #1-#3 are fixed and re-verified.
- Minimal unblock evidence required:
  1. `build_check.ps1` PASS with `0 errors, 0 warnings`.
  2. Explicit 4-module boundary implementation wired in framework + skeleton.
  3. ENV risk-mode mismatch enforcement implemented and tested (`EA_INPUT_RISK_MODE_MISMATCH` path).
