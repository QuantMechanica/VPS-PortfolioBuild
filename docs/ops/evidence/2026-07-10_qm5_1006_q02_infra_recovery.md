# QM5_1006 Q02 Infrastructure Recovery - 2026-07-10

## Selection

`QM5_1006_davey-eu-day` was selected as a diversity recovery unit because it is an APPROVED, A-tier-book-sourced EURUSD H1 sleeve with no Q02 PASS, no downstream work item, and no active replacement. Its Q02 rows repeatedly ended `INFRA_FAIL` with `summary_missing_retries_exhausted` across multiple factory terminals.

Farm coordination was recorded against work item `0319aa4a-9ce2-4d35-85d9-e3d086d77636` by `codex:agents/board-advisor`. The pre-repair DB backup is `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1006_repair_20260710T063651Z.sqlite`.

## Diagnosis

The source compiled, but the current strict build gate failed before a clean Q02 handoff:

- both backtest setfiles lacked every canonical V5 header field and build hash;
- the EA defined a duplicate local `IsNewBar()` instead of using the framework gate;
- Davey's small, card-authorized closed-H1-bar windows were not marked as reviewed bespoke series access;
- adjacent `SPEC.md` and Strategy Card traceability were missing.

The diagnostic report is `D:/QM/reports/framework/21/build_check_20260710_063706.json`.

## Repair

- Replaced the local bar gate with `QM_IsNewBar()`.
- Kept Davey's entry, stop, target, and time parameters unchanged; added explicit `perf-allowed` rationale to the closed-bar reads.
- Added canonical `RISK_FIXED` backtest headers and regenerated build hashes on both existing setfiles.
- Added the required seven-section `SPEC.md` and an adjacent pointer to the canonical APPROVED card.
- Recompiled the `.ex5` against the current shared framework.

No backtest, T_Live access, AutoTrading action, portfolio-gate change, or deploy-manifest change was performed.

## Verification

- `framework/scripts/build_check.ps1 -EALabel QM5_1006_davey-eu-day`: PASS, 0 failures, 0 warnings. Evidence: `D:/QM/reports/framework/21/build_check_20260710_063924.json`.
- `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1006_davey-eu-day/QM5_1006_davey-eu-day.mq5 -Strict`: PASS, 0 errors, 0 warnings. Evidence: `D:/QM/reports/compile/20260710_063944/summary.csv`.
- `framework/scripts/validate_spec_doc.py framework/EAs/QM5_1006_davey-eu-day`: PASS.
- `tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_1006_davey-eu-day --fail-on-leak --json`: `SINGLE_SYMBOL_OK`, 0 violations.

The paced handoff is one fresh EURUSD.DWX Q02 work item. The factory queue owns execution; this recovery did not launch a manual smoke/backtest session.
