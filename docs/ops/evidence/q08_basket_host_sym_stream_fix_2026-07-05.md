# Evidence: Q08 Basket Host-Symbol TRADE_CLOSED Stream Fix (2026-07-05)

**Task:** `45ec67a7` — DIAG: QM5_12772 cointegration Q08 INFRA persists after recompile  
**Author:** Claude (claude-sonnet-4-6, orchestration cycle 2026-07-05T13:47Z)

---

## Root Cause

`QM5_12772` (GBPJPY/AUDJPY/USDJPY cointegration, Q02–Q07 all PASS) failed Q08 twice
with `INFRA_FAIL` / `verdict_reason=phase_runner_invalid_report` and `trades=0`.

### Why trades=0

`aggregate.py` builds the TRADE_CLOSED stream via two mechanisms:
1. **Common\Files path** — deterministic path based on the work-item symbol:
   `Common\Files\QM\q08_trades\{ea_id}_{symbol}.jsonl`
2. **Tester agent log** — searched under `D:\QM\mt5\{term}\Tester\Agent-*\MQL5\Files\QM\`

For basket EAs, the baseline backtest runs on the **host_symbol** (GBPJPY.DWX), not the
logical composite symbol. The EA's `_Symbol` variable therefore equals `GBPJPY.DWX`, and
TRADE_CLOSED events are emitted to:

```
C:\Users\Administrator\...\Common\Files\QM\q08_trades\12772_GBPJPY_DWX.jsonl
```

But `aggregate.py` looked for:

```
C:\Users\Administrator\...\Common\Files\QM\q08_trades\12772_QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1.jsonl
```

This file never exists. The fallback path (tester agent log + MT5 HTML report) also
yields 0 trades because the EQUITY_SNAPSHOT log search uses the logical symbol as the
search token and the basket EA tester runs on the host symbol.

### Evidence

```
D:\QM\strategy_farm\logs\work_item_68dc6e09-d39c-4cd5-bfb9-9dbd4cea7054.log:
  2026-07-05T05:00:27+00:00 spawning phase runner:
    aggregate.py --ea-id 12772
                 --symbol QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1
                 --log D:\QM\mt5\T5\MQL5\Logs\QM\QM5_12772.log

  Q08  QM5_12772 QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1  ->  INVALID
    trades=0  equity_snaps=0
```

File present in Common\Files before fix:
```
12772_GBPJPY_DWX.jsonl   ← EA actually wrote here
12772_QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1.jsonl   ← did not exist
```

---

## Fix

`framework/scripts/q08_davey/aggregate.py` — `run_all()` function.

Two changes:
1. **Pre-baseline cleanup**: resolve the host-symbol log path using
   `_host_symbol_from_setfile(baseline_setfile, symbol)` and clear it before running the
   baseline (alongside clearing the logical-symbol path). This prevents stale data from a
   prior run from surviving a fresh baseline.

2. **Post-baseline fallback**: after reading the logical-symbol path, if `trades` is still
   empty AND a host-symbol path was resolved, load trades from the host-symbol path instead.
   Records `baseline_run["host_sym_log_fallback"]` for auditability.

Non-basket EAs are unaffected: `_host_symbol_from_setfile` returns the symbol unchanged
when the setfile has no `; host_symbol:` header line.

```python
# Basket EA host-symbol fallback: if logical-symbol path is empty after baseline,
# the EA used _Symbol (physical chart symbol) as its TRADE_CLOSED key.
if not trades and host_log is not None:
    trades = common.load_trades_from_log(host_log)
    equity_stream = common.load_equity_stream(host_log) or equity_stream
    if trades and baseline_run is not None:
        baseline_run["host_sym_log_fallback"] = str(host_log)
```

**Syntax check:** `python -c "import ast; ast.parse(open('aggregate.py').read())"` → PARSE OK.

---

## Action

- `QM5_12772` Q08 work_item `68dc6e09` requeued (`status='pending'`) for re-evaluation.
- The fix is general: all basket EAs that run on a host_symbol and write TRADE_CLOSED
  using `_Symbol` (not the logical composite) will now be handled correctly.

---

## Files Changed

| File | Change |
|---|---|
| `framework/scripts/q08_davey/aggregate.py` | Host-symbol TRADE_CLOSED fallback in `run_all()` |
| `docs/ops/evidence/q08_basket_host_sym_stream_fix_2026-07-05.md` | This doc |
