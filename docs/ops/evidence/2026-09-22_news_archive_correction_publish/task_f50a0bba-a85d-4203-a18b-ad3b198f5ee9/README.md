# Q09 news-archive correction publication and requalification

Task: `f50a0bba-a85d-4203-a18b-ad3b198f5ee9`

Disposition: **REVIEW**. The approved 82-row USD `+60 minute` correction is published as an immutable successor and the 128 directly exposed historical Q09/Q10 rows have an append-only requalification roster. This artifact does not approve any successor verdict or any live use.

## Publication result

- Fable decision: `FABLE-DEC-NEWS-ARCHIVE-DST-CORRECTION-20260922` (`APPROVED_CORRECTION`).
- Parent preserved: `q09cal-20150101-20260809-0bb19b5bb9790b76`, events SHA-256 `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1`.
- Successor published: `q09cal-20150101-20260809-3d44f107363359bb`, 48,245 rows, events SHA-256 `7a3243cf14d3ac6786423a48dd50317eed155d9c5360ba1067c55355f9618522`.
- Sealed successor manifest SHA-256: `50e16cfbb8ebdf56093cbae8f05d0972f666c257c8034bd6cdcb393e679c2015`; publisher receipt SHA-256: `7abe608b9977a8a5393ba1ea0a0e609e5fc0f1e7adef79dba514ee0bbb05527f`.
- The governed publisher's WhatIf plan was clean before apply. The parent archive was not edited. The content-addressed successor was provisioned to all four existing FILE_COMMON roots, each rehashed to the successor content hash; no active calendar file was overwritten.

The committed copies of the sealed metadata are [successor_manifest.json](successor_manifest.json), [publisher_receipt.json](publisher_receipt.json), and [publication_verification.json](publication_verification.json).

## Versioned contract

Newly sealed Q09/Q10 rows use `qm.q09-calendar-pin-contract/v2`. The hypothesis is: correcting the 82 proven one-hour-early USD releases removes false blackout timing without changing any Q10 selection threshold. The single changed evaluation input is the news-calendar bundle/content hash; selection thresholds and the historical contracts remain unchanged.

The false-positive measure is a new `CONFIG_LOCKED` where the source was `REVIEW_REQUIRED`. The false-negative measure is loss of a source `CONFIG_LOCKED` under the successor calendar. Old rows, evidence and verdicts remain immutable. Code commit `c98df1f41c` centralizes the successor pin and stamps it into new farmctl, live-diagnostic and OOS-confirmation payloads.

## Append-only requalification

The impact roster is bound to `sealed_verdict_impact.csv` SHA-256 `a6fa51c1d756b663c931e13be60a3b25880f7f0e8bae806308da5a2c57c34719`. The deterministic plan SHA-256 is `fc71284dc419a25549aad464bcadcc733ea6b384c509cbb9a324aaa8f0befe68`.

Apply result:

- 128 directly exposed source rows, ordered with D2g6 `13213/10706/10700/11422/10403/41219` first, then `11708`, `12710 -> 41488`, `20266 -> 41489`, then remaining book relevance.
- 125 append-only successor rows inserted; 0 pre-existing successors; all 128 source rows verified unchanged after commit.
- 13 diagnostic successors are pending remeasurement with their sealed successor plans.
- 110 successors are held fail-closed: 54 failed source-plan authentication before build, and 56 failed final binding (54 include-closure vintage mismatches and 2 Q08 MQ5-vintage mismatches).
- 2 `12710 -> 41488` successors were successfully sealed/bound during apply. The canonical scheduled pump subsequently placed `NEWS_CALENDAR_TAINTED` holds because the reviewed successor pin commit is not yet integrated into the canonical worker checkout. Their payloads and sealed plans remain pinned to `7a3243cf...`; release is a separate governed post-integration action.
- 3 `20266 -> 41489` mappings were not fabricated because target identity `41489` ends at an ineligible Q08 chain. Cross-build replacement comparisons are explicitly labelled non-causal.
- All 125 inserted payloads carry both the v2 pin and requalification marker for successor hash `7a3243cf...`.

The database was backed up before mutation at `D:\QM\strategy_farm\state\backups\farm_state_before_q09_calendar_requalification_20260922T064928Z_44726e76.sqlite`, SHA-256 `3224b606984ba7c8bf726604648fd76445c9d5905ce7b194d261ea9248cba671`. The task-scoped run-plan root is `D:\QM\strategy_farm\artifacts\news_calendar_requalification\task_f50a0bba-a85d-4203-a18b-ad3b198f5ee9\`.

See [requalification_plan.json](requalification_plan.json), [requalification_apply_receipt.json](requalification_apply_receipt.json), [requalification_status.json](requalification_status.json), and [verdict_delta.csv](verdict_delta.csv).

## Current verdict delta

No successor has completed, so no new pipeline verdict exists and no roster seal can yet be reported as changed. The current table contains 13 pending remeasurements, 110 requalification-input holds, 2 canonical-deployment taint holds, and 3 ineligible replacement mappings. It records zero completed D2g6 `CONFIG_LOCKED` losses; therefore `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` was correctly left unchanged.

## Verification

- Focused unit/integration suite: `34 passed` after rebasing onto canonical HEAD `8f85759ef8`.
- Python compilation and `git diff --check`: PASS.
- Clone rehearsal of the full governed apply: PASS before live mutation.
- Live apply: 125 inserted, 0 existing, 0 build failures, 56 binding failures converted to explicit holds, source preservation `true`.
- Safety: no roster edit, no T_Live or AutoTrading change, no terminal launch, and no running backtest interruption.

One broader pre-existing test remains outside this change: `test_diagnostic_uses_deployed_ex5_name_and_worker_accepts_only_review_sidecar` fails because its temporary schema rejects the canonical `review` verdict-taxonomy value. The focused tests covering this publication and requalification are green.
