#property strict
#property version   "5.0"
#property description "QM5_11575 robo-32points-d1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11575;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_offset_pips      = 32;
input int    strategy_tp_pips                = 35;
input int    strategy_sl_pips                = 28;
input int    strategy_pending_expiry_hours   = 23;
input int    strategy_friday_cutoff_hour     = 21;
input int    strategy_spread_cap_tenths_pips = 25;

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_tenths_pips) / 10.0;
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      QM_TM_RemovePendingOrder(ticket, "robo32_new_day_cancel");
     }

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hour)
      return false;

   const double prev_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: literal card input, single closed D1 bar, called only behind framework QM_IsNewBar gate
   if(prev_close <= 0.0)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_offset_pips);
   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   if(offset <= 0.0 || sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   const double buy_stop_price = QM_StopRulesNormalizePrice(_Symbol, prev_close + offset);
   const double sell_stop_price = QM_StopRulesNormalizePrice(_Symbol, prev_close - offset);
   if(buy_stop_price <= 0.0 || sell_stop_price <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool buy_leg_crossed = (ask >= buy_stop_price);
   const bool sell_leg_crossed = (bid <= sell_stop_price);
   if(buy_leg_crossed && sell_leg_crossed)
     {
      QM_LogEvent(QM_WARN, "ROBO32_GAP_SKIP",
                  StringFormat("{\"prev_close\":%.8f,\"buy_stop\":%.8f,\"sell_stop\":%.8f,\"ask\":%.8f,\"bid\":%.8f}",
                               prev_close, buy_stop_price, sell_stop_price, ask, bid));
      return false;
     }

   const int expiry_seconds = (strategy_pending_expiry_hours > 0) ? strategy_pending_expiry_hours * 3600 : 0;

   if(!sell_leg_crossed)
     {
      QM_EntryRequest sell_req;
      sell_req.type = QM_SELL_STOP;
      sell_req.price = sell_stop_price;
      sell_req.sl = QM_StopRulesNormalizePrice(_Symbol, sell_stop_price + sl_dist);
      sell_req.tp = QM_StopRulesNormalizePrice(_Symbol, sell_stop_price - tp_dist);
      sell_req.reason = "robo32_sell_stop";
      sell_req.symbol_slot = qm_magic_slot_offset;
      sell_req.expiration_seconds = expiry_seconds;

      ulong sell_ticket = 0;
      QM_TM_OpenPosition(sell_req, sell_ticket);
     }

   if(buy_leg_crossed)
      return false;

   req.type = QM_BUY_STOP;
   req.price = buy_stop_price;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, buy_stop_price - sl_dist);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, buy_stop_price + tp_dist);
   req.reason = "robo32_buy_stop";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      QM_TM_RemovePendingOrder(ticket, "robo32_opposite_on_fill");
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
