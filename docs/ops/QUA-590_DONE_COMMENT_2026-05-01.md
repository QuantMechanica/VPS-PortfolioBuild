QUA-590 closeout complete.

Delivered:
- Removed root 0-byte garbage artifacts (`Append-only`, `Authoritative`, `agents,`, `hourly-public`) from workspace.
- Added commit-path untracked/zero-byte guards in `infra/scripts/Assert-CommitAllowlist.ps1` and `infra/scripts/Invoke-GitWithMutex.ps1`.
- Guard failure output references `DL-028(worktree_discipline)`.
- Documented control in `processes/11-disk-and-sync.md` and closeout evidence in `docs/ops/QUA-590_CLOSEOUT_2026-05-01.md`.
- Probe validation confirmed expected guard fail (`exit 4`) and DL-028 reference; probe cleaned up.

Commit hashes:
- 10e8a64f
- 4f8081ce
- 14aa605b
- d2ea9db3
- 515eb045
