# Velocity family F1 — multi-hour session-range breakout sweep (pre-registered, 2026-09-21)

**Author:** Fable (claude-fable-5-1). **Status:** pre-registration written and committed BEFORE the sweep ran
(see the git history of this file); results are appended below the registration and never edit it.
**Authority:** OWNER 2026-09-20 Velocity priority; OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917.
**Harness:** `tools/strategy_farm/session_tools/hcc_m1_reader_0921.py` (read-only `.hcc` M1 reader, validated
bar-for-bar against the terminal's own JSONL export) + `velocity_family_f1_sweep_0921.py` (this sweep).
**Factory time:** 0 hours. No card, no build, no factory row, no QM-RESEARCH artifact is created by this sweep.

## 1. Why this family

The only measured Velocity-class stream in the whole inventory is QM5_13213 (René Balke's 03:00–06:00 GMT+3
range breakout on USDJPY H1: 0.74 trades/bd, +0.064R, median hold 7.2 h, 0 % overnight; byte-identical lineage
QM5_41484 USDJPY reproduced it at Q02: 888 trades, +46,637 USD, PF 1.12, 2018-07-02..2022-12-31). Its verbatim
transplant to nine other FX symbols failed (README §2c), and the one-hour pre-open ranges of H-V1/H-V2 were
falsified in 0 factory hours (`VELOCITY_HYPOTHESES_H_V1_V3_2026-09-21.md`, Revision 2): a 60-minute range is too
thin for a range-width stop to carry commission and spread. Family F1 asks the next honest question: does the
13213 mechanism — unchanged — carry expectancy on other symbols when the range is a MULTI-HOUR range ending at
that symbol's own session anchor?

## 2. Mechanism (frozen = QM5_13213 logic, replicated from its source)

Replicated from `framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213_balke-gmt3-range-breakout.mq5`
(547 lines, read in full) and `SPEC.md`:

- **Range:** the N completed 60-minute bars immediately before the anchor (13213: GMT+3-equivalent hours
  [3, 6) with N = 3, i.e. the bars whose GMT+3 hour is in `[end − N, end)` on the same GMT+3 day). All N bars
  must exist (13213: `bars_in_range >= end − start`), else no trade that day.
- **Filter:** ATR(14) of the same 60-minute grid at shift 1 (MT5 `iATR` = simple 14-bar average of the true
  range, read on the last closed bar before the anchor). Skip the day when `W < 0.4 × ATR` or `W > 2.5 × ATR`.
- **Orders:** at the first tick of the anchor bar, a buy stop at the range high with SL at the range low and a
  sell stop at the range low with SL at the range high; no take profit; one-cancels-other (13213 removes the
  opposite pending order on the tick after a fill). One position per day.
- **Management:** once the open profit reaches `1.0 × |entry − current SL|`, trail the SL to the lower (buy) /
  higher (sell) of the two most recently completed 60-minute bars whenever that improves it (13213
  `Strategy_ManageOpenPosition`). Exit on an opposite range-side touch (equivalent to the initial SL) and at the
  flat time (first tick at or after it: 13213 `Strategy_ExitSignal`); untriggered pending orders are cancelled
  at the flat time. Framework Friday close at 21:00 broker time closes any open position and blocks later
  entries. Framework news blackout (PRE30_POST30, high impact, the symbol's strict currencies) delays or blocks
  the order placement tick exactly as `OnTick` returns early in the EA; it is not modelled for exits/trailing
  (stated approximation).
- **Not modelled (stated):** real-tick intra-minute paths (the tester ran Model=4 real ticks; this sweep fills
  stop orders on the M1 bar that touches the level, at the level, with zero spread — the `.DWX` history carries
  no spread), and the ±1 point slippage visible in the Q02 report. If one M1 bar touches BOTH range edges the day
  is scored as a full loss at the stop (conservative rule).

## 3. Grid (369 cells = 41 symbols × 3 anchors × 3 N)

- **Anchors** (economic time → server time via `zoneinfo`; server clock = America/New_York + 7 h, i.e. GMT+2 /
  GMT+3 exactly as `QM_BrokerToUTC` + `Strategy_Gmt3Hour` assume):
  - **A** = 06:00 GMT+3-equivalent (the 13213 window end; flat 18:00 GMT+3-equivalent). Range bars on the
    server's on-the-hour grid, exactly like 13213.
  - **B** = 08:00 Europe/London cash open (flat 16:00 Europe/London). On-the-hour server grid.
  - **C** = 08:30 America/New_York (flat 16:00 America/New_York = 23:00 server, so the Friday 21:00 close
    applies). The 60-minute grid is shifted by 30 minutes so that bars end at :30 (an EA would build this grid
    from M1/M30; stated).
- **N** ∈ {2, 3, 4} hours (13213 = A × 3).
- **Symbols:** every FX symbol with `.hcc` M1 history under `D:/QM/mt5/T*/Bases/Custom/history/` (33: majors,
  JPY crosses, EUR/GBP/AUD/NZD/CAD/CHF crosses), XAUUSD.DWX, XAGUSD.DWX, and the six index symbols with M1
  history (GDAXI, JPN225, NDX, SP500, UK100, WS30). Index files pass the reader's structural validation only
  (parse, monotonic time, sane OHLC) — no JSONL harvest exists for them, so their rows are labelled
  `structural_validation_only`; the FX reader validation (EURUSD 94,574 / 94,575 rows, GBPUSD 100,000 / 100,000)
  is the harness's bar-level proof.
- **Costs:** `framework/registry/live_commission.json` (`max(0.005 % notional, flat per lot)`; forex 5 USD/lot,
  index 5.5 USD/lot, commodity 0) at RISK_FIXED 1000; lot size and USD notional use the symbol's own price and,
  for crosses, the USD pair closes at the anchor (EURUSD, GBPUSD, AUDUSD, NZDUSD, USDJPY, USDCHF, USDCAD).
  Index point values from the registry matrix (`custom_tv`: NDX 1.0, WS30 0.1, GDAXI 1 EUR, UK100 1 GBP);
  SP500 and JPN225 have no registry point value → 1.0 USD/point ASSUMED and flagged (cost only; gross R is
  unaffected). `.DWX` spread = 0 (stated); XAUUSD FTMO-venue spread sensitivity as in the H-V2 prescreen.

## 4. Pre-registered selection rule and null (written before running)

- **Periods:** SEL = 2018-07-02..2022-12-31 (1,175 business days, the Q02 window); VAL = 2023-01-01..2025-12-31.
- **SURVIVOR** iff on SEL: `n ≥ 300`, `E[R] ≥ +0.05R` after commission, `PF ≥ 1.10`, worst calendar-year
  drawdown `≤ 25R`; AND on VAL: `E[R] > 0` and `PF ≥ 1.05`. VAL is confirmation only — it is never used to choose
  among SEL cells. **Family consistency:** a survivor's neighbouring N cells (same symbol, same anchor) must have
  SEL `E[R] > 0`.
- **Null:** (a) the fraction of all cells with SEL `E[R] > 0`; (b) for every cell with `n ≥ 300` a centred
  circular block bootstrap of its SEL trade-R sequence (mean removed, block = 20 trades, 200 resamples): the
  fraction of resamples that meet the SEL rule is that cell's chance-pass probability, and the expected number of
  false SEL survivors is the sum of those probabilities over the grid (reported next to the observed count).
  A plain shuffle would not change E[R] or PF, so the centred bootstrap is the honest chance model for this rule.
- **Control cell (run first, mandatory):** USDJPY.DWX × A × 3 must reproduce the byte-identical lineage's Q02
  (work item 652e0768: 888 trades, +46,637 USD after commission, PF 1.12 over SEL). Tolerance ±15 % on trade
  count and ±0.03R on E[R]; the per-trade deals of the tester report (`raw/run_01/report.htm`) are parsed for a
  day-by-day overlap so any residual is explained, not averaged away.
- **Disposition rule:** survivors (if any, beyond the USDJPY × A control) are listed for Fable to mint
  QM-RESEARCH artifacts + Codex critique + Q02 canary; zero survivors beyond the control = the family is closed
  as measured, no build.

---

# Results (appended after the sweep; registration above unchanged)

**Run:** `velocity_family_f1_sweep_0921.py --workers 4`, 36 symbols with M1 history (JPN225.DWX has no M1
history → GAP), 314 cells with trades (GDAXI × A4 produced none), ~12 min wall-clock, 0 factory hours.
Output: `docs/ops/evidence/2026-09-20_velocity_book/velocity_family_f1_sweep_0921.json`.

**Harness fix first (round-2 critique 9caac5c7):** the H-V1/H-V2 prescreen's time-stop exit on holiday
early-close days used the next available open after the flat time (an overnight exit); it now exits at the close
of the final bar before the flat time. Re-run: H-V2 XAUUSD A15 SEL −0.0504 → −0.0514R, A20 −0.0459 → −0.0470R
(exactly the shift Codex predicted); H-V1 unchanged to 3 dp. `velocity_hv_prescreen_0921.json` regenerated; the
sealed (retired) artifacts 0009/0010 were not touched.

## Control cell: the simulator reproduces the tester within tolerance, with a known optimistic bias

| | trades | net R (after commission) | E[R] | PF | hold median (min) | trades/yr 2018–2022 |
|---|---|---|---|---|---|---|
| simulation | 904 | 63.55 | 0.0703 | 1.167 | 421.0 | 110, 199, 208, 212, 175 |
| tester report | 888 | 46.64 | 0.0525 | 1.122 | 419.3 | 106, 194, 205, 209, 174 |

Day-by-day: 886 common trade days, 18 simulation-only (net 9.376R), 2 report-only, 881 same direction on common days; per-trade net-R difference on common same-direction days: mean 0.007, median 0.0034, p10 -0.002, p90 0.0339.

Trade count +1.8 % (tolerance ±15 %), E[R] +0.018R (tolerance ±0.03R), median hold 421 vs 419 min, 881 of 886
common trade days in the same direction. The residual is a systematic optimism of the harness, not a rule
mismatch: (a) fills at the level with zero spread and zero slippage where the tester (Model=4 real ticks) fills a
point or so worse (mean +0.007R per common trade → ≈ +6R), (b) 18 simulation-only days worth +9.4R where the
tester placed no order or was blocked at tick level (the harness models the news blackout at the placement tick
only), (c) 5 direction mismatches on days when both edges were touched within seconds. **Read every harness E[R] in
this sweep as ≈ +0.02R above what the tester would print; the SEL bar +0.05R corresponds to ≈ +0.03R in a Q02.**

## Grid outcome and null

- Cells with trades: 314; cells with n ≥ 300 on SEL: 314; fraction of cells with SEL E[R] > 0: 0.3726.
- Cells passing the SEL rule: 27 (expected by chance under the per-cell centred block-bootstrap null: 17.41); survivors after VAL confirmation: 13 (expected by chance: 5.481; family-consistent: 13). Caveat: cells of one symbol share days and ranges (neighbouring N, overlapping anchors) and are not independent; the sums are per-cell expectations, not a family-level test.

## Survivors (SEL rule + VAL confirmation)

| symbol | cell | SEL n | /bd | E[R] | PF | DD R | R/bd | VAL n | /bd | E[R] | PF | DD R | R/bd | p SEL | p VAL | p joint | family-consistent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AUDJPY.DWX | B2 | 1100 | 0.94 | +0.089 | 1.193 | 21.97 | +0.083 | 695 | 0.89 | +0.035 | 1.073 | 21.69 | +0.031 | 0.055 | 0.29 | 0.0159 | True |
| CADJPY.DWX | A4 | 979 | 0.83 | +0.088 | 1.206 | 18.35 | +0.073 | 595 | 0.76 | +0.036 | 1.082 | 30.34 | +0.027 | 0.07 | 0.28 | 0.0196 | True |
| EURUSD.DWX | C3 | 729 | 0.62 | +0.076 | 1.181 | 24.68 | +0.047 | 512 | 0.65 | +0.105 | 1.225 | 15.75 | +0.069 | 0.075 | 0.33 | 0.0248 | True |
| EURUSD.DWX | C4 | 527 | 0.45 | +0.085 | 1.218 | 14.89 | +0.038 | 383 | 0.49 | +0.082 | 1.18 | 15.62 | +0.040 | 0.175 | 0.325 | 0.0569 | True |
| GBPUSD.DWX | B3 | 841 | 0.72 | +0.056 | 1.106 | 15.71 | +0.040 | 530 | 0.68 | +0.064 | 1.117 | 17.98 | +0.043 | 0.09 | 0.33 | 0.0297 | True |
| USDJPY.DWX | A2 | 1072 | 0.91 | +0.095 | 1.201 | 24.27 | +0.087 | 685 | 0.87 | +0.087 | 1.186 | 16.27 | +0.076 | 0.035 | 0.365 | 0.0128 | True |
| USDJPY.DWX | A3 | 904 | 0.77 | +0.070 | 1.167 | 19.94 | +0.054 | 577 | 0.74 | +0.104 | 1.242 | 19.34 | +0.077 | 0.08 | 0.29 | 0.0232 | True |
| USDJPY.DWX | A4 | 831 | 0.71 | +0.083 | 1.205 | 16.64 | +0.059 | 515 | 0.66 | +0.131 | 1.319 | 15.12 | +0.086 | 0.075 | 0.37 | 0.0278 | True |
| USDJPY.DWX | B3 | 1017 | 0.87 | +0.124 | 1.248 | 20.47 | +0.107 | 613 | 0.78 | +0.064 | 1.128 | 19.26 | +0.050 | 0.05 | 0.27 | 0.0135 | True |
| USDJPY.DWX | B4 | 944 | 0.80 | +0.110 | 1.23 | 19.11 | +0.088 | 549 | 0.70 | +0.047 | 1.097 | 23.34 | +0.033 | 0.065 | 0.35 | 0.0227 | True |
| USDJPY.DWX | C2 | 998 | 0.85 | +0.141 | 1.302 | 20.83 | +0.120 | 632 | 0.81 | +0.144 | 1.295 | 25.04 | +0.116 | 0.05 | 0.27 | 0.0135 | True |
| USDJPY.DWX | C3 | 926 | 0.79 | +0.123 | 1.288 | 20.65 | +0.097 | 596 | 0.76 | +0.141 | 1.319 | 22.2 | +0.107 | 0.065 | 0.275 | 0.0179 | True |
| USDJPY.DWX | C4 | 818 | 0.70 | +0.085 | 1.213 | 23.24 | +0.059 | 538 | 0.69 | +0.090 | 1.215 | 19.88 | +0.062 | 0.085 | 0.265 | 0.0225 | True |

## Reading

1. **The family does not transfer as a class.** Only 37 % of the 314 cells have positive SEL expectancy; the
   27 SEL passes are barely above the 17.4 expected from per-cell chance, and the 13 survivors after VAL sit
   against ≈ 5.5 expected by chance. AUDNZD, CHFJPY, EURCAD, EURCHF, GBPNZD and all five tradeable
   indices are negative on SEL in every cell; the crosses that pass SEL in isolated cells (EURAUD A2–A4, GBPJPY
   B2–B4, GBPCHF B3/B4, NZDUSD A2, AUDCHF B2, NZDJPY A4) all fail VAL, most with VAL E[R] ≤ −0.05R — exactly the
   in-sample-winner pattern the census holdout warned about. The 41484 lesson stands: a range breakout is not a
   mechanism that works "on FX", it works on specific symbols.
2. **USDJPY is the family.** 9 of 9 USDJPY cells are positive on SEL and 8 of 9 survive VAL — the edge is a
   property of the symbol, robust to the anchor (Tokyo, London, New York) and the range length (2–4 h), not of
   Balke's particular 03:00–06:00 window. The strongest cells in the whole grid are **USDJPY × C2 / C3** (2–3 h
   range before 08:30 New York, flat 16:00 New York): SEL +0.141 / +0.123R, PF 1.30 / 1.29, 0.85 / 0.79
   trades/bd, R/bd +0.120 / +0.097; VAL +0.144 / +0.141R, PF 1.30 / 1.32, R/bd +0.116 / +0.107; worst year
   20.8 / 20.7R (SEL) and 25.0 / 22.2R (VAL); family-consistent (C4 +0.085 / +0.090). That is ≈ 2× the measured
   incumbent (A3: +0.054 SEL / +0.077 VAL R/bd in the same harness; 0.040 R/bd in the Q02 census) with the same
   density. Because the Darwinex server clock follows US DST, 08:30 New York is 15:30 server time all year: the
   EA needs a fixed 15:30-server anchor on an M30 grid (range = 13:30–15:30 server, flat 23:00 server, framework
   Friday close 21:00), i.e. a **new build identity**, not a set-file variant of 13213. The JPY-quote pattern is
   broader (CADJPY 8/9, EURJPY 8/9, AUDJPY 6/9, NZDJPY 6/9 cells positive on SEL) but only USDJPY confirms on VAL
   with margin.
3. **EURUSD × C is the one non-JPY cell family that holds up on both periods:** C2 / C3 / C4 all positive on SEL
   (+0.073 / +0.076 / +0.085) and VAL (+0.094 / +0.105 / +0.082), PF 1.15–1.22, DD 15–28R; C3 and C4 survive.
   The A and B anchors on EURUSD are clearly negative (−0.04 to −0.08R), consistent with the H-V1 London failure.
   Density is capped at 0.45–0.62 trades/bd mainly by the ATR filter (C3: 523 of ≈1,930 days outside
   0.4–2.5 × ATR, vs 207 for USDJPY C3) and secondarily by the 08:30 ET high-impact releases (86 days blocked,
   225 delayed at the placement tick). R/bd +0.047 (C3, SEL) / +0.069 (VAL). Worth carrying as the second slot of the same NY-pre-open EA, with the USDJPY × EURUSD joint-tail
   check at Q08.
4. **GBPUSD B3, AUDJPY B2, CADJPY A4** pass the letter of the rule but not its spirit: GBPUSD B3 sits at the SEL
   bar (+0.056, neighbours +0.033 / +0.045), AUDJPY B2's VAL is +0.035 / PF 1.07 with neighbours ≈ 0 on VAL,
   CADJPY A4's VAL is +0.036 with 2023 at −20R and neighbours at +0.030 / +0.018. Recorded as watch cells, no
   artifact.
5. **XAUUSD** is instructive: B3 / B4 pass SEL and fail VAL, C2–C4 are ≈ 0 on SEL and +0.12–0.17 on VAL — the
   2023–25 gold regime, not a selectable edge (the H-V2 lesson again). No artifact.

## Verdict

There is a Velocity edge here, but it is **USDJPY's**, and the sweep found a materially better expression of it
than the incumbent: the New-York pre-open 2–3-hour range (USDJPY × C2 / C3) roughly doubles R per business day
at equal density on both the selection and the validation period, with a chance probability well below the
grid's false-positive expectation. Second, the same NY pre-open range carries expectancy on EURUSD (C3) at lower
density. Recommended next step (Fable, then Codex): mint **one** QM-RESEARCH artifact "NY pre-open session-range
breakout (13213 mechanics, 15:30-server anchor, M30 range grid)" with two symbol slots USDJPY (C2 primary, C3
as the frozen second arm) and EURUSD (C3), citing this sweep as the computed output; Codex critique; on
APPROVE_BUILD a new EA identity cloned from 13213's code with the anchor/grid change; Q02 canary USDJPY first
(the control lineage 41484 stays retired). Everything else in the grid is closed as measured. The harness
(reader + sweep, ~20 s per symbol-cell family) is the durable deliverable and should precede every future
Velocity card.

## Full cell table

| symbol | cell | SEL n | /bd | E[R] | PF | DD R | R/bd | VAL n | E[R] | PF | DD R | flag |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AUDCAD.DWX | A2 | 1071 | 0.91 | -0.044 | 0.912 | 42.22 | -0.041 | 673 | -0.080 | 0.837 | 50.29 |  |
| AUDCAD.DWX | A3 | 989 | 0.84 | +0.002 | 1.005 | 31.59 | +0.002 | 582 | -0.048 | 0.892 | 31.65 |  |
| AUDCAD.DWX | A4 | 946 | 0.81 | -0.014 | 0.969 | 35.02 | -0.011 | 553 | -0.039 | 0.909 | 30.19 |  |
| AUDCAD.DWX | B2 | 1110 | 0.94 | -0.033 | 0.939 | 37.49 | -0.031 | 720 | -0.142 | 0.741 | 52.31 |  |
| AUDCAD.DWX | B3 | 1061 | 0.90 | -0.046 | 0.911 | 32.44 | -0.042 | 674 | -0.117 | 0.775 | 49.49 |  |
| AUDCAD.DWX | B4 | 982 | 0.84 | -0.052 | 0.895 | 30.38 | -0.044 | 607 | -0.090 | 0.816 | 48.26 |  |
| AUDCAD.DWX | C2 | 1025 | 0.87 | -0.024 | 0.953 | 27.28 | -0.021 | 676 | -0.154 | 0.722 | 40.51 |  |
| AUDCAD.DWX | C3 | 946 | 0.81 | -0.025 | 0.944 | 23.98 | -0.020 | 651 | -0.138 | 0.723 | 39.4 |  |
| AUDCAD.DWX | C4 | 842 | 0.72 | -0.038 | 0.909 | 27.69 | -0.028 | 601 | -0.147 | 0.684 | 33.97 |  |
| AUDCHF.DWX | A2 | 1056 | 0.90 | +0.030 | 1.059 | 30.02 | +0.027 | 682 | -0.076 | 0.854 | 34.68 |  |
| AUDCHF.DWX | A3 | 954 | 0.81 | -0.010 | 0.979 | 26.1 | -0.008 | 612 | -0.097 | 0.808 | 38.11 |  |
| AUDCHF.DWX | A4 | 891 | 0.76 | -0.013 | 0.972 | 19.37 | -0.010 | 575 | -0.124 | 0.756 | 37.93 |  |
| AUDCHF.DWX | B2 | 1064 | 0.91 | +0.057 | 1.114 | 24.06 | +0.051 | 693 | -0.089 | 0.83 | 36.21 | SEL-pass, VAL fail |
| AUDCHF.DWX | B3 | 997 | 0.85 | +0.027 | 1.056 | 25.69 | +0.023 | 652 | -0.051 | 0.896 | 26.97 |  |
| AUDCHF.DWX | B4 | 906 | 0.77 | +0.014 | 1.03 | 24.12 | +0.011 | 596 | -0.056 | 0.881 | 20.58 |  |
| AUDCHF.DWX | C2 | 1076 | 0.92 | -0.106 | 0.79 | 42.81 | -0.097 | 715 | -0.108 | 0.798 | 57.8 |  |
| AUDCHF.DWX | C3 | 986 | 0.84 | -0.118 | 0.746 | 39.59 | -0.099 | 672 | -0.060 | 0.871 | 40.01 |  |
| AUDCHF.DWX | C4 | 818 | 0.70 | -0.106 | 0.746 | 37.13 | -0.074 | 576 | -0.068 | 0.841 | 28.4 |  |
| AUDJPY.DWX | A2 | 985 | 0.84 | +0.034 | 1.072 | 24.34 | +0.028 | 630 | +0.017 | 1.037 | 33.29 |  |
| AUDJPY.DWX | A3 | 795 | 0.68 | +0.019 | 1.044 | 16.57 | +0.013 | 518 | +0.017 | 1.04 | 22.19 |  |
| AUDJPY.DWX | A4 | 701 | 0.60 | +0.045 | 1.116 | 13.74 | +0.027 | 465 | +0.002 | 1.004 | 21.81 |  |
| AUDJPY.DWX | B2 | 1100 | 0.94 | +0.089 | 1.193 | 21.97 | +0.083 | 695 | +0.035 | 1.073 | 21.69 | SURVIVOR |
| AUDJPY.DWX | B3 | 1013 | 0.86 | +0.086 | 1.202 | 25.69 | +0.074 | 637 | +0.002 | 1.005 | 23.1 |  |
| AUDJPY.DWX | B4 | 913 | 0.78 | +0.072 | 1.177 | 20.93 | +0.056 | 566 | -0.012 | 0.973 | 22.95 | SEL-pass, VAL fail |
| AUDJPY.DWX | C2 | 1123 | 0.96 | -0.042 | 0.92 | 46.41 | -0.040 | 737 | -0.059 | 0.891 | 46.33 |  |
| AUDJPY.DWX | C3 | 1074 | 0.91 | -0.021 | 0.955 | 37.43 | -0.019 | 711 | -0.080 | 0.839 | 43.27 |  |
| AUDJPY.DWX | C4 | 963 | 0.82 | -0.044 | 0.896 | 43.96 | -0.036 | 652 | -0.082 | 0.822 | 37.3 |  |
| AUDNZD.DWX | A2 | 1032 | 0.88 | -0.078 | 0.842 | 50.43 | -0.069 | 645 | -0.098 | 0.795 | 53.52 |  |
| AUDNZD.DWX | A3 | 905 | 0.77 | -0.033 | 0.924 | 21.63 | -0.025 | 564 | -0.078 | 0.818 | 37.66 |  |
| AUDNZD.DWX | A4 | 817 | 0.70 | -0.021 | 0.948 | 19.68 | -0.015 | 506 | -0.080 | 0.803 | 37.76 |  |
| AUDNZD.DWX | B2 | 1131 | 0.96 | -0.085 | 0.835 | 53.4 | -0.082 | 732 | -0.193 | 0.631 | 63.59 |  |
| AUDNZD.DWX | B3 | 1092 | 0.93 | -0.061 | 0.87 | 37.88 | -0.057 | 704 | -0.197 | 0.603 | 63.43 |  |
| AUDNZD.DWX | B4 | 1027 | 0.87 | -0.011 | 0.975 | 23.53 | -0.009 | 658 | -0.185 | 0.594 | 59.52 |  |
| AUDNZD.DWX | C2 | 1109 | 0.94 | -0.239 | 0.554 | 83.85 | -0.226 | 718 | -0.264 | 0.546 | 93.43 |  |
| AUDNZD.DWX | C3 | 1051 | 0.89 | -0.207 | 0.554 | 61.07 | -0.185 | 699 | -0.237 | 0.533 | 70.24 |  |
| AUDNZD.DWX | C4 | 953 | 0.81 | -0.207 | 0.51 | 56.08 | -0.168 | 645 | -0.194 | 0.557 | 50.87 |  |
| AUDUSD.DWX | A2 | 1023 | 0.87 | +0.040 | 1.086 | 21.1 | +0.035 | 634 | -0.033 | 0.93 | 29.62 |  |
| AUDUSD.DWX | A3 | 889 | 0.76 | +0.025 | 1.058 | 29.89 | +0.019 | 559 | +0.002 | 1.004 | 24.59 |  |
| AUDUSD.DWX | A4 | 829 | 0.71 | +0.044 | 1.107 | 23.99 | +0.031 | 531 | -0.003 | 0.994 | 26.36 |  |
| AUDUSD.DWX | B2 | 1085 | 0.92 | +0.006 | 1.013 | 32.23 | +0.006 | 694 | -0.072 | 0.863 | 31.96 |  |
| AUDUSD.DWX | B3 | 1000 | 0.85 | +0.014 | 1.028 | 25.4 | +0.012 | 639 | -0.050 | 0.9 | 25.81 |  |
| AUDUSD.DWX | B4 | 890 | 0.76 | +0.023 | 1.05 | 25.47 | +0.017 | 560 | -0.027 | 0.944 | 20.21 |  |
| AUDUSD.DWX | C2 | 1036 | 0.88 | +0.045 | 1.09 | 26.42 | +0.040 | 651 | -0.013 | 0.975 | 48.09 |  |
| AUDUSD.DWX | C3 | 970 | 0.83 | +0.005 | 1.01 | 27.53 | +0.004 | 627 | -0.018 | 0.964 | 41.43 |  |
| AUDUSD.DWX | C4 | 854 | 0.73 | +0.001 | 1.001 | 20.15 | +0.000 | 579 | -0.017 | 0.961 | 37.86 |  |
| CADCHF.DWX | A2 | 1136 | 0.97 | -0.098 | 0.841 | 64.71 | -0.095 | 731 | -0.162 | 0.746 | 68.19 |  |
| CADCHF.DWX | A3 | 1141 | 0.97 | -0.059 | 0.898 | 48.82 | -0.057 | 743 | -0.146 | 0.758 | 68.31 |  |
| CADCHF.DWX | A4 | 1133 | 0.96 | -0.073 | 0.868 | 46.31 | -0.070 | 726 | -0.129 | 0.775 | 66.05 |  |
| CADCHF.DWX | B2 | 1067 | 0.91 | -0.001 | 0.998 | 37.96 | -0.001 | 686 | -0.106 | 0.825 | 53.26 |  |
| CADCHF.DWX | B3 | 1042 | 0.89 | -0.007 | 0.988 | 25.54 | -0.006 | 663 | -0.097 | 0.834 | 44.91 |  |
| CADCHF.DWX | B4 | 1006 | 0.86 | +0.004 | 1.008 | 23.78 | +0.004 | 641 | -0.136 | 0.767 | 51.08 |  |
| CADCHF.DWX | C2 | 875 | 0.74 | -0.091 | 0.827 | 43.26 | -0.068 | 583 | -0.046 | 0.911 | 36.52 |  |
| CADCHF.DWX | C3 | 703 | 0.60 | -0.124 | 0.756 | 41.57 | -0.074 | 487 | -0.084 | 0.836 | 32.36 |  |
| CADCHF.DWX | C4 | 515 | 0.44 | -0.103 | 0.777 | 26.81 | -0.045 | 354 | -0.022 | 0.952 | 22.33 |  |
| CADJPY.DWX | A2 | 1120 | 0.95 | +0.122 | 1.243 | 29.06 | +0.116 | 705 | +0.030 | 1.063 | 24.53 |  |
| CADJPY.DWX | A3 | 1040 | 0.89 | +0.087 | 1.196 | 28.09 | +0.077 | 631 | +0.018 | 1.04 | 27.97 |  |
| CADJPY.DWX | A4 | 979 | 0.83 | +0.088 | 1.206 | 18.35 | +0.073 | 595 | +0.036 | 1.082 | 30.34 | SURVIVOR |
| CADJPY.DWX | B2 | 1095 | 0.93 | +0.050 | 1.092 | 39.02 | +0.047 | 691 | +0.011 | 1.02 | 25.17 |  |
| CADJPY.DWX | B3 | 1048 | 0.89 | +0.082 | 1.159 | 28.64 | +0.073 | 653 | +0.012 | 1.023 | 20.33 |  |
| CADJPY.DWX | B4 | 984 | 0.84 | +0.070 | 1.139 | 26.35 | +0.059 | 598 | -0.004 | 0.992 | 23.24 |  |
| CADJPY.DWX | C2 | 980 | 0.83 | +0.010 | 1.021 | 34.16 | +0.009 | 691 | +0.020 | 1.038 | 26.18 |  |
| CADJPY.DWX | C3 | 907 | 0.77 | -0.014 | 0.97 | 31.88 | -0.011 | 641 | +0.029 | 1.059 | 24.87 |  |
| CADJPY.DWX | C4 | 798 | 0.68 | +0.003 | 1.006 | 21.48 | +0.002 | 580 | +0.026 | 1.058 | 24.15 |  |
| CHFJPY.DWX | A2 | 1126 | 0.96 | -0.033 | 0.94 | 56.33 | -0.032 | 706 | -0.019 | 0.963 | 22.77 |  |
| CHFJPY.DWX | A3 | 1049 | 0.89 | -0.024 | 0.953 | 41.84 | -0.021 | 643 | -0.030 | 0.938 | 34.32 |  |
| CHFJPY.DWX | A4 | 991 | 0.84 | -0.042 | 0.914 | 34.27 | -0.036 | 596 | -0.067 | 0.863 | 31.52 |  |
| CHFJPY.DWX | B2 | 1062 | 0.90 | -0.010 | 0.982 | 36.98 | -0.009 | 661 | -0.060 | 0.886 | 33.54 |  |
| CHFJPY.DWX | B3 | 1017 | 0.87 | -0.033 | 0.942 | 26.05 | -0.028 | 608 | -0.040 | 0.92 | 26.78 |  |
| CHFJPY.DWX | B4 | 956 | 0.81 | -0.029 | 0.947 | 28.59 | -0.023 | 546 | -0.046 | 0.901 | 26.07 |  |
| CHFJPY.DWX | C2 | 1055 | 0.90 | -0.088 | 0.817 | 42.61 | -0.079 | 705 | -0.100 | 0.799 | 55.63 |  |
| CHFJPY.DWX | C3 | 907 | 0.77 | -0.043 | 0.897 | 25.93 | -0.034 | 656 | -0.067 | 0.844 | 29.07 |  |
| CHFJPY.DWX | C4 | 691 | 0.59 | -0.031 | 0.918 | 18.62 | -0.018 | 561 | -0.058 | 0.847 | 23.02 |  |
| EURAUD.DWX | A2 | 1037 | 0.88 | +0.135 | 1.298 | 13.85 | +0.119 | 640 | -0.064 | 0.87 | 56.45 | SEL-pass, VAL fail |
| EURAUD.DWX | A3 | 929 | 0.79 | +0.097 | 1.226 | 11.72 | +0.077 | 541 | -0.078 | 0.84 | 44.55 | SEL-pass, VAL fail |
| EURAUD.DWX | A4 | 864 | 0.74 | +0.093 | 1.225 | 12.72 | +0.068 | 508 | -0.091 | 0.81 | 41.13 | SEL-pass, VAL fail |
| EURAUD.DWX | B2 | 1019 | 0.87 | +0.030 | 1.06 | 33.91 | +0.026 | 646 | -0.058 | 0.885 | 33.1 |  |
| EURAUD.DWX | B3 | 948 | 0.81 | +0.018 | 1.037 | 31.27 | +0.014 | 590 | -0.018 | 0.963 | 20.27 |  |
| EURAUD.DWX | B4 | 871 | 0.74 | +0.012 | 1.026 | 19.89 | +0.009 | 522 | -0.016 | 0.964 | 20.47 |  |
| EURAUD.DWX | C2 | 1090 | 0.93 | -0.015 | 0.968 | 30.99 | -0.014 | 704 | -0.057 | 0.889 | 34.38 |  |
| EURAUD.DWX | C3 | 980 | 0.83 | -0.014 | 0.965 | 18.99 | -0.012 | 663 | -0.036 | 0.921 | 28.32 |  |
| EURAUD.DWX | C4 | 822 | 0.70 | -0.011 | 0.969 | 20.16 | -0.008 | 590 | -0.041 | 0.899 | 25.57 |  |
| EURCAD.DWX | A2 | 1138 | 0.97 | -0.107 | 0.827 | 85.47 | -0.104 | 741 | -0.120 | 0.808 | 47.84 |  |
| EURCAD.DWX | A3 | 1145 | 0.97 | -0.060 | 0.897 | 73.02 | -0.058 | 739 | -0.134 | 0.772 | 57.3 |  |
| EURCAD.DWX | A4 | 1139 | 0.97 | -0.063 | 0.888 | 67.12 | -0.061 | 732 | -0.036 | 0.933 | 26.36 |  |
| EURCAD.DWX | B2 | 1021 | 0.87 | -0.057 | 0.905 | 52.93 | -0.049 | 648 | -0.017 | 0.97 | 45.19 |  |
| EURCAD.DWX | B3 | 984 | 0.84 | -0.073 | 0.875 | 59.63 | -0.061 | 631 | -0.031 | 0.945 | 44.82 |  |
| EURCAD.DWX | B4 | 934 | 0.79 | -0.062 | 0.893 | 57.78 | -0.049 | 606 | -0.041 | 0.926 | 43.2 |  |
| EURCAD.DWX | C2 | 849 | 0.72 | -0.029 | 0.943 | 37.25 | -0.021 | 557 | -0.024 | 0.955 | 28.83 |  |
| EURCAD.DWX | C3 | 683 | 0.58 | -0.026 | 0.945 | 32.05 | -0.015 | 455 | -0.023 | 0.953 | 20.75 |  |
| EURCAD.DWX | C4 | 491 | 0.42 | -0.008 | 0.982 | 21.56 | -0.003 | 338 | -0.028 | 0.939 | 23.07 |  |
| EURCHF.DWX | A2 | 1137 | 0.97 | -0.225 | 0.669 | 83.88 | -0.218 | 737 | -0.141 | 0.787 | 67.14 |  |
| EURCHF.DWX | A3 | 1142 | 0.97 | -0.162 | 0.748 | 56.79 | -0.158 | 745 | -0.123 | 0.801 | 57.83 |  |
| EURCHF.DWX | A4 | 1131 | 0.96 | -0.134 | 0.78 | 52.6 | -0.129 | 736 | -0.114 | 0.806 | 60.11 |  |
| EURCHF.DWX | B2 | 904 | 0.77 | -0.055 | 0.906 | 57.82 | -0.043 | 568 | -0.069 | 0.884 | 59.35 |  |
| EURCHF.DWX | B3 | 877 | 0.75 | -0.004 | 0.992 | 48.42 | -0.003 | 540 | -0.075 | 0.872 | 56.34 |  |
| EURCHF.DWX | B4 | 834 | 0.71 | -0.002 | 0.997 | 44.76 | -0.001 | 507 | -0.096 | 0.835 | 58.28 |  |
| EURCHF.DWX | C2 | 958 | 0.82 | -0.115 | 0.764 | 59.64 | -0.093 | 634 | -0.122 | 0.764 | 39.98 |  |
| EURCHF.DWX | C3 | 749 | 0.64 | -0.099 | 0.772 | 43.33 | -0.063 | 523 | -0.109 | 0.765 | 32.81 |  |
| EURCHF.DWX | C4 | 519 | 0.44 | -0.064 | 0.837 | 22.78 | -0.028 | 363 | -0.100 | 0.764 | 24.46 |  |
| EURGBP.DWX | A2 | 1122 | 0.95 | -0.140 | 0.787 | 76.19 | -0.134 | 737 | -0.029 | 0.955 | 51.04 |  |
| EURGBP.DWX | A3 | 1142 | 0.97 | -0.061 | 0.902 | 75.37 | -0.059 | 741 | +0.025 | 1.042 | 38.81 |  |
| EURGBP.DWX | A4 | 1138 | 0.97 | -0.028 | 0.952 | 67.74 | -0.028 | 739 | +0.033 | 1.058 | 33.14 |  |
| EURGBP.DWX | B2 | 856 | 0.73 | +0.094 | 1.165 | 29.68 | +0.068 | 487 | -0.129 | 0.778 | 35.4 |  |
| EURGBP.DWX | B3 | 802 | 0.68 | +0.094 | 1.166 | 32.41 | +0.064 | 466 | -0.127 | 0.775 | 40.23 |  |
| EURGBP.DWX | B4 | 755 | 0.64 | +0.079 | 1.141 | 29.5 | +0.051 | 441 | -0.128 | 0.772 | 40.35 |  |
| EURGBP.DWX | C2 | 883 | 0.75 | -0.088 | 0.805 | 31.91 | -0.067 | 593 | -0.120 | 0.758 | 53.47 |  |
| EURGBP.DWX | C3 | 642 | 0.55 | -0.084 | 0.797 | 27.41 | -0.046 | 454 | -0.096 | 0.782 | 23.33 |  |
| EURGBP.DWX | C4 | 389 | 0.33 | -0.153 | 0.627 | 27.13 | -0.051 | 300 | -0.137 | 0.683 | 26.92 |  |
| EURJPY.DWX | A2 | 1110 | 0.94 | -0.011 | 0.98 | 35.91 | -0.010 | 689 | +0.049 | 1.094 | 47.02 |  |
| EURJPY.DWX | A3 | 975 | 0.83 | +0.015 | 1.031 | 20.59 | +0.012 | 599 | +0.034 | 1.073 | 22.87 |  |
| EURJPY.DWX | A4 | 918 | 0.78 | +0.006 | 1.012 | 25.95 | +0.004 | 544 | +0.011 | 1.023 | 26.93 |  |
| EURJPY.DWX | B2 | 997 | 0.85 | +0.002 | 1.003 | 27.27 | +0.001 | 614 | +0.040 | 1.082 | 23.03 |  |
| EURJPY.DWX | B3 | 943 | 0.80 | +0.015 | 1.028 | 28.66 | +0.012 | 562 | +0.030 | 1.065 | 20.22 |  |
| EURJPY.DWX | B4 | 871 | 0.74 | +0.008 | 1.016 | 29.33 | +0.006 | 499 | +0.021 | 1.046 | 22.33 |  |
| EURJPY.DWX | C2 | 1050 | 0.89 | +0.045 | 1.102 | 21.06 | +0.040 | 703 | +0.056 | 1.118 | 22.87 |  |
| EURJPY.DWX | C3 | 937 | 0.80 | +0.039 | 1.101 | 20.95 | +0.032 | 646 | +0.024 | 1.057 | 20.37 |  |
| EURJPY.DWX | C4 | 766 | 0.65 | +0.046 | 1.135 | 17.51 | +0.030 | 571 | +0.040 | 1.113 | 14.98 |  |
| EURNZD.DWX | A2 | 1084 | 0.92 | +0.047 | 1.098 | 20.46 | +0.044 | 672 | +0.013 | 1.028 | 19.89 |  |
| EURNZD.DWX | A3 | 1008 | 0.86 | +0.033 | 1.073 | 20.05 | +0.028 | 589 | -0.022 | 0.951 | 21.54 |  |
| EURNZD.DWX | A4 | 942 | 0.80 | +0.020 | 1.046 | 17.41 | +0.016 | 536 | -0.034 | 0.922 | 21.89 |  |
| EURNZD.DWX | B2 | 1049 | 0.89 | +0.022 | 1.041 | 30.52 | +0.020 | 667 | -0.083 | 0.837 | 47.83 |  |
| EURNZD.DWX | B3 | 1008 | 0.86 | +0.043 | 1.087 | 24.77 | +0.036 | 625 | -0.108 | 0.781 | 48.92 |  |
| EURNZD.DWX | B4 | 940 | 0.80 | +0.018 | 1.039 | 22.87 | +0.015 | 571 | -0.090 | 0.804 | 40.39 |  |
| EURNZD.DWX | C2 | 1065 | 0.91 | -0.096 | 0.8 | 38.61 | -0.087 | 688 | -0.112 | 0.786 | 42.17 |  |
| EURNZD.DWX | C3 | 955 | 0.81 | -0.097 | 0.776 | 39.99 | -0.079 | 647 | -0.091 | 0.798 | 35.65 |  |
| EURNZD.DWX | C4 | 817 | 0.70 | -0.081 | 0.789 | 37.9 | -0.057 | 579 | -0.108 | 0.736 | 33.01 |  |
| EURUSD.DWX | A2 | 1143 | 0.97 | -0.042 | 0.929 | 78.21 | -0.041 | 740 | -0.067 | 0.891 | 39.75 |  |
| EURUSD.DWX | A3 | 1118 | 0.95 | -0.073 | 0.872 | 68.3 | -0.069 | 715 | -0.038 | 0.934 | 36.71 |  |
| EURUSD.DWX | A4 | 1102 | 0.94 | -0.075 | 0.865 | 65.31 | -0.070 | 697 | -0.056 | 0.901 | 35.21 |  |
| EURUSD.DWX | B2 | 907 | 0.77 | -0.071 | 0.879 | 52.64 | -0.054 | 596 | +0.089 | 1.164 | 23.42 |  |
| EURUSD.DWX | B3 | 845 | 0.72 | -0.083 | 0.855 | 53.79 | -0.060 | 554 | +0.051 | 1.093 | 22.25 |  |
| EURUSD.DWX | B4 | 773 | 0.66 | -0.081 | 0.855 | 51.88 | -0.053 | 509 | +0.009 | 1.016 | 24.7 |  |
| EURUSD.DWX | C2 | 896 | 0.76 | +0.073 | 1.154 | 27.51 | +0.055 | 589 | +0.094 | 1.19 | 17.92 |  |
| EURUSD.DWX | C3 | 729 | 0.62 | +0.076 | 1.181 | 24.68 | +0.047 | 512 | +0.105 | 1.225 | 15.75 | SURVIVOR |
| EURUSD.DWX | C4 | 527 | 0.45 | +0.085 | 1.218 | 14.89 | +0.038 | 383 | +0.082 | 1.18 | 15.62 | SURVIVOR |
| GBPAUD.DWX | A2 | 1078 | 0.92 | +0.013 | 1.025 | 27.34 | +0.012 | 657 | -0.061 | 0.881 | 56.84 |  |
| GBPAUD.DWX | A3 | 1001 | 0.85 | +0.003 | 1.007 | 22.39 | +0.003 | 563 | -0.053 | 0.89 | 41.14 |  |
| GBPAUD.DWX | A4 | 959 | 0.82 | -0.012 | 0.975 | 27.42 | -0.010 | 532 | -0.060 | 0.873 | 38.73 |  |
| GBPAUD.DWX | B2 | 1070 | 0.91 | +0.021 | 1.04 | 24.98 | +0.019 | 655 | -0.036 | 0.929 | 27.32 |  |
| GBPAUD.DWX | B3 | 998 | 0.85 | +0.025 | 1.051 | 21.71 | +0.021 | 600 | -0.030 | 0.938 | 21.83 |  |
| GBPAUD.DWX | B4 | 922 | 0.78 | +0.001 | 1.001 | 26.85 | +0.001 | 540 | -0.004 | 0.991 | 17.86 |  |
| GBPAUD.DWX | C2 | 1039 | 0.88 | -0.100 | 0.786 | 49.82 | -0.089 | 707 | -0.099 | 0.799 | 41.0 |  |
| GBPAUD.DWX | C3 | 916 | 0.78 | -0.102 | 0.761 | 37.36 | -0.079 | 658 | -0.104 | 0.764 | 41.27 |  |
| GBPAUD.DWX | C4 | 732 | 0.62 | -0.086 | 0.776 | 32.41 | -0.053 | 567 | -0.101 | 0.745 | 31.7 |  |
| GBPCAD.DWX | A2 | 1129 | 0.96 | -0.073 | 0.882 | 42.23 | -0.070 | 730 | -0.110 | 0.826 | 76.21 |  |
| GBPCAD.DWX | A3 | 1150 | 0.98 | -0.062 | 0.894 | 40.16 | -0.060 | 746 | -0.090 | 0.853 | 70.2 |  |
| GBPCAD.DWX | A4 | 1140 | 0.97 | -0.033 | 0.941 | 34.61 | -0.032 | 743 | -0.073 | 0.878 | 63.87 |  |
| GBPCAD.DWX | B2 | 1010 | 0.86 | +0.027 | 1.048 | 39.51 | +0.023 | 617 | -0.174 | 0.729 | 64.5 |  |
| GBPCAD.DWX | B3 | 966 | 0.82 | +0.016 | 1.029 | 36.97 | +0.013 | 598 | -0.161 | 0.745 | 63.65 |  |
| GBPCAD.DWX | B4 | 923 | 0.79 | +0.015 | 1.027 | 37.24 | +0.012 | 572 | -0.168 | 0.727 | 60.71 |  |
| GBPCAD.DWX | C2 | 807 | 0.69 | -0.133 | 0.732 | 32.95 | -0.092 | 552 | -0.044 | 0.912 | 30.72 |  |
| GBPCAD.DWX | C3 | 610 | 0.52 | -0.102 | 0.774 | 26.35 | -0.053 | 434 | -0.056 | 0.881 | 20.13 |  |
| GBPCAD.DWX | C4 | 390 | 0.33 | -0.076 | 0.822 | 16.1 | -0.025 | 320 | -0.078 | 0.829 | 17.61 |  |
| GBPCHF.DWX | A2 | 1132 | 0.96 | -0.136 | 0.789 | 74.43 | -0.131 | 735 | -0.059 | 0.909 | 63.14 |  |
| GBPCHF.DWX | A3 | 1148 | 0.98 | -0.093 | 0.849 | 86.77 | -0.091 | 748 | -0.046 | 0.923 | 50.05 |  |
| GBPCHF.DWX | A4 | 1135 | 0.97 | -0.078 | 0.867 | 81.15 | -0.075 | 736 | -0.031 | 0.945 | 49.6 |  |
| GBPCHF.DWX | B2 | 943 | 0.80 | +0.087 | 1.153 | 27.76 | +0.070 | 579 | -0.131 | 0.783 | 44.7 |  |
| GBPCHF.DWX | B3 | 897 | 0.76 | +0.088 | 1.159 | 24.63 | +0.068 | 560 | -0.129 | 0.782 | 42.95 | SEL-pass, VAL fail |
| GBPCHF.DWX | B4 | 842 | 0.72 | +0.087 | 1.159 | 20.4 | +0.062 | 538 | -0.117 | 0.797 | 37.41 | SEL-pass, VAL fail |
| GBPCHF.DWX | C2 | 913 | 0.78 | -0.073 | 0.844 | 30.08 | -0.057 | 601 | -0.178 | 0.669 | 51.89 |  |
| GBPCHF.DWX | C3 | 692 | 0.59 | -0.061 | 0.855 | 23.99 | -0.036 | 478 | -0.187 | 0.623 | 38.32 |  |
| GBPCHF.DWX | C4 | 430 | 0.37 | -0.087 | 0.78 | 19.11 | -0.032 | 315 | -0.166 | 0.629 | 29.93 |  |
| GBPJPY.DWX | A2 | 1119 | 0.95 | -0.023 | 0.96 | 40.04 | -0.022 | 706 | +0.053 | 1.103 | 29.57 |  |
| GBPJPY.DWX | A3 | 1047 | 0.89 | -0.004 | 0.992 | 42.3 | -0.004 | 644 | +0.023 | 1.048 | 24.58 |  |
| GBPJPY.DWX | A4 | 1001 | 0.85 | +0.015 | 1.031 | 34.4 | +0.013 | 592 | +0.015 | 1.033 | 20.92 |  |
| GBPJPY.DWX | B2 | 1016 | 0.86 | +0.096 | 1.184 | 20.66 | +0.083 | 620 | -0.004 | 0.993 | 31.93 | SEL-pass, VAL fail |
| GBPJPY.DWX | B3 | 958 | 0.82 | +0.093 | 1.181 | 20.8 | +0.076 | 575 | +0.002 | 1.003 | 26.5 | SEL-pass, VAL fail |
| GBPJPY.DWX | B4 | 879 | 0.75 | +0.119 | 1.24 | 15.24 | +0.089 | 521 | -0.003 | 0.995 | 20.03 | SEL-pass, VAL fail |
| GBPJPY.DWX | C2 | 1015 | 0.86 | -0.018 | 0.961 | 33.58 | -0.015 | 698 | +0.002 | 1.005 | 30.32 |  |
| GBPJPY.DWX | C3 | 878 | 0.75 | -0.003 | 0.993 | 20.28 | -0.002 | 634 | +0.022 | 1.053 | 17.11 |  |
| GBPJPY.DWX | C4 | 658 | 0.56 | +0.029 | 1.083 | 15.36 | +0.017 | 543 | +0.041 | 1.109 | 15.05 |  |
| GBPNZD.DWX | A2 | 1106 | 0.94 | -0.028 | 0.948 | 37.76 | -0.026 | 690 | +0.029 | 1.062 | 19.39 |  |
| GBPNZD.DWX | A3 | 1061 | 0.90 | -0.030 | 0.941 | 36.18 | -0.028 | 620 | +0.029 | 1.069 | 15.76 |  |
| GBPNZD.DWX | A4 | 1020 | 0.87 | -0.037 | 0.924 | 38.49 | -0.032 | 564 | +0.011 | 1.028 | 15.61 |  |
| GBPNZD.DWX | B2 | 1103 | 0.94 | -0.076 | 0.864 | 44.27 | -0.071 | 673 | -0.088 | 0.837 | 35.6 |  |
| GBPNZD.DWX | B3 | 1060 | 0.90 | -0.092 | 0.829 | 47.22 | -0.083 | 636 | -0.092 | 0.819 | 33.3 |  |
| GBPNZD.DWX | B4 | 986 | 0.84 | -0.092 | 0.822 | 46.4 | -0.078 | 594 | -0.088 | 0.817 | 37.46 |  |
| GBPNZD.DWX | C2 | 1036 | 0.88 | -0.096 | 0.784 | 35.78 | -0.085 | 692 | -0.152 | 0.701 | 47.05 |  |
| GBPNZD.DWX | C3 | 886 | 0.75 | -0.090 | 0.772 | 34.4 | -0.068 | 653 | -0.142 | 0.685 | 40.1 |  |
| GBPNZD.DWX | C4 | 710 | 0.60 | -0.079 | 0.777 | 24.96 | -0.048 | 559 | -0.109 | 0.731 | 26.9 |  |
| GBPUSD.DWX | A2 | 1141 | 0.97 | -0.049 | 0.919 | 50.17 | -0.047 | 742 | +0.016 | 1.028 | 29.32 |  |
| GBPUSD.DWX | A3 | 1135 | 0.97 | +0.010 | 1.018 | 34.66 | +0.010 | 729 | -0.025 | 0.955 | 32.83 |  |
| GBPUSD.DWX | A4 | 1112 | 0.95 | +0.040 | 1.075 | 35.7 | +0.038 | 712 | -0.009 | 0.984 | 30.66 |  |
| GBPUSD.DWX | B2 | 917 | 0.78 | +0.033 | 1.059 | 24.53 | +0.025 | 576 | +0.033 | 1.058 | 19.03 |  |
| GBPUSD.DWX | B3 | 841 | 0.72 | +0.056 | 1.106 | 15.71 | +0.040 | 530 | +0.064 | 1.117 | 17.98 | SURVIVOR |
| GBPUSD.DWX | B4 | 790 | 0.67 | +0.045 | 1.087 | 23.14 | +0.031 | 487 | +0.024 | 1.043 | 21.05 |  |
| GBPUSD.DWX | C2 | 864 | 0.74 | -0.011 | 0.975 | 25.55 | -0.008 | 575 | +0.023 | 1.044 | 21.25 |  |
| GBPUSD.DWX | C3 | 668 | 0.57 | -0.021 | 0.95 | 20.57 | -0.012 | 481 | +0.041 | 1.087 | 12.2 |  |
| GBPUSD.DWX | C4 | 464 | 0.39 | -0.016 | 0.958 | 11.25 | -0.006 | 355 | +0.003 | 1.006 | 15.28 |  |
| GDAXI.DWX | A2 | 845 | 0.72 | -0.065 | 0.904 | 57.73 | -0.046 | 685 | -0.157 | 0.78 | 73.14 |  |
| GDAXI.DWX | A3 | 511 | 0.43 | -0.010 | 0.984 | 23.91 | -0.004 | 444 | -0.010 | 0.985 | 27.44 |  |
| GDAXI.DWX | A4 | 0 | | | | | | | | | | no trades |
| GDAXI.DWX | B2 | 748 | 0.64 | -0.066 | 0.892 | 40.18 | -0.042 | 658 | +0.004 | 1.008 | 22.05 |  |
| GDAXI.DWX | B3 | 724 | 0.62 | -0.038 | 0.935 | 33.26 | -0.024 | 626 | +0.027 | 1.05 | 19.33 |  |
| GDAXI.DWX | B4 | 702 | 0.60 | -0.044 | 0.924 | 36.63 | -0.026 | 604 | +0.025 | 1.048 | 22.15 |  |
| GDAXI.DWX | C2 | 1041 | 0.89 | -0.080 | 0.855 | 51.89 | -0.070 | 680 | +0.016 | 1.031 | 24.63 |  |
| GDAXI.DWX | C3 | 925 | 0.79 | -0.029 | 0.936 | 34.39 | -0.023 | 589 | +0.013 | 1.03 | 24.69 |  |
| GDAXI.DWX | C4 | 758 | 0.65 | -0.024 | 0.939 | 26.39 | -0.016 | 446 | -0.013 | 0.968 | 22.53 |  |
| NDX.DWX | A2 | 1084 | 0.92 | -0.116 | 0.807 | 83.63 | -0.107 | 663 | -0.113 | 0.813 | 38.86 |  |
| NDX.DWX | A3 | 1114 | 0.95 | -0.067 | 0.88 | 59.69 | -0.063 | 732 | -0.102 | 0.824 | 47.88 |  |
| NDX.DWX | A4 | 1099 | 0.94 | -0.049 | 0.905 | 36.08 | -0.046 | 737 | -0.056 | 0.9 | 49.51 |  |
| NDX.DWX | B2 | 1135 | 0.97 | -0.103 | 0.848 | 74.6 | -0.100 | 757 | -0.179 | 0.733 | 77.02 |  |
| NDX.DWX | B3 | 1120 | 0.95 | -0.135 | 0.796 | 71.84 | -0.129 | 745 | -0.109 | 0.828 | 55.93 |  |
| NDX.DWX | B4 | 1098 | 0.93 | -0.146 | 0.774 | 66.05 | -0.137 | 734 | -0.128 | 0.794 | 64.24 |  |
| NDX.DWX | C2 | 979 | 0.83 | -0.064 | 0.916 | 78.0 | -0.053 | 622 | -0.013 | 0.982 | 36.71 |  |
| NDX.DWX | C3 | 892 | 0.76 | -0.066 | 0.908 | 67.33 | -0.050 | 546 | +0.022 | 1.031 | 34.94 |  |
| NDX.DWX | C4 | 760 | 0.65 | -0.018 | 0.972 | 48.99 | -0.012 | 447 | +0.062 | 1.093 | 24.54 |  |
| NZDCAD.DWX | A2 | 1092 | 0.93 | -0.016 | 0.968 | 32.49 | -0.015 | 700 | -0.046 | 0.905 | 37.36 |  |
| NZDCAD.DWX | A3 | 1043 | 0.89 | +0.007 | 1.016 | 29.49 | +0.006 | 648 | -0.023 | 0.947 | 30.75 |  |
| NZDCAD.DWX | A4 | 981 | 0.83 | -0.008 | 0.983 | 31.32 | -0.006 | 593 | -0.003 | 0.993 | 24.33 |  |
| NZDCAD.DWX | B2 | 1136 | 0.97 | +0.005 | 1.01 | 26.57 | +0.005 | 731 | -0.106 | 0.801 | 48.81 |  |
| NZDCAD.DWX | B3 | 1103 | 0.94 | +0.015 | 1.031 | 25.37 | +0.014 | 701 | -0.104 | 0.794 | 43.79 |  |
| NZDCAD.DWX | B4 | 1038 | 0.88 | +0.003 | 1.006 | 25.15 | +0.003 | 651 | -0.125 | 0.744 | 37.65 |  |
| NZDCAD.DWX | C2 | 997 | 0.85 | -0.052 | 0.896 | 40.2 | -0.044 | 663 | -0.169 | 0.707 | 78.96 |  |
| NZDCAD.DWX | C3 | 913 | 0.78 | -0.059 | 0.872 | 35.91 | -0.045 | 626 | -0.147 | 0.723 | 67.94 |  |
| NZDCAD.DWX | C4 | 787 | 0.67 | -0.053 | 0.872 | 25.8 | -0.036 | 576 | -0.132 | 0.723 | 55.81 |  |
| NZDCHF.DWX | A2 | 1082 | 0.92 | +0.003 | 1.006 | 24.79 | +0.003 | 697 | +0.002 | 1.005 | 35.56 |  |
| NZDCHF.DWX | A3 | 1000 | 0.85 | -0.031 | 0.937 | 30.35 | -0.026 | 657 | -0.056 | 0.881 | 40.83 |  |
| NZDCHF.DWX | A4 | 929 | 0.79 | -0.048 | 0.899 | 31.37 | -0.038 | 601 | -0.041 | 0.906 | 32.17 |  |
| NZDCHF.DWX | B2 | 1094 | 0.93 | +0.007 | 1.013 | 23.87 | +0.006 | 702 | -0.139 | 0.75 | 46.16 |  |
| NZDCHF.DWX | B3 | 1055 | 0.90 | +0.003 | 1.006 | 24.26 | +0.003 | 684 | -0.134 | 0.745 | 40.22 |  |
| NZDCHF.DWX | B4 | 993 | 0.85 | -0.021 | 0.956 | 26.49 | -0.018 | 647 | -0.124 | 0.747 | 36.67 |  |
| NZDCHF.DWX | C2 | 1071 | 0.91 | -0.152 | 0.698 | 54.11 | -0.138 | 691 | -0.168 | 0.698 | 68.5 |  |
| NZDCHF.DWX | C3 | 961 | 0.82 | -0.143 | 0.682 | 37.47 | -0.117 | 649 | -0.159 | 0.682 | 59.13 |  |
| NZDCHF.DWX | C4 | 783 | 0.67 | -0.111 | 0.722 | 30.38 | -0.074 | 564 | -0.143 | 0.68 | 38.7 |  |
| NZDJPY.DWX | A2 | 1032 | 0.88 | +0.043 | 1.092 | 22.52 | +0.038 | 657 | +0.019 | 1.042 | 18.63 |  |
| NZDJPY.DWX | A3 | 881 | 0.75 | +0.046 | 1.111 | 24.88 | +0.035 | 555 | -0.028 | 0.934 | 23.79 |  |
| NZDJPY.DWX | A4 | 785 | 0.67 | +0.058 | 1.147 | 21.29 | +0.039 | 497 | -0.015 | 0.964 | 17.49 | SEL-pass, VAL fail |
| NZDJPY.DWX | B2 | 1103 | 0.94 | +0.045 | 1.091 | 18.4 | +0.042 | 709 | -0.062 | 0.872 | 32.49 |  |
| NZDJPY.DWX | B3 | 1052 | 0.90 | +0.045 | 1.098 | 19.41 | +0.040 | 662 | -0.057 | 0.872 | 28.84 |  |
| NZDJPY.DWX | B4 | 961 | 0.82 | +0.039 | 1.092 | 18.96 | +0.032 | 594 | -0.066 | 0.843 | 24.04 |  |
| NZDJPY.DWX | C2 | 1121 | 0.95 | -0.070 | 0.862 | 43.81 | -0.067 | 736 | -0.141 | 0.748 | 56.35 |  |
| NZDJPY.DWX | C3 | 1057 | 0.90 | -0.027 | 0.937 | 39.41 | -0.025 | 719 | -0.115 | 0.767 | 43.94 |  |
| NZDJPY.DWX | C4 | 923 | 0.79 | -0.024 | 0.94 | 25.59 | -0.018 | 662 | -0.091 | 0.795 | 33.59 |  |
| NZDUSD.DWX | A2 | 1071 | 0.91 | +0.090 | 1.195 | 20.83 | +0.082 | 675 | -0.049 | 0.9 | 29.44 | SEL-pass, VAL fail |
| NZDUSD.DWX | A3 | 963 | 0.82 | +0.027 | 1.059 | 26.48 | +0.022 | 599 | -0.012 | 0.973 | 32.77 |  |
| NZDUSD.DWX | A4 | 886 | 0.75 | +0.004 | 1.008 | 27.3 | +0.003 | 549 | -0.023 | 0.948 | 32.4 |  |
| NZDUSD.DWX | B2 | 1103 | 0.94 | -0.002 | 0.997 | 38.41 | -0.002 | 707 | -0.049 | 0.906 | 30.79 |  |
| NZDUSD.DWX | B3 | 1050 | 0.89 | -0.030 | 0.942 | 21.32 | -0.027 | 665 | -0.065 | 0.873 | 30.4 |  |
| NZDUSD.DWX | B4 | 953 | 0.81 | -0.023 | 0.954 | 16.6 | -0.018 | 607 | -0.052 | 0.891 | 25.31 |  |
| NZDUSD.DWX | C2 | 997 | 0.85 | -0.026 | 0.949 | 34.23 | -0.022 | 653 | -0.061 | 0.892 | 49.8 |  |
| NZDUSD.DWX | C3 | 930 | 0.79 | -0.019 | 0.959 | 28.03 | -0.015 | 621 | -0.021 | 0.957 | 39.93 |  |
| NZDUSD.DWX | C4 | 802 | 0.68 | -0.028 | 0.935 | 32.64 | -0.019 | 566 | -0.007 | 0.984 | 31.1 |  |
| SP500.DWX | A2 | 1096 | 0.93 | -0.712 | 0.311 | 241.99 | -0.664 | 634 | -0.772 | 0.296 | 202.95 |  |
| SP500.DWX | A3 | 1106 | 0.94 | -0.539 | 0.371 | 187.11 | -0.508 | 714 | -0.624 | 0.349 | 176.35 |  |
| SP500.DWX | A4 | 1088 | 0.93 | -0.477 | 0.394 | 149.56 | -0.442 | 726 | -0.551 | 0.373 | 155.33 |  |
| SP500.DWX | B2 | 1128 | 0.96 | -0.778 | 0.323 | 318.79 | -0.747 | 745 | -0.714 | 0.348 | 213.27 |  |
| SP500.DWX | B3 | 1118 | 0.95 | -0.719 | 0.333 | 285.62 | -0.684 | 740 | -0.650 | 0.362 | 206.07 |  |
| SP500.DWX | B4 | 1096 | 0.93 | -0.649 | 0.355 | 253.73 | -0.605 | 736 | -0.633 | 0.349 | 198.4 |  |
| SP500.DWX | C2 | 977 | 0.83 | -0.643 | 0.416 | 195.9 | -0.534 | 608 | -0.496 | 0.539 | 145.53 |  |
| SP500.DWX | C3 | 887 | 0.75 | -0.523 | 0.465 | 153.39 | -0.395 | 535 | -0.410 | 0.584 | 104.38 |  |
| SP500.DWX | C4 | 757 | 0.64 | -0.428 | 0.508 | 109.52 | -0.276 | 421 | -0.345 | 0.621 | 72.42 |  |
| UK100.DWX | A2 | 1093 | 0.93 | -0.169 | 0.767 | 77.97 | -0.157 | 736 | -0.267 | 0.668 | 109.66 |  |
| UK100.DWX | A3 | 1043 | 0.89 | -0.130 | 0.791 | 61.78 | -0.116 | 719 | -0.181 | 0.74 | 91.38 |  |
| UK100.DWX | A4 | 983 | 0.84 | -0.128 | 0.782 | 60.06 | -0.107 | 686 | -0.187 | 0.721 | 89.72 |  |
| UK100.DWX | B2 | 1030 | 0.88 | -0.177 | 0.751 | 77.41 | -0.155 | 604 | -0.266 | 0.653 | 76.78 |  |
| UK100.DWX | B3 | 996 | 0.85 | -0.177 | 0.745 | 72.77 | -0.150 | 571 | -0.262 | 0.649 | 68.71 |  |
| UK100.DWX | B4 | 953 | 0.81 | -0.169 | 0.747 | 70.79 | -0.137 | 554 | -0.257 | 0.645 | 76.76 |  |
| UK100.DWX | C2 | 1041 | 0.89 | -0.144 | 0.744 | 66.96 | -0.128 | 681 | -0.252 | 0.614 | 66.33 |  |
| UK100.DWX | C3 | 909 | 0.77 | -0.139 | 0.719 | 48.17 | -0.107 | 599 | -0.200 | 0.641 | 52.69 |  |
| UK100.DWX | C4 | 711 | 0.61 | -0.126 | 0.712 | 35.3 | -0.076 | 450 | -0.203 | 0.614 | 43.22 |  |
| USDCAD.DWX | A2 | 1142 | 0.97 | -0.079 | 0.86 | 69.81 | -0.076 | 736 | -0.168 | 0.719 | 60.13 |  |
| USDCAD.DWX | A3 | 1135 | 0.97 | -0.077 | 0.853 | 55.8 | -0.074 | 724 | -0.159 | 0.725 | 46.84 |  |
| USDCAD.DWX | A4 | 1107 | 0.94 | -0.086 | 0.832 | 52.39 | -0.081 | 721 | -0.143 | 0.746 | 47.0 |  |
| USDCAD.DWX | B2 | 1105 | 0.94 | -0.040 | 0.932 | 40.04 | -0.037 | 724 | -0.050 | 0.913 | 28.83 |  |
| USDCAD.DWX | B3 | 1053 | 0.90 | -0.064 | 0.886 | 37.45 | -0.058 | 696 | -0.047 | 0.915 | 29.45 |  |
| USDCAD.DWX | B4 | 998 | 0.85 | -0.057 | 0.895 | 37.01 | -0.049 | 670 | -0.043 | 0.921 | 31.07 |  |
| USDCAD.DWX | C2 | 844 | 0.72 | -0.009 | 0.983 | 25.92 | -0.007 | 542 | +0.043 | 1.083 | 19.91 |  |
| USDCAD.DWX | C3 | 736 | 0.63 | -0.011 | 0.977 | 25.27 | -0.007 | 480 | +0.075 | 1.157 | 13.41 |  |
| USDCAD.DWX | C4 | 600 | 0.51 | +0.043 | 1.093 | 18.63 | +0.022 | 401 | +0.059 | 1.129 | 14.55 |  |
| USDCHF.DWX | A2 | 1137 | 0.97 | -0.028 | 0.955 | 39.55 | -0.027 | 740 | -0.037 | 0.934 | 53.03 |  |
| USDCHF.DWX | A3 | 1136 | 0.97 | -0.029 | 0.95 | 45.73 | -0.028 | 730 | -0.042 | 0.924 | 54.43 |  |
| USDCHF.DWX | A4 | 1111 | 0.95 | -0.059 | 0.897 | 44.42 | -0.056 | 713 | -0.071 | 0.869 | 59.88 |  |
| USDCHF.DWX | B2 | 1002 | 0.85 | +0.045 | 1.078 | 28.02 | +0.038 | 625 | -0.019 | 0.967 | 44.63 |  |
| USDCHF.DWX | B3 | 953 | 0.81 | +0.030 | 1.053 | 29.84 | +0.024 | 588 | +0.012 | 1.021 | 37.42 |  |
| USDCHF.DWX | B4 | 893 | 0.76 | +0.036 | 1.067 | 21.91 | +0.028 | 555 | -0.036 | 0.934 | 37.63 |  |
| USDCHF.DWX | C2 | 889 | 0.76 | +0.028 | 1.059 | 23.22 | +0.021 | 568 | -0.076 | 0.858 | 43.25 |  |
| USDCHF.DWX | C3 | 716 | 0.61 | +0.002 | 1.005 | 24.55 | +0.001 | 482 | -0.018 | 0.961 | 27.46 |  |
| USDCHF.DWX | C4 | 489 | 0.42 | -0.023 | 0.946 | 18.51 | -0.010 | 366 | -0.022 | 0.95 | 15.94 |  |
| USDJPY.DWX | A2 | 1072 | 0.91 | +0.095 | 1.201 | 24.27 | +0.087 | 685 | +0.087 | 1.186 | 16.27 | SURVIVOR |
| USDJPY.DWX | A3 | 904 | 0.77 | +0.070 | 1.167 | 19.94 | +0.054 | 577 | +0.104 | 1.242 | 19.34 | SURVIVOR |
| USDJPY.DWX | A4 | 831 | 0.71 | +0.083 | 1.205 | 16.64 | +0.059 | 515 | +0.131 | 1.319 | 15.12 | SURVIVOR |
| USDJPY.DWX | B2 | 1086 | 0.92 | +0.096 | 1.181 | 28.4 | +0.088 | 668 | -0.001 | 0.999 | 29.29 |  |
| USDJPY.DWX | B3 | 1017 | 0.87 | +0.124 | 1.248 | 20.47 | +0.107 | 613 | +0.064 | 1.128 | 19.26 | SURVIVOR |
| USDJPY.DWX | B4 | 944 | 0.80 | +0.110 | 1.23 | 19.11 | +0.088 | 549 | +0.047 | 1.097 | 23.34 | SURVIVOR |
| USDJPY.DWX | C2 | 998 | 0.85 | +0.141 | 1.302 | 20.83 | +0.120 | 632 | +0.144 | 1.295 | 25.04 | SURVIVOR |
| USDJPY.DWX | C3 | 926 | 0.79 | +0.123 | 1.288 | 20.65 | +0.097 | 596 | +0.141 | 1.319 | 22.2 | SURVIVOR |
| USDJPY.DWX | C4 | 818 | 0.70 | +0.085 | 1.213 | 23.24 | +0.059 | 538 | +0.090 | 1.215 | 19.88 | SURVIVOR |
| WS30.DWX | A2 | 1102 | 0.94 | -0.846 | 0.263 | 266.03 | -0.793 | 561 | -1.175 | 0.175 | 271.9 |  |
| WS30.DWX | A3 | 1117 | 0.95 | -0.643 | 0.32 | 206.2 | -0.611 | 694 | -1.017 | 0.212 | 292.61 |  |
| WS30.DWX | A4 | 1094 | 0.93 | -0.557 | 0.348 | 172.28 | -0.519 | 730 | -0.874 | 0.246 | 266.97 |  |
| WS30.DWX | B2 | 1135 | 0.97 | -0.872 | 0.299 | 321.49 | -0.843 | 749 | -1.088 | 0.233 | 313.03 |  |
| WS30.DWX | B3 | 1121 | 0.95 | -0.792 | 0.309 | 288.21 | -0.755 | 748 | -0.979 | 0.257 | 289.18 |  |
| WS30.DWX | B4 | 1098 | 0.93 | -0.722 | 0.326 | 264.56 | -0.675 | 745 | -0.946 | 0.25 | 281.03 |  |
| WS30.DWX | C2 | 983 | 0.84 | -0.694 | 0.395 | 225.42 | -0.581 | 580 | -0.722 | 0.431 | 178.79 |  |
| WS30.DWX | C3 | 891 | 0.76 | -0.638 | 0.385 | 185.44 | -0.484 | 487 | -0.656 | 0.439 | 136.79 |  |
| WS30.DWX | C4 | 746 | 0.63 | -0.555 | 0.405 | 127.0 | -0.352 | 374 | -0.621 | 0.44 | 100.32 |  |
| XAGUSD.DWX | A2 | 1082 | 0.92 | +0.065 | 1.137 | 45.22 | +0.059 | 708 | -0.003 | 0.993 | 45.22 |  |
| XAGUSD.DWX | A3 | 1051 | 0.89 | +0.019 | 1.041 | 40.17 | +0.017 | 687 | -0.019 | 0.959 | 47.5 |  |
| XAGUSD.DWX | A4 | 1015 | 0.86 | +0.008 | 1.017 | 37.19 | +0.007 | 667 | -0.027 | 0.941 | 48.97 |  |
| XAGUSD.DWX | B2 | 1010 | 0.86 | -0.015 | 0.971 | 38.15 | -0.013 | 688 | +0.009 | 1.017 | 28.43 |  |
| XAGUSD.DWX | B3 | 940 | 0.80 | +0.007 | 1.014 | 27.73 | +0.005 | 645 | -0.015 | 0.971 | 36.49 |  |
| XAGUSD.DWX | B4 | 890 | 0.76 | -0.014 | 0.971 | 35.38 | -0.011 | 583 | -0.006 | 0.987 | 30.52 |  |
| XAGUSD.DWX | C2 | 866 | 0.74 | -0.014 | 0.973 | 34.42 | -0.010 | 622 | +0.086 | 1.154 | 20.7 |  |
| XAGUSD.DWX | C3 | 775 | 0.66 | -0.019 | 0.959 | 30.32 | -0.013 | 576 | +0.038 | 1.071 | 22.34 |  |
| XAGUSD.DWX | C4 | 671 | 0.57 | -0.015 | 0.965 | 28.04 | -0.009 | 518 | +0.001 | 1.003 | 25.85 |  |
| XAUUSD.DWX | A2 | 1119 | 0.95 | +0.040 | 1.078 | 31.61 | +0.038 | 729 | +0.097 | 1.214 | 30.08 |  |
| XAUUSD.DWX | A3 | 1096 | 0.93 | +0.046 | 1.097 | 28.14 | +0.043 | 693 | +0.076 | 1.174 | 23.15 |  |
| XAUUSD.DWX | A4 | 1064 | 0.91 | +0.031 | 1.066 | 26.98 | +0.028 | 665 | +0.074 | 1.171 | 19.42 |  |
| XAUUSD.DWX | B2 | 1049 | 0.89 | +0.015 | 1.029 | 34.08 | +0.014 | 702 | +0.030 | 1.059 | 24.81 |  |
| XAUUSD.DWX | B3 | 983 | 0.84 | +0.051 | 1.1 | 24.13 | +0.043 | 658 | -0.013 | 0.974 | 34.83 | SEL-pass, VAL fail |
| XAUUSD.DWX | B4 | 914 | 0.78 | +0.054 | 1.111 | 20.94 | +0.042 | 605 | -0.004 | 0.991 | 38.2 | SEL-pass, VAL fail |
| XAUUSD.DWX | C2 | 895 | 0.76 | -0.000 | 1.0 | 40.02 | -0.000 | 613 | +0.167 | 1.331 | 28.8 |  |
| XAUUSD.DWX | C3 | 811 | 0.69 | -0.025 | 0.949 | 32.73 | -0.017 | 552 | +0.150 | 1.309 | 22.18 |  |
| XAUUSD.DWX | C4 | 675 | 0.57 | -0.018 | 0.962 | 31.62 | -0.010 | 494 | +0.120 | 1.266 | 20.81 |  |

### Per-symbol summary (best SEL cell by E[R], its VAL)

| symbol | best cell | SEL E[R] | PF | VAL E[R] | PF | cells SEL>0 / 9 |
|---|---|---|---|---|---|---|
| AUDCAD.DWX | A3 | +0.002 | 1.005 | -0.048 | 0.892 | 1 / 9 |
| AUDCHF.DWX | B2 | +0.057 | 1.114 | -0.089 | 0.83 | 4 / 9 |
| AUDJPY.DWX | B2 | +0.089 | 1.193 | +0.035 | 1.073 | 6 / 9 |
| AUDNZD.DWX | B4 | -0.011 | 0.975 | -0.185 | 0.594 | 0 / 9 |
| AUDUSD.DWX | C2 | +0.045 | 1.09 | -0.013 | 0.975 | 9 / 9 |
| CADCHF.DWX | B4 | +0.004 | 1.008 | -0.136 | 0.767 | 1 / 9 |
| CADJPY.DWX | A2 | +0.122 | 1.243 | +0.030 | 1.063 | 8 / 9 |
| CHFJPY.DWX | B2 | -0.010 | 0.982 | -0.060 | 0.886 | 0 / 9 |
| EURAUD.DWX | A2 | +0.135 | 1.298 | -0.064 | 0.87 | 6 / 9 |
| EURCAD.DWX | C4 | -0.008 | 0.982 | -0.028 | 0.939 | 0 / 9 |
| EURCHF.DWX | B4 | -0.002 | 0.997 | -0.096 | 0.835 | 0 / 9 |
| EURGBP.DWX | B2 | +0.094 | 1.165 | -0.129 | 0.778 | 3 / 9 |
| EURJPY.DWX | C4 | +0.046 | 1.135 | +0.040 | 1.113 | 8 / 9 |
| EURNZD.DWX | A2 | +0.047 | 1.098 | +0.013 | 1.028 | 6 / 9 |
| EURUSD.DWX | C4 | +0.085 | 1.218 | +0.082 | 1.18 | 3 / 9 |
| GBPAUD.DWX | B3 | +0.025 | 1.051 | -0.030 | 0.938 | 5 / 9 |
| GBPCAD.DWX | B2 | +0.027 | 1.048 | -0.174 | 0.729 | 3 / 9 |
| GBPCHF.DWX | B3 | +0.088 | 1.159 | -0.129 | 0.782 | 3 / 9 |
| GBPJPY.DWX | B4 | +0.119 | 1.24 | -0.003 | 0.995 | 5 / 9 |
| GBPNZD.DWX | A2 | -0.028 | 0.948 | +0.029 | 1.062 | 0 / 9 |
| GBPUSD.DWX | B3 | +0.056 | 1.106 | +0.064 | 1.117 | 5 / 9 |
| GDAXI.DWX | A3 | -0.010 | 0.984 | -0.010 | 0.985 | 0 / 8 |
| NDX.DWX | C4 | -0.018 | 0.972 | +0.062 | 1.093 | 0 / 9 |
| NZDCAD.DWX | B3 | +0.015 | 1.031 | -0.104 | 0.794 | 4 / 9 |
| NZDCHF.DWX | B2 | +0.007 | 1.013 | -0.139 | 0.75 | 3 / 9 |
| NZDJPY.DWX | A4 | +0.058 | 1.147 | -0.015 | 0.964 | 6 / 9 |
| NZDUSD.DWX | A2 | +0.090 | 1.195 | -0.049 | 0.9 | 3 / 9 |
| SP500.DWX | C4 | -0.428 | 0.508 | -0.345 | 0.621 | 0 / 9 |
| UK100.DWX | C4 | -0.126 | 0.712 | -0.203 | 0.614 | 0 / 9 |
| USDCAD.DWX | C4 | +0.043 | 1.093 | +0.059 | 1.129 | 1 / 9 |
| USDCHF.DWX | B2 | +0.045 | 1.078 | -0.019 | 0.967 | 5 / 9 |
| USDJPY.DWX | C2 | +0.141 | 1.302 | +0.144 | 1.295 | 9 / 9 |
| WS30.DWX | C4 | -0.555 | 0.405 | -0.621 | 0.44 | 0 / 9 |
| XAGUSD.DWX | A2 | +0.065 | 1.137 | -0.003 | 0.993 | 4 / 9 |
| XAUUSD.DWX | B4 | +0.054 | 1.111 | -0.004 | 0.991 | 6 / 9 |
