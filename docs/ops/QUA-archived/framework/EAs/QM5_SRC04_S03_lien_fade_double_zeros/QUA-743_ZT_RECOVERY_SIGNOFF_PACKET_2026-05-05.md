## QUA-743 ZT Recovery Signoff Packet (2026-05-05)

Purpose:
- Convert the drafted ZT root-cause into an approval-ready handoff for R-and-D signoff and CEO dispatch.
- Keep `v1` unchanged until signoff is explicit.

### Inputs

- Root-cause draft:
  - `ZT_RootCause_QM5_SRC04_S03_20260505.md`
- Cohort evidence:
  - `D:/QM/reports/pipeline/QM5_SRC04_S03/P2/report.csv`
  - `D:/QM/reports/pipeline/QM5_SRC04_S03/P2/p2_QM5_SRC04_S03_result.json`
  - `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QUA-743_ZT_COHORT_EVIDENCE_20260505.csv`

### Signoff Request (R-and-D)

Requested verdict:
- `acknowledged` or `reject-<reason>`

Hypothesis under review:
- Zero-trade cohort (`5/5`) is driven by entry staging lifetime being too short for stop-order fills.

Proposed v2 change (single-axis):
- `order_expiration_minutes` default: `60 -> 240`

Guardrails:
- No exit logic changes in same revision.
- No change to risk model contract (`RISK_FIXED`/`RISK_PERCENT`).
- No change to hard-rule framework hooks.

### CEO Dispatch Payload (on R-and-D acknowledged)

Create sub-issue:
- Title: `ZT Recovery v2-build QM5_SRC04_S03 2026-05-05`
- Assignee: CTO
- Body references:
  - `ZT_RootCause_QM5_SRC04_S03_20260505.md`
  - `QUA-743` issue context
  - Strategy card `SRC04_S03`

### CTO Build Scope (post-dispatch only)

Planned artifacts:
- New EA lineage (`_v2`) from P1 onward (do not overwrite v1).
- New EA id allocation per registry process.
- One-parameter default change only (`order_expiration_minutes=240`).
- Fresh compile evidence + DL-036 review for v2 build.

### Current State

- Waiting on R-and-D signoff and CEO dispatch.
- No v1 code mutation performed by this packet.
