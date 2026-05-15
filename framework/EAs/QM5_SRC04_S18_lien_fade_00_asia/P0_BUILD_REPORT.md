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
- Current state: deployment step blocked pending script location/provision from CTO/DevOps owner.
