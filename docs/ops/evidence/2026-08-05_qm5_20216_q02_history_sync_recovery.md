# QM5_20216 Q02 conversion-history recovery and requeue

## Selection and claim

- Branch: `agents/board-advisor`.
- Farm coordination task: `105cf4c2-c5af-4c21-b6ac-debfbbeea5f3`.
- EA: `QM5_20216_audusd-euraud`.
- Logical sleeve: D1 market-neutral AUDUSD/EURAUD cointegration basket.
- Failed Q02 row: `214ac1b6-a810-456f-801a-97e3673bc953`.
- Logical symbol: `QM5_20216_AUDUSD_EURAUD_COINTEGRATION_D1`.

The approved unbuilt diversity backlog had no claimable registry-complete forex,
crypto, rates, or new-energy card: the genuinely unbuilt forex cards had EA IDs
but no allocated magic rows. This diverse FX market-neutral sleeve was therefore
claimed under the mission's Q02-Q03 infrastructure-recovery priority. The claim,
collision checks, and pre-claim database backup were recorded in the active farm
DB before diagnosis.

## Diagnosis

The work item exhausted three cold-cache attempts as `INFRA_FAIL` with
`cold_cache_retries_exhausted:BARS_ZERO`. The archived summaries report only
blank tester artefacts (`EMPTY_EXPERT`, `EMPTY_SYMBOL`, `M0_1970_PERIOD`, and
`BARS_ZERO`), but the underlying evidence rules out an EA or build failure:

- The expected source, deployed EX5, and setfile hashes still match the repository
  artefacts exactly.
- The captured logger sample records `SYMBOL_GUARD_INIT` for `AUDUSD.DWX`,
  `EURAUD.DWX`, and `EURUSD.DWX`, followed by `BASKET_WARMUP` and `INIT_OK`.
  `OnInit` therefore completed successfully.
- T5's tester log starts the correct EA on `AUDUSD.DWX,D1` for
  `2018.07.02-2022.12.31`. `AUDUSD.DWX` and `EURAUD.DWX` synchronize, then
  `EURUSD.DWX: history synchronization error` disconnects the tester before it
  can produce a valid report.
- The same terminal-local failure occurs on all three latest tester launches at
  `01:10:57.621`, `01:11:14.987`, and `01:11:35.597` in
  `D:/QM/mt5/T5/Tester/logs/20260805.log` (lines 6648, 6678, and 6708).

`EURUSD.DWX` is the USD-account conversion/history-only dependency; the traded
legs remain `AUDUSD.DWX` and `EURAUD.DWX`. The surface `BARS_ZERO` verdict is
therefore a T5 conversion-history synchronization failure, not a strategy,
`OnInit`, source, or stale-EX5 defect.

## Repair

No strategy or binary change was warranted. The same Q02 row was reopened in
place with the following bounded recovery state:

- status `pending`, verdict/evidence binding cleared, and attempt count reset
  from 3 to 0;
- stale process, launch, and cold-cache retry fields cleared;
- prior failure and evidence retained in `requeue_history`;
- learned terminal exclusions preserved as `T3`, `T5`, and `T7`, ensuring this
  retry cannot return to the failing T5 history cache;
- priority-track, basket scope, source/EX5 bindings, and the fixed-risk contract
  retained; the header-only setfile rebind is recorded below;
- `RISK_FIXED=1000` and `RISK_PERCENT=0` explicitly persisted in the queue
  payload.

No duplicate work-item row was inserted.

The strict checker refreshed only the two setfiles' provenance-comment
`build_hash` values. The farm pump concurrently captured those header-only
changes in branch commit `aae85d36ef9472bd8ab2cdca318f0de3f0cdc94b`.
Because the Q02 row was still pending and unclaimed, its exact setfile binding
was atomically updated from the pre-check hash to the committed working-tree
bytes under the same factory mutation lock. Inputs, risk, symbols, timeframe,
dates, and all strategy parameters are unchanged.

## Validation

- Strict build/static check with the captured logger sample and `-SkipCompile`:
  PASS, zero failures and zero warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260805_095910.json`.
- MQ5 SHA-256:
  `8a7beac6dad3787a9920b658da87262b44f5fd371f39260c954a41a240477e72`.
- EX5 SHA-256:
  `8191c96f3509ae24b6f8015b633edb5c9eaa6e7e5ff209080629106f384954e5`.
- Pre-check setfile SHA-256:
  `35b8bd10b17dea3ae21326e71871b4369562d22ebc37ad90b46faddbb4e36adc`.
- Final queued setfile SHA-256 after the committed metadata-header refresh:
  `17d53bceba8223eda05f1ab4bb20482e44f591896ef5ea9b8f60a2bdb372ab06`.
- Active farm DB `PRAGMA quick_check`: `ok` after the handoff.
- Factory terminals immediately before and after requeue: 4, below the ceiling
  of 7.

No manual tester or additional terminal was launched; execution remains owned
by the paced fleet.

## Queue handoff

- Requeued at: `2026-08-05T10:06:23+00:00`.
- Pre-write online backup:
  `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_20216_q02_requeue_20260805T100612Z.sqlite`
  (`PRAGMA quick_check=ok`).
- Crash-safe committed journal:
  `D:/QM/reports/state/qm5_20216_q02_history_sync_requeue_20260805T100612Z.json`.
- Pre-binding-refresh online backup:
  `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_20216_setfile_rebind_20260805T101224Z.sqlite`
  (`PRAGMA quick_check=ok`).
- Committed binding-refresh journal:
  `D:/QM/reports/state/qm5_20216_q02_setfile_rebind_20260805T101224Z.json`.
- Archived failed evidence root:
  `D:/QM/reports/work_items/214ac1b6-a810-456f-801a-97e3673bc953.requeued_20260805T1006230000`.
- Readback at handoff: `pending`, verdict `NULL`, attempt count 0, unclaimed.

No portfolio gate, portfolio manifest, deploy manifest, `T_Live` path,
AutoTrading state, or live configuration was touched.
