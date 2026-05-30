#property strict
#property version   "5.0"
#property description "QM5_1120 Big Ben London Open Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1120;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_timeframe_minutes       = 15;
input int    strategy_range_start_hour_broker = 0;
input int    strategy_range_end_hour_broker   = 7;
input int    strategy_entry_start_hour_broker = 7;
input int    strategy_cancel_hour_broker      = 11;
input int    strategy_exit_hour_broker        = 19;
input int    strategy_breakout_buffer_points  = 5;
input int    strategy_max_spread_points       = 25;
input double strategy_rr_target               = 2.0;
input bool   strategy_use_atr_stop            = false;
input int    strategy_atr_period              = 14;
input double strategy_atr_stop_mult           = 1.0;
input bool   strategy_mon_thu_only            = false;

datetime g_last_order_day = 0;
datetime g_last_cancel_day = 0;
datetime g_last_exit_day = 0;
datetime g_last_range_day = 0;
double   g_range_high = 0.0;
double   g_range_low = 0.0;

int ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

datetime BrokerMidnight(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime BrokerDateTimeAtHour(const datetime anchor, const int hour)
  {
   MqlDateTime dt;
   TimeToStruct(anchor, dt);
   dt.hour = ClampInt(hour, 0, 23);
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool HasOpenPositionForMagic()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

int PendingOrderCountForMagic()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic)
         ++count;
     }
   return count;
  }

bool DeletePendingOrder(const ulong ticket, const string reason)
  {
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   request.symbol = _Symbol;
   request.comment = reason;

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);
   QM_LogEvent(ok ? QM_INFO : QM_WARN,
               "PENDING_DELETE",
               StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
                            ticket,
                            QM_LoggerEscapeJson(reason),
                            ok ? "true" : "false",
                            result.retcode,
                            QM_LoggerEscapeJson(error_class)));
   return ok;
  }

int DeletePendingOrdersForMagic(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   int deleted = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(DeletePendingOrder(ticket, reason))
         ++deleted;
     }
   return deleted;
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_M15);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

bool ComputeAsianRange(const datetime day_midnight, double &range_high, double &range_low)
  {
   const datetime range_start = BrokerDateTimeAtHour(day_midnight, strategy_range_start_hour_broker);
   const datetime range_end = BrokerDateTimeAtHour(day_midnight, strategy_range_end_hour_broker);
   if(range_end <= range_start)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_M15, range_start, range_end - 1, rates); // perf-allowed: called only after the M15 QM_IsNewBar gate.
   if(copied <= 0)
      return false;

   range_high = 0.0;
   range_low = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0)
         return false;
      if(range_high <= 0.0 || rates[i].high > range_high)
         range_high = rates[i].high;
      if(range_low <= 0.0 || rates[i].low < range_low)
         range_low = rates[i].low;
     }

   return (range_high > range_low && range_low > 0.0);
  }

bool TradingDayAllowed(const datetime day_midnight)
  {
   MqlDateTime dt;
   TimeToStruct(day_midnight, dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   if(strategy_mon_thu_only && dt.day_of_week == 5)
      return false;
   return true;
  }

bool SpreadAllowsOrderPlacement()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   return ((ask - bid) / point <= (double)MathMax(1, strategy_max_spread_points));
  }

void InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool BuildStopPair(QM_EntryRequest &long_req, QM_EntryRequest &short_req, datetime &day_midnight)
  {
   InitEntryRequest(long_req);
   InitEntryRequest(short_req);

   const datetime broker_now = TimeCurrent();
   day_midnight = BrokerMidnight(broker_now);
   if(g_last_order_day == day_midnight)
      return false;
   if(!TradingDayAllowed(day_midnight))
      return false;

   const datetime entry_start = BrokerDateTimeAtHour(day_midnight, strategy_entry_start_hour_broker);
   const datetime cancel_time = BrokerDateTimeAtHour(day_midnight, strategy_cancel_hour_broker);
   if(broker_now < entry_start || broker_now >= cancel_time)
      return false;
   if(HasOpenPositionForMagic() || PendingOrderCountForMagic() > 0)
      return false;
   if(!SpreadAllowsOrderPlacement())
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(g_last_range_day == day_midnight && g_range_high > g_range_low)
     {
      range_high = g_range_high;
      range_low = g_range_low;
     }
   else if(ComputeAsianRange(day_midnight, range_high, range_low))
     {
      g_last_range_day = day_midnight;
      g_range_high = range_high;
      g_range_low = range_low;
     }
   else
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double buffer = MathMax(0, strategy_breakout_buffer_points) * point;
   const double long_entry = QM_TM_NormalizePrice(_Symbol, range_high + buffer);
   const double short_entry = QM_TM_NormalizePrice(_Symbol, range_low - buffer);
   if(long_entry <= 0.0 || short_entry <= 0.0 || long_entry <= short_entry)
      return false;

   double long_sl = QM_TM_NormalizePrice(_Symbol, range_low - buffer);
   double short_sl = QM_TM_NormalizePrice(_Symbol, range_high + buffer);
   if(strategy_use_atr_stop)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_H1, MathMax(1, strategy_atr_period), 1);
      if(atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
         return false;
      long_sl = QM_TM_NormalizePrice(_Symbol, long_entry - atr * strategy_atr_stop_mult);
      short_sl = QM_TM_NormalizePrice(_Symbol, short_entry + atr * strategy_atr_stop_mult);
     }

   if(long_sl <= 0.0 || long_sl >= long_entry || short_sl <= short_entry)
      return false;

   const double rr = MathMax(0.0, strategy_rr_target);
   const int expiration_seconds = MathMax(60, (int)(cancel_time - broker_now));

   long_req.type = QM_BUY_STOP;
   long_req.price = long_entry;
   long_req.sl = long_sl;
   long_req.tp = (rr > 0.0) ? QM_TM_NormalizePrice(_Symbol, long_entry + (long_entry - long_sl) * rr) : 0.0;
   long_req.reason = "QM5_1120_BIGBEN_LONG";
   long_req.symbol_slot = qm_magic_slot_offset;
   long_req.expiration_seconds = expiration_seconds;

   short_req.type = QM_SELL_STOP;
   short_req.price = short_entry;
   short_req.sl = short_sl;
   short_req.tp = (rr > 0.0) ? QM_TM_NormalizePrice(_Symbol, short_entry - (short_sl - short_entry) * rr) : 0.0;
   short_req.reason = "QM5_1120_BIGBEN_SHORT";
   short_req.symbol_slot = qm_magic_slot_offset;
   short_req.expiration_seconds = expiration_seconds;

   return true;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(HasOpenPositionForMagic())
      DeletePendingOrdersForMagic("oco_after_fill");
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   const datetime day_midnight = BrokerMidnight(broker_now);
   const datetime exit_time = BrokerDateTimeAtHour(day_midnight, strategy_exit_hour_broker);
   if(broker_now < exit_time || g_last_exit_day == day_midnight)
      return false;

   g_last_exit_day = day_midnight;
   DeletePendingOrdersForMagic("time_stop_19");
   return HasOpenPositionForMagic();
  }

void Strategy_CancelExpiredPending()
  {
   const datetime broker_now = TimeCurrent();
   const datetime day_midnight = BrokerMidnight(broker_now);
   const datetime cancel_time = BrokerDateTimeAtHour(day_midnight, strategy_cancel_hour_broker);
   if(broker_now < cancel_time || g_last_cancel_day == day_midnight)
      return;

   g_last_cancel_day = day_midnight;
   DeletePendingOrdersForMagic("cancel_11");
  }

void Strategy_PlaceStopPair()
  {
   QM_EntryRequest long_req;
   QM_EntryRequest short_req;
   datetime day_midnight = 0;
   if(!BuildStopPair(long_req, short_req, day_midnight))
      return;

   int opened = 0;
   ulong out_ticket = 0;
   if(QM_TM_OpenPosition(long_req, out_ticket))
      ++opened;
   out_ticket = 0;
   if(QM_TM_OpenPosition(short_req, out_ticket))
      ++opened;

   if(opened > 0)
     {
      g_last_order_day = day_midnight;
      QM_LogEvent(QM_INFO,
                  "BIGBEN_STOP_PAIR_PLACED",
                  StringFormat("{\"day\":%I64d,\"orders\":%d,\"range_high\":%.8f,\"range_low\":%.8f}",
                               (long)day_midnight,
                               opened,
                               g_range_high,
                               g_range_low));
     }
  }

int OnInit()
  {
   if(strategy_range_end_hour_broker <= strategy_range_start_hour_broker ||
      strategy_cancel_hour_broker <= strategy_entry_start_hour_broker ||
      strategy_exit_hour_broker <= strategy_cancel_hour_broker)
     {
      Print("QM5_1120 invalid time inputs.");
      return INIT_PARAMETERS_INCORRECT;
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1120\",\"ea\":\"bigben-london-open-breakout\"}");
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
     {
      DeletePendingOrdersForMagic("friday_close");
      return;
     }

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_CancelExpiredPending();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, PERIOD_M15))
      return;

   QM_EquityStreamOnNewBar();
   Strategy_PlaceStopPair();
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
