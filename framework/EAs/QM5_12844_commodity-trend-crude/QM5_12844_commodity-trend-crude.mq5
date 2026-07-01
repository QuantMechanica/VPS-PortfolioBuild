#property strict
#property version   "5.0"
#property description "QM5_12844 Crude Commodity Trend Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12844 - Crude Commodity Trend Breakout
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - closed-bar 20-bar Donchian breakout
//   - ADX(11) trend-state gate
//   - ATR(14) hard stop, ATR trail, 10-bar opposite-channel exit, time stop
// Runtime uses MT5 OHLC and framework indicator helpers only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12844;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_period         = 20;
input int    strategy_exit_period          = 10;
input int    strategy_adx_period           = 11;
input double strategy_adx_threshold        = 20.0;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 3.0;
input double strategy_atr_trail_mult       = 3.0;
input double strategy_trail_activation_atr = 1.0;
input int    strategy_max_hold_days        = 45;
input int    strategy_max_spread_points    = 1000;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_LoadClosedState(double &close_last,
                              datetime &closed_time,
                              double &entry_high,
                              double &entry_low,
                              double &exit_high,
                              double &exit_low,
                              double &adx_value,
                              double &atr_value)
  {
   const int bars_needed = MathMax(strategy_entry_period, strategy_exit_period) + 1;
   if(bars_needed <= 2)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: bounded D1 channel math on closed-bar path.
   if(copied < bars_needed)
      return false;

   close_last = rates[0].close;
   closed_time = rates[0].time;
   if(close_last <= 0.0 || closed_time <= 0)
      return false;

   entry_high = -DBL_MAX;
   entry_low = DBL_MAX;
   for(int i = 1; i <= strategy_entry_period; ++i)
     {
      if(rates[i].high > entry_high)
         entry_high = rates[i].high;
      if(rates[i].low < entry_low)
         entry_low = rates[i].low;
     }

   exit_high = -DBL_MAX;
   exit_low = DBL_MAX;
   for(int j = 1; j <= strategy_exit_period; ++j)
     {
      if(rates[j].high > exit_high)
         exit_high = rates[j].high;
      if(rates[j].low < exit_low)
         exit_low = rates[j].low;
     }

   adx_value = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   return (entry_high > 0.0 &&
           entry_low > 0.0 &&
           exit_high > 0.0 &&
           exit_low > 0.0 &&
           adx_value > 0.0 &&
           atr_value > 0.0);
  }

bool Strategy_CloseOppositeChannel(const double close_last,
                                   const double exit_high,
                                   const double exit_low)
  {
   const int magic = QM_FrameworkMagic();
   bool closed_any = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_exit = false;
      if(position_type == POSITION_TYPE_BUY && close_last < exit_low)
         should_exit = true;
      if(position_type == POSITION_TYPE_SELL && close_last > exit_high)
         should_exit = true;

      if(should_exit)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         closed_any = true;
        }
     }

   return closed_any;
  }

bool Strategy_BuildEntryRequest(const QM_OrderType side,
                                const double atr_value,
                                QM_EntryRequest &req)
  {
   req.type = side;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "XTI_DONCHIAN_ADX_LONG" : "XTI_DONCHIAN_ADX_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_value, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_entry_period < 5 || strategy_exit_period < 2 || strategy_exit_period > strategy_entry_period)
      return true;
   if(strategy_adx_period <= 0 || strategy_adx_threshold < 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_atr_trail_mult <= 0.0)
      return true;
   if(strategy_trail_activation_atr < 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12844_COMMODITY_TREND_CRUDE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   double close_last = 0.0;
   datetime closed_time = 0;
   double entry_high = 0.0;
   double entry_low = 0.0;
   double exit_high = 0.0;
   double exit_low = 0.0;
   double adx_value = 0.0;
   double atr_value = 0.0;
   if(!Strategy_LoadClosedState(close_last,
                                closed_time,
                                entry_high,
                                entry_low,
                                exit_high,
                                exit_low,
                                adx_value,
                                atr_value))
      return false;

   if(Strategy_CloseOppositeChannel(close_last, exit_high, exit_low))
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(adx_value <= strategy_adx_threshold)
      return false;

   if(close_last > entry_high)
      return Strategy_BuildEntryRequest(QM_BUY, atr_value, req);
   if(close_last < entry_low)
      return Strategy_BuildEntryRequest(QM_SELL, atr_value, req);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
        }

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(open_price <= 0.0 || market_price <= 0.0 || atr_value <= 0.0)
         continue;

      const double favorable = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(favorable >= atr_value * strategy_trail_activation_atr)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_trail_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12844\",\"ea\":\"commodity-trend-crude\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
