# QUA-402 CTO Review Checklist (2026-05-01T074202Z)

Reference diff: $diffFile
Reference impl commit: 32dbaf859b56e9d2ba221962e00127a19fc4734

## Review Focus
- Card alignment for SRC04_S03 entry/management/exit behavior.
- Magic semantics: qm_ea_id=1009, qm_magic_slot_offset, QM_Magic(...) wiring.
- Risk modes: both FIXED and PERCENT paths present.
- Friday close hook default-enabled.
- Set files use .DWX naming.
- Confirm no Pipeline-Operator dispatch has occurred.

## Development Note
- Awaiting explicit CTO EA-vs-Card pass on QUA-402 before any pipeline dispatch.
