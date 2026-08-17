# QM5_11011 diverse FX build recovery — Q01 PASS, Q02 deferred at CPU ceiling

Date: 2026-08-17

Branch: `agents/board-advisor`

EA: `QM5_11011_the5ers-pinbar-sr`

Farm claim: `3e2b5c57-4759-4188-94fa-be8cf0fa285e`

Build task: `fb0901f0-072d-461d-a056-fa7b66fff818`, recovery generation 1

## Outcome

The approved structural H4 pin-bar/support-resistance EA is now a complete,
current V5 Q01 build package. Static build validation and strict compilation
pass, and five governed H4 backtest setfiles use fixed $1,000 risk. The prior
permanent build failure was not a strategy defect: `build_check.ps1` treated a
source-citation URL in an MQ5 comment as a forbidden external-data API.

No smoke or Q02 work item was started. The host exceeded the farm's hard CPU
admission ceiling immediately after Q01, so the paced-fleet stop rule was
applied. The build task is returned to `pending` with
`blocked_reason=backtest_cpu_ceiling_after_q01_pass`; no build-result JSON is
materialized for automatic recording.

## Diversity selection and collision control

The first eligible priority was the approved `QM5_20042` Brent DOM17 card,
which would add energy beyond XNG. It was left untouched because XBR custom
symbol validation could not pass: T1-T5 contained only February-May 2026
history/ticks, no reproducible Tick Data Manager export, no October/November
DST evidence, and no validated symbol-matrix/history-range record. That is an
availability gap, not authority to infer validation.

The next eligible preallocated low-frequency row was `QM5_11011`: an approved
H4 structural reversal rule sourced to The5ers Team's 2020 pin-bar article,
with frontmatter R1-R4 PASS and an expected 35 trades/year/symbol. It adds three
governed FX paths (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`) rather than another
index/metal/energy-only survivor. Existing registry identities were reused
without mutation:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `EURUSD.DWX` | 110110000 |
| 1 | `GBPUSD.DWX` | 110110001 |
| 2 | `USDJPY.DWX` | 110110002 |
| 3 | `XAUUSD.DWX` | 110110003 |
| 4 | `GDAXI.DWX` | 110110004 |

`GDAXI.DWX` is the registered canonical DAX symbol used for the card's
`GER40.DWX` label. Before implementation, the target had no work item or
competing live farm claim. The pre-claim database backup is
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11011_build_recovery_claim_20260817T112903Z.sqlite`.

## Scoped build recovery

- Removed the literal URL from the MQ5 citation comment while retaining the
  source ID and full citation in `SPEC.md` and the localized Strategy Card.
- Added explicit H4 execution-contract binding, the first-statement Q08 MAE
  hook, entry-only news gating, explicit H4 new-bar binding, and zeroed entry
  request initialization from current V5 wiring.
- Preserved the approved pin geometry, swing-cluster S/R rule, ATR filters,
  pending stop entry, opposite-wick SL, 2R TP, midpoint exit, 20-bar timeout,
  and all strategy parameter defaults.
- Localized the approved Strategy Card byte-for-byte and refreshed the spec
  revision record.
- Generated one H4 `backtest` setfile for each registered symbol. Every file
  has `RISK_FIXED=1000`, `RISK_PERCENT=0`, the correct slot, and all 15 strategy
  inputs. No live setfile was created.

## Q01 evidence

| Check | Result |
|---|---|
| Approved build prerequisite guard | PASS: active EA row, magic rows, EA directory |
| Approved-card localization | exact content match, 5,408 characters |
| `validate_spec_doc.py` | PASS, 1/1 |
| `validate_build_guardrails.py` | PASS for MQ5 and all five setfiles; no findings |
| `validate_symbol_scope.py --fail-on-leak` | `SINGLE_SYMBOL_OK`, 0 violations |
| `build_check.ps1` with real logger sample | PASS, 0 failures, 1 pre-setfile warning |
| Explicit `compile_one.ps1 -Strict` | PASS, 0 errors, 0 warnings |

- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260817_113748.json`.
- Strict compile summary:
  `D:\QM\reports\compile\20260817_114128\summary.csv`.
- Strict compile log:
  `C:\QM\repo\framework\build\compile\20260817_114128\QM5_11011_the5ers-pinbar-sr.compile.log`.

| Artifact | SHA-256 |
|---|---|
| MQ5 | `2769814b3ea1895f4e4c0cbcc0fad81b0f6ae576120218545c68d11797c8a161` |
| EX5 | `ff24f7d05bd0686452e17f958251dbd85e21d2f9999ef1e8ae9c600573066650` |
| SPEC | `d90a0a8f2e0d90d2612dc284a22f385523eaab52ca2fffd23efe5683c2768d9d` |
| Localized card | `d20d5193f59ae045f2125de393e83746e8e4cd47c98aa99b021f40c9795d3794` |
| EURUSD setfile | `699b5e85e131f9fd271ad11d339cb75d6f601c9cab3d86888202a75a2aea6999` |
| GBPUSD setfile | `b913363a4e0851c8a339a493bae0211b988ced63463a28a7c0d1f5cf9871f296` |
| USDJPY setfile | `bb40a742ca322a7ad37607b09f038eaa3a903e6f2783e794e670a99b570a59d9` |
| XAUUSD setfile | `02e38c3a961623b388aebc1068699743fbf473963747f7ebdf0b6732cc6691c1` |
| GDAXI setfile | `e135e9333142e74daff3efcd63591912a41bb086ee393cf87f387ec90a489415` |

## CPU-ceiling stop

At `2026-08-17T11:44:29.5072235Z`, five two-second host CPU samples were
`99.7559%`, `98.3452%`, `98.4439%`, `98.9360%`, and `98.8376%` (average
`98.8637%`). Every sample exceeded the worker admission ceiling
`CPU_MAX_LOAD_PERCENT=97.0`. Exact path-anchored inspection found eight
governed T1-T10 terminals (`T1`, `T2`, `T3`, `T4`, `T6`, `T7`, `T8`, `T10`)
and six metatesters. T_Live and non-factory terminals were excluded and not
controlled.

The operation therefore stopped before `run_smoke.ps1`, `record-build`, or Q02
enqueue. No process, terminal, reservation, or existing work item was started,
stopped, released, or dispatched.

## Deterministic continuation

When a fresh sustained CPU sample is below 97% and governed capacity is free:

1. verify the hashes above and confirm that `QM5_11011` still has no work item
   or competing claim;
2. atomically reclaim build task
   `fb0901f0-072d-461d-a056-fa7b66fff818` generation 1;
3. run exactly one governed H4 smoke on `EURUSD.DWX` through `-Terminal any`;
4. materialize the build result and use canonical `record-build` to enqueue
   the five append-only Q02 rows without manual dispatcher intervention.

## Safety boundary

No T_Live file or process, AutoTrading setting, live/deploy manifest, portfolio
gate, or portfolio-admission artifact was touched. This records Q01 build
fitness only; no efficacy, decorrelation, certification, or portfolio claim is
made.
