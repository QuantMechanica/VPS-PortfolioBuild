---
ea_id: 11932
slug: ff-tms-big-e
g0_status: APPROVED
r1_track_record: forex_factory_classic
source_id: forex_factory_classic
r2_mechanical: true
r3_data_available: true
r4_ml_forbidden: true
expected_trades_per_year_per_symbol: 100
target_symbols: ["EURUSD.DWX"]
last_updated: 2026-09-13
g0_approval_reasoning: "Card review 2026-09-13 (Claude): H4 canonical TDI (RSI13/SMA2-7-34) green/red cross confirmed by Heiken Ashi, single deterministic exit (green crosses yellow base line), SL fixed 60 pips (midpoint of source 50-80pip range); charter-compliant FTMO block, single symbol EURUSD.DWX, 100 trades/yr >> 5 f"
expected_pf: 1.2
expected_dd_pct: 10.0
g0_rejection_reason: "R2 FAIL: TDI has no periods specified, the primary exit ('Green line flattens or hooks back') is discretionary, and the safety stop is an unresolved 50-80 pip range."
---

# FF — Trading Made Simple (TMS, Big E)

Source: ForexFactory "Trading Made Simple" thread by Big E (lineage `forex_factory_classic`), using the canonical TDI (Traders Dynamic Index, Dean Malone).
Target symbols: EURUSD.DWX

## Thesis
A TDI-based H4 trend system: enter on the TDI price/signal line cross confirmed by Heiken Ashi direction; exit when the TDI price line crosses the market base line.

## Indicator Definitions (canonical TDI, all on the CLOSED bar [1])
- `R = RSI(Close,13)`.
- **Green (Price Line):** `G = SMA(R,2)`.
- **Red (Signal Line):** `S = SMA(R,7)`.
- **Yellow (Market Base Line):** `Y = SMA(R,34)`.
- **Heiken Ashi:** `HA_Close = (Open+High+Low+Close)/4`; `HA_Open = (HA_Open_prev + HA_Close_prev)/2`. Bullish if `HA_Close[1] > HA_Open[1]`, bearish if `<`.

## Entry Rules
- **Timeframe:** H4, closed bar [1].
- **Buy:** `G[1] > S[1]` AND `G[2] <= S[2]` (green crosses above red) AND Heiken Ashi bullish.
- **Sell:** `G[1] < S[1]` AND `G[2] >= S[2]` (green crosses below red) AND Heiken Ashi bearish.
- One position per magic.

## Exit & Management
- **Primary Exit:** close a Long when `G[1] < Y[1]` (green crosses below the yellow base line); close a Short when `G[1] > Y[1]`.
- **Stop Loss:** fixed 60 pips (resolved from the stated "50-80 pips" range to its midpoint).
- **Position Sizing:** RISK_FIXED (backtest) / RISK_PERCENT (live) tied to the 60-pip stop.

## Respecification Provenance (2026-08-21)
- **Defective passage:** "Primary Signal: TDI"; "Exit when the Green TDI line flattens, 'hooks' back, or crosses the Yellow Market Base Line"; "Safety SL: Fixed 50-80 pips (pair dependent)."
- **Correction:** the fuzzy exit ("flattens/hooks") is resolved to the one deterministic condition stated last — **green crosses the yellow market base line**; TDI lines given their canonical closed-form definitions (RSI13; SMA 2/7/34); Heiken Ashi confirmation defined explicitly; SL resolved to a single **60 pips**. All values are the canonical TDI defaults; no new mechanics invented.

## Edge Lab FTMO Block
- Drawdown: <=5% daily / <=10% total.
- News Blackout: Mandatory.
- Horizon: Swing (H4).
- No Martingale/Grid/Averaging.
- Mechanical/No-ML.
