# QM5_20004 (turn-of-month-index-long, GDAXI+NDX) — Q02 INFRA_FAIL x3 root cause

Date: 2026-07-21. Author: Claude (infra diagnosis, headless).
Work items: `ec31f192-30e8-47eb-8e87-004a6d55ec11` (GDAXI.DWX), `90c4751d-7547-450d-8974-6d24461eaa7e` (NDX.DWX), both Q02 `backtest`, both ended `status=failed / verdict=INFRA_FAIL / final_failure=summary_missing_retries_exhausted` after the 2026-07-20 staged-recovery requeue also exhausted.

## Verdict (one line)

**The EA is innocent.** Both failures are the shared-`bases`-store history-lock class: MT5 could not serve a needed symbol's history from the ONE junctioned `D:\QM\mt5\T1\Bases` store under cross-terminal sharing-violation contention — for GDAXI this discarded an otherwise **finished, profitable pass** at result-latch time; for NDX it killed the pass at t=0. No rebuild required; no registry/resolver/set defect exists.

## Ruled out (static checks, all clean)

| Check | Evidence |
|---|---|
| Magic registry rows | `framework/registry/magic_numbers.csv` lines 15076–15077: `20004,turn-of-month-index-long,0,GDAXI.DWX,200040000,2026-07-19,claude,active` and `...,1,NDX.DWX,200040001,...,active` |
| Resolver contains 20004 | `framework/include/QM/QM_MagicResolver.mqh` packed arrays contain ea_id 20004 + magics 200040000/200040001; commit `d2bf65d80` (2026-07-19 20:20:15) added registry rows + resolver entries + `.ex5` **atomically** (correct order-of-operations) |
| Stale-.ex5 class | Repo `.ex5` mtime 2026-07-19 20:19:36 (323,662 B), source 20:17:52 — binary newer than source; deployed copy `D:\QM\mt5\T9\MQL5\Experts\QM\...ex5` SHA256 `951B7697DE401D22F46829970C1004A3FCC23D902270546FA335DFEB4B3AAD24` == repo SHA256 (identical) |
| Set files | `sets/*_GDAXI.DWX_D1_backtest.set`: `qm_ea_id=20004`, `qm_magic_slot_offset=0`, ENV backtest, `RISK_FIXED=1000`/`RISK_PERCENT=0`; NDX set has slot offset 1. Matches passing sibling 20010's set shape |
| symbol_slot-UB build rule | `QM5_20004_turn-of-month-index-long.mq5:58` sets `req.symbol_slot = qm_magic_slot_offset` after `ZeroMemory(req)` (OnTick:220) — rule satisfied |
| ONINIT_FAILED family | Disproved by runtime evidence below: GDAXI pass initialized, traded 27 round trips, and returned an OnTester value |

## Runtime evidence — GDAXI.DWX (T9)

Agent log `D:\QM\mt5\T9\Tester\Agent-127.0.0.1-3007\logs\20260720.log` (UTF-16), pass of 18:48 local:

```
18:48:38.953  Tester   expert file added: Experts\QM\QM5_20004_turn-of-month-index-long.ex5. 323715 bytes loaded
18:48:39.012  Tester   GDAXI.DWX,Daily: testing ... from 2018.07.02 to 2022.12.31 started with inputs: (qm_ea_id=20004, slot 0 ... all correct)
18:51:21.352  Tester   final balance 101535.65 USD
18:51:21.352  Tester   OnTester result 1.583744188786972          <-- pass FINISHED, 27 round trips
18:51:21.354  Symbols  EURUSD.DWX: symbol to be synchronized
18:51:21.381  History  EURUSD.DWX: history synchronization error [Not found]   <-- fatal for the result latch
18:51:21.593  Tester   ... Test passed in 0:02:42.634 ... EURUSD: generate 169572782 ticks ... thread finished
18:51:23.616  127.0.0.1  tester forced to close
```

Terminal log `D:\QM\mt5\T9\logs\20260720.log` line ~197938:

```
18:51:22.676  Tester  last test passed with result "some error after pass finished" in 0:00:00.000
18:51:23.584  Terminal exit with code 0
```

No `report.htm` written; `raw/run_01/` holds only `tester.ini` → run_smoke `valid_report_latched=False` → `summary_missing` → INFRA_FAIL (mapping: `tools/strategy_farm/farmctl.py:1893`). The 22:29:23 retry (work-item log `D:\QM\strategy_farm\logs\work_item_ec31f192-....log`, terminal pid 15020) shows the identical signature: testing 22:29:28 → 22:32:05 "some error after pass finished".

Key mechanics: GDAXI.DWX is EUR-quoted in a USD-deposit tester, so every pass pulls **raw EURUSD** as the conversion symbol (169.5M ticks generated in-pass). At result finalization the agent re-requests conversion-symbol history from the terminal; the terminal could not serve it (locked store, see below) and MT5 then marks the *finished* pass as errored and discards the report.

## Runtime evidence — NDX.DWX (T4)

Agent log `D:\QM\mt5\T4\Tester\Agent-127.0.0.1-3004\logs\20260720.log` (also agents 3007/3008 for the earlier inner retries at 18:39/18:41/18:42):

```
22:29:14.626  Symbols  NDX.DWX: symbol to be synchronized
22:29:14.635  History  NDX.DWX: history synchronization error [Not found]
22:29:14.635  Tester   cannot get history NDX.DWX,Daily
18:42:48.315  Tester   unexpected end of testing            (identical class, batch-1 attempt)
```

Same class, different kill point: here the **test symbol itself** could not be served, so the pass dies in ~40 ms — which produces exactly the "runs ~45s (terminal boot) then exits 0:00:00.000" surface signature. T4's terminal log has 1,595 `'NDX.DWX' file opening or reading error [32]` lines on 07-20.

## Root cause — shared bases store + live-login writers

1. **Topology:** `D:\QM\mt5\T2..T10\bases` are all NTFS junctions to `D:\QM\mt5\T1\Bases` (created 19.05.2026 16:11; verified via `dir /A`). This shares not only `bases\Custom` (known, by design) but also the **raw `Darwinex-Live` history store**.
2. **Writers:** every transient tester terminal spawn logs into the **live account 4000090541** ("authorized on Darwinex-Live ... trading has been enabled", terminal log at every spawn) and syncs/appends live quote history into that same shared store. With ~5 concurrent spawns, exclusive-write opens collide with reads: T9's 07-20 terminal log alone has **217,232** `file opening or reading error [32]` (sharing-violation) lines across `EURUSD`, `EURUSD.DWX`, `EURGBP.DWX`, `NDX.DWX`, ... (other terminals: ~700–5,800/day — same class, lower intensity).
3. **Effect:** when the locked file is (a) the conversion symbol at pass end → finished pass discarded ("some error after pass finished", 291 on T9 / 17–196 on other terminals on 07-20 — the fleet-wide standing retry noise); (b) the test symbol at pass start → instant `cannot get history`.
4. **Why 20004 exhausted all retries:** its GDAXI attempts were all claimed by **T9**, the sickest terminal (07-20: 283 "some error" vs 64 "successfully finished" ≈ 18% success; T1 ≈ 65%), and its NDX attempts hit the NDX.DWX lock storm on T4. Combined with the "handoff_2026-07-20b_urgent_backfill" priority wave flooding GDAXI/NDX work (which itself multiplies EURUSD-conversion traffic), retries (`MAX_WORK_ITEM_RETRIES=3`, `farmctl.py:4609`) burned out. Since 07-19: GDAXI 126 INFRA_FAIL vs 58 PASS; NDX 68 INFRA_FAIL vs 23 PASS; storm still active 2026-07-21 04:0x–04:40 UTC (GDAXI `summary_missing_retries_exhausted` streak on T7/T2).
5. **Why sibling 20010 passed the same evening:** XAUUSD is USD-quoted — no EURUSD conversion dependency at pass end, and its symbol history wasn't in the contended set.

Note: T9 additionally produced a 1.6 GB tester log on 07-19 (`D:\QM\mt5\T9\Tester\logs\20260719.log`, 1,609,381,078 B) — log-bomb-scale spam of the same History errors; worth purging in the next quiet window.

## Fixed now (minimal)

- **Requeued both Q02 rows** (2026-07-21T04:43:12Z, staged-recovery pattern): `status failed→pending`, `verdict=NULL`, `attempt_count=0`, `claimed_by=NULL`; payload: cleared stale runtime + failure keys (per `terminal_worker.py:497` `_STALE_RUNTIME_PAYLOAD_KEYS`), set `requeue_reason=infra_shared_bases_history_lock_diag_20260721`, `requeued_by=claude_infra_diag_20260721`, **`avoid_terminals=["T9"]`** (code-supported steering, `terminal_worker.py:480 _payload_avoid_terminals`). `priority_track=true` + reason preserved.
- **No rebuild, no resolver regen, no set-file change** — deliberately: static state is provably correct, and a rebuild would only churn the build lane.
- **No mutation of `bases\`** — factory is ON; the shared store must not be touched live.

## Deferred — proposed Saturday-window fix (OWNER decision needed)

The structural fix needs Factory OFF (quiet window). Options, cheapest first:

1. **Stop live-history writes from transient spawns:** tester spawns do not need a live login for custom-symbol (.DWX) backtests except for raw conversion symbols. Either pre-seed the raw conversion pairs once and run spawns offline, or
2. **Remap custom-symbol profit/margin conversion to `.DWX` pairs** (e.g., GDAXI.DWX → EURUSD.DWX) in the custom symbol specs, so the tester never touches the raw `Darwinex-Live` store, or
3. **De-junction the raw `Darwinex-Live` store only** (keep `Custom` shared): per-terminal raw stores end write-write collisions at ~1.7 GB/major-symbol disk cost.

Any option must be validated with the standard CSV/log evidence (broker vs custom symbol probe) before factory-wide rollout. Interim (no window needed): use `avoid_terminals` steering for priority items, and consider throttling concurrent EUR-quoted-index Q02s while the GDAXI/NDX backfill wave drains.

OWNER preference (2026-07-21): the live login (link 2) is NOT a concern — do not
touch it. Primary weekend fix = **link 3 (remap custom-symbol profit/margin
conversion to `.DWX` pairs)**: surgical, zero extra disk, removes the fatal pass-end
read from the contended raw store. **Link 1 (de-junction the raw store)** is the
belt-and-suspenders option if the ~1.7 GB/symbol/terminal disk cost is acceptable —
it eliminates every cross-terminal collision. Weekend ToDo block C.

## Mitigation LANDED (factory-ON, no OFF window) — 2026-07-21

`terminal_worker.py` commit `3d6fc09c9` (verified by a 3-lens adversarial workflow,
0 blockers): the shared-bases storm signature (`summary_missing` with the tester
having run but no valid report latched) is reclassified as a TRANSIENT infra class —
auto-requeued via staged recovery with `avoid_terminals` accumulation (whole-fleet
guard), on a SEPARATE `transient_infra_attempts` counter (cap 6, exponential backoff
45→600s) that never consumes the strategy `MAX_WORK_ITEM_RETRIES` budget; exhaustion
falls through to a real `INFRA_FAIL`. Genuine strategy verdicts (PASS/FAIL/ZERO_TRADES/
RETIRE/DRAFT_DEFECT) all produce a summary and are classified BEFORE this branch — never
masked (verified + test). 11 new tests. Storm-hit index items now self-heal instead of
burning to INFRA_FAIL after 3 tries.

**Deferred hardening (verified as CONCERN, non-blocking):** the detector reads the
terminal's SHARED daily log tail with no per-run time correlation, so during a storm a
stale token from a neighbor/earlier pass can sweep a GENUINE non-storm no-summary
failure (ONINIT_FAILED / stale-.ex5 / real DATA_MISSING) into the transient class —
delayed by ≤6 backoff cycles + mislabeled `final_failure`, but self-terminating and
never verdict-masking. The clean fix (scope the token match to the run window) requires
comparing MT5 log-line times (server-local GMT+1/+2) against the UTC `started_at_iso` —
a timezone-careful correlation that must NOT be rushed into the dispatch path (a naive
compare would wrongly reject valid storm tokens and regress the mitigation). Scheduled
as a bounded follow-up, not forced under time pressure.

## Reconciliation of prior evidence

- "T9 Core log EURUSD history synchronization error / ~205k error[32] lines" — confirmed, and identified as the terminal-side cause of the agent-side `[Not found]`.
- "news selftest / framework symbol probe / live-chart sync suspicion" — narrowed: the EURUSD pull is the tester's own **deposit-currency conversion** path (EA framework code contains no EURUSD reference in 20004's include graph; `QM_CurrencyStrength.mqh:15` is not included by `QM_Common.mqh`).
- "ONINIT_FAILED / stale-.ex5 family" — excluded by the successful 18:48 pass (trades + OnTester value) and hash-identical deploy.
