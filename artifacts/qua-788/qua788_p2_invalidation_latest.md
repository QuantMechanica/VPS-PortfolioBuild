# QUA-788 Dispatch Attempt (QM5_1009)

- tick_utc: 05/08/2026 06:28:40
- command: $(@{issue=QUA-788; tick_utc=05/08/2026 06:28:40; ea_id=QM5_1009; phase_target=P2; action=p2_baseline_dry_run; command=python framework\scripts\p2_baseline.py --ea QM5_1009 --dry-run; exit_code=1; verdict=INVALID; dl054_reason=SETUP_DATA_MISMATCH; invalidation_reason=EA directory alias mismatch: runner expects framework/EAs/QM5_1009_* but only QM5_SRC04_S03_lien_fade_double_zeros exists; evidence=; unblock_owner=CTO; unblock_action=Provide canonical EA folder/id mapping so QM5_1009 resolves to a launchable EA dir (or update dispatch target id to match compiled artifact), then rerun p2_baseline dry-run + live run; next_action=Blocked until mapping corrected; rerun same command immediately after fix}.command)
- exit_code: 1
- verdict: INVALID
- DL-054 reason: SETUP_DATA_MISMATCH
- invalidation_reason: EA directory alias mismatch: runner expects framework/EAs/QM5_1009_* but only QM5_SRC04_S03_lien_fade_double_zeros exists

## Evidence
- runner_error: [FATAL] EA dir not found: C:\QM\repo\framework\EAs/QM5_1009_*
- ex5_exists: True
- ex5_path: C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros\QM5_SRC04_S03_lien_fade_double_zeros.ex5
- registry_rows_for_1009: 36
- qm5_1009_dir_exists: False

## Blocker
- unblock_owner: CTO
- unblock_action: Provide canonical EA folder/id mapping so QM5_1009 resolves to a launchable EA dir (or update dispatch target id to match compiled artifact), then rerun p2_baseline dry-run + live run
