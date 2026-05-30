---
ea_id: QM5_10131
slug: tv-nifty-range-short
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
source_citation: "TradingView user script, Nifty Range Short Strategy, TradingView, https://www.tradingview.com/scripts/search/entry/page-28/?script_access=all&script_type=strategies"
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/opening-range]]"
  - "[[concepts/intraday-reversal]]"
indicators:
  - "[[indicators/session-range]]"
  - "[[indicators/atr]]"
target_symbols: [DAX.DWX, NDX.DWX, WS30.DWX, SP500.DWX]
period: M15
expected_trade_frequency: "Intraday range-break/reversal short setup; one or fewer setups per session, estimate 80-140 trades/year/symbol after filters."
expected_trades_per_year_per_symbol: 100
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView search/title attribution cited; R2 deterministic opening-range failed-break short with session/ATR exits and ~100 trades/year/symbol; R3 ports to DWX index CFDs/SP500 backtest with T6 caveat; R4 fixed rules, one trade/session, no ML/grid/martingale."
---

# TradingView Nifty Range Short Reversal

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Citation: "Nifty Range Short Strategy", TradingView search/category entry, 2026 access URL https://www.tradingview.com/scripts/search/entry/page-28/?script_access=all&script_type=strategies.
- Source location: popular strategy search snapshot describes an intraday Nifty range-based short strategy with entry and exit rules.

## Mechanik

### Entry
- Baseline parameters:
  - Opening range window: first 60 minutes of the relevant index cash session.
  - ATR length 14.
- Compute session range high and low during the first hour.
- Short entry when all conditions are true after the range window closes:
  - Price first trades above the opening range high.
  - A later M15 candle closes back below the opening range high.
  - No trade has already been opened for that session.
- No long entries in the base card.

### Exit
- Close short at the first of:
  - Close reaches opening range low.
  - End of session.
  - Close crosses above the opening range high again.

### Stop Loss
- Short stop: max(session range high + 0.5 * ATR(14), entry + 1.5 * ATR(14)).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One trade per symbol/session, one active position per magic.

### Zusaetzliche Filter
- Use local exchange-session analogs:
  - DAX.DWX: Frankfurt/London morning.
  - NDX.DWX, WS30.DWX, SP500.DWX: New York cash open.
- Skip if opening range height < 0.5 * ATR(14) or > 2.5 * ATR(14).
- Skip if spread > 10% of stop distance.

## Concepts
- [[concepts/opening-range]] - primary
- [[concepts/intraday-reversal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | TradingView search/category URL with named strategy title; direct script URL should be captured during P1 if visible. |
| R2 Mechanical | PASS | Opening-range sweep and close-back-inside short rule is deterministic. |
| R3 DWX-testbar | PASS | Nifty index behavior ports to DWX index CFDs; SP500.DWX covers broad-index backtest analog. |
| R4 No ML | PASS | Fixed session/range/ATR rules; no ML, grid, martingale, or adaptive online parameters. |

## R3
Primary P2 basket: DAX.DWX, NDX.DWX, WS30.DWX, SP500.DWX.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9988_tv-opening-range-breakout-dual]] - related opening-range family; this card trades the failed upside breakout short.

## Lessons Learned
- TBD during pipeline run.
