# MFE capture next to MAE in the Q08 trade stream (2026-09-13)

**Author:** Claude (framework engineer lane) · router MFE-capture ticket
**Scope:** additive telemetry only. No gate criteria, verdict logic, candidate pool, or
live surface is touched. GRÜN zone (existing-tool operation, additive measurement).

## What changed

The per-tick excursion sweep now records the **maximum favourable excursion (MFE)** of
every open position alongside the existing **maximum adverse excursion (MAE)**, and emits it
as `mfe_acct` next to `mae_acct` in every `TRADE_CLOSED` record.

Framework include (`framework/include/QM/`):

1. `QM_Common.mqh`
   - `struct QM_PositionMaeState` gains `double max_floating_pnl` next to `min_floating_pnl`.
   - `QM_FrameworkMaeUpsert()` tracks `mfe = MathMax(0.0, floating_pnl)` symmetric to
     `mae = MathMin(0.0, floating_pnl)`, at the **same tick sampling point** (no new sweep,
     no new EA call).
   - `QM_FrameworkTrackOpenPositionMae()` is **unchanged in name and call site** (the
     `build_gate_hardening.check_mae_hook` contract keys on this exact symbol); its header
     comment now documents that it tracks both MAE and MFE. **No EA source change is
     required** — the hook EAs already call gains MFE for free.
   - `QM_FrameworkQ08LookupMae()` gains a `double &mfe_acct_out` output parameter (MFE is
     not in deal history, so it must come from the live-tracked arrays; clamped `>= 0`).
   - The `QM_FrameworkQ08EmitFromHistory()` writer emits `"mfe_acct":%.2f` after
     `"mae_acct"`, with the symmetric realized-net cap `mfe_acct = MathMax(mfe_acct, net)`
     (mirrors the existing `mae_acct = MathMin(mae_acct, net)`; guarantees
     `giveback = (mfe-net)/mfe >= 0` for winners even when ticks miss the true peak).

2. `modules/QM_Mod_FtmoJointTradeV2_20181.mqh` — the only other emitter that carries
   `mae_acct` and the only other caller of `QM_FrameworkQ08LookupMae()`. Updated identically:
   new `mfe` local, symmetric clamp `mfe = MathMax(MathMax(0.0, mfe), net)`, and
   `"mfe_acct":%.2f` in its schema-version-2 record.

Guard: MFE starts at `0.0` and is never negative (a position that only ever floated at a
loss has MFE 0). MAE is byte-for-byte unchanged.

Python readers (`tools/strategy_farm/`):

3. `portfolio/portfolio_common.py` — the shared sealed-stream `Trade` loader that
   `book_builder_common.py` and the other portfolio tools delegate to. `Trade` gains an
   optional `mfe_acct: float | None = None` (appended last, so no positional construction
   breaks), read tolerantly via `row.get("mfe_acct")`. Old streams → `None`, no `KeyError`.

4. `research/exit_surgery_scan_v2.py` — the tool that surfaced the gap. `Trade` gains
   `mfe_acct` (default `0.0`, read via `rec.get(...)`). New `mfe_giveback()` mirrors
   `mae_tier_b()` and computes the **giveback ratio** — the symmetric MFE summary added
   where a MAE summary already exists — written to a new `mfe_winners.csv`:

   > `giveback = (mfe_acct - max(net, 0)) / mfe_acct` for winners with `mfe_acct > 0`,
   > reported as median / p75 / p90 / mean plus `n_winners_mfe` and `mfe_winner_med`.

Readers **not** changed and why they are already tolerant:
- `q08_durable_stream_export.py` (sealed sidecar) copies the stream **bytes verbatim** and
  hashes them — no per-record field whitelist; `mfe_acct` flows through untouched.
- `framework/scripts/q08_davey/aggregate.py` has **no MAE summary** (so no MFE summary is
  added, per "only where a MAE summary already exists"), and its `_STREAM_IDENTITY_FIELDS`
  whitelist is an *identity* set that deliberately excludes enrichment fields like
  `mae_acct` (see its own comment) — `mfe_acct` is likewise enrichment and must stay out of
  it; unknown on-disk fields are ignored, so it already tolerates the new field.

## Why

OWNER 2026-09-13 ("alle Hebel in Bewegung setzen, Evidenz für alles"). Today's Exit-Surgery
Scan v2 found MFE is captured **nowhere**, so the value of a trailing stop / earlier exit is
unmeasurable: MAE tells us how much heat a winner took, but not how much open profit it gave
back before the close. Capturing MFE at the same sampling point as MAE makes the giveback
ratio a first-class, reproducible metric on every future trade stream.

## Impact on existing EAs / binaries

**Nothing changes for any already-compiled `.ex5`.** MFE capture only exists in binaries
compiled after this include change. Rebuilding an EA produces a **new identity from Q02**
(OWNER rule: rebuilt EX5 = new identity) — MFE arrives naturally on the next rebuild, never
by recompiling an EA in active inventory. Streams already on disk are unaffected; every
reader tolerates their absence of `mfe_acct`.

## Tests

`tools/strategy_farm/tests/test_mfe_capture.py` (new, 8 tests, all pass):
- `exit_surgery_scan_v2.load_trades` parses a legacy row (no `mfe_acct` → `0.0`) and a new
  row side by side.
- giveback-ratio math: exact values over `[(mfe=100,net=60/50/90)]` → median 0.4, p75 0.45,
  p90 0.48, mean 0.3333; exit-at-peak → 0; legacy stream → `n=0`, all-NaN.
- `run_scan` writes `mfe_winners.csv` for both a new stream (n=3, median giveback 0.4) and a
  legacy stream (n=0, blank stats, no crash).
- `portfolio_common.load_streams` parses old and new rows (`mfe_acct` `None` vs float).

Regression: `test_exit_surgery_scan_v2.py` (11) and `test_portfolio_common.py` (1 class)
still pass. Command:
`python -X utf8 -m pytest tools/strategy_farm/tests/test_mfe_capture.py tools/strategy_farm/tests/test_exit_surgery_scan_v2.py tools/strategy_farm/tests/test_portfolio_common.py -q`

## Manual compile-verification step (orchestrator)

The MQL5 change **cannot be compiled in this lane** (no compiler, no terminal). Before this
propagates to any rebuild wave, the orchestrator compiles **one `*-symfix` EA through the
factory build gate** (a symfix rebuild is already a new identity, so it costs no incumbent):
run the standard `build_ea` / `build_check.ps1` path for a single symfix EA and confirm:
- `QM_Common.mqh` + the 20181 module compile with **0 errors / 0 warnings**;
- `build_gate_hardening.check_mae_hook` still passes (function name unchanged);
- a produced `TRADE_CLOSED` line now carries `"mfe_acct"` next to `"mae_acct"`.

## MQL5 diff (verbatim hunk)

```diff
--- a/framework/include/QM/QM_Common.mqh
+++ b/framework/include/QM/QM_Common.mqh
@@ struct QM_PositionMaeState @@
    ulong    position_id;
    datetime entry_time;
-   double   min_floating_pnl;
+   double   min_floating_pnl;   // MAE: worst (most negative) floating PnL over the life of the position, account ccy
+   double   max_floating_pnl;   // MFE: best (most positive) floating PnL, account ccy; never < 0 (see QM_FrameworkMaeUpsert)
   };
@@ void QM_FrameworkMaeUpsert(...) @@
    const double mae = MathMin(0.0, floating_pnl);
+   const double mfe = MathMax(0.0, floating_pnl);
    int index = QM_FrameworkMaeFind(position_id);
    if(index < 0)
      {
       ...
       g_qm_q08_mae_states[index].min_floating_pnl = mae;
+      g_qm_q08_mae_states[index].max_floating_pnl = mfe;
       return;
      }
    ...
    if(mae < g_qm_q08_mae_states[index].min_floating_pnl)
       g_qm_q08_mae_states[index].min_floating_pnl = mae;
+   if(mfe > g_qm_q08_mae_states[index].max_floating_pnl)
+      g_qm_q08_mae_states[index].max_floating_pnl = mfe;
   }
@@ double QM_FrameworkQ08LookupMae(...) @@
-double QM_FrameworkQ08LookupMae(const ulong position_id, datetime &entry_time_out)
+double QM_FrameworkQ08LookupMae(const ulong position_id, datetime &entry_time_out,
+                                double &mfe_acct_out)
   {
    for(int i = ArraySize(g_qm_q08_mae_states) - 1; i >= 0; --i)
       if(g_qm_q08_mae_states[i].position_id == position_id)
         {
          entry_time_out = g_qm_q08_mae_states[i].entry_time;
+         mfe_acct_out = MathMax(0.0, g_qm_q08_mae_states[i].max_floating_pnl);
          return MathMin(0.0, g_qm_q08_mae_states[i].min_floating_pnl);
         }
    for(int i = ArraySize(g_qm_q08_mae_closed) - 1; i >= 0; --i)
       if(g_qm_q08_mae_closed[i].position_id == position_id)
         {
          entry_time_out = g_qm_q08_mae_closed[i].entry_time;
+         mfe_acct_out = MathMax(0.0, g_qm_q08_mae_closed[i].max_floating_pnl);
          return MathMin(0.0, g_qm_q08_mae_closed[i].min_floating_pnl);
         }
    entry_time_out = 0;
+   mfe_acct_out = 0.0;
    return 0.0;
   }
@@ QM_FrameworkQ08EmitFromHistory() @@
       datetime mae_entry_time = 0;
+      double mfe_acct = 0.0;
       double mae_acct = QM_FrameworkQ08LookupMae(position_id,
-                                                 mae_entry_time);
+                                                 mae_entry_time,
+                                                 mfe_acct);
       mae_acct = MathMin(mae_acct, net);
+      mfe_acct = MathMax(mfe_acct, net);   // symmetric to the MAE cap (see source comment)
       g_qm_q08_trade_log += StringFormat(
-         "...\"mae_acct\":%.2f,\"net\":%.2f,...",
+         "...\"mae_acct\":%.2f,\"mfe_acct\":%.2f,\"net\":%.2f,...",
          ...
          mae_acct,
+         mfe_acct,
          net,

--- a/framework/include/QM/modules/QM_Mod_FtmoJointTradeV2_20181.mqh
+++ b/framework/include/QM/modules/QM_Mod_FtmoJointTradeV2_20181.mqh
@@ bool QM_FJ_TradeV2Prepare() @@
       datetime mae_entry_time = 0;
+      double mfe = 0.0;
       double mae = QM_FrameworkQ08LookupMae(rows[i].position_id,
-                                            mae_entry_time);
+                                            mae_entry_time,
+                                            mfe);
       ...
       mae = MathMin(MathMin(0.0, mae), net);
+      mfe = MathMax(MathMax(0.0, mfe), net);   // symmetric to the MAE clamp above
       ...
-         "\"mae_acct\":%.2f,\"volume\":%.2f,\"notional\":%.2f}\r\n",
+         "\"mae_acct\":%.2f,\"mfe_acct\":%.2f,\"volume\":%.2f,\"notional\":%.2f}\r\n",
          ...
          mae,
+         mfe,
          rows[i].exit_volume,
          notional);
```

## Rollback

Revert the two include hunks
(`framework/include/QM/QM_Common.mqh`,
`framework/include/QM/modules/QM_Mod_FtmoJointTradeV2_20181.mqh`) and rebuild. The Python
changes are additive and back-compatible; they can stay (they tolerate the absence of
`mfe_acct`) or be reverted independently. No stream, verdict, or binary needs migration.

## Files

- `framework/include/QM/QM_Common.mqh`
- `framework/include/QM/modules/QM_Mod_FtmoJointTradeV2_20181.mqh`
- `tools/strategy_farm/portfolio/portfolio_common.py`
- `tools/strategy_farm/research/exit_surgery_scan_v2.py`
- `tools/strategy_farm/tests/test_mfe_capture.py` (new)
- `docs/ops/evidence/2026-09-13_mfe_capture_hook.md` (this file)
