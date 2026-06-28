# QM5_9229 DeMarker Divergence Q02 Infra Repair

Date: 2026-06-28
Agent: codex:agents/board-advisor
Branch: agents/board-advisor

## Scope

Repaired `QM5_9229_mql5-dem-div`, a built H1 forex DeMarker divergence EA stuck at Q02 preflight with `ex5_missing`.

Root cause: the EA still carried local `QM_IndDeMarker` / `QM_DeMarker` helper bodies after the shared framework added those functions in `QM_Indicators.mqh`. Strict compile failed on duplicate function bodies, so no fresh `.ex5` existed for Q02 preflight.

Fix: removed only the duplicate local DeMarker helper block. The strategy now uses the shared framework helper implementation.

No portfolio gate, T_Live manifest, AutoTrading state, or manual MT5 backtest was touched.

## Verification

- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260628_060901\QM5_9229_mql5-dem-div.compile.log`
- Rebuilt artifact: `C:\QM\repo\framework\EAs\QM5_9229_mql5-dem-div\QM5_9229_mql5-dem-div.ex5`
- Artifact size after compile: 280048 bytes.
- Targeted build check: PASS, 0 failures, 16 shared-framework DWX advisory warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260628_061135.json`
- Build-check compile log: `C:\QM\repo\framework\build\compile\20260628_061135\QM5_9229_mql5-dem-div.compile.log`
- FX setfiles verified present and `RISK_FIXED=1000`.
- DWX H1 history registry coverage verified for both requeued symbols: first year 2017, last year 2026.

## Q02 Re-Enqueue

Fresh pending Q02 work items were inserted after confirming no active or pending Q02 rows existed for these EA/symbol pairs.

DB backup before insert: `D:\QM\strategy_farm\state\backups\farm_state_pre_qm5_9229_q02_requeue_20260628_061104Z.sqlite`

| Work item | Symbol | Timeframe | Source failure |
| --- | --- | --- | --- |
| `29a05977-c332-4224-8474-632401e98fb0` | `EURUSD.DWX` | `H1` | `a7d462bb-50bc-4aa6-aac6-318131331d93` |
| `ade5a866-6487-414c-b5f8-0dee8c21862c` | `GBPUSD.DWX` | `H1` | `6720e231-0b59-458d-ba17-f84ea0aa0d2b` |

Farm DB event: `q02_reenqueued_after_infra_fix` for `QM5_9229`.

The paced MT5 worker fleet owns Q02 execution from these pending rows.
