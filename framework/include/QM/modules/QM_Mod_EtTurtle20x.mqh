#ifndef QM_MOD_ETTURTLE20X_MQH
#define QM_MOD_ETTURTLE20X_MQH

#include "../QM_StrategyModule.mqh"

// Phase-3-REST — CQMStrategyModule port of the standalone QM5_10403
// et-turtle20x EA (XAUUSD.DWX, D1). Entry/Exit/Manage/NoTrade mechanics and
// strategy input defaults are taken 1:1 from
// framework/EAs/QM5_10403_et-turtle20x/QM5_10403_et-turtle20x.mq5 (its
// XAUUSD backtest set carries no strategy_* overrides, so the .mq5 input
// defaults ARE the verified backtest config).
// Original identity preserved: Magic() = 104030002 (ea_id 10403, slot 2).
//
// Differences from the standalone are framework-lifecycle only:
//  - TF() is hard PERIOD_D1; HighestHigh/LowestLow/ATR reads use PERIOD_D1
//    explicitly instead of the standalone's chart-timeframe `strategy_tf`
//    input (the master dispatcher gates entries on this module's own TF
//    new-bar, so chart TF is never consulted).
//  - Entry sizes via the explicit Phase-2.5 dual-mode path
//    (QM_TM_OpenPosition(..., Magic(), RiskMode(), RiskValue())) instead of
//    the standalone's global risk context — no global risk state is read.
//  - The standalone's straddle entry (when both a long and short Donchian
//    breakout are simultaneously valid) opened the buy leg inline via the
//    2-arg QM_TM_OpenPosition overload (global magic/risk) and returned the
//    sell leg for OnTick's own explicit call. CheckEntry() here opens both
//    legs directly through the explicit dual-mode overload instead —
//    same observable outcome (both pending stops placed under this
//    module's own magic when both signals are valid).
//  - CheckExit() keeps the standalone's two-pass "find trigger, then close
//    all own-magic positions" shape (unlike the pilot's one-pass
//    simplification) because this strategy CAN carry simultaneous
//    long+short positions under one magic (the dual-pending-stop straddle
//    above), so collapsing to one pass would change which positions close.
//  - Indicator handles are the framework's pooled handles (QM_Indicators.mqh);
//    there is no per-instance handle to create in Init() or release in
//    Deinit().
class CQMModEtTurtle20x : public CQMStrategyModule
  {
private:
   bool        m_enabled;
   QM_RiskMode m_risk_mode;
   double      m_risk_value;

   // Strategy inputs — identical defaults to the standalone EA / its
   // verified backtest set (QM5_10403_et-turtle20x_XAUUSD.DWX_D1_backtest.set).
   int    m_entry_channel;
   int    m_exit_channel;
   int    m_atr_period;
   double m_atr_stop_mult;
   bool   m_atr_regime_filter;
   int    m_atr_regime_window;
   double m_atr_regime_percentile;
   double m_max_spread_points;
   int    m_pending_expiry_bars;

public:
   CQMModEtTurtle20x()
     {
      m_enabled               = false;
      m_risk_mode             = QM_RISK_MODE_UNSET;
      m_risk_value            = 0.0;
      m_entry_channel         = 20;
      m_exit_channel          = 10;
      m_atr_period            = 20;
      m_atr_stop_mult         = 2.0;
      m_atr_regime_filter     = false;
      m_atr_regime_window     = 100;
      m_atr_regime_percentile = 50.0;
      m_max_spread_points     = 0.0;
      m_pending_expiry_bars   = 1;
     }

   void Configure(const bool enabled, const QM_RiskMode risk_mode, const double risk_value)
     {
      m_enabled    = enabled;
      m_risk_mode  = risk_mode;
      m_risk_value = risk_value;
     }

   virtual bool             Enabled()   const { return m_enabled; }
   virtual long              Magic()     const { return 104030002L; }
   virtual ENUM_TIMEFRAMES  TF()        const { return PERIOD_D1; }
   virtual QM_RiskMode      RiskMode()  const { return m_risk_mode; }
   virtual double           RiskValue() const { return m_risk_value; }

private:
   // Ported 1:1 from HasOurExposure(): true if this module already owns an
   // open position OR a pending order on this symbol.
   bool HasOurExposure()
     {
      const long magic = Magic();

      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(QM_ModuleOwnsPosition(magic))
            return true;
        }

      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((long)OrderGetInteger(ORDER_MAGIC) == magic)
            return true;
        }

      return false;
     }

   // Ported 1:1 from HighestHigh()/LowestLow(), hard PERIOD_D1.
   double HighestHigh(const int start_shift, const int bars)
     {
      if(start_shift < 1 || bars < 1)
         return 0.0;

      double value = -DBL_MAX;
      for(int i = start_shift; i < start_shift + bars; ++i)
        {
         const double high = iHigh(_Symbol, PERIOD_D1, i);
         if(high <= 0.0)
            return 0.0;
         value = MathMax(value, high);
        }
      return value;
     }

   double LowestLow(const int start_shift, const int bars)
     {
      if(start_shift < 1 || bars < 1)
         return 0.0;

      double value = DBL_MAX;
      for(int i = start_shift; i < start_shift + bars; ++i)
        {
         const double low = iLow(_Symbol, PERIOD_D1, i);
         if(low <= 0.0)
            return 0.0;
         value = MathMin(value, low);
        }
      return value;
     }

   // Ported 1:1 from PercentileATR(), hard PERIOD_D1.
   double PercentileATR(const int bars, const double percentile)
     {
      if(bars < 3)
         return 0.0;

      double values[];
      ArrayResize(values, bars);
      for(int i = 0; i < bars; ++i)
        {
         values[i] = QM_ATR(_Symbol, PERIOD_D1, m_atr_period, i + 2);
         if(values[i] <= 0.0)
            return 0.0;
        }

      ArraySort(values);
      double p = percentile;
      if(p < 0.0)
         p = 0.0;
      if(p > 100.0)
         p = 100.0;

      const int index = (int)MathRound((p / 100.0) * (bars - 1));
      return values[index];
     }

   // Ported 1:1 from AtrRegimeAllowsEntry(), hard PERIOD_D1.
   bool AtrRegimeAllowsEntry()
     {
      if(!m_atr_regime_filter)
         return true;

      const double atr = QM_ATR(_Symbol, PERIOD_D1, m_atr_period, 1);
      const double threshold = PercentileATR(m_atr_regime_window, m_atr_regime_percentile);
      if(atr <= 0.0 || threshold <= 0.0)
         return false;

      return (atr > threshold);
     }

   // Ported 1:1 from SpreadAllowsEntry().
   bool SpreadAllowsEntry()
     {
      if(m_max_spread_points <= 0.0)
         return true;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return false;

      return ((ask - bid) / point <= m_max_spread_points);
     }

   // Ported 1:1 from InitRequest(), hard PERIOD_D1.
   void InitRequest(QM_EntryRequest &req)
     {
      req.type = QM_BUY_STOP;
      req.price = 0.0;
      req.sl = 0.0;
      req.tp = 0.0;
      req.reason = "";
      req.symbol_slot = 0;

      const int seconds = PeriodSeconds(PERIOD_D1);
      req.expiration_seconds = (seconds > 0) ? MathMax(seconds, m_pending_expiry_bars * seconds) : 86400;
     }

   // Ported 1:1 from BuildStopRequest(), hard PERIOD_D1.
   bool BuildStopRequest(const QM_OrderType side,
                         const double entry_price,
                         const double channel_stop,
                         QM_EntryRequest &req)
     {
      InitRequest(req);

      const double atr = QM_ATR(_Symbol, PERIOD_D1, m_atr_period, 1);
      if(atr <= 0.0 || entry_price <= 0.0 || channel_stop <= 0.0)
         return false;

      const double atr_stop = (side == QM_BUY_STOP)
                              ? entry_price - m_atr_stop_mult * atr
                              : entry_price + m_atr_stop_mult * atr;
      const double stop_price = (side == QM_BUY_STOP)
                                ? MathMax(channel_stop, atr_stop)
                                : MathMin(channel_stop, atr_stop);

      if(side == QM_BUY_STOP && stop_price >= entry_price)
         return false;
      if(side == QM_SELL_STOP && stop_price <= entry_price)
         return false;

      req.type = side;
      req.price = QM_TM_NormalizePrice(_Symbol, entry_price);
      req.sl = QM_TM_NormalizePrice(_Symbol, stop_price);
      req.tp = 0.0;
      req.reason = (side == QM_BUY_STOP) ? "ET_TURTLE20X_LONG_STOP" : "ET_TURTLE20X_SHORT_STOP";
      return true;
     }

public:
   // Ported 1:1 from Strategy_NoTradeFilter(). The standalone's exposure
   // exception exists so a wide spread does not also block management/exit
   // in its single unified per-tick gate; the master dispatcher already runs
   // ManageOpen()/CheckExit() unconditionally regardless of NoTrade(), so
   // this exception only affects entry gating here, which is a no-op
   // because CheckEntry() carries its own HasOurExposure() guard below.
   // Kept 1:1 anyway for structural fidelity with the standalone.
   virtual bool NoTrade(datetime now)
     {
      MqlDateTime dt;
      TimeToStruct(now, dt);
      if(dt.day_of_week == 0 || dt.day_of_week == 6)
         return true;

      if(!SpreadAllowsEntry() && !HasOurExposure())
         return true;

      return false;
     }

   // Ported 1:1 from Strategy_ManageOpenPosition().
   virtual void ManageOpen()
     {
      const long magic = Magic();

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return;

      const double long_exit = LowestLow(1, m_exit_channel);
      const double short_exit = HighestHigh(1, m_exit_channel);
      if(long_exit <= 0.0 || short_exit <= 0.0)
         return;

      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(!QM_ModuleOwnsPosition(magic))
            continue;

         const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double current_sl = PositionGetDouble(POSITION_SL);
         const double target_sl = QM_TM_NormalizePrice(_Symbol, (type == POSITION_TYPE_BUY) ? long_exit : short_exit);

         if(type == POSITION_TYPE_BUY && target_sl > 0.0 &&
            (current_sl <= 0.0 || target_sl > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "ET_TURTLE20X_10DAY_EXIT_STOP");

         if(type == POSITION_TYPE_SELL && target_sl > 0.0 &&
            (current_sl <= 0.0 || target_sl < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "ET_TURTLE20X_10DAY_EXIT_STOP");
        }
     }

   // Ported 1:1 from Strategy_ExitSignal() + its OnTick close loop. Two-pass
   // (find trigger, then close all own-magic positions) preserved — see
   // class header for why this cannot collapse to one pass like the pilot.
   virtual void CheckExit()
     {
      const long magic = Magic();

      const double long_exit = LowestLow(1, m_exit_channel);
      const double short_exit = HighestHigh(1, m_exit_channel);
      if(long_exit <= 0.0 || short_exit <= 0.0)
         return;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0)
         return;

      bool should_exit = false;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(!QM_ModuleOwnsPosition(magic))
            continue;

         const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(type == POSITION_TYPE_BUY && bid <= long_exit)
           {
            should_exit = true;
            break;
           }
         if(type == POSITION_TYPE_SELL && ask >= short_exit)
           {
            should_exit = true;
            break;
           }
        }

      if(!should_exit)
         return;

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

   // Ported 1:1 from Strategy_EntrySignal(); the standalone's straddle
   // (opening both legs when both are valid) is preserved — see class
   // header. Sizing is the Phase-3 dual-mode requirement: explicit magic +
   // explicit (RiskMode(), RiskValue()), never the global risk context.
   virtual void CheckEntry()
     {
      if(m_entry_channel < 2 || m_exit_channel < 1 ||
         m_atr_period < 1 || m_atr_stop_mult <= 0.0)
         return;
      if(HasOurExposure())
         return;
      if(!AtrRegimeAllowsEntry())
         return;

      const double entry_high = HighestHigh(1, m_entry_channel);
      const double entry_low = LowestLow(1, m_entry_channel);
      const double exit_low = LowestLow(1, m_exit_channel);
      const double exit_high = HighestHigh(1, m_exit_channel);
      if(entry_high <= 0.0 || entry_low <= 0.0 || exit_low <= 0.0 || exit_high <= 0.0)
         return;

      QM_EntryRequest buy_req;
      QM_EntryRequest sell_req;
      const bool can_buy = BuildStopRequest(QM_BUY_STOP, entry_high, exit_low, buy_req);
      const bool can_sell = BuildStopRequest(QM_SELL_STOP, entry_low, exit_high, sell_req);

      if(can_buy)
        {
         ulong buy_ticket = 0;
         QM_TM_OpenPosition(buy_req, buy_ticket, (int)Magic(), m_risk_mode, m_risk_value);
        }
      if(can_sell)
        {
         ulong sell_ticket = 0;
         QM_TM_OpenPosition(sell_req, sell_ticket, (int)Magic(), m_risk_mode, m_risk_value);
        }
     }
  };

#endif // QM_MOD_ETTURTLE20X_MQH
