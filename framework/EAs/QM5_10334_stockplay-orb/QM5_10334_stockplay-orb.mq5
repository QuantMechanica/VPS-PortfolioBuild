#property strict
#property version   "5.0"
#property description "QM5_10334 Stocks-In-Play Opening Range Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10334;
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
input int    strategy_session_start_hour       = 16;
input int    strategy_session_start_minute     = 30;
input int    strategy_session_end_hour         = 23;
input int    strategy_session_end_minute       = 0;
input int    strategy_opening_range_minutes    = 5;
input int    strategy_relative_volume_minutes  = 15;
input int    strategy_volume_median_sessions   = 20;
input double strategy_relative_volume_min      = 1.50;
input int    strategy_atr_period               = 14;
input double strategy_emergency_atr_mult       = 1.00;
input int    strategy_spread_history_bars      = 100;
input double strategy_spread_percentile        = 80.0;

#define QM_SPREAD_HISTORY_MAX 200
#define QM_VOLUME_HISTORY_MAX 60

int    g_session_key = 0;
bool   g_session_active = false;
bool   g_session_volume_stored = false;
bool   g_opening_range_ready = false;
bool   g_first15_ready = false;
bool   g_in_play = false;
bool   g_breakout_taken = false;
bool   g_first_bar_spread_ok = false;

int    g_session_bar_count = 0;
double g_opening_high = 0.0;
double g_opening_low = 0.0;
double g_first15_volume = 0.0;
double g_last_closed_close = 0.0;
double g_last_closed_high = 0.0;
double g_last_closed_low = 0.0;

double g_volume_history[QM_VOLUME_HISTORY_MAX];
int    g_volume_history_count = 0;
int    g_volume_history_next = 0;

double g_spread_history[QM_SPREAD_HISTORY_MAX];
int    g_spread_history_count = 0;
int    g_spread_history_next = 0;
double g_spread_p80_points = 0.0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_ConfiguredMinute(const int hour_value, const int minute_value)
  {
   return MathMax(0, MathMin(23, hour_value)) * 60 + MathMax(0, MathMin(59, minute_value));
  }

bool Strategy_MinuteInSession(const int minute_value)
  {
   const int start_minute = Strategy_ConfiguredMinute(strategy_session_start_hour, strategy_session_start_minute);
   const int end_minute = Strategy_ConfiguredMinute(strategy_session_end_hour, strategy_session_end_minute);
   if(start_minute == end_minute)
      return false;
   if(start_minute < end_minute)
      return (minute_value >= start_minute && minute_value < end_minute);
   return (minute_value >= start_minute || minute_value < end_minute);
  }

double Strategy_Percentile(const double &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;

   double temp[QM_SPREAD_HISTORY_MAX];
   const int capped = MathMin(count, QM_SPREAD_HISTORY_MAX);
   for(int i = 0; i < capped; ++i)
      temp[i] = values[i];

   for(int i = 1; i < capped; ++i)
     {
      const double key = temp[i];
      int j = i - 1;
      while(j >= 0 && temp[j] > key)
        {
         temp[j + 1] = temp[j];
         --j;
        }
      temp[j + 1] = key;
     }

   const double pct = MathMax(0.0, MathMin(100.0, percentile)) / 100.0;
   const int idx = (int)MathFloor((capped - 1) * pct);
   return temp[MathMax(0, MathMin(capped - 1, idx))];
  }

double Strategy_MedianVolume()
  {
   if(g_volume_history_count <= 0)
      return 0.0;

   double temp[QM_VOLUME_HISTORY_MAX];
   for(int i = 0; i < g_volume_history_count; ++i)
      temp[i] = g_volume_history[i];

   for(int i = 1; i < g_volume_history_count; ++i)
     {
      const double key = temp[i];
      int j = i - 1;
      while(j >= 0 && temp[j] > key)
        {
         temp[j + 1] = temp[j];
         --j;
        }
      temp[j + 1] = key;
     }

   const int mid = g_volume_history_count / 2;
   if((g_volume_history_count % 2) == 1)
      return temp[mid];
   return 0.5 * (temp[mid - 1] + temp[mid]);
  }

void Strategy_StoreSessionVolume()
  {
   if(g_session_volume_stored || !g_first15_ready || g_first15_volume <= 0.0)
      return;

   const int max_sessions = MathMax(1, MathMin(strategy_volume_median_sessions, QM_VOLUME_HISTORY_MAX));
   g_volume_history[g_volume_history_next] = g_first15_volume;
   g_volume_history_next = (g_volume_history_next + 1) % max_sessions;
   if(g_volume_history_count < max_sessions)
      g_volume_history_count++;
   g_session_volume_stored = true;
  }

void Strategy_ResetSession(const int day_key)
  {
   Strategy_StoreSessionVolume();

   g_session_key = day_key;
   g_session_active = true;
   g_session_volume_stored = false;
   g_opening_range_ready = false;
   g_first15_ready = false;
   g_in_play = false;
   g_breakout_taken = false;
   g_first_bar_spread_ok = false;
   g_session_bar_count = 0;
   g_opening_high = 0.0;
   g_opening_low = 0.0;
   g_first15_volume = 0.0;
  }

void Strategy_UpdateSpreadHistory()
  {
   const long spread_raw = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_raw <= 0)
      return;

   const int max_bars = MathMax(20, MathMin(strategy_spread_history_bars, QM_SPREAD_HISTORY_MAX));
   g_spread_history[g_spread_history_next] = (double)spread_raw;
   g_spread_history_next = (g_spread_history_next + 1) % max_bars;
   if(g_spread_history_count < max_bars)
      g_spread_history_count++;
   if(g_spread_history_count >= 20)
      g_spread_p80_points = Strategy_Percentile(g_spread_history, g_spread_history_count, strategy_spread_percentile);
  }

bool Strategy_CurrentSpreadAllowed()
  {
   if(g_spread_history_count < 20 || g_spread_p80_points <= 0.0)
      return true;
   const long spread_raw = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_raw <= 0)
      return false;
   return ((double)spread_raw <= g_spread_p80_points);
  }

void AdvanceState_OnNewBar()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar ORB cache
   if(bar_time <= 0)
      return;

   const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: closed-bar ORB cache
   const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed: closed-bar ORB cache
   const double bar_close = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar ORB cache
   const long bar_volume_raw = iVolume(_Symbol, _Period, 1); // perf-allowed: closed-bar ORB cache
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return;

   g_last_closed_high = bar_high;
   g_last_closed_low = bar_low;
   g_last_closed_close = bar_close;
   Strategy_UpdateSpreadHistory();

   const int minute = Strategy_MinuteOfDay(bar_time);
   const int start_minute = Strategy_ConfiguredMinute(strategy_session_start_hour, strategy_session_start_minute);
   const int day_key = Strategy_DayKey(bar_time);
   const bool is_start_bar = (minute == start_minute);

   if(is_start_bar && day_key != g_session_key)
      Strategy_ResetSession(day_key);

   if(!g_session_active)
      return;

   if(!Strategy_MinuteInSession(minute))
     {
      Strategy_StoreSessionVolume();
      g_session_active = false;
      return;
     }

   g_session_bar_count++;
   if(g_session_bar_count == 1)
     {
      g_opening_high = bar_high;
      g_opening_low = bar_low;
      g_first15_volume = (double)MathMax(0, bar_volume_raw);
      g_opening_range_ready = true;

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const long spread_raw = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      const double spread_price = (point > 0.0 && spread_raw > 0) ? (point * (double)spread_raw) : 0.0;
      g_first_bar_spread_ok = (spread_price > 0.0 && (g_opening_high - g_opening_low) >= 3.0 * spread_price);
      return;
     }

   if(g_session_bar_count <= 3)
      g_first15_volume += (double)MathMax(0, bar_volume_raw);

   if(g_session_bar_count == 3)
     {
      const int required_sessions = MathMax(1, MathMin(strategy_volume_median_sessions, QM_VOLUME_HISTORY_MAX));
      const double median_volume = Strategy_MedianVolume();
      g_first15_ready = true;
      g_in_play = (g_volume_history_count >= required_sessions &&
                   median_volume > 0.0 &&
                   g_first15_volume >= strategy_relative_volume_min * median_volume);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_session_active || !g_opening_range_ready || !g_first15_ready || !g_in_play)
      return false;
   if(g_breakout_taken || !g_first_bar_spread_ok || !Strategy_CurrentSpreadAllowed())
      return false;
   if(g_last_closed_high <= 0.0 || g_last_closed_low <= 0.0 || g_last_closed_close <= 0.0)
      return false;

   const bool broke_high = (g_last_closed_high > g_opening_high);
   const bool broke_low = (g_last_closed_low < g_opening_low);
   if(!broke_high && !broke_low)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double emergency = atr * strategy_emergency_atr_mult;
   if(ask <= 0.0 || bid <= 0.0 || emergency <= 0.0)
      return false;

   const double midpoint = 0.5 * (g_opening_high + g_opening_low);
   const bool choose_long = (broke_high && !broke_low) || (broke_high && broke_low && g_last_closed_close >= midpoint);

   if(choose_long)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = g_opening_low;
      if((req.price - req.sl) > emergency)
         req.sl = req.price - emergency;
      req.reason = "STOCKPLAY_ORB_LONG";
     }
   else
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = g_opening_high;
      if((req.sl - req.price) > emergency)
         req.sl = req.price + emergency;
      req.reason = "STOCKPLAY_ORB_SHORT";
     }

   if(req.sl <= 0.0 || MathAbs(req.price - req.sl) <= 0.0)
      return false;

   g_breakout_taken = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int now_minute = Strategy_MinuteOfDay(TimeCurrent());
   const int end_minute = Strategy_ConfiguredMinute(strategy_session_end_hour, strategy_session_end_minute);
   if(now_minute >= end_minute && strategy_session_start_hour <= strategy_session_end_hour)
      return true;

   if(g_opening_range_ready && g_last_closed_close > g_opening_low && g_last_closed_close < g_opening_high)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10334_stockplay_orb\"}");
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

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

   if(!is_new_bar)
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
