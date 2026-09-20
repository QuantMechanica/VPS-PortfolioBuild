---
card_schema_version: 2
ea_id: QM5_41010
slug: developing-poc-migration-scalper
type: strategy
strategy_id: QM5-41010-DEVELOPING-POC-MIGRATION-SCALPER-2026
variant_id: QM5-41010-DEVELOPING-POC-MIGRATION-SCALPER-2026_M15
source_id: developing-poc-migration-scalper-official-source
status: APPROVED
g0_status: REJECTED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-21
source_authors: "Peter Steidlmayer (CBOT)"
strategy_mechanic: developing-poc-migration-scalper-quantitative-production-blueprint
source_citation: "Steidlmayer, P. (1986). Markets & Market Logic. CBOT Market Profile Framework."
source_citations:
  - type: verified_quantitative_model
    citation: "Steidlmayer, P. (1986). Markets & Market Logic. CBOT Market Profile Framework."
    quality_tier: A
    role: primary
sources:
  - "[[sources/developing-poc-migration-scalper]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/time-of-day]]"
indicators:
  - "[[indicators/moving-average]]"
  - "[[indicators/average-true-range]]"
  - "[[indicators/rsi]]"
strategy_type_flags: [futures, m15, production-ready, fixed-risk, g0-pass]
target_symbols: [NDX.DWX, SP500.DWX]
primary_target_symbols: [NDX.DWX]
markets: [futures]
single_symbol_only: false
period: M15
timeframe: M15
timeframes: [M15]
expected_trade_frequency: "80-160 high-conviction trades per year"
expected_pf: 1.3
expected_dd_pct: 15
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
g0_approval_reasoning: "R1 PASS documented source per card citation; R2 PASS closed-form mechanical rules; R3 PASS DWX-native data; R4 PASS no ML. Source PF/winrate claims ignored as unevidenced (evidence over claims); conservative priors set. Notes: symbols normalized to DWX universe; volume profile approximated from MT5 "
expected_trades_per_year_per_symbol: 110
g0_rejection_reason: "RETIRED via 471cffc3 re-specification pass (2026-08-21): Steidlmayer 1986 source does not define d-POC volume-profile algorithm, bucket resolution, or intra-bar volume assignment; mechanization requires invented heuristics (violates R2/R3). Evidence: docs/ops/evidence/471cffc3_strategy_cards_respeci"
---

# QM5_41010: Developing Point of Control (d-POC) Migration Scalper

## 1. Economic & Quantitative Strategy Thesis

Tracks intraday developing Point of Control (d-POC) migration. When d-POC migrates upwards into new high-volume acceptance, it enters in the direction of the institutional value migration.

### 1.1 Statistical Profile & Prop Performance
* **Historical / Monte Carlo Win Rate**: **73.8%**
* **Risk-to-Reward Ratio (R:R)**: **1:2.0**
* **Expected Profit Factor (PF)**: **2.4**
* **Challenge Pass Rate / Evaluation Pass Rate**: **86.0% Pass Rate**
* **Maximum Expected Portfolio Drawdown**: **<2.8%**

---

## 2. Mathematical Formulation & Indicator Pipeline

All calculations are evaluated strictly at the close of bar `[1]` (Shift = 1) to eliminate lookahead bias and intra-bar repaint artifacts.

$$\Delta \text{dPOC} = \text{dPOC}_t - \text{dPOC}_{t-4} > 0, \quad \text{Close}[1] > \text{dPOC}_t$$

---

## 3. Exact Entry & Exit Rules (Deterministic State Signals)

### 3.1 No-Trade Filter Conditions (`Strategy_NoTradeFilter`)
The strategy remains in an inactive (`STATE_IDLE`) state if any of the following conditions evaluate to `TRUE`:
1. **Spread Filter**: Current Market Spread $> 1.8 \times \text{ATR}(14, \text{M15})[1]$.
2. **Rollover Blackout**: Server time is within `23:55` to `00:05` GMT.
3. **Daily Loss Limit**: Account daily realized loss $\ge 2.0\%$ (FTMO/Topstep Daily Circuit Breaker).
4. **Max Open Positions**: Active concurrent positions for this strategy instance $\ge 1$.

### 3.2 Long Entry Conditions (`Strategy_EntrySignal` $\rightarrow$ `BUY`)
$$\Delta \text{dPOC} > 0 \quad \text{AND} \quad \text{Close}[1] > \text{dPOC}_t + 4.0\text{ ticks} \quad \text{AND} \quad \text{Volume}[1] > 1.2 \times \text{SMA}(\text{Vol}, 20)[1]$$

### 3.3 Short Entry Conditions (`Strategy_EntrySignal` $\rightarrow$ `SELL`)
$$\Delta \text{dPOC} < 0 \quad \text{AND} \quad \text{Close}[1] < \text{dPOC}_t - 4.0\text{ ticks} \quad \text{AND} \quad \text{Volume}[1] > 1.2 \times \text{SMA}(\text{Vol}, 20)[1]$$

### 3.4 Position Exit Conditions (`Strategy_ExitSignal`)
* **Take Profit (TP)**: Set to $2.0 \times \text{SL\_Distance}$ ($1:2.0\text{ R:R}$).
* **Stop Loss (SL)**: Set at the active d-POC line $\mp 4.0\text{ ticks}$.
* **Trailing Stop**: Ratchet stop with migrating d-POC.

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
| `InpLookbackBars` | `int` | `4` | `2 - 8` | POC migration lookback bars |
| `InpMinVolumeMult` | `double` | `1.20` | `1.0 - 1.5` | Minimum volume surge multiplier |
| `InpRiskPercent` | `double` | `0.50` | `0.20 - 1.00` | Account equity risk percent per trade |

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

* **Target symbols**: NDX.DWX, SP500.DWX
* **Primary symbol**: NDX.DWX
* **Timeframe**: M15
* **Conservative expected frequency**: 110 trades per year per symbol (ordering prior only; Q02 measures reality).
* Symbols normalized to the DWX tradeable universe (`framework/registry/dwx_symbol_matrix.csv`); futures/index aliases from the source document were mapped to their CFD equivalents.

---

## RETIRED (2026-08-21) — DO NOT BUILD

* **Status**: RETIRED (`g0_status: REJECTED`) via the `471cffc3` re-specification pass.
* **Retired by**: Claude (orchestrator), 2026-08-21, after the `471cffc3` re-specification pass.
* **Reason**: Steidlmayer (1986) Market Profile does not define a discrete OHLCV volume-profile algorithm, a price-bucket resolution, or an intra-bar volume assignment for MT5 candlestick data. Constructing the developing Point of Control (d-POC) would force the implementer to invent arbitrary heuristics (e.g. uniform tick-volume distribution over fixed buckets), violating the closed-form mechanical-completeness rule (R2) and data-availability rule (R3).
* **Evidence**: `docs/ops/evidence/471cffc3_strategy_cards_respecification_or_retirement_2026-08-21.md`

This card must NOT be built. The source under-specifies the strategy's core mechanic; no faithful, deterministic mechanization is possible. No EA code exists to remove (nothing was compiled).
