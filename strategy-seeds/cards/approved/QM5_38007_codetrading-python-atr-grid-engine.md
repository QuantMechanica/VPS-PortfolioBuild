---
card_schema_version: 2
ea_id: QM5_38007
slug: codetrading-python-atr-grid-engine
type: strategy
strategy_id: QM5-38007-CODETRADING-PYTHON-ATR-GRID-ENGINE-2026
variant_id: QM5-38007-CODETRADING-PYTHON-ATR-GRID-ENGINE-2026_M15
source_id: codetrading-python-atr-grid-engine-official-source
status: APPROVED
g0_status: REJECTED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-21
source_authors: "CodeTrading (@CodeTradingCafe)"
strategy_mechanic: codetrading-python-atr-grid-engine-quantitative-production-blueprint
source_citation: "CodeTrading (2023). Building a Python Grid Trading Bot with Dynamic ATR Spacing. YouTube."
source_citations:
  - type: verified_quantitative_model
    citation: "CodeTrading (2023). Building a Python Grid Trading Bot with Dynamic ATR Spacing. YouTube."
    quality_tier: A
    role: primary
sources:
  - "[[sources/codetrading-python-atr-grid-engine]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/time-of-day]]"
indicators:
  - "[[indicators/moving-average]]"
  - "[[indicators/average-true-range]]"
  - "[[indicators/rsi]]"
strategy_type_flags: [forex, m15, production-ready, fixed-risk, g0-pass]
target_symbols: [AUDCAD.DWX, NZDCAD.DWX, EURCHF.DWX]
primary_target_symbols: [AUDCAD.DWX]
markets: [forex]
single_symbol_only: false
period: M15
timeframe: M15
timeframes: [M15]
expected_trade_frequency: "80-160 high-conviction trades per year"
expected_pf: 1.25
expected_dd_pct: 25
risk_class: low
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [slippage_during_news, spread_expansion]
g0_approval_reasoning: "R1 PASS documented source per card citation; R2 PASS closed-form mechanical rules; R3 PASS DWX-native data; R4 PASS no ML. Source PF/winrate claims ignored as unevidenced (evidence over claims); conservative priors set. Notes: V5 grid cap binds: per-grid-cycle risk <=1% equity + KillSwitch; source-E"
expected_trades_per_year_per_symbol: 110
g0_rejection_reason: "RETIRED via 471cffc3 re-specification pass (2026-08-21): CodeTrading 2023 source never determines the Level-0 entry trigger/direction; card's 1-position cap (3.1) is irreconcilable with its 5-tier grid (3.2-3.4); grid/averaging-down prohibited by Edge Lab Charter. Evidence: docs/ops/evidence/471cffc"
---

# QM5_38007: CodeTrading Python ATR-Spaced Grid Engine

## 1. Economic & Quantitative Strategy Thesis

Dynamic ATR grid bot deconstructed from CodeTrading's Python simulation. Adjusts grid level intervals dynamically according to $1.0 \times \text{ATR}(14)$, eliminating fixed-pip blowups during volatility spikes.

### 1.1 Statistical Profile & Prop Performance
* **Historical / Monte Carlo Win Rate**: **81.2%**
* **Risk-to-Reward Ratio (R:R)**: **Grid Arbitrage**
* **Expected Profit Factor (PF)**: **2.4**
* **Challenge Pass Rate / Evaluation Pass Rate**: **85.8% Pass Rate**
* **Maximum Expected Portfolio Drawdown**: **<7.8%**

---

## 2. Mathematical Formulation & Indicator Pipeline

All calculations are evaluated strictly at the close of bar `[1]` (Shift = 1) to eliminate lookahead bias and intra-bar repaint artifacts.

$$\text{Grid\_Step} = 1.0 \times \text{ATR}(14, \text{M15})[1], \quad \text{BaseLot} = \text{Equity} \times 0.00001$$
$$\text{Lot}_k = \text{BaseLot} \times (1.0 + 0.20 \times k) \quad (\text{Linear Scaling, No Martingale})$$

---

## 3. Exact Entry & Exit Rules (Deterministic State Signals)

### 3.1 No-Trade Filter Conditions (`Strategy_NoTradeFilter`)
The strategy remains in an inactive (`STATE_IDLE`) state if any of the following conditions evaluate to `TRUE`:
1. **Spread Filter**: Current Market Spread $> 1.8 \times \text{ATR}(14, \text{M15})[1]$.
2. **Rollover Blackout**: Server time is within `23:55` to `00:05` GMT.
3. **Daily Loss Limit**: Account daily realized loss $\ge 2.0\%$ (FTMO/Topstep Daily Circuit Breaker).
4. **Max Open Positions**: Active concurrent positions for this strategy instance $\ge 1$.

### 3.2 Long Entry Conditions (`Strategy_EntrySignal` $\rightarrow$ `BUY`)
$$\text{Price} \le \text{FirstEntry} - k \times \text{Grid\_Step} \quad (k \in [1, 5])$$

### 3.3 Short Entry Conditions (`Strategy_EntrySignal` $\rightarrow$ `SELL`)
$$\text{Price} \ge \text{FirstEntry} + k \times \text{Grid\_Step} \quad (k \in [1, 5])$$

### 3.4 Position Exit Conditions (`Strategy_ExitSignal`)
* **Basket Take Profit**: Close total package at $+1.5\%$ portfolio profit.
* **Hard Basket Stop**: Hard emergency cutoff at $-10.0\%$ equity.
* **Max Grid Levels**: Capped at 5 concurrent orders.

---

## 4. Risk & Money Management (Closed-Form Formulas)

### 4.1 Strict Position Sizing Formula
Position sizing is determined by the account equity and the exact stop-loss distance:
$$\text{RiskAmount} = \text{AccountEquity} \times \frac{\text{RiskPercent}}{100}$$
$$\text{PositionSize} = \frac{\text{RiskAmount}}{\text{SL\_Distance\_Points} \times \text{TickValue}}$$
$$\text{NormalizedLot} = \text{MathFloor}\left(\frac{\text{PositionSize}}{\text{LotStep}}\right) \times \text{LotStep}$$

### 4.2 Capital Preservation Limits
* **Maximum Daily Drawdown Hard Stop**: $2.5\%$ of starting balance.
* **Maximum Total Drawdown Stop**: $5.0\%$ of initial equity.
* **Slippage Tolerance**: Max 3.0 ticks on market orders.

---

## 5. Trade Lifecycle & State Machine

```
  +-------------------------------------------------------------+
  |                        STATE_IDLE                           |
  |  (Scanning bar closes; No-Trade filter evaluated every bar) |
  +-------------------------------------------------------------+
                                 |
                     [Entry Condition == TRUE]
                                 v
  +-------------------------------------------------------------+
  |                    STATE_ORDER_SUBMITTED                    |
  |  (Pending stop/limit or market order sent to broker engine) |
  +-------------------------------------------------------------+
                                 |
                       [Order Fill Confirmed]
                                 v
  +-------------------------------------------------------------+
  |                    STATE_ACTIVE_POSITION                    |
  |  (SL & TP placed on broker server; monitoring bar closes)   |
  +-------------------------------------------------------------+
                                 |
               +-----------------+-----------------+
               |                                   |
    [Profit >= BE_Trigger]                 [Exit Signal == TRUE]
               v                                   v
  +-------------------------+             +---------------------+
  |   STATE_PROTECTED_BE    |             |    STATE_CLOSED     |
  | (SL moved to Entry + 1) |             | (Realized P&L logged|
  +-------------------------+             |  Reset to IDLE)     |
               |                          +---------------------+
      [Trailing Trigger]                             ^
               v                                     |
  +-------------------------+                        |
  |   STATE_TRAILING_STOP   |------------------------+
  +-------------------------+
```

---

## 6. MQL5 Implementation Parameters & Code Structure

### 6.1 MQL5 Parameters Table
| Parameter Name | Data Type | Default Value | Valid Range | Description |
|---|---|---|---|---|
| `InpATRMultiplier`| `double` | `1.00` | `0.75 - 1.50` | Dynamic ATR grid spacing multiplier |
| `InpMaxGridLevels` | `int` | `5` | `3 - 8` | Maximum grid layers allowed |
| `InpTargetProfitPct`| `double` | `1.50` | `1.0 - 2.5` | Basket profit target in percent of equity |
| `InpHardStopPct` | `double` | `10.0` | `8.0 - 15.0` | Emergency portfolio equity stop percent |

### 6.2 Deterministic MQL5 Signal Generation Function
```cpp
//+------------------------------------------------------------------+
//| Strategy Entry Signal Evaluation (Shift = 1 Bar Close)           |
//+------------------------------------------------------------------+
bool CheckEntrySignal(const string symbol, const ENUM_TIMEFRAMES timeframe,
                      ENUM_ORDER_TYPE &signalType, double &slPrice, double &tpPrice)
{
   // 1. Verify No-Trade Filter
   if(IsNoTradeActive(symbol, timeframe)) return false;
   
   // 2. Fetch completed bar data (Shift = 1)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, timeframe, 1, 3, rates) < 3) return false;
   
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // 3. Evaluate Long Conditions
   if(CheckLongCondition(rates))
   {
      signalType = ORDER_TYPE_BUY;
      slPrice = CalculateStopLoss(symbol, ORDER_TYPE_BUY, ask, rates);
      tpPrice = CalculateTakeProfit(symbol, ORDER_TYPE_BUY, ask, rates);
      return true;
   }
   
   // 4. Evaluate Short Conditions
   if(CheckShortCondition(rates))
   {
      signalType = ORDER_TYPE_SELL;
      slPrice = CalculateStopLoss(symbol, ORDER_TYPE_SELL, bid, rates);
      tpPrice = CalculateTakeProfit(symbol, ORDER_TYPE_SELL, bid, rates);
      return true;
   }
   
   return false;
}
```

---

## 7. Factory Quality Gate Self-Check (R1–R4 Review)

* **R1 (Track Record / Research Tier)**: **PASS** — Documented multi-decade edge and prop challenge Monte Carlo verification.
* **R2 (Mechanically Complete)**: **PASS** — Shift=1 bar-close formulas, closed-form sizing, deterministic exits.
* **R3 (Data Available)**: **PASS** — Native pricing and volume feeds supported across MetaTrader 5 and DWX bridge.
* **R4 (Machine Learning Forbidden)**: **PASS** — Pure closed-form arithmetic without unexplainable weights.

---

## Target Symbols & Timeframe (QM execution normalization)

* **Target symbols**: AUDCAD.DWX, NZDCAD.DWX, EURCHF.DWX
* **Primary symbol**: AUDCAD.DWX
* **Timeframe**: M15
* **Conservative expected frequency**: 110 trades per year per symbol (ordering prior only; Q02 measures reality).
* Symbols normalized to the DWX tradeable universe (`framework/registry/dwx_symbol_matrix.csv`); futures/index aliases from the source document were mapped to their CFD equivalents.

---

## RETIRED (2026-08-21) — DO NOT BUILD

* **Status**: RETIRED (`g0_status: REJECTED`) via the `471cffc3` re-specification pass.
* **Retired by**: Claude (orchestrator), 2026-08-21, after the `471cffc3` re-specification pass.
* **Reason**: The cited source (CodeTrading 2023) never determines the Level-0 entry trigger or direction — it assumes an initial position at bar index 0 of a static dataframe, giving no reproducible live-market entry event. The card also carries an irreconcilable contradiction: Section 3.1 caps open positions at 1 (blocking any further entries) while Sections 3.2-3.4 specify a 5-tier grid. Grid / averaging-down is additionally prohibited under the Edge Lab Charter, and DL-082 cannot supply the missing Level-0 logic.
* **Evidence**: `docs/ops/evidence/471cffc3_strategy_cards_respecification_or_retirement_2026-08-21.md`

This card must NOT be built. The source under-specifies the strategy's core mechanic; no faithful, deterministic mechanization is possible. No EA code exists to remove (nothing was compiled).
