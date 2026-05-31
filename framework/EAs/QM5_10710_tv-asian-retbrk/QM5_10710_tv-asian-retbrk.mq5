#property strict
#property version   "5.0"
#property description "QM5_10710 TradingView Asian Range Breakout Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10710;
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
input int    strategy_session1_start_hour = 20;
input int    strategy_session1_start_min  = 0;
input int    strategy_session1_end_hour   = 23;
input int    strategy_session1_end_min    = 59;
input int    strategy_session2_start_hour = 0;
input int    strategy_session2_start_min  = 0;
input int    strategy_session2_end_hour   = 8;
input int    strategy_session2_end_min    = 0;
input int    strategy_atr_period          = 14;
input double strategy_tp_r                = 3.0;
input double strategy_buf_min_points      = 2.0;
input double strategy_buf_atr_frac        = 0.10;
input double strategy_max_stop_atr        = 2.5;
input double strategy_max_spread_stop     = 0.15;
input double strategy_retest_tolerance_pts = 2.0;
input int    strategy_max_hold_bars       = 48;
input bool   strategy_one_per_session     = true;

int    g_session_key = 0;
double g_range_high = 0.0;
double g_range_low = 0.0;
bool   g_range_ready = false;
bool   g_bull_breakout = false;
bool   g_bear_breakout = false;
bool   g_trade_taken_this_session = false;

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_MinuteInput(const int hour_value, const int min_value)
  {
   return hour_value * 60 + min_value;
  }

bool Strategy_TimeInputsValid()
  {
   if(strategy_session1_start_hour < 0 || strategy_session1_start_hour > 23)
      return false;
   if(strategy_session1_end_hour < 0 || strategy_session1_end_hour > 23)
      return false;
   if(strategy_session2_start_hour < 0 || strategy_session2_start_hour > 23)
      return false;
   if(strategy_session2_end_hour < 0 || strategy_session2_end_hour > 23)
      return false;
   if(strategy_session1_start_min < 0 || strategy_session1_start_min > 59)
      return false;
   if(strategy_session1_end_min < 0 || strategy_session1_end_min > 59)
      return false;
   if(strategy_session2_start_min < 0 || strategy_session2_start_min > 59)
      return false;
   if(strategy_session2_end_min < 0 || strategy_session2_end_min > 59)
      return false;
   return true;
  }

bool Strategy_InMinuteWindow(const int minute_value,
                             const int start_minute,
                             const int end_minute,
                             const bool include_end)
  {
   if(start_minute <= end_minute)
     {
      if(include_end)
         return (minute_value >= start_minute && minute_value <= end_minute);
      return (minute_value >= start_minute && minute_value < end_minute);
     }

   if(include_end)
      return (minute_value >= start_minute || minute_value <= end_minute);
   return (minute_value >= start_minute || minute_value < end_minute);
  }

bool Strategy_InAsianSession(const datetime t)
  {
   if(!Strategy_TimeInputsValid())
      return false;

   const int m = Strategy_MinutesOfDay(t);
   const int s1 = Strategy_MinuteInput(strategy_session1_start_hour, strategy_session1_start_min);
   const int e1 = Strategy_MinuteInput(strategy_session1_end_hour, strategy_session1_end_min);
   const int s2 = Strategy_MinuteInput(strategy_session2_start_hour, strategy_session2_start_min);
   const int e2 = Strategy_MinuteInput(strategy_session2_end_hour, strategy_session2_end_min);

   return Strategy_InMinuteWindow(m, s1, e1, true) ||
          Strategy_InMinuteWindow(m, s2, e2, false);
  }

bool Strategy_AfterAsianSession(const datetime t)
  {
   if(!Strategy_TimeInputsValid() || Strategy_InAsianSession(t))
      return false;

   const int m = Strategy_MinutesOfDay(t);
   const int s1 = Strategy_MinuteInput(strategy_session1_start_hour, strategy_session1_start_min);
   const int e2 = Strategy_MinuteInput(strategy_session2_end_hour, strategy_session2_end_min);
   return (m >= e2 && m < s1);
  }

datetime Strategy_Midnight(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return t - (dt.hour * 3600 + dt.min * 60 + dt.sec);
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_SessionKey(const datetime t)
  {
   const int m = Strategy_MinutesOfDay(t);
   const int s1 = Strategy_MinuteInput(strategy_session1_start_hour, strategy_session1_start_min);
   datetime key_day = Strategy_Midnight(t);
   if(m >= s1)
      key_day += 86400;
   return Strategy_DateKey(key_day);
  }

void Strategy_ResetSession(const int session_key)
  {
   g_session_key = session_key;
   g_range_high = 0.0;
   g_range_low = 0.0;
   g_range_ready = false;
   g_bull_breakout = false;
   g_bear_breakout = false;
   g_trade_taken_this_session = false;
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_ReadClosedBar(datetime &bar_time,
                            double &bar_high,
                            double &bar_low,
                            double &bar_close)
  {
   bar_time = iTime(_Symbol, _Period, 1);       // perf-allowed: one closed M15 bar for session-state logic
   bar_high = iHigh(_Symbol, _Period, 1);       // perf-allowed: one closed M15 bar for session-state logic
   bar_low = iLow(_Symbol, _Period, 1);         // perf-allowed: one closed M15 bar for session-state logic
   bar_close = iClose(_Symbol, _Period, 1);     // perf-allowed: one closed M15 bar for session-state logic
   return (bar_time > 0 && bar_high > 0.0 && bar_low > 0.0 && bar_close > 0.0);
  }

void Strategy_AdvanceSessionState(const datetime bar_time,
                                  const double bar_high,
                                  const double bar_low)
  {
   const int key = Strategy_SessionKey(bar_time);
   if(key != g_session_key)
      Strategy_ResetSession(key);

   if(!Strategy_InAsianSession(bar_time))
      return;

   if(!g_range_ready)
     {
      g_range_high = bar_high;
      g_range_low = bar_low;
      g_range_ready = true;
      return;
     }

   g_range_high = MathMax(g_range_high, bar_high);
   g_range_low = MathMin(g_range_low, bar_low);
  }

bool Strategy_StopAndSpreadOK(const bool is_long,
                              const double entry_price,
                              const double stop_price,
                              const double atr_value)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || atr_value <= 0.0 || entry_price <= 0.0 || stop_price <= 0.0)
      return false;

   const double stop_dist = is_long ? (entry_price - stop_price) : (stop_price - entry_price);
   if(stop_dist <= 0.0)
      return false;
   if(stop_dist > strategy_max_stop_atr * atr_value)
      return false;

   const double spread = ask - bid;
   return (spread >= 0.0 && spread <= strategy_max_spread_stop * stop_dist);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;
   if(!Strategy_TimeInputsValid())
      return true;
   if(strategy_atr_period <= 0 || strategy_tp_r <= 0.0)
      return true;
   if(strategy_buf_min_points < 0.0 || strategy_buf_atr_frac < 0.0)
      return true;
   if(strategy_max_stop_atr <= 0.0 || strategy_max_spread_stop < 0.0)
      return true;
   if(strategy_retest_tolerance_pts < 0.0 || strategy_max_hold_bars <= 0)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime bar_time = 0;
   double bar_high = 0.0;
   double bar_low = 0.0;
   double bar_close = 0.0;
   if(!Strategy_ReadClosedBar(bar_time, bar_high, bar_low, bar_close))
      return false;

   Strategy_AdvanceSessionState(bar_time, bar_high, bar_low);
   if(!Strategy_AfterAsianSession(bar_time))
      return false;
   if(!g_range_ready || g_range_high <= g_range_low)
      return false;
   if(strategy_one_per_session && g_trade_taken_this_session)
      return false;
   if(Strategy_HasOurOpenPosition())
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   const double buffer = MathMax(strategy_buf_min_points * point, strategy_buf_atr_frac * atr);
   const double retest_tolerance = strategy_retest_tolerance_pts * point;

   if(!g_bull_breakout && bar_close > g_range_high)
     {
      g_bull_breakout = true;
      return false;
     }

   if(!g_bear_breakout && bar_close < g_range_low)
     {
      g_bear_breakout = true;
      return false;
     }

   if(g_bull_breakout && bar_low <= g_range_high + retest_tolerance && bar_close > g_range_high)
     {
      const double entry = ask;
      const double sl = NormalizeDouble(bar_low - buffer, _Digits);
      const double stop_dist = entry - sl;
      if(Strategy_StopAndSpreadOK(true, entry, sl, atr))
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = NormalizeDouble(entry + strategy_tp_r * stop_dist, _Digits);
         req.reason = "ASIAN_RANGE_BREAKOUT_RETEST_LONG";
         g_trade_taken_this_session = true;
         return true;
        }
     }

   if(g_bear_breakout && bar_high >= g_range_low - retest_tolerance && bar_close < g_range_low)
     {
      const double entry = bid;
      const double sl = NormalizeDouble(bar_high + buffer, _Digits);
      const double stop_dist = sl - entry;
      if(Strategy_StopAndSpreadOK(false, entry, sl, atr))
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = NormalizeDouble(entry - strategy_tp_r * stop_dist, _Digits);
         req.reason = "ASIAN_RANGE_BREAKOUT_RETEST_SHORT";
         g_trade_taken_this_session = true;
         return true;
        }
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, BE, partial, or add-on logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(PERIOD_M15);
   const datetime now = TimeCurrent();
   const bool next_asian_started = Strategy_InAsianSession(now);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(next_asian_started)
         return true;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && seconds_per_bar > 0 &&
         (now - opened) >= strategy_max_hold_bars * seconds_per_bar)
         return true;
     }

   return false;
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
