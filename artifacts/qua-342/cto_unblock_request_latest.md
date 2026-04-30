# QUA-342 Unblock Request (Latest)

Updated: 2026-04-28T10:10:34Z
Issue: QUA-342 / SRC04_S03 (lien-fade-double-zeros)
Status: BLOCKED (mapping-only)

## Current State
- dispatch_ready: False
- blocked: True
- state_changed: False
- consecutive_unchanged_blocked_ticks: 3
- escalation_threshold: 5
- escalate_now: False
- latest_tick_bundle: C:\QM\repo\artifacts\\qua-342\\tick_bundle_20260428_101025.json

## Missing Required Fields
- ea_name
- setfile_path
- ea_id is still TBD and must be mapped to a concrete strategy EA ID

## Unblock Owner
- CTO

## Required Action
Assign executable mapping fields in payload (ea_name, setfile_path) and set strategy EA ID from TBD to concrete mapping
