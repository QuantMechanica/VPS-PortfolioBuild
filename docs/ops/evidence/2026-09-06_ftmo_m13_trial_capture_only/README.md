# FTMO M13 Capture-Only Trial — Evidence Skeleton (2026-09-06)

Decision: **OWNER-DEC-M13-ECONOMIC-TRIAL-20260906 = YES (Option B)** · Receipt `c575c17a-b55e-4cd3-9770-b9d6bf287f9d`, 2026-09-06 06:17Z.
Runbook: `docs/ops/FTMO_M13_CAPTURE_RUNBOOK_2026-09-06.md`.

This directory holds the evidence for a **capture-only** demo trial. It is populated only after the OWNER creates the FTMO Free Trial demo, the AI preconditions are accepted, and the `EXPECTED_STATE` PARKED→RUNNING flip is made. Until then the entries below are placeholders (`<PENDING>`).

## Firewall statement (binding)

The telemetry captured under this trial is **capture-only**. It is **recorded, not scored**. It is **ineligible as confirmation**: it may inform a NEW preregistration but is never eligible as confirmation under that revised plan, and a post-hoc scored rehearsal is never converted into confirmation. It is **separate from R5** (no trial day enters the R5 sealed-OOS population; a short span does not widen it) and **separate from C-6** (it feeds only the exact-guard INPUT; the sample sits far below the C-6 floors 36/23/9, so C-6 stays LOW_SAMPLE / INERT). Real capital at risk is **USD 0** and **no purchase** is authorized — NO-BUY stands.

## Expected artifacts

| Artifact | Path | Status |
|---|---|---|
| Raw telemetry stream (`qm.ftmo-trial-telemetry.raw/v1`) | `D:/QM/reports/ftmo_trial/<date>/trial_telemetry_raw.jsonl` | `<PENDING>` |
| Compacted M5 report (`qm.ftmo-trial-telemetry.m5/v1`) | `D:/QM/reports/ftmo_trial/<date>/trial_telemetry_m5.json` | `<PENDING>` |
| Daily pulse observations (read-only) | `D:/QM/reports/ftmo_trial/<date>/pulse/` | `<PENDING>` |
| Collector acceptance evidence (Codex ticket) | `<bound by acceptance ticket>` | `<PENDING>` |
| Live-mode set-path generator evidence (Codex ticket) | `<bound by build ticket>` | `<PENDING>` |
| Trial record | `docs/ops/evidence/YYYY-MM-DD_ftmo_m13_trial_capture_only.md` | `<PENDING>` |

## Drill / defect checklist (populate at window close)

- [ ] Continuity: gap-free Prague-day-keyed M5 interval-minimum series (`continuity.status = PASS` except drilled restart boundaries) — `<PENDING>`
- [ ] Validation: `ftmo_trial_telemetry.py` ingests without a `TelemetryError` — `<PENDING>`
- [ ] Identity: account login/server bound; every row `reconciliation_complete=true` — `<PENDING>`
- [ ] Restart drill: new `session_id`, `restart_count ≥ 1`, boundary annotated, state recovered — `<PENDING>`
- [ ] Prague-midnight crossing: `prague_day_key` increments, new day anchored, floor re-baselined — `<PENDING>`
- [ ] Entry-window guardrail: no new entries 23:50–00:10 Europe/Prague — `<PENDING>`
- [ ] Governor: no un-drilled pulse ALARM after RUNNING flip — `<PENDING>`
- [ ] Operational defects total: `<PENDING>` (target: 0)

## Verdict

`<PENDING>` — one of `CAPTURE_SUCCESS` (0 operational defects) or `STOPPED:<reason>`. A demo hit of the FTMO daily/total rule is a data point, not a defect and not a monetary loss.
