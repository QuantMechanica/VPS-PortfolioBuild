# QM5_20012 host-entry review rework

Date: 2026-08-06
Branch: `agents/board-advisor`
Farm build task: `06aa245f-b650-4088-bb34-1c0718f1f14c` (generation 1)
Router task: `8e56ec8d-ac8f-48ab-9b4e-65db3fd0c270`

## Selection and claim

`QM5_20012_xauxag-cmtar` was the only row accepted by the farm's deterministic
build-task claim guard from the approved build backlog. It is a low-frequency
D1 XAU/XAG C-MTAR relative-value package, so it adds a market-neutral pair lane
rather than another index/metal/energy directional clone. The approved card is
backed by Mighri and Al Saggaf (2018), and the existing deterministic registry
rows were already active:

- slot 0: `XAUUSD.DWX`, magic `200120000`
- slot 1: `XAGUSD.DWX`, magic `200120001`

No registry file was changed. The farm build-dispatch claim and a distinct
router task were acquired before editing.

## Review finding repaired

The generation-0 Codex review rejected the execution boundary because both
legs were routed through `QM_BasketOpenPosition`. The framework contract allows
that helper only for off-chart legs; the chart-host leg must pass through
`QM_TM_OpenPosition`.

The generation-1 source now:

1. Computes the joint XAU/XAG package and its fixed-risk lot split exactly as
   before.
2. Resolves the joint-sized XAU volume to an explicit framework risk share.
3. Opens only the off-chart XAG leg through `QM_BasketOpenPosition`.
4. Returns the XAU request through `Strategy_EntrySignal` and opens it through
   `QM_TM_OpenPosition`.
5. Immediately closes all owned legs if the host open fails or the completed
   package violates the composition or hedge checks.

Signal constants, C-MTAR orientation, monthly cadence, ATR stops, time stop,
and the joint risk/hedge constraints are unchanged. The canonical set remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Validation

- `validate_spec_doc.py`: PASS.
- `build_check.ps1`: PASS, 0 failures, 0 warnings.
- MetaEditor compile: PASS, 0 errors, 0 warnings.
- Compile log: `C:/QM/repo/framework/build/compile/20260806_065105/QM5_20012_xauxag-cmtar.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_065105/summary.csv`.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260806_065105.json`.
- MQ5 SHA-256: `D8A4FFEAC67E52ADBEF7E9643181CADF57EBF226BA4E46AFA340BA0C1550043E`.
- EX5 SHA-256: `A02C1387DDB000C39599A03FD1779D3A1EC3B514D68CB2DCB5A388B82BBACB5D`.
- Setfile SHA-256: `AA2D0BFEE98104672F36A17F84913B248F442CFB9ADF5E6609C53F59CA135F28`.
- Setfile build hash: `ffaeb08abe752065533b44ef4628811f4e88cc318ec68008ddb07a50b727a06a`.

The deterministic artifact pump captured the regenerated EX5 and setfile in
commit `2b9dbd869f65234d412dd5bb46692f7b5c7d2131` while this repair was in
progress. The scoped source/SPEC/evidence commit completes the same unit.

## Paced-fleet smoke boundary

Exactly one smoke-harness invocation was started for `XAUUSD.DWX`, D1, 2024,
using the canonical logical-basket setfile. It was stopped when terminal
contention became explicit:

- smoke root: `D:/QM/reports/smoke/QM5_20012/20260806_065321`
- runs 01-03 each captured `QM5_11422_ea-11422.log`
- those logs identify `ea_id=11422`, `symbol=USDCAD.DWX`, not QM5_20012/XAU
- run 04 had only `tester.ini` when the wrapper was stopped
- no valid QM5_20012 smoke summary was produced
- after the stop, no `terminal64.exe` process referenced the QM5_20012 smoke
  path; the factory scanner showed nine running T1-T10 terminals and workers
  resident for all ten slots

This is `framework_error`/fleet capacity, not `zero_trades` and not a strategy
failure. No second smoke invocation was launched. The build result therefore
requests the standard deferred P2 smoke path and a fresh Q02 enqueue rather
than spending more manual backtest CPU.

## Safety boundary

No T_Live file, AutoTrading state, deploy manifest, live manifest, portfolio
gate, portfolio admission rule, or portfolio KPI was changed. No optimization
or pipeline backtest was manually dispatched.

## Mandatory Codex acceptance review

The headless orchestration cycle independently reviewed the completed repair
before returning the router task to REVIEW. It did not self-approve the EA or
assign a Q02 verdict.

Preflight under `qm-build-ea-from-card` passed:

- approved card: `g0_status: APPROVED`, EA `QM5_20012`, slug `xauxag-cmtar`;
- active EA registry row: `20012 / xauxag-cmtar`;
- active magic rows: slot 0 `XAUUSD.DWX / 200120000`, slot 1
  `XAGUSD.DWX / 200120001`;
- card, EA folder, EA file, and registry slug align; the compiled EA label is
  within the framework name bound.

The source review confirmed the repaired execution boundary:

- the source contains exactly one `QM_BasketOpenPosition` call;
- that call is confined to `Strategy_OpenForeignLeg`, which rejects `_Symbol`,
  any symbol other than `XAGUSD.DWX`, and any slot other than 1;
- `Strategy_PreparePair` returns the fully populated XAU slot-0 request and
  never invokes the host order helper itself;
- `OnTick` submits the XAU request through the explicit-risk overload of
  `QM_TM_OpenPosition` and immediately closes the package if the host open,
  two-leg composition, or hedge check fails;
- `Strategy_ResolveHostRisk` supports exactly one active risk mode, scales the
  framework risk value to the joint-sized XAU target, and round-trips the
  framework lot calculation to within one tenth of a volume step before XAG is
  sent.

The canonical source and artifacts exactly match the recorded generation-1
build result: MQ5 `D8A4FFE...0043E`, EX5 `A02C138...CB5D`, SPEC
`C1BD125...7033`, basket manifest `5A94DE1...FC43C`, and setfile
`AA2D0BF...35F28`. The retained strict compile is therefore bound to the
reviewed source and reports 0 errors / 0 warnings; no canonical recompile was
performed after the governed Q02 handoff.

Fresh focused verification on the reviewed tree:

- build check with `-SkipCompile`: PASS, 0 failures, 0 warnings —
  `D:/QM/reports/framework/21/build_check_20260806_071925.json`;
- SPEC validation: PASS;
- build guardrails: PASS, including `qm_news_stale_max_hours=336`;
- symbol scope: `BASKET_OK`, 0 violations;
- host-entry and basket-manifest regression tests: 43 PASS;
- regression file:
  `tools/strategy_farm/tests/test_qm5_20012_host_entry_static.py`.

The build recorder already created exactly one open governed handoff,
`37f826f9-3423-4e8d-94ec-95a2fc8ee43f`, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, status `pending`, and no verdict. It was not duplicated or
manually run. The older Q02 PASS belongs to the pre-review binary and is not a
verdict for this repaired generation; pipeline authority remains with the new
row's future evidence.
