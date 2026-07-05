# News-Filter Index Defect — Root Cause + Fix (2026-07-05)

**Status: FIXED (commit `89963ff75`), SELF_REVIEW flagged for Codex (quota reset Tue 07-07).**

## Defect

`framework/include/QM/QM_NewsFilter.mqh`, `QM_NewsEventAffectsSymbol` (old line 312):
any symbol whose normalized name (after `.DWX` strip) is shorter than 6 characters was
treated via the FX-pair heuristic fallback `return true` — i.e. **affected by EVERY
calendar event worldwide**. NDX (3), SP500 (5), GDAXI (5), WS30 (4) all fell through;
XAUUSD/XTIUSD (6) correctly used the base/quote path.

Discovered via the 12985/12986 zero-trade investigation (0 trades over the full window
on all symbols despite correct entry logic — Sonnet code review, Claude-verified):

- **QM5_12985** (D1 RSI2 MR, entry on first tick after midnight broker): NZD/AUD
  early-Asia releases sit inside the PRE30_POST30 window around the D1 open on most
  days → the one entry evaluation per day was news-blocked → 0 trades.
- **QM5_12986** (GDAXI M15 ORB, needs 4 contiguous session bars): with ALL events
  matching GDAXI, one blocked M15 bar breaks the ORB accumulation (max count 3 < 4);
  UK 07:00 UTC releases land exactly in the Xetra ORB window → near-zero completed ORBs.
- **QM5_12988** (XTIUSD): NO defect — honest starvation (verdict stands).

Second finding, same file (~old line 462): calendar staleness used `TimeGMT()` (real
wall clock) — Strategy-Tester results depended on WHEN the backtest was executed
relative to the calendar file mtime (>14d gap ⇒ INIT_FAILED). Not live-relevant
(live uses the native MT5 calendar API; CSV path is tester-only, see `QM_NewsFilter.mqh`
~line 925), but a determinism landmine — especially with the refresh task dead during
scheduler outages.

## Fix (commit `89963ff75`)

1. `QM_NewsIndexCurrencies()` mapping: NDX/SP500/SPX500/WS30/US30/US500/USTEC→USD,
   GDAXI/GER40/DE40/STOXX50E/EU50/ESP35/FRA40/F40→EUR, UK100/FTSE100→GBP,
   JP225/NIK225→JPY. Mapped symbols are affected only by their economy's events.
   **Unknown short symbols remain fail-closed** (`return true`, unchanged).
   News protection stays intact (Edge-Lab/FTMO requirement) — this is a scoping fix,
   not a filter removal.
2. Staleness gate skipped under `MQLInfoInteger(MQL_TESTER)` (dispatch harness enforces
   calendar freshness for tester runs; live keeps fail-closed).

Recompiled: QM5_12985 + QM5_12986 (0 errors each, serial builds; logs under
`framework/build/compile/20260705_1141*`). Q02 requeued fast-lane
(`requeue_reason=news_filter_index_fix_89963ff75`, 4 items: 12985 NDX/SP500/GDAXI,
12986 GDAXI).

## Impact assessment

- **Past index-EA gate evidence remains VALID.** The defect was a pure handicap
  (over-blocking); every index EA that passed gates did so despite it. Nothing is
  invalidated; no requeue wave is warranted.
- **T_Live untouched** — deployed .ex5 binaries predate the fix; the change reaches
  live sleeves only through a future OWNER-approved rebuild/redeploy. Live news
  gating runs on the native MT5 calendar path anyway.
- **Forward effect:** rebuilt/new index EAs will fire more (entries near foreign
  events no longer blocked). Expect somewhat higher trade counts on NDX/SP500/GDAXI/
  WS30 builds vs their pre-fix siblings; gate bars unchanged.
- Framework include change ⇒ affects every FUTURE compile. Flagged SELF_REVIEW for
  Codex spot-check alongside 9f2792c5c and 7afcc62e3.

## Evidence

- Review transcript: Sonnet agent (session b18f380a, 2026-07-05); code lines verified
  by Claude directly (`QM_NewsFilter.mqh:305-358`, `:490-502` post-fix).
- Zero-trade evidence: Q02 summaries `D:\QM\reports\work_items\...\QM5_12985\...\summary.json`
  (0 trades, full window, all 3 symbols), 12986 prescreen ditto.
- Compile logs: `C:\QM\repo\framework\build\compile\20260705_114126\` + `...114141\`.

## Follow-up (same day): the ACTUAL 12985/12986 fire-blocker — uninitialized symbol_slot

The news fix was real but NOT sufficient: re-runs with the fixed .ex5 (verified fresh
on all terminals) still produced 0 trades. Empirical smoke autopsy found the smoking
gun in the tester log (`...\19743dd7...\QM5_12985\20260705_121117\raw\run_01\20260705.log`):

```
EA_MAGIC_NOT_REGISTERED: invalid symbol_slot=-74591040
```

Both agent-built EAs declare `QM_EntryRequest req;` in OnTick and never assign
`req.symbol_slot` (the skeleton line `req.symbol_slot = qm_magic_slot_offset;` —
present in e.g. QM5_10209, which fires 1162 trades — was omitted). Stack garbage →
`QM_MagicChecked` fails → EVERY entry silently rejected (the resolver warn throttles
to one log line per (ea,slot) pair — near-invisible in an 8-year run).

**Fix (commit `9e4cfedb1` + pump auto-commit `124ff9f50`):** `ZeroMemory(req);` after
declaration in both EAs; recompiled 0/0; Q02 requeued fast-lane
(`requeue_reason=symbol_slot_zeromem_fix_9e4cfedb1`).

**Class assessment (undefined behavior, stack-luck):** ~30 older EA sources share the
no-init/no-assign pattern, but it is NOT deterministically fatal — QM5_10490 (same
pattern) fires 842 trades; outcome depends on stack layout per build. Wave-1 calendar
EAs verified clean (16/16 assign symbol_slot). Recommended durable fix for Codex
review (Tue 07-07): default-initializing constructor on `QM_EntryRequest` in
`QM_Entry.mqh` (framework-level, protects all future builds) + optional later sweep of
historical zero-/low-trade FAILs among the ~30 pattern EAs for false negatives.
**Build-mission rule going forward: every agent-built Strategy_EntrySignal MUST set
`req.symbol_slot` (or the EA must ZeroMemory the request) — add to build prompts.**
