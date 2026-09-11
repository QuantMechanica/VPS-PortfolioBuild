# Balke USDJPY range-window sweep — stage A result (2026-09-11)

Program `WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025`, pre-registered plan
`docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md` (commit 1da6f019c7), tooling
`tools/strategy_farm/window_sweep.py` (Codex 1b4644149e, stage B fc926dde). Adjudicated by the
tool's frozen stage-A rule (plan §5), not by hand. Evidence: surface
`docs/ops/evidence/2026-09-09_window_sweep_surface.csv` / `.json` (420 rows, 0 errors),
cell summaries under `D:\QM\reports\work_items\<id>\QM5_41398\...\summary.json`.

## Verdict

| Item | Result |
|---|---|
| Cells | 420 / 420 MEASURED (real ticks, Model 4, per year 2019–2025) |
| Refutation verdict (§2) | **H-WIN KEPT** — a better window exists |
| Winner (§5 plateau rule) | **start 0, length 8, exit 18** = 00:00–08:00 on the EA's fixed UTC+3 clock (21:00–05:00 UTC; broker 23:00–07:00 winter / 00:00–08:00 summer) |
| Winner DEV score / plateau | 1.96 / 1.56 |
| Baseline 03–06 (s3_l3) DEV / plateau | 0.65 / 0.78 (winner plateau = 2.0× baseline; margin ≥ 1.10 met) |
| OOS confirmation (§5) | true — winner OOS median ≥ baseline OOS median; **OOS pooled costed PF 1.21** |
| Top five (plateau order) | s0_l8, s1_l8, s1_l4, s2_l4, s3_l4 |

Score = costed net / max-DD per year; costed = native net − 5 USD per entry lot (DXZ venue truth).

## Per-year detail (score / costed net / trades / entry days)

| Window | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | Σ costed | trades |
|---|---|---|---|---|---|---|---|---|---|
| **s0_l8 (winner)** | −1.12 / −16.5k / 98 / 97 | 3.43 / 17.3k / 86 / 86 | 2.36 / 16.1k / 79 / 79 | 1.57 / 13.4k / 54 / 54 | 0.91 / 8.6k / 83 / 83 | −0.63 / −10.4k / 61 / 60 | 3.72 / 18.7k / 62 / 62 | **47.3k** | 523 |
| s1_l8 | −1.03 / −13.3k | 3.32 / 16.0k | 1.46 / 9.0k | 1.03 / 9.3k | −0.26 / −3.2k | 0.73 / 7.2k | 1.82 / 7.3k | 32.0k | 413 |
| s1_l4 | −0.51 / −8.9k | 2.26 / 28.7k | 3.84 / 32.1k | 1.38 / 20.7k | −0.58 / −12.2k | 0.18 / 2.7k | 1.37 / 19.6k | 82.7k | 1,335 |
| s2_l4 | −1.01 / −16.7k | 2.30 / 30.2k | 0.06 / 0.7k | 2.28 / 20.9k | −0.46 / −9.6k | −0.28 / −5.0k | 4.13 / 33.6k | 54.1k | 1,225 |
| s3_l4 | −0.88 / −12.7k | 3.38 / 32.1k | 0.58 / 6.3k | 0.97 / 10.6k | −0.24 / −3.7k | 0.75 / 9.2k | 0.63 / 6.4k | 48.2k | 1,146 |
| s3_l3 (baseline 03–06) | −0.90 / −17.0k | 1.55 / 23.3k | −0.25 / −4.0k | 2.14 / 21.0k | −0.47 / −11.7k | 0.15 / 2.1k | 2.64 / 23.9k | 37.4k | 1,347 |

Reading: the winner trades ~75 days a year (one straddle per day, roughly 2.5× fewer trades than the
3–4 h windows) with a much higher expectancy per trade and the best drawdown-normalised years; the
4-hour windows earn more gross money on many more trades but with deeper drawdowns. 2019 is negative
for every window; 2023–2025 are thin for all 3–4 h windows and positive for the winner (2 of 3 years).

**Notable:** the empirical winner (00:00–08:00 on the fixed UTC+3 clock) is essentially René Balke's
own published USDJPY configuration (range 00:00–07:30 broker time, close 18:00, captions evidence
`docs/research/VIDEO_Pay-JP34YSI_BALKE_USDJPY_CLOCK_2026-09-09.md`). The 03:00–06:00 window we had
carried since 2026-06-27 was the OWNER's own spec and ranks 29th of 48 admissible windows on DEV.

## Tooling note (GRÜN repair, rule untouched)

The report initially refused 111/420 MEASURED cells ("native round-trip pairing mismatch"): the
sequential in/out zip-pairing broke on same-timestamp fills with tester-rounded volumes (e.g. IN 17.22
/ OUT 17.23 lots). No plan metric needs pairing: per-trade costed P&L is now taken from each MT5
`out` deal (commission + swap + profit − 5 USD × lots), whose aggregate equals the former sum exactly;
net reconciliation against the summary stays strict. 17 tests pass. Patch in `window_sweep.py`
(commit noted in OPEN_ITEMS).

## Next (pre-registered)

1. Stage B: exit ∈ {15,16,17,19,20,21} for the top five (30 windows × 7 years = 210 cells,
   ~10 h at 2 lanes); final configuration = stage-B winner only if it beats s0_l8/exit 18 by ≥ 1.10
   on the plateau score and passes the OOS confirmation, else s0_l8 with exit 18 stands.
2. Astra `d444a7a8` continuation on the winner: clock modes (fixed UTC+3 / broker-DST / CET), buffer
   0 / 20 points, outside-range rule variants, ATR band off, and Balke's minute-granular 00:00–07:30
   configuration — as a NEW sibling instrument (QM5_41405 reserved), never by overwriting 41398.
3. A fresh Q02→Q10 chain for the final configuration; the DL-089 pattern census for 41398 (on the
   03–06 window) is provisional and will be re-planned on the winner.

## Not claimed

No live authorisation, no verdict change, no counter change. Stage A selects a window on the fixed
UTC+3 clock only; the clock-mode question and minute-granular range ends are stage-2 work.

## Stage B result (exit axis, 2026-09-11 ~15:00Z, tool-adjudicated)

210/210 cells MEASURED (top five windows x exit 15/16/17/19/20/21). Rule (plan §3/§5): the top-ranked
stage-B candidate must beat the stage-A winner (s0_l8, exit 18, plateau 1.56) by ≥ 1.10 on the plateau
score AND pass the OOS confirmation.

| | Candidate s1_l4 exit 21 | Stage-A winner s0_l8 exit 18 |
|---|---|---|
| DEV score / plateau | 2.71 / 2.60 | 1.96 / 1.56 |
| DEV improvement ≥ 1.10× | yes (1.66×) | — |
| OOS median costed return-to-maxDD | 0.24 | 0.91 |
| OOS pooled costed PF | 1.07 | 1.21 |
| OOS confirmation | **fails** | — |

**Final rule: STAGE_A_EXIT_18_STANDS.** Final configuration = start 0 / length 8 / exit 18.

Observation (not a selection, outside the rule): later exits raise DEV plateaus for both leading
windows (s0_l8 exit 21: 2.51, exit 20: 2.46) but only the top-ranked candidate is tested OOS by the
pre-registered rule, and it fails. A later-exit hypothesis for s0_l8 would be a new, separately
pre-registered program (stage-3 lever), not a re-selection here.

Tooling note: select_stage_b read the plateau from the raw stage-A surface (unannotated) and crashed
on KeyError; fixed to use the frozen stage-A report winner (same numbers), 17 tests pass.
