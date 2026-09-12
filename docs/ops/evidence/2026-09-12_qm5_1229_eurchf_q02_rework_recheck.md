# QM5_1229 EURCHF Q02 rework recheck

Date: 2026-09-12

Router task: `076c4a69-79c6-4b41-9034-37a895783719`

Original predecessor: `8870ee05-fbc6-4bc2-a721-b3cba2a334c5`

## Result

The requeued router task is superseded by a later canonical append-only recovery row. No duplicate Q02 work was created.

Read-only database inspection found work item `8faa0e69-3f8f-4cf0-ab8c-df9e031fe2b7`, created 2026-08-25 and completed 2026-09-07. Its payload explicitly records:

- `append_only_rerun: true`;
- `append_only_rerun_of_work_item: 8870ee05-fbc6-4bc2-a721-b3cba2a334c5`;
- exact EA/symbol/phase: QM5_1229 / EURCHF.DWX / Q02;
- the current MQ5, EX5, and setfile hashes;
- `custom_history_copy_on_claim.status: PASS_PRIVATIZED`; and
- a real-MT5 evidence path at `D:/QM/reports/work_items/8faa0e69-3f8f-4cf0-ab8c-df9e031fe2b7/QM5_1229/20260907_111717/summary.json`.

The governed result is `status=done`, `verdict=FAIL`, with `verdict_reason=run_smoke_fail:MIN_TRADES_NOT_MET`. This is a valid strategy-layer Q02 verdict after the infrastructure isolation repair; it replaces the old BARS_ZERO recovery question but does not constitute a PASS.

Current hashes still match the retry binding:

- MQ5: `98c621bdcf2e22ced88e2da30387789ba7219b42e83b37963ce1b0521689080f`
- EX5: `a1cb81c11a932a1f3f5f00f1af7a32952466d26fcbf3ff31434a4cc22256eda1`
- EURCHF D1 set: `a78381adf6e6b4653c196e50140bd68af0e8d91cd33d4a895f5809e809f49eaa`

An independent current capacity sample also remains above the historical hard ceiling: five whole-host readings were 97, 83, 90, 99, and 96 percent (average 93.0%, maximum 99%). The canonical slot census showed five active governed terminals. Capacity is secondary here because the requested successor already exists and has finished.

No source, binary, setfile, registry, work item, or pipeline verdict was changed. No terminal was started or interrupted, and neither `T_Live` nor AutoTrading was touched.

RESULT: SUPERSEDED_BY_Q02_SUCCESSOR — isolated retry `8faa0e69-3f8f-4cf0-ab8c-df9e031fe2b7` completed with pipeline-evidenced strategy FAIL/MIN_TRADES_NOT_MET; no duplicate enqueue.
