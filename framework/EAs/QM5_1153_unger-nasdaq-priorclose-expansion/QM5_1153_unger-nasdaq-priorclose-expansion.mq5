#property strict
#property version   "5.0"
#property description "QM5_1153 Unger Nasdaq Prior-Close Expansion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                         = 1153;
input int    qm_magic_slot_offset             = 0;
input uint   qm_rng_seed                      = 42;

input group "Risk"
input double RISK_PERCENT                     = 0.0;
input double RISK_FIXED                       = 1000.0;
input double PORTFOLIO_WEIGHT                 = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours          = 336;
input string qm_news_min_impact               = "high";
input QM_NewsMode qm_news_mode_legacy         = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled          = true;
input int    qm_friday_close_hour_broker      = 21;

input group "Stress"
input double qm_stress_reject_probability     = 0.0;

input group "Strategy"
input int    strategy_entry_start_hour_ny     = 9;
input int    strategy_entry_start_minute_ny   = 30;
input int    strategy_cancel_hour_ny          = 15;
input int    strategy_cancel_minute_ny        = 30;
input int    strategy_session_end_hour_ny     = 16;
input int    strategy_session_end_minute_ny   = 0;
input int    strategy_preclose_flatten_minutes = 5;
input int    strategy_daily_atr_period        = 14;
input int    strategy_m15_atr_period          = 14;
input double strategy_expansion_mult          = 0.25;
input double strategy_extreme_range_atr_mult  = 2.50;
input double strategy_sl_atr_mult             = 1.50;
input double strategy_tp_atr_mult             = 2.50;
input int    strategy_max_spread_points       = 0;

datetime g_last_order_day = 0;
datetime g_last_cancel_day = 0;
datetime g_last_exit_day = 0;

int ClampInt(const int value, const int min_value, const int max_value)
  {
   return MathMax(min_value, MathMin(max_value, value));
  }

datetime BrokerMidnight(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime BrokerToNYLocal(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 3600 : 5 * 3600);
  }

datetime NYLocalToBroker(const datetime ny_day, const int hour, const int minute)
  {
   MqlDateTime ny;
   TimeToStruct(ny_day, ny);
   ny.hour = ClampInt(hour, 0, 23);
   ny.min = ClampInt(minute, 0, 59);
   ny.sec = 0;

   const datetime local_stamp = StructToTime(ny);
   datetime utc_guess = local_stamp + 5 * 3600;
   if(QM_IsUSDSTUTC(utc_guess))
      utc_guess = local_stamp + 4 * 3600;
   return QM_UTCToBroker(utc_guess);
  }

datetime NYMidnightForBrokerNow(const datetime broker_time)
  {
   MqlDateTime ny;
   TimeToStruct(BrokerToNYLocal(broker_time), ny);
   ny.hour = 0;
   ny.min = 0;
   ny.sec = 0;
   return StructToTime(ny);
  }

int NYDayOfWeek(const datetime broker_time)
  {
   MqlDateTime ny;
   TimeToStruct(BrokerToNYLocal(broker_time), ny);
   return ny.day_of_week;
  }

bool TuesdayThroughFridayNY(const datetime broker_time)
  {
   const int dow = NYDayOfWeek(broker_time);
   return (dow >= 2 && dow <= 5);
  }

int StrategySymbolSlot()
  {
   if(_Symbol == "NDX.DWX")
      return 0;
   if(_Symbol == "WS30.DWX")
      return 1;
   if(_Symbol == "SP500.DWX")
      return 2;
   return -1;
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

bool SpreadAllowsOrderPlacement()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool PreviousDayAllowsEntry()
  {
   const double high = iHigh(_Symbol, PERIOD_D1, 1);
   const double low = iLow(_Symbol, PERIOD_D1, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, strategy_daily_atr_period), 1);
   if(high <= low || atr <= 0.0)
      return false;
   return ((high - low) <= strategy_extreme_range_atr_mult * atr);
  }

bool BuildStopPair(QM_EntryRequest &long_req, QM_EntryRequest &short_req, datetime &day_midnight)
  {
   long_req.type = QM_BUY_STOP;
   long_req.price = 0.0;
   long_req.sl = 0.0;
   long_req.tp = 0.0;
   long_req.reason = "";
   long_req.symbol_slot = StrategySymbolSlot();
   long_req.expiration_seconds = 0;

   short_req = long_req;
   short_req.type = QM_SELL_STOP;

   const datetime broker_now = TimeCurrent();
   day_midnight = BrokerMidnight(broker_now);
   if(g_last_order_day == day_midnight)
      return false;
   if(_Period != PERIOD_M5 || long_req.symbol_slot < 0)
      return false;
   if(!TuesdayThroughFridayNY(broker_now))
      return false;

   const datetime ny_midnight = NYMidnightForBrokerNow(broker_now);
   const datetime entry_start = NYLocalToBroker(ny_midnight,
                                                strategy_entry_start_hour_ny,
                                                strategy_entry_start_minute_ny);
   const datetime cancel_time = NYLocalToBroker(ny_midnight,
                                                strategy_cancel_hour_ny,
                                                strategy_cancel_minute_ny);
   const datetime flatten_time = NYLocalToBroker(ny_midnight,
                                                 strategy_session_end_hour_ny,
                                                 strategy_session_end_minute_ny) -
                                 strategy_preclose_flatten_minutes * 60;
   if(broker_now < entry_start || broker_now >= cancel_time || broker_now >= flatten_time)
      return false;
   if(HasOpenPositionForMagic() || PendingOrderCountForMagic() > 0)
      return false;
   if(!SpreadAllowsOrderPlacement() || !PreviousDayAllowsEntry())
      return false;

   const double pdc = iClose(_Symbol, PERIOD_D1, 1);
   const double daily_atr = QM_ATR(_Symbol, PERIOD_D1, MathMax(1, strategy_daily_atr_period), 1);
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, MathMax(1, strategy_m15_atr_period), 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pdc <= 0.0 || daily_atr <= 0.0 || atr_m15 <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double expansion = daily_atr * MathMax(0.0, strategy_expansion_mult);
   const double long_entry = QM_TM_NormalizePrice(_Symbol, pdc + expansion);
   const double short_entry = QM_TM_NormalizePrice(_Symbol, pdc - expansion);
   if(long_entry <= ask + point || short_entry >= bid - point || short_entry <= 0.0 || short_entry >= long_entry)
      return false;

   const int expiration_seconds = MathMax(60, (int)(cancel_time - broker_now));
   long_req.price = long_entry;
   long_req.sl = QM_StopATRFromValue(_Symbol, long_req.type, long_req.price, atr_m15, strategy_sl_atr_mult);
   long_req.tp = QM_StopRulesTakeFromDistance(_Symbol, long_req.type, long_req.price, atr_m15 * strategy_tp_atr_mult);
   long_req.reason = "QM5_1153_BUY_PDC_EXPANSION";
   long_req.expiration_seconds = expiration_seconds;

   short_req.price = short_entry;
   short_req.sl = QM_StopATRFromValue(_Symbol, short_req.type, short_req.price, atr_m15, strategy_sl_atr_mult);
   short_req.tp = QM_StopRulesTakeFromDistance(_Symbol, short_req.type, short_req.price, atr_m15 * strategy_tp_atr_mult);
   short_req.reason = "QM5_1153_SELL_PDC_EXPANSION";
   short_req.expiration_seconds = expiration_seconds;

   if(long_req.sl <= 0.0 || long_req.sl >= long_req.price || long_req.tp <= long_req.price)
      return false;
   if(short_req.sl <= short_req.price || short_req.tp >= short_req.price || short_req.tp <= 0.0)
      return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(StrategySymbolSlot() < 0)
      return true;
   if(_Period != PERIOD_M5)
      return true;
   if(strategy_daily_atr_period <= 0 || strategy_m15_atr_period <= 0)
      return true;
   if(strategy_expansion_mult <= 0.0 || strategy_sl_atr_mult <= 0.0 || strategy_tp_atr_mult <= 0.0)
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
   req.symbol_slot = StrategySymbolSlot();
   req.expiration_seconds = 0;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(HasOpenPositionForMagic())
      DeletePendingOrdersForMagic("oco_after_fill");

   const datetime broker_now = TimeCurrent();
   const datetime day_midnight = BrokerMidnight(broker_now);
   if(g_last_cancel_day == day_midnight)
      return;

   const datetime ny_midnight = NYMidnightForBrokerNow(broker_now);
   const datetime cancel_time = NYLocalToBroker(ny_midnight,
                                                strategy_cancel_hour_ny,
                                                strategy_cancel_minute_ny);
   if(broker_now >= cancel_time)
     {
      g_last_cancel_day = day_midnight;
      DeletePendingOrdersForMagic("entry_cutoff");
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   const datetime day_midnight = BrokerMidnight(broker_now);
   if(g_last_exit_day == day_midnight)
      return false;

   const datetime ny_midnight = NYMidnightForBrokerNow(broker_now);
   const datetime flatten_time = NYLocalToBroker(ny_midnight,
                                                 strategy_session_end_hour_ny,
                                                 strategy_session_end_minute_ny) -
                                 strategy_preclose_flatten_minutes * 60;
   if(broker_now < flatten_time)
      return false;

   g_last_exit_day = day_midnight;
   DeletePendingOrdersForMagic("session_flatten");
   return HasOpenPositionForMagic();
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
                  "PDC_EXPANSION_STOP_PAIR_PLACED",
                  StringFormat("{\"day\":%I64d,\"orders\":%d}", (long)day_midnight, opened));
     }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1153\",\"ea\":\"unger-nasdaq-priorclose-expansion\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_M5))
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
