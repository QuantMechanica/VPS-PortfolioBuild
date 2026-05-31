#property strict
#property version   "5.0"
#property description "QM5_10687 TradingView Parent Session Sweep Reclaim"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10687;
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
input int    strategy_asia_start_hour       = 0;
input int    strategy_asia_end_hour         = 8;
input int    strategy_london_start_hour     = 8;
input int    strategy_london_end_hour       = 16;
input int    strategy_newyork_start_hour    = 13;
input int    strategy_newyork_end_hour      = 21;
input double strategy_min_rr                = 1.5;
input bool   strategy_reclaim_filter        = true;
input int    strategy_atr_period            = 14;
input double strategy_stop_atr_buffer       = 0.10;
input int    strategy_max_spread_points     = 60;
input int    strategy_rollover_start_hhmm   = 2355;
input int    strategy_rollover_end_hhmm     = 5;

struct SessionRange
  {
   bool     active;
   bool     ready;
   int      key;
   datetime start_time;
   datetime end_time;
   double   high;
   double   low;
  };

SessionRange g_current_sessions[3];
SessionRange g_done_sessions[3];
int          g_last_trade_parent_key = -1;
datetime     g_active_exit_time = 0;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int SessionStartHour(const int idx)
  {
   if(idx == 0)
      return strategy_asia_start_hour;
   if(idx == 1)
      return strategy_london_start_hour;
   return strategy_newyork_start_hour;
  }

int SessionEndHour(const int idx)
  {
   if(idx == 0)
      return strategy_asia_end_hour;
   if(idx == 1)
      return strategy_london_end_hour;
   return strategy_newyork_end_hour;
  }

string SessionName(const int idx)
  {
   if(idx == 0)
      return "ASIA";
   if(idx == 1)
      return "LONDON";
   return "NEWYORK";
  }

datetime DateAtMinutes(const datetime t, const int minutes)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = minutes / 60;
   dt.min = minutes % 60;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool SessionWindow(const datetime t,
                   const int idx,
                   datetime &session_start,
                   datetime &session_end)
  {
   const int start_min = MathMax(0, MathMin(23, SessionStartHour(idx))) * 60;
   const int end_min = MathMax(0, MathMin(24, SessionEndHour(idx))) * 60;
   const int minute_now = MinutesOfDay(t);
   if(start_min == end_min)
      return false;

   if(start_min < end_min)
     {
      session_start = DateAtMinutes(t, start_min);
      session_end = DateAtMinutes(t, end_min);
      return (minute_now >= start_min && minute_now < end_min);
     }

   if(minute_now >= start_min)
     {
      session_start = DateAtMinutes(t, start_min);
      session_end = DateAtMinutes(t, end_min) + 86400;
      return true;
     }

   if(minute_now < end_min)
     {
      session_start = DateAtMinutes(t, start_min) - 86400;
      session_end = DateAtMinutes(t, end_min);
      return true;
     }

   session_start = 0;
   session_end = 0;
   return false;
  }

int SessionKey(const datetime session_start, const int idx)
  {
   MqlDateTime dt;
   TimeToStruct(session_start, dt);
   return (dt.year * 1000 + dt.day_of_year) * 10 + idx;
  }

void FinalizeSession(const int idx)
  {
   if(!g_current_sessions[idx].active)
      return;

   g_done_sessions[idx] = g_current_sessions[idx];
   g_done_sessions[idx].active = false;
   g_done_sessions[idx].ready = true;

   g_current_sessions[idx].active = false;
   g_current_sessions[idx].ready = false;
  }

void UpdateOneSession(const int idx,
                      const datetime bar_time,
                      const double bar_high,
                      const double bar_low)
  {
   datetime session_start = 0;
   datetime session_end = 0;
   const bool in_session = SessionWindow(bar_time, idx, session_start, session_end);

   if(g_current_sessions[idx].active && bar_time >= g_current_sessions[idx].end_time)
      FinalizeSession(idx);

   if(!in_session)
      return;

   const int key = SessionKey(session_start, idx);
   if(!g_current_sessions[idx].active || g_current_sessions[idx].key != key)
     {
      if(g_current_sessions[idx].active)
         FinalizeSession(idx);

      g_current_sessions[idx].active = true;
      g_current_sessions[idx].ready = false;
      g_current_sessions[idx].key = key;
      g_current_sessions[idx].start_time = session_start;
      g_current_sessions[idx].end_time = session_end;
      g_current_sessions[idx].high = bar_high;
      g_current_sessions[idx].low = bar_low;
      return;
     }

   if(bar_high > g_current_sessions[idx].high)
      g_current_sessions[idx].high = bar_high;
   if(bar_low < g_current_sessions[idx].low)
      g_current_sessions[idx].low = bar_low;
  }

void AdvanceSessionState()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return;

   const double bar_high = iHigh(_Symbol, _Period, 1);
   const double bar_low = iLow(_Symbol, _Period, 1);
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high < bar_low)
      return;

   for(int idx = 0; idx < 3; ++idx)
      UpdateOneSession(idx, bar_time, bar_high, bar_low);
  }

bool ParentContainsChild(const int parent_idx, const int child_idx)
  {
   if(!g_done_sessions[parent_idx].ready || !g_done_sessions[child_idx].ready)
      return false;
   if(g_done_sessions[child_idx].end_time <= g_done_sessions[parent_idx].end_time)
      return false;
   return (g_done_sessions[parent_idx].high >= g_done_sessions[child_idx].high &&
           g_done_sessions[parent_idx].low <= g_done_sessions[child_idx].low);
  }

bool SelectParentRange(SessionRange &parent, string &pair_name)
  {
   int best_child_end = 0;
   int best_pair = -1;

   for(int pair = 0; pair < 3; ++pair)
     {
      const int parent_idx = (pair == 1) ? 1 : 0;
      const int child_idx = (pair == 0) ? 1 : 2;
      if(!ParentContainsChild(parent_idx, child_idx))
         continue;

      const int child_end = (int)g_done_sessions[child_idx].end_time;
      if(child_end > best_child_end)
        {
         best_child_end = child_end;
         best_pair = pair;
        }
     }

   if(best_pair < 0)
      return false;

   const int selected_parent = (best_pair == 1) ? 1 : 0;
   const int selected_child = (best_pair == 0) ? 1 : 2;
   parent = g_done_sessions[selected_parent];
   pair_name = SessionName(selected_parent) + "_TO_" + SessionName(selected_child);
   return true;
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

bool RolloverBlocked(const int hhmm)
  {
   if(strategy_rollover_start_hhmm == strategy_rollover_end_hhmm)
      return false;
   if(strategy_rollover_start_hhmm < strategy_rollover_end_hhmm)
      return (hhmm >= strategy_rollover_start_hhmm && hhmm < strategy_rollover_end_hhmm);
   return (hhmm >= strategy_rollover_start_hhmm || hhmm < strategy_rollover_end_hhmm);
  }

datetime NextSessionEnd(const datetime broker_time)
  {
   datetime best = 0;
   for(int idx = 0; idx < 3; ++idx)
     {
      datetime session_start = 0;
      datetime session_end = 0;
      if(SessionWindow(broker_time, idx, session_start, session_end) && session_end > broker_time)
        {
         if(best == 0 || session_end < best)
            best = session_end;
        }
     }

   if(best > 0)
      return best;

   for(int idx = 0; idx < 3; ++idx)
     {
      const int end_min = MathMax(0, MathMin(24, SessionEndHour(idx))) * 60;
      datetime candidate = DateAtMinutes(broker_time, end_min);
      if(candidate <= broker_time)
         candidate += 86400;
      if(best == 0 || candidate < best)
         best = candidate;
     }

   return best;
  }

double NormalizedPrice(const double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool ProjectedRRPasses(const QM_OrderType side,
                       const double entry,
                       const double sl,
                       const double tp)
  {
   const double risk = MathAbs(entry - sl);
   const double reward = MathAbs(tp - entry);
   if(risk <= 0.0 || reward <= 0.0)
      return false;
   return (reward / risk >= strategy_min_rr);
  }

bool Strategy_NoTradeFilter()
  {
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   if(RolloverBlocked(Hhmm(TimeCurrent())))
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

   AdvanceSessionState();

   if(HasOurOpenPosition())
      return false;

   SessionRange parent;
   string pair_name = "";
   if(!SelectParentRange(parent, pair_name))
      return false;
   if(parent.key == g_last_trade_parent_key)
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(strategy_stop_atr_buffer > 0.0 && atr <= 0.0)
      return false;

   const double buffer = MathMax(0.0, strategy_stop_atr_buffer) * atr;
   const bool bullish_reclaim = (low1 < parent.low && close1 > parent.low);
   const bool bearish_reclaim = (high1 > parent.high && close1 < parent.high);

   if(bullish_reclaim && (!strategy_reclaim_filter || close1 > open1))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = NormalizedPrice(low1 - buffer);
      const double tp = NormalizedPrice(parent.high);
      if(entry > 0.0 && sl > 0.0 && tp > entry && sl < entry &&
         ProjectedRRPasses(QM_BUY, entry, sl, tp))
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "PARENT_SWEEP_LONG_" + pair_name;
         g_last_trade_parent_key = parent.key;
         g_active_exit_time = NextSessionEnd(TimeCurrent());
         return true;
        }
     }

   if(bearish_reclaim && (!strategy_reclaim_filter || close1 < open1))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = NormalizedPrice(high1 + buffer);
      const double tp = NormalizedPrice(parent.low);
      if(entry > 0.0 && sl > entry && tp > 0.0 && tp < entry &&
         ProjectedRRPasses(QM_SELL, entry, sl, tp))
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "PARENT_SWEEP_SHORT_" + pair_name;
         g_last_trade_parent_key = parent.key;
         g_active_exit_time = NextSessionEnd(TimeCurrent());
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, or partial-close management.
  }

bool Strategy_ExitSignal()
  {
   if(g_active_exit_time <= 0)
      return false;
   if(!HasOurOpenPosition())
      return false;
   return (TimeCurrent() >= g_active_exit_time);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10687_tv-parent-sweep\"}");
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
