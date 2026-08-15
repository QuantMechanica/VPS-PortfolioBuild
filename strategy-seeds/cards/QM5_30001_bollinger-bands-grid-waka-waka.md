---
card_schema_version: 2
ea_id: QM5_30001
slug: bollinger-bands-grid-waka-waka
type: strategy
strategy_id: ATS-WAKA-WAKA-GRID-2026
variant_id: ATS-WAKA-WAKA-GRID-2026_M15
source_id: valeryia-mishchenko-waka-waka
status: APPROVED
g0_status: APPROVED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-15
source_authors: "Valeriia Mishchenko (Valery Trading)"
strategy_mechanic: bollinger-band-rsi-mean-reversion-with-dynamic-atr-grid-and-martingale-recovery
source_citation: "Valery Trading (2021), Waka Waka EA Official Whitepaper & Live Audited Myfxbook Portfolio."
source_citations:
  - type: vendor_verified_live
    citation: "Valery Trading (2021). Waka Waka MT4/MT5 Trading System Architecture. Verified live Myfxbook since 2018; algotradingspace.com live tracking."
    quality_tier: A
    role: primary
sources:
  - "[[sources/valeryia-mishchenko-waka-waka]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/grid-trading]]"
  - "[[concepts/martingale]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr-stop]]"
strategy_type_flags: [forex, mean-reversion, grid-trading, martingale, basket-tp, news-filter, multi-symbol]
target_symbols: [AUDCAD.DWX, AUDNZD.DWX, NZDCAD.DWX]
primary_target_symbols: [AUDCAD.DWX, AUDNZD.DWX, NZDCAD.DWX]
markets: [forex]
single_symbol_only: false
period: M15
timeframe: M15
timeframes: [M15]
expected_trade_frequency: "15-25 grid cycles per year per symbol; 800-1200 individual order fills/year"
expected_pf: 1.25
expected_dd_pct: 25
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_drawdown_limit, martingale_margin_exhaustion, spread_expansion]
g0_approval_reasoning: "R1 PASS documented source per card citation; R2 PASS closed-form mechanical rules; R3 PASS DWX-native data; R4 PASS no ML. Source PF/winrate claims ignored as unevidenced (evidence over claims); conservative priors set. Notes: V5 grid cap binds: per-grid-cycle risk <=1% equity + KillSwitch; source-E"
expected_trades_per_year_per_symbol: 20
---

# QM5_30001 Bollinger Band Grid Mean Reversion (Waka Waka)

## 1. Economic Thesis & Market Mechanism

The strategy exploits the statistical mean-reverting properties of closely cointegrated commodity currency crosses—specifically **AUDCAD**, **AUDNZD**, and **NZDCAD** (the "Golden Trio"). Because Australia, New Zealand, and Canada share similar economic drivers, trade partners (China/US), and commodity dependencies, their exchange rates fluctuate within bounded historical equilibrium ranges.

When the price experiences a short-term volatility shock that pushes it outside its 20-period standard deviation bands on the M15 timeframe, the probability of a corrective snap-back towards the volume-weighted mean is statistically significant. If a trend persists, an adaptive grid opens additional positions with increasing lot sizes (martingale multiplier) at widening intervals, allowing the entire basket to exit profitably on a minor counter-trend retracement (reversion to basket mean).

---

## 2. Mathematical Formulation & Indicator Calculations

All calculations are evaluated strictly on the **completed bar (`Shift = 1`)** to ensure determinism and prevent repainting.

### 2.1 Bollinger Bands (M15, 20, 2.0)
$$\mu_t = rac{1}{20} \sum_{i=1}^{20} 	ext{Close}_{t-i}$$
$$\sigma_t = \sqrt{rac{1}{20} \sum_{i=1}^{20} (	ext{Close}_{t-i} - \mu_t)^2}$$
$$	ext{BB\_Upper}_t = \mu_t + 2.0 	imes \sigma_t$$
$$	ext{BB\_Lower}_t = \mu_t - 2.0 	imes \sigma_t$$

### 2.2 Relative Strength Index (M15, 14)
$$	ext{RSI}_t = 100 - \left( rac{100}{1 + 	ext{RS}_t} 
ight), \quad 	ext{RS}_t = rac{	ext{Smoothed\_Gain}_{14}}{	ext{Smoothed\_Loss}_{14}}$$

### 2.3 Average True Range (D1, 14)
$$	ext{TR}_t = \max(	ext{High}_t - 	ext{Low}_t, |	ext{High}_t - 	ext{Close}_{t-1}|, |	ext{Low}_t - 	ext{Close}_{t-1}|)$$
$$	ext{ATR\_D1}_t = rac{1}{14} \sum_{i=1}^{14} 	ext{TR}_{t-i}$$

---

## 3. Exact Entry Rules & Trigger Logic

### 3.1 Base Entry Trigger (Level 0 - Initial Trade)
Evaluated only when no open positions exist for the symbol with the strategy's magic number:
* **BUY Signal (Long)**:
  $$	ext{Close}[1] < 	ext{BB\_Lower}[1] \quad 	ext{AND} \quad 	ext{RSI}[1] < 30.0$$
* **SELL Signal (Short)**:
  $$	ext{Close}[1] > 	ext{BB\_Upper}[1] \quad 	ext{AND} \quad 	ext{RSI}[1] > 70.0$$

### 3.2 Grid Progression & Placement Rules (Levels 1..N)
When an active basket exists, the next grid trade is triggered at the close of an M15 bar if the price has moved adversely from the last opened order by at least $\Delta 	ext{Pips}_{	ext{required}}$:
$$\Delta 	ext{Pips}_{	ext{required}} = 	ext{Grid\_Step}(n) 	imes \left( rac{	ext{ATR\_D1}[1]}{	ext{ATR\_Historical\_Mean}} 
ight)$$

**Base Grid Step Table:**
* Level 1 $
ightarrow$ 2: $24.0	ext{ pips}$
* Level 2 $
ightarrow$ 3: $24.0	ext{ pips}$
* Level 3 $
ightarrow$ 4: $28.0	ext{ pips}$
* Level 4 $
ightarrow$ 5: $28.0	ext{ pips}$
* Level 5 $
ightarrow$ 6: $35.0	ext{ pips}$
* Level 6 $
ightarrow$ 7: $40.0	ext{ pips}$
* Level 7 $
ightarrow$ 8: $45.0	ext{ pips}$
* Level 8+: $50.0	ext{ pips}$
* **Max Allowed Grid Levels**: 10 levels.

---

## 4. Exit Rules & Order Termination

### 4.1 Initial Trade (Single Order Active)
* **Take Profit (TP)**: Placed at $	ext{Entry\_Price} \pm 10.0	ext{ pips}$.
* **Stop Loss**: None on order-level; managed by basket equity protection.

### 4.2 Basket Exit (Multiple Orders Active)
1. **Break-Even Price Calculation**:
   $$P_{	ext{BE}} = rac{\sum_{i=1}^{N} (P_i 	imes V_i)}{\sum_{i=1}^{N} V_i}$$
   *(where $P_i$ is open price and $V_i$ is lot volume of order $i$)*
2. **Dynamic Basket TP**:
   * For **BUY Basket**: $	ext{TP}_{	ext{Basket}} = P_{	ext{BE}} + 6.0	ext{ pips}$
   * For **SELL Basket**: $	ext{TP}_{	ext{Basket}} = P_{	ext{BE}} - 6.0	ext{ pips}$
   All open orders in the basket have their TP modified to $	ext{TP}_{	ext{Basket}}$.
3. **Catastrophe Basket Stop Loss**:
   $$	ext{Floating\_Drawdown\_Pct} = rac{	ext{Account\_Equity} - 	ext{Account\_Balance}}{	ext{Account\_Balance}} 	imes 100$$
   If $	ext{Floating\_Drawdown\_Pct} \le -20.0\%$, the EA initiates an immediate market close (`OrderClose` / `PositionClose`) for all open trades of this strategy.

---

## 5. Position Sizing & Risk Management (HR4 Fixed Risk)

### 5.1 Base Lot Size Formula
$$	ext{Base\_Lot} = 	ext{NormalizeLot}\left( rac{	ext{Account\_Equity}}{1000.0} 	imes 0.01 
ight)$$
*(For P2 Baseline backtesting with $1,000 risk budget, $	ext{Base\_Lot} = 0.01$ lot).*

### 5.2 Martingale Multiplier Progression
$$	ext{Lot}(n) = egin{cases} 
	ext{Base\_Lot}, & n = 1, 2 \
	ext{NormalizeLot}(	ext{Lot}(n-1) 	imes 1.45), & n \ge 3 
\end{cases}$$
* Example sizing (0.01 base): `0.01, 0.01, 0.015 -> 0.02, 0.03, 0.04, 0.06, 0.09, 0.13, 0.19, 0.28`.
* **Max Lot Cap**: $5.0	ext{ lots}$.

---

## 6. Execution State Machine & Trade Management

```text
[STATE_IDLE]
   │
   ├── (Close < BB_Lower && RSI < 30) ──> Open BUY Level 0 ──> [STATE_BASKET_BUY]
   └── (Close > BB_Upper && RSI > 70) ──> Open SELL Level 0 ──> [STATE_BASKET_SELL]

[STATE_BASKET_BUY / SELL]
   │
   ├── (Bid/Ask reaches Basket TP) ──> Close All Orders ──> [STATE_IDLE]
   ├── (Drawdown >= 20%) ───────────> Force Flatten All ──> [STATE_IDLE]
   └── (Price adverse >= Step Pips) ──> Open Level N+1 (Lot*1.45) ──> Recalculate BE TP
```

* **OnTick Monitoring**: Every tick recalculates current floating basket profit and checks if $P_{	ext{BE}} \pm 	ext{TP}$ has been reached.
* **Orphan Cleanup**: If orders are desynchronized or broker disconnects, the EA reconciles magic numbers on startup.

---

## 7. Filters & No-Trade Conditions (No-Trade Module)

1. **News Filter**: Suspends trade opening 120 minutes before and 120 minutes after high-impact economic releases (CPI, Interest Rates, Employment) for AUD, CAD, NZD.
2. **Stock Market Crash Filter**: If SP500 daily return is $< -3.0\%$, new grid creation is blocked for 24 hours.
3. **Max Spread Filter**: Skip entry if current spread $> 30	ext{ points}$ ($3.0	ext{ pips}$).
4. **Rollover Blackout**: No new base orders between 23:55 and 00:15 broker time.

---

## 8. Parameters To Test (Complete MQL5 Input Table)

| Type | Parameter Name | Default | Authorized Sweep Range | Role |
|---|---|---:|---|---|
| `int` | `Inp_BB_Period` | 20 | `[14, 20, 30]` | Bollinger Band period |
| `double` | `Inp_BB_Deviation` | 2.0 | `[1.8, 2.0, 2.2]` | Bollinger Band deviation |
| `int` | `Inp_RSI_Period` | 14 | `[7, 14, 21]` | RSI period |
| `double` | `Inp_RSI_Oversold` | 30.0 | `[20.0, 30.0, 35.0]` | RSI oversold threshold |
| `double` | `Inp_RSI_Overbought` | 70.0 | `[65.0, 70.0, 80.0]` | RSI overbought threshold |
| `double` | `Inp_Base_Grid_Step` | 24.0 | `[20.0, 24.0, 30.0]` | Base step in pips |
| `double` | `Inp_Martingale_Mult` | 1.45 | `[1.3, 1.45, 1.6]` | Lot multiplier factor |
| `double` | `Inp_Basket_TP_Pips` | 6.0 | `[4.0, 6.0, 10.0]` | Target profit above BE |
| `double` | `Inp_Max_Drawdown_Pct` | 20.0 | `[15.0, 20.0, 25.0]` | Catastrophe equity stop % |
| `int` | `Inp_Max_Grid_Levels` | 10 | `[7, 10, 12]` | Max allowable open orders |
| `int` | `Inp_Max_Spread_Pts` | 30 | `[20, 30, 45]` | Max spread filter |

---

## 9. Implementation Blueprint & Pseudo-Code

```mql5
// MQL5 Pseudo-Code Snippet for QM5_30001
void OnTick()
{
   if(!IsNewBar(PERIOD_M15)) return;
   
   double bb_upper = iBands(Symbol(), PERIOD_M15, Inp_BB_Period, 0, Inp_BB_Deviation, PRICE_CLOSE, MODE_UPPER, 1);
   double bb_lower = iBands(Symbol(), PERIOD_M15, Inp_BB_Period, 0, Inp_BB_Deviation, PRICE_CLOSE, MODE_LOWER, 1);
   double rsi_val  = iRSI(Symbol(), PERIOD_M15, Inp_RSI_Period, PRICE_CLOSE, 1);
   double close1   = iClose(Symbol(), PERIOD_M15, 1);
   
   int open_positions = CountPositions(MagicNumber);
   
   if(open_positions == 0)
   {
      if(close1 < bb_lower && rsi_val < Inp_RSI_Oversold && SpreadOK())
         OpenOrder(ORDER_TYPE_BUY, Inp_Base_Lot);
      else if(close1 > bb_upper && rsi_val > Inp_RSI_Overbought && SpreadOK())
         OpenOrder(ORDER_TYPE_SELL, Inp_Base_Lot);
   }
   else
   {
      ManageGridAndBasketExits();
   }
}
```

---

## Target Symbols & Timeframe (QM execution normalization)

* **Target symbols**: AUDCAD.DWX, AUDNZD.DWX, NZDCAD.DWX
* **Primary symbol**: AUDCAD.DWX
* **Timeframe**: M15
* **Conservative expected frequency**: 20 trades per year per symbol (ordering prior only; Q02 measures reality).
* Symbols normalized to the DWX tradeable universe (`framework/registry/dwx_symbol_matrix.csv`); futures/index aliases from the source document were mapped to their CFD equivalents.
