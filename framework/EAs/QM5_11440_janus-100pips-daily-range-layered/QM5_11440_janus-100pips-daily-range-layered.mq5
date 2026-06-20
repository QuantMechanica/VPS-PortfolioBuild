#property strict
#property version   "5.0"
#property description "QM5_11440 JanusTrader 100-Pips Daily Range P2 OCO"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11440;
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
input int    strategy_range_bars_h1       = 24;
input int    strategy_reset_hour_broker   = 1;
input int    strategy_offset_pips         = 7;
input int    strategy_tp_pips             = 35;
input int    strategy_sl_pips             = 25;
input int    strategy_max_spread_pips     = 15;

int g_last_setup_ymd = 0;

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(max_spread <= 0.0)
      return false;

   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > max_spread)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.hour != strategy_reset_hour_broker)
      return false;

   const int setup_ymd = now_dt.year * 10000 + now_dt.mon * 100 + now_dt.day;
   if(g_last_setup_ymd == setup_ymd)
      return false;

   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      has_position = true;
      break;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const long order_type = OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, "JANUS_DAILY_EXPIRY");
     }

   if(has_position)
     {
      g_last_setup_ymd = setup_ymd;
      return false;
     }

   int lookback = strategy_range_bars_h1;
   if(lookback < 1)
      lookback = 24;

   double daily_high = -DBL_MAX;
   double daily_low = DBL_MAX;
   int samples = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double bar_high = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: 24-bar session range at reset only
      const double bar_low = iLow(_Symbol, PERIOD_H1, shift);   // perf-allowed: 24-bar session range at reset only
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high <= bar_low)
         continue;
      if(bar_high > daily_high)
         daily_high = bar_high;
      if(bar_low < daily_low)
         daily_low = bar_low;
      samples++;
     }
   if(samples <= 0 || daily_high <= 0.0 || daily_low <= 0.0 || daily_high <= daily_low)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_offset_pips);
   if(offset <= 0.0)
      return false;

   const double buy_entry = QM_StopRulesNormalizePrice(_Symbol, daily_high + offset);
   const double sell_entry = QM_StopRulesNormalizePrice(_Symbol, daily_low - offset);
   if(buy_entry <= 0.0 || sell_entry <= 0.0)
      return false;

   QM_EntryRequest sell_req;
   sell_req.type = QM_SELL_STOP;
   sell_req.price = sell_entry;
   sell_req.sl = QM_StopFixedPips(_Symbol, QM_SELL_STOP, sell_entry, strategy_sl_pips);
   sell_req.tp = QM_TakeFixedPips(_Symbol, QM_SELL_STOP, sell_entry, strategy_tp_pips);
   sell_req.reason = "JANUS_SELL_STOP_P2";
   sell_req.symbol_slot = qm_magic_slot_offset;
   sell_req.expiration_seconds = 24 * 3600;

   if(sell_req.sl <= 0.0 || sell_req.tp <= 0.0)
      return false;

   ulong sell_ticket = 0;
   QM_TM_OpenPosition(sell_req, sell_ticket);

   req.type = QM_BUY_STOP;
   req.price = buy_entry;
   req.sl = QM_StopFixedPips(_Symbol, QM_BUY_STOP, buy_entry, strategy_sl_pips);
   req.tp = QM_TakeFixedPips(_Symbol, QM_BUY_STOP, buy_entry, strategy_tp_pips);
   req.reason = "JANUS_BUY_STOP_P2";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 24 * 3600;

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   g_last_setup_ymd = setup_ymd;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   bool has_buy = false;
   bool has_sell = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long position_type = PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY)
         has_buy = true;
      if(position_type == POSITION_TYPE_SELL)
         has_sell = true;
     }

   if(!has_buy && !has_sell)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const long order_type = OrderGetInteger(ORDER_TYPE);
      if(has_buy && order_type == ORDER_TYPE_SELL_STOP)
         QM_TM_RemovePendingOrder(ticket, "JANUS_OCO_LONG_FILLED");
      if(has_sell && order_type == ORDER_TYPE_BUY_STOP)
         QM_TM_RemovePendingOrder(ticket, "JANUS_OCO_SHORT_FILLED");
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

   g_last_setup_ymd = 0;
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
