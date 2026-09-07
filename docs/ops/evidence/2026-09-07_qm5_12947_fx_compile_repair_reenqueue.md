# QM5_12947 FX compile repair and Q02 re-enqueue

Date: 2026-09-07

Branch: `agents/board-advisor`

EA: `QM5_12947_mql5-ha-ema-trend-card`

## Outcome

Repaired the diverse FX sleeve's framework-static compile blocker without changing its strategy mechanics. The governed compile completed `COMPILE_OK`, and the existing held Q02 work item was released against the newly compiled binary.

## Scope and coordination

- Durable PACER claim: agent task `94c8da39-a1f3-44b9-9f6c-45bf54ff4981`.
- Previous governed compile: `e4bcce97-6655-45b9-92b8-8702d8c07966`, `COMPILE_FAIL` on `EA_FRAMEWORK_RAW_SERIES_CALL` despite the MQL5 compiler reporting zero errors and zero warnings.
- Existing Q02 repair row: `fc014472-3b6e-4b31-a232-7b462132f0dc`, held with `MAE_HOOK_RECOMPILE_REQUIRED` until a current binary existed.
- Instruments remain the reviewed registry allocation: `EURUSD.DWX`, `GBPUSD.DWX`, and `GDAXI.DWX`, all H1. No magic or portfolio registry was changed.

## Repair

- Replaced direct `Bars`, `iClose`, `iHigh`, and `iLow` calls with `QM_ReadBar` framework accessors.
- Moved the news entry gate below Friday-close and open-position management, restoring entry-only news gating.
- Left all `strategy_*` parameters and entry/exit mechanics unchanged.

## Guard and validation evidence

- Mandatory pre-enqueue PACER audit:
  - command: `python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12947_mql5-ha-ema-trend-card/QM5_12947_mql5-ha-ema-trend-card.mq5`
  - result: PASS, `EA_FRAMEWORK_INPUT_PINNED` hit count `0`.
- Source SHA-256 bound at compile intake: `da6ea5c27ee771dbb0a62dbc65f7939110c355fbfb795e7fecbfa1488fbc3f0d`.
- `build_gate_hardening.py`: PASS, zero failures and zero warnings.
- `validate_spec_doc.py`: PASS.
- An ad-hoc `build_check.ps1 -SkipCompile` attempt was correctly refused by `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no ad-hoc compile was used.
- Governed compile work item: `5d074dcd-7192-4460-9731-06f1aeeba472`.
- Governed compile verdict: `COMPILE_OK`; build check PASS; compiler errors `0`, warnings `0`.
- New EX5 SHA-256: `6818157a429d98e15b5a1edb019c8d138f4784f329d560d20c3fb35468f715d2`.
- Three regenerated backtest setfiles use `RISK_FIXED` and retain the three active magic slots.

## Queue handoff

After `COMPILE_OK`, release eligibility for Q02 row `fc014472-3b6e-4b31-a232-7b462132f0dc` was checked with `--dry-run` and returned `would_release: true`. The exact hold was then released at `2026-09-07T03:41:12+00:00`, ledger sequence `3105`, with the compile work-item and EX5 hash in the release note. The row remains pending for the governed tester fleet; no terminal was launched manually.

The sampled CPU load before handoff averaged `82.56%` (maximum `88.11%`) against the `97%` ceiling, so the ceiling was not hit.

## Card symbol note

The older card prose still names `GER40.DWX`, while the approved implementation review and deterministic active magic rows use `GDAXI.DWX`. A fresh `build-ea` precheck therefore emitted agent task `269ac1c4-1986-4e1a-a7cc-2965c52984c8`. This repair made no symbol or registry mutation and relied on the existing approved implementation plus OWNER-authorized force-rebuild path; the stale card prose should be handled separately under OWNER card-amendment authority.
