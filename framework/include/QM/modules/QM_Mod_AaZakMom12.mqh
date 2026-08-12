#ifndef QM_MOD_AAZAKMOM12_MQH
#define QM_MOD_AAZAKMOM12_MQH

#include "../QM_StrategyModule.mqh"

// Phase-3-REST — CQMStrategyModule port of the standalone QM5_1556
// aa-zak-mom12 EA (XAUUSD.DWX, D1). Entry/Exit/Manage/NoTrade mechanics and
// strategy input defaults are taken 1:1 from
// framework/EAs/QM5_1556_aa-zak-mom12/QM5_1556_aa-zak-mom12.mq5 (its
// XAUUSD backtest set carries no strategy_* overrides, so the .mq5 input
// defaults ARE the verified backtest config).
// Original identity preserved: Magic() = 15560004 (ea_id 1556, slot 4).
//
// Differences from the standalone are framework-lifecycle only:
//  - TF() is hard PERIOD_D1 instead of the standalone's `_Period != PERIOD_D1`
//    NoTradeFilter chart-timeframe guard, which is dropped: the master
//    dispatcher already gates this module's entries on its own hard TF()
//    new-bar (same rationale as the 12567 pilot).
//  - Entry sizes via the explicit Phase-2.5 dual-mode path
//    (QM_TM_OpenPosition(..., Magic(), RiskMode(), RiskValue())) instead of
//    the standalone's global risk context — no global risk state is read.
//  - CheckExit() runs every tick under the master dispatcher (management/
//    exit are never gated by NoTrade() or new-bar there), whereas the
//    standalone only evaluated its exit check once per closed D1 bar
//    (behind its own QM_IsNewBar() gate). This is a no-op behavioral
//    difference: the monthly rebalance decision is latched by
//    QM_CalendarPeriodKey(PERIOD_MN1) — a calendar key, not a bar counter —
//    so re-evaluating it on every intra-bar tick still fires exactly once
//    per month, at the same transition tick, exactly as the framework's own
//    documentation for QM_IsNewCalendarPeriod describes ("tester-robust...
//    survives a restart mid-period unlike a pure new-bar edge").
//  - The standalone's explicit QM_SymbolGuardInit/QM_BasketWarmupHistory
//    calls in OnInit are basket-history pre-loaders (FW9); this module
//    trades only the master's own chart symbol, which the tester already
//    loads full D1 history for, and CheckEntry/CheckExit's own bars-needed
//    guard (via NoTrade()) already blocks trading until enough D1 history
//    exists — matches the pilot's "no per-instance handle/setup in Init()"
//    approach.
//  - Indicator handles are the framework's pooled handles (QM_Indicators.mqh),
//    exactly as the standalone used them.
class CQMModAaZakMom12 : public CQMStrategyModule
  {
private:
   bool        m_enabled;
   QM_RiskMode m_risk_mode;
   double      m_risk_value;

   // Strategy inputs — identical defaults to the standalone EA / its
   // verified backtest set (QM5_1556_aa-zak-mom12_XAUUSD.DWX_D1_backtest.set).
   int    m_momentum_lookback_d1;
   double m_momentum_trigger;
   int    m_atr_period_d1;
   double m_atr_sl_mult;
   int    m_max_spread_points;   // retained for parameter-table compatibility, unused (matches standalone)
   bool   m_first_d1_bar_only;   // retained for parameter-table compatibility, unused (matches standalone)

   int    m_last_entry_rebalance_key;
   int    m_last_exit_rebalance_key;

public:
   CQMModAaZakMom12()
     {
      m_enabled                 = false;
      m_risk_mode                = QM_RISK_MODE_UNSET;
      m_risk_value                = 0.0;
      m_momentum_lookback_d1     = 252;
      m_momentum_trigger         = 100.0;
      m_atr_period_d1            = 20;
      m_atr_sl_mult              = 3.0;
      m_max_spread_points        = 0;
      m_first_d1_bar_only        = true;
      m_last_entry_rebalance_key = 0;
      m_last_exit_rebalance_key  = 0;
     }

   void Configure(const bool enabled, const QM_RiskMode risk_mode, const double risk_value)
     {
      m_enabled    = enabled;
      m_risk_mode  = risk_mode;
      m_risk_value = risk_value;
     }

   virtual bool             Enabled()   const { return m_enabled; }
   virtual long              Magic()     const { return 15560004L; }
   virtual ENUM_TIMEFRAMES  TF()        const { return PERIOD_D1; }
   virtual QM_RiskMode      RiskMode()  const { return m_risk_mode; }
   virtual double           RiskValue() const { return m_risk_value; }

private:
   // Ported 1:1 from Strategy_RebalanceDue().
   bool RebalanceDue(const bool entry_path, int &month_key)
     {
      month_key = QM_CalendarPeriodKey(PERIOD_MN1);
      if(month_key <= 0)
         return false;

      if(entry_path)
         return (month_key != m_last_entry_rebalance_key);
      return (month_key != m_last_exit_rebalance_key);
     }

   // Ported 1:1 from Strategy_MomentumRatio().
   double MomentumRatio()
     {
      if(m_momentum_lookback_d1 < 20)
         return 0.0;
      return QM_Momentum(_Symbol, PERIOD_D1, m_momentum_lookback_d1, 1, PRICE_CLOSE);
     }

   // Ported 1:1 from Strategy_HasOpenPosition().
   bool HasOpenPosition()
     {
      return (QM_TM_OpenPositionCount((int)Magic()) > 0);
     }

   // Ported 1:1 from MedianSpreadD1().
   int MedianSpreadD1(const string sym, const int lookback)
     {
      if(lookback <= 0)
         return 0;

      MqlRates rates[];
      const int copied = CopyRates(sym, PERIOD_D1, 1, lookback, rates);
      if(copied <= 0)
         return 0;

      int spreads[];
      ArrayResize(spreads, copied);
      int n = 0;
      for(int i = 0; i < copied; ++i)
        {
         if(rates[i].spread < 0)
            continue;
         spreads[n] = rates[i].spread;
         n++;
        }
      if(n <= 0)
         return 0;

      for(int i = 1; i < n; ++i)
        {
         const int key = spreads[i];
         int j = i - 1;
         while(j >= 0 && spreads[j] > key)
           {
            spreads[j + 1] = spreads[j];
            j--;
           }
         spreads[j + 1] = key;
        }

      return spreads[n / 2];
     }

   // Ported 1:1 from Strategy_SpreadAllowsEntry().
   bool SpreadAllowsEntry()
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0)
         return false;
      if(!(ask > bid))
         return true;   // zero or inverted spread — fail-open (.DWX invariant)

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return false;

      const int current_spread = (int)MathRound((ask - bid) / point);
      if(current_spread <= 0)
         return true;   // fail-open

      const int median_spread = MedianSpreadD1(_Symbol, 20);
      if(median_spread <= 0)
         return true;   // insufficient history — fail-open (.DWX invariant)

      const int cap = (int)MathMax(1.0, MathRound(2.5 * median_spread));
      return (current_spread <= cap);
     }

public:
   // Ported 1:1 from Strategy_NoTradeFilter() (timeframe, parameter bounds,
   // minimum warmup bars); the chart-timeframe guard is dropped — see class
   // header.
   virtual bool NoTrade(datetime now)
     {
      if(m_momentum_lookback_d1 < 20)
         return true;
      if(m_atr_period_d1 <= 0 || m_atr_sl_mult <= 0.0)
         return true;

      const int bars_needed = m_momentum_lookback_d1 + m_atr_period_d1 + 2;
      const int bars_avail = iBars(_Symbol, PERIOD_D1);
      if(bars_avail < bars_needed)
         return true;

      return false;
     }

   // Ported 1:1 from Strategy_ManageOpenPosition(): card specifies a fixed
   // initial ATR stop and monthly signal-flip exit, no active management.
   virtual void ManageOpen() {}

   // Ported 1:1 from Strategy_ExitSignal() + its OnTick close loop — see
   // class header for why running every tick (vs. once per closed D1 bar in
   // the standalone) does not change observable behavior.
   virtual void CheckExit()
     {
      if(!HasOpenPosition())
         return;

      int month_key = 0;
      if(!RebalanceDue(false, month_key))
         return;
      m_last_exit_rebalance_key = month_key;

      const double momentum = MomentumRatio();
      if(momentum <= 0.0)
         return;   // indicator not ready / warmup — fail-open, do not force-exit
      if(momentum > m_momentum_trigger)
         return;

      const long magic = Magic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(!QM_ModuleOwnsPosition(magic))
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Ported 1:1 from Strategy_EntrySignal(). Sizing is the Phase-3 dual-mode
   // requirement: explicit magic + explicit (RiskMode(), RiskValue()), never
   // the global risk context.
   virtual void CheckEntry()
     {
      int month_key = 0;
      if(!RebalanceDue(true, month_key))
         return;
      m_last_entry_rebalance_key = month_key;

      if(HasOpenPosition())
         return;
      if(!SpreadAllowsEntry())
         return;

      const double momentum = MomentumRatio();
      if(momentum <= m_momentum_trigger)
         return;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return;

      QM_EntryRequest req;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, QM_BUY, entry, m_atr_period_d1, m_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "QM5_1556_D1_12M_MOM_LONG";
      req.symbol_slot = 0;
      req.expiration_seconds = 0;
      if(req.sl <= 0.0)
         return;

      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket, (int)Magic(), m_risk_mode, m_risk_value);
     }
  };

#endif // QM_MOD_AAZAKMOM12_MQH
