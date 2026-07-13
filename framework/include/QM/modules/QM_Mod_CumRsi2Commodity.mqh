#ifndef QM_MOD_CUMRSI2COMMODITY_MQH
#define QM_MOD_CUMRSI2COMMODITY_MQH

#include "../QM_StrategyModule.mqh"

// Phase-3 PILOT — CQMStrategyModule port of the standalone
// QM5_12567_cum-rsi2-commodity EA (XAUUSD.DWX, D1). Entry/Exit/Manage/NoTrade
// mechanics and strategy input defaults are taken 1:1 from
// framework/EAs/QM5_12567_cum-rsi2-commodity/QM5_12567_cum-rsi2-commodity.mq5.
// Original identity preserved: Magic() = 125670003 (ea_id 12567, slot 3).
//
// Differences from the standalone are framework-lifecycle only:
//  - TF() is hard PERIOD_D1 instead of the standalone's `_Period != PERIOD_D1`
//    NoTradeFilter check; the master dispatcher gates entries on this module's
//    own TF new-bar, so the chart-period guard has no equivalent here.
//  - Entry sizes via the explicit Phase-2.5 dual-mode path
//    (QM_TM_OpenPosition(..., Magic(), RiskMode(), RiskValue())) instead of
//    the standalone's global risk context — no global risk state is read.
//  - Indicator handles are the framework's pooled handles (QM_Indicators.mqh),
//    exactly as the standalone used them; there is no per-instance handle to
//    create in Init() or release in Deinit().
class CQMModCumRsi2Commodity : public CQMStrategyModule
  {
private:
   bool        m_enabled;
   QM_RiskMode m_risk_mode;
   double      m_risk_value;

   // Strategy inputs — identical defaults to the standalone EA / its
   // verified backtest set (QM5_12567_cum-rsi2-commodity_XAUUSD.DWX_D1_backtest.set).
   int    m_rsi_period;
   int    m_cum_window;
   double m_cum_rsi_entry;
   double m_rsi_exit;
   int    m_sma_period;
   int    m_atr_period;
   double m_atr_sl_mult;
   int    m_max_hold_bars;
   int    m_max_spread_points;

public:
   CQMModCumRsi2Commodity()
     {
      m_enabled           = false;
      m_risk_mode         = QM_RISK_MODE_UNSET;
      m_risk_value        = 0.0;
      m_rsi_period         = 2;
      m_cum_window         = 2;
      m_cum_rsi_entry      = 35.0;
      m_rsi_exit           = 65.0;
      m_sma_period         = 200;
      m_atr_period         = 14;
      m_atr_sl_mult        = 2.5;
      m_max_hold_bars      = 5;
      m_max_spread_points  = 300;
     }

   void Configure(const bool enabled, const QM_RiskMode risk_mode, const double risk_value)
     {
      m_enabled    = enabled;
      m_risk_mode  = risk_mode;
      m_risk_value = risk_value;
     }

   virtual bool             Enabled()   const { return m_enabled; }
   virtual long              Magic()     const { return 125670003L; }
   virtual ENUM_TIMEFRAMES  TF()        const { return PERIOD_D1; }
   virtual QM_RiskMode      RiskMode()  const { return m_risk_mode; }
   virtual double           RiskValue() const { return m_risk_value; }

   // Ported 1:1 from Strategy_NoTradeFilter(); the `_Period != PERIOD_D1`
   // chart-timeframe guard is dropped because the master dispatcher already
   // gates this module's entries on its own hard TF() (see class header).
   virtual bool NoTrade(datetime now)
     {
      if(m_max_spread_points > 0)
        {
         const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if(spread_points > m_max_spread_points)
            return true;
        }
      return false;
     }

   // Ported 1:1 from Strategy_ManageOpenPosition(): card specifies no
   // trailing, break-even, pyramiding, or partial close.
   virtual void ManageOpen() {}

   // Ported 1:1 from Strategy_ExitSignal() + its OnTick close loop. The
   // standalone's two-pass "find trigger, then close all own-magic
   // positions" collapses to one pass here because duplicate-entry
   // protection in QM_EntryInternal guarantees at most one open position per
   // (magic, symbol) at a time.
   virtual void CheckExit()
     {
      const long magic = Magic();
      const double rsi_last = QM_RSI(_Symbol, PERIOD_D1, m_rsi_period, 1, PRICE_CLOSE);

      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(!QM_ModuleOwnsPosition(magic))
            continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;

         bool should_exit = (rsi_last > m_rsi_exit);
         if(!should_exit)
           {
            const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
            const int bars_since_open = iBarShift(_Symbol, PERIOD_D1, open_time, false);
            should_exit = (bars_since_open >= m_max_hold_bars);
           }

         if(should_exit)
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Ported 1:1 from Strategy_EntrySignal(). Sizing is the Phase-3 dual-mode
   // requirement: explicit magic + explicit (RiskMode(), RiskValue()), never
   // the global risk context.
   virtual void CheckEntry()
     {
      if(m_rsi_period <= 0 ||
         m_cum_window != 2 ||
         m_cum_rsi_entry <= 0.0 || m_cum_rsi_entry >= 200.0 ||
         m_rsi_exit <= 0.0 || m_rsi_exit >= 100.0 ||
         m_sma_period <= 0 ||
         m_atr_period <= 0 ||
         m_atr_sl_mult <= 0.0 ||
         m_max_hold_bars <= 0)
         return;

      const double close_last = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
      const double sma_last   = QM_SMA(_Symbol, PERIOD_D1, m_sma_period, 1, PRICE_CLOSE);
      const double rsi_last   = QM_RSI(_Symbol, PERIOD_D1, m_rsi_period, 1, PRICE_CLOSE);
      const double rsi_prev   = QM_RSI(_Symbol, PERIOD_D1, m_rsi_period, 2, PRICE_CLOSE);
      if(close_last <= 0.0 || sma_last <= 0.0 || rsi_last <= 0.0 || rsi_prev <= 0.0)
         return;

      const double cumulative_rsi = rsi_last + rsi_prev;
      if(close_last <= sma_last || cumulative_rsi >= m_cum_rsi_entry)
         return;

      const double entry_price = QM_EntryMarketPrice(QM_BUY);
      if(entry_price <= 0.0)
         return;

      QM_EntryRequest req;
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, m_atr_period, m_atr_sl_mult);
      if(req.sl <= 0.0)
         return;
      req.reason = "TM_CUM_RSI2_LONG";

      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket, (int)Magic(), m_risk_mode, m_risk_value);
     }
  };

#endif // QM_MOD_CUMRSI2COMMODITY_MQH
