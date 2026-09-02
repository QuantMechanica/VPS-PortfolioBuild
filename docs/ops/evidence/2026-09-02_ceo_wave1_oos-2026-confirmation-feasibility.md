# 2026 Out-of-Sample Confirmation — Feasibility and First Read

Auditor dimension: `oos-2026`. 2026-09-02. Read-only. Every claim below is file/DB-evidenced.

## Bottom line

1. **2026 data physically exists and is fleet-consistent for every live-sleeve and frontier symbol**, covering **2026-01-01 through ~2026-04-06** (Jan/Feb/Mar full, April cut at ~the 6th). Beyond ~Apr 6 only a few indices (NDX, JPN225) carry data; the FX/metals majors stop at Apr 6.
2. **That 2026 segment is NOT in the signed archive manifest.** The owner-approved manifest (`archive_manifest_owner_approved.json`, sha `fe0dd0fd…`) explicitly covers `archive_years = 2017…2025` with `current_year = 2026` deliberately excluded as the *mutable* year. A 2026 backtest runs against unsigned, non-isolation-covered tick data.
3. **Every Q09/Q11 verdict scored to `2017.01.01 → 2025.12.31`.** No pipeline work item anywhere ran a scored 2026 window (2 stray OPT_CENSUS rows aside). **No existing run — including the live-news A/B diagnostics — covers 2026;** they all cut at `2025-12-31T23:59:59Z`. There is therefore **no existing 2026 P&L to extract from the pipeline**.
4. **An OOS `2026-01-01…2026-04-06` diagnostic is feasible today without touching any sealed criterion.** The `diagnostic_non_admission` plumbing already exists, is OWNER-blessed, and suppresses the admission cascade. Copy-on-claim does **not** fail-close on a non-manifest year (it privatizes per-symbol, not per-window), so the run dispatches cleanly. **But** the existing diagnostic runner is wired to the multi-year 40-cell Q09-NEWS contract; a clean 3-month read needs a small single-window runner (≈1 day build) reusing the same plumbing.
5. **Cost is trivial:** minimal regime read = **55 runs ≈ 2.5–3 terminal-hours** (~20–30 min wall at 10 terminals). The full news-A/B matrix version would be ~55–75 terminal-hours and is not needed for a regime read.
6. **The honest limitation:** a 3.2-month window on D1/H4 strategies yields only a handful of trades per sleeve — a **directional read, not a significance test** — and there is a **~3.5-month blind gap (Apr 6 → Jul 19) between the last backtestable tick and live-book start**, so even a clean 2026-OOS pass leaves the regime the book actually trades untested.

---

## 1 · Data availability

### 1.1 What exists per symbol (T1 `Bases/Custom/ticks`, confirmed identical on T5, T10)

Evidence: `D:/QM/mt5/{T1,T5,T10}/Bases/Custom/ticks/<SYM>.DWX/*.tkc`. XAUUSD `202601.tkc = 31,667,366 B` and `202604.tkc = 23,624,003 B` byte-identical across T1/T5/T10 → the mutable 2026 segment was fanned out fleet-wide (matches `DUKASCOPY_BACKFILL_PLAN` P4 "Verteilung des mutablen 2026-Segments auf T2–T10").

| Symbol | 2026-01 | 2026-02 | 2026-03 | 2026-04 (partial) | In live book? | In frontier? |
|---|---|---|---|---|---|---|
| EURUSD | full (5.6MB) | full | full (9.8MB) | ~Apr6 (2.7MB) | ✓ (×4) | ✓ |
| GBPUSD | full | full | full | ✓ | ✓ (×2) | ✓ |
| USDJPY | full | full | full | ✓ | ✓ (×2) | ✓ |
| USDCAD | full | full | full | ✓ (1.1MB) | – | ✓ |
| AUDUSD | full | full | full | ✓ (2.2MB) | ✓ (×2) | ✓ |
| AUDCAD | full | full | full | ✓ | ✓ | ✓ |
| EURGBP | full | full | full | ✓ (1.1MB) | ✓ | ✓ |
| XAUUSD | full (31MB) | full | full (41MB) | ✓ (23MB) | ✓ (×5) | ✓ |
| XAGUSD | full (22MB) | full | full | ✓ (2.5MB) | – | ✓ |
| XTIUSD | full | full | full | ✓ | ✓ | ✓ |
| XNGUSD | **thin** (1.0MB) | **thin** (0.7MB) | **thin** (0.7MB) | thin (0.4MB) | ✓ | – |
| NDX | full (37MB) | full | full | full (41MB); extends to **Jul-2026** | ✓ (×2) | ✓ |
| SP500 | full | full | full | ✓ | ✓ | ✓ |
| GDAXI | full | full | full | ✓ | ✓ (×2) | ✓ |
| WS30 | full | full | full | ✓ | – | ✓ |
| JPN225 | **absent** | full | full | ✓ | – | – |
| XBRUSD | **absent** | full | full | ✓ | – | – |

Notes:
- The tiny `202605.tkc`–`202608.tkc` files (≈500–800 KB) are early-May cutoffs; the `202609.tkc` (1,784 B) files are live-terminal placeholders (mtime Sep-01/02) — **not** backtestable months.
- **12 distinct live-sleeve symbols** (GDAXI, USDJPY, EURUSD, XTIUSD, AUDCAD, AUDUSD, GBPUSD, NDX, SP500, XAUUSD, XNGUSD, EURGBP) → **all have 2026-01…04 coverage.** Only caveat: **XNGUSD is tick-thin** (sleeve 12567/XNGUSD, live rank 1, weight 0.98) — OOS read for it will be noisy.
- The **frontier** distinct symbols (XAUUSD, XTIUSD, XAGUSD, NDX, GDAXI, EURUSD, WS30, USDCAD, SP500, USDJPY, GBPUSD, AUDUSD, plus FX legs of the basket/cointegration EAs AUDJPY/NZDCAD/EURAUD/EURJPY) → **all covered**.
- **The requested window `2026-01-01…2026-04-06` is exactly the maximal common fully-covered 2026 window** across the whole universe — it is not an arbitrary choice, it is "all the 2026 data that reliably exists."

### 1.2 Signed manifest — 2026 is explicitly out of scope

`D:/QM/strategy_farm/state/custom_history_master_root.json` → manifest `…/custom_history_variant_a_20260809/archive_manifest_owner_approved.json`, `manifest_sha256 = fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`, `file_count = 3946`.

Parsed manifest: `archive_years = [2017…2025]`, `current_year = 2026`, tkc months `201710 … 202512`, **zero 2026 months**. `owner_approval.signed_by = OWNER`, `window_end_utc = 2026-08-09T22:00:00Z`.

`DUKASCOPY_BACKFILL_PLAN_2026-08-29.md` corroborates: "Signiertes Archiv … Jahre 2017–2025 … Ticks bis `202512.tkc`. Mutables Jahr 2026: über die alte TDS/TDM-Automatik importiert bis ~06.04.2026 (TDS-Lizenz seit 05.05.2026 ausgelaufen)."

**Consequence:** any 2026 backtest reads *mutable, unsigned, non-Variant-A-isolated* tick data. Acceptable for a **non-admission diagnostic**; it must never feed a sealed gate verdict, and the report must label the data provenance.

### 1.3 Tester windows used by Q09/Q11 (DB)

`work_items`, read-only:
- **Q09**: `data_window_start='2017.01.01', data_window_end='2025.12.31'` (265 rows); 48 rows NULL (window carried in the run-plan file, not the column); 1 outlier.
- **Q11**: `2017.01.01 → 2025.12.31` (21 of 22 rows); 1 outlier `2022.07.01→2022.12.31`.
- Fleet-wide `data_window_end` histogram: dominated by `2024.12.31` / `2022.12.31` / `2025.12.31`. **Only 2 rows (OPT_CENSUS) reference 2026** (`2019.01.01→2026.12.31`) and are stray, not a scored OOS run.
- The live-news A/B diagnostic (`q09_live_news_backfill.py`) hard-codes `full_to_utc="2025-12-31T23:59:59Z"`, `holdout 2024-01-01…2025-12-31`. **It does not cover 2026.**

→ **Verdicts score to 2025-12-31; nothing in the factory has ever measured 2026.** This is the data-side confirmation of audit finding D9-03.

---

## 2 · Feasibility of a non-admission 2026 OOS run

### 2.1 The mechanism exists

`diagnostic_non_admission` is a first-class payload flag (`farmctl.py`; created by `q09_live_news_backfill.py`, `q09_news_runner.py`, `qm5_35005_equivalence.py`). Its properties, verified in `farmctl.py`:
- `auto_enqueue_q10_after_q09_result` returns `{"enqueued": False, "reason": "diagnostic_non_admission"}` (line 17624) → **a diagnostic result never cascades into an admission gate.** It cannot move a pair toward Q10/Q11/Q14 or toward the 25-pair book trigger.
- The runner stages the **exact deployed EX5** via `staged_ex5_path` (`q09_expert = QM\<staged_ex5_path.stem>`, line 8788) rather than the numeric EA label — so it measures the real live binary.
- Rows are ranked *behind* admission/round-chain work (`_diagnostic_queue_rank`, line 1694) → **it never head-blocks the census/frontier.**

### 2.2 Copy-on-claim does NOT fail-close on 2026

`custom_history_copy_on_claim.py` `select_archive_rows_for_symbols` selects manifest rows **per claimed symbol** (all 3946 rows for that symbol), independent of the backtest date window. It fail-closes only if the manifest has *no archive rows for a claimed symbol* — impossible here (all frontier/sleeve symbols are in the manifest). The mutable 2026 `.tkc` files are simply left in place and read locally by the tester. **A 2026-windowed claim dispatches exactly like any other claim.** (Integrity caveat: the 2026 files are the shared inode family Variant-A was built to isolate; for a read-only diagnostic on stable files this is low-risk but must be noted.)

### 2.3 Gap: the runner is wired to a multi-year 40-cell contract

`q09.build_run_plan(...)` in the backfill enforces `complete_months=60` and asserts `cell_count==40` (8 news configs × 5 seeds). That contract assumes a multi-year window; a 3.2-month window breaks the `complete_months` assertion and produces a semantically odd "news A/B over a quarter with few events." **For a regime read the news matrix is unnecessary** — we want the raw deployed-config P&L. So the clean path is a **small single-window diagnostic runner** that reuses the `diagnostic_non_admission` plumbing (staged EX5, cascade suppression, ranking) but emits a single baseline backtest per (EA, symbol, TF) over the 2026 window. Estimated build: ~1 day on the Claude/Sonnet headless lane (no ROT — it touches no gate criterion).

### 2.4 `enqueue-backtest` cannot do this via a flag

`farmctl enqueue-backtest` has **no** `--data-window` / `--window-source` / `--diagnostic` argument (verified in the argparse block, lines 29566–29618). Windows are fixed per phase by the gate contract. So there is **no CLI shortcut** — a 2026 diagnostic must go through a campaign script. This is by design (windows are a sealed part of each gate).

---

## 3 · Exact enqueue recipe (DRY-RUN ONLY)

The `diagnostic_non_admission` campaign pattern already ships with a **`plan` (dry-run) vs `apply` (writes DB)** split — `q09_live_news_backfill.py` `build_parser()` exposes `plan`, `apply`, `rerun`, `refresh`, `status`. `plan` builds the run-plans + campaign JSON and writes **no** work_items row; `apply` runs `enqueue_campaign()` which does `INSERT INTO work_items(...)`.

**Recommended (single-window OOS runner), dry-run:**

1. Author `tools/strategy_farm/oos_2026_confirmation.py` as a copy of `q09_live_news_backfill.py` with these changes (Sonnet/headless, ~1 day, GREEN — no sealed criterion touched):
   - Universe = the 24 live sleeves (`book_manifest.sleeves` from `live_book_pulse.json`) **+** the 31 frontier pairs (`work_items` Q09/Q10_NEWS/Q11 frontier set). Each entry = (ea_id, symbol.DWX, timeframe, EX5, deployed/Q11 setfile).
   - Window: `full_from_utc="2026-01-01T00:00:00Z"`, `full_to_utc="2026-04-06T23:59:59Z"`, `selection == holdout == full` (single OOS block, no split), `complete_months=3`, **single seed**, **single config** (deployed news mode) → 1 cell per pair.
   - Payload additions: `"diagnostic_non_admission": True`, `"window_source": "oos_2026"`, `"staged_ex5_path": <deployed/Q11 ex5>`, `"risk_fixed": 1000.0`, `"risk_percent": 0.0` (matches the live-news diagnostic; RISK_FIXED for backtest per Hard Rules).
   - `tester_model="REAL_TICKS"`, `cost_profile="DXZ_CANONICAL_REAL_TICKS_V1"` (same as the live-news diagnostic, so cost assumptions match the book).
   - Phase = a diagnostic phase carrying `diagnostic_non_admission` (reuse `Q09_NEWS` as the backfill does — the cascade suppressor keys off the payload flag, not the phase).
2. **Dry run:** `cd C:/QM/repo && python -m tools.strategy_farm.oos_2026_confirmation plan --router-task-id <task>` → writes the campaign JSON + run-plans under an artifact root, **inserts nothing**. Inspect: per-pair window, staged EX5 sha, cell_count, terminal allow/avoid list.
3. **Do NOT run `apply`.** `apply` is the only step that writes `work_items` rows and requires an explicit go.

**Guardrails baked in:** non-admission (no cascade), diagnostic queue-rank (never head-blocks frontier), `avoid_terminals`/concurrency cap (5) so it cannot starve the census, RISK_FIXED, T_Live read-only (staged EX5 copied, live presets read-only).

---

## 4 · Terminal-hours estimate

Anchor: **7.2 min median wall per 1-year REAL_TICKS D1 cell** (audit brief, n=98; OPT_CENSUS cells confirmed 1-year D1 windows, e.g. `2021.01.01→2021.12.31`). The OOS window is ~3.2 months ≈ 0.27 yr; scaling by tick volume + ~30–60 s fixed tester startup → **~2.5–3 min per single-config OOS run** (H1/H4 sleeves add bars but stay bounded).

| Scope | Runs | Per-run | Terminal-hours | Wall @10 terminals |
|---|---|---|---|---|
| **Minimal regime read** (1 cell/pair, deployed config, 1 seed) — **recommended** | 24 live + 31 frontier = **55** | ~3 min | **~2.5–3 h** | **~20–30 min** |
| Full Q09-NEWS A/B matrix (40 cells/pair) — not needed | 55 × 40 = 2,200 | ~2 min | ~55–75 h | ~6–8 h (or ~33 h at the current ~66 cells/h fleet rate) |

**The minimal read is essentially free** — a rounding error against the ~3,500 terminal-h the 25-pair census will consume, and it runs behind the census without displacing it.

---

## 5 · Early evidence of 2026 regime decay — first read

**There is no pipeline 2026 P&L to extract** (§1.3): the only realized 2026 evidence is the **live DXZ book itself**, and even that does **not** cover the backtestable OOS window.

- **Backtestable OOS window:** 2026-01-01 … ~2026-04-06.
- **Live-book window:** since **2026-07-19** (24 sleeves; `live_book_pulse.json`), i.e. Aug–Sep 2026.
- **Blind gap:** **~2026-04-06 → 2026-07-19 (~3.5 months) has neither tick data nor live trading.** The regime the book actually trades (Aug–Sep 2026) is *later* than anything testable.

Realized live signal (from the audit digest, DB/state-file-sourced): equity ~99,205 / balance ~99,075 vs 100k start (**≈ −0.8 %**), **−2.6 % off HWM 101,871**, DD-guard `breached=false`; realized book Sharpe **−3.25 vs modeled +2.4** (−1.3σ over ~40 days); vault records "only 10 of 24 EAs traded in 7 days." This is *consistent with* 2026 regime decay **but does not isolate it** from slippage/cost, selection bias, or the partial-book execution problem — and it is statistically underpowered (a handful of trades per sleeve).

**What the proposed OOS-2026 read adds that nothing else can:** it is the **only** way to separate "the *strategies* stopped working in 2026" (in-sample 2024–25 vs OOS 2026-Q1 on the *same sleeves*, zero live-execution noise) from "live execution/cost is eating the edge." That makes it a **direct, cheap test of the audit-critique's omitted third hypothesis (regime decay)** — the one MNT-036's slippage-vs-absent-edge binary structurally cannot surface. Concretely: run scope-A, then diff each sleeve's OOS-2026-Q1 PF/expectancy against its sealed 2017–2025 (and 2024–2025 holdout) statistics already in the Q09/Q11 evidence.

---

## 6 · Recommended actions

| # | Action | Who | Effort | Zone |
|---|---|---|---|---|
| 1 | Build `oos_2026_confirmation.py` (single-window, non-admission, `window_source=oos_2026`), reusing the `diagnostic_non_admission` plumbing; **`plan` dry-run only**, inspect campaign JSON, stop. | claude-headless | ~1 day | GREEN |
| 2 | Run scope-A (55 runs, ~3 terminal-h) behind the census; diff OOS-2026-Q1 PF/expectancy vs each sleeve's sealed 2017–25 & 2024–25 holdout stats → regime-decay attribution feeding MNT-036 as its explicit third hypothesis. | claude-headless→claude-interactive | ~0.5 day + <1 h factory | GREEN |
| 3 | In every 2026-OOS artifact, stamp the provenance caveat: **unsigned mutable data, outside the Variant-A signed manifest, window ends ~2026-04-06, ~3.5-month blind gap to live start, low trade count = directional not significant.** | claude-headless | included | GREEN |
| 4 | Do **not** attempt to admit any 2026 result into a gate, and do **not** add a 2026 window to any sealed gate. If a signed 2026 test window is ever wanted, it goes through the Dukascopy backfill (DEFERRED) + a fresh OWNER manifest signature — **ROT**. | owner | — | ROT (park) |

---

## Evidence index

- Fleet tick files: `D:/QM/mt5/{T1,T5,T10}/Bases/Custom/ticks/<SYM>.DWX/2026{01..09}.tkc` (+ `.../history/<SYM>.DWX/2026.hcc`).
- Signed manifest: `D:/QM/strategy_farm/state/custom_history_master_root.json` → `…/custom_history_variant_a_20260809/archive_manifest_owner_approved.json` (`fe0dd0fd…`, 3946 files, `archive_years 2017–2025`, `current_year 2026`).
- Backfill plan (2026 cutoff, TDS expiry): `docs/ops/DUKASCOPY_BACKFILL_PLAN_2026-08-29.md`.
- DB windows: `work_items.data_window_start/end` per phase (read-only URI, `PRAGMA busy_timeout=30000`).
- Diagnostic mechanism: `tools/strategy_farm/farmctl.py` (lines 8776, 11930, 17624, 1694), `tools/strategy_farm/q09_live_news_backfill.py` (payload/INSERT at 531–600, windows at 471/1417/1835, `plan`/`apply` CLI at 2201–2254), `tools/strategy_farm/custom_history_copy_on_claim.py` (`select_archive_rows_for_symbols`).
- Live universe: `D:/QM/reports/state/live_book_pulse.json` `book_manifest.sleeves` (24), `live_book_dd_guard_state.json` (`breached=false`).
- Frontier: `work_items` Q09/Q10_NEWS/Q11/Q12/Q14 distinct (ea,symbol).
