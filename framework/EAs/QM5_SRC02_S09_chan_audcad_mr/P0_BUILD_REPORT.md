# P0 Build Report - QUA-1572

- Strategy: SRC02_S09 (chan-audcad-mr)
- EA: QM5_SRC02_S09_chan_audcad_mr
- Build time (UTC): 2026-05-15T11:28:11.5302546Z

## Compile

- Command: framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_SRC02_S09_chan_audcad_mr/QM5_SRC02_S09_chan_audcad_mr.mq5 -Strict
- Result: PASS
- Errors: 0
- Warnings: 0

## Artifact

- File: framework/EAs/QM5_SRC02_S09_chan_audcad_mr/QM5_SRC02_S09_chan_audcad_mr.ex5
- Size (bytes): 97156
- SHA256: 50E4DCE888778ED872F92AEBAF9EB34E40D0156A42871EC3A8A5A73D5D719D2C

## Deployment (T1-T5)

- Script: C:/QM/repo/framework/scripts/deploy_ea_to_all_terminals.ps1
- Deployed at local: 05/15/2026 13:28:52
- Hash match: true on all terminals

Evidence JSON:
- framework/EAs/QM5_SRC02_S09_chan_audcad_mr/deploy_evidence.json

## Notes

- framework/scripts/build_check.ps1 (repo-wide) remains FAIL from unrelated pre-existing files in this worktree.
- Target EA compiles strict cleanly and is deployed with matching hash across T1-T5.
