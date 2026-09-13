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

---

## Addendum 2026-09-13T21:25Z — root-cause correction + EA source patch (second review)

A second, independent pass re-derived the incident straight from the log and found the
two root causes stated above (§"Root cause") are **not supported by the evidence**. Both
are corrected here, the true mechanism is documented, and the genuine EA-source defect —
which the first pass declared did not exist — is patched.

### Correction 1 — the target did NOT drift; it was a constant

```
grep 'MON_SWEEP_BE_LOCK' QM5_10706_ea-10706.log | grep -o '"new_sl":[0-9.]*' | sort | uniq -c
  36099 "new_sl":1.33010000      <- the storm: one identical value
      1 "new_sl":1.35224000      }
      1 "new_sl":1.35342000      } later, unrelated tickets (all ok:true)
      1 "new_sl":1.36304000      }
```

The storm is **36,099 byte-identical `new_sl:1.33010000` / `new_tp:1.33888000` lines**.
`new_sl = g_be_entry + BeLockFrac*g_be_risk` with both operands captured once at
first-touch (`mq5:299-301`) — it *cannot* drift tick-to-tick. So the §"Root cause" #2
claim ("the retry target drifted just enough on most ticks to dodge the exact-match
suppression") is factually wrong for this incident. The deployed EX5 (built 2026-07-13)
simply predates *all* modify-hygiene (the 2026-07-20 exact-match window and the 2026-08-22
per-ticket backoff), which is the whole reason nothing throttled it — not any drift.

### Correction 2 — the price was already normalized; normalization is not the cause

`1.33010000` is a valid 5-digit GBPUSD price already on the pip grid — `QM_TM_NormalizePrice`
is a no-op on it. §"Root cause" #1 ("unnormalized break-even price … rounding put it on an
invalid stop level") does not explain a rejection of an already-normalized value. `3d853ab6b2`
(the normalization commit) is real and good hygiene, but it does **not** fix this incident:
a perfectly normalized `1.33010` is still rejected here.

### True root cause — a time-armed BE lock placed on the WRONG SIDE of the market

- Entry (`ENTRY_ACCEPTED`, 2026-07-28T12:59:59Z): BUY GBPUSD @ 1.32985, SL 1.32715
  (risk 0.00270), TP 1.33888. → BE-lock target = 1.32985 + 0.1*0.00270 = **1.33012 → 1.33010**.
- The storm's first line is **2026-07-29T16:00:00 broker time = exactly `BeBars`=24 H1 bars
  after entry.** The lock armed on the **time branch**
  (`if(r_now < BeTriggerR && bars_open < BeBars) return;`, `mq5:320`), NOT the 1.5R profit
  branch — price had not advanced that far.
- With price still near/below entry, a stop at 1.33010 (only 2.5 pips above entry) sat
  **at/above the live Bid** for a long → the broker correctly rejected it as
  `INVALID_STOPS` (retcode 10016). A confirming `BROKER_OTHER` line logs
  `retcode_comment:"Invalid stops"`.
- The `improves` gate (`mq5:326-327`, pre-patch) compared `new_sl` only against the
  *current* SL (still the far-below initial 1.32715), so it was trivially "improving" and
  TRUE — the doomed request went out **every tick**.
- The storm ran `2026-07-29T12:59:58.890Z → 19:00:58.234Z` (~6h) and ended the instant the
  modify **succeeded** (`ok:true retcode:10009`) — i.e. the moment Bid finally rose above
  `1.33010 + stops_level`. That success-on-price-clearing is the definitive proof the
  rejection was wrong-side-of-market, not rounding and not drift.

### EA source patch (this pass) — the BE-lock condition corrected

`framework/EAs/QM5_10706_tv-mon-ls/QM5_10706_tv-mon-ls.mq5`, `Strategy_ManagePosition`
BE-lock block:

- Added a `side_ok` invariant: the BE-lock stop must sit on the correct side of the live
  market by at least `SYMBOL_TRADE_STOPS_LEVEL` (`new_sl < market - min_dist` for a long,
  `new_sl > market + min_dist` for a short) before it is eligible to send.
- `improves` now requires `side_ok`; the "already at/beyond the lock" fast-path
  (`g_be_done = true`) is also gated on `side_ok`, so a time-armed lock whose target is
  still off-market **waits for a later tick** rather than emitting a doomed request.
- In-source comment documents the invariant that was violated.
- **Zero P&L impact:** the modify still lands at the same instant price clears the lock —
  identical trading behaviour to today — it only stops the structurally-invalid requests
  being generated at all. This is defence-in-depth *in front of* the framework backoff
  (`ebffd42074`): backoff throttles doomed retries; this stops them being generated.

**No recompile.** Source-only; lands at 10706's next natural rebuild (rebuilt EX5 = new
identity = OWNER-gated, ROT).

### Framework backoff half — confirmed sufficient

`QM_TM_MoveSL → QM_TM_SendSLTPModify` (`QM_TradeManagement.mqh:427-433, 208-256`) applies
the per-ticket, target-independent backoff/give-up ladder on every rejected modify
(including retcode 10016), so it fully covers a constant target too. No framework change
needed. `python -m pytest framework/tests/test_tm_modify_backoff.py -q` → 5 passed.

### Fleet scan — re-confirmed

Loop `grep -c '"event":"TM_MODIFY".*"ok":false'` over every `*.log`: **QM5_10706 = 36,098;
every other configured live log = 0.** QM5_10706 is the sole sleeve with any TM_MODIFY
failure series (consistent with the table above).

### Revised verdict

REVIEW — true root cause = time-armed BE lock (`BeBars`=24) placing a stop on the wrong
side of the live market; framework backoff half already shipped/tested; **EA BE-lock
condition now corrected in source** (wrong-side guard, no recompile, next-rebuild only);
0 other sleeves affected. The earlier "unnormalized price"/"drifting target" attributions
are superseded by the log evidence above.
