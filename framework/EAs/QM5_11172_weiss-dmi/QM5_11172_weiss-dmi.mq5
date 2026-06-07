#property strict
#property version   "5.0"
#property description "QM5_11172 Weissman DMI Threshold Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11172;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_dmi_period        = 10;
input double strategy_entry_threshold   = 20.0;
input int    strategy_atr_period        = 20;
input double strategy_atr_stop_mult     = 3.0;

// No Trade Filter: time/spread/news are handled by the framework; this card only restricts the base timeframe.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   return false;
  }

// Trade Entry: completed-bar DMI directional-difference threshold cross.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_dmi_period <= 0 || strategy_entry_threshold <= 0.0 ||
      strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double plus_now = QM_ADX_PlusDI(_Symbol, PERIOD_D1, strategy_dmi_period, 1);
   const double minus_now = QM_ADX_MinusDI(_Symbol, PERIOD_D1, strategy_dmi_period, 1);
   const double plus_prev = QM_ADX_PlusDI(_Symbol, PERIOD_D1, strategy_dmi_period, 2);
   const double minus_prev = QM_ADX_MinusDI(_Symbol, PERIOD_D1, strategy_dmi_period, 2);
   if((plus_now <= 0.0 && minus_now <= 0.0) || (plus_prev <= 0.0 && minus_prev <= 0.0))
      return false;

   const double ddif_now = plus_now - minus_now;
   const double ddif_prev = plus_prev - minus_prev;
   int cross = 0;
   if(ddif_prev <= strategy_entry_threshold && ddif_now > strategy_entry_threshold)
      cross = 1;
   else if(ddif_prev >= -strategy_entry_threshold && ddif_now < -strategy_entry_threshold)
      cross = -1;
   if(cross == 0)
      return false;

   req.type = (cross > 0) ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(point <= 0.0 || atr <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double broker_min_distance = MathMax(0, stops_level) * point;
   const double stop_distance = MathMax(atr * strategy_atr_stop_mult, broker_min_distance);
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, stop_distance, 1.0);
   if(req.sl <= 0.0)
      return false;

   req.reason = (cross > 0) ? "weiss_dmi_ddif_above_20" : "weiss_dmi_ddif_below_minus_20";
   return true;
  }

// Trade Management: restore the card's catastrophic ATR stop if a broker/session event removes it.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetDouble(POSITION_SL) > 0.0)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(open_price <= 0.0 || point <= 0.0 || atr <= 0.0)
         continue;

      const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const double broker_min_distance = MathMax(0, stops_level) * point;
      const double stop_distance = MathMax(atr * strategy_atr_stop_mult, broker_min_distance);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const QM_OrderType side = (position_type == POSITION_TYPE_BUY) ? QM_BUY : QM_SELL;
      const double protective_sl = QM_StopATRFromValue(_Symbol, side, open_price, stop_distance, 1.0);
      if(protective_sl > 0.0)
         QM_TM_MoveSL(ticket, protective_sl, "weiss_dmi_catastrophic_stop_restore");
     }
  }

// Trade Close: zero-line DDIF cross exits to flat.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_dmi_period <= 0)
      return false;

   const double plus_now = QM_ADX_PlusDI(_Symbol, PERIOD_D1, strategy_dmi_period, 1);
   const double minus_now = QM_ADX_MinusDI(_Symbol, PERIOD_D1, strategy_dmi_period, 1);
   const double plus_prev = QM_ADX_PlusDI(_Symbol, PERIOD_D1, strategy_dmi_period, 2);
   const double minus_prev = QM_ADX_MinusDI(_Symbol, PERIOD_D1, strategy_dmi_period, 2);
   if((plus_now <= 0.0 && minus_now <= 0.0) || (plus_prev <= 0.0 && minus_prev <= 0.0))
      return false;

   const double ddif_now = plus_now - minus_now;
   const double ddif_prev = plus_prev - minus_prev;
   const bool long_exit = (ddif_prev >= 0.0 && ddif_now < 0.0);
   const bool short_exit = (ddif_prev <= 0.0 && ddif_now > 0.0);
   if(!long_exit && !short_exit)
      return false;

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
      if(position_type == POSITION_TYPE_BUY && long_exit)
         return true;
      if(position_type == POSITION_TYPE_SELL && short_exit)
         return true;
     }

   return false;
  }

// News Filter Hook: defer to the central P8-callable framework news filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11172_weiss-dmi\",\"source_id\":\"3005c768-aa91-5daf-9dd7-500d7bfcb7a6\"}");
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
