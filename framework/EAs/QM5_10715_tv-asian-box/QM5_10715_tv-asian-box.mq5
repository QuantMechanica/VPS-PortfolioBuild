#property strict
#property version   "5.0"
#property description "QM5_10715 TradingView Asian Box Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10715;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_M15;
input int    strategy_source_utc_offset_hours  = 7;
input int    strategy_asian_start_hour         = 0;
input int    strategy_asian_start_min          = 0;
input int    strategy_asian_end_hour           = 6;
input int    strategy_asian_end_min            = 0;
input int    strategy_eod_close_hour           = 23;
input int    strategy_eod_close_min            = 55;
input int    strategy_atr_period               = 14;
input double strategy_fx_metal_sl_atr_mult     = 0.50;
input double strategy_index_sl_atr_mult        = 0.35;
input double strategy_min_range_atr_mult       = 0.20;
input double strategy_max_range_atr_mult       = 1.50;
input double strategy_max_spread_stop_frac     = 0.12;
input double strategy_entry_buffer_points      = 2.0;
input bool   strategy_use_atr_tp               = false;
input double strategy_tp_atr_mult              = 1.50;

int    g_box_session_key = 0;
double g_box_high = 0.0;
double g_box_low = 0.0;
bool   g_box_ready = false;
int    g_orders_placed_key = 0;
int    g_trade_taken_key = 0;

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_Midnight(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return t - (dt.hour * 3600 + dt.min * 60 + dt.sec);
  }

int Strategy_MinuteInput(const int hour_value, const int minute_value)
  {
   return hour_value * 60 + minute_value;
  }

datetime Strategy_BrokerToSourceTime(const datetime broker_time)
  {
   return QM_BrokerToUTC(broker_time) + strategy_source_utc_offset_hours * 3600;
  }

datetime Strategy_SourceToBrokerTime(const datetime source_time)
  {
   const datetime utc_time = source_time - strategy_source_utc_offset_hours * 3600;
   return QM_UTCToBroker(utc_time);
  }

bool Strategy_TimeInputsValid()
  {
   if(strategy_timeframe != PERIOD_M5 && strategy_timeframe != PERIOD_M15)
      return false;
   if(strategy_source_utc_offset_hours < -12 || strategy_source_utc_offset_hours > 14)
      return false;
   if(strategy_asian_start_hour < 0 || strategy_asian_start_hour > 23)
      return false;
   if(strategy_asian_end_hour < 0 || strategy_asian_end_hour > 23)
      return false;
   if(strategy_eod_close_hour < 0 || strategy_eod_close_hour > 23)
      return false;
   if(strategy_asian_start_min < 0 || strategy_asian_start_min > 59)
      return false;
   if(strategy_asian_end_min < 0 || strategy_asian_end_min > 59)
      return false;
   if(strategy_eod_close_min < 0 || strategy_eod_close_min > 59)
      return false;
   return Strategy_MinuteInput(strategy_asian_start_hour, strategy_asian_start_min) !=
          Strategy_MinuteInput(strategy_asian_end_hour, strategy_asian_end_min);
  }

bool Strategy_InWindow(const int minute_value, const int start_minute, const int end_minute)
  {
   if(start_minute < end_minute)
      return (minute_value >= start_minute && minute_value < end_minute);
   return (minute_value >= start_minute || minute_value < end_minute);
  }

int Strategy_SessionKeyFromSourceTime(const datetime source_time)
  {
   const int start_m = Strategy_MinuteInput(strategy_asian_start_hour, strategy_asian_start_min);
   const int end_m = Strategy_MinuteInput(strategy_asian_end_hour, strategy_asian_end_min);
   const int now_m = Strategy_MinutesOfDay(source_time);
   datetime session_day = Strategy_Midnight(source_time);
   if(start_m > end_m && now_m < end_m)
      session_day -= 86400;
   return Strategy_DateKey(session_day);
  }

void Strategy_SourceSessionBounds(const datetime source_time,
                                  datetime &source_start,
                                  datetime &source_end)
  {
   const int start_m = Strategy_MinuteInput(strategy_asian_start_hour, strategy_asian_start_min);
   const int end_m = Strategy_MinuteInput(strategy_asian_end_hour, strategy_asian_end_min);
   const int now_m = Strategy_MinutesOfDay(source_time);
   datetime session_day = Strategy_Midnight(source_time);
   if(start_m > end_m && now_m < end_m)
      session_day -= 86400;

   source_start = session_day + start_m * 60;
   source_end = session_day + end_m * 60;
   if(start_m > end_m)
      source_end += 86400;
  }

bool Strategy_InAsianSession(const datetime source_time)
  {
   if(!Strategy_TimeInputsValid())
      return false;
   return Strategy_InWindow(Strategy_MinutesOfDay(source_time),
                            Strategy_MinuteInput(strategy_asian_start_hour, strategy_asian_start_min),
                            Strategy_MinuteInput(strategy_asian_end_hour, strategy_asian_end_min));
  }

bool Strategy_AfterAsianSession(const datetime source_time)
  {
   if(!Strategy_TimeInputsValid() || Strategy_InAsianSession(source_time))
      return false;

   const int start_m = Strategy_MinuteInput(strategy_asian_start_hour, strategy_asian_start_min);
   const int end_m = Strategy_MinuteInput(strategy_asian_end_hour, strategy_asian_end_min);
   const int now_m = Strategy_MinutesOfDay(source_time);
   if(start_m < end_m)
      return (now_m >= end_m);
   return (now_m >= end_m && now_m < start_m);
  }

bool Strategy_PastEod(const datetime source_time)
  {
   const int eod_m = Strategy_MinuteInput(strategy_eod_close_hour, strategy_eod_close_min);
   return Strategy_MinutesOfDay(source_time) >= eod_m;
  }

bool Strategy_IndexSymbol()
  {
   return (StringFind(_Symbol, "NDX") >= 0 ||
           StringFind(_Symbol, "GDAXI") >= 0 ||
           StringFind(_Symbol, "WS30") >= 0 ||
           StringFind(_Symbol, "SP500") >= 0 ||
           StringFind(_Symbol, "UK100") >= 0);
  }

double Strategy_StopAtrMultiplier()
  {
   return Strategy_IndexSymbol() ? strategy_index_sl_atr_mult : strategy_fx_metal_sl_atr_mult;
  }

bool Strategy_CurrentSpread(double &spread_price)
  {
   spread_price = 0.0;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   spread_price = ask - bid;
   return true;
  }

bool Strategy_HasOurOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_IsOurPendingStop(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

int Strategy_PendingStopCount()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingStop((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

void Strategy_RemovePendingStops(const string reason)
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
      if(!Strategy_IsOurPendingStop((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_LoadAsianBox(const datetime source_now)
  {
   datetime source_start = 0;
   datetime source_end = 0;
   Strategy_SourceSessionBounds(source_now, source_start, source_end);
   if(source_now < source_end)
      return false;

   const int key = Strategy_DateKey(Strategy_Midnight(source_start));
   if(g_box_ready && g_box_session_key == key)
      return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const datetime broker_start = Strategy_SourceToBrokerTime(source_start);
   const datetime broker_end = Strategy_SourceToBrokerTime(source_end);
   const int copied = CopyRates(_Symbol, strategy_timeframe, broker_start, broker_end, rates); // perf-allowed: bounded Asian-box session reconstruction inside framework new-bar EntrySignal
   if(copied <= 0)
      return false;

   double high = -DBL_MAX;
   double low = DBL_MAX;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high < rates[i].low)
         continue;
      high = MathMax(high, rates[i].high);
      low = MathMin(low, rates[i].low);
     }

   if(high <= 0.0 || low <= 0.0 || high <= low)
      return false;

   g_box_session_key = key;
   g_box_high = high;
   g_box_low = low;
   g_box_ready = true;
   if(g_orders_placed_key != key && g_trade_taken_key != key)
     {
      g_orders_placed_key = 0;
      g_trade_taken_key = 0;
     }
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_TimeInputsValid())
      return true;
   if(_Period != strategy_timeframe)
      return true;
   if(strategy_atr_period <= 0 ||
      strategy_fx_metal_sl_atr_mult <= 0.0 ||
      strategy_index_sl_atr_mult <= 0.0 ||
      strategy_min_range_atr_mult < 0.0 ||
      strategy_max_range_atr_mult <= strategy_min_range_atr_mult ||
      strategy_max_spread_stop_frac < 0.0 ||
      strategy_entry_buffer_points < 0.0 ||
      strategy_tp_atr_mult <= 0.0)
      return true;

   double spread = 0.0;
   if(!Strategy_CurrentSpread(spread))
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);

   const datetime source_now = Strategy_BrokerToSourceTime(TimeCurrent());
   if(!Strategy_AfterAsianSession(source_now) || Strategy_PastEod(source_now))
      return false;
   if(!Strategy_LoadAsianBox(source_now))
      return false;

   const int key = Strategy_SessionKeyFromSourceTime(source_now);
   if(g_trade_taken_key == key || g_orders_placed_key == key)
      return false;
   if(Strategy_HasOurOpenPosition() || Strategy_PendingStopCount() > 0)
      return false;

   const double daily_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(daily_atr <= 0.0)
      return false;

   const double box_size = g_box_high - g_box_low;
   if(box_size < strategy_min_range_atr_mult * daily_atr)
      return false;
   if(box_size > strategy_max_range_atr_mult * daily_atr)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   double spread = 0.0;
   if(!Strategy_CurrentSpread(spread))
      return false;

   const double buffer = strategy_entry_buffer_points * point;
   const double stop_dist = Strategy_StopAtrMultiplier() * daily_atr;
   if(stop_dist <= 0.0 || spread > strategy_max_spread_stop_frac * stop_dist)
      return false;

   datetime source_start = 0;
   datetime source_end = 0;
   Strategy_SourceSessionBounds(source_now, source_start, source_end);
   const datetime eod_source = Strategy_Midnight(source_now) +
                               Strategy_MinuteInput(strategy_eod_close_hour, strategy_eod_close_min) * 60;
   int expiry_seconds = (int)(Strategy_SourceToBrokerTime(eod_source) - TimeCurrent());
   if(expiry_seconds < 60)
      expiry_seconds = 60;

   const double buy_entry = QM_TM_NormalizePrice(_Symbol, g_box_high + buffer);
   const double sell_entry = QM_TM_NormalizePrice(_Symbol, g_box_low - buffer);
   if(buy_entry <= 0.0 || sell_entry <= 0.0 || buy_entry <= sell_entry)
      return false;

   QM_EntryRequest buy_req;
   Strategy_InitRequest(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = QM_TM_NormalizePrice(_Symbol, buy_entry - stop_dist);
   buy_req.tp = strategy_use_atr_tp ? QM_TM_NormalizePrice(_Symbol, buy_entry + strategy_tp_atr_mult * daily_atr) : 0.0;
   buy_req.expiration_seconds = expiry_seconds;
   buy_req.reason = "ASIAN_BOX_BUY_STOP";

   req.type = QM_SELL_STOP;
   req.price = sell_entry;
   req.sl = QM_TM_NormalizePrice(_Symbol, sell_entry + stop_dist);
   req.tp = strategy_use_atr_tp ? QM_TM_NormalizePrice(_Symbol, sell_entry - strategy_tp_atr_mult * daily_atr) : 0.0;
   req.expiration_seconds = expiry_seconds;
   req.reason = "ASIAN_BOX_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;

   if(buy_req.sl <= 0.0 || buy_req.sl >= buy_entry)
      return false;
   if(req.sl <= sell_entry)
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   g_orders_placed_key = key;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   const datetime source_now = Strategy_BrokerToSourceTime(TimeCurrent());
   const int key = Strategy_SessionKeyFromSourceTime(source_now);
   const bool has_position = Strategy_HasOurOpenPosition();
   const int pending_count = Strategy_PendingStopCount();

   if(has_position)
     {
      g_trade_taken_key = key;
      if(pending_count > 0)
         Strategy_RemovePendingStops("opposite_order_after_fill");
      return;
     }

   if(g_orders_placed_key == key && pending_count > 0 && pending_count < 2)
     {
      g_trade_taken_key = key;
      Strategy_RemovePendingStops("one_side_triggered_or_closed");
      return;
     }

   if(pending_count > 0 && Strategy_PastEod(source_now))
      Strategy_RemovePendingStops("asian_box_eod_pending_cancel");
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition())
      return false;
   const datetime source_now = Strategy_BrokerToSourceTime(TimeCurrent());
   return Strategy_PastEod(source_now);
  }

// News Filter Hook
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

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
