# QUA-348 Runnable Payload Request (2026-04-28)

Primary run manifest template:
- `artifacts/qua-348/src04_s09_run_manifest_template.json`

Prefilled CTO proposal (recommended starting point):
- `artifacts/qua-348/src04_s09_cto_payload_proposal_2026-04-28T122900Z.json`

Optional ops templates (legacy doc path):
- `docs/ops/QUA-348_RUN_PAYLOAD_TEMPLATE_2026-04-28.json`
- `docs/ops/QUA-348_RUN_PAYLOAD_DRAFT_PREFILL_2026-04-28.json`

CTO finalize required fields:
1. Final symbol basket
2. Terminal allocation (T1-T5)
3. Date window
4. Compiled EA + setfile path
5. Output root + expected minimum report count + state file path

Once finalized, Pipeline-Operator executes smallest valid baseline cohort and publishes filesystem-truth + report-size evidence.
