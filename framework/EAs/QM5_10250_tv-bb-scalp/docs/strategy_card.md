---
ea_id: QM5_10250
slug: tv-bb-scalp
type: strategy
source_id: c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
sources:
  - "[[sources/tradingview-top-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/scalping]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
primary_symbol: EURUSD.DWX
expected_trades_per_year_per_symbol: 250
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/handle cited; R2 deterministic BB/EMA entries/exits with 250 trades/year/symbol estimate; R3 DWX FX/index OHLC/volume testable; R4 fixed rules no ML/grid/martingale one-position-per-magic."
---

# QM5_10250 TradingView Bollinger Band EMA Scalping

## Quelle
- Source: TradingView Pine script "Bollinger Band Scalping"
- URL: https://www.tradingview.com/script/CmHXgNGT-Bollinger-Band-Scalping/
- Author: JuliusStark (TradingView handle - anon OK under relaxed R1 post-2026-05-15)
- Source location: TradingView Volatility category, public open-source script, 2026-05-19 snapshot.

## Mechanik

### Entry
- Trading timeframe: M5 baseline; M3 is a P3 variant.
- Compute Bollinger Bands using default baseline `SMA(20)` and `2.0` standard deviations.
- Compute EMA(8), EMA(12), EMA(26), and optional EMA(200) trend filter.
- Long setup:
  - A closed candle has both `Open < lower_band` and `Close < lower_band`.
  - Tick volume is above `SMA(tick_volume, 20)`.
  - Optional trend filter baseline: `Close > EMA(200)`.
  - Enter long at next bar open, one position per magic.
- Short setup:
  - A closed candle has both `Open > upper_band` and `Close > upper_band`.
  - Tick volume is above `SMA(tick_volume, 20)`.
  - Optional trend filter baseline: `Close < EMA(200)`.
  - Enter short at next bar open.

### Exit
- Source has three EMA-based take-profit targets: EMA(8), EMA(12), EMA(26).
- V5 baseline uses a single full-position exit at EMA(8), because partial exits would require split magic slots.
- P3 variants can test EMA(12) and EMA(26) as the single exit target.
- Hard time-stop: flatten after 24 bars if no EMA target or stop is hit.

### Stop Loss
- Source states configurable percent SL. V5 baseline: SL = 0.35% of entry for index CFDs and `1.2 x ATR(14)` for FX symbols, with P3 sweep over 0.25% / 0.50% and 1.0 / 1.5 ATR.

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` for P2 baseline. `RISK_PERCENT` for live.

### Zusaetzliche Filter
- Trade only during London and New York liquid hours.
- Spread filter: skip entry when spread > 1.5 x 50-bar average spread.
- Standard V5: QM_KillSwitch, news filter, MAX_DD trip, Friday-close flatten.

## Concepts
- [[concepts/mean-reversion]] - primary; fade an outside-band excursion back toward fast EMAs.
- [[concepts/scalping]] - source recommends 3m/5m and high trade count.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public TradingView URL and author handle JuliusStark are cited. |
| R2 Mechanical | PASS | Entry requires open and close outside Bollinger Band; exits are EMA targets; SL is configurable percent/ATR default. |
| R3 Data Available | PASS | Bollinger Bands, EMAs, ATR, tick volume, and M5/M3 bars are available on DWX FX/index symbols. |
| R4 ML Forbidden | PASS | Fixed indicator rules only. No ML, adaptive learning, grid, or martingale. One position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from TradingView top-script resume batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9168_tv-elaris-confluence-scalping]] - sibling TradingView scalping/confluence card.

## Lessons Learned (waehrend Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- Source claims 50-100 trades/day in volatile sessions; cadence is capped conservatively to 250/year/symbol for G0 frontmatter because DWX spread/session filters should suppress much of the raw signal stream.
- Default P2 symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX.
- Implement TP as full exit at EMA(8) first. Partial EMA ladder is not baseline-compatible with one-position-per-magic.
