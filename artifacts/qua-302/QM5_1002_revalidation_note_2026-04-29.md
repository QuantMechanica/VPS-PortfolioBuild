# QUA-302 Revalidation Note (2026-04-29)

EA: framework/EAs/QM5_1002_davey-eu-night/QM5_1002_davey-eu-night.mq5
Card: strategy-seeds/cards/davey-eu-night_card.md (SRC01_S01)

## Delta Applied
- Enforced explicit hard-rule magic resolution via `QM_Magic(ea_id, magic_slot_offset)`.
- Kept framework-driven risk/news/friday/kill-switch flow and module structure unchanged.

## Compile Evidence
- Command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1002_davey-eu-night/QM5_1002_davey-eu-night.mq5`
- Result: PASS
- Errors: 0
- Warnings: 0
- Summary: `D:/QM/reports/compile/20260429_000511/summary.csv`
- Log: `C:/QM/worktrees/cto/framework/build/compile/20260429_000511/QM5_1002_davey-eu-night.compile.log`
