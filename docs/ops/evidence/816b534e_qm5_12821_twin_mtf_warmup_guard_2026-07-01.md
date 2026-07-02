# QM5_12821 T-WIN MN/W1 Warmup Guard Evidence

Task: `816b534e-69ca-4faa-819a-ac62b4036475`
Date: 2026-07-01
Agent: codex

## Verdict

Implemented a calendar/time-based MN/W1 maturity guard for T-WIN entries.
The EA now anchors the host H1 first-bar time during `OnInit` and blocks new
basket entry evaluation until both the four-W1-period and one-MN-equivalent
windows have elapsed.

## Code Changes

- Added `framework/include/QM/QM_TWINWarmupGuard.mqh`.
  - `QM_TWIN_MTF_WARMUP_W1_PERIODS = 4`.
  - `QM_TWIN_MTF_WARMUP_MN_DAYS = 31`.
  - `QM_TWIN_MtfWarmupReadyTime(...)` returns the later of the W1 and MN
    maturity timestamps.
  - `QM_TWIN_MtfWarmupReady(...)` fails closed until broker time reaches that
    maturity timestamp.
- Updated
  `framework/EAs/QM5_12821_twin-csm-basket/QM5_12821_twin-csm-basket.mq5`.
  - Anchors `g_mtf_warmup_first_bar_time` from
    `iTime(QM12821_HOST_SYMBOL, QM12821_HOST_TF, 0)` during `OnInit`.
  - Logs `BASKET_MTF_WARMUP_BLOCK` once while the guard is immature.
  - Blocks `Strategy_NoTradeFilter` and `Strategy_EntrySignal` before
    `QM12821_EvaluateSignal(...)`, so exhaustion and W1/MN MTF coherence are
    not evaluated during the startup artifact window.
  - Skips signal-shift W1/MN evaluation while the guard is immature, while
    leaving time/equity risk management intact for existing exposure.
- Updated `framework/EAs/_tests/QM_TWIN_Module_tests/QM_TWIN_Module_tests.mq5`.
  - Added `TestMtfWarmupGuard()` assertion that the 2018.07.02 first bar is
    blocked at 28 and 30 days and becomes ready only at the 31-day maturity.

## Guardrail Notes

- Existing W1/MN preload calls remain unchanged:
  - `QM_BasketWarmupHistory(..., PERIOD_W1, 80)`
  - `QM_BasketWarmupHistory(..., PERIOD_MN1, 80)`
- The basket equity stop remains `strategy_basket_stop_pct = 1.0`.
- No broker-side SL was introduced.
- News stale max remains `336`.
- Backtest setfiles remain `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Verification

Strict compile: T-WIN module harness

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/_tests/QM_TWIN_Module_tests -Strict
```

Result:

- `compile_one.result=PASS`
- `compile_one.errors=0`
- `compile_one.warnings=0`
- Log: `C:\QM\repo\framework\build\compile\20260701_121022\QM_TWIN_Module_tests.compile.log`

Strict compile: QM5_12821 EA

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12821_twin-csm-basket -Strict
```

Result:

- `compile_one.result=PASS`
- `compile_one.errors=0`
- `compile_one.warnings=0`
- Log: `C:\QM\repo\framework\build\compile\20260701_121030\QM5_12821_twin-csm-basket.compile.log`

Build guardrails:

```powershell
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12821_twin-csm-basket
```

Result:

- `verdict=PASS`
- `files_checked=30`
- `findings=[]`
- `max_news_stale_hours=336`

Static readback:

- `QM12821_EvaluateSignal(...)` is reached only after
  `QM12821_MtfWarmupReady(...)` / `QM12821_BlockEntryForMtfWarmup(...)`.
- `strategy_basket_stop_pct` remains `1.0`.

No terminal was started and no live/AutoTrading state was touched.
