## QUA-743 v2 Build-Ready Change Spec (Post-Approval)

Scope:
- Apply only after R-and-D signoff + CEO dispatch.
- Do not modify `v1` in place; create `v2` lineage artifact per V5 enhancement loop.

### Single-Axis Change

- Parameter: `order_expiration_minutes`
- Current default: `60`
- Proposed v2 default: `240`
- Reason: ZT cohort (`5/5`) suggests staged stop orders are expiring before trigger in current profile.

### Source Reference

- Current location in v1 source:
  - `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.mq5`
  - line: `input int    order_expiration_minutes     = 60;`

### Required Build Outputs (v2)

- New EA folder/slug lineage for v2 (no overwrite of v1 evidence).
- Updated `.mq5` with only this default change in entry module settings.
- Recompiled `.ex5` with compile log evidence (`0 errors, 0 warnings` target).
- Fresh DL-036 checklist and review artifact for v2.
- New P2 baseline run artifacts for v2 cohort.

### Non-Goals in This Revision

- No exit logic modifications.
- No additional entry filter changes.
- No risk model changes.
- No framework gate policy changes.
