#ifndef QM_MOD_MQL5ICHIMOKU_MQH
#define QM_MOD_MQL5ICHIMOKU_MQH

#include "../QM_StrategyModule.mqh"

// Phase-3-REST — CQMStrategyModule port of the standalone QM5_10513
// mql5-ichimoku EA (XAUUSD.DWX, D1). Entry/Exit/Manage/NoTrade mechanics and
// strategy input defaults are taken 1:1 from
// framework/EAs/QM5_10513_mql5-ichimoku/QM5_10513_mql5-ichimoku.mq5 (its
// XAUUSD backtest set carries no strategy_* overrides, so the .mq5 input
// defaults ARE the verified backtest config).
// Original identity preserved: Magic() = 105130003 (ea_id 10513, slot 3).
//
// Differences from the standalone are framework-lifecycle only:
//  - TF() is hard PERIOD_D1 instead of the standalone's `strategy_signal_tf`
//    input; the master dispatcher gates entries on this module's own TF
//    new-bar, so chart TF is never consulted.
//  - Entry sizes via the explicit Phase-2.5 dual-mode path
//    (QM_TM_OpenPosition(..., Magic(), RiskMode(), RiskValue())) instead of
//    the standalone's global risk context — no global risk state is read.
//  - CheckExit() collapses the standalone's two-pass "find trigger, then
//    close all own-magic positions" to one pass because this strategy only
//    ever opens plain market orders (no pending straddle like 10403), so
//    duplicate-entry protection in QM_EntryInternal guarantees at most one
//    open position per (magic, symbol) at a time.
//  - Indicator handles are the framework's pooled handles (QM_Indicators.mqh
//    is not used here — Ichimoku midpoints read iHighest/iLowest/iHigh/iLow/
//    iClose directly, exactly as the standalone did; these are structural
//    OHLC reads, not indicator buffers).
class CQMModMql5Ichimoku : public CQMStrategyModule
  {
private:
   bool        m_enabled;
   QM_RiskMode m_risk_mode;
   double      m_risk_value;

   // Strategy inputs — identical defaults to the standalone EA / its
   // verified backtest set (QM5_10513_mql5-ichimoku_XAUUSD.DWX_D1_backtest.set).
   int    m_tenkan_period;
   int    m_kijun_period;
   int    m_senkou_b_period;
   int    m_atr_period;
   double m_atr_sl_mult;
   double m_tp_rr;
   int    m_max_spread_points;
   bool   m_session_enabled;
   int    m_session_start_hhmm;
   int    m_session_end_hhmm;

public:
   CQMModMql5Ichimoku()
     {
      m_enabled             = false;
      m_risk_mode           = QM_RISK_MODE_UNSET;
      m_risk_value          = 0.0;
      m_tenkan_period       = 9;
      m_kijun_period        = 26;
      m_senkou_b_period     = 52;
      m_atr_period          = 14;
      m_atr_sl_mult         = 1.5;
      m_tp_rr               = 1.5;
      m_max_spread_points   = 0;
      m_session_enabled     = false;
      m_session_start_hhmm  = 0;
      m_session_end_hhmm    = 2359;
     }

   void Configure(const bool enabled, const QM_RiskMode risk_mode, const double risk_value)
     {
      m_enabled    = enabled;
      m_risk_mode  = risk_mode;
      m_risk_value = risk_value;
     }

   virtual bool             Enabled()   const { return m_enabled; }
   virtual long              Magic()     const { return 105130003L; }
   virtual ENUM_TIMEFRAMES  TF()        const { return PERIOD_D1; }
   virtual QM_RiskMode      RiskMode()  const { return m_risk_mode; }
   virtual double           RiskValue() const { return m_risk_value; }

private:
   // Ported 1:1 from Strategy_Midpoint(), hard PERIOD_D1.
   bool Midpoint(const int period, const int shift, double &out_value)
     {
      out_value = 0.0;
      if(period <= 0 || shift < 0)
         return false;

      const int hi_shift = iHighest(_Symbol, PERIOD_D1, MODE_HIGH, period, shift);
      const int lo_shift = iLowest(_Symbol, PERIOD_D1, MODE_LOW, period, shift);
      if(hi_shift < 0 || lo_shift < 0)
         return false;

      const double high = iHigh(_Symbol, PERIOD_D1, hi_shift);
      const double low = iLow(_Symbol, PERIOD_D1, lo_shift);
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;

      out_value = (high + low) * 0.5;
      return true;
     }

   // Ported 1:1 from Strategy_IchimokuSnapshot(), hard PERIOD_D1.
   bool IchimokuSnapshot(const int card_shift,
                         double &tenkan,
                         double &kijun,
                         double &span_b,
                         double &close_price)
     {
      tenkan = 0.0;
      kijun = 0.0;
      span_b = 0.0;
      close_price = 0.0;

      if(m_tenkan_period <= 0 || m_kijun_period <= 0 || m_senkou_b_period <= 0)
         return false;

      const int mt5_shift = card_shift + 1; // card [0] is the latest completed bar

      if(!Midpoint(m_tenkan_period, mt5_shift, tenkan))
         return false;
      if(!Midpoint(m_kijun_period, mt5_shift, kijun))
         return false;
      if(!Midpoint(m_senkou_b_period, mt5_shift, span_b))
         return false;

      close_price = iClose(_Symbol, PERIOD_D1, mt5_shift);
      return (close_price > 0.0);
     }

   // Ported 1:1 from Strategy_OppositeSignal().
   int OppositeSignal()
     {
      double tenkan_0 = 0.0;
      double kijun_0 = 0.0;
      double span_b_0 = 0.0;
      double close_0 = 0.0;
      double tenkan_1 = 0.0;
      double kijun_1 = 0.0;
      double span_b_1 = 0.0;
      double close_1 = 0.0;

      if(!IchimokuSnapshot(0, tenkan_0, kijun_0, span_b_0, close_0))
         return 0;
      if(!IchimokuSnapshot(1, tenkan_1, kijun_1, span_b_1, close_1))
         return 0;

      if(tenkan_1 < kijun_0 && tenkan_0 >= kijun_0 && close_0 > span_b_0)
         return 1;
      if(tenkan_1 > kijun_0 && tenkan_0 <= kijun_0 && close_0 < span_b_0)
         return -1;

      return 0;
     }

public:
   // Ported 1:1 from Strategy_NoTradeFilter().
   virtual bool NoTrade(datetime now)
     {
      if(m_max_spread_points > 0)
        {
         const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if(spread_points > m_max_spread_points)
            return true;
        }

      if(m_session_enabled)
        {
         MqlDateTime dt;
         TimeToStruct(now, dt);
         const int hhmm = dt.hour * 100 + dt.min;
         if(m_session_start_hhmm <= m_session_end_hhmm)
           {
            if(hhmm < m_session_start_hhmm || hhmm > m_session_end_hhmm)
               return true;
           }
         else
           {
            if(hhmm > m_session_end_hhmm && hhmm < m_session_start_hhmm)
               return true;
           }
        }

      return false;
     }

   // Ported 1:1 from Strategy_ManageOpenPosition(): card specifies no
   // trailing, break-even, pyramiding, or partial close.
   virtual void ManageOpen() {}

   // Ported 1:1 from Strategy_ExitSignal() + its OnTick close loop, collapsed
   // to one pass — see class header.
   virtual void CheckExit()
     {
      const int signal = OppositeSignal();
      if(signal == 0)
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

         const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         bool should_exit = false;
         if(type == POSITION_TYPE_BUY && signal < 0)
            should_exit = true;
         if(type == POSITION_TYPE_SELL && signal > 0)
            should_exit = true;

         if(should_exit)
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Ported 1:1 from Strategy_EntrySignal(). Sizing is the Phase-3 dual-mode
   // requirement: explicit magic + explicit (RiskMode(), RiskValue()), never
   // the global risk context. No explicit exposure guard needed: this
   // strategy only opens plain market orders, so the duplicate-position
   // reject inside QM_EntryInternal is sufficient (matches the standalone,
   // which also relied on it).
   virtual void CheckEntry()
     {
      if(m_atr_period <= 0 || m_atr_sl_mult <= 0.0 || m_tp_rr <= 0.0)
         return;

      const int signal = OppositeSignal();
      if(signal == 0)
         return;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0)
         return;

      QM_EntryRequest req;
      req.symbol_slot = 0;
      req.expiration_seconds = 0;

      if(signal > 0)
        {
         req.type = QM_BUY;
         req.sl = QM_StopATR(_Symbol, req.type, ask, m_atr_period, m_atr_sl_mult);
         req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, m_tp_rr);
         req.reason = "ICHIMOKU_TK_CROSS_CLOUD_LONG";
         if(!(req.sl > 0.0 && req.sl < ask && req.tp > ask))
            return;
        }
      else
        {
         req.type = QM_SELL;
         req.sl = QM_StopATR(_Symbol, req.type, bid, m_atr_period, m_atr_sl_mult);
         req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, m_tp_rr);
         req.reason = "ICHIMOKU_TK_CROSS_CLOUD_SHORT";
         if(!(req.sl > bid && req.tp > 0.0 && req.tp < bid))
            return;
        }

      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket, (int)Magic(), m_risk_mode, m_risk_value);
     }
  };

#endif // QM_MOD_MQL5ICHIMOKU_MQH
