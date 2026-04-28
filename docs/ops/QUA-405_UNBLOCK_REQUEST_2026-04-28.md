# QUA-405 Unblock Request - CEO/CTO Action Required

Date: 2026-04-28
Issue: QUA-405
Strategy: `SRC04_S06` (`lien-fader`)
Source card issue: `QUA-345`

## Request

Development cannot start EA implementation because governance prerequisites are not satisfied. Please complete the unblock actions below and re-dispatch QUA-405.

## Required Actions (Blocking Owners)

Owner: CEO
1. Approve Strategy Card `SRC04_S06` (`lien-fader`) from `DRAFT` -> `APPROVED`.

Owner: CTO
2. Allocate `ea_id` for `slug=lien-fader`, `strategy_id=SRC04_S06` in `framework/registry/ea_id_registry.csv`.
3. Ensure the approved card and registry row are synced into `C:\QM\worktrees\development`.
4. Re-dispatch Development on QUA-405 after sync.

## Current Evidence

- Card present but not approved:
  - `C:\QM\repo\strategy-seeds\cards\lien-fader_card.md`
  - Header: `strategy_id: SRC04_S06`, `ea_id: TBD`, `status: DRAFT`
- Card missing in assigned checkout:
  - `C:\QM\worktrees\development\strategy-seeds\cards\lien-fader_card.md` (absent)
- Registry allocation missing:
  - `C:\QM\worktrees\development\framework\registry\ea_id_registry.csv`
  - `C:\QM\repo\framework\registry\ea_id_registry.csv`

## Development Immediate Next Step After Unblock

Implement:
- `framework/EAs/QM5_<ea_id>_lien_fader/QM5_<ea_id>_lien_fader.mq5`

Conformance targets:
- V5 framework include + 4-module strategy boundary
- `QM_Magic(ea_id, slot)` usage only
- Inputs include both `RISK_FIXED` and `RISK_PERCENT`
- Friday close default-enabled
- No hardcoded symbol
- Card section/page citation comments in non-obvious rule blocks
- Compile clean; submit to CTO review gate (no Pipeline-Operator dispatch)
