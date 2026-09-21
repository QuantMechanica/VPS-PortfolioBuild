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
