# Dukascopy P3 follow-up: DWX coverage and contract-basis diagnosis

Date: 2026-09-12

Router task: `f12fbdb3-ce5c-456d-9fc4-046460dbf141`

Parent task: `b5f660f9-2fbc-4072-89fa-2fa52b546752`

Prior governed work item: `156ed639-3557-4c8e-bc14-b8ff69637bc5`

## Result

The follow-up remains fail-closed. All 37 symbols have a per-symbol disposition, but the fresh P3 run can consume only 25 incomplete bar exports. It returns 25/25 `FAIL`, the 12 header-only exports are `NOT_RUN`, and `production_splice_authorized=false`. The proposal remains blocked until a fresh fixed-window export and P3 run both cover 37/37 symbols.

No archive was written, no terminal was started, and neither `T_Live` nor AutoTrading was touched. The T1 observations below are from the already governed read-only export/probe receipts.

## Source receipts

- T1 M1 export root: `D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1/20260912_125000/dwx_m1/`
- T1 journal: `D:/QM/mt5/T1/MQL5/Logs/20260912.log` (53,330 bytes; SHA-256 `cc50b9de4ca852f5c768c9ddcaaee7ed11035165f073ff3ee849fdb9524f445a`)
- Governed tick-tail receipt: `D:/QM/reports/dukascopy/splice/20260909_185632/tick_tail.csv` (5,781 bytes; SHA-256 `8322db7a4536f25650b2bfff9e87f19b2e667324c9575448b574ca9e66a766c9`)
- Prior P3 evidence: `C:/QM/repo/docs/ops/evidence/2026-09-12_dukascopy_p3_redo/README.md`
- Full per-symbol diagnosis and action: `per_symbol_coverage_plan.csv`
- UK100/XTI proof table: `basis_proof.csv`

## Why 12 exports are empty and 25 stop in December 2025

The journal records two governed attempts with the same deterministic split. The first is at lines 80-129; the quiet-window retry is at lines 180-229. On both attempts the same 12 symbols fail the first requested weekly chunk (`2025-10-01` through `2025-10-07`) after the exporter retry budget, with MT5 error 4401 (`ERR_HISTORY_NOT_FOUND`) and zero rows: AUDCHF, EURJPY, EURUSD, GBPCAD, GBPNZD, GBPUSD, GDAXI, NDX, SP500, USDJPY, WS30, and XNGUSD. Each resulting CSV is 34 bytes: header only. Journal line 229 records `successes=25 failures=12 total_rows=1735391`.

The other 25 `CopyRates` calls succeed, but the last returned M1 bar is on 2025-12-31 (UK100 at 12:49Z; all others at 21:58Z or 21:59Z). Those are partial outputs, not completed overlap exports.

The active HCC inventory supplies the discriminant. Every symbol has a signed 2025 HCC of roughly 17-26 MB. The 25 partial-success symbols have only 28-37 KB 2026 HCC placeholders, while the 12 error-4401 symbols have 5.5-10.8 MB 2026 HCC files. The association exactly matches the two CopyRates outcomes and is reproduced by the quiet retry. This establishes an MT5 materialized-bar/HCC-state split; it does not establish missing source ticks.

The independent tick-tail receipt resolves the source question: all 37 T1 custom symbols have archived ticks past `2026-04-01` (at least 2026-04-05; most through 2026-04-24, NDX through 2026-07-12), and the corresponding tick trees contain monthly `202601.tkc` through `202604.tkc`. Therefore an external provider is not needed for the required overlap coverage.

## Required coverage source and DST proof

The next governed read-only source must be T1 `CopyTicksRange`, deterministically aggregated into M1 bars over the fixed half-open UTC interval `[2025-10-01T00:00:00Z, 2026-04-01T00:00:00Z)`. That interval is mandatory: it covers both fall-2025 and spring-2026 clock changes (EU end 2025-10-26, US end 2025-11-02, US start 2026-03-08, EU start 2026-03-29). The current December endpoint can exercise only the fall side.

A quiet window is prudent for a future governed T1 read, but it is not the remedy: the quiet retry already reproduced all 12 failures and cannot create the missing January-March M1 bars for the other 25. Rebuilding HCC from the existing ticks would require separate archive-write authority and is not required for reconciliation. Read-only tick aggregation avoids that mutation.

## UK100 and XTI from first principles

The decoder scale is correct. The raw scale receipt gives representative transformations `9374886 / 1000 = 9374.886` for UK100 against DWX near `9384.5`, and `62475 / 1000 = 62.475` for XTI against DWX near `62.28`. Contract size/multiplier changes P&L, not the quoted index level or dollars-per-barrel price, so it cannot repair a price-series delta.

On exact matched M1 timestamps, UK100 has 79,153 observations. Signed `Dukascopy - DWX` close difference has median `-13.799` index points, q05/q95 `-22.323/-9.196`, and daily medians from `-26.017` to `-6.908`. Monthly medians drift from `-11.108` in October to `-17.999` in December. OLS is `Dukascopy = 0.9821500 * DWX + 157.9451`. P3 reports an absolute p95 of 223.23 DWX points; at point size 0.1 that is 22.323 index points versus a 3.2955 limit.

XTI has 82,357 exact matches. Signed `Dukascopy - DWX` close difference has median `+0.125` USD/barrel, q05/q95 `+0.002/+0.385`, and daily medians from `-0.005` to `+0.465`. Monthly medians are `+0.182`, `+0.072`, and `+0.125`. OLS is `Dukascopy = 1.0262576 * DWX - 1.41245`. P3 reports absolute p95 38.5 points; at point size 0.01 that is 0.385 USD/barrel versus a 0.075 limit.

The changing sign/magnitude across days and months disproves a scale error and rules out a defensible static offset. The evidence is consistent with different provider/broker cash-CFD financing/dividend conventions for UK100 and different continuous-contract roll/financing conventions for XTI. These mappings must be rejected for splice use unless an independently documented, time-varying contract transformation is approved. The safer route is a source whose UK100 and XTI contract construction matches DarwinexZero; until then both remain blocked.

## Fresh P3 rerun

Command (from `C:/QM/repo`):

```text
python tools/dukascopy/reconcile_overlap.py --jobs docs/ops/evidence/2026-09-12_dukascopy_p3_redo/p3_jobs.json --instrument-metadata docs/ops/evidence/2026-09-12_dukascopy_p3_redo/dukascopy_price_scale.csv --out D:/QM/reports/dukascopy/reconciliation/20260912_f12fbdb3/p3_reconciliation_summary.json
```

Exit code: `1` (expected fail-closed result).

The tool treats `--out` as a directory; the fresh receipts are therefore under `D:/QM/reports/dukascopy/reconciliation/20260912_f12fbdb3/p3_reconciliation_summary.json/`:

- `reconciliation_summary.json`: 61,201 bytes; SHA-256 `c0fd5ee19748b5e6eba8bdb032aa8d51a825aaa01f9b65316fb4d9f16b72077a`
- `reconciliation_summary.csv`: 7,322 bytes; SHA-256 `8c325c7fe87cb3cecff07d0cb270b7a60a68cc58ea6cedfa42bb1833a8c13bb8`
- `README.md`: 1,826 bytes; SHA-256 `716f94cfb94e331a15114e82acd58070ea21c80ed34fca8f938ede62657a254d`

All 25 supplied jobs fail required overlap end and session coverage; their input bars stop in December 2025. UK100 and XTI additionally fail price tolerance. The 12 header-only symbols have no P3 jobs and are explicitly `NOT_RUN`. This is pipeline evidence only for this P3 rerun; it does not authorize production or any later Q phase.

## Close condition

1. Claim a normal governed T1 read-only window.
2. Export all 37 symbols from archived ticks by `CopyTicksRange` and deterministic UTC-minute aggregation for the exact fixed interval.
3. Prove 37/37 non-empty files, endpoints through 2026-04-01, and both fall/spring DST windows.
4. Replace or formally transform UK100/XTI only with separately approved contract-basis evidence.
5. Run P3 in another fresh scratch directory; keep the proposal blocked unless all 37 pass the governed checks.

RESULT: FAIL_CLOSED — 37/37 diagnosed; fresh P3 is 25 FAIL plus 12 NOT_RUN; T1 tick aggregation is the coverage source; UK100/XTI are structural contract-basis mismatches; production splice remains unauthorized.
