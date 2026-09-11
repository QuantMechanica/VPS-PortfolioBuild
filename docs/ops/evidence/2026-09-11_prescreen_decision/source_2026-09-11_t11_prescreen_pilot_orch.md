# T11 Prescreen Pilot: OHLC-M1 / Open-Prices vs Real-Tick (2026-09-11)

Program `T11_PRESCREEN_PILOT_ORCH`, EA QM5_41398_balke-pattern-repair-opt USDJPY.DWX H1.
30/30 planned canary runs completed on first attempt via `research_canary.py`
(`--stage` + run, `QM_CANARY_CPU_LIMIT=100`, `QM_CANARY_ADMISSION_SAMPLE_SECONDS=5`,
`--max-agents 2 --timeout-seconds 900`, sequential). 2 extra pre-existing dirs recorded
as evidence: one CPU-guard REFUSAL (99.16%>97.0, first attempt at 2021 s3_l3, later
retried successfully as the reference run) and one `--dry-run` probe. One completed cell
(2019 s3_l3, ohlc-m1) came back with `Ticks:0 / Symbols:0` — a genuine empty-backtest
anomaly, excluded from the stats below (n=19 for Mode A "all").

## Results (Spearman rho of score_cheap=net/max(|maxdd|,1) vs score_real)

| Scope | n | rho | sign agree | trade-count exact | top-5 overlap | FN@top-50% | median tester_s |
|---|---|---|---|---|---|---|---|
| Mode A ohlc-m1, all 3 years | 19 | 0.977 | 73.7% | 57.9% | 3/5 | 0/9 (0%) | 42.7s |
| Mode A ohlc-m1, 2021 only | 10 | 0.952 | 100.0% | 60.0% | 4/5 | 1/5 (20%) | 42.7s |
| Mode B open-prices, 2021 only | 10 | 0.988 | 90.0% | 20.0% | 4/5 | 1/5 (20%) | 37.8s |

Speed: real-tick reference for 2021 s3_l3 = 132s (given). Cheap tester time for the same
cell: ohlc-m1 39.4s (3.4x), open-prices 38.4s (3.4x). Median cheap tester time across all
cells 37.8-42.7s -> roughly 3.1-3.5x faster than the single real-tick reference point
(no fleet-wide real-tick timing available for direct per-cell comparison).

## Verdict

OHLC-M1 is admissible as a coarse PRE-SORT ranking tool for this window-sweep surface:
rank correlation is high (rho 0.95-0.98) and the false-negative rate at a top-50% cut is
low (0-20% across scopes, i.e. at most 1 truly-top cell in 5 would be wrongly discarded).
It is NOT admissible as a magnitude or trade-count surrogate: trade counts disagree on
40-80% of cells (open-prices is markedly worse here, 80% mismatch) and net-sign agreement
drops to 74% pooled across years (2021-only is much better, 90-100%). Recommended use:
OHLC-M1 (not open-prices, given its poor trade-count fidelity) to cut a window-sweep
candidate pool by ~50% before committing real-tick budget, never to accept/reject a
cell's economics outright. One cell (2019 s3_l3) needs re-run to confirm the zero-tick
result was transient rather than a data-window boundary defect.
