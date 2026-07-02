# QM5_12847 Turn-of-Month Fidelity Repair

Task: `05a836a7-22a6-4ffb-a3b0-fcb8790911fc`

EA: `QM5_12847_turn-of-month-sp500`

## Defects Fixed

1. Friday close was enabled by default and no set file overrode it, truncating the card mechanic that exits on trading day 3 of the next month.
2. Month trading-day count was seeded with `21` and could carry a partially observed warm-up month into later entry timing.
3. `QM_EntryRequest.expiration_seconds` was not initialized before `QM_TM_OpenPosition()`.

## Source Changes

Patched:

`C:\QM\repo\framework\EAs\QM5_12847_turn-of-month-sp500\QM5_12847_turn-of-month-sp500.mq5`

- replaced `g_prev_tdc = 21` with `g_prev_tdc = 0` plus `g_have_prev_tdc`
- added `QM12847_TradingDaysInMonth()` using the D1 bar sequence for exact current-month trading-day counts when available
- only records previous-month count after a complete prior month was observed
- entry timing now prefers exact current-month count, with previous-complete-month fallback only after a clean prior month exists
- initialized `req.expiration_seconds = 0`

Patched set files:

- `QM5_12847_turn-of-month-sp500_SP500.DWX_D1_backtest.set`
- `QM5_12847_turn-of-month-sp500_NDX.DWX_D1_backtest.set`
- `QM5_12847_turn-of-month-sp500_WS30.DWX_D1_backtest.set`
- `QM5_12847_turn-of-month-sp500_GDAXI.DWX_D1_backtest.set`
- `QM5_12847_turn-of-month-sp500_NDX.DWX_D1_q05_stress_medium.set`

Each now pins:

```text
qm_friday_close_enabled=false
RISK_FIXED=1000
RISK_PERCENT=0
```

## Verification

Compile:

```text
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
compile_one.log=C:\QM\repo\framework\build\compile\20260702_053022\QM5_12847_turn-of-month-sp500.compile.log
compile_one.ex5=C:\QM\repo\framework\EAs\QM5_12847_turn-of-month-sp500\QM5_12847_turn-of-month-sp500.ex5
```

Guardrails:

```text
python tools/strategy_farm/validate_build_guardrails.py C:\QM\repo\framework\EAs\QM5_12847_turn-of-month-sp500
verdict=PASS
max_news_stale_hours=336
findings=[]
```

Focused source/set checks:

- `g_prev_tdc` no longer seeded to 21
- `g_have_prev_tdc` gates fallback month counts
- `QM12847_TradingDaysInMonth()` present
- `req.expiration_seconds = 0` present
- all current 12847 set files include `qm_friday_close_enabled=false`

Direct MT5 smoke was not launched manually to avoid colliding with active T1-T10 worker-owned backtests.

## Queue Actions

Requeued Q02 rows requested by the task:

```json
[
  {
    "phase": "Q02",
    "symbol": "NDX.DWX",
    "status": "pending",
    "verdict": null,
    "attempt_count": 0,
    "evidence_path": null,
    "claimed_by": null
  },
  {
    "phase": "Q02",
    "symbol": "SP500.DWX",
    "status": "pending",
    "verdict": null,
    "attempt_count": 0,
    "evidence_path": null,
    "claimed_by": null
  }
]
```

Invalidated downstream rows promoted from the bad SP500/NDX evidence:

- `ed65f307-8d67-4650-8587-99de616284ed` Q03 NDX -> `failed/INVALID`
- `658d14e1-c567-4f49-85c6-2f931644c0fc` Q04 NDX -> `failed/INVALID`
- `356ba890-1484-405e-b435-9f29850cb2f8` Q04 SP500 -> `failed/INVALID`
- `07e0ef9d-1d87-42d5-9180-679fb5701a82` Q05 NDX -> `failed/INVALID`
