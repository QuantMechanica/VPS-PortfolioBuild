#property strict
#property version   "5.0"
#property description "QM5_10335 Volume-Confirmed ORB"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10335;
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
input int    strategy_session_open_hour       = 9;
input int    strategy_session_open_minute     = 0;
input int    strategy_session_close_hour      = 17;
input int    strategy_session_close_minute    = 30;
input int    strategy_opening_range_minutes   = 15;
input int    strategy_volume_median_sessions  = 20;
input double strategy_relative_volume_min     = 1.20;
input int    strategy_holding_bars            = 3;
input int    strategy_atr_period              = 14;
input double strategy_emergency_atr_mult      = 0.80;
input int    strategy_spread_lookback_bars    = 120;
input double strategy_spread_percentile       = 80.0;

#define STRATEGY_VOLUME_MAX 60
#define STRATEGY_SPREAD_MAX 500

int      g_session_key = 0;
bool     g_session_ready = false;
bool     g_opening_range_ready = false;
bool     g_session_breakout_taken = false;
double   g_opening_high = 0.0;
double   g_opening_low = 0.0;
datetime g_signal_bar_time = 0;
double   g_signal_close = 0.0;
double   g_signal_volume = 0.0;
int      g_signal_minute = -1;

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

int Strategy_PeriodMinutes()
  {
   const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds <= 0)
      return 5;
   return MathMax(1, seconds / 60);
  }

bool Strategy_MinuteInSession(const int minute_value)
  {
   const int open_minute = Strategy_ConfiguredMinute(strategy_session_open_hour, strategy_session_open_minute);
   const int close_minute = Strategy_ConfiguredMinute(strategy_session_close_hour, strategy_session_close_minute);
   if(open_minute == close_minute)
      return false;
   if(open_minute < close_minute)
      return (minute_value >= open_minute && minute_value < close_minute);
   return (minute_value >= open_minute || minute_value < close_minute);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
  }

double Strategy_SortedMedian(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;

   for(int i = 1; i < count; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }

   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

double Strategy_SortedPercentile(double &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;

   for(int i = 1; i < count; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }

   const double pct = MathMax(0.0, MathMin(100.0, percentile)) / 100.0;
   const int idx = (int)MathFloor((double)(count - 1) * pct);
   return values[MathMax(0, MathMin(count - 1, idx))];
  }

double Strategy_SameTimeVolumeMedian(const datetime bar_time)
  {
   const int required = MathMax(1, MathMin(strategy_volume_median_sessions, STRATEGY_VOLUME_MAX));
   const int target_minute = Strategy_MinuteOfDay(bar_time);
   double vols[STRATEGY_VOLUME_MAX];
   int count = 0;

   for(int day_back = 1; day_back <= 45 && count < required; ++day_back)
     {
      const datetime target = bar_time - (datetime)(day_back * 86400);
      const int shift = iBarShift(_Symbol, _Period, target, false); // perf-allowed: bounded same-time volume lookup
      if(shift <= 0)
         continue;

      const datetime candidate_time = iTime(_Symbol, _Period, shift); // perf-allowed: bounded same-time validation
      if(candidate_time <= 0 || Strategy_MinuteOfDay(candidate_time) != target_minute)
         continue;

      const long volume_raw = iVolume(_Symbol, _Period, shift); // perf-allowed: bounded same-time volume lookup
      if(volume_raw <= 0)
         continue;

      vols[count] = (double)volume_raw;
      count++;
     }

   if(count < required)
      return 0.0;
   return Strategy_SortedMedian(vols, count);
  }

bool Strategy_SpreadAllowed()
  {
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   const int lookback = MathMax(20, MathMin(strategy_spread_lookback_bars, STRATEGY_SPREAD_MAX));
   double spreads[STRATEGY_SPREAD_MAX];
   int count = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const int spread_value = iSpread(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar spread percentile
      if(spread_value <= 0)
         continue;
      spreads[count] = (double)spread_value;
      count++;
     }

   if(count < 20)
      return true;

   const double threshold = Strategy_SortedPercentile(spreads, count, strategy_spread_percentile);
   if(threshold <= 0.0)
      return true;

   return ((double)current_spread <= threshold);
  }

bool Strategy_RangeWidthAllowed()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_raw = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(point <= 0.0 || spread_raw <= 0 || g_opening_high <= g_opening_low)
      return false;

   const double spread_price = point * (double)spread_raw;
   return ((g_opening_high - g_opening_low) >= 3.0 * spread_price);
  }

void Strategy_ResetSession(const int day_key)
  {
   g_session_key = day_key;
   g_session_ready = true;
   g_opening_range_ready = false;
   g_session_breakout_taken = false;
   g_opening_high = 0.0;
   g_opening_low = 0.0;
  }

void Strategy_AdvanceOnClosedBar()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar ORB state
   if(bar_time <= 0)
      return;

   g_signal_bar_time = bar_time;
   g_signal_close = iClose(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar breakout close
   g_signal_volume = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar breakout volume
   g_signal_minute = Strategy_MinuteOfDay(bar_time);

   const int open_minute = Strategy_ConfiguredMinute(strategy_session_open_hour, strategy_session_open_minute);
   const int offset_minutes = g_signal_minute - open_minute;
   const int day_key = Strategy_DayKey(bar_time);

   if(g_signal_minute == open_minute && day_key != g_session_key)
      Strategy_ResetSession(day_key);

   if(!g_session_ready || day_key != g_session_key)
      return;

   if(!Strategy_MinuteInSession(g_signal_minute))
     {
      g_session_ready = false;
      return;
     }

   const int range_minutes = MathMax(Strategy_PeriodMinutes(), strategy_opening_range_minutes);
   if(offset_minutes >= 0 && offset_minutes < range_minutes)
     {
      const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar opening range high
      const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar opening range low
      if(bar_high <= 0.0 || bar_low <= 0.0)
         return;

      if(g_opening_high <= 0.0 || bar_high > g_opening_high)
         g_opening_high = bar_high;
      if(g_opening_low <= 0.0 || bar_low < g_opening_low)
         g_opening_low = bar_low;

      if(offset_minutes + Strategy_PeriodMinutes() >= range_minutes)
         g_opening_range_ready = true;
     }
  }

// Return TRUE to BLOCK trading this tick (time/spread gate only; framework owns news).
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M5)
      return true;

   if(Strategy_HasOpenPosition())
      return false;

   const int now_minute = Strategy_MinuteOfDay(TimeCurrent());
   if(!Strategy_MinuteInSession(now_minute))
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (current_spread <= 0);
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

   Strategy_AdvanceOnClosedBar();

   if(Strategy_HasOpenPosition() || g_session_breakout_taken)
      return false;
   if(!g_session_ready || !g_opening_range_ready)
      return false;
   if(g_signal_close <= 0.0 || g_signal_volume <= 0.0)
      return false;

   const int open_minute = Strategy_ConfiguredMinute(strategy_session_open_hour, strategy_session_open_minute);
   const int range_minutes = MathMax(Strategy_PeriodMinutes(), strategy_opening_range_minutes);
   if(g_signal_minute < open_minute + range_minutes)
      return false;
   if(!Strategy_MinuteInSession(g_signal_minute))
      return false;
   if(!Strategy_RangeWidthAllowed() || !Strategy_SpreadAllowed())
      return false;

   const double median_volume = Strategy_SameTimeVolumeMedian(g_signal_bar_time);
   if(median_volume <= 0.0 || (g_signal_volume / median_volume) < strategy_relative_volume_min)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   const double emergency_distance = atr * strategy_emergency_atr_mult;
   if(ask <= 0.0 || bid <= 0.0 || emergency_distance <= 0.0)
      return false;

   if(g_signal_close > g_opening_high)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = g_opening_low;
      if((req.price - req.sl) > emergency_distance)
         req.sl = req.price - emergency_distance;
      req.reason = "NSE_VOL_ORB_LONG";
      g_session_breakout_taken = true;
      return (req.sl > 0.0 && req.sl < req.price);
     }

   if(g_signal_close < g_opening_low)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = g_opening_high;
      if((req.sl - req.price) > emergency_distance)
         req.sl = req.price + emergency_distance;
      req.reason = "NSE_VOL_ORB_SHORT";
      g_session_breakout_taken = true;
      return (req.sl > req.price);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int now_minute = Strategy_MinuteOfDay(TimeCurrent());
   const int close_minute = Strategy_ConfiguredMinute(strategy_session_close_hour, strategy_session_close_minute);
   if(now_minute >= close_minute)
      return (QM_TM_OpenPositionCount(magic) > 0);

   const int hold_seconds = MathMax(1, strategy_holding_bars) * PeriodSeconds(PERIOD_M5);
   const datetime now_time = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && (now_time - open_time) >= hold_seconds)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10335_nse_vol_orb\"}");
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
