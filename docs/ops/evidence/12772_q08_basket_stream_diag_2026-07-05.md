# Evidence: QM5_12772 Q08 INFRA Persists After Recompile — Basket Stream Diagnosis

**Task:** `45ec67a7` (DIAG: 12772 cointegration Q08 INFRA persists after recompile)
**Author:** Claude (claude-sonnet-4-6, orchestration cycle 2026-07-05T15:xx Z)
**EA:** QM5_12772 edgelab-gbpjpy-audjpy-cointegration (GBPJPY/AUDJPY D1)

---

## 1. Failure History

| Run Tag | Terminal | Symbol Used | Result | Root Cause |
|---|---|---|---|---|
| 20260704_082145 | T1 | QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1 (40 chars) | REPORT_MISSING | Symbol truncated to 32 chars → "not exist" → fell back to EURUSD.DWX |
| 20260704_111749 | T1 | GBPJPY.DWX | FAIL | Run details not shown (likely cold-cache) |
| 20260704_193252 | T2 | GBPJPY.DWX | NO_HISTORY (3 attempts) | Cold .hcc on T2 — BARS_ZERO, HISTORY_CONTEXT_INVALID all 3 runs |
| 20260704_215907 | T1 | GBPJPY.DWX | Incomplete (no summary.json) | Likely cold-cache |
| 20260705_050028 | T5 | GBPJPY.DWX | TIMEOUT (2400s) | Multi-symbol warmup timed out — METATESTER_HUNG |

Q08 work_item `68dc6e09` verdict=INFRA_FAIL, updated 2026-07-05T05:40Z.

---

## 2. Root Cause Analysis

### 2a. Basket-stream path mismatch (ALREADY FIXED in main)

The `_common_q08_trade_log` function keyed the stream file on the logical composite symbol
(`QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1`), but the EA's `OnTesterDeinit` writes to
`_Symbol` = `GBPJPY.DWX` (the host_symbol the tester runs on).

Result: aggregator looked for `12772_QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1.jsonl`
but EA wrote `12772_GBPJPY_DWX.jsonl` → 0 trades → INVALID.

**Status:** Fixed in commits `977a31a2b` (host_symbol baseline runner) and `46465c162` /
`7c1976bb3` on main (host_sym fallback in run_all). This bug did NOT cause the
2026-07-04/05 failures because the aggregator's host_log fallback path handles it.

### 2b. Cold-cache / timeout (CURRENT BLOCKER)

The Q08 baseline runs a full-history 2017-2025 D1 model=4 backtest. For a 3-symbol EA
(GBPJPY.DWX + AUDJPY.DWX + USDJPY.DWX), `QM_BasketWarmupHistory` must load all three
symbols' real-tick history. On any terminal without warm .hcc caches:

- NO_HISTORY (all 3 T2 attempts 20260704_193252): GBPJPY.DWX history not available on T2
- TIMEOUT 2400s (T5 on 20260705_050028): T5 had LSM degradation + GBPJPY+AUDJPY+USDJPY
  cold cache needing download/generation — exceeded the hard 40-minute limit

**This is the actual reason n_trades=0: the baseline backtest never completed.**

The NO_HISTORY class self-heals on retry (known behavior — "Riesen-Fenster brauchen
mehrere Anläufe"). The T5 TIMEOUT was compounded by the watchdog parse error
(0x800700E0 session degradation) that affected all scheduled tasks from 2026-07-04T02:30Z.

### 2c. Improvement applied this cycle

`_persist_durable_sleeve_stream` now accepts a `common_log_override` parameter. The
call in `run_all` now passes `host_log` so the durable store copies the raw JSONL from
the host-symbol path (preserving notional data) rather than falling back to in-memory
serialization when trades come from the basket fallback path.

Commit: see below.

---

## 3. Baseline Runner Configuration

Tester.ini verified correct:
```
Symbol=GBPJPY.DWX          ← host_symbol (correct since 977a31a2b)
Period=D1
Model=4
FromDate=2017.01.01
ToDate=2025.12.31
TimeoutSeconds=2400
```

Set file `host_symbol: GBPJPY.DWX` header confirmed present.
`strategy_z_lookback_d1=60`, `strategy_atr_period_d1=20` → warmup requests 300+ bars.

---

## 4. Actions Taken

1. Diagnosed all 5 baseline run attempts and identified cold-cache TIMEOUT as root cause
2. Verified basket-stream path fix already on main
3. Improved `_persist_durable_sleeve_stream`: added `common_log_override` parameter,
   `run_all` now passes `host_log` for proper JSONL copy with notional
4. Q08 work_item `68dc6e09` confirmed in `pending` state (reset at 13:58 local) —
   will be dispatched to a warm terminal by the factory

---

## 5. Expected Recovery

The next Q08 dispatch should run on a terminal that already has GBPJPY.DWX/AUDJPY.DWX
history warm from Q02-Q07 runs. With the watchdog fixed and session degradation
resolved, T1-T7 workers are now stable. The 2400s timeout is generous for a warm cache.

If TIMEOUT recurs: the terminal used for prior successful Q02-Q07 runs should be
preferred (their warm .hcc will serve the Q08 baseline). The factory dispatcher does
not have warm-cache affinity, so a second timeout on a cold terminal is possible —
in that case, move Q08 to the terminal that ran Q07 (check Q07 work_item terminal field).
