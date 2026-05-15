## QUA-1573 P0 Build Report

- EA: `QM5_SRC04_S18_lien_fade_00_asia`
- Commit: `ea9d14e19`
- Strategy Card: `QUA-1568` (`strategy-seeds/cards/lien-fade-00-asia_card.md`)

### Build Artifact

- EX5: `framework/EAs/QM5_SRC04_S18_lien_fade_00_asia/QM5_SRC04_S18_lien_fade_00_asia.ex5`
- Size (bytes): `101654`
- SHA256: `84E67E17F54BB21C5E26D7E13930A335FC7D01C6557602943370D42FAA5EAB66`
- LastWriteTimeUtc: `2026-05-15T08:53:09Z`

### Verification

- Command: `./framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_SRC04_S18_lien_fade_00_asia/QM5_SRC04_S18_lien_fade_00_asia.mq5 -Strict`
- Result: `PASS`
- Errors: `0`
- Warnings: `0`
- Compile log: `framework/build/compile/20260515_085522/QM5_SRC04_S18_lien_fade_00_asia.compile.log`

### Dispatch Step 6 Status

- Required script `deploy_ea_to_all_terminals.ps1` was not found in this workspace.
- Checked paths: `framework/scripts`, `infra/scripts` (and filename grep under both trees).
- Additional full-workspace search for deploy-script aliases and docs references found no executable replacement procedure for EA deployment to T1-T5.
- Current state: deployment step blocked pending script location/provision from CTO/DevOps owner.

### Dispatch Step 4 Status (`build_check.ps1`)

- `framework/scripts/build_check.ps1` currently has no per-EA scope option and compiles all `framework/EAs/**/*.mq5`.
- In this workspace snapshot, unrelated EA outputs/setfiles are already modified outside `QM5_SRC04_S18_lien_fade_00_asia`.
- Result: full repository `build_check.ps1` cannot be used as an issue-local acceptance proof for QUA-1573 without cross-issue contamination risk.
- Unblock owner/action: CTO to approve one of:
  - run full-repo `build_check.ps1` in a clean coordinated baseline window, or
  - provide/approve a scoped build-check path for single-EA dispatch validation.
