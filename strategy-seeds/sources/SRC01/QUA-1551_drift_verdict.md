# QUA-1551 — P2 strategy-drift verdict: QM5_1004 (davey-es-breakout)

> Author: Research Agent (`7aef7a17`) — 2026-05-15
> Triggering issue: [QUA-1551](/QUA/issues/QUA-1551) (child of [QUA-1548](/QUA/issues/QUA-1548) → [QUA-1546](/QUA/issues/QUA-1546))
> Card under review: [`strategy-seeds/cards/davey-es-breakout_card.md`](../../cards/davey-es-breakout_card.md) — strategy_id `SRC01_S04`, ea_id `QM5_1004`
> Evidence:
> - `docs/ops/evidence/2026-05-15_zero_trades_p2_baseline_verdicts.csv` (row `QM5_1004,AUDNZD.DWX,P2,0,1,STRATEGY_DRIFT:QUA-1551`)
> - `D:/QM/reports/pipeline/QM5_1004/P2/p2_QM5_1004_result.json` (PASS=0, FAIL=8, INVALID=29)
> - `D:/QM/reports/pipeline/QM5_1004/P2/report.csv` (per-symbol MIN_TRADES_NOT_MET across 37 symbols)

## Verdict

**STRATEGY_DRIFT** — confirmed. Sub-class: **symbol-universe drift**, NOT parameter drift and NOT BASELINE_ACCURATE_FAILED.

## Reasoning

The Davey ES countertrend "breakout" strategy is calibrated by the source author on a single instrument: CME mini S&P 500 continuous futures (@ES) on **daily bars** (Davey, *Building Algorithmic Trading Systems*, Ch 13 p. 117 verbatim: "We will use daily bars"). The card's § 3 fixes the V5 Darwinex deployment surface to one CFD proxy:

```yaml
primary_target_symbols:
  - "@ES (mini S&P continuous futures, CME) — Davey's deployment"
  - "US500.DWX — V5 Darwinex CFD proxy (proposed; CTO confirms tick-size + contract-size mapping)"
```

The P2 dispatcher for `QM5_1004` fanned out the SAME set-file (X=9, Y=5, Z=$600 — Davey's full-period optimum from p. 117) across 37 Darwinex symbols including FX majors (AUDNZD, AUDCAD, EURUSD, GBPUSD, USDJPY, USDCAD, NZDUSD, USDCHF, EURJPY, GBPJPY, EURGBP, EURAUD, GBPAUD, NZDCAD, CHFJPY, CADCHF, CADJPY, EURCAD, EURCHF, EURNZD, ...), metals (XAUUSD, XAGUSD), and other equity-index CFDs (NDXm, UK100). The card never authorised this universe. The parameters in particular are intrinsically equity-index-scaled — Z=$600 stop ≈ 12 S&P points, derived from ES tick value $12.50/0.25; reusing that on AUDNZD or EURUSD does not produce a sensibly-sized stop and the entry trigger (close = highest(close, 9)) interacts with very different volatility regimes.

The 0-trade outcome on AUDNZD.DWX (and the bulk MIN_TRADES_NOT_MET across the fanout) is therefore consistent with two compounding factors, neither of which falsifies the strategy hypothesis at the author's level:

1. **Symbol-universe drift** (primary): the EA was loaded onto symbols whose price-scale and bar geometry weren't part of the card's calibration. On a low-vol cross like AUDNZD over 6 months, fresh 9-day-high closes occur a handful of times, and on the wrong stop scale the position-flip mechanic plus 1-trade minimum can yield zero qualifying trades inside the H1 (first-half) window.
2. **Expected-low-frequency on the right symbol**: even on US500.DWX, this is a daily-bar strategy with author-reported ~5–10 trades/year (Davey Table 13.1, p. 118). A 6-month window can plausibly produce <1 valid trade on a calm sub-period.

The card's § 16 (entries dated 2026-04-27) anticipates this outcome explicitly — Davey shows cumulative OOS 2005–2010 = -$9,938 (Ch 13 p. 118) and frames the strategy as a walk-forward failure example; the card is preserved per OWNER Rule 1 as the "expected fail" calibration specimen for the V5 pipeline.

## Corrective card delta (sub-gate-conformant)

No EA code edits and no parameter-set-file changes (X, Y, Z remain at Davey's p. 117 optimum: 9, 5, 600). Only the **P2 dispatch symbol universe** is corrected to honor the card:

```yaml
qm5_1004_p2_symbol_universe:
  primary: ["US500.DWX"]
  secondary: []   # NDXm.DWX / UK100.DWX are NOT approved proxies — different indices, different vol regimes
  excluded: ["all FX majors/minors", "metals", "non-US equity indices", "crypto"]
```

Also recommended for the re-dispatch (still sub-gate-conformant):

- **Window**: full calendar 2024 (1 year), not just H1. Reason: author's reported trade frequency on @ES is ~5–10/year, so a 6-month window has a non-trivial probability of producing <1 trade for legitimate reasons.
- **Timeframe**: D1 explicit (Davey p. 117 "We will use daily bars"). If the EA chart timeframe is currently anything other than D1, that itself is a build-side drift to flag back to Development on a separate issue (NOT in scope for QUA-1551).

## Decision branches for re-dispatch outcome

| US500.DWX, full 2024, D1 | Verdict path |
|---|---|
| ≥ 1 trade and ≤ ~15 trades, cum P&L flat-to-negative | **CARD HYPOTHESIS REPRODUCED**: Davey's -$9,938 OOS outcome is reproduced in spirit; the V5 P2 baseline gate kills it cleanly per § 6 / § 16 calibration prior. Retire strategy (mark `cancelled` at P2). The "expected fail" specimen has discharged its purpose. |
| ≥ 1 trade, cum P&L surprisingly positive | Edge-case reproduction; advance to P3 sweep per normal V5 pipeline. Card's § 8 sweep ranges apply (re-derive on US500.DWX data). |
| 0 trades over full 2024 D1 on US500.DWX | **BASELINE_ACCURATE_FAILED** with build-side suspicion. Author's data implies ~5–10 trades/year; zero trades on a year of D1 US500 would indicate a build defect (timeframe binding, symbol filter, EA mode mismatch). Open a separate Dev issue for build inspection. Card is NOT falsified by this outcome. |
| Run fails for non-strategy reasons (REPORT_MISSING, METATESTER_HUNG, NO_REAL_TICKS_MARKER) | Pipeline-Operator / Dev infrastructure issue; not Research's verdict surface. |

## Out-of-scope

- No EA code edits in this verdict (per QUA-1551 description).
- No parameter set-file recalibration (X/Y/Z unchanged from author's p. 117 optimum).
- No strategy-card hypothesis change — the hypothesis is unchanged and aligns with author's own framing.

## Next action owner

**Zero-Trades-Specialist** (`8ba981d2-a750-4566-9681-e237fa66261f`): apply the symbol-universe restriction at P2 dispatch for `QM5_1004` and re-run.
