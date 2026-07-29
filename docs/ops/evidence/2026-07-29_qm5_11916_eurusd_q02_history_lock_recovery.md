# QM5_11916 EURUSD Q02 History-Lock Recovery

Date: 2026-07-29
Agent: Codex headless paced fleet
Branch: `agents/board-advisor`

## Outcome

Recovered the existing `QM5_11916_neely-weller-alexander-filter-2pct-d1`
`EURUSD.DWX` Q02 work item from an MT5 history-file sharing violation. The
same row was reopened in place; no duplicate work item and no manual backtest
were created.

- Work item: `ad1aaca6-e639-4680-94c7-5108902438d2`
- State: `done / INFRA_FAIL / attempt_count=2` ->
  `pending / verdict=NULL / attempt_count=0`
- Active matching Q02 rows after requeue: `1`
- Farm repair task: `b1404c28-4431-4f26-aad9-6533bb202db3`
- Exclusive claim key:
  `manual:codex:agents/board-advisor:QM5_11916:q02-history-lock-recovery`

## Diversity And Selection

No priority-1 build had a clean structural, low-frequency, diversity-first
preflight at selection time. The pending lumber/rates cards require unavailable
DWX inputs, while the registry-complete unbuilt choices were high-frequency
indicator ports or another XNG strategy. This made the priority-2 FX recovery
the highest-value non-duplicate unit.

The approved card is a deterministic D1 Alexander 2% filter rule across ten FX
majors/crosses, with eight expected trades per year per symbol. Its source is
Neely and Weller's Federal Reserve Bank of St. Louis working paper, tracing the
rule to Alexander (1961). The EURUSD preset declares `risk_mode: FIXED` and
`RISK_FIXED=1000`.

Approved card:
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_11916_neely-weller-alexander-filter-2pct-d1.md`

## Diagnosis

The archived run-smoke summary surfaced `ONINIT_FAILED` and `INCOMPLETE_RUNS`,
with an invalid zero-bar report. The matching T6 controller log identifies the
underlying infrastructure fault:

- At `18:55:20`, T6 launched the exact work-item run rooted at
  `20260728_165516`.
- At `18:56:18-20`, MT5 repeatedly logged
  `'EURUSD.DWX' file opening or reading error [32]`.
- At `18:57:25`, MT5 ended with `some error after pass finished` and no test
  duration.

Win32 error 32 is a sharing violation. The source and deployed artifacts matched
and remained stable throughout the failed run, so this is not an EA logic,
magic-registry, or stale-binary defect and is not a strategy verdict.

Evidence:

- Controller log: `D:\QM\mt5\T6\logs\20260728.log`, lines 2745-2769
- Archived report root:
  `D:\QM\reports\work_items\ad1aaca6-e639-4680-94c7-5108902438d2.requeued_20260729T090927Z`
- Reversible state journal:
  `D:\QM\reports\state\qm5_11916_q02_history_lock_requeue_20260729T090927Z.json`

## Farm Handoff

Before mutation, the farm database was backed up to:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11916_q02_history_lock_requeue_20260729T090635Z.sqlite`

The existing row was atomically reset and annotated with the repair claim,
diagnosis, archive, and journal paths. Its terminal avoidance list is now
`T1,T2,T6,T9`; T6 was added because it produced the observed sharing violation.
Stale runtime and retry fields were removed while the expected artifact hashes
and RISK_FIXED preset were preserved.

At handoff, `FACTORY_OFF.flag` is present and there are zero factory terminals
or terminal workers. The row is therefore queued but intentionally undispatched
until the paced factory resumes.

## Validation

- `build_check.ps1 -Strict -SkipCompile`: `PASS`, 0 failures, 0 warnings.
  Report: `D:\QM\reports\framework\21\build_check_20260729_090726.json`
- Farm database `PRAGMA quick_check`: `ok` for the live database and backup.
- MQ5 SHA-256:
  `f2de162b78d1a98dc7fcc2ce629aa40640e9aa95c0945b660dc01f75a8425c50`
- EX5 SHA-256:
  `fb2ff02f4c1168d2b6f324f6658764fb4a56efd13c357f99e317f432103ef769`
- EURUSD setfile SHA-256:
  `fed80ae6df1c63705307b450c7d706cb0cef198c953594c79a3aa7ece5ceff44`

The validation command's preset-header refresh was not retained; all 18 preset
files were restored byte-for-byte, and the current EURUSD hash matches the
failed-run evidence binding and pending work-item payload.

No T_Live process, AutoTrading setting, portfolio gate, deploy manifest, or live
artifact was changed.
