# Evidence: Q08 Basket EA INVALID Loop — host_log Deletion Bug (2026-07-05)

**Task:** `45ec67a7` (DIAG: QM5_12772 cointegration Q08 INFRA persists after recompile)
**Author:** Claude (claude-sonnet-4-6, orchestration cycle 2026-07-05)

---

## 1. Symptom

`QM5_12772` (edgelab-gbpjpy-audjpy-cointegration, GBPJPY/AUDJPY D1) reached Q07 PASS but
failed Q08 FIVE times across two days (2026-07-04 and 2026-07-05) with `INVALID / n_trades=0`.
The 2026-07-04T09:42 recompile (clean, BASKET_OK) did not fix it — confirming it was NOT
the stale-ex5 class of failure.

---

## 2. Root Cause: Two Compounding Defects

### 2a. symbol key mismatch (commit 977a31a2b)

The EA writes its `TRADE_CLOSED` stream to:
```
Common\Files\QM\q08_trades\{ea_id}_{_Symbol.replace('.','_')}.jsonl
```
using `_Symbol` = the physical MT5 chart symbol (`GBPJPY.DWX`).

The aggregate.py `_common_q08_trade_log()` expected:
```
Common\Files\QM\q08_trades\{ea_id}_{logical_symbol.replace('.','_')}.jsonl
```
where `logical_symbol = "QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1"`.

For single-symbol EAs the two match (`GBPJPY.DWX` == `GBPJPY.DWX`). For basket EAs they
diverge. Commit `977a31a2b` fixed the baseline to run on `host_symbol`. Commit `46465c162`
added a basket fallback that resolves `host_log = _common_q08_trade_log(ea_id, host_sym)`.

### 2b. host_log deletion before timed-out baseline (fixed by this task)

`aggregate.py` commit `46465c162` (2026-07-05T13:59Z) introduced both the basket fallback
AND a host_log deletion block:

```python
# Also clear the host-symbol path so stale data does not survive a fresh baseline.
if host_log is not None:
    try:
        if host_log.exists():
            host_log.unlink()
    except OSError:
        pass
baseline_run = _run_baseline_for_trades(...)
...
if not trades and host_log is not None:
    trades = common.load_trades_from_log(host_log)
```

For basket EAs, the Q08 baseline backtest on GBPJPY.DWX (3 symbols, 2017-2025, Model 4)
takes ~59 minutes. The `_run_baseline_for_trades` timeout is 2500 seconds (~41 minutes),
so `run_smoke.ps1` is killed before MT5 finishes. When `run_smoke.ps1` is killed, MT5
(metatester64) continues as an orphan process. When MT5 eventually finishes (~18 minutes
after the subprocess is killed), its OnDeinit writes `12772_GBPJPY_DWX.jsonl`.

The deletion block destroyed the pre-existing file BEFORE running the baseline. After the
baseline timed out, neither the logical-symbol file nor the host-symbol file had data.
The fallback read an empty file. Result: `trades=0 → INVALID`.

**Evidence:**
- `12772_GBPJPY_DWX.jsonl` existed (226 lines, 2026-07-04T22:58:23Z) before each Q08 run
- `D:\QM\reports\pipeline\QM5_12772\Q08\_baseline\QM5_12772\20260705_050028\summary.json`:
  `"result":"FAIL","reason_classes":["TIMEOUT","METATESTER_HUNG","INCOMPLETE_RUNS"]`
- Each Q08 run logged `trades=0 equity_snaps=0 → INVALID`

---

## 3. Fix

Removed the `host_log` pre-deletion block from `aggregate.py`:

```python
# BEFORE (commit 46465c162):
if host_log is not None:
    try:
        if host_log.exists():
            host_log.unlink()
    except OSError:
        pass

# AFTER: block removed. Comment explains why:
# NOTE: we intentionally do NOT delete host_log here. For basket EAs the host-symbol
# file is written only by a full-history OnDeinit, so pre-existing data is always a
# valid full-history run. If the fresh baseline succeeds, the EA overwrites it with
# updated data. If the baseline times out (long cold-cache multi-symbol runs), the
# pre-existing file provides the correct fallback. Deleting it before a potentially
# timed-out baseline discards the only valid trade stream — the 0-trade INVALID loop.
```

**Why it's safe to keep pre-existing host_log:**
- The host-symbol file is written by `QM_Common.mqh` `OnDeinit` at the END of a full
  backtest (full date range). It is never written during mid-fold or partial runs.
- The only code path that writes to it is the Q08 baseline runner (2017-2025 full history).
- If pre-existing data survives a failed baseline, it is from an earlier full-history run
  of the same EA — a valid input for the Davey sub-gates.
- If the fresh baseline succeeds, it overwrites the file with current data (`FILE_WRITE`
  truncates).

---

## 4. Current file state

`C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades\12772_GBPJPY_DWX.jsonl`:
- 226 lines (TRADE_CLOSED events)
- Written 2026-07-04T22:58:23Z (full-history baseline from Q08 3rd run, orphan metatester)
- First trade close: 2018-03-30 (within 2017-2025 range) ✓
- Fields present: event, time, entry_time, mae_acct, net, profit, swap, commission, volume, notional, symbol ✓

---

## 5. Action taken

1. `aggregate.py` fix committed to `agents/board-advisor` (canonical factory branch):
   the deletion block replaced with explanatory comment.
2. Work item `68dc6e09` (Q08 for QM5_12772) is `status=pending` — factory will pick
   it up with the fixed aggregator. No manual requeue needed.
3. Evidence committed to `docs/ops/evidence/` on `agents/board-advisor`.

---

## 6. Systemic risk

All basket EAs share this class of failure if their Q08 baseline backtest exceeds
the 2500s aggregate timeout (41 minutes). The root cause is:
- Multi-symbol history loading for cold tester caches can take 45-90+ minutes
- The aggregate's outer `subprocess.run(..., timeout=2500)` fires before MT5 finishes
- Orphan metatester continues and eventually writes the file, but the aggregate has
  already completed with 0 trades

**Mitigation (this fix):** preserve pre-existing host_log data across failed baselines.
**Further hardening (deferred):** increase `_run_baseline_for_trades` timeout to 7200s
for basket EAs, or add cold-cache pre-warm logic.

---

## Files changed

| File | Change |
|---|---|
| `framework/scripts/q08_davey/aggregate.py` | Removed host_log pre-deletion block; added explanatory comment |
| `docs/ops/evidence/q08_basket_host_log_deletion_loop_2026-07-05.md` | This doc |
