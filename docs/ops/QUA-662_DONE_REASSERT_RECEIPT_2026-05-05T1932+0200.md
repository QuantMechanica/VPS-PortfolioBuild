# QUA-662 done reassert receipt (2026-05-05T1932+0200)

- Issue: QUA-662 (`29bb311e-7f6e-4caf-8838-e9a238b1c4a0`)
- Reason: control-plane status drift observed (`in_progress` after prior done transition)

## Actions this heartbeat

1. Read done transition payload and verified target state is `done`.
2. Queried issue API and confirmed live status drift to `in_progress`.
3. Attempted legacy transition script; it failed on comment endpoint payload validation (endpoint expects JSON object, not raw text).
4. Applied direct status patch:
   - `PATCH /api/issues/29bb311e-7f6e-4caf-8838-e9a238b1c4a0 {"status":"done"}`
5. Re-fetched issue and confirmed:
   - `status=done`
   - `updatedAt=2026-05-05 17:32:10Z` (API-rendered)

## Evidence of record

- Final report artifact: `D:\QM\reports\pipeline\QM5_1003\P2\report.csv`
- Canonical coverage proof: `36/36` (from prior closeout packet)
- Coverage note: `C:\QM\repo\docs\ops\QUA-662_P2_COVERAGE_COMPLETE_2026-05-05T1926+0200.md`

## Follow-up

- No further execution work on QUA-662.
- Route any new scope to a child issue under QUA-741 / QUA-740 hierarchy.
