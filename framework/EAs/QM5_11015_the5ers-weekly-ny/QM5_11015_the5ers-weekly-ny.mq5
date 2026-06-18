#property strict
#property version   "5.0"
#property description "QM5_11015 the5ers-weekly-ny Tue/Wed NY weekly continuation breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11015;
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
input int    strategy_ny_start_hour     = 16;
input int    strategy_ny_end_hour       = 22;
input int    strategy_sma_period        = 20;
input int    strategy_atr_period        = 14;
input double strategy_session_move_atr  = 0.5;
input double strategy_breakout_buf_atr  = 0.0;
input double strategy_sl_atr_mult       = 1.5;
input double strategy_sl_atr_floor      = 1.0;
input double strategy_tp_rr             = 2.0;
input int    strategy_time_stop_bars    = 36;
input int    strategy_friday_exit_hour  = 18;

datetime g_week_anchor       = 0;
bool     g_week_entry_taken  = false;
double   g_active_range_high = 0.0;
double   g_active_range_low  = 0.0;
datetime g_entry_bar_time    = 0;

datetime WeekAnchorBroker(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int days_since_monday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   const datetime day_midnight = broker_time - (datetime)(dt.hour * 3600 + dt.min * 60 + dt.sec);
   return day_midnight - (datetime)(days_since_monday * 86400);
  }

datetime DayMidnightBroker(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return broker_time - (datetime)(dt.hour * 3600 + dt.min * 60 + dt.sec);
  }

string StateKey(const string suffix)
  {
   return StringFormat("QM511015_%d_%s", QM_FrameworkMagic(), suffix);
  }

void SaveEntryState()
  {
   GlobalVariableSet(StateKey("week"), (double)g_week_anchor);
   GlobalVariableSet(StateKey("rh"), g_active_range_high);
   GlobalVariableSet(StateKey("rl"), g_active_range_low);
   GlobalVariableSet(StateKey("et"), (double)g_entry_bar_time);
  }

void LoadEntryState()
  {
   if(GlobalVariableCheck(StateKey("rh")))
      g_active_range_high = GlobalVariableGet(StateKey("rh"));
   if(GlobalVariableCheck(StateKey("rl")))
      g_active_range_low = GlobalVariableGet(StateKey("rl"));
   if(GlobalVariableCheck(StateKey("et")))
      g_entry_bar_time = (datetime)GlobalVariableGet(StateKey("et"));
  }

void RefreshWeekState(const datetime broker_time)
  {
   const datetime anchor = WeekAnchorBroker(broker_time);
   if(anchor == g_week_anchor)
      return;

   g_week_anchor = anchor;
   g_week_entry_taken = false;
   g_active_range_high = 0.0;
   g_active_range_low = 0.0;
   g_entry_bar_time = 0;
  }

bool IsEntryDayAndSession(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(dt.day_of_week != 2 && dt.day_of_week != 3)
      return false;

   if(strategy_ny_start_hour <= strategy_ny_end_hour)
      return (dt.hour >= strategy_ny_start_hour && dt.hour < strategy_ny_end_hour);
   return (dt.hour >= strategy_ny_start_hour || dt.hour < strategy_ny_end_hour);
  }

bool HasFamilyOpenPosition()
  {
   const int family_base = qm_ea_id * 10000;
   const int family_end = family_base + 4;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(magic >= family_base && magic <= family_end && PositionGetString(POSITION_SYMBOL) != _Symbol)
         return true;
     }
   return false;
  }

bool HasTradeThisWeek()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return true;

   if(g_week_anchor <= 0)
      return false;

   if(!HistorySelect(g_week_anchor, TimeCurrent()))
      return false;

   const int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return true;
     }
   return false;
  }

bool LoadRates(MqlRates &rates[], const int count)
  {
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, count, rates); // perf-allowed: bounded OHLC snapshot, consumed on new-bar entry path or O(1) exit path
   return (copied >= count);
  }

bool LoadD1Closed(MqlRates &day_rate)
  {
   MqlRates daily[];
   ArraySetAsSeries(daily, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, daily) != 1) // perf-allowed: one closed D1 bar for top-down bias
      return false;
   day_rate = daily[0];
   return true;
  }

bool ComputeSessionLevels(MqlRates &rates[],
                          const int copied,
                          const datetime bar_time,
                          double &weekly_open,
                          double &day_open,
                          double &ny_open,
                          double &range_high,
                          double &range_low)
  {
   weekly_open = 0.0;
   day_open = 0.0;
   ny_open = 0.0;
   range_high = -DBL_MAX;
   range_low = DBL_MAX;

   const datetime day_midnight = DayMidnightBroker(bar_time);
   const datetime ny_open_time = day_midnight + (datetime)(strategy_ny_start_hour * 3600);
   bool have_range = false;

   for(int i = copied - 1; i >= 1; --i)
     {
      const datetime ts = rates[i].time;
      if(ts < g_week_anchor)
         continue;
      if(weekly_open <= 0.0)
         weekly_open = rates[i].open;
      if(ts >= day_midnight && day_open <= 0.0)
         day_open = rates[i].open;
      if(ts >= ny_open_time && ny_open <= 0.0)
         ny_open = rates[i].open;
      if(ts >= g_week_anchor && ts < ny_open_time)
        {
         if(rates[i].high > range_high)
            range_high = rates[i].high;
         if(rates[i].low < range_low)
            range_low = rates[i].low;
         have_range = true;
        }
     }

   return (weekly_open > 0.0 &&
           day_open > 0.0 &&
           ny_open > 0.0 &&
           have_range &&
           range_high > 0.0 &&
           range_low > 0.0 &&
           range_high > range_low);
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid)
     {
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value > 0.0 && (ask - bid) > strategy_sl_atr_mult * atr_value)
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

   MqlRates rates[];
   if(!LoadRates(rates, 240))
      return false;

   const datetime bar_time = rates[0].time;
   RefreshWeekState(bar_time);

   if(!IsEntryDayAndSession(bar_time))
      return false;
   if(g_week_entry_taken || HasTradeThisWeek())
      return false;
   if(HasFamilyOpenPosition())
      return false;

   double weekly_open = 0.0;
   double day_open = 0.0;
   double ny_open = 0.0;
   double range_high = 0.0;
   double range_low = 0.0;
   const int copied = ArraySize(rates);
   if(!ComputeSessionLevels(rates, copied, bar_time, weekly_open, day_open, ny_open, range_high, range_low))
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   MqlRates d1;
   if(!LoadD1Closed(d1))
      return false;

   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   if(d1.close <= 0.0 || d1_sma <= 0.0)
      return false;

   const double brk_close = rates[1].close;
   const double buffer = strategy_breakout_buf_atr * atr_value;
   const double session_move = ny_open - day_open;

   const bool bias_bull = (d1.close > d1_sma) && (brk_close > weekly_open);
   if(bias_bull &&
      session_move >= strategy_session_move_atr * atr_value &&
      brk_close > range_high + buffer)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double struct_dist = entry - range_low;
      const double atr_cap = strategy_sl_atr_mult * atr_value;
      const double atr_floor = strategy_sl_atr_floor * atr_value;
      double sl_dist = MathMin(struct_dist, atr_cap);
      if(sl_dist < atr_floor)
         sl_dist = atr_floor;

      const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_BUY, entry, sl_dist);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "the5ers_weekly_ny_long";
      g_week_entry_taken = true;
      g_active_range_high = range_high;
      g_active_range_low = 0.0;
      g_entry_bar_time = bar_time;
      SaveEntryState();
      return true;
     }

   const bool bias_bear = (d1.close < d1_sma) && (brk_close < weekly_open);
   if(bias_bear &&
      session_move <= -strategy_session_move_atr * atr_value &&
      brk_close < range_low - buffer)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double struct_dist = range_high - entry;
      const double atr_cap = strategy_sl_atr_mult * atr_value;
      const double atr_floor = strategy_sl_atr_floor * atr_value;
      double sl_dist = MathMin(struct_dist, atr_cap);
      if(sl_dist < atr_floor)
         sl_dist = atr_floor;

      const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_SELL, entry, sl_dist);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "the5ers_weekly_ny_short";
      g_week_entry_taken = true;
      g_active_range_high = 0.0;
      g_active_range_low = range_low;
      g_entry_bar_time = bar_time;
      SaveEntryState();
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   LoadEntryState();

   MqlRates rates[];
   if(!LoadRates(rates, 2))
      return false;

   MqlDateTime dt;
   TimeToStruct(rates[0].time, dt);
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_exit_hour)
      return true;

   if(g_entry_bar_time > 0 && strategy_time_stop_bars > 0)
     {
      const int seconds_per_bar = PeriodSeconds(_Period);
      if(seconds_per_bar > 0)
        {
         const int held_bars = (int)((rates[0].time - g_entry_bar_time) / seconds_per_bar);
         if(held_bars >= strategy_time_stop_bars)
            return true;
        }
     }

   const double closed_h1 = rates[1].close;
   if(g_active_range_high > 0.0 && closed_h1 < g_active_range_high)
      return true;
   if(g_active_range_low > 0.0 && closed_h1 > g_active_range_low)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return QM_NewsInWindow(utc_time, _Symbol, 120, 120, "HIGH");
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
