# QUA-402 Change Summary (2026-05-01T074716Z)

## Implemented
- Added EA: ramework/EAs/QM5_1009_lien_fade_double_zeros/QM5_1009_lien_fade_double_zeros.mq5
- Added .DWX set pack under corresponding sets/ folder.
- Added V5 boundary hooks (NoTrade, Entry, Management, Close).

## Verified
- Pre-CTO validation PASS.
- Hard-rule scan PASS.
- Strict compile PASS (rrors=0, warnings=0).

## Tooling Fix
- Patched ramework/scripts/compile_one.ps1 for MetaEditor nonzero-exit false-negative when compile log is clean and valid EX5 exists.

## Gate
- CTO EA-vs-Card review required before any Pipeline-Operator dispatch.
