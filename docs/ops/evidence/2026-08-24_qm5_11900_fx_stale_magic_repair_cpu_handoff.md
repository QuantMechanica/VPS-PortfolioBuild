# QM5_11900 FX stale-magic Q02 recovery — source repair complete, CPU-ceiling handoff

Date: 2026-08-24

Branch: `agents/board-advisor`

EA: `QM5_11900_kobasfx-4ema-macd-sentiment-h1`

Farm task: `46e34047-c661-462c-96d5-b4f9d76914db`

Outcome: **SOURCE/SPEC/SET REPAIR PASS; GOVERNED COMPILE ELIGIBLE; COMPILE AND
Q02 RERUN DEFERRED AT THE 97% CPU CEILING**

## Diversity selection and collision control

The canonical router had no `BACKLOG` build rows. Its only Codex `TODO`
build, QM5_20175, was explicitly deprioritized because it has no active magic
rows; building it would violate the deterministic Q01 precondition. Two other
builds, QM5_20065 and QM5_20077, were already `IN_PROGRESS` on the Gemini lane.
No eligible priority-1 build was therefore available without colliding or
bypassing a registry gate.

The existing priority-100 `q02_infra_repair` row for QM5_11900 was advanced
atomically from `RECYCLE` to `IN_PROGRESS`. It is a ten-symbol H1 FX sleeve,
while the current Q08 soft survivors are concentrated in indices, metals, and
energy. No other open agent task claimed QM5_11900 at selection time.

## Deterministic failure diagnosis

The July Q02 evidence is infrastructure-only. For example,
`D:/QM/reports/work_items/7eb8a129-07d5-4e36-b96a-9d0366412f66/QM5_11900/20260728_131837/summary.json`
records:

- `result=FAIL`, `reason_classes=[ONINIT_FAILED, INCOMPLETE_RUNS]`;
- `BARS_ZERO`, zero trades, and no economic verdict;
- source and deployed EX5 both at SHA-256
  `16c7f328707e6e530360090a4e91e319bab02518dccd0b8cd5c0e65d787e2cfa`;
- EX5 last-write time `2026-06-21T15:06:47Z`;
- source and deployed setfiles byte-identical during the run.

The governed allocator did not reserve QM5_11900's ten active magic rows until
2026-08-17 (commit `ee93708a6`). The failed June binary therefore predates the
only resolver version that can recognize EA 11900. The current resolver was
read back mechanically and contains all ten exact rows, slots 0–9 and magics
119000000–119000009.

The old setfiles added a second deterministic defect after that allocation:
all ten forced `qm_magic_slot_offset=0`. Only AUDJPY owns slot 0; the other nine
symbols own slots 1–9. This would keep those symbols fail-closed even after a
fresh compile.

## Repair applied

The approved EMA/MACD entry, stop, take-profit, and exit rules were not changed.
The recovery is limited to current framework and execution plumbing:

- default tester risk now has `RISK_PERCENT=0` and `RISK_FIXED=1000`;
- the Q08 open-position MAE hook is first in `OnTick`;
- news blackout gates only new entries, leaving management and exits active;
- `QM_EntryRequest` is zero-initialized and its expiration is explicit;
- framework init/deinit evidence logging is restored;
- the three card-authorized closed-bar OHLC reads carry bounded
  `perf-allowed` annotations;
- the previously missing seven-section `SPEC.md` is complete;
- all ten canonical H1 backtest setfiles were regenerated from the approved
  card and active registry. They bind slots 0–9 respectively and each contains
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The ordinary compile classifier correctly refuses overwrite of an existing
binary with historical work. A narrowly scoped source-repair authority was
added for this exact farm task and exact EA label. Its read-only classification
is now `eligible=true`, `source_repair_authorized=true`, with only
`EX5_ALREADY_PRESENT` and `WORK_ITEMS_EXIST` waived. No other EA can use this
authority.

## Validation

- `skill_build_ea_guard.py`: PASS (`ea_registry_row`, `magic_registry_rows`,
  and `ea_dir_exists`).
- `validate_spec_doc.py`: PASS (1 PASS, 0 FAIL).
- `validate_build_guardrails.py`: PASS across 11 files, zero findings.
- `tools/strategy_farm/tests/test_compile_work_items.py`: 17 passed.
- Governed compile classification: ELIGIBLE, ten active magic rows, H1 resolved
  from the setfiles, repaired source SHA-256
  `261570f12ae7708e58c64f008a9029df35e147882b716cc4143e807ebb41a656`.
- Scoped `git diff --check`: PASS.

`update_magic_resolver.py --dry-run` was intentionally fail-closed because
three unrelated active registry IDs (1001, 1015, 1016) lack materialized EA
directories. It wrote nothing. No resolver regeneration was needed for this
repair because the current 17,991-row resolver already contains all ten
QM5_11900 mappings.

The single standard build-check admission attempt stopped before compile or
static build execution with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because
factory `terminal64` processes were alive. No compile retry was attempted.

## Binding CPU-ceiling stop

Five consecutive whole-host `Processor(_Total)` samples at
`2026-08-24T04:28:15Z` were 88.89%, 98.34%, 96.00%, 94.63%, and 98.73%.
The average was 95.32% and the peak was 98.73%, above the governed 97% ceiling.
The same read-only snapshot found no duplicate workers or orphaned terminal
processes. This is the mission's explicit stop condition.

No compile utility row, smoke test, Q02 preview, Q02 rerun, dispatcher tick,
terminal reservation, tester launch, or manual terminal action was performed.
The stale EX5 remains evidence and is not represented as repaired. Q02 remains
correctly gated by a fresh compile and final build binding.

## Safe continuation

After sustained host CPU is below 97%, enqueue the exact source-hash-bound
compile successor through the governed path:

```powershell
python tools/strategy_farm/farmctl.py enqueue-compile `
  QM5_11900_kobasfx-4ema-macd-sentiment-h1 `
  --source-repair-authority router_q02_infra_repair:46e34047-c661-462c-96d5-b4f9d76914db
```

Require `COMPILE_OK`, strict build-check PASS, zero errors/warnings, a new EX5
hash, and final (non-`pending`) setfile build bindings. Then append one governed
USDCHF Q02 canary from the immutable timeout row, binding the new EX5 hash:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_11900 --phase Q02 `
  --append-only-rerun-of fe21ca57-20eb-44af-90f1-d961618b2900 `
  --rerun-reason "stale pre-magic-allocation EX5 and slot-0 setfiles repaired" `
  --expected-current-ex5-sha256 <NEW_COMPILE_OK_EX5_SHA256>
```

No AutoTrading action, `T_Live` write, live/deploy-manifest change,
portfolio-gate change, portfolio admission, or certification claim occurred.
