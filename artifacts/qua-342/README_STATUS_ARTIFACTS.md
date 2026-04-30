# QUA-342 Status Artifacts

Updated: 2026-04-28
Scope: SRC04_S03 blocker tracking and escalation handoff.

## Files
- `tick_bundle_latest.json`: full heartbeat snapshot (readiness + infra + change detection).
- `unblock_status_latest.json`: compact machine-readable blocker status.
- `blocked_streak_latest.json`: consecutive unchanged-blocked counter.
- `cto_unblock_request_latest.md`: human-readable unblock handoff.
- `cto_unblock_request_latest.json`: machine-readable unblock handoff.
- `cto_escalation_trigger_latest.json`: escalation trigger (latched once threshold reached).
- `validate_cto_mapping_payload.ps1`: validates a CTO mapping payload has non-placeholder values and a resolvable `setfile_path`.
- `apply_cto_mapping_preview.ps1`: non-destructive preview merge of CTO mapping values into target payload; writes `*.patched_preview.json` only when mapping is valid.

## Key Fields
- `blocked` (bool): whether dispatch is blocked.
- `dispatch_ready` (bool): readiness gate.
- `missing_fields` (string[]): payload fields still missing.
- `unblock_owner` (string): current owner (CTO).
- `unblock_action` (string): exact required action.
- `consecutive_unchanged_blocked_ticks` (int): unchanged blocked streak.
- `escalation_threshold` (int): streak threshold for escalation.
- `escalate_now` (bool): threshold condition currently true.

## Escalation Semantics
- `cto_escalation_trigger_latest.json` is written when `escalate_now=true`.
- `triggered_at_utc` is latched at first trigger and remains stable.
- `last_seen_utc` updates on each subsequent escalated tick.

## Current Known Blocker
- Missing: `ea_name`, `setfile_path`
- Also unresolved: concrete `ea_id` mapping (currently `TBD`)


- generate_cto_payload_from_env.ps1: builds a filled CTO mapping payload from env vars EA_ID, EA_NAME, SETFILE_PATH, then runs validator.

- cto_fill_payload_example.cmd: Windows example wrapper to set EA_ID/EA_NAME/SETFILE_PATH and run env-based payload generation+validation.
