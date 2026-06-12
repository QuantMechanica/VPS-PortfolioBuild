---
ea_id: QM5_10330
slug: illiq-rev
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
source_citation: "Doron Avramov, Tarun Chordia, Amit Goyal, Liquidity and Autocorrelations in Individual Stock Returns, SSRN abstract 555968, 2005, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=555968"
sources:
  - "[[sources/ssrn-microstructure-hft]]"
concepts:
  - "[[concepts/illiquidity]]"
  - "[[concepts/short-run-reversal]]"
  - "[[concepts/liquidity-pressure]]"
indicators:
  - "[[indicators/spread-percentile]]"
  - "[[indicators/turnover-proxy]]"
  - "[[indicators/atr]]"
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "Short-run reversal only after high-turnover/high-spread pressure events; conservative estimate 40-80 trades/year/symbol."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
r1_reasoning: "Single source_id with SSRN URL and named authors (Avramov, Chordia, Goyal 2005)."
r2_reasoning: "Return shock, spread/tick-volume percentile conditions, two-bar exit, ATR stop are deterministic."
r3_reasoning: "Liquidity-pressure proxy via spread and tick-volume is available in MT5 on DWX index CFDs and XAUUSD.DWX."
r4_reasoning: "Fixed thresholds, no ML, no martingale, one position per magic per session."
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS SSRN paper URL/attribution; R2 PASS deterministic H1 return/spread/tick-volume reversal with two-bar/session-close exit and 60 trades/year/symbol; R3 PASS port-testable on DWX indices/XAUUSD with SP500 T6 caveat; R4 PASS fixed rules no ML/grid/martingale."
---

# Illiq Rev

## Quelle
- Source: [[sources/ssrn-microstructure-hft]]
- Paper URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=555968
- Paper: Doron Avramov, Tarun Chordia, Amit Goyal, "Liquidity and Autocorrelations in Individual Stock Returns", SSRN / Journal of Finance version, 2005.
- Source location: SSRN abstract. The abstract links short-run reversals to illiquidity and high turnover.

## Mechanik

### Entry
- Evaluate on H1 bars during the main cash-session window for index CFDs and liquid metals.
- Compute one-bar return, current spread percentile over 60 trading days, and tick-volume percentile over 60 trading days.
- Long if the just-closed H1 return is below `-0.75 * ATR(14,H1)`, spread percentile is above 70, and tick-volume percentile is above 70.
- Short if the just-closed H1 return is above `0.75 * ATR(14,H1)`, spread percentile is above 70, and tick-volume percentile is above 70.
- Trade only the first qualifying reversal signal per symbol per session.

### Exit
- Exit after two H1 bars or at session close, whichever comes first.
- No overnight holding.

### Stop Loss
- Stop at `1.00 * ATR(14,H1)` from entry.
- Cancel entry if stop distance is less than four current spreads.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.

### Zusaetzliche Filter
- Skip first H1 bar after weekend reopen.
- Skip if the symbol's median spread over the prior 20 sessions is above its 1-year 80th percentile.
- Skip major scheduled macro-release windows unless P3 explicitly tests a macro-included variant.

## Concepts
- [[concepts/illiquidity]] - primary
- [[concepts/short-run-reversal]] - primary
- [[concepts/liquidity-pressure]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | SSRN URL plus named authors and Journal of Finance version. |
| R2 Mechanical | PASS | Return shock, spread/turnover proxies, fixed exit, and stop are deterministic. |
| R3 DWX-testbar | UNKNOWN | Source is individual stocks; DWX can test a CFD liquidity-pressure proxy but not the source universe exactly. |
| R4 No ML | PASS | Fixed thresholds and no adaptive online parameter changes, grid, or martingale. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`, `XAUUSD.DWX`. SP500.DWX caveat if used: "Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable."

## Author Claims
- "strong relationship between short-run reversals and stock return illiquidity" (SSRN abstract).
- "largest reversals" occur in "high turnover, low liquidity stocks" (SSRN abstract).

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10329_imbalance-rev]] - daily imbalance reversal.
- [[strategies/QM5_10328_residual-rev]] - residual intraday reversal.

## Lessons Learned
- TBD during pipeline run.

