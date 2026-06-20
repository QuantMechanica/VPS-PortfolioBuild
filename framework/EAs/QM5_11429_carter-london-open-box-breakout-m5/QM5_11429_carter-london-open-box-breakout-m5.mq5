#property strict
#property version   "5.0"
#property description "QM5_11429 Carter London Open Box Breakout (M5)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11429;
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
input int    strategy_box_end_et_hhmm       = 800;
input int    strategy_box_minutes           = 60;
input int    strategy_entry_window_minutes  = 60;
input int    strategy_position_stop_minutes = 120;
input double strategy_entry_buffer_mult     = 0.20;
input double strategy_tp_box_mult           = 4.00;
input double strategy_trail_trigger_mult    = 2.00;
input double strategy_trail_distance_mult   = 1.00;
input int    strategy_min_box_pips          = 5;
input int    strategy_max_box_pips          = 60;
input int    strategy_sl_buffer_pips        = 1;
input int    strategy_spread_cap_pips       = 15;
input int    strategy_box_scan_bars         = 96;

int    g_session_key = 0;
bool   g_box_ready = false;
bool   g_trade_attempted_this_session = false;
double g_box_high = 0.0;
double g_box_low = 0.0;
double g_box_height = 0.0;
int    g_box_bar_count = 0;

datetime BrokerToEastern(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int et_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   return utc + et_offset_hours * 3600;
  }

int EasternDateKey(const datetime broker_time)
  {
   MqlDateTime et;
   ZeroMemory(et);
   TimeToStruct(BrokerToEastern(broker_time), et);
   return et.year * 10000 + et.mon * 100 + et.day;
  }

int EasternMinuteOfDay(const datetime broker_time)
  {
   MqlDateTime et;
   ZeroMemory(et);
   TimeToStruct(BrokerToEastern(broker_time), et);
   return et.hour * 60 + et.min;
  }

int HhmmToMinutes(const int hhmm)
  {
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return -1;
   return hour * 60 + minute;
  }

int BoxEndMinute()
  {
   return HhmmToMinutes(strategy_box_end_et_hhmm);
  }

int BoxStartMinute()
  {
   const int end_minute = BoxEndMinute();
   if(end_minute < 0)
      return -1;
   return end_minute - strategy_box_minutes;
  }

int EntryEndMinute()
  {
   const int end_minute = BoxEndMinute();
   if(end_minute < 0)
      return -1;
   return end_minute + strategy_entry_window_minutes;
  }

int PositionStopMinute()
  {
   const int end_minute = BoxEndMinute();
   if(end_minute < 0)
      return -1;
   return end_minute + strategy_position_stop_minutes;
  }

void ResetSessionIfNeeded(const datetime broker_now)
  {
   const int key = EasternDateKey(broker_now);
   if(key == g_session_key)
      return;

   g_session_key = key;
   g_box_ready = false;
   g_trade_attempted_this_session = false;
   g_box_high = 0.0;
   g_box_low = 0.0;
   g_box_height = 0.0;
   g_box_bar_count = 0;
  }

bool SpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   return (ask > bid && (ask - bid) > cap);
  }

bool IsOurPendingOrderType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP ||
           order_type == ORDER_TYPE_SELL_STOP ||
           order_type == ORDER_TYPE_BUY_LIMIT ||
           order_type == ORDER_TYPE_SELL_LIMIT);
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
      if(IsOurPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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
      return true;
     }
   return false;
  }

void CancelOurPendingOrders(const string reason)
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
      if(!IsOurPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool BuildLondonBox(const datetime broker_now)
  {
   ResetSessionIfNeeded(broker_now);
   if(g_box_ready)
      return true;

   const int box_start = BoxStartMinute();
   const int box_end = BoxEndMinute();
   if(box_start < 0 || box_end <= box_start)
      return false;
   if(EasternMinuteOfDay(broker_now) < box_end)
      return false;

   double box_high = -DBL_MAX;
   double box_low = DBL_MAX;
   int box_bars = 0;

   const int scan_bars = (strategy_box_scan_bars > 12) ? strategy_box_scan_bars : 12;
   for(int shift = 1; shift <= scan_bars; ++shift)
     {
      const datetime bar_broker = iTime(_Symbol, PERIOD_M5, shift); // perf-allowed: bounded M5 session-box scan inside framework new-bar entry path.
      if(bar_broker <= 0)
         continue;
      if(EasternDateKey(bar_broker) != g_session_key)
         continue;

      const int minute = EasternMinuteOfDay(bar_broker);
      if(minute < box_start || minute >= box_end)
         continue;

      const double bar_high = iHigh(_Symbol, PERIOD_M5, shift); // perf-allowed: structural London-box high; bounded to strategy_box_scan_bars.
      const double bar_low = iLow(_Symbol, PERIOD_M5, shift);   // perf-allowed: structural London-box low; bounded to strategy_box_scan_bars.
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high < bar_low)
         continue;

      if(bar_high > box_high)
         box_high = bar_high;
      if(bar_low < box_low)
         box_low = bar_low;
      box_bars++;
     }

   if(box_bars <= 0 || box_high <= 0.0 || box_low <= 0.0 || box_high <= box_low)
      return false;

   const double box_height = box_high - box_low;
   const double min_height = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_box_pips);
   const double max_height = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_box_pips);
   if(min_height > 0.0 && box_height < min_height)
      return false;
   if(max_height > 0.0 && box_height > max_height)
      return false;

   g_box_high = box_high;
   g_box_low = box_low;
   g_box_height = box_height;
   g_box_bar_count = box_bars;
   g_box_ready = true;
   return true;
  }

int EntryExpirationSeconds(const datetime broker_now)
  {
   const int entry_end = EntryEndMinute();
   const int now_minute = EasternMinuteOfDay(broker_now);
   if(entry_end <= now_minute)
      return 0;
   return (entry_end - now_minute) * 60;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask <= 0.0 || bid <= 0.0);
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

   const datetime broker_now = TimeCurrent();
   ResetSessionIfNeeded(broker_now);

   const int now_minute = EasternMinuteOfDay(broker_now);
   const int box_end = BoxEndMinute();
   const int entry_end = EntryEndMinute();
   if(box_end < 0 || entry_end <= box_end)
      return false;
   if(now_minute < box_end || now_minute >= entry_end)
      return false;
   if(g_trade_attempted_this_session || HasOurOpenPosition() || HasOurPendingOrder())
      return false;
   if(SpreadTooWide())
      return false;
   if(!BuildLondonBox(broker_now))
      return false;

   const double signal_high = iHigh(_Symbol, PERIOD_M5, 1); // perf-allowed: closed M5 breakout bar; EntrySignal is framework-new-bar gated.
   const double signal_low = iLow(_Symbol, PERIOD_M5, 1);   // perf-allowed: closed M5 breakout bar; EntrySignal is framework-new-bar gated.
   if(signal_high <= 0.0 || signal_low <= 0.0)
      return false;

   const double buffer = g_box_height * strategy_entry_buffer_mult;
   if(buffer <= 0.0)
      return false;

   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const int expiration = EntryExpirationSeconds(broker_now);
   if(expiration <= 0)
      return false;

   const double buy_trigger = QM_StopRulesNormalizePrice(_Symbol, g_box_high + buffer);
   const double sell_trigger = QM_StopRulesNormalizePrice(_Symbol, g_box_low - buffer);

   if(signal_high > buy_trigger)
     {
      req.type = QM_BUY_STOP;
      req.price = buy_trigger;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_box_low - sl_buffer);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, g_box_high + strategy_tp_box_mult * g_box_height);
      req.reason = StringFormat("CARTER_LONDON_BOX_LONG bars=%d", g_box_bar_count);
      req.expiration_seconds = expiration;
      g_trade_attempted_this_session = true;
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
     }

   if(signal_low < sell_trigger)
     {
      req.type = QM_SELL_STOP;
      req.price = sell_trigger;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_box_high + sl_buffer);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, g_box_low - strategy_tp_box_mult * g_box_height);
      req.reason = StringFormat("CARTER_LONDON_BOX_SHORT bars=%d", g_box_bar_count);
      req.expiration_seconds = expiration;
      g_trade_attempted_this_session = true;
      return (req.price > 0.0 && req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   ResetSessionIfNeeded(broker_now);

   const int entry_end = EntryEndMinute();
   if(entry_end > 0 && EasternMinuteOfDay(broker_now) >= entry_end)
      CancelOurPendingOrders("london_box_entry_window_expired");

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      g_trade_attempted_this_session = true;
      if(!BuildLondonBox(broker_now))
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= g_box_high + strategy_trail_trigger_mult * g_box_height)
            continue;
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, bid - strategy_trail_distance_mult * g_box_height);
         if(current_sl <= 0.0 || new_sl > current_sl + point * 0.5)
            QM_TM_MoveSL(ticket, new_sl, "trail_by_london_box_height");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask >= g_box_low - strategy_trail_trigger_mult * g_box_height)
            continue;
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, ask + strategy_trail_distance_mult * g_box_height);
         if(current_sl <= 0.0 || new_sl < current_sl - point * 0.5)
            QM_TM_MoveSL(ticket, new_sl, "trail_by_london_box_height");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   ResetSessionIfNeeded(broker_now);

   const int stop_minute = PositionStopMinute();
   if(stop_minute < 0 || EasternMinuteOfDay(broker_now) < stop_minute)
      return false;

   return HasOurOpenPosition();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11429\",\"ea\":\"carter_london_open_box_breakout_m5\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
