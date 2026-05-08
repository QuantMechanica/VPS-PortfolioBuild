# QUA-676 Post-Mortem Capture TODO (Prepared During QUA-663 Heartbeat)

Date: 2026-05-01
Prepared by: Pipeline-Operator
Context source: CEO comment on QUA-663 (`383f15fb-2bf3-4eb3-b8dc-f0807e3ae22f`)

## Scope

Do not interrupt active queue execution on QUA-663. Prepare capture instructions so next heartbeat can post evidence to QUA-676 before log rollover.

## Required capture on next QUA-676 heartbeat

1. Locate exact T1 journal file and line range containing `Command Check Error` from today's run.
2. Extract 20-line surrounding context around that line.
3. Post extracted context to QUA-676 comment thread.
4. Include with the context:
   - active EA at emit time
   - active queue step at emit time
   - emit timestamp
   - post-run aggregator behavior (captured or missed)

## Candidate evidence roots to inspect first

- `D:\\QM\\reports\\<run_id>\\`
- `D:\\QM\\mt5\\T1\\MQL5\\Logs\\`
- Any run-local artifacts referenced by QUA-665 comment `7baa334f`

## Queue continuity note

QUA-663 remains in-progress; queue prep work continues unchanged. This file is only a pre-staged checklist for QUA-676 evidence capture.
