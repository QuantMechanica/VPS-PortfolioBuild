# APPLY — offline chart-profile cutover, incumbent 11 charts -> D2g6 9 charts

This replaces **RUNBOOK step 5** (start MT5, close six charts, open four, re-load presets, shut
down cleanly). The same end state is produced **offline**, by writing the `.chr` file set directly
while the terminal is **down**, so no GUI interaction and no intermediate hot start are needed.

Everything in this directory was produced read-only from
`profile_backup_pre_D2g6_prestop/`, `sets/`, `collector/`, the repo governor preset and the EA
sources. Nothing here has been copied into the terminal.

- `MANIFEST.json` — per-file sha256, symbol, period, expert path, magic/slot/risk inputs, provenance
- `PARSE_CHECK.json` — `demo_cycle.parse_chart_profile()` output on this directory (6 sleeves,
  risk 1.71875, all six `ex5_sha` equal to PACKAGE.md §3) plus a verifier-equivalent cross-check of
  every preset key against each chart's `<expert>` block

---

## 0. Preconditions (all must already hold)

1. **RUNBOOK steps 1–4 are done**: governor rebound (`governor_rebind_receipt.json`, `applied:true`),
   terminal shut down cleanly with `[Experts] Enabled=0`, authoritative backup taken into
   `profile_backup_pre_D2g6/`, and `demo_install --execute` finished with
   `status: INSTALLED_UNATTACHED_PARKED`.
   The six sleeve `.ex5` files must be in `...\MQL5\Experts\QM_FTMO\` **before** MT5 next starts,
   otherwise the charts reference binaries that are not there and `parse_chart_profile` reports
   `ex5_sha: UNKNOWN`.
2. **No FTMO-path `terminal64.exe` is running.** Select by path, never by name — T_Live and
   T1..T10 must not be touched:

       Get-Process terminal64 -ErrorAction SilentlyContinue | Select-Object Id,Path

   must show no process under `C:\Program Files\FTMO Global Markets MT5 Terminal`.
   **If MT5 is running, stop here** — it rewrites the whole profile on clean shutdown and would
   silently discard everything written below.
3. The authoritative rollback source `profile_backup_pre_D2g6\` exists and holds 12 files.

---

## 1. Apply (terminal DOWN)

    $P = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default'
    $S = 'C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\profile_target_D2g6'

    # 1a. remove the stale charts FIRST - otherwise incumbent chart10.chr/chart11.chr
    #     survive the copy and the profile still carries the retired sleeves.
    Remove-Item -LiteralPath (Join-Path $P 'chart*.chr') -Force

    # 1b. write the target set (9 charts + the regenerated order.wnd)
    Copy-Item -LiteralPath (Join-Path $S 'chart01.chr') -Destination $P -Force
    Copy-Item -LiteralPath (Join-Path $S 'chart02.chr') -Destination $P -Force
    Copy-Item -LiteralPath (Join-Path $S 'chart03.chr') -Destination $P -Force
    Copy-Item -LiteralPath (Join-Path $S 'chart04.chr') -Destination $P -Force
    Copy-Item -LiteralPath (Join-Path $S 'chart05.chr') -Destination $P -Force
    Copy-Item -LiteralPath (Join-Path $S 'chart06.chr') -Destination $P -Force
    Copy-Item -LiteralPath (Join-Path $S 'chart07.chr') -Destination $P -Force
    Copy-Item -LiteralPath (Join-Path $S 'chart08.chr') -Destination $P -Force
    Copy-Item -LiteralPath (Join-Path $S 'chart09.chr') -Destination $P -Force
    Copy-Item -LiteralPath (Join-Path $S 'order.wnd')   -Destination $P -Force

    # MANIFEST.json / PARSE_CHECK.json / APPLY.md stay in the repo - do NOT copy
    # them into the profile directory; the verifier asserts an exact file set.

**Note on `order.wnd`.** Step 1a deliberately deletes only `chart*.chr`, so the live `order.wnd` is
kept; step 1b then overwrites it with a nine-chart version. The incumbent file lists
`chart11.chr … chart01.chr` (reverse order, UTF-16LE + BOM, CRLF); leaving it in place would name two
charts that no longer exist. If you prefer to leave the live `order.wnd` completely untouched, skip
its `Copy-Item` — MT5 rebuilds the window order on the next clean shutdown and the contract verifier
does not read the file's contents, only its presence. Copying it is the tidier option and is what
`MANIFEST.json` hashes.

### 1c. Readback, still with the terminal DOWN

    Get-ChildItem $P -File | Get-FileHash -Algorithm SHA256 | Select-Object Hash,Path

Must be exactly these ten files with these hashes (also in `MANIFEST.json`):

| file | sha256 |
|---|---|
| chart01.chr | `f91a1ed1c2e9e33b99fe1a160381c0e2d935f09c6a883aa636a5fc324c5fdfaf` |
| chart02.chr | `2d88aa6f2e7317717793cc9117e7024394bceec59a9bcd51388e58359a3d624e` |
| chart03.chr | `55235430af9233297d28a1d50f5ebb0925eb757efc56227f973ec50915fa5700` |
| chart04.chr | `c92d5211fbc584a0baaf9b047398b2a78fdee7600b0f6777ce729c17e86fe63d` |
| chart05.chr | `bb122a123c24de8622d1d2f8f668d2ac3fc1a5c20e6a9139cadfa6e8e617181b` |
| chart06.chr | `5a821d2ea24aaffff55c4165d8b1fc253640ff90fe95c5ec49cbd668e11be720` |
| chart07.chr | `fb2d875bcac41a9500ba252d57d3128a95636e6061ff3f0a0487add81bd4be7b` |
| chart08.chr | `b9608670b7163145a13aea228848fb3000a3f7175c86a4344977893433b69279` |
| chart09.chr | `a979e58410f1db7713a2ab7c407cdac7028772c729c2abc321df0ecf6230762b` |
| order.wnd   | `162f6a36bcbc3a85b3500dd44cc31497c25661887d50865ea0ef6ff3fb44f513` |

Then run RUNBOOK **step 6** unchanged (it is already a terminal-down, file-level check):

    python -c "import sys;sys.path.insert(0,'.');from pathlib import Path;from tools.strategy_farm.ftmo import demo_cycle as d;T=Path(r'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850');r=d.parse_chart_profile(T/'MQL5/Profiles/Charts/Default',T/'MQL5/Experts/QM_FTMO');print(len(r));[print(x) for x in r]"

Expect the six rows recorded in `PARSE_CHECK.json` — identical magics, identical `risk_pct`,
identical `ex5_sha`. Only `chart` differs if you deviated from this file set.

Then RUNBOOK **step 7** (re-pin the launcher verifier against this 9-chart layout) and **step 8**.

**Step 5's "AutoTrading was never green" stop condition is satisfied by construction here** — the
terminal is never started during the edit. The first start is step 8, through `FTMO_ON.ps1`, which is
the deliberate AutoTrading-on event.

---

## 2. Rollback (terminal DOWN)

Authoritative source is the step-3 backup — the one MT5 itself wrote on clean shutdown — **not**
`profile_backup_pre_D2g6_prestop/` (that was taken while the terminal was running and is a reference
snapshot only, per RUNBOOK step 1).

    $P = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default'
    $B = 'C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\profile_backup_pre_D2g6'

    # AutoTrading off and terminal cleanly down first (RUNBOOK step 3).
    Remove-Item -LiteralPath (Join-Path $P 'chart*.chr') -Force
    Copy-Item -LiteralPath (Join-Path $B '*') -Destination $P -Force
    Get-ChildItem $P -File | Get-FileHash -Algorithm SHA256 | Select-Object Hash,Path
    # -> 12 files, 11 .chr hashes == CHART_PLAN.md section 1

Then the remaining CHART_PLAN §3 rollback items, unchanged: restore
`QM5_10706_tv-mon-ls.ex5` from `Experts\QM_FTMO\_pre_FTMO_DEMO_BOOK_V3_D2G6_20260918\` and the
collector preset from the same backup dir; revert the governor rebind
(`git checkout` the two `QM5_13206_…` presets + `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json`);
revert the verifier re-pin and the `EXPECTED_MAGICS` change; start via `FTMO_ON.ps1`.

If `profile_backup_pre_D2g6\` was never taken, the degraded fallback is
`profile_backup_pre_D2g6_prestop\` (same 12 filenames, hashes per CHART_PLAN §1); its charts are the
same charts, only the geometry/objects are a few minutes older.

---

## 3. Target layout and where each file came from

| target | role | symbol | TF (`period_type`/`period_size`) | expert `path` | slot | magic | RISK_PERCENT | source |
|---|---|---|---|---|---|---|---|---|
| chart01.chr | governor | EURUSD | M1 (`0`/`1`) | `Experts\QM_FTMO\QM5_13206_ftmo-account-governor.ex5` | — | — | — | backup chart01, five rebound inputs replaced |
| chart02.chr | sleeve 10706 | GBPUSD | H1 (`1`/`1`) | `…\QM5_10706_tv-mon-ls.ex5` | 1 | 107060001 | 0.3125 | backup chart02, **byte-identical** |
| chart03.chr | sleeve 11422 | USDCAD | D1 (`1`/`24`) | `…\QM5_11422_williams-18ma-outside-bar-entry-d1.ex5` | 4 | 114220004 | 0.3125 | backup chart04, **byte-identical**, renumbered |
| chart04.chr | sleeve 13213 | USDJPY | H1 (`1`/`1`) | `…\QM5_13213_balke-gmt3-range-breakout.ex5` | 0 | 132130000 | **0.15625** | NEW, template backup chart02 (nearest H1) |
| chart05.chr | sleeve 10700 | XAUUSD | H1 (`1`/`1`) | `…\QM5_10700_tv-liq-break.ex5` | 3 | 107000003 | 0.3125 | NEW, template backup chart02 (nearest H1) |
| chart06.chr | sleeve 10403 | XAUUSD | D1 (`1`/`24`) | `…\QM5_10403_et-turtle20x.ex5` | 2 | 104030002 | 0.3125 | NEW, template backup chart08 (nearest D1 metal) |
| chart07.chr | sleeve 41219 | XAUUSD | D1 (`1`/`24`) | `…\QM5_41219_cum-rsi2-commodity-requal8.ex5` | 0 | 412190000 | 0.3125 | NEW, template backup chart09 (nearest D1 metal) |
| chart08.chr | collector | EURUSD | M1 (`0`/`1`) | `…\QM_FTMO_TrialTelemetry.ex5` | — | — | — | backup chart10, `InpOutputDir`/`InpTrialId` rebound |
| chart09.chr | blank | EURUSD | D1 (`1`/`24`) | *(no expert block)* | — | — | — | backup chart11, **byte-identical** |

Numbering follows CHART_PLAN §2's own order — governor, the two staying sleeves in their existing
relative order (2b), the four additions in §2c order, collector, blank — which is also the order MT5
itself produces when survivors keep their relative window order and new charts are appended.

The six incumbent charts that leave (11421 EURUSD D1, 11910 NZDUSD D1, 13054 USOIL.cash D1,
20048 USOIL.cash D1, 1537 XAGUSD D1, 21505 XAGUSD D1) are **removed as files**, i.e. CHART_PLAN §2a's
preferred "close the chart" outcome, not the `expertmode=0` variant it explicitly forbids.

---

## 4. Assumptions — every one of them, stated

**A1 — a partial `<inputs>` list is equivalent to "Load preset".** The `<inputs>` block of each new
chart carries every key of the derived preset verbatim, plus the framework inputs the preset omits
(`qm_rng_seed`, `qm_news_min_impact`, `qm_news_mode_legacy`, `qm_stress_reject_probability`,
`qm_chartui_*`, `InpQMSimCommissionPerLot`, `opt_pp_*`) at their compiled defaults, rendered exactly
as the incumbent charts render them. Inputs MT5 does not find in the block fall back to the EA's
compiled default — the same semantics as loading a `.set` in the properties dialog, which also only
overrides the keys it lists. **`RISK_FIXED` is the one that matters**: its compiled default is
`1000.0`, so it is written explicitly as `0` on every sleeve chart (all six verified in
`PARSE_CHECK.json`).

**A2 — `qm_filter_*` are not EA inputs.** The 10706 and 10403 presets carry a `qm_filter_*` block,
but no incumbent chart contains those keys and the launcher verifier explicitly skips them. They are
therefore **not** written into the new charts. If a future build of those EAs does declare them, the
chart would silently use their defaults, and the verifier would not catch it — the preset is then the
only record.

**A3 — `Optimization Pattern Profile` / `opt_pp_*` exist only in binaries built on/after
2026-08-26** (framework commit `b0bdc4d72f`). `chart05` (10700, `.ex5` 2026-09-03) and `chart07`
(41219, 2026-09-01) carry the group; `chart04` (13213, 2026-08-25) and `chart06` (10403, 2026-08-21)
do not. This mirrors the observed split between incumbent chart04 (11422, `.ex5` 2026-08-03 — no
group) and incumbent chart02/chart08/chart09 (10706/1537/21505, later builds — group present).
Getting this wrong is harmless in both directions — MT5 ignores unknown
keys, and the omitted defaults are `0` = inert — but it is what MT5 itself would write.

**A4 — `qm_risk_cap_pct` is declared only by QM5_10700** (its `.mq5` line 49, default `1.0`), so it
appears on `chart05` only, at `1.0`. `1.0 %` is far above the sleeve's `0.3125 %`, so it never binds.

**A5 — chart ids are invented and only have to be unique.** `chart04..chart07` use
`43391000000001..43391000000004`, above every id in the incumbent profile
(max observed `43390345893350`). MT5 treats the id as an opaque handle; it does not encode symbol,
time or order. If MT5 ever rejected them it would drop the chart, which step 6's sleeve count would
catch immediately.

**A6 — window geometry, colours and indicators are cosmetic and MT5 tolerates whatever is there.**
The new charts inherit their template's full header (scale, colours, `windows_total=1`) and get a
minimal `<window>` tail: `objects=0` plus the mandatory `name=Main` indicator block. No trade-marker
`<object>` entries are carried over — those belong to the retired sleeves' closed positions and MT5
redraws its own. Tiles were assigned non-overlapping (`chart04` 430/88, `chart05` 430/176,
`chart06` 430/264, `chart07` 860/0); nothing reads them.

**A7 — `digits` and `description` are per-symbol facts I could NOT determine**, because the FTMO
terminal directory is out of scope for this task and its `symbols.sel` / symbol database was not
read. `USDJPY` is written as `digits=3`, `XAUUSD` as `digits=2`, descriptions as
`US Dollar vs Japanese Yen` / `Gold vs US Dollar`. **MT5 overwrites both from the broker's own symbol
record when the chart opens**, and neither field is read by `parse_chart_profile` or by the contract
verifier. If FTMO's `XAUUSD` is in fact 3-digit, nothing breaks; the value is corrected on the first
clean shutdown. Flagged so nobody later mistakes these for verified venue facts.

**A8 — `scale_fixed_min` / `scale_fixed_max` are zeroed on the new charts.** `scale_fix=0` on every
one of them, so the fixed-scale bounds are unused; carrying a GBPUSD or XAGUSD price range onto a
USDJPY/XAUUSD chart would have been actively misleading.

**A9 — the governor and collector charts are edited in place, not rebuilt.** `chart01` differs from
incumbent `chart01` in exactly five lines (`governed_symbols_csv`, `challenge_id`,
`challenge_start_utc`, `allowed_magics_csv`, `governed_ea_ids_csv`), taken from the **rebound**
`QM5_13206_…_demo_active.set` at HEAD (post-`governor_rebind --apply`, receipt sha
`f1b277a6…`). `signed_policy_id`, `expected_account_login`, `expected_account_server`,
`governor_dry_run=false` and `challenge_state_bootstrap=false` are untouched, as CHART_PLAN §2d
requires. `chart08` differs from incumbent `chart10` in exactly two lines (`InpOutputDir`,
`InpTrialId`), taken from `collector/QM_FTMO_TrialTelemetry_1514536732.set` (`9de24d3d…`).

**A10 — `order.wnd` grammar is inferred from the one sample**: chart file names, one per CRLF line,
in reverse numeric order, UTF-16LE with BOM, no trailing blank line. The regenerated file is
`chart09.chr … chart01.chr`. Nothing in the repo parses it; see the note under §1.

**A11 — this replaces the GUI, it does not replace the clean shutdown that follows.** RUNBOOK step 5
item 8 ("shut down cleanly so the profile is written") is moot here — the profile is already on disk.
But the *next* clean shutdown after step 8 will rewrite all nine files with MT5's own geometry,
`digits`, `description` and object lists. **The hashes in §1c are therefore valid only between the
copy and the first shutdown** — re-pin the verifier (step 7) from the file set as it stands at step 6,
and expect the hashes, not the pinned fields, to move afterwards. That is exactly the situation the
incumbent pin was in, and it is why the verifier pins field values plus preset/binary shas rather
than `.chr` hashes.

**A12 — nothing here touches AutoTrading, T_Live, the factory, MT5 processes, the farm SQLite or
git.** The only write target is this directory.
