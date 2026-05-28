---
ea_id: QM5_10081
slug: gh-victor-rsi
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
sources:
  - "[[sources/github-mql5-stars-20]]"
source_citation: "Victor Algo, Divergence Rsi de LeTraderSmart EA, GitHub, https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Divergence%20Rsi%20de%20LeTraderSmart/Expert/DivergenceRsi.mq5"
concepts:
  - "[[concepts/divergence]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/trailing-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source GitHub file URLs cited; R2 deterministic RSI divergence/trailing-stop rules with ~30 trades/year/symbol; R3 OHLC/RSI portable to DWX CFDs; R4 fixed-parameter non-ML one-position-per-magic."
---

# GitHub Victor Algo RSI Divergence Reversal

## Quelle
- Source: [[sources/github-mql5-stars-20]]
- Source citation: Victor Algo, Divergence Rsi de LeTraderSmart EA, GitHub URL cited 2026, https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Divergence%20Rsi%20de%20LeTraderSmart/Expert/DivergenceRsi.mq5
- Page / Timestamp: `victor-algo/channel`, `LIVE BOT - Creation de trading bot from scratch/Divergence Rsi de LeTraderSmart/Expert/DivergenceRsi.mq5`, https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Divergence%20Rsi%20de%20LeTraderSmart/Expert/DivergenceRsi.mq5
- Signal file: https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Divergence%20Rsi%20de%20LeTraderSmart/Include/Signal.mqh
- Source-code author/institution: Victor Algo, https://github.com/victor-algo/channel

## Mechanik

### Entry
- Baseline test period: H1.
- Calculate RSI 14 on close.
- Search the last 20 to 100 closed candles for RSI/price divergence.
- Buy setup: the recent local price low is lower than the older local low, the recent RSI local low is higher than the older RSI local low, both RSI local lows are below 30, and the latest closed candle is bullish.
- Sell setup: the recent local price high is higher than the older local high, the recent RSI local high is lower than the older RSI local high, both RSI local highs are above 70, and the latest closed candle is bearish.
- Enter only if no position exists for the symbol/magic and the symbol has not already traded on that timeframe during the prior bar.

### Exit
- Source uses a percent trailing stop, not a fixed take profit.
- For a long, trail SL to current price * (1 - 1.0 percent) when that value is above the current SL.
- For a short, trail SL to current price * (1 + 1.0 percent) when that value is below the current SL.

### Stop Loss
- Initial long SL = ask * (1 - 1.0 percent).
- Initial short SL = bid * (1 + 1.0 percent).

### Position Sizing
- Source default volume: fixed 0.1 lot.
- V5 baseline: fixed risk $1,000 for P2.

### Zusatzliche Filter
- Drawing options are source visualization only and not part of the trading edge.
- Optional spread/session/news filters may be added by V5 framework defaults.
- V5 constraint: one active position per symbol/magic.
- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Concepts (was ist das fur eine Strategie)
- [[concepts/divergence]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full GitHub repository and file URLs are cited with named institution Victor Algo. |
| R2 Mechanical | PASS | Local-extreme divergence, RSI thresholds, confirmation candle, and trailing stop are deterministic. |
| R3 Data Available | PASS | Uses OHLC and RSI data available on DWX forex, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed parameters, no ML, no martingale, no grid, and one active position per magic in V5. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9461_gh-rsi-breakin]] - RSI threshold mean-reversion; this card requires explicit price/RSI divergence.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
