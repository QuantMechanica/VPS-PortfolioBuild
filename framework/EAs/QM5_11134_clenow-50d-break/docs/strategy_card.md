---
ea_id: QM5_11134
slug: clenow-50d-break
type: strategy
source_id: f2c83ece-d932-5e08-a923-1f63034348ee
source_citation: "Andreas F. Clenow, Following the Trend: Diversified Managed Futures Trading, Wiley, 2012; public rules page https://www.followingthetrend.com/the-trading-system/trading-system-rules/"
sources:
  - "[[sources/clenow-following-the-trend]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/donchian-breakout]]"
  - "[[concepts/atr-risk-parity]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
  - "[[indicators/rolling-high-low]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 8
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
strategy_type_flags: [donchian-breakout, trend-filter-ma, atr-trailing-stop, atr-hard-stop, symmetric-long-short]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX, XTIUSD.DWX]
g0_approval_reasoning: "R1 cited Clenow book/public rules URL; R2 fixed D1 SMA 50d breakout plus ATR exits supports >=2 trades/yr/symbol despite low cadence; R3 OHLC/ATR rules port to DWX basket; R4 fixed non-ML one-position logic."
---

# QM5_11134 Clenow 50D Breakout Trend

## Quelle
- Source: [[sources/clenow-following-the-trend]]
- Primary book: Andreas F. Clenow, *Following the Trend: Diversified Managed Futures Trading*, Wiley, 2012.
- Primary URL: https://www.followingthetrend.com/the-trading-system/trading-system-rules/
- Book URL: https://www.followingthetrend.com/the-book/
- Q&A URL: https://www.followingthetrend.com/the-trading-system/questions-and-answers/
- Author / institution: Andreas F. Clenow, FollowingTheTrend.com.
- Location: public rules page sections `Position Size`, `Trend Filter`, `Entry Signal`, `Exit Signal`, `Investment Universe`; book Chapter 4 core strategy as queued source.

## Mechanik

Daily diversified CTA-style trend following. The source rule is designed for a broad managed-futures universe; the V5 draft ports the same OHLC mechanics to DWX FX, index, metals, and oil CFDs with one open position per symbol/magic.

### Entry
- Evaluate once per completed D1 bar after rollover spread normalises.
- Compute `SMA(50, close)` and `SMA(100, close)`.
- Compute `HighestClose(50)` and `LowestClose(50)` using completed D1 closes.
- Long setup:
  - `SMA(50) > SMA(100)`.
  - Today's close is the highest close of the last 50 completed D1 bars.
  - No existing position for this EA/symbol/magic.
  - Enter BUY at next bar open.
- Short setup:
  - `SMA(50) < SMA(100)`.
  - Today's close is the lowest close of the last 50 completed D1 bars.
  - No existing position for this EA/symbol/magic.
  - Enter SELL at next bar open.

### Exit
- For a long, track `peak_close_since_entry`.
- Close long at next bar open when D1 close <= `peak_close_since_entry - 3.0 * ATR(20)`.
- For a short, track `trough_close_since_entry`.
- Close short at next bar open when D1 close >= `trough_close_since_entry + 3.0 * ATR(20)`.
- Flip only after the current position is closed and a later completed D1 bar triggers the opposite entry.

### Stop Loss
- Emergency hard stop at `3.5 * ATR(20, D1)` from entry.
- Primary source exit is close-based 3 ATR trailing logic; the hard stop bounds MT5 gap and intraday risk.

### Position Sizing
- Source sizing concept: ATR-scaled position size targeting equal daily impact per market.
- P2 baseline: `RISK_FIXED = 1000` USD per trade, sized against the emergency ATR stop.
- Live: `RISK_PERCENT = 0.25`.
- No pyramiding. One open position per symbol/magic.

### Zusaetzliche Filter
- Minimum warmup: 120 D1 bars.
- Require at least six enabled target symbols in the test basket before portfolio interpretation.
- Skip new entries when current spread exceeds `2 * MedianSpread(60D)`.
- News filter: no new entries within +/-30 minutes of high-impact events; open positions follow the source trailing exit unless framework risk modules force flat.
- Friday close: framework default enabled for index, metals, and oil CFDs; FX can be evaluated with Friday close on/off in P3 if needed.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/donchian-breakout]] - primary
- [[concepts/atr-risk-parity]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Named author Andreas F. Clenow, book title, public book page, and full public trading-system rules URL. |
| R2 Mechanical | PASS | Fixed D1 SMA trend filter, 50-day close breakout entry, ATR sizing, and 3 ATR trailing exit. |
| R3 DWX-testbar | PASS | Rule uses D1 OHLC and ATR only; futures universe ports to DWX FX, index, metals, and oil CFDs. |
| R4 No ML | PASS | Fixed parameters, no optimiser, no online learning, no grid, no martingale, no pyramiding. |

## R3
Primary DWX port should test FX majors plus index/metals/oil CFDs so the portfolio keeps the source's diversification premise. SP500.DWX is optional for backtest-only equity-index coverage; if it is the only survivor, T6 deploy requires parallel validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Clenow describes the rule page as "Core Trend Following Rules".
- The source says the strategy value comes from "the diversification".
- The Q&A warns against trading "less than 40 markets".

## Parameters To Test
- Breakout lookback: `40`, `50`, `60` D1 closes.
- Trend filter: `SMA(40/100)`, `SMA(50/100)`, `SMA(50/150)`.
- ATR period: `14`, `20`, `30`.
- Trailing ATR multiple: `2.5`, `3.0`, `3.5`.
- Emergency stop multiple: `3.0`, `3.5`, `4.0 * ATR(20)`.
- Friday close: `true`, `false` for FX-only ablation; default true for indices/metals/oil.

## Initial Risk Profile
Medium-high. Single-symbol trade frequency is low and performance depends on cross-symbol diversification and occasional large trend captures. The source's futures sizing is volatility balanced; V5 must enforce per-symbol fixed risk plus portfolio exposure caps downstream.

## Framework Alignment
```yaml
modules_used:
  no_trade:
    used: true
    notes: "Warmup, spread cap, minimum basket-size interpretation, news blackout, and framework Friday close."
  trade_entry:
    used: true
    notes: "D1 50-day close breakout gated by 50/100-day SMA trend filter."
  trade_management:
    used: true
    notes: "Track peak/trough close since entry and maintain emergency ATR hard stop; no pyramiding."
  trade_close:
    used: true
    notes: "Close-based 3 ATR trailing exit from best close since entry."
hard_rules_at_risk:
  - friday_close
  - one_position_per_magic_symbol
at_risk_explanation: |
  Daily trend-following trades can span weekends, so Friday-close impact must be measured in P3/P4. The original managed-futures concept can carry many contracts, but this V5 port is explicitly one position per symbol/magic and does not pyramid.
```

## Implementation Notes
```yaml
target_modules:
  no_trade: "D1 warmup >= 120 bars, spread cap, news blackout, framework Friday close."
  entry: "SMA(50/100) trend filter plus 50-day closing high/low breakout on completed D1 bars."
  management: "Persist best close since entry; maintain 3.5 ATR emergency hard stop."
  close: "Close at next bar open after completed D1 close breaches 3 ATR trail from best close."
estimated_complexity: small
estimated_test_runtime: "standard D1 BL sweep"
data_requirements: standard
```

## Pipeline-Verlauf
- G0: 2026-05-22 - drafted from Clenow Following the Trend source, PENDING.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
