# DEV2 WS30 reconciliation and V4a parity handoff

Task: `a413ae7d-75bc-43f4-93b0-4fa8f27732f8`

Verdict: **DEV2 RECONCILIATION PASS; V4A DEVIATION_STOP**

The uncontracted `WS30.DWX` transport was traced and moved intact to a
recoverable DEV2 quarantine.  The physical DEV2 custom-history tree now equals
the signed six-symbol lane contract.  The frozen USDJPY projection then passed
its 108-file prelaunch audit.  The commissioned V4a validation started through
the governed DEV2 controller and stopped on the first authenticated parity
deviation, as required by its OWNER authorization.  It is not eligible for
activation and produces no pipeline verdict.

## 1. Drift provenance and reconciliation

`WS30.DWX` was not an undocumented broker or MT5 mutation.  It came from the
candidate-analysis transport added by commit
`e183104e448c7771562e0064cf3287d2ba5578b1` and the guarded provisioner:

`framework/EAs/QM5_10834_tv-nq-ict-ob/tools/candidate_analysis/provision_ws30_dev2_transport.py`

The authoritative provision receipt is
`D:/QM/reports/setup/tick-data-timezone/WS30.DWX_DEV2_TRANSPORT_001/provision_receipt.json`
with SHA-256
`16e4f1d647e72180ed40028dbf9bf323deca275e99f12a0faf659cb0f4acd782`.
It records a T1-to-DEV2 offline transport completed on 2026-07-21: 98 files,
892,701,569 bytes, and file-set SHA-256
`2130460517c1affa3f6749d4c30279ddc6f47dcbc1cfcdc73370ccb1a1ebf674`.
The associated QM5_10834 data receipt is
`D:/QM/reports/candidate_analysis/QM5_10834/data/WS30_DWX_201807_202512_DEV2_backtest_data_receipt.json`
with SHA-256
`bd398f53d31e7c91667069e6b2c5b6ec466bb2630fb0934436a3b8f75aedd401`.
This provenance supports transport-only candidate analysis; it does not expand
the signed DEV2 lane contract.

The process-scoped, authorization-bound reconciliation tool moved both WS30
directories atomically without deleting bytes or starting MT5:

- Tool and tests: commit `aaa05e882d38c0c4228572cef548a2c9e4bb2a18`.
- Receipt: `a413ae7d_dev2_ws30_quarantine_2026-08-27.json`, committed as
  `5b2f76d8f6486a28f04f78509f2195f84eaec12b`.
- Recoverable target:
  `D:/QM/reports/dev2/quarantine/a413ae7d_ws30_transport_2026-08-27`.
- Before/after quarantine inventories: exactly 98 files, 892,701,569 bytes,
  file-set SHA-256
  `2130460517c1affa3f6749d4c30279ddc6f47dcbc1cfcdc73370ccb1a1ebf674`.
- Source WS30 history/ticks directories are absent after the move.  The
  quarantine directories and both provenance receipts are present.
- Files deleted: 0.  T1-T10, T_Live, AutoTrading, and the signed lane contract
  were not changed.

## 2. Contract equals physical DEV2 state

The unchanged contract
`framework/registry/dev2_lane_contract.json` has SHA-256
`866e4e346187e47c33e32beb30bb96dc4085e98cc316819fb33f7925306dda06`
and permits exactly:

`EURUSD.DWX, GBPUSD.DWX, GDAXI.DWX, NDX.DWX, USDJPY.DWX, XAUUSD.DWX`

After quarantine, both
`D:/QM/mt5/DEV2/Bases/Custom/history` and
`D:/QM/mt5/DEV2/Bases/Custom/ticks` contain exactly that set.  The first
reconciled validation attempt therefore cleared the symbol-directory gate and
reached the next fail-closed prerequisite.  Its append-only receipt is
`a413ae7d_v4a_phase3_dev2_reconciled_2026-08-27_packet.json`, committed as
`a56a110423583eee4e2b578a908f1193d7ae68a5`.  It stopped before MT5 because
the isolated QMDev2 FILE_COMMON calendar copy was stale.

The canonical multi-principal publisher omitted QMDev2.  Commit
`10e5fc37656265f7281a00278d86b90a11e5f67e` adds the isolated principal to the
same atomic, manifest/hash-bound publication used by Administrator, SYSTEM,
and QMDev1.  The governed refresh then:

- appended two feed rows to each calendar;
- published bundle
  `news-calendar-b2b5b2030218c2afc99101fc8f96d954929b977a04224dd77da295ca4df90ac5`
  to the source and all four Common roots;
- produced operation id
  `fc8ac50dc919185358ff2d1ddcf3d7ec429d6b23d79df1ef2fdef8f100041e5b`;
- pinned primary SHA-256
  `66f7b74616fd975beb4ce1921d1c24c33e4e8a8629df68b3a82deef50dba9e7f`
  and secondary SHA-256
  `853440667555a0f5344ce7d722ea5d1d0d82c31683d3bc195e0d41830be71096`;
- left `qm_news_stale_max_hours` at the enforced 336-hour ceiling; and
- recorded the dependency repin in commit
  `eaedbd9867d064a21cf171a7b582bccc2d5ae236`.

The publication receipt is
`D:/QM/reports/state/news_calendar_publication_receipt_20260827T172743Z-32efbc0676d6471eae909b8f33faff5f.json`.
Its QMDev2 preflight is `OK`, with zero source/Common mismatches.  A separate
read-only no-cache preflight also returned `OK`, age `0.026237` hours, and
`max_age_hours=336`.

The feed coverage monitor emitted a warning because its latest weekly event
(`2026-08-29 16:15Z`) was 72 minutes short of the script's strict `now+2d`
coverage target at publication time.  This did not weaken or bypass the MT5
age/hash gate; the warning remains visible for operations.

## 3. Frozen inventory and commissioned V4a result

The second reconciled attempt authenticated the common frozen projection
before launch:

- 20 claim receipts;
- 108 byte-identical USDJPY history/tick files;
- manifest SHA-256
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`;
- inventory SHA-256
  `b849a1608e0533f633ee516b2bb468ea9819dfe38b9008ddfae2c5893dfe5640`;
- identical inventory before and after the run.

The generated 20-row ledger is
`a413ae7d_v4a_phase3_dev2_reconciled_retry2_2026-08-27_comparison.csv`, and
the full machine packet is
`a413ae7d_v4a_phase3_dev2_reconciled_retry2_2026-08-27_packet.json`, committed
as `89da56e649436c63d108bf193b42bcb975c082e3`.

The authorization says `stop_on_first_deviation=true`.  Consequently, the
driver recorded one authenticated `DEVIATION` row and nineteen
`NOT_RUN_AFTER_STOP` rows; it did not violate that seal to manufacture a full
batch after failure.

Cell 1 (`baseline`) comparison:

| Check | Cold | DEV2 validation | Result |
|---|---:|---:|---|
| MT5 report build | 6090 | 5833 | mismatch |
| closed trades | 193 | 193 | count exact |
| entry trading days | 193 | 193 | exact |
| entry/exit time, symbol, side, raw profit, swap | all 193 rows | all 193 rows | exact |
| commission | `-6247.80` total | `0.00` total | all 193 rows differ |
| net profit | `-10748.50` | `-4500.70` | delta is exactly `6247.80` |
| profit factor | `0.88` | `0.95` | mismatch |
| drawdown | `18981.05` | `16843.63` | mismatch |
| cold/warm wall time | `238.565 s` | `444.766 s` | `0.5282x` attempted speedup |

The set file, EA binary, MQ5 source, model, window, symbol, frozen history,
and normalized execution identity are exact.  The report proves the runtime
cause is outside strategy mechanics: the cold receipt was produced by MT5
build 6090 with native custom-symbol commission, while the signed DEV2 lane is
pinned to build 5833 and recorded zero commission.  The receipt schemas also
differ because the cold worker records `staged_ex5` plus
`pre_dispatch_verified/required_sha256`, whereas the DEV2 controller records
an EX5 source object.  Merely injecting a commission would therefore not make
the raw native report, logger bytes, or receipt schema exact.

The complete-batch speedup is deliberately `null`: only an all-exact 20-cell
batch may claim it.  The measured first-cell ratio is below the `>=2.5x`
target, so no performance success is inferred.

## 4. Checklist and disposition

| Gate | Status |
|---|---|
| WS30 provenance established | PASS |
| WS30 quarantined without deletion | PASS |
| signed DEV2 symbol set equals physical history/ticks set | PASS |
| 108-file frozen inventory and prelaunch | PASS |
| QMDev2 news calendar age/hash preflight | PASS |
| governed DEV2 execution and containment closeout | PASS |
| 20-row parity disposition table | PASS: 1 deviation, 19 sealed stop rows |
| 20/20 exact parity | FAIL-CLOSED / NOT RUN AFTER FIRST DEVIATION |
| complete-batch speedup `>=2.5x` | NOT MEASURED; attempted cell `0.5282x` |
| production feature flag | OFF / no production wiring |
| cold path and DL-089 | byte-identical / untouched |
| activation eligibility | BLOCKED |

A new OWNER-scoped design decision is required before another parity attempt:
an exact build-6090 disposable DEV2 runtime (without mutating T1-T10), cold
worker-equivalent commission and EX5 staging semantics, and a reviewed receipt
schema contract.  This task did not rewrite the signed DEV2 binary contract,
weaken the comparator, alter the cold references, or continue past the sealed
first-deviation stop.

## 5. Verification

- Quarantine/reconciliation focused suite: 32 tests passed.
- `framework/scripts/tests/Test-Dev2ControllerContracts.ps1`: PASS.
- Calendar publisher/gate suite: 41 tests passed.
- Final combined regression invocation: 129 passed; five calendar tests were
  blocked only because the canonical scheduled sweep acquired
  `FACTORY_MUTATION.lock` during the run.  The lock holder was not interrupted
  or altered.  After it released the lock, the complete affected calendar file
  passed 8/8, so every one of the 134 selected tests has a passing result.
- Repin chain verify: PASS, 5 receipts, 19 registry targets, current pins exact.
- V4a session closeout: `closed_exact=true`, one authenticated restart, zero
  DEV2 processes, QMDev2 disabled with password required, no residual DEV2
  Scheduled Tasks.
- No T1-T10 process was interrupted.  T_Live and AutoTrading were never
  enabled or changed.  No pipeline verdict is claimed.
