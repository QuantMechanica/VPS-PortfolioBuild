#property strict
#property version   "5.0"
#property description "QM5_9581 ForexFactory DIBS Inside-Bar Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9581;
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
input int    strategy_atr_period          = 14;
input double strategy_entry_atr_fraction  = 0.10;
input double strategy_min_inside_atr      = 0.15;
input double strategy_max_inside_atr      = 1.25;
input double strategy_take_rr             = 2.0;
input int    strategy_start_gmt_hour      = 6;
input int    strategy_cancel_gmt_hour     = 16;
input int    strategy_time_stop_bars      = 10;

int      g_last_signal_dir = 0;
double   g_last_long_break = 0.0;
double   g_last_short_break = 0.0;
datetime g_last_signal_bar = 0;

void InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

datetime DayStartUTC(const datetime utc_time)
  {
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   return utc_time - (dt.hour * 3600 + dt.min * 60 + dt.sec);
  }

int HourUTC(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(broker_time), dt);
   return dt.hour;
  }

bool IsEntrySessionUTC(const datetime broker_time)
  {
   const int hour = HourUTC(broker_time);
   return (hour >= strategy_start_gmt_hour && hour < strategy_cancel_gmt_hour);
  }

int SecondsUntilCancelUTC(const datetime broker_time)
  {
   const datetime utc_now = QM_BrokerToUTC(broker_time);
   datetime cancel_utc = DayStartUTC(utc_now) + strategy_cancel_gmt_hour * 3600;
   if(cancel_utc <= utc_now)
      return 0;
   return (int)(cancel_utc - utc_now);
  }

bool ReferenceCloseGMTMidnight(double &ref_close)
  {
   ref_close = 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, 72, rates); // perf-allowed: bounded H1 structural lookup under framework new-bar gate.
   if(copied < 24)
      return false;

   const datetime utc_day_start = DayStartUTC(QM_BrokerToUTC(TimeCurrent()));
   const datetime broker_midnight_utc = QM_UTCToBroker(utc_day_start);
   const datetime target_open = broker_midnight_utc - 3600;

   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time == target_open)
        {
         ref_close = rates[i].close;
         return (ref_close > 0.0);
        }
     }

   return false;
  }

bool ReadInsideBar(double &inside_high,
                   double &inside_low,
                   datetime &inside_time)
  {
   inside_high = 0.0;
   inside_low = 0.0;
   inside_time = 0;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, 2, bars); // perf-allowed: two closed bars for DIBS inside-bar structure.
   if(copied != 2)
      return false;

   if(bars[0].high <= 0.0 || bars[0].low <= 0.0 ||
      bars[1].high <= 0.0 || bars[1].low <= 0.0)
      return false;

   if(!(bars[0].high < bars[1].high && bars[0].low > bars[1].low))
      return false;

   inside_high = bars[0].high;
   inside_low = bars[0].low;
   inside_time = bars[0].time;
   return true;
  }

bool HasOurPendingOrder()
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

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }

   return false;
  }

void RemoveOurPendingOrders(const string reason)
  {
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
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   return (QM_TM_OpenPositionCount(magic) > 0);
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitEntryRequest(req);

   const datetime broker_now = TimeCurrent();
   if(!IsEntrySessionUTC(broker_now))
      return false;

   double reference_close = 0.0;
   if(!ReferenceCloseGMTMidnight(reference_close))
      return false;

   double inside_high = 0.0;
   double inside_low = 0.0;
   datetime inside_time = 0;
   if(!ReadInsideBar(inside_high, inside_low, inside_time))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double inside_range = inside_high - inside_low;
   if(inside_range < strategy_min_inside_atr * atr ||
      inside_range > strategy_max_inside_atr * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   const double buffer = strategy_entry_atr_fraction * atr;
   const double long_entry = QM_StopRulesNormalizePrice(_Symbol, inside_high + buffer);
   const double short_entry = QM_StopRulesNormalizePrice(_Symbol, inside_low - buffer);

   g_last_signal_bar = inside_time;
   g_last_long_break = long_entry;
   g_last_short_break = short_entry;
   g_last_signal_dir = 0;

   const bool long_bias = (bid > reference_close);
   const bool short_bias = (ask < reference_close);

   if(long_bias)
      g_last_signal_dir = 1;
   else if(short_bias)
      g_last_signal_dir = -1;

   if(HasOurOpenPosition() || HasOurPendingOrder())
      return false;

   const int expiry_seconds = SecondsUntilCancelUTC(broker_now);
   if(expiry_seconds <= 0)
      return false;

   if(long_bias && ask < long_entry)
     {
      req.type = QM_BUY_STOP;
      req.price = long_entry;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, inside_low - buffer);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_rr);
      req.reason = "DIBS_LONG_STOP";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = expiry_seconds;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(short_bias && bid > short_entry)
     {
      req.type = QM_SELL_STOP;
      req.price = short_entry;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, inside_high + buffer);
      req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_rr);
      req.reason = "DIBS_SHORT_STOP";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = expiry_seconds;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(HourUTC(TimeCurrent()) >= strategy_cancel_gmt_hour)
      RemoveOurPendingOrders("DIBS_1600_GMT_CANCEL");
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_time_stop_bars > 0 &&
         broker_now - open_time >= strategy_time_stop_bars * PeriodSeconds(PERIOD_H1))
         return true;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY &&
         g_last_signal_dir < 0 &&
         g_last_short_break > 0.0 &&
         bid <= g_last_short_break)
         return true;

      if(position_type == POSITION_TYPE_SELL &&
         g_last_signal_dir > 0 &&
         g_last_long_break > 0.0 &&
         ask >= g_last_long_break)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9581_ff-dibs-breakout\"}");
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
