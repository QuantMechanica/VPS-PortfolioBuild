# QM5_11421 FTMO demo Signature Chart Panel canary

Task `c8e01483-ef2a-41de-bab4-a950e08b5620` is complete for REVIEW. The shared `QM_ChartPanel.mqh` presentation component is wired into QM5_11421 without changing entry, exit, sizing, news, Friday-close, or kill-switch decisions.

## Wiring

- `qm_show_chart_panel=true` is an opt-out input in the QuantMechanica V5 Framework input group.
- `qm_panel_build_hash` is supplied by the demo preset and equals the freshly compiled EX5 SHA-256; the EA does not infer identity from a runtime file.
- Initialization occurs after magic/environment/execution-contract resolution. A successful visual/live initialization reuses the EA timer at a five-second cadence.
- Refresh occurs only from `OnTimer`. Non-visual tester initialization returns false in the shared component and therefore does not arm panel work.
- Shutdown precedes framework shutdown in `OnDeinit`.
- The snapshot reads existing framework state: news active/load/cache verdict, Friday-close due state, kill-switch halt state, runtime environment, configured risk mode/value, and framework heartbeat. Exposure remains the shared component's read-only sum for this magic.

Expected panel lines after OWNER attachment:

```text
QM | QUANTMECHANICA
EA 11421 | ohlc-daily-squeeze-reversal-d1
EURUSD / D1 | MAGIC 114210000
GOVERNANCE: NEWS <state> | FRI <state> | GOV <state> | ENV LIVE
RISK / EXPOSURE: RISK_PERCENT 0.3125 | OPEN <magic exposure>
HB OK | <broker time> | BUILD 48fddf28045a034e8365d948aa19fcf108002493a76a03f0b6cc1451bcfee15c
```

## Build and installation

The source was copied into the isolated artifact root `D:/QM/ftmo/compile_probe_panel_11421_20260907`, together with a private include mirror. FTMO MetaEditor produced `0 errors, 0 warnings`; the canonical `framework/EAs/*.ex5` inventory was never written. The artifact SHA-256 is `48fddf28045a034e8365d948aa19fcf108002493a76a03f0b6cc1451bcfee15c`.

The previous demo EX5 and both prior presets are recoverable under `_pre_panel_11421_20260907_0515Z`. The fresh binary is installed only under the FTMO demo data folder `MQL5/Experts/QM_FTMO`. Both the Load-dialog preset and Profiles copy have SHA-256 `c60ac4b1a6752bd1febbacca51229ebb65ccfb653b1700ef845f95a1cffd4442` and contain `qm_show_chart_panel=true` plus the compiled build identity prefix `48fddf28`. See `install_receipt.json` and `compile.log`.

`validate_build_guardrails.py` passed with zero findings and the 336-hour news ceiling intact. The common component acceptance and canary lifecycle tests passed (3 tests). The canonical `build_check.ps1 -Strict -SkipCompile` was attempted but correctly refused before checks with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because T1-T10 terminal64 workers are active; no retry, bypass, worker interruption, or pipeline identity mutation was attempted. The task's separately authorized isolated FTMO MetaEditor build supplied the native compile proof.

## OWNER action — exactly three lines

1. In the FTMO demo terminal, open/choose the EURUSD D1 chart; do not change the existing AutoTrading state.
2. Load `QM5_11421_EURUSD_D1_live_trial.set` and attach `QM5_11421_ohlc-daily-squeeze-reversal-d1`; any trading-state change remains a separate OWNER/governor procedure.
3. Confirm the six panel lines above (especially `ENV LIVE`, `RISK_PERCENT 0.3125`, and BUILD `48fddf28...`) and capture the requested screenshot.

No chart was attached by this task. `terminal64.exe` was not started, T_Live and T1-T10 were untouched, and AutoTrading was not changed. The next seven sleeve integrations and the governor-specific panel remain outside this canary ticket.
