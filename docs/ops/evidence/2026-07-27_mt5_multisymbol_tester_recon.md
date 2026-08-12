# RECON 2 — MT5 Strategy Tester with several .DWX symbols at once: capability + cost

Date: 2026-07-27 · Branch: `agents/board-advisor` · Author: Claude
Scope: empirical recon only. **Nothing was launched.** No `Factory_OFF/ON`, no
`T_Live`, no terminal killed or reused. All figures are from our own terminals,
reports, registries and framework source — not from general MT5 knowledge.

## Bottom line

A joint multi-symbol .DWX backtest **is feasible here, and is already a solved,
in-production pattern.** The factory runs multi-symbol real-tick baskets through the
full automated pipeline today (`QM5_12781` reached Q05→Q08, 2026-06-30…07-08). The
machinery the RECON prompt says to reuse (`host_symbol`, `basket_manifest.json`,
`QM_SymbolGuardInit` + `QM_BasketWarmupHistory`, `QM_BasketOrder.mqh`) exists and is
what the FTMO joint EA should be built on.

The sleeve set that actually matters collapses to **two symbols** — `USDJPY.DWX`
(9936, 13213) and `XAUUSD.DWX` (10553, 10848); `GDAXI` (13301) is already disqualified
by the 30-day dormancy rule. A 2-symbol basket is the *cheapest and best-proven*
configuration (it is exactly the `QM5_12781` / `QM5_12533` shape), and it dodges the
two GDAXI-specific hazards documented below.

Cost per joint run: **~20–44 GB working-set RAM and roughly 1.5–3 h wall-clock** for an
8–9-year 2-symbol real-tick run. That is practical for a handful of ad-hoc runs on a
free terminal **when the fleet is quiet** — it is not practical to launch alongside 7
busy real-tick terminals (pagefile-storm risk). This does close the equity-gap and the
intraday-interleaving gap: one account = one real equity curve with real tick ordering.

---

## 1. Multi-currency testing in THIS installation

**An EA runs on ONE chart symbol but can trade others — confirmed, and the loading
semantics are non-obvious.** The controlling evidence is the framework's own history-
load fix comment:

`framework/include/QM/QM_SymbolGuard.mqh:100-141` (FW9, 2026-05-24):

> "basket EAs … called `SymbolSelect(symbol, true)` in OnInit which only adds the
> symbol to Market Watch — **the MT5 tester does NOT load that symbol's history into
> the testing context.** First per-symbol `iClose` then returned 0 or stale data, the
> strategy made no decisions, MT5 fast-finished, run_smoke flagged
> `NO_REAL_TICKS_MARKER_FAST_FINISH` → INVALID. Fix: after `SymbolSelect`, force MT5 to
> load `warmup_bars` of history per symbol via `CopyClose`. The `CopyClose` itself
> triggers the tester's symbol-data sync."

So the answer to "does the tester load tick history for secondary symbols
automatically?" is **NO — not from `SymbolSelect` alone.** The EA must force the sync
per secondary symbol (`QM_BasketWarmupHistory`, `QM_SymbolGuard.mqh:112-141`, which
calls `CopyClose`). **What happens when it cannot load:** the secondary symbol returns
0 bars / stale data, the strategy makes no decisions, the tester fast-finishes, and the
run is classified INVALID / `NO_HISTORY`. Concrete instance —
`docs/ops/evidence/2026-06-27_qm5_12533_multisymbol_ram_guard.md:33-40`: the
`EURJPY.DWX/GBPJPY.DWX` basket produced `Bars: 0`, journal
`"EURJPY.DWX,Daily: 0 ticks, 0 bars generated"` — but the root cause there was a
low-RAM launch, not bad history (see §4).

**Live example to copy** — `QM5_12781` (USDJPY/AUDJPY cointegration):
- `framework/EAs/QM5_12781_.../QM5_12781_....mq5:118-131` — `OnInit` calls
  `SymbolSelect` on both legs, then `QM_SymbolGuardInit(allowed)` then
  `QM_BasketWarmupHistory(allowed, PERIOD_D1, …)`.
- `basket_manifest.json` contract: `host_symbol`, `host_timeframe`, `basket_symbols`,
  `traded_symbols`, `tester_currency`, `tester_deposit`. Q08 requires `host_symbol`.
- Order plumbing already exists: `framework/include/QM/QM_BasketOrder.mqh`
  (`QM_BasketOrderRequest` carries `symbol` + `symbol_slot`, per-symbol magic).

**Prior multi-symbol evidence found in-repo / on-disk:**
- `docs/ops/CROSS_SECTIONAL_BASKET_PIPELINE_DESIGN_2026-05-22.md` — design of the
  basket pipeline.
- `docs/ops/evidence/2026-06-27_qm5_12533_multisymbol_ram_guard.md` and
  `..._jpy_deposit_active_cpu_ceiling.md` — a live 2-symbol Q02 run + its RAM guard.
- `D:/QM/reports/pipeline/QM5_12781/{Q05,Q06,Q07,Q08}` — a 2-symbol basket that
  **completed the full automated evidence pipeline through Q08.** This is the
  strongest single proof that multi-symbol .DWX testing works end-to-end here.

**Per-sleeve magic:** magic = `ea_id*10000 + slot`; a joint EA assigns a distinct slot
per sleeve. `QM_BasketOrder.mqh` already keys open-position lookups by
`(magic, symbol)`. **News-filter hazard confirmed applicable:** each sleeve's order
request MUST set `symbol_slot` (or `ZeroMemory` the struct) — `symbol_slot` is a field
on `QM_BasketOrderRequest` (`QM_BasketOrder.mqh:23`) and an unset index is UB.

## 2. .DWX symbols with usable tick history over the sleeve window (~2017-10 → 2025-12)

Source of truth = the imported custom-symbol tick stores inside the terminals
(`<T>/bases/Custom/ticks/<SYMBOL>.DWX/`) plus `framework/registry/dwx_symbol_matrix.csv`
head/tail import timestamps. Real coverage, stated from the data — not assumed from the
trade streams:

| Symbol | Import head | Import tail | Tick store (T9 / T10) | Covers 2017-10→2025-12? |
|---|---|---|---|---|
| `USDJPY.DWX` | 2017-10-02 | 2026-04-06 | 958 MB / 958 MB | **Yes** (full) |
| `XAUUSD.DWX` | 2017-10-02 | 2026-04-06 | 1.9 GB / 1.9 GB | **Yes** (full) |
| `GDAXI.DWX`  | **2018-07-02** | 2026-04-02 | 415 MB / 415 MB | Partial — **starts 2018-07**, ~9 mo of window missing |
| `XTIUSD.DWX` | 2017-10-02 | 2026-04-06 | 435 MB / 435 MB | **Yes** (full) |

Dates decoded from `dwx_symbol_matrix.csv` `head_ms`/`tail_ms` epochs. Both free
candidate terminals (T9, T10) are fully provisioned with all four caches.

**On the matrix "FAIL" verdicts:** every row reads `FAIL_tail_mid_bars` /
`FAIL_tail_bars` with `bars_one_shot=0`, `bars_one_shot_err=(-2,'Terminal: Invalid
params')`, `maxbars=100,000`. **These are tick-value / canonical-name verification
concerns, not tester-usability.** They record (a) a `custom_tv` vs `broker_tv`
rel-error ~0.001, (b) a ~2 h tail delta = the GMT+2/+3 broker-time offset, and (c) a
one-shot `CopyRates` probe truncated by the 100k-maxbars ceiling. They are **not**
evidence the symbol can't backtest. Direct usability proof, dated today:
- `QM5_9936` `USDJPY.DWX` H1 → **PASS** this morning, 336M real ticks (§4).
- `QM5_1567` `XAUUSD.DWX` → running Q07 on T7 right now.
- `QM5_10704` `GDAXI.DWX` → running Q05 on T1 right now.

So for the sleeves that matter (USDJPY + XAUUSD) the joint window is **fully covered**.
GDAXI is both disqualified by dormancy AND short 9 months of window — a second reason
to keep it out of the joint EA.

## 3. Tick model

**Model 4 = "Every tick based on real ticks", unchanged for multi-symbol.**
- Policy: `framework/registry/tester_defaults.json:16-19` (`p2_real_tick_policy.model:
  4`).
- Confirmed on the live run: `QM5_9936` summary `model: 4`, `real_ticks_marker: true`,
  report "History Quality: 91% real ticks"
  (`D:/QM/reports/pipeline/QM5_9936/20260727_053637/summary.json:97,145` + report.htm).

Multi-symbol does **not** change the model *number*; it changes the *volume* of tick
data loaded. In Model 4 the tester uses real ticks for the chart symbol and, when the
EA trades a secondary symbol, uses that symbol's own tick data — which our `.DWX`
symbols have (the on-disk tick stores in §2 are real per-tick data; 91% real / ~9% M1
gap-fill). No new model decision is required; the joint EA inherits Model 4.

## 4. Cost — wall-clock and RAM for one joint 8-year multi-symbol run

**Single-symbol anchor (measured today):** `QM5_9936` `USDJPY.DWX`, H1, Model 4,
2017.01.01–2025.12.31 (9 yr): **336,370,591 real ticks**, 50,708 bars, report 3.8 MB.
End-to-end wall-clock ≈ **19–20 min** (run dir created 05:36:37Z → summary written
05:56:16Z; five consecutive neighborhood runs spaced ~19–21 min apart confirm the
cadence). Ordinary single-symbol working set ≈ **6–7 GB** (`terminal_worker.py:55`).

**Multi-symbol, from our own worker's measured constants** (`terminal_worker.py:66-80`):
- `MULTISYMBOL_RAM_MIN_FREE_GB = 12.0` — min free physical RAM to even launch.
- **"Observed multi-symbol working sets range from 20–44 GB"** (line 70).
- `MULTISYMBOL_COMMIT_MIN_FREE_GB = 48`, reservation 44 GB held for **3600 s** because
  "a multisymbol loader materializes its working set over **tens of minutes**"
  (lines 72-80).
- The 2-symbol D1 basket `QM5_12533` peaked ~12.9 GB and OOM'd only because the fleet
  was contended (`..._ram_guard.md:37`); its Q02 timeout budget was **120 min**.

**Estimate for the FTMO joint EA (USDJPY + XAUUSD, ~8–9 yr, Model 4):**
- **RAM: 20–44 GB working set.** XAUUSD's tick store (1.9 GB, ~2× USDJPY) dominates;
  gold tick density is high. Budget the 44 GB worst case.
- **Wall-clock: ~1.5–3 h end-to-end.** Tick throughput is the driver: USDJPY 336M
  ticks ≈ 20 min; XAUUSD carries ~2× the tick store, so the merged 2-symbol stream is
  on the order of ~1 billion ticks; plus tens-of-minutes multi-symbol init/sync. This
  is consistent with the 120-min budget the D1 basket used (and an intraday host is
  heavier than D1). Adding GDAXI would push both figures up — another reason to keep
  the joint EA to the two symbols that matter.

**Verdict on practicality:** feasible for a *handful* of ad-hoc joint runs, not for
bulk. One run costs ~2 h and up to ~44 GB. It must run when the fleet is quiet: with 7
terminals each holding ~6–7 GB real-tick working sets, launching a 44 GB job now would
balloon into the pagefile (the 2026-07-26 17:45 pagefile storm, `terminal_worker.py:76`).

## 5. Terminal availability RIGHT NOW (`farmctl.py mt5-slots`, 2026-07-27 ~11:00 local)

| Terminal | State |
|---|---|
| T1 | BUSY — `QM5_10704` GDAXI.DWX Q05 |
| T2 | BUSY — `QM5_11619` GBPUSD.DWX Q02 |
| T3 | BUSY — pipeline run |
| T4 | BUSY — `QM5_1634` EURUSD.DWX Q04 |
| T5 | "free" but **DEAD tester-indicator engine — excluded, never use** |
| T6 | BUSY — `QM5_11063` EURJPY.DWX Q04 |
| T7 | BUSY — `QM5_1567` XAUUSD.DWX Q07 |
| T8 | BUSY — `QM5_11147` USDJPY.DWX Q04 |
| **T9** | **FREE — fully provisioned with all 4 .DWX caches** |
| **T10** | **FREE — fully provisioned with all 4 .DWX caches** |
| T_Live | OFF-LIMITS (live trading; not touched) |

**Safe candidate for a future ad-hoc joint run: T9 or T10** (NOT T5, NOT T_Live). Free
physical RAM now = 36.1 GB of 63.1 GB. That clears the 12 GB launch floor, but a 44 GB
worst-case working set alongside 7 busy terminals would spill to pagefile — so the run
should wait for the fleet to drain (or be scheduled into a quiet window). **Nothing was
started.**

## 6. Known ad-hoc failure classes — exposure of a joint multi-symbol run

1. **Cold-cache `NO_HISTORY` on first attempt — EXPOSED, and amplified.** Each
   *secondary* symbol's cache must warm, not just the chart symbol. `SymbolSelect`
   alone does not sync history in the tester (§1); the EA MUST call
   `QM_BasketWarmupHistory`, or the first per-symbol read returns 0 bars → fast-finish →
   INVALID. Self-heals on worker retry; **do NOT re-import `.DWX` history**.
2. **`launch_fault` — EXPOSED** (true of any heavy ad-hoc launch). A child that exits in
   `< LAUNCH_FAULT_MIN_SECONDS = 10 s` is a host/pwsh fault, not a clean run
   (`terminal_worker.py:81-88`). Unambiguous here because multi-symbol init takes tens
   of minutes; a fast exit is always a fault, back off and retry.
3. **`CustomTicksReplace` cache trap (needs Factory OFF/ON) — NOT EXPOSED** for a
   read-only joint backtest. That trap is triggered by **re-importing** custom ticks
   (`CustomTicksReplace` during a symbol rebuild). A joint backtest only **reads**
   existing custom history; it never re-imports. Since all needed symbols already have
   full history (§2), no re-import is required. **Caveat / hard stop:** if any `.DWX`
   symbol ever *did* need re-import, that would hit the trap and require an OFF/ON cycle
   — which I may not perform; that would be an OWNER-routed blocker. Current evidence:
   not required.
4. **ADDITIONAL — shared-bases history-lock storm (not in the prompt's list, but
   material).** `terminal_worker.py:94-114`: T2–T10 `bases` are NTFS junctions to ONE
   T1 store that also holds live Darwinex-Live history. Concurrent spawns collide on
   sharing violations; **index symbols are worst-hit — measured GDAXI 126 INFRA vs 58
   PASS (~2/3 burned)**. A joint run touching **GDAXI** under fleet concurrency is
   exposed to this. USDJPY + XAUUSD (forex + metal) are far less exposed. Mitigation:
   run when the fleet is quiet; keep GDAXI out of the joint EA (it is disqualified
   anyway).

## Recommended next step

Build the FTMO joint EA as a standard **2-symbol basket** (`host_symbol = USDJPY.DWX`,
`basket_symbols = [USDJPY.DWX, XAUUSD.DWX]`) reusing `QM_SymbolGuardInit` +
`QM_BasketWarmupHistory` + `QM_BasketOrder.mqh`, distinct magic slot per sleeve,
`symbol_slot` set on every order, `RISK_FIXED` (backtest-only, no live path). Run it
ad-hoc on **T9 or T10 in a quiet fleet window**, Model 4, 2017-10→2025-12. Expect
~20–44 GB and ~1.5–3 h. The resulting single-account equity curve is what closes the
equity-gap (`docs/ops/evidence/a5768d03_equity_export_gap_2026-07-27.md`) and the
intraday-interleaving hazard flagged in
`docs/ops/evidence/2026-07-27_single_account_adversarial_review.md`, and yields realized
USDJPY↔XAUUSD correlation directly.
