# Deterministic cross-symbol/session scanner

Task: `35bbe0bc-45ff-448d-a346-c5cee6974397`

Authority: `OWNER-DEC-FTMO-FULL-THROTTLE-20260921`

## Verdict

The scanner is implemented and the complete declared family ran in 251.18 seconds on four workers, below the two-hour target. It evaluated 75,660 pre-declared cells: 71,136 cross-symbol cells and 4,524 single-symbol controls.

No selection cell survived Benjamini-Hochberg FDR at 10%, so there are **0 `WORTH_MT5_TEST` survivors** and 0 holdout-confirmed hypotheses. The state distribution is:

- `CLEAR_REJECT`: 65,230
- `UNKNOWN`: 10,430
- `WORTH_MT5_TEST`: 0

This is a research-prescreen result only. It creates no EA, Strategy Card, registry row, factory row, roster change, pipeline verdict, or economic-validation claim.

## Artifacts

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `tools/strategy_farm/research/cross_symbol_scanner.py` | 41,471 | `75253bb56916691eb8fea51b3c51c3a58a9982c2e0bb59513f692ac39ad40027` |
| `tools/strategy_farm/tests/test_cross_symbol_scanner.py` | 4,583 | `2e16af551f3272bbe93ffc3184c4d6cfd9eb6a8fd71c662cbbafbbe465a94c90` |
| `docs/research/ftmo_shadow/cross_symbol_scan_2026-09-22.json` | 78,361,246 | `2629b573dcceb3b6390c80dcbe49431542cd4334ff6a70c69f90619e78f35f63` |
| `docs/research/ftmo_shadow/cross_symbol_scan_2026-09-22.md` | 1,835 | `2c91e1ab8105dfa209790288e838a9112906cd7b13a2db30680ccb10510dafd1` |

Implementation/results commit: `d9ec345297` (`agents/board-advisor`).

The JSON contains every cell, not only the best cells. It is compact canonical JSON to keep the complete family below common repository blob limits; keys and cell order are deterministic.

## Frozen family and execution discipline

Declared universe: 28 FX pairs; GDAXI, JPN225, NDX, SP500, UK100, WS30; XAUUSD/XAGUSD; XTIUSD/XBRUSD/XNGUSD (39 symbols, 1,482 ordered non-self pairs).

Declared windows:

1. Asia 00:00-07:00 Europe/London
2. London 08:00-12:00 Europe/London
3. NY pre-open 08:00-09:30 America/New_York
4. cash-open 09:30-10:30 America/New_York
5. NY cash 10:30-16:00 America/New_York
6. London/NY overlap 13:00-16:00 Europe/London

For each ordered pair/window the scanner evaluates two fixed lead-size thresholds (0.5 and 1.0 prior-14 same-window ATR), continuation and reversal as separate tests, and two timing modes:

- `LEAD_ONLY`: the reference predecessor window is complete before entry.
- `PEER_CONFIRMED_15M`: the reference's first 15-minute bar in the execution window must confirm; entry is the next bar open.

This gives exactly `39 * 38 * 6 * 2 * 2 * 2 = 71,136` cross-symbol cells. The 4,524 single-symbol cells cover day-of-week x session, prior-only volatility state x session, overnight gap x US cash session, and prior-day range-extreme x session.

The market-return convention is shared with the conservative F2 engine: completed bars only, entry/exit at window boundaries, and `spread_rt + slip_rt` charged once as a round trip. Risk is the prior 14 same-window ATR. Exact F2 priors are reused where registered; the broader universe uses explicitly labelled conservative class priors. Double-cost means are emitted per cell. No ML is used.

Time boundaries use the F1 `server_from_local` / `utc_from_server` helpers with IANA `Europe/London` and `America/New_York`, including US/EU DST divergence weeks. ATR and volatility state exclude the current window. Validation is never read to select a threshold, relation, session, direction, or confirmation mode.

## Multiple testing and holdout

- Selection: 2018-07-02 through 2022-12-31.
- Validation: 2023-01-01 through 2025-12-31.
- 67,220 cells have at least 30 selection observations.
- One-sided p-values come from each cell's net-R t-stat. Negative or zero selection effects are assigned p=1 for the positive-edge test.
- All 75,660 declared cells remain in one BH family at `q=0.10`.
- A survivor must be FDR-rejected, have at least 30 validation observations, remain positive net of cost, and retain at least half the selection mean effect.

The smallest unadjusted p-value is `2.358183e-06`, for `SINGLE|X=XNGUSD.DWX|TYPE=DOW|W=CASH_OPEN|D=3|DIR=SHORT` (SEL mean `+0.16324851 R`, VAL mean `+0.16958580 R`). It does not clear the first family-wide BH boundary, `0.10 / 75,660 = 1.3217e-06`. The best cross-symbol cell has p `0.000250803696` and reverses sign in validation. Thus the zero-survivor result is driven by the declared family correction, not by an empty scan.

Every cross cell records adjacent-threshold/adjacent-window same-sign robustness counts. A full neighbor ID trace is reserved for decision-relevant survivors; there are none in this run.

## Archive availability finding

The task context described 2018-2025 M1 history for all 39 symbols. The filesystem audit found:

- 37 symbols have all eight annual HCC files for 2018-2025.
- `JPN225.DWX` and `XBRUSD.DWX` have only `2026.hcc` and no 2018-2025 HCC file in T2-T10.

The scanner does not silently drop those symbols: their declared pair and single-symbol cells remain in the 75,660-test BH family and fail closed as `UNKNOWN`. All 37 available histories report zero OHLC structural violations and zero duplicate timestamps after decoding.

`XBRUSD` also retains an explicitly labelled unresolved venue-parity cost prior. No result involving absent history can survive.

## Verification

Focused tests:

```text
python -m pytest -q tools/strategy_farm/tests/test_cross_symbol_scanner.py
....                                                                     [100%]
4 passed
```

The tests prove:

- a planted two-symbol lead/lag effect survives FDR and the locked holdout;
- a deterministic null fixture produces no survivor;
- complete cell generation and compact JSON are byte-deterministic;
- London/New York session boundaries round-trip through stable and US/EU DST-divergence dates.

Additional checks passed:

- `py_compile` for scanner and tests;
- JSON parse and schema check;
- cell-count algebra and exact 75,660-row count;
- 39-symbol inventory and explicit 37/2 availability split;
- all available symbols have eight source years and zero OHLC violations;
- no survivors when the JSON claims zero;
- `git diff --check` on all scoped files.

Reproduction:

```powershell
python tools/strategy_farm/research/cross_symbol_scanner.py --workers 4
```

The reusable feature cache is under `D:/QM/reports/research/cross_symbol_scanner/features_v1/`; it is derived read-only from the HCC archive and contains no terminal or farm-database mutation.

## Safety / disposition

The run was read-only toward `D:/QM/mt5/T2..T10/Bases/Custom/history`, terminals, T_Live, AutoTrading, and the farm database. It created no factory rows and made no roster or gate-criteria change. With 0 survivors, Fable has nothing from this scan to pre-register for an F2 prescreen; the result remains a durable negative discovery artifact.
