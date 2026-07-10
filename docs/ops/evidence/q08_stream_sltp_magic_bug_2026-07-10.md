# Q08 per-trade stream undercount — root cause + fix (2026-07-10)

## Symptom
Codex' stream-to-report reconciliation found the q08 per-trade streams (`Common/Files/QM/q08_trades/<ea>_<sym>.jsonl`)
**undercount trades vs the MT5 tester report**, with the missing trades skewed toward winners:

| EA / symbol | stream trades | report trades | stream net | report net |
|---|---:|---:|---:|---:|
| 10916 / GDAXI | 611 | 611 | — | — | (reconciled — no SL/TP-magic-0 closes) |
| 10118 / NDX | 714 | 716 | | | (−2) |
| 10706 / GBPUSD | 364 | 367 | $66,172 | $71,673 | (−3) |
| 10546 / XAUUSD | 1,708 | 1,762 | $96,692 | $143,387 | (**−54 / −$46,695**) |

## Diagnosis chain (three stages — first two were WRONG, documented for the record)
1. **WRONG — "my OOM flush fix drops the tail."** The 2026-07-10 OOM fix (`0a1c7fee4`) made the
   in-memory buffer flush at 32 KB by re-opening the file with `FILE_READ|FILE_WRITE` + `FileSeek(SEEK_END)`.
   Hypothesis: the seek mis-lands and overwrites. **Refuted:** replacing it with a persistent open
   handle (kept as hardening) did NOT change the gap (10546 still 1708). The OOM fix was never the cause.
2. **WRONG — "the tester drops OnTradeTransaction events / positions open at end."** Rebuilding the
   stream deterministically from `HistorySelect` at OnDeinit ALSO produced exactly 1708 — and
   max-concurrent open positions was 1 (no end-of-window pile-up). Identical count in both the event
   path and the history walk was the key tell: **both apply the same ownership filter.**
3. **RIGHT — SL/TP closing deals carry `DEAL_MAGIC = 0`.** Instrumented the history walk
   (`Q08_HISTWALK_DIAG`): `out_deals:1762, owned:1708, bad_magics:"0|XAUUSD.DWX", bad_net:$46,702.76`.
   The 54 rejected closing deals all have magic 0 and are all winners. In MT5 a position closed by a
   **stop-loss or take-profit** produces a closing deal whose `DEAL_MAGIC` is 0, not the EA's magic.
   The ownership filter `QM_FrameworkOwnsMagicSymbol(deal_magic, …)` (`magic == g_qm_fw_magic`) therefore
   **dropped every TP/SL exit from the stream** — and TP exits are the winners, hence the profit skew.

## Root cause
`QM_FrameworkOnTradeTransaction` decided per-trade-stream ownership on the **closing** deal's magic.
SL/TP-triggered closing deals carry magic 0, so they failed the check and were never written. This is a
**pre-existing framework bug (not the OOM fix)** and affects **every EA that uses a broker-side SL/TP** —
their q08 streams have systematically omitted TP/SL exits, biasing the per-trade P&L distribution the
Q08 Davey sub-gates and the portfolio composites (Q09) read.

## Fix (`framework/include/QM/QM_Common.mqh`)
The q08 stream is now built at OnDeinit by a **deterministic two-pass history walk**, with ownership
decided on the **opening** deal (the IN/INOUT deal always carries the EA magic; only the close can be 0):
- **Pass 1** — collect the `position_id`s this EA opened (IN/INOUT deals passing `QM_FrameworkOwnsMagicSymbol`).
- **Pass 2** — emit one `TRADE_CLOSED` line per closing deal whose `position_id` is in that owned set,
  regardless of the closing deal's magic. MAE (worst floating loss, not in deal history) is looked up
  from the live-tracked arrays; the OnTick sweep now **archives** closed-position MAE (`g_qm_q08_mae_closed`)
  instead of discarding it, so the walk can attach it.
- Kept as independent hardening: the persistent-handle append (removes the fragile re-open/seek) and the
  original OOM bound (32 KB incremental flush + `FileFlush` durability).
- The live kill-switch feed stays event-driven in `QM_FrameworkOnTradeTransaction` (OnTradeTransaction is
  reliable LIVE; the unreliability is tester-specific and irrelevant to the post-run stream now).

## Verification (T7 / T6, 2017–2025, Model 4)
| EA | before | after fix | report | match |
|---|---|---|---|---|
| 10546 / XAUUSD M30 | 1,708 / $96,692 | **1,762 / $143,395** | 1,762 / $143,387 | ✓ (Δnet $7.66 = cent rounding) |
| 10706 / GBPUSD H1 | 364 / $66,172 | _(verifying)_ | 367 / $71,673 | _pending_ |

## Implications / rollout
- **Every EA must be recompiled** to pick up the fix (framework include change). Streams generated before
  the recompile remain undercounted.
- **Prior q08-stream-based analysis is biased** where SL/TP was used: the FTMO MAE study (invalidated docs
  from 2026-07-10) and any Q08/Q09 composite built on affected streams should be re-run from reconciled
  streams. The MT5 **report** was always correct; only the q08 stream was lossy.
- Reconcile the DXZ Sunday-admit streams vs their reports before the 2026-07-12 deploy (do NOT reuse
  post-fix-but-pre-recompile live streams).
