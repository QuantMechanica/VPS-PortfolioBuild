#property strict
#property version   "5.0"
#property description "QM5_10760 TradingView IU Opening Range Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10760;
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
input int    strategy_session_start_hhmm        = 915;
input int    strategy_session_end_hhmm          = 1515;
input int    strategy_opening_range_minutes     = 15;
input int    strategy_max_trades_per_day        = 2;
input double strategy_rr_target                 = 2.0;
input int    strategy_atr_period                = 14;
input double strategy_min_stop_atr              = 0.25;
input double strategy_max_stop_atr              = 3.00;
input double strategy_max_spread_points         = 0.0;

int      g_strategy_day_key       = 0;
int      g_strategy_trades_today  = 0;
bool     g_strategy_or_has_range  = false;
bool     g_strategy_or_ready      = false;
double   g_strategy_or_high       = 0.0;
double   g_strategy_or_low        = 0.0;
datetime g_strategy_or_locked_at  = 0;

int Strategy_HhmmToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return -1;
   return hh * 60 + mm;
  }

int Strategy_HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int start_m = Strategy_HhmmToMinutes(start_hhmm);
   const int end_m = Strategy_HhmmToMinutes(end_hhmm);
   if(now_m < 0 || start_m < 0 || end_m < 0 || start_m == end_m)
      return false;
   if(start_m < end_m)
      return (now_m >= start_m && now_m < end_m);
   return (now_m >= start_m || now_m < end_m);
  }

int Strategy_MinutesFromSessionStart(const int hhmm)
  {
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int start_m = Strategy_HhmmToMinutes(strategy_session_start_hhmm);
   if(now_m < 0 || start_m < 0)
      return -1;
   int delta = now_m - start_m;
   if(delta < 0)
      delta += 1440;
   return delta;
  }

void Strategy_ResetDay(const int day_key)
  {
   g_strategy_day_key = day_key;
   g_strategy_trades_today = 0;
   g_strategy_or_has_range = false;
   g_strategy_or_ready = false;
   g_strategy_or_high = 0.0;
   g_strategy_or_low = 0.0;
   g_strategy_or_locked_at = 0;
  }

void Strategy_ResetDayIfNeeded(const datetime t)
  {
   const int day_key = Strategy_DayKey(t);
   if(day_key != g_strategy_day_key)
      Strategy_ResetDay(day_key);
  }

bool Strategy_ReadClosedBars(MqlRates &bar1, MqlRates &bar2)
  {
   MqlRates bars[2];
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 2, bars) != 2) // perf-allowed: two closed bars for OR breakout and previous-candle stop; caller is behind QM_IsNewBar().
      return false;
   bar1 = bars[0];
   bar2 = bars[1];
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   return ((ask - bid) / point) <= strategy_max_spread_points;
  }

void Strategy_AdvanceOpeningRange(const MqlRates &bar)
  {
   Strategy_ResetDayIfNeeded(bar.time);

   const int hhmm = Strategy_HhmmFromTime(bar.time);
   if(!Strategy_HhmmInWindow(hhmm, strategy_session_start_hhmm, strategy_session_end_hhmm))
      return;

   const int elapsed = Strategy_MinutesFromSessionStart(hhmm);
   if(elapsed < 0)
      return;

   const int or_minutes = MathMax(5, MathMin(60, strategy_opening_range_minutes));
   const int bar_minutes = MathMax(1, PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60);

   if(elapsed < or_minutes)
     {
      if(!g_strategy_or_has_range)
        {
         g_strategy_or_high = bar.high;
         g_strategy_or_low = bar.low;
         g_strategy_or_has_range = true;
        }
      else
        {
         g_strategy_or_high = MathMax(g_strategy_or_high, bar.high);
         g_strategy_or_low = MathMin(g_strategy_or_low, bar.low);
        }

      if(elapsed + bar_minutes >= or_minutes)
        {
         g_strategy_or_ready = true;
         g_strategy_or_locked_at = bar.time + bar_minutes * 60;
        }
      return;
     }

   if(g_strategy_or_has_range && !g_strategy_or_ready)
     {
      g_strategy_or_ready = true;
      g_strategy_or_locked_at = bar.time;
     }
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   if(strategy_min_stop_atr > 0.0 && stop_distance < atr * strategy_min_stop_atr)
      return false;
   if(strategy_max_stop_atr > 0.0 && stop_distance > atr * strategy_max_stop_atr)
      return false;
   return true;
  }

bool Strategy_BuildRequest(const bool want_long, const MqlRates &bar, QM_EntryRequest &req)
  {
   const double entry = want_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   const double sl = want_long ? bar.low : bar.high;
   if(want_long && sl >= entry)
      return false;
   if(!want_long && sl <= entry)
      return false;
   if(!Strategy_StopDistanceAllowed(entry, sl))
      return false;

   req.type = want_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
   req.reason = want_long ? "TV_IU_ORB_LONG_PREV_CANDLE_STOP" : "TV_IU_ORB_SHORT_PREV_CANDLE_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(want_long && req.tp <= entry)
      return false;
   if(!want_long && req.tp >= entry)
      return false;
   return true;
  }

// No Trade Filter: time, spread, and framework news hooks gate entries.
bool Strategy_NoTradeFilter()
  {
   Strategy_ResetDayIfNeeded(TimeCurrent());

   if(Strategy_HasOurOpenPosition())
      return false;

   if(!Strategy_SpreadAllowed())
      return true;

   const int hhmm = Strategy_HhmmFromTime(TimeCurrent());
   if(!Strategy_HhmmInWindow(hhmm, strategy_session_start_hhmm, strategy_session_end_hhmm))
      return true;

   if(strategy_max_trades_per_day > 0 && g_strategy_trades_today >= strategy_max_trades_per_day)
      return true;

   return false;
  }

// Trade Entry: post-opening-range close cross with previous-candle SL and RR TP.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlRates bar1, bar2;
   if(!Strategy_ReadClosedBars(bar1, bar2))
      return false;

   Strategy_AdvanceOpeningRange(bar1);

   if(Strategy_HasOurOpenPosition())
      return false;
   if(strategy_max_trades_per_day > 0 && g_strategy_trades_today >= strategy_max_trades_per_day)
      return false;
   if(!g_strategy_or_has_range || !g_strategy_or_ready || g_strategy_or_high <= g_strategy_or_low)
      return false;
   if(bar1.time < g_strategy_or_locked_at)
      return false;

   const int hhmm = Strategy_HhmmFromTime(bar1.time);
   if(!Strategy_HhmmInWindow(hhmm, strategy_session_start_hhmm, strategy_session_end_hhmm))
      return false;

   const bool long_signal = (bar2.close <= g_strategy_or_high && bar1.close > g_strategy_or_high);
   const bool short_signal = (bar2.close >= g_strategy_or_low && bar1.close < g_strategy_or_low);

   if(long_signal && Strategy_BuildRequest(true, bar1, req))
     {
      g_strategy_trades_today++;
      return true;
     }

   if(short_signal && Strategy_BuildRequest(false, bar1, req))
     {
      g_strategy_trades_today++;
      return true;
     }

   return false;
  }

// Trade Management: source baseline has no trailing, break-even, or partial close.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: force flat at configured session end.
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition())
      return false;

   const int close_m = Strategy_HhmmToMinutes(strategy_session_end_hhmm);
   const int now_m = Strategy_HhmmToMinutes(Strategy_HhmmFromTime(TimeCurrent()));
   if(close_m < 0 || now_m < 0)
      return false;

   return now_m >= close_m;
  }

// News Filter Hook: callable for P8; default delegates to framework news logic.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   Strategy_ResetDay(0);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10760\",\"ea\":\"QM5_10760_tv_iu_orb\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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

