# QUA-684 D2 — Tester Read-Access Root-Cause Audit (2026-05-01)

**Author:** Board Advisor at OWNER explicit directive.
**Subject:** Why `bars_one_shot=0 / Terminal: Invalid params` on 21 (actually 33) imported `.DWX` symbols.

## TL;DR

The DWX import landed **ticks** (`.tkc` files) for all 36 symbols, but **compiled M1 bar history** (`.hcc` files) for only 3. MT5's strategy tester needs `.hcc` files to feed M1 bars to an EA. Without `.hcc` for the test window, `mt5.copy_rates_range()` returns 0 with error `(-2, 'Terminal: Invalid params')`. This is a setup failure, not a strategy / EA / framework bug.

## Evidence

T1 disk inventory of `D:\QM\mt5\T1\bases\Custom\history\<SYM>.DWX\*.hcc` (compiled M1 bar files) for all 36 imported `.DWX` symbols, 2026-05-01 ~13:00 UTC:

| Symbol | hcc files | size | years available |
|---|---:|---:|---|
| **EURUSD.DWX** | 10 | 183 MB | 2017–2026 ✅ |
| **WS30.DWX** | 9 | 199 MB | 2018–2026 ✅ |
| **XTIUSD.DWX** | 10 | 177 MB | 2017–2026 ✅ |
| GDAXI.DWX | 1 | 5 MB | 2026 only |
| JPN225.DWX | 1 | 7 MB | 2026 only |
| NDX.DWX | 1 | 8 MB | 2026 only |
| XBRUSD.DWX | 1 | 5.9 MB | 2026 only |
| All other 29 .DWX symbols | 1 | ~20 KB | 2026 stub only |

The 3 fully-compiled symbols (EURUSD / WS30 / XTIUSD) have `.hcc` files dated 2026-04-28 19:23 (or near). The other 33 have `.hcc` files dated 2026-05-01 13:21 — created today during Pipeline-Op's broken loop (each test launch creates a tiny stub for the current year as MT5 attempts to start, then exits with "Invalid params" because there's no history for the requested past window).

`.tkc` (tick) files are fully present for all 36 symbols — covering 2017+ where applicable — and are NOT the problem.

## Why this looked like "Tester: Invalid params"

`verify_import.py` calls `mt5.copy_rates_range(symbol, M1, b_first, b_last)`. MT5 evaluates the request:

1. Does the symbol exist? Yes (custom symbol registered).
2. Does the symbol have `.hcc` compiled bars covering the requested range?
   - For EURUSD / WS30 / XTIUSD: yes → returns bars.
   - For 33 others: no → returns 0 + sets `last_error = (-2, 'Invalid params')`.

`bars_drift = -100,000` because `expected_accessible = min(b_count, maxbars) = 100,000` and got 0.

For the same reason the live tester journal shows:

```
QM5_1003_davey_baseline_3bar.ex5 X64
custom group settings applied
EURCAD.DWX: no history data from 2024.01.01 00:00 to 2024.12.31 00:00
no history data, stop testing
```

— "no history data" means **no compiled bar history**, regardless of whether ticks exist.

## Why EURUSD / WS30 / XTIUSD got compiled

These three symbols were **touched** by either chart-open or strategy-tester at some point on or before 2026-04-28 19:23. MT5 lazy-compiles `.hcc` from `.tkc` when:

- A chart is opened on the symbol and history is scrolled
- Strategy Tester runs against the symbol (and the symbol has tick data)
- (Possibly) a custom MQL5 script forces bar synthesis via `iBars()` or `CopyRates()`

The other 33 symbols were imported as ticks but never touched, so MT5 never built `.hcc`.

## Why this is now THE blocker for Phase 3

Pipeline-Op's QM5_1003 P2 baseline cohort ran across 36 symbols on the 2024 window. Only EURUSD.DWX has 2024 in `.hcc` form — that's the only run that produced real trades (per `P2_postfix2` evidence from Pipeline-Op's 10:36Z recovery doc). All 35 other rows had no bars to test against; they exited in 100ms with the matrix being filled by the parser misreading `automatical testing finished` as PASS (DL-054 Gate 4 violation).

**Until `.hcc` history is compiled for the 33 missing symbols, no real Phase 3 multi-symbol baseline is possible.**

## Fix path

The fix is per-symbol bar compilation from existing tick data. Three known mechanisms, in order of automation:

### A. MQL5 `iBars` script (programmatic, batch)

Author a small `Compile_Custom_Bars.mq5` script in `D:\QM\mt5\T1\MQL5\Scripts\` that:

```
for each .DWX symbol in Custom\:
    SymbolSelect(sym, true)
    iBars(sym, PERIOD_M1)            // forces presence
    CopyRates(sym, PERIOD_M1, 2017.01.01, 2026.05.01, rates_array)
```

Run once per terminal (T1..T5). Watch for `.hcc` year files appearing.

### B. MT5 Python API (programmatic, external)

```python
mt5.initialize(path=r"D:\QM\mt5\T1\terminal64.exe")
for sym in fail_symbols:
    mt5.symbol_select(sym, True)
    mt5.copy_rates_range(sym, mt5.TIMEFRAME_M1,
                         dt(2017,1,1), dt(2026,5,1))
```

This is what `verify_import.py` already does — but it FAILS on the symbols without `.hcc`. So this approach may not lazy-compile; it may require the symbol to already have history. Needs testing.

### C. MT5 UI manual walkthrough (last resort, slow)

Open MT5 T1 → for each FAIL symbol → open chart → set period M1 → scroll back ~9 years → MT5 generates bars from ticks lazily. Slow + manual.

Once T1 has all 36 symbols compiled, copy `D:\QM\mt5\T1\bases\Custom\history\` to T2..T5 (per CLAUDE.md factory propagation rule).

## Companion finding — XBRUSD.DWX is real

I previously stated XBRUSD.DWX was hallucinated by Pipeline-Op. **Correction:** XBRUSD.DWX exists in `D:\QM\mt5\T1\bases\Custom\history\XBRUSD.DWX\` with a 5.9 MB `2026.hcc` and proper tick files. It IS a legitimate Darwinex custom symbol. What was wrong was **testing it on a 2024 window when its history starts 2026-02-02** — same root cause as the 33 others (no historical `.hcc`), just with a different visible failure mode (`history data begins from 2026.02.02`).

The `.scratch/qua662_done_symbols.txt` sanitization (in this commit's QUA-662 comment + earlier external rewrite) leaves XBRUSD in the canonical 36 — correct.

## Validation plan once fix lands

1. Re-run `verify_import.py` (currently at `D:\QM\mt5\T1\dwx_import\verify_import.py`) on all 36 symbols.
2. Acceptance: `bars_one_shot > 0` and `bars_drift` within tolerance for every symbol.
3. Re-run a 1-symbol test on, say, `USDCAD.DWX` for 2024 window; tester journal must show `history data begins from 2017-XX-XX` (not 2026-02-02) and trades fire.
4. Then re-attempt the 36-symbol baseline with DL-054 gate enforcement.
5. Propagate `bases/Custom/history/` from T1 to T2..T5.

## Cross-references

- `decisions/DL-054_anti_theater_pass_criteria.md` — Gates 1, 4 specifically address this class of failure.
- `framework/registry/tester_defaults.json` — independent tester-side fix (deposit + risk).
- `D:\QM\mt5\T1\dwx_import\verify_import.py` — the verifier whose FAIL output exposed this.
- `D:\QM\mt5\T1\dwx_import\logs\hourly_2026-04-27.log` 09:48Z — where 21 of 36 FAILs are recorded; the readiness verdict was prematurely stamped READY despite these.
- `D:\QM\reports\pipeline\QM5_1003\P2\zero_trade_audit_20260501.json` — Pipeline-Op's 36/36 zero-trade audit; this audit explains WHY.

— Board Advisor 2026-05-01 13:00 UTC, at OWNER explicit directive.
