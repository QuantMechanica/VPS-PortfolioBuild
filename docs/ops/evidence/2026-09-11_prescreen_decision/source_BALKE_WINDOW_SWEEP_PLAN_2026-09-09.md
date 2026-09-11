# Balke USDJPY range-window sweep — pre-registered plan (2026-09-09)

Author: Claude (Orchestrator). OWNER instruction 2026-09-09 ~21:45Z: "Am sinnvollsten wird es wohl
sein, wenn du mittels Backtests auf unseren Daten selbst die beste Range herausfindest! Überlege einen
Plan wie das funktionieren könnte und mach dann die Umsetzung!"

This document is the **pre-registration**. Grid, metric, split, admissibility, plateau rule and
refutation criterion are fixed here BEFORE any cell runs; the commit hash of this file is bound into
the program declaration. Changing any of them after cells have run is a new program, not an edit.
Standing authorization: GELB "new Q14 lever" (hypothesis, refutation criterion, frequency check,
parameter count — all four below). No gate threshold, verdict or card universe is touched.

## 1. Instrument and clock

- EA: `QM5_41398_balke-pattern-repair-opt` (binary unchanged, inputs only: `strategy_range_start_hour`,
  `strategy_range_end_hour`, `strategy_exit_hour`). Pattern slots `opt_pp_*` stay 0 (no filter).
  ATR band, trailing, news, Friday close, sizing exactly as the DL-089 baseline setfile
  `…/DL089_QM5_13213_USDJPY_DWX_2019_2025/setfiles/…_opt_census_2019_baseline.set`.
- Clock: the EA's fixed **UTC+3** clock (hour h ⇒ h−3 UTC, all year). Range = closed H1 bars with
  hour in [start, end), straddle placed during hour `end`, flat at `exit`. Broker-DST and CET
  clock variants, minute-granular ranges, buffers and the outside-range rule are NOT part of this
  sweep; they belong to Astra `d444a7a8` and will be run on the winning window only.
- Symbol/TF/data: `USDJPY.DWX` H1, Model 4 real ticks, years 2019..2025 as separate cells (same
  per-year cell contract, worker, evidence schema and commission group as the DL-089 census, so
  the numbers are directly comparable with the running pattern census).

## 2. Hypothesis (H-WIN) and refutation criterion

H-WIN: on our own .DWX data there is a range window whose out-of-sample economics beat the
inherited 03:00–06:00 window by more than grid noise.

Refutation (H-WIN is rejected, 03–06 stays): the winner's **plateau DEV score is not ≥ 1.10 × the
03–06 DEV score**, OR the winner fails the OOS confirmation in §5. In that case the sweep is reported
as "no better window found" and the surface is kept as evidence — no re-selection, no grid change.

## 3. Grid, parameter count, trial count

Stage A (exit fixed at 18): `start ∈ {0..9}`, `length ∈ {2..8}` h, `end = start+length ≤ 13`
→ **60 windows** (includes 03–06 = start 3 / length 3 as the baseline cell).
Stage B (exit sweep): for the **top-5 plateau windows** of stage A, `exit ∈ {15,16,17,19,20,21}`
→ **30 windows**. Stage B is enqueued only after stage A is fully measured.

Parameters: 3 (start, length, exit). **Declared trial count: 90 windows** (= 630 per-year cells).
Cost: 630 cells ≈ 8–9 h of fleet time at the current 70–80 census cells/h (>1 h ⇒ reported here
per GELB). The running 1,085-cell pattern census on the 03–06 window keeps running; its result is
provisional until the window is settled and will be re-planned on the winner if H-WIN survives.

## 4. Per-cell measurement and admissibility

From each per-year cell's `summary.json` (`runs[0]`): `net_profit`, `profit_factor`, `drawdown`,
`total_trades`, plus the tester report for **distinct entry days** and per-trade volume.
Score per window-year: `return_to_maxdd = net_profit / max(drawdown, 1)` — the same success
measure the sealed DL-089 rule uses, so the two programs stay comparable. Costed variant:
net − 5 USD/lot round-trip (DXZ venue truth) from the report volumes; both gross and costed are
reported, **selection uses the costed score**.

Admissibility (checked before any score is looked at; one breach ⇒ window inadmissible):
- ≥ 10 distinct entry days in EVERY year 2019..2025 (Aktivitätskriterium, OWNER 2026-08-20);
- ≥ 5 trades in every year (Q02 economics floor) and ≥ 40 trades/yr on average (a 3–8 h
  straddle should fire most days; far fewer means the window is degenerate);
- all 7 year-cells `MEASURED` (INFRA/timeout cells are re-run append-only, never scored as 0).

## 5. Selection rule (plateau, walk-forward)

- DEV years = 2019, 2020, 2021, 2022. OOS years = 2023, 2024, 2025.
- Window DEV score = **median** over DEV years of the costed return_to_maxdd.
- Plateau score = **median of the DEV scores over the window's grid neighbourhood**
  {start ±1} × {length ±1} (valid grid points only, the window itself included). Choosing the
  plateau centre instead of the single best cell is the anti-overfitting device.
- Winner = admissible window with the highest plateau score (ties → shorter length, then earlier
  start).
- OOS confirmation (evaluated once, on the winner only): winner OOS median costed
  return_to_maxdd ≥ the 03–06 window's OOS median, AND winner OOS pooled costed PF ≥ 1.00.
- Stage B repeats the same rule over the exit axis for the top-5 stage-A windows; the final
  configuration is the stage-B winner (or the stage-A winner with exit 18 if no exit beats it by the
  same 1.10 margin).

## 6. Execution mechanics

- Program id `WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025`, artifacts under
  `D:\QM\strategy_farm\artifacts\opt_census\WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025\`
  (`declaration.json` with this file's commit hash + grid + rule text + sha256s, `setfiles/`,
  `ledger.json`, `cell_receipts/`).
- Cells are ordinary `OPT_CENSUS` work items (deterministic UUIDs from program id + cell key
  `WINSWEEP…:<year>:s<start>_l<length>_x<exit>`), so the existing worker, custom-history
  isolation, per-year contract, evidence schema and retention apply unchanged. Stage A rows get
  the frontier priority of the running pattern census so the two programs interleave; nothing is
  deleted or re-prioritised downward.
- Tool: `tools/strategy_farm/window_sweep.py` with `plan | enqueue --stage A|B | report`
  (Codex ticket, see OPEN_ITEMS). `report` writes the surface CSV and this plan's tables.
- Selection and reporting: Claude (this plan's rule, executed by the tool, adjudicated by me).

## 7. Outputs and follow-ups

- `docs/research/BALKE_WINDOW_SWEEP_RESULT_2026-09-XX.md` + `docs/ops/evidence/…_window_sweep_surface.csv`
  (all 90 windows × 7 years, gross and costed, admissibility flags, plateau scores).
- If H-WIN survives: (a) Astra `d444a7a8` runs clock modes / buffer / outside-range rule /
  minute-granular Balke config on the winner only; (b) the DL-089 pattern census for 41398 is
  re-planned on the winner as a new sibling instrument; (c) a fresh Q02→Q10 chain for the final
  configuration — never by overwriting 41398.
- If refuted: 03–06 stays; the surface still tells us how flat/fragile the window landscape is.

## Not claimed

No economic result yet. Nothing here changes a gate, a verdict, the DL-089 sealed rule, or the
counter. The sweep is a measurement program on an existing measurement instrument.
