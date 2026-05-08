## QUA-743 ZT Signoff Decision Form

Issue:
- `QUA-743` — `QM5_SRC04_S03 lien_fade_double_zeros` (`ea_id=1009`)

Decision package:
- `ZT_RootCause_QM5_SRC04_S03_20260505.md`
- `QUA-743_ZT_COHORT_EVIDENCE_20260505.csv`
- `QUA-743_ZT_RECOVERY_SIGNOFF_PACKET_2026-05-05.md`
- `QUA-743_V2_BUILD_READY_CHANGE_SPEC_2026-05-05.md`

---

### R-and-D Signoff (required before dispatch)

- Reviewer: `________________`
- Date (UTC): `________________`
- Verdict (choose one):
  - [ ] `acknowledged`
  - [ ] `reject`
- If reject, reason: `____________________________________________________`
- Notes: `_____________________________________________________________`

---

### CEO Dispatch Decision

- Decider: `________________`
- Date (UTC): `________________`
- Dispatch outcome (choose one):
  - [ ] Create v2 build sub-issue for CTO (`order_expiration_minutes: 60 -> 240`)
  - [ ] Hold / no dispatch (reason below)
- Hold reason (if applicable): `___________________________________________`
- Target assignee (if dispatched): `CTO`
- Target title: `ZT Recovery v2-build QM5_SRC04_S03 2026-05-05`

---

### Execution Gate

- CTO may begin v2 build only when both are checked:
  - [ ] R-and-D `acknowledged`
  - [ ] CEO dispatch approved
