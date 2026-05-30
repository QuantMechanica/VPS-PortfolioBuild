---
ea_id: QM5_10111
slug: tv-pmax-flip
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
source_citation: "KivancOzbilgic, PMax Explorer STRATEGY & SCREENER, TradingView, 2020-10-09, https://www.tradingview.com/script/nHGK4Qtp/"
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/trailing-stop-reversal]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/moving-average]]"
  - "[[indicators/supertrend]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX]
period: H1
expected_trade_frequency: "H1 trailing-stop reversal signals are less frequent than bar-by-bar momentum; conservative estimate 25-55 trades/year/symbol."
expected_trades_per_year_per_symbol: 40
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/author present; R2 ATR/MA PMax cross entries, reverse/trailing-stop exits mechanical with 25-55 trades/year/symbol; R3 ports to DWX FX/gold/index CFDs; R4 fixed rules no ML/grid/martingale."
---

# TradingView PMax Flip

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Citation: KivancOzbilgic, "PMax Explorer STRATEGY & SCREENER", TradingView, 2020-10-09, URL https://www.tradingview.com/script/nHGK4Qtp/.
- Author / handle: `KivancOzbilgic`.
- Source location: description defines PMax as a MOST + ATR SuperTrend hybrid; trend is up when the moving average is above PMax and down when below; buy/sell signals occur on MA/PMax crosses or price/PMax crosses.

## Mechanik

### Entry
- Compute PMax using:
  - ATR length default 10.
  - ATR multiplier default 3.0.
  - Moving average type EMA, length default 10, unless P3 sweeps alternatives.
- Baseline signal variant: MA/PMax cross.
- Long: enter when the selected moving average crosses above PMax on bar close.
- Short: enter when the selected moving average crosses below PMax on bar close.

### Exit
- Close and reverse on the opposite MA/PMax cross.
- Optional protective TP for P2: 4 * ATR(14) from entry; disabled in final if reverse-only surface is stronger.

### Stop Loss
- Initial stop at the active PMax line at entry.
- Trail stop to the current PMax line while in position.
- Skip entries where the initial PMax stop distance is < 0.5 * ATR(14) or > 4.0 * ATR(14).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Use confirmed bar-close crosses only; ignore "potential reversal" intrabar state.
- Skip if spread > 10% of current PMax stop distance.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/trailing-stop-reversal]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full TradingView URL plus author handle `KivancOzbilgic`. |
| R2 Mechanical | PASS | ATR length, multiplier, MA/PMax state, confirmed reversal signals, and stop basis are mechanically defined. |
| R3 DWX-testbar | PASS | ATR and moving-average trailing-stop logic ports directly to DWX FX, gold, and index CFDs. |
| R4 No ML | PASS | Fixed indicator parameters and one-position flip logic; no ML/grid/martingale/adaptive online learning. |

## R3
Primary P2 basket / period: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX on H1.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9986_tv-donchian20-breakout-flip]] - prior TradingView breakout-flip card; compare trend-flip family overlap.

## Lessons Learned
- TBD during pipeline run.
