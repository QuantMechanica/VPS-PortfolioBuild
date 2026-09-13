# QM5_10706/GBPUSD break-even modify storm — root cause verification + closure (2026-09-13)

Ticket 9f0923ef. Read-only investigation against `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM`
(no file writes, no terminal control, no AutoTrading touch, no recompile of the live
inventory — all per the ticket's hard limits).

## Incident

`QM5_10706_ea-10706.log`: ticket `3169417771` (GBPUSD, magic `107060001`), starting
`2026-07-29T12:59:58.890Z`, repeated every tick for ~4.5h:

```json
{"ts_utc":"2026-07-29T12:59:58.890Z","event":"TM_MODIFY","payload":{"ticket":3169417771,
"symbol":"GBPUSD","new_sl":1.33010000,"new_tp":1.33888000,"reason":"MON_SWEEP_BE_LOCK",
"ok":false,"retcode":10016,"retcode_class":"BROKER_OTHER"}}
```

Exact count: **36,102 `TM_MODIFY` events, 36,098 `ok:false` (retcode 10016
TRADE_RETCODE_INVALID_STOPS), 4 successes** — matches the ticket's stated numbers.

## Root cause (two independent defects, both already fixed in source)

1. **Unnormalized break-even price.** `Strategy_ManageOpenPosition()` in
   `QM5_10706_tv-mon-ls.mq5` computed `new_sl = g_be_entry ± lock` as a raw double and
   passed it straight to `QM_TM_MoveSL`. GBPUSD's tick/digit rounding could put that raw
   value on an invalid stop level for the broker, so every attempt was rejected with
   10016 — deterministically, since the input never changed between the entry price and
   the fixed `BeLockFrac * g_be_risk` offset.
2. **No backoff on a drifting retry target.** `QM_TM_ModifySuppressed` /
   `QM_TM_RememberFailedModify` (pre-fix) only suppressed a retry on an *exact* repeat of
   the same failed `(sl, tp)` pair within 30s. Because the position's SL also moves
   fractionally with spread/price on each tick in some paths, the retry target drifted
   just enough on most ticks to dodge the exact-match suppression entirely — so the
   modify was retried on every tick with no backoff and no cap.

## Fix status: already landed, before this ticket was opened

- **`3d853ab6b2`** (2026-08-17, "fix: normalize stop comparisons before modify") wraps
  the break-even target in `QM_TM_NormalizePrice(_Symbol, ...)` at the exact call site
  (`QM5_10706_tv-mon-ls.mq5:324`, `MON_SWEEP_BE_LOCK`). This is the "10706 BE-lock
  condition corrected in source" the ticket asked for — already present.
- **`ebffd42074`** (2026-08-22, "fix(framework): per-ticket exponential backoff + hard
  cap for TM_MODIFY retries") changed `QM_TM_TradeManagement.mqh` to back off
  **per-ticket regardless of target drift** (`30s * 2^n`, capped 900s) and log one
  `TM_MODIFY_BACKOFF_CAP` WARN after 20 consecutive failures, continuing at the capped
  cadence rather than stopping. Covered by `framework/tests/test_tm_modify_backoff.py`
  (reject-simulation replay of this exact incident window). This is the framework-level
  fix the ticket asked for — already present.

Both commits are framework-include/source-only changes; per the standing rule (rebuilt
EX5 = new identity, OWNER decision required) neither touched the live `.ex5`. The
36,098-line historical log entry predates both fixes (2026-07-29 vs. 2026-08-17/22) and
will not recur once QM5_10706's next natural rebuild picks up the current source. No
further source change is needed for this ticket; there is nothing left to patch.

## Fleet-wide scan: other live sleeves with a TM_MODIFY failure series

Read-only scan of all 24 configured `QM5_*_ea-*.log` files in
`C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM` for `"event":"TM_MODIFY"` and
`"event":"TM_MODIFY".*"ok":false`:

| EA/symbol | TM_MODIFY total | ok:false |
|---|---:|---:|
| QM5_10706 (GBPUSD) | 36,102 | 36,098 |
| QM5_13213 | 59 | 0 |
| QM5_13301 | 15 | 0 |
| QM5_10940 | 1 | 0 |
| all other 20 sleeves | 0 | 0 |

**Result: 0 other live sleeves show a `TM_MODIFY ok:false` series.** QM5_10706 is the
sole affected sleeve; every other sleeve's modify attempts (where present) succeeded.

## Disposition

No further action required. Evidence closes ticket 9f0923ef read-only-verified; the
fix already exists in source and is proven fleet-isolated to the one historical
incident on the one sleeve. Live identity change (recompiling QM5_10706) remains an
OWNER-gated decision, tracked separately under the DXZ book v2 / rebuilt-identity
workstream (`docs/ops/evidence/2026-09-13_dxz_book_v2/`), not reopened here.
