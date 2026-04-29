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

## Hard-Rule Checklist (Final)
- `QM_Common.mqh` included: PASS
- 4-module strategy functions present (`Strategy_EntrySignal`, `Strategy_ManageOpenPosition`, `Strategy_ExitSignal`): PASS
- Magic via `QM_Magic(ea_id, slot)`: PASS
- `RISK_FIXED` + `RISK_PERCENT` inputs present: PASS
- Friday close input + framework handling enabled by default: PASS
- No hardcoded symbol (uses `_Symbol`): PASS
- No external API calls: PASS
- No ML imports: PASS
- Required input groups present: PASS

## Close-out (DL-026)
- Final revalidation commit hash: `b2de2a3f`
- Prior changeset in same issue: `d10cd657`
