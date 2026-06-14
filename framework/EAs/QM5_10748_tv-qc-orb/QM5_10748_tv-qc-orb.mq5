#property strict
#property version   "5.0"
#property description "QM5_10748 tv-qc-orb"

#include <QM/QM_Common.mqh>

#define OR_RANGE_STORE_MAX 256

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10748;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_session_start_hour_et = 9;
input int    strategy_session_start_min_et  = 30;
input int    strategy_orb_minutes           = 15;
input int    strategy_session_end_hour_et   = 16;
input int    strategy_session_end_min_et    = 0;
input int    strategy_adaptive_lookback     = 20;
input double strategy_adaptive_min_ratio    = 0.50;
input double strategy_adaptive_max_ratio    = 2.00;
input double strategy_adaptive_stop_mult    = 1.00;
input double strategy_rr_target             = 1.50;
input int    strategy_retest_timeout_bars   = 10;
input int    strategy_retest_level_mode     = 2;     // 0=OR edge, 1=midpoint, 2=either.
input int    strategy_min_or_range_points   = 0;
input int    strategy_max_spread_points     = 0;
input bool   strategy_trade_monday          = true;
input bool   strategy_trade_tuesday         = true;
input bool   strategy_trade_wednesday       = true;
input bool   strategy_trade_thursday        = true;
input bool   strategy_trade_friday          = true;

int      g_session_date_key       = 0;
bool     g_or_has_bars            = false;
bool     g_or_locked              = false;
double   g_or_high                = 0.0;
double   g_or_low                 = 0.0;
double   g_locked_avg_or_range    = 0.0;
bool     g_long_traded_today      = false;
bool     g_short_traded_today     = false;
int      g_breakout_dir           = 0;
int      g_retest_bars_waited     = 0;
double   g_or_ranges[OR_RANGE_STORE_MAX];
int      g_or_range_count         = 0;
int      g_or_range_next          = 0;
double   g_last_open              = 0.0;
double   g_last_high              = 0.0;
double   g_last_low               = 0.0;
double   g_last_close             = 0.0;
int      g_last_et_minutes        = -1;
int      g_last_et_date_key       = 0;
int      g_last_et_day_of_week    = -1;

datetime BrokerToEastern(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   return utc + offset_hours * 3600;
  }

int EtDateKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(BrokerToEastern(broker_time), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int EtMinutesOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(BrokerToEastern(broker_time), dt);
   return dt.hour * 60 + dt.min;
  }

int EtDayOfWeek(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(BrokerToEastern(broker_time), dt);
   return dt.day_of_week;
  }

int SessionStartMinutes()
  {
   return strategy_session_start_hour_et * 60 + strategy_session_start_min_et;
  }

int SessionEndMinutes()
  {
   return strategy_session_end_hour_et * 60 + strategy_session_end_min_et;
  }

bool WeekdayEnabled(const int dow)
  {
   if(dow == 1)
      return strategy_trade_monday;
   if(dow == 2)
      return strategy_trade_tuesday;
   if(dow == 3)
      return strategy_trade_wednesday;
   if(dow == 4)
      return strategy_trade_thursday;
   if(dow == 5)
      return strategy_trade_friday;
   return false;
  }

void ResetSessionState(const int date_key)
  {
   g_session_date_key = date_key;
   g_or_has_bars = false;
   g_or_locked = false;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_locked_avg_or_range = 0.0;
   g_long_traded_today = false;
   g_short_traded_today = false;
   g_breakout_dir = 0;
   g_retest_bars_waited = 0;
  }

double AverageStoredORRange()
  {
   const int samples = MathMin(strategy_adaptive_lookback, g_or_range_count);
   if(samples <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < samples; ++i)
     {
      int idx = g_or_range_next - 1 - i;
      while(idx < 0)
         idx += OR_RANGE_STORE_MAX;
      sum += g_or_ranges[idx % OR_RANGE_STORE_MAX];
     }

   return sum / samples;
  }

void StoreORRange(const double range)
  {
   if(range <= 0.0)
      return;

   g_or_ranges[g_or_range_next] = range;
   g_or_range_next = (g_or_range_next + 1) % OR_RANGE_STORE_MAX;
   if(g_or_range_count < OR_RANGE_STORE_MAX)
      g_or_range_count++;
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

bool ClosedBarSnapshot()
  {
   MqlRates rates[1];
   if(CopyRates(_Symbol, _Period, 1, 1, rates) != 1) // perf-allowed: one closed-bar OHLC/time row after framework new-bar gate.
      return false;

   g_last_open = rates[0].open;
   g_last_high = rates[0].high;
   g_last_low = rates[0].low;
   g_last_close = rates[0].close;
   g_last_et_minutes = EtMinutesOfDay(rates[0].time);
   g_last_et_date_key = EtDateKey(rates[0].time);
   g_last_et_day_of_week = EtDayOfWeek(rates[0].time);

   return (g_last_open > 0.0 && g_last_high > 0.0 && g_last_low > 0.0 && g_last_close > 0.0);
  }

void LockOpeningRangeIfReady()
  {
   if(g_or_locked || !g_or_has_bars)
      return;

   const int or_end = SessionStartMinutes() + strategy_orb_minutes;
   if(g_last_et_minutes < or_end)
      return;

   const double today_range = g_or_high - g_or_low;
   if(today_range <= 0.0)
      return;

   double avg_range = AverageStoredORRange();
   if(avg_range <= 0.0)
      avg_range = today_range;

   g_locked_avg_or_range = avg_range;
   g_or_locked = true;
   StoreORRange(today_range);
  }

void AdvanceStateOnClosedBar()
  {
   if(!ClosedBarSnapshot())
      return;

   if(g_session_date_key != g_last_et_date_key)
      ResetSessionState(g_last_et_date_key);

   const int or_start = SessionStartMinutes();
   const int or_end = or_start + strategy_orb_minutes;
   if(g_last_et_minutes >= or_start && g_last_et_minutes < or_end)
     {
      if(!g_or_has_bars)
        {
         g_or_high = g_last_high;
         g_or_low = g_last_low;
         g_or_has_bars = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, g_last_high);
         g_or_low = MathMin(g_or_low, g_last_low);
        }
     }

   LockOpeningRangeIfReady();
  }

bool EntryTimeAllowsTrade()
  {
   if(!WeekdayEnabled(g_last_et_day_of_week))
      return false;

   const int start_after_or = SessionStartMinutes() + strategy_orb_minutes;
   if(g_last_et_minutes < start_after_or)
      return false;
   if(g_last_et_minutes >= SessionEndMinutes())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   if(strategy_min_or_range_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0 || (g_or_high - g_or_low) / point < strategy_min_or_range_points)
         return false;
     }

   return true;
  }

bool IsRetestRejection(const int dir, const double level)
  {
   if(level <= 0.0)
      return false;

   if(dir > 0)
      return (g_last_low <= level && g_last_close > level && g_last_close > g_last_open);
   if(dir < 0)
      return (g_last_high >= level && g_last_close < level && g_last_close < g_last_open);
   return false;
  }

bool RetestConfirmed(const int dir)
  {
   const double midpoint = (g_or_high + g_or_low) * 0.5;

   if(strategy_retest_level_mode == 0)
      return IsRetestRejection(dir, (dir > 0) ? g_or_high : g_or_low);
   if(strategy_retest_level_mode == 1)
      return IsRetestRejection(dir, midpoint);

   if(IsRetestRejection(dir, (dir > 0) ? g_or_high : g_or_low))
      return true;
   return IsRetestRejection(dir, midpoint);
  }

bool BuildOrderRequest(QM_EntryRequest &req, const int dir)
  {
   const QM_OrderType side = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double today_range = g_or_high - g_or_low;
   const double avg_range = (g_locked_avg_or_range > 0.0) ? g_locked_avg_or_range : today_range;
   if(today_range <= 0.0 || avg_range <= 0.0)
      return false;

   const bool normal_range = (today_range >= avg_range * strategy_adaptive_min_ratio &&
                              today_range <= avg_range * strategy_adaptive_max_ratio);
   double sl = 0.0;
   if(normal_range)
      sl = (dir > 0) ? g_or_low : g_or_high;

   if(sl <= 0.0 || (dir > 0 && sl >= entry) || (dir < 0 && sl <= entry))
     {
      const double stop_distance = avg_range * strategy_adaptive_stop_mult;
      if(stop_distance <= 0.0)
         return false;
      sl = (dir > 0) ? entry - stop_distance : entry + stop_distance;
     }

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = (dir > 0) ? "QC_ORB_RETEST_LONG" : "QC_ORB_RETEST_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const int et_minutes = EtMinutesOfDay(broker_now);
   const int et_dow = EtDayOfWeek(broker_now);

   if(!WeekdayEnabled(et_dow))
      return true;
   if(et_minutes < SessionStartMinutes() || et_minutes >= SessionEndMinutes())
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

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

   AdvanceStateOnClosedBar();

   if(!g_or_locked || !EntryTimeAllowsTrade() || HasOurOpenPosition())
      return false;

   if(g_breakout_dir == 0)
     {
      if(g_last_close > g_or_high && !g_long_traded_today)
        {
         g_breakout_dir = 1;
         g_retest_bars_waited = 0;
        }
      else if(g_last_close < g_or_low && !g_short_traded_today)
        {
         g_breakout_dir = -1;
         g_retest_bars_waited = 0;
        }
      return false;
     }

   g_retest_bars_waited++;
   if(g_retest_bars_waited > strategy_retest_timeout_bars)
     {
      g_breakout_dir = 0;
      g_retest_bars_waited = 0;
      return false;
     }

   if(!RetestConfirmed(g_breakout_dir))
      return false;

   const int dir = g_breakout_dir;
   g_breakout_dir = 0;
   g_retest_bars_waited = 0;

   if(dir > 0)
      g_long_traded_today = true;
   else
      g_short_traded_today = true;

   return BuildOrderRequest(req, dir);
  }

void Strategy_ManageOpenPosition()
  {
   // Source baseline uses full-position SL/TP only; no trailing, BE, or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;

   const int et_minutes = EtMinutesOfDay(TimeCurrent());
   return (et_minutes >= SessionEndMinutes());
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10748_tv-qc-orb\"}");
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
