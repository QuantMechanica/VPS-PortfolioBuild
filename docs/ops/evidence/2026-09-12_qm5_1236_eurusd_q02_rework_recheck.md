# QM5_1236 EURUSD Q02 rework recheck

Date: 2026-09-12

Router task: `32d9b93a-18eb-41e9-bf09-242419686fd0`

Original predecessor: `1b921415-5b5e-441a-896d-9304e3ad9392`

## Result

The requeued router task is superseded by a later OWNER disposition row and remains capacity-blocked. No Q02 work was created.

Read-only database inspection found later work item `cd22436c-663e-5750-a7dc-4ceb3eb1cd28`, created 2026-08-23 for exact QM5_1236 / EURUSD.DWX / Q02. It is a disposition-only row with:

- `status=failed`, `verdict=INVALID`;
- `backtest_enqueued=false` and `disposition_only=true`;
- `owner_decision_id=OWNER-DEC-STRANDED-182`;
- `source_work_item_id=1b921415-5b5e-441a-896d-9304e3ad9392`; and
- `verdict_reason=OWNER_APPROVED_DETERMINISTIC_NO_SUMMARY_INVALID`.

That append-only OWNER decision preserves the historical infrastructure row and explicitly declines a backtest. This orchestration cycle cannot override it by replaying the older capacity-clear handoff.

Current artifacts remain byte-identical to the August diagnosis:

- MQ5: `797e048a936fae2050b0a1b43f506ff42e0ddf8c79e8822046306248fffaac37`
- EX5: `3d161d442dbd8b9087e0ad46106ead9e0ba0abd5c522f9373a4ad7bc73583690`
- EURUSD D1 set: `7a104f547f56f143c7134403807e5f6fc17c98f3b7a64957b961d29912acf7d2`

There is no source/build defect indicated by those stable bindings, so a `COMPILE_EA` request would be unrelated to the failed history layer. The five current CPU samples were 97, 83, 90, 99, and 96 percent (average 93.0%, maximum 99%), still above the historical 97% hard ceiling. The canonical slot census showed five active governed terminals.

No source, binary, setfile, registry, work item, or pipeline verdict was changed. No terminal was started or interrupted, and neither `T_Live` nor AutoTrading was touched.

RESULT: SUPERSEDED_BY_OWNER_INVALID_DISPOSITION — `cd22436c-663e-5750-a7dc-4ceb3eb1cd28` explicitly records no enqueue; CPU maximum remains 99%; no duplicate Q02 successor.
