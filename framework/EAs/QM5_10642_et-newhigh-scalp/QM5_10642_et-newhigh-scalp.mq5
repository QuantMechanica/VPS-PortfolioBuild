#property strict
#property version   "5.0"
#property description "QM5_10642 Elite Trader opening new-high/new-low scalp"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10642;
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
input int    strategy_breakout_lookback_bars = 20;
input int    strategy_window_start_minutes   = 15;
input int    strategy_window_end_minutes     = 60;
input int    strategy_atr_period             = 14;
input double strategy_atr_trail_mult         = 0.35;
input int    strategy_min_trail_ticks        = 5;
input double strategy_max_spread_trail_frac  = 0.25;
input double strategy_first_range_min_mult   = 0.50;
input int    strategy_direction_mode         = 0;    // -1 short only, 0 symmetric, 1 long only.
input int    strategy_us_open_hour_broker    = 16;
input int    strategy_us_open_minute_broker  = 30;
input int    strategy_eu_open_hour_broker    = 9;
input int    strategy_eu_open_minute_broker  = 0;

int      g_cached_day_key = 0;
bool     g_first_range_ready = false;
bool     g_first_range_allows = true;
double   g_today_opening_range = 0.0;
double   g_median_opening_range = 0.0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_IsEuIndex()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "GER40") >= 0);
  }

datetime Strategy_SessionOpenForDate(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(Strategy_IsEuIndex())
     {
      dt.hour = strategy_eu_open_hour_broker;
      dt.min = strategy_eu_open_minute_broker;
     }
   else
     {
      dt.hour = strategy_us_open_hour_broker;
      dt.min = strategy_us_open_minute_broker;
     }
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_InEntryWindow(const datetime broker_now)
  {
   const datetime session_open = Strategy_SessionOpenForDate(broker_now);
   const int elapsed = (int)((broker_now - session_open) / 60);
   return (elapsed >= strategy_window_start_minutes && elapsed < strategy_window_end_minutes);
  }

double Strategy_TrailDistance()
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double min_dist = MathMax(1, strategy_min_trail_ticks) * tick_size;
   const double atr = QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period, 1);
   const double atr_dist = atr * strategy_atr_trail_mult;
   return MathMax(min_dist, atr_dist);
  }

double Strategy_OpeningRangeForSession(const datetime session_open)
  {
   const datetime end_time = session_open + 14 * 60;
   const int end_shift = iBarShift(_Symbol, PERIOD_M1, end_time, false);
   if(end_shift < 0)
      return 0.0;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int i = end_shift; i < end_shift + 15; ++i)
     {
      const double h = iHigh(_Symbol, PERIOD_M1, i); // perf-allowed: bounded 15-bar opening-range scan, cached by day.
      const double l = iLow(_Symbol, PERIOD_M1, i); // perf-allowed: bounded 15-bar opening-range scan, cached by day.
      if(h <= 0.0 || l <= 0.0)
         return 0.0;
      hi = MathMax(hi, h);
      lo = MathMin(lo, l);
     }
   if(hi <= lo || hi == -DBL_MAX || lo == DBL_MAX)
      return 0.0;
   return hi - lo;
  }

double Strategy_MedianPriorOpeningRange(const datetime broker_now)
  {
   double ranges[];
   ArrayResize(ranges, 0);

   const datetime today_start = Strategy_DayStart(broker_now);
   for(int d = 1; d <= 35 && ArraySize(ranges) < 20; ++d)
     {
      const datetime candidate = today_start - d * 86400;
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.day_of_week == 0 || dt.day_of_week == 6)
         continue;

      const double range = Strategy_OpeningRangeForSession(Strategy_SessionOpenForDate(candidate));
      if(range <= 0.0)
         continue;

      const int n = ArraySize(ranges);
      ArrayResize(ranges, n + 1);
      ranges[n] = range;
     }

   const int count = ArraySize(ranges);
   if(count < 5)
      return 0.0;

   ArraySort(ranges);
   if((count % 2) == 1)
      return ranges[count / 2];
   return 0.5 * (ranges[count / 2 - 1] + ranges[count / 2]);
  }

void Strategy_RefreshFirstRangeCache(const datetime broker_now)
  {
   const int day_key = Strategy_DayKey(broker_now);
   if(day_key == g_cached_day_key)
      return;

   g_cached_day_key = day_key;
   g_first_range_ready = false;
   g_first_range_allows = true;
   g_today_opening_range = 0.0;
   g_median_opening_range = 0.0;
  }

void Strategy_EnsureFirstRangeFilter(const datetime broker_now)
  {
   Strategy_RefreshFirstRangeCache(broker_now);
   if(g_first_range_ready)
      return;

   const datetime session_open = Strategy_SessionOpenForDate(broker_now);
   if(broker_now < session_open + strategy_window_start_minutes * 60)
      return;

   g_today_opening_range = Strategy_OpeningRangeForSession(session_open);
   g_median_opening_range = Strategy_MedianPriorOpeningRange(broker_now);
   g_first_range_ready = true;

   if(strategy_first_range_min_mult > 0.0 && g_today_opening_range > 0.0 && g_median_opening_range > 0.0)
      g_first_range_allows = (g_today_opening_range >= strategy_first_range_min_mult * g_median_opening_range);
   else
      g_first_range_allows = true;
  }

bool Strategy_HasPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_HasOpenedTradeToday(const datetime broker_now)
  {
   const int magic = QM_FrameworkMagic();
   const datetime day_start = Strategy_DayStart(broker_now);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((datetime)PositionGetInteger(POSITION_TIME) >= day_start)
         return true;
     }

   if(!HistorySelect(day_start, broker_now))
      return false;

   const int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; --i)
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

bool Strategy_BreakoutLevels(double &prior_high, double &prior_low)
  {
   prior_high = -DBL_MAX;
   prior_low = DBL_MAX;
   if(strategy_breakout_lookback_bars < 1)
      return false;

   for(int i = 1; i <= strategy_breakout_lookback_bars; ++i)
     {
      const double h = iHigh(_Symbol, PERIOD_M1, i); // perf-allowed: bounded 20-bar breakout scan inside QM_IsNewBar-gated hook.
      const double l = iLow(_Symbol, PERIOD_M1, i); // perf-allowed: bounded 20-bar breakout scan inside QM_IsNewBar-gated hook.
      if(h <= 0.0 || l <= 0.0)
         return false;
      prior_high = MathMax(prior_high, h);
      prior_low = MathMin(prior_low, l);
     }
   return (prior_high > 0.0 && prior_low > 0.0 && prior_high > prior_low);
  }

bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   Strategy_EnsureFirstRangeFilter(broker_now);

   if(!Strategy_InEntryWindow(broker_now) && !Strategy_HasPosition())
      return true;

   if(!g_first_range_allows && !Strategy_HasPosition())
      return true;

   const double trail_dist = Strategy_TrailDistance();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(trail_dist <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return true;

   const double spread = ask - bid;
   if(spread > strategy_max_spread_trail_frac * trail_dist && !Strategy_HasPosition())
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

   const datetime broker_now = TimeCurrent();
   Strategy_EnsureFirstRangeFilter(broker_now);

   if(!Strategy_InEntryWindow(broker_now))
      return false;
   if(!g_first_range_allows)
      return false;
   if(Strategy_HasOpenedTradeToday(broker_now))
      return false;

   const double trail_dist = Strategy_TrailDistance();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(trail_dist <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_max_spread_trail_frac * trail_dist)
      return false;

   double prior_high = 0.0;
   double prior_low = 0.0;
   if(!Strategy_BreakoutLevels(prior_high, prior_low))
      return false;

   if(strategy_direction_mode >= 0 && ask > prior_high)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask - trail_dist;
      req.tp = 0.0;
      req.reason = "ET_NEWHIGH_LONG";
      return true;
     }

   if(strategy_direction_mode <= 0 && bid < prior_low)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid + trail_dist;
      req.tp = 0.0;
      req.reason = "ET_NEWLOW_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double trail_dist = Strategy_TrailDistance();
   if(trail_dist <= 0.0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double target_sl = NormalizeDouble(is_buy ? market - trail_dist : market + trail_dist, _Digits);
      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5)
                                    : (target_sl < current_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "et_newhigh_scalp_immediate_trail");
     }
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   const datetime session_open = Strategy_SessionOpenForDate(broker_now);
   return (broker_now >= session_open + strategy_window_end_minutes * 60);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10642\",\"ea\":\"QM5_10642_et-newhigh-scalp\"}");
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
