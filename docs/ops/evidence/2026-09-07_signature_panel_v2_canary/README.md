# QM5_11421 Signature Panel v2 light canary

- Router task: `b020c337-ee9f-47f2-9c33-f6cf0ab4afea`
- Dependency: `docs/ops/evidence/2026-09-07_signature_panel_v2_spec/README.md`
- OWNER amendment: `docs/ops/evidence/2026-09-07_signature_panel_v2_spec/AMENDMENT_LIGHT_SCHEME.md`
- State: `REVIEW`
- Scope: presentation-only source revision, artifact-only compile, and FTMO demo-only install

## Result

Signature Panel v2 is implemented for the QM5_11421 canary. When `qm_show_chart_panel=true`, the EA suppresses the legacy framework `QM_ChartUI` before framework initialization, so only the `QM_SIG_11421_<magic>_*` namespace is created. The new panel is timer-refreshed, tester-inert, read-only, and has no calls from `OnTick`.

The panel now displays the final presentation state for trading permission/reason, news and next-block countdown, Friday-flat countdown, governor binding, exact kill-switch state/reason, spread/session, configured/effective risk, daily and total room, SL-priced exposure, balance/equity/today P/L, per-magic position and pending-order summaries, next bar, last signal/trade, heartbeat/tick/connection, calendar source, build, masked account login, license, and MQL5 support route. Missing producer contracts are explicit: this legacy-contract canary shows governor `UNBOUND`, total room `N/A`, strategy signal `N/A`, and native event name `unavailable` rather than inventing values.

No entry, exit, sizing, news, Friday-close, kill-switch, pending-order, or position-management rule changed. The only framework-wide change is an opt-in legacy-chart-UI suppression switch whose default remains false.

## Light chart and panel scheme

`QM_ChartScheme_Apply(chart_id)` captures every property before applying the scheme. `QM_ChartScheme_Restore(chart_id)` restores the exact snapshot on deinit; a partial apply rolls itself back.

| MT5 property | V2 value | Purpose |
|---|---|---|
| `CHART_COLOR_BACKGROUND` | `#FFFFFF` | Color on White base |
| `CHART_COLOR_FOREGROUND` | `#0F172A` | Dark axis/text |
| `CHART_COLOR_GRID` | `#CBD5E1`, with `CHART_SHOW_GRID=false` | Subtle opt-in grid token; hidden by default |
| `CHART_COLOR_CHART_UP`, `CHART_COLOR_CANDLE_BULL` | `#059669` | Emerald bullish bars/candles |
| `CHART_COLOR_CHART_DOWN`, `CHART_COLOR_CANDLE_BEAR` | `#EF4444` | Red bearish bars/candles |
| `CHART_COLOR_BID`, `CHART_COLOR_ASK`, `CHART_COLOR_LAST` | `#2954D4` | Steel-blue price lines |
| `CHART_COLOR_VOLUME` | `#2954D4` | Steel-blue volume |
| `CHART_COLOR_STOP_LEVEL` | `#EF4444` | Stop level |
| `CHART_MODE` | `CHART_CANDLES` | Consistent candle view |
| `CHART_SCALE` | `3` | Readable default scale |
| `CHART_SHOW_BID_LINE`, `CHART_SHOW_ASK_LINE` | `true` | Visible live prices |

Panel tokens share the same white/slate/steel/emerald/red palette, with `#F8FAFC` as the card surface and amber for degraded or unavailable state.

## Implemented panel mockup

```text
QM | QUANTMECHANICA
EA QM5_11421 | ohlc-daily-squeeze-reversal-d1 | v5.0 | BUILD d90cfa27
EURUSD.DWX / D1 | MAGIC 114210000 | DEMO | LOGIN ****6732
TRADING NO | AUTOTRADING_DISABLED
NEWS OPEN | LIVE MT5 NATIVE | next HIGH event/name unavailable in 03:12:00
GOV UNBOUND legacy execution contract | KS ARMED
FRI OK 2d 04:31 | SPREAD PASS 0.20/25.00 pip | SESSION N/A
RISK RISK_PERCENT 0.3125 | EFFECTIVE 0.3125%
ROOM DAILY $... / ...% | TOTAL N/A (governor unbound)
EXPOSURE SL $...
BAL ... | EQ ... | TODAY +... (N trades)
POS BUY ... / NONE
ORD ... / NONE
NEXT BAR 2026.09.08 00:00:00 (...)
LAST SIGNAL N/A (strategy hook absent)
LAST TRADE ... / NONE
HEALTH HB OK | TICK ...ms | CONNECTION UP
CAL LIVE MT5 NATIVE OK
LICENSE LICENSE_FULL | Support: MQL5 comments/messages
```

## Single-source object census

The source census is in `object_census.json`.

- Before: framework-created `QM5_UI_11421_*` plus v1 `QM_SIG_11421_*` (10 logical objects) could coexist and overlap.
- After: enabled v2 sets `QM_FrameworkSetChartUISuppressed(true)` before framework init. Legacy init, refresh, and shutdown are all guarded. Expected legacy object count is zero; v2 owns 22 logical objects and deletes all 22 on shutdown.
- The runtime after-census remains pending because this task did not attach/re-attach the EA or manipulate the running terminal. It is an OWNER visual acceptance step, not a reason to automate chart control.

## Build and installation

- Header-only native probe: `D:/QM/ftmo/compile_probe_panel_v2_header_20260907_r2`; `0 errors, 0 warnings`; EX5 SHA-256 `0e8a6a89569b6a616954d0c1ebffef5e880fc6290da88f5ec67cd3f80ea9ccff`.
- Full canary artifact: `D:/QM/ftmo/compile_probe_panel_v2_20260907`; `0 errors, 0 warnings`.
- Full canary EX5 SHA-256: `d90cfa27d37326b2a9de0b0a561019baf5639d3be9bf20ac4117d4cfc1b58a9a`.
- Installed only at the FTMO demo `MQL5/Experts/QM_FTMO` path recorded in `install_receipt.json`.
- Pre-install binary and both presets are recoverable under `_pre_panel_v2_11421_20260907_0620Z`.
- Load-dialog and profile preset copies match at SHA-256 `9713772ba225b58ae26f04545e188b8a963a3ff44eda44999fe88ad45e8da016`, with `qm_show_chart_panel=true`, `qm_apply_chart_scheme=true`, `qm_panel_build_hash=d90cfa27`, and `qm_news_stale_max_hours=336`.
- Canonical `framework/EAs/*.ex5` files were not written.

## Verification

- `python -m pytest -q tools/strategy_farm/tests/test_chart_panel_acceptance.py tools/strategy_farm/tests/test_qm5_11421_chart_panel_integration.py` -> `4 passed`.
- Static acceptance -> PASS: ASCII, no trade calls, no `OnTick`, tester inert, timer lifecycle, required v2 fields, object namespace, light tokens, snapshot/restore, 22-row ceiling, Market-safe support text.
- Native header probe -> `0 errors, 0 warnings`.
- Native full canary compile -> `0 errors, 0 warnings`.
- `validate_build_guardrails.py` on the isolated source -> PASS, zero findings, news stale ceiling 336.
- Installed binary and both preset hashes verified after copy.

The FTMO demo terminal was already running. It was not started, stopped, restarted, or interrupted. No chart was attached and AutoTrading was not changed.

## OWNER re-attach (three lines)

1. On the existing FTMO demo EURUSD.DWX D1 chart, remove QM5_11421 and attach `Experts/QM_FTMO/QM5_11421_ohlc-daily-squeeze-reversal-d1` again.
2. Load `QM5_11421_EURUSD_D1_live_trial.set`; confirm `qm_show_chart_panel=true`, `qm_apply_chart_scheme=true`, and build `d90cfa27` before accepting.
3. Leave AutoTrading in its current state; visually confirm one light panel, zero legacy overlap, readable candles/price lines, and report the object census/screenshot for close-out.

## Review boundary

This is a canary artifact in REVIEW. It is not a fleet rollout, pipeline verdict, live-book authorization, or permission to touch the other seven sleeves or the governor view.
