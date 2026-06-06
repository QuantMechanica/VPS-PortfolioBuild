---
ea_id: QM5_10845
slug: tv-ls-short-3r
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "parthaborah022, 5 Min Liquidity Sweep Short 1:3 RR, TradingView open-source strategy, Apr 25, https://www.tradingview.com/script/u6Mgs9n6-5-Min-Liquidity-Sweep-Short-1-3-RR/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/candlestick-pattern]]"
indicators:
  - "[[indicators/ohlc]]"
  - "[[indicators/session-high-low]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 90
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cited TradingView URL/author; R2 precise M5 sweep short entry with bounded 3R exit and plausible intraday cadence >2/yr/symbol; R3 portable to DWX OHLC/ATR symbols; R4 fixed non-ML one-position rules."
---

# TradingView Five Minute Liquidity Sweep Short

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `5 Min Liquidity Sweep Short 1:3 RR`, author handle `parthaborah022`, open-source strategy, accessed 2026-05-22, page shows Apr 25, https://www.tradingview.com/script/u6Mgs9n6-5-Min-Liquidity-Sweep-Short-1-3-RR/

## Mechanik

### Entry
Use M5 baseline. Short-only source logic:

- Previous candle is bullish: close[1] > open[1].
- Previous candle high equals the current day high at that time.
- Current candle high takes out previous candle high.
- Current candle closes below previous candle open.
- Enter short on the next bar open after the confirmed sweep/reclaim candle.

### Exit
- Fixed take profit at 3.0R below entry.
- No reversal entry in baseline because the source is short-only.

### Stop Loss
- Initial stop above the sweep high.
- Add V5 buffer = max(0.10 * ATR(14), 2 * spread) above the sweep high.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- Trade only during liquid sessions for P2 baseline: London/NY overlap for FX/metals and regular cash-open window for index CFDs.
- Skip if stop distance < 3 * spread or > 2.5 * ATR(14).

## Concepts (was ist das fur eine Strategie)
- [[concepts/liquidity-sweep]] - fades a sweep above the current day high.
- [[concepts/mean-reversion]] - expects failed upside break to reverse.
- [[concepts/candlestick-pattern]] - entry is a two-candle OHLC pattern.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `parthaborah022` are cited. |
| R2 Mechanical | PASS | Source gives a precise two-candle short setup and fixed 1:3 risk-reward. |
| R3 Data Available | PASS | Intraday OHLC, current-day high, ATR, and bracket exits are available on DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed price-action rules, no ML, no grid, no martingale, one-position compatible. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the setup is on the 5-minute timeframe.
- Source says the previous candle must be bullish and its high must be at the current day high.
- Source says the latest candle must close below the previous candle open while taking out the previous candle high.
- Source says the strategy uses fixed 1:3 risk-reward.

## Parameters To Test
- Timeframe: M5, M15.
- Session: London, New York, both.
- Stop buffer: 0.05, 0.10, 0.20 * ATR(14).
- RR target: 2.0R, 3.0R, 4.0R.
- Day-high definition: broker day, session day.

## Initial Risk Profile
Short-only intraday reversal with clear bounded risk. Main risks are high sensitivity to session/day boundary and a potential short bias mismatch on equity-index CFDs.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView mechanical strategy source.

## Verwandte Strategien
- QM5_10842 tv-kalki-sweep
- QM5_10687 tv-parent-sweep

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
