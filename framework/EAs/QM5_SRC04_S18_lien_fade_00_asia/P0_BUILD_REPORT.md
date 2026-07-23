## QUA-1573 P0 Build Report

- EA: `QM5_SRC04_S18_lien_fade_00_asia`
- Commit: `ea9d14e19`
- Strategy Card: `QUA-1568` (`strategy-seeds/cards/lien-fade-00-asia_card.md`)

### Build Artifact (Latest)

- EX5: `framework/EAs/QM5_SRC04_S18_lien_fade_00_asia/QM5_SRC04_S18_lien_fade_00_asia.ex5`
- Size (bytes): `101250`
- SHA256: `061DF6E577042DAC2DEE8C10D31187CDC60DE414C352388C27DB407E7D69D410`
- LastWriteTimeUtc: `2026-05-15T12:08:02Z`

### Verification

- Command: `./framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_SRC04_S18_lien_fade_00_asia/QM5_SRC04_S18_lien_fade_00_asia.mq5 -Strict`
- Result: `PASS`
- Errors: `0`
- Warnings: `0`
- Compile log: `framework/build/compile/20260515_085522/QM5_SRC04_S18_lien_fade_00_asia.compile.log`

### Dispatch Step 6 Status (Deployment to T1-T5)

- Deployment script used: `C:/QM/repo/framework/scripts/deploy_ea_to_all_terminals.ps1`
- Command executed:
  - `powershell -ExecutionPolicy Bypass -File C:/QM/repo/framework/scripts/deploy_ea_to_all_terminals.ps1 -EaPath C:/QM/worktrees/development/framework/EAs/QM5_SRC04_S18_lien_fade_00_asia/QM5_SRC04_S18_lien_fade_00_asia.ex5 -EvidenceJsonPath C:/QM/worktrees/development/framework/EAs/QM5_SRC04_S18_lien_fade_00_asia/deploy_evidence_t1_t5.json`
- Result: `PASS` on T1, T2, T3, T4, T5
- Destination hash on all terminals: `061DF6E577042DAC2DEE8C10D31187CDC60DE414C352388C27DB407E7D69D410`
- Evidence JSON: `framework/EAs/QM5_SRC04_S18_lien_fade_00_asia/deploy_evidence_t1_t5.json`

### Dispatch Step 4 Status (`build_check.ps1`)

- `framework/scripts/build_check.ps1` currently has no per-EA scope option and compiles all `framework/EAs/**/*.mq5`.
- In this workspace snapshot, unrelated EA outputs/setfiles are already modified outside `QM5_SRC04_S18_lien_fade_00_asia`.
- Result: full repository `build_check.ps1` cannot be used as an issue-local acceptance proof for QUA-1573 without cross-issue contamination risk.
- Unblock owner/action: CTO to approve one of:
  - run full-repo `build_check.ps1` in a clean coordinated baseline window, or
  - provide/approve a scoped build-check path for single-EA dispatch validation.

### Ghost-Build Recheck (2026-05-15T12:07Z)

- Board verifier command referenced in comment:
  - `python framework/scripts/verify_build_deployment.py --ea-id 1042 --ea-dir-glob "*lien*fade*00*asia*"`
- Result in this worktree: script path does not exist (`framework/scripts/verify_build_deployment.py` missing), command cannot be executed here.
- Direct artifact evidence in this worktree:
  - EA directory exists: `framework/EAs/QM5_SRC04_S18_lien_fade_00_asia`
  - EX5 exists: `framework/EAs/QM5_SRC04_S18_lien_fade_00_asia/QM5_SRC04_S18_lien_fade_00_asia.ex5`
  - Size (bytes): `102040` (> 50 KB gate)
  - SHA256: `726ACF75234FBD2FAF95076EFC1A7B2D2D94FCFDCFC8F1FAE93532B913681F22`
  - LastWriteTimeUtc: `2026-05-15T11:26:23Z`
- Fresh compile proof:
  - Command: `powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_SRC04_S18_lien_fade_00_asia/QM5_SRC04_S18_lien_fade_00_asia.mq5`
  - Result: `PASS` (`0` errors, `0` warnings)
  - Compile log: `framework/build/compile/20260515_120713/QM5_SRC04_S18_lien_fade_00_asia.compile.log`

### Verifier Status (Current)

- Command: `python framework/scripts/verify_build_deployment.py --ea-id 1042 --ea-dir-glob "*lien*fade*00*asia*"`
- Result: `PASS`
- Checks:
  - `ea_dir_exists=true`
  - `ex5_exists=true`
  - `ex5_size_gt_min=true`
