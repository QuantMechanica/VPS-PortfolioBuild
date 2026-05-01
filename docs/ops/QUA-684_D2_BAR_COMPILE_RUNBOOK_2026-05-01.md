# QUA-684 D2 — Bar Compilation Runbook (2026-05-01)

**Author:** Board Advisor at OWNER explicit directive.
**Audit:** `QUA-684_D2_BAR_COMPILATION_AUDIT_2026-05-01.md`.
**Tooling (USE THIS ONE):** `D:\QM\mt5\T1\MQL5\Scripts\Compile_Custom_Bars_QM_v2.mq5`.

> **v1 → v2 update (2026-05-01 13:50Z):** v1 used `CopyRates` to "trigger" lazy bar synthesis. **It does NOT work.** Confirmed empirically on T1: `CopyRates` only reads pre-existing `.hcc` files; it never builds bars from ticks. v1 logged 22 of 23 symbols as `rates=0` despite 200M–600M ticks loaded per symbol. The only "OK" (JPN225) was just reading its existing 2026 stub. v2 replaces the approach: aggregate ticks → M1 OHLC → `CustomRatesUpdate` (the same API the original `Import_DWX_From_Bin.mq5` used). Month-by-month chunks keep memory bounded.

## What this fixes

Restores the M1 bar history (`.hcc` compiled files) for 33 of 36 imported `.DWX` custom symbols whose ticks were imported but bars were never compiled. Required before any P2/P3/P5/P6/P7/P8 baseline can run on multi-symbol cohorts. See the audit doc for full root cause.

## Why it cannot be fully programmatic

The MT5 Python API (`copy_rates_*`) does NOT trigger MT5's lazy bar synthesis from ticks. Verified 2026-05-01 13:30Z on `USDCAD.DWX` — three different copy_rates patterns all returned 0 with `Terminal: Invalid params`, no `.hcc` files materialized. Bar compilation must run **inside** MT5 (via MQL5 script or chart open). The Python or shell wrappers can't drive it.

## Steps (T1 first, then propagation)

### 1. Compile MQL5 script

In MetaEditor on T1 (or via command line):

```
"D:\QM\mt5\T1\metaeditor64.exe" /portable /compile:"MQL5\Scripts\Compile_Custom_Bars_QM.mq5"
```

Verify `D:\QM\mt5\T1\MQL5\Scripts\Compile_Custom_Bars_QM.ex5` exists.

### 2. Run script in T1

In T1 MetaTrader 5:

1. Open any chart (any symbol — script doesn't trade).
2. From Navigator → expand **Scripts**.
3. Drag **`Compile_Custom_Bars_QM_v2`** onto the chart. (NOT v1 — v1 is broken.)
4. Defaults are fine: `YearFrom = 2017`, `YearTo = 2024`, `MinBarsToSkip = 50000`, `DryRun = false`.
5. Click OK.

The script iterates 35 missing-history symbols. Per symbol → per year → per month: `CopyTicksRange` → aggregate ticks to M1 OHLC → `CustomRatesUpdate`. Symbols that already have ≥ 50K bars are skipped (e.g. EURUSD/WS30/XTIUSD).

**Expected runtime: ~70–150 minutes total.** Long but bounded memory per chunk (~3M ticks → 50K bars per month).

Output:
- Experts tab: `[OK] USDCAD.DWX wrote=N bars Bars()=M in Ts`.
- Log: `D:\QM\mt5\T1\MQL5\Files\compile_custom_bars_v2_<TIMESTAMP>.log`.

Run with `DryRun=true` first if you want to confirm the symbol list / years before any disk write.

### 3. Verify on T1

```
cd D:\QM\mt5\T1\dwx_import
python verify_import.py    # or per existing CLI, see verify_import.py --help
```

Acceptance: every `.DWX` row shows `verdict=OK` (head, tail, mid, bars, spec all present). No `bars_one_shot=0` or `FAIL_tail_bars` left.

Disk-side spot check (any of the 33 previously-broken symbols):

```bash
ls -la D:/QM/mt5/T1/bases/Custom/history/USDCAD.DWX/
# Expect 9-10 .hcc files (2017.hcc through 2026.hcc) totaling ~150-200 MB
```

If any symbol still fails, re-run the script with that symbol only (edit `Symbols` input) and check Experts tab for the FAIL reason.

### 4. Propagate T1 → T2..T5

Per CLAUDE.md "Copy validated factory state from T1 to T2-T5":

```powershell
foreach ($T in @('T2','T3','T4','T5')) {
    robocopy "D:\QM\mt5\T1\bases\Custom\history" "D:\QM\mt5\$T\bases\Custom\history" /E /MT:8 /R:1 /W:1
}
```

Each terminal should be **closed** during the copy (T6 is unaffected — out of factory scope).

### 5. Re-attempt Phase 3 baseline (after CEO unblocks QUA-662)

With bars compiled and `framework/registry/tester_defaults.json` loaded, the QM5_1003 P2 baseline cohort should now produce real trades on all 36 symbols with `trade_count >= 1` (DL-054 Gate 4). Quality-Tech reviews under the five-gate criteria.

## What the script does NOT do

- **Does NOT** modify tick data — `.tkc` files are read-only.
- **Does NOT** trade. No `OrderSend`. The script is read/synthesize only.
- **Does NOT** touch T6_Live. Per CLAUDE.md hard rule.
- **Does NOT** modify EAs or framework code.
- **Does NOT** resolve the `EA_MAGIC_NOT_REGISTERED` issue Pipeline-Op partially fixed earlier — that's a separate concern (resolved in Pipeline-Op's `QM_MagicResolver.mqh` patch).

## Cross-references

- Root cause: `QUA-684_D2_BAR_COMPILATION_AUDIT_2026-05-01.md`
- Anti-theater pass criteria: `decisions/DL-054_anti_theater_pass_criteria.md`
- Tester defaults: `framework/registry/tester_defaults.json`
- DL-038: Seven Binding Backtest Rules (36-symbol matrix)
- QUA-684: CEO directive (D2 = this work)
- QUA-662: phantom-PASS matrix to invalidate

— Board Advisor 2026-05-01 13:40 UTC.
