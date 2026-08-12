# FTMO Phase-1 Monte-Carlo harness — method + data provenance (2026-07-20)

Support artifact for the 26.07 FTMO demo-book decision (tasks #13/#38).
Harness: `tools/strategy_farm/portfolio/ftmo_p1_mc.py`.
Run output: `D:\QM\reports\portfolio\ftmo_p1_mc_20260720\` (`results.json` + `summary.md`).
Label: **backtest-derived, gross-of-slippage**. No terminal/tester runs — pure Python
over existing factory evidence artifacts.

## Question answered

For candidate FTMO Phase-1 book compositions (100k account): how fast does the book
reach the +10% target, and how often does it die on the −5% daily-loss or −10%
total-loss rule, within 90 trading days?

## Data sources (all READ-ONLY)

Per-EA×symbol closed-trade streams (Q08 JSONL, `TRADE_CLOSED` events carrying
`profit`, `swap`, `commission` (close-side), `volume`, `notional`, `entry_time`,
`time`). Located via the consolidated metrics DB
(`tools/strategy_farm/ea_metrics.py query`, backing store
`D:\QM\strategy_farm\state\farm_state.sqlite`) which resolves each (EA, symbol, gate)
row to its `D:\QM\reports\work_items\...` evidence path; the trade-level artifacts
themselves are the Q08 stream JSONLs. Where a SHA-pinned frozen copy exists in the
sealed DXZ-24 weekend bundle it is preferred; otherwise the current
`Common\Files\QM\q08_trades` export is used and its SHA256 recorded at runtime.

| Sleeve | Stream artifact | Basis | Trades | Span |
|---|---|---|---|---|
| 12969 USDJPY gotobi (motor) | `D:\QM\reports\portfolio\dxz24_weekend_frozen_20260717\QM\q08_trades\12969_USDJPY_DWX.jsonl` | frozen, SHA-pinned in `bundle_manifest.json` | 331 | 2017-10..2025-12 |
| 10706 GBPUSD | same dir, `10706_GBPUSD_DWX.jsonl` | frozen | 367 | 2017-10..2025-12 |
| 12778 AUDUSD/EURJPY basket | same dir, `12778_AUDUSD_DWX.jsonl` | frozen | 195 | 2018-05..2025-06 |
| 13128 pre-FOMC NDX | same dir, `13128_NDX_DWX.jsonl` | frozen | 56 | 2018-09..2025-12 |
| 13013 grimes-trendday-v2 NDX | `...\Common\Files\QM\q08_trades\13013_NDX_DWX.jsonl` | current export (not in frozen bundle) | 71 | 2018-08..2025-11 |
| 10815 GDAXI chain | `...\10815_GDAXI_DWX.jsonl` | current export | 66 | 2018-07..2025-12 |
| 10815 EURUSD chain | `...\10815_EURUSD_DWX.jsonl` | current export | 123 | 2017-10..2025-12 |
| 12474 GBPUSD | `...\12474_GBPUSD_DWX.jsonl` | current export | 273 | 2017-10..2025-12 |

Full SHA256 per file is recorded in `results.json` (`sleeves` block) at run time.

Cross-check performed: 10706 GBPUSD frozen stream (367 trades, net +76,920, PF 1.37)
reconciles with the metrics-DB Q08 row (366 trades, net 72,694, PF 1.34) — same run
family, the frozen copy is the sealed live-book basis.

### Known data caveats (documented, not hidden)

- **12474 GBPUSD**: current stream (2026-07-19) carries 273 trades vs 442 in the
  metrics-DB Q05/Q07/Q08 rows from an earlier run. The current artifact is used
  as-is; the mismatch is recorded in the sleeve notes.
- **10815 streams** predate the `entry_time` schema field — holding periods are
  unknowable from the artifact; concurrency counts them on close-day only, and the
  GDAXI sleeve's FTMO index-swap exposure is flagged as unquantifiable.
- **12969**: verified `net == profit + swap + commission` per row (loader asserts
  this for every stream; run aborts on mismatch).

## Exclusions

- **20004 TOM (GDAXI/NDX)** — pending Q02. No Q02 row exists in the consolidated
  ea_metrics table as of 2026-07-20, and the only stream on disk
  (`20004_GDAXI_DWX.jsonl`, 26 trades, span 2019-02..2022-12, mtime 2026-07-20
  18:51) is an in-flight partial from a run still in progress. Never fabricate:
  excluded.

## Cost model (FTMO venue)

Single source: `framework/registry/venue_cost_model.json` (2026-07-19, OWNER
directive "no fantasy figures").

- **Commission**: the stream's DXZ close-side tester commission is dropped and
  replaced by the FTMO figure — forex flat **$5/lot round-trip** ($2.50/side),
  indices **$0** (official FTMO), pct-notional for metals/energy (not present in
  this book). EURJPY (12778 basket leg) is not in the per-symbol table → forex
  class flat $5/lot RT (recorded as fallback).
- **Swap**: no real FTMO swap numbers exist anywhere on disk (venue model marks
  swap OPEN for all symbols; `docs/research/SWAP_RESEARCH_FTMO_DXZ_5PERS_2026-06-09.md`).
  The stream's tester swap (DXZ-spec derived) is kept as a labelled proxy. Index
  sleeves holding overnight are additionally flagged with a **breakeven swap**
  (edge at 1% risk wiped if FTMO index swap ≥ X $/lot/night): 13128 NDX $339/lot/night,
  13013 NDX $1,623/lot/night — both far above plausible index swap magnitudes, so
  swap does NOT wipe these edges; 10815 GDAXI unquantifiable (no entry_time).
- **Spread**: embedded in .DWX 100% real-tick history — not double-counted.
- **Slippage**: not modelled (gross-of-slippage label).

## Method

1. Per-trade FTMO net at source risk: `profit + swap − ftmo_commission`. Source
   sizing = factory `RISK_FIXED=1000` on 100k (= 1.0% per trade; verified in EA set
   files). A sleeve at risk r% multiplies its P&L by r/1.0. Cap 1.0%/sleeve,
   book total ≤ 5%.
2. **Day-bundle bootstrap**: each sleeve's stream is grouped into active-day bundles
   (all trades closing the same broker-time day stay together → intra-day clustering
   preserved). Empirical arrival: p_active = active days / weekdays in span. Each
   simulated trading day, each sleeve is active with p_active and realises a
   uniformly resampled historical day bundle. Sleeves resample independently —
   cross-sleeve correlation is broken (Q09 max-corr for these sleeves is low), and
   the **historical rolling-window evaluation** (real calendar alignment, stride 5
   trading days, same rules) is reported per composition as the correlation-faithful
   anchor. MC and historical anchors agree well (e.g. full book 7.4% vs 6.3%).
3. **Phase-1 rules on closed daily P&L**: fail when day P&L ≤ −5% of initial
   balance; fail when cumulative ≤ −10%; pass when cumulative ≥ +10% and ≥ 4
   trading days; horizon 90 trading days. Breaches are evaluated before the target
   on the same day. Floating intraday drawdown is invisible in closed-trade
   artifacts → breach probabilities are **lower bounds**.
4. 10,000 paths, deterministic seed 20260720 with per-composition substreams.
5. Concurrency: historical risk-weighted co-open exposure per calendar day from
   entry/close intervals (close-day-only for streams without entry_time).

## Headline result (run 2026-07-20, seed 20260720)

| Composition | Σrisk% | P(pass 90td) | P(daily-DD) | P(total-DD) | days-to-pass p25/50/75 | hist. windows pass% |
|---|---|---|---|---|---|---|
| a motor solo @1.0 | 1.0 | 0.0% | 0.0% | 0.0% | — | 0.0% |
| b motor + 13013 + 12778 | 2.0 | 0.0% | 0.0% | 0.0% | — | 0.0% |
| c full book equal @0.5 | 4.0 | 7.4% | 0.0% | 0.01% | 52/67/80 | 6.3% |
| d full book inverse-vol | 4.0 | 0.0% | 0.0% | 0.0% | — | 0.0% |
| e speed tilt (10706+motor @1.0) | 4.5 | 30.6% | 0.0% | 3.6% | 32/52/70 | 36.7% |

Interpretation: the candidate pipeline-survivor book is **safe but far too slow** for
Phase 1. Death risk is negligible (worst composition 3.6% total-DD, 0% daily-DD on
closed-P&L basis), but even the most aggressive admissible tilt passes only ~31% of
the time inside 90 trading days, with conditional median 52 days — the median PATH
never passes. The ≤50-median-days go-gate is **not met by any composition**. The
binding constraint is carry: the whole book earns ~$4.2k expected per 90 trading days
at 4.5% concurrent risk vs the $10k target; only 10706 GBPUSD (~$9k/yr at 1%)
materially moves the needle, and it is a Q08 FAIL_HARD/probation sleeve.

## Reproduce

```powershell
"C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe" `
  tools/strategy_farm/portfolio/ftmo_p1_mc.py `
  --out-dir D:\QM\reports\portfolio\ftmo_p1_mc_20260720
```
