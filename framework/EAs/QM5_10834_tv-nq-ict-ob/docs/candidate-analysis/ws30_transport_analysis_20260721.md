# QM5_10834 — preregistered WS30.DWX transport analysis

Status: **PREREGISTERED / NOT READY TO RUN**

This is a genuinely new symbol transport of the approved `tv-nq-ict-ob` EA to
untouched `WS30.DWX` evidence. It is not a new identifier wrapped around the
invalid NDX run. The WS30 audit does not open, import, validate, reset, or retry
any NDX claim, state, report, or outcome.

The immutable machine-readable policy is
`ws30_transport_analysis_contract_20260721.json`. The executable adapter is
`../../tools/candidate_analysis/audit_tv_nq_ict_ob_ws30.py`. The adapter loads
the existing NDX auditor in a private Python module namespace, changes only the
frozen symbol profile, and reuses its outcome fence, controller, duplicate,
Model-4, lifecycle, report-integrity, and merit logic. The NDX module loaded by
other callers remains on its original constants and historical verification.

## Frozen analysis

- EA: `QM5_10834_tv-nq-ict-ob`
- Research/backtest symbol: `WS30.DWX`
- Timeframe/model: `M5`, MT5 Model `4` (real ticks)
- DEV: `2018-07-02..2022-12-31`
- OOS: calendar years `2023`, `2024`, and `2025`, each isolated
- Accepted duplicates: `2` per cell, with exact canonical Deal-sequence identity
- Strategy inputs: identical to NDX; only the already-built WS30 set header,
  magic slot `1`, and corresponding set build hash differ
- Merit: exact `QM5_10834_MERIT_V1_20260720`; there are no CLI merit overrides
- Parameter tuning, technical prescreen promotion, and retrospective gate changes
  are forbidden

The approved SPEC already lists `WS30.DWX`. The existing build receipt binds the
WS30 set and the same MQ5/EX5/source closure used by the NDX implementation.

## Cost center and stress axes

The merit center is fixed before outcomes exist:

- Spread: embedded in the bound `WS30.DWX` real-tick data
- DXZ: `$0.70` round trip per lot
- FTMO index: `$0.00` commission
- Merit commission: `$0.70` round trip per lot (the worst of those two venues)
- Merit slippage increment: `0` points

Two supplemental views cannot change the merit decision:

1. The bound calibration auto-stub preregisters a `0 / 1 / 3` point slippage
   axis. Because that source does not bind an exact USD-per-point conversion,
   POST reports the axis but does not invent a USD P&L adjustment or use it as a
   merit gate.
2. The legacy registry class-flat overcost is evaluated at an absolute `$5.50`
   round-trip commission per lot. It replaces `$0.70` for that stress view; it
   is not added on top. POST computes separate cell and pooled stress metrics,
   while leaving the primary merit center unchanged.

## Why PRE and freeze-data correctly fail today

Two prerequisites are deliberately absent:

1. `framework/registry/execution_symbol_aliases_v1.json` has no WS30 rows. A
   later, separately reviewed registry change must add exactly:
   - `WS30.DWX -> WS30` for `DXZ_LIVE`
   - `WS30.DWX -> US30.cash` for `FTMO_TRIAL`
2. The T1 WS30 store has not yet been transported byte-for-byte into the isolated
   DEV2 store and no provision evidence exists at the preregistered paths.

Neither command provisions data, edits a registry, launches MT5, creates a task,
or starts a tester. Missing prerequisites return exit code `2` with an `INVALID`
diagnostic on stderr; they deliberately do **not** create a freeze or PRE receipt.
This is a readiness failure, not a strategy result and not an attempt.

## Offline DEV2 provision evidence required later

The source terminal is frozen to `T1`; choosing a different source after seeing
results is not allowed. The future files are:

- `D:\QM\reports\setup\tick-data-timezone\WS30.DWX_DEV2_TRANSPORT_001\provision_manifest.json`
- `D:\QM\reports\setup\tick-data-timezone\WS30.DWX_DEV2_TRANSPORT_001\provision_receipt.json`

The manifest must be schema 1,
`QM5_10834_WS30_DEV2_PROVISION_MANIFEST`, and bind:

- source `T1`, `D:\QM\mt5\T1\Bases\Custom`
- target `DEV2`, `D:\QM\mt5\DEV2\Bases\Custom`
- exact `201807..202512` closure: 8 HCC years + 90 TKC months = 98 files
- operation `BYTE_EXACT_OFFLINE_FILE_TRANSPORT`
- all four outcome/MT5 fence flags false

The receipt must be schema 1,
`QM5_10834_WS30_DEV2_PROVISION_RECEIPT`, status `PASS`, bind the exact manifest,
and contain the exact ordered 98-row ledger. Every row binds the preregistered
T1 source and DEV2 target path, size, and SHA-256 for its HCC year or TKC month.
Freeze rehashes both copies, rechecks their file identities around both hash
passes, and rejects reordered/substituted paths, byte drift, hardlink/same-file
aliases, and any reparse component. The receipt must also keep all outcome/MT5
fence flags false. The later provisioner is outside this change; it must not use
this PRE command as a copier.

After the provision is complete, freeze exactly the DEV2 corpus once:

```powershell
C:\Python311\python.exe `
  C:\QM\repo\framework\EAs\QM5_10834_tv-nq-ict-ob\tools\candidate_analysis\audit_tv_nq_ict_ob_ws30.py `
  freeze-data `
  --symbol WS30.DWX `
  --receipt D:\QM\reports\candidate_analysis\QM5_10834\data\WS30_DWX_201807_202512_DEV2_backtest_data_receipt.json
```

The receipt is exclusive-create and binds exactly the 98 WS30 files plus the
Factory namespace, alias, matrix, cost, slippage-calibration, and provision
evidence bytes. An NDX path or file cannot satisfy the closure.

## PRE and runtime provenance

The only primary run root is:

`D:\QM\reports\candidate_analysis\QM5_10834\runs\WS30_ICT_OB_TRANSPORT_NATIVE_ATTEMPT_001`

When all prerequisites exist, PRE is:

```powershell
C:\Python311\python.exe `
  C:\QM\repo\framework\EAs\QM5_10834_tv-nq-ict-ob\tools\candidate_analysis\audit_tv_nq_ict_ob_ws30.py `
  pre `
  --symbol WS30.DWX `
  --data-receipt D:\QM\reports\candidate_analysis\QM5_10834\data\WS30_DWX_201807_202512_DEV2_backtest_data_receipt.json `
  --build-receipt C:\QM\repo\framework\EAs\QM5_10834_tv-nq-ict-ob\docs\candidate-analysis\build_receipt_20260720.json `
  --run-root D:\QM\reports\candidate_analysis\QM5_10834\runs\WS30_ICT_OB_TRANSPORT_NATIVE_ATTEMPT_001 `
  --receipt D:\QM\reports\candidate_analysis\QM5_10834\runs\WS30_ICT_OB_TRANSPORT_NATIVE_ATTEMPT_001\pre_receipt.json
```

PRE dynamically proves that commit
`13e82258f5e7d514b50ed4c04787d8aa2e30eb5a` (`fix: tolerate metatester owner
lookup exit races`) is an ancestor of PRE HEAD. It then binds the current bytes
for this base auditor itself, the runner, WMI-fixed child, cleanup, credential
helpers, smoke runner, lane contract, and scheduled-task helper. Later unrelated
commits do not invalidate PRE by themselves; any bound runtime byte change does.

All freeze, PRE, launch, status, worker-job, and POST paths are confined to their
exact preregistered WS30 lexical paths before any inherited auditor read. Existing
path components must not be reparse points. A resolved alias into the WS30 tree,
or into an NDX claim/state/report tree, is therefore rejected before it is opened.

## Primary attempt and the only possible infrastructure alternate

The global counted-attempt budget is fixed at two:

- Primary attempt `001`: one atomic claim, one exact run root, one exact OWNER
  authorization scope
- Reserved infrastructure alternate `002`: at most one atomic claim, separate
  root and authorization scope
- Attempt `003+`: forbidden

Primary identities:

- Claim:
  `D:\QM\reports\candidate_analysis\QM5_10834\claims\QM5_10834_TV_NQ_ICT_OB_WS30_TRANSPORT_001_DEV2_NATIVE_ATTEMPT_001.json`
- Authorization:
  `D:\QM\reports\candidate_analysis\QM5_10834\runs\WS30_ICT_OB_TRANSPORT_NATIVE_ATTEMPT_001\native_outcome_authorization.json`
- Scope:
  `QM5_10834_WS30_TRANSPORT_PRIMARY_001_4_CELLS_X_2_DUPLICATES_MODEL4_MAX_4_NATIVE_STARTS_PER_CELL`

Reserved alternate identities:

- Root:
  `D:\QM\reports\candidate_analysis\QM5_10834\runs\WS30_ICT_OB_TRANSPORT_INFRA_ALTERNATE_002`
- Claim:
  `D:\QM\reports\candidate_analysis\QM5_10834\claims\QM5_10834_TV_NQ_ICT_OB_WS30_TRANSPORT_001_DEV2_NATIVE_ATTEMPT_002.json`
- Authorization:
  `D:\QM\reports\candidate_analysis\QM5_10834\runs\WS30_ICT_OB_TRANSPORT_INFRA_ALTERNATE_002\native_outcome_authorization.json`
- Scope:
  `QM5_10834_WS30_TRANSPORT_INFRA_ALTERNATE_002_4_CELLS_X_2_DUPLICATES_MODEL4_MAX_4_NATIVE_STARTS_PER_CELL`

The alternate is a reservation, not an automatic retry. It is ineligible after
a performance failure, after any native report exists, after strategy outcomes
are read/adjudicated, or after any parameter/gate/cost/symbol/date/model change.
It can only be activated from an immutable outcome-blind primary infrastructure
receipt in one of the three preregistered cause classes in the JSON contract.
No later cause class or exemption may be added retrospectively. The current
adapter authorizes only primary attempt `001`; that prevents an accidental
alternate launch before qualifying evidence exists.

The native-start counting boundary is the exact DEV2 `metatester64.exe` process
start. Claim-file creation alone does not count. Per cell, the existing auditor
still permits at most two outcome-blind zero-result warmups followed by exactly
two accepted duplicate runs, for a maximum of four starts per cell.

## Outcome fence

- Before launch: no report, Deal, price, or strategy outcome is read.
- Worker: persistent scheduled task; seals native artifacts as opaque bytes.
- Status: only state/cell status is exposed.
- POST: only a structurally COMPLETE launch state can open reports.
- POST rechecks real-tick Model 4, headers, input closure, lifecycle/session
  invariants, zero native/simulated commission, cost ledger, exact duplicates,
  and the unchanged merit gates.

Until the two prerequisites above land, stop after static tests. Do not create
an authorization, claim, task, or MT5 run.
