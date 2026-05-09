QUA-671 OWNER approval packet (P0-13 T6 deploy manifest dry-run)

- Scope guard: DRY-RUN ONLY, no MT5 write, no AutoTrading toggle, no live credentials.
- Commit lineage head: $CommitHash
- Evidence:
  - ramework/deploy/manifests/T6_DRYRUN_v0.yaml
  - ramework/deploy/scripts/manifest_dryrun.ps1
  - $EvidencePath
  - ramework/deploy/manifests/QUA-671_NO_POLLING_UNTIL_OWNER_UNBLOCK.signal
- Blocked state: locked_pending_owner_approval

Unblock owner/action:
- OWNER: approve P0-13 T6 manifest dry-run evidence and authorize transition to done.
