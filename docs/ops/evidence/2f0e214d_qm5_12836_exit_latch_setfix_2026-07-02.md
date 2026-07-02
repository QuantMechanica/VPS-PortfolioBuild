# QM5_12836 Exit-Hour/Latch Fix Evidence

Task: `2f0e214d-ba67-4144-baa8-005c6a49c799`
EA: `QM5_12836_turnaround-tuesday-ws30`
Date: 2026-07-02

## Changes

- Corrected hard exit mapping from broker `22` to broker `23` for 16:00 ET under the DXZ ET+7 convention.
- Replaced the weekly setup latch with `QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1)` so the latch is calendar-key based instead of raw `iTime` equality.
- Moved `g_entry_taken` burn to the successful `QM_TM_OpenPosition` path; failed sends can retry instead of consuming the weekly entry.
- Updated `SPEC.md` and the approved runtime card with the corrected ET-to-broker arithmetic.
- Verified regenerated backtest sets pin card/default strategy params and `exit_hour=23`.

## Verification

- Compile: `python tools/strategy_farm/compile_ea.py --ea-label QM5_12836_turnaround-tuesday-ws30 --force --json`
  - Verdict: `COMPILED`
  - Errors: `0`
  - Warnings: `0`
  - Ex5: `C:\QM\repo\framework\EAs\QM5_12836_turnaround-tuesday-ws30\QM5_12836_turnaround-tuesday-ws30.ex5`
  - Compile log: `C:\QM\repo\framework\build\compile\20260702_054257\QM5_12836_turnaround-tuesday-ws30.compile.log`
- Guardrails: `python tools/strategy_farm/validate_build_guardrails.py ...QM5_12836...`
  - Verdict: `PASS`
  - `qm_news_stale_max_hours=336`
  - Backtest sets remain `RISK_FIXED > 0` and `RISK_PERCENT = 0`
- Setfile check:
  - No `qm_filter_*` dead keys.
  - No `card_defaults_source=not_found`.
  - All four Q02 setfiles carry `qm_ea_id=12836`.
  - WS30/SP500/NDX/GDAXI setfiles all pin `exit_hour=23`.

## Queue State

`farmctl work-items --ea QM5_12836` shows Q02 retries pending for:

- `GDAXI.DWX`: `1529a5a3-1048-4ab7-bd7e-44f30c26c56a`
- `NDX.DWX`: `5da57408-d6ce-406f-96b8-9c897f0f1678`
- `WS30.DWX`: `f4b5ad9f-88c3-4df7-bacb-7d7c87a79ecf`

No terminal was started manually and no active backtest was interrupted.
