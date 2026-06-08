#property strict
#property version   "5.0"
#property description "QM5_11342 Triad Off-Hours Watermark Fade"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11342;
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
input int    strategy_session_start_hour_broker      = 20;
input int    strategy_session_end_hour_broker        = 0;
input bool   strategy_use_us_dst_session_hours       = true;
input int    strategy_dst_session_start_hour_broker  = 19;
input int    strategy_dst_session_end_hour_broker    = 23;
input int    strategy_tp_pips                        = 12;
input int    strategy_sl_pips                        = 12;
input int    strategy_atr_period                     = 14;
input double strategy_atr_sl_cap_mult                = 0.5;
input int    strategy_spread_cap_pips                = 3;
input int    strategy_min_watermark_range_pips       = 3;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_FirstSunday(const int year, const int month)
  {
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = 1;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime first_day = StructToTime(dt);
   TimeToStruct(first_day, dt);
   return 1 + ((7 - dt.day_of_week) % 7);
  }

bool Strategy_UsDstActive(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(dt.mon < 3 || dt.mon > 11)
      return false;
   if(dt.mon > 3 && dt.mon < 11)
      return true;

   if(dt.mon == 3)
     {
      const int second_sunday = Strategy_FirstSunday(dt.year, 3) + 7;
      return dt.day >= second_sunday;
     }

   const int first_sunday = Strategy_FirstSunday(dt.year, 11);
   return dt.day < first_sunday;
  }

int Strategy_StartHour(const datetime broker_time)
  {
   if(strategy_use_us_dst_session_hours && Strategy_UsDstActive(broker_time))
      return strategy_dst_session_start_hour_broker;
   return strategy_session_start_hour_broker;
  }

int Strategy_EndHour(const datetime broker_time)
  {
   if(strategy_use_us_dst_session_hours && Strategy_UsDstActive(broker_time))
      return strategy_dst_session_end_hour_broker;
   return strategy_session_end_hour_broker;
  }

bool Strategy_InHourWindow(const datetime broker_time, const int start_hour, const int end_hour)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (dt.hour >= start_hour && dt.hour < end_hour);
   return (dt.hour >= start_hour || dt.hour < end_hour);
  }

bool Strategy_InSession(const datetime broker_time)
  {
   return Strategy_InHourWindow(broker_time, Strategy_StartHour(broker_time), Strategy_EndHour(broker_time));
  }

int Strategy_SecondsToSessionEnd(const datetime broker_time)
  {
   const int start_hour = Strategy_StartHour(broker_time);
   const int end_hour = Strategy_EndHour(broker_time);

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   MqlDateTime end_dt = dt;
   end_dt.hour = end_hour;
   end_dt.min = 0;
   end_dt.sec = 0;

   datetime end_time = StructToTime(end_dt);
   if(start_hour > end_hour && dt.hour >= start_hour)
      end_time += 24 * 60 * 60;
   if(end_time <= broker_time)
      end_time += 24 * 60 * 60;

   const int seconds_left = (int)(end_time - broker_time);
   return (seconds_left > 60) ? seconds_left : 60;
  }

double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
  }

double Strategy_CurrentSpreadPips()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double pip = Strategy_PipSize();
   if(bid <= 0.0 || ask <= 0.0 || pip <= 0.0)
      return DBL_MAX;
   return (ask - bid) / pip;
  }

bool Strategy_HasOpenPositionOrPending(const int magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (int)OrderGetInteger(ORDER_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasPendingType(const int magic, const ENUM_ORDER_TYPE wanted_type)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == wanted_type)
         return true;
     }
   return false;
  }

void Strategy_RemovePendingOutsideSession()
  {
   if(Strategy_InSession(TimeCurrent()))
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         QM_TM_RemovePendingOrder(ticket, "triad_session_expired");
     }
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && Strategy_HasOpenPositionOrPending(magic))
      return false;

   if(!Strategy_InSession(TimeCurrent()))
      return true;

   if(Strategy_CurrentSpreadPips() > (double)strategy_spread_cap_pips)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   if(_Period != PERIOD_H1)
      return false;

   const datetime broker_now = TimeCurrent();
   const int session_start = Strategy_StartHour(broker_now);
   const int session_day = Strategy_DayKey(broker_now);
   static int armed_day = -1;
   static double wm_high = 0.0;
   static double wm_low = 0.0;
   static bool buy_submitted = false;
   static bool sell_submitted = false;

   MqlRates setup_bar[];
   ArraySetAsSeries(setup_bar, true);
   if(CopyRates(_Symbol, PERIOD_H1, 1, 1, setup_bar) != 1) // perf-allowed: one closed setup bar for session watermark.
      return false;

   MqlDateTime setup_dt;
   TimeToStruct(setup_bar[0].time, setup_dt);
   const int setup_day = Strategy_DayKey(setup_bar[0].time);

   if(setup_dt.hour == session_start && setup_day != armed_day)
     {
      armed_day = setup_day;
      wm_high = setup_bar[0].high;
      wm_low = setup_bar[0].low;
      buy_submitted = false;
      sell_submitted = false;
     }

   if(armed_day != session_day || wm_high <= 0.0 || wm_low <= 0.0 || wm_high <= wm_low)
      return false;

   if(!Strategy_InSession(broker_now))
      return false;

   const double pip = Strategy_PipSize();
   if(pip <= 0.0)
      return false;

   if((wm_high - wm_low) / pip < (double)strategy_min_watermark_range_pips)
      return false;

   if(Strategy_CurrentSpreadPips() > (double)strategy_spread_cap_pips)
      return false;

   double sl_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr > 0.0 && strategy_atr_sl_cap_mult > 0.0)
      sl_distance = MathMin(sl_distance, atr * strategy_atr_sl_cap_mult);

   const double tp_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   if(sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   const int expiration_seconds = Strategy_SecondsToSessionEnd(broker_now);
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   QM_EntryRequest sell_req;
   Strategy_InitRequest(sell_req);
   sell_req.type = QM_SELL_LIMIT;
   sell_req.price = NormalizeDouble(wm_high, _Digits);
   sell_req.sl = NormalizeDouble(sell_req.price + sl_distance, _Digits);
   sell_req.tp = NormalizeDouble(sell_req.price - tp_distance, _Digits);
   sell_req.reason = "TRIAD_WM_HIGH_FADE";
   sell_req.expiration_seconds = expiration_seconds;

   if(!sell_submitted && !Strategy_HasPendingType(magic, ORDER_TYPE_SELL_LIMIT))
     {
      ulong sell_ticket = 0;
      if(QM_TM_OpenPosition(sell_req, sell_ticket))
         sell_submitted = true;
     }

   if(!buy_submitted && !Strategy_HasPendingType(magic, ORDER_TYPE_BUY_LIMIT))
     {
      req.type = QM_BUY_LIMIT;
      req.price = NormalizeDouble(wm_low, _Digits);
      req.sl = NormalizeDouble(req.price - sl_distance, _Digits);
      req.tp = NormalizeDouble(req.price + tp_distance, _Digits);
      req.reason = "TRIAD_WM_LOW_FADE";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = expiration_seconds;
      buy_submitted = true;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_RemovePendingOutsideSession();
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || Strategy_InSession(TimeCurrent()))
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
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
