# Hyonix Legacy Mining — 2026-08-13

**Provenance:** OWNER pointed to `C:\Users\Administrator\Dropbox\Hyonix` (pre-QuantMechanica
strategy work, 2,557 files: 281 MQ5, 273 sets, 123 tester HTMLs, 215 ONNX). Four parallel
read-only analysis agents (inventory / breakout lineage / density triage / evidence harvest),
session c0f49ed8. Nothing in the folder was modified.

## Verdict summary

| Asset | Verdict | Action |
|---|---|---|
| MeanReversion base (`Breakout2/MeanReversion/ModularEA.mq5`) | **DENSITY_CANDIDATE** | Card dispatched (see below) |
| `OrderDistance` entry-offset lever (10% of range + edge veto) | **PORT LEVER** | Q14 wave-2 input for QM5_13213/13301; native in future range ports |
| Pattern-filter A/B evidence (vers38 ON: PF 1.36/DD 9.78% vs QuantRangePRO OFF: PF 1.26/DD 20.66%, same params, 5.5y AUDUSD) | **EVIDENCE** | Raises priority of the sanctioned compiled pattern-profile port (survivor program §5) |
| `DailyRangeBreakout_1.mq5` (OWNER-authored) | DXZ_CANDIDATE (parked) | Range-breakout family already saturated; revisit as WS-1 carrier variant |
| SL-%/TP-%/direction-filter/window-duration levers | Q08 search dimensions | Note for future range-breakout gate runs |
| Pyramiding, fade mode (WITH=false), profit-lock SL | **DO-NOT-PORT** | OWNER's own tuned sets: 0/~80 enabled — optimization discarded them |
| PrecisionBullet / QuantPrecisionBullet | REJECT | ICT Silver Bullet class (twice retired); M1 stops die on DWX cost; top PFs are a 2025.01–07 in-sample window only |
| RapidFireScalper, Cowabunga, 3EMA, OneTradeSetup | REJECT | Templates without structural cause; 3EMA short side is dead code (buggy) |
| NewSMC5 "PF 45" XAUUSD | INVALID | Look-ahead/repaint artifact — never cite |
| ICT/SMC/Wyckoff/LiquiditySweep contingent + 215 ONNX (weeks 1–6 ML) | KILL-LIST | ML branch self-invalidated in `Transfer.txt` (95/212 features filled, corrupt scalers) |
| 5-portfolio FTMO fleet (`FTMO-ready/`) | UNVERIFIED | Metrics exist only in markdown; no tester reports in tree |

## Key findings

1. **Convergence validation:** across 50+ iterations (v1→v52 + QuantRangePRO fork) the OWNER's
   tuned production sets converged on exactly the live Balke core: WITH-breakout, SL=100% of
   range, TP off, no pyramiding, no trailing in finals, EOD flat, pattern permission ON,
   minute-precise per-symbol windows (`XAUUSD_Rene` 03:05–06:05 ≙ our Balke gold window).
   The ONE production lever we lack is `OrderDistance` (present in 100% of tuned sets).
2. **Evidence hierarchy:** TimeRangeBreakout vers38 is the only family with multi-year
   backtests (PF 1.4–1.84, 500–2500 trades, DD 3–10%, 2020–2025) AND live deployment.
   Everything shinier is short-window or artifact.
3. **Live reality check (OWNER's 2025 prop year, from `Forex 2025.xlsx` + statements):**
   gross +€374.57, costs €1,191.61, net **−€817**; FTMO Challenge Swing failed (PF 0.79),
   FundedNext ~breakeven-negative (PF 0.94), $200k free trial blown in one week (−$20k);
   single success: FTMO 10k passed 2025-07-17, one payout +€285.57. The best backtested
   engine went net-negative live — the execution/overfit gap the QM 14-gate pipeline exists
   to close. This history is the strongest internal argument for gate discipline.
4. **MeanReversion density candidate:** BB(20,2.0) reversion gated on ADX(14)<30, RSI-extreme
   confluence, M15 closed-bar, SL 2.5×StdDev, RR 2.0 partial-TP; est. 150–350 trades/yr;
   target sizes (25–70 pips) clear DWX spread-inclusive costs. No ML (in-folder
   `HiddenMarkovFilter.mqh` is NOT #included — verified). No multi-year evidence in tree →
   must earn everything in Q02+.

## Dispatches

- research_strategy card ticket: MR density candidate (see router; OWNER provenance,
  mechanism refs `MeanReversionStrategy.mqh:455-570`, `ModularEA.mq5:431-455`).
- OrderDistance lever + Q08 dims + pattern-profile evidence recorded for survivor-program
  wave 2 (Q14 cohort freeze respected — no wave-1 change).
- Agent briefs preserved in session task outputs; parser artifacts in session scratchpad.
