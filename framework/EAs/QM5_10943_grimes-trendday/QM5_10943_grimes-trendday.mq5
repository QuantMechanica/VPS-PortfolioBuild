#property strict
#property version   "5.0"
#property description "QM5_10943 Grimes Compressed Trend-Day Breakout"
// Strategy Card: QM5_10943 (grimes-trendday), G0 APPROVED 2026-05-22.
// Source: Adam H. Grimes, Finding trend days in index futures, 2015-09-16.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10943;
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
input int    strategy_atr_period_d1              = 20;
input int    strategy_atr_period_m15             = 20;
input double strategy_prior_range_atr_mult       = 0.65;
input double strategy_two_day_range_atr_mult     = 0.75;
input int    strategy_opening_range_bars         = 4;
input int    strategy_session_open_hour_broker   = 16;
input int    strategy_session_open_minute_broker = 30;
input int    strategy_session_close_hour_broker  = 22;
input int    strategy_session_close_minute_broker= 45;
input double strategy_max_open_range_d1_atr_mult = 0.90;
input double strategy_stop_m15_atr_mult          = 0.15;
input double strategy_target_r_mult              = 3.00;
input double strategy_trail_trigger_r            = 1.50;
input int    strategy_trail_lookback_bars        = 3;
input double strategy_spread_stop_fraction       = 0.10;

int      g_session_key             = 0;
bool     g_daily_setup_loaded       = false;
bool     g_daily_setup_valid        = false;
double   g_prior_d1_high            = 0.0;
double   g_prior_d1_low             = 0.0;
double   g_opening_range_high       = 0.0;
double   g_opening_range_low        = 0.0;
bool     g_trade_submitted_today    = false;
bool     g_close_inside_range       = false;
double   g_cached_trail_stop        = 0.0;
ulong    g_active_ticket            = 0;
double   g_active_entry             = 0.0;
double   g_active_initial_r         = 0.0;
bool     g_active_is_long           = false;

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int SessionOpenMinute()
  {
   return MathMax(0, MathMin(23, strategy_session_open_hour_broker)) * 60 +
          MathMax(0, MathMin(59, strategy_session_open_minute_broker));
  }

int SessionCloseMinute()
  {
   return MathMax(0, MathMin(23, strategy_session_close_hour_broker)) * 60 +
          MathMax(0, MathMin(59, strategy_session_close_minute_broker));
  }

double BarRange(const MqlRates &bar)
  {
   return bar.high - bar.low;
  }

bool SelectOurPosition(ulong &ticket,
                       ENUM_POSITION_TYPE &ptype,
                       double &open_price,
                       double &sl)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      return true;
     }
   return false;
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
      return true;
     }
   return false;
  }

void RemoveOurPendingOrders(const string reason)
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
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void ResetPositionTracking()
  {
   g_active_ticket = 0;
   g_active_entry = 0.0;
   g_active_initial_r = 0.0;
   g_active_is_long = false;
   g_cached_trail_stop = 0.0;
   g_close_inside_range = false;
  }

void EnsurePositionTracking(const ulong ticket,
                            const ENUM_POSITION_TYPE ptype,
                            const double open_price,
                            const double sl)
  {
   if(ticket == g_active_ticket)
      return;

   g_active_ticket = ticket;
   g_active_entry = open_price;
   g_active_initial_r = MathAbs(open_price - sl);
   g_active_is_long = (ptype == POSITION_TYPE_BUY);
   g_cached_trail_stop = 0.0;
   g_close_inside_range = false;
   g_trade_submitted_today = true;
  }

bool LoadDailySetup()
  {
   g_daily_setup_loaded = true;
   g_daily_setup_valid = false;
   g_prior_d1_high = 0.0;
   g_prior_d1_low = 0.0;

   MqlRates d1[];
   ArraySetAsSeries(d1, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 3, d1); // perf-allowed: bounded D1 compression window, new-bar gated.
   if(copied < 3)
      return false;
   ArraySetAsSeries(d1, true);

   g_prior_d1_high = d1[0].high;
   g_prior_d1_low = d1[0].low;
   if(g_prior_d1_high <= 0.0 || g_prior_d1_low <= 0.0 || g_prior_d1_high <= g_prior_d1_low)
      return false;

   const double atr_prior = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double atr_day_before = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 2);
   const double prior_range = BarRange(d1[0]);
   const double day_before_range = BarRange(d1[1]);
   if(atr_prior <= 0.0 || atr_day_before <= 0.0 || prior_range <= 0.0 || day_before_range <= 0.0)
      return false;

   const bool compressed_prior = (prior_range <= strategy_prior_range_atr_mult * atr_prior);
   const bool inside_day = (d1[0].high <= d1[1].high && d1[0].low >= d1[1].low);
   const bool two_compressed = (prior_range <= strategy_two_day_range_atr_mult * atr_prior &&
                                day_before_range <= strategy_two_day_range_atr_mult * atr_day_before);

   g_daily_setup_valid = (compressed_prior && (inside_day || two_compressed));
   return g_daily_setup_valid;
  }

bool BuildOpeningRange(const MqlRates &rates[],
                       const int copied,
                       const int session_key)
  {
   g_opening_range_high = 0.0;
   g_opening_range_low = 0.0;

   if(!g_daily_setup_valid || strategy_opening_range_bars < 1)
      return false;

   const int open_minute = SessionOpenMinute();
   const int range_end_minute = open_minute + strategy_opening_range_bars * (PeriodSeconds(PERIOD_M15) / 60);

   int counted = 0;
   double range_high = -DBL_MAX;
   double range_low = DBL_MAX;

   for(int i = copied - 1; i >= 1; --i)
     {
      if(DayKey(rates[i].time) != session_key)
         continue;
      const int minute = MinuteOfDay(rates[i].time);
      if(minute < open_minute || minute >= range_end_minute)
         continue;

      counted++;
      range_high = MathMax(range_high, rates[i].high);
      range_low = MathMin(range_low, rates[i].low);
     }

   if(counted < strategy_opening_range_bars)
      return false;
   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_d1 <= 0.0)
      return false;
   if((range_high - range_low) > strategy_max_open_range_d1_atr_mult * atr_d1)
      return false;

   g_opening_range_high = range_high;
   g_opening_range_low = range_low;
   return true;
  }

void UpdateCachedTrailStop()
  {
   g_cached_trail_stop = 0.0;
   if(g_active_ticket == 0 || strategy_trail_lookback_bars < 1)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, strategy_trail_lookback_bars, rates); // perf-allowed: bounded prior-three-bar trail window, new-bar gated.
   if(copied < strategy_trail_lookback_bars)
      return;
   ArraySetAsSeries(rates, true);

   if(g_active_is_long)
     {
      double lo = DBL_MAX;
      for(int i = 0; i < copied; ++i)
         lo = MathMin(lo, rates[i].low);
      if(lo < DBL_MAX)
         g_cached_trail_stop = NormalizeDouble(lo, _Digits);
     }
   else
     {
      double hi = -DBL_MAX;
      for(int i = 0; i < copied; ++i)
         hi = MathMax(hi, rates[i].high);
      if(hi > 0.0)
         g_cached_trail_stop = NormalizeDouble(hi, _Digits);
     }
  }

// No Trade Filter (time, spread, news). Framework handles news and Friday close;
// this hook blocks invalid parameters/period while entry applies session timing.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M15)
      return true;
   if(strategy_atr_period_d1 <= 0 ||
      strategy_atr_period_m15 <= 0 ||
      strategy_prior_range_atr_mult <= 0.0 ||
      strategy_two_day_range_atr_mult <= 0.0 ||
      strategy_opening_range_bars != 4 ||
      strategy_max_open_range_d1_atr_mult <= 0.0 ||
      strategy_stop_m15_atr_mult <= 0.0 ||
      strategy_target_r_mult <= 0.0 ||
      strategy_trail_trigger_r <= 0.0 ||
      strategy_trail_lookback_bars < 1 ||
      strategy_spread_stop_fraction <= 0.0)
      return true;
   return false;
  }

// Trade Entry. Called once per closed M15 bar by the framework. It advances
// cached setup/opening-range/trailing state and emits at most one entry/session.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   if(SelectOurPosition(ticket, ptype, open_price, sl))
     {
      EnsurePositionTracking(ticket, ptype, open_price, sl);
      UpdateCachedTrailStop();
     }
   else
      ResetPositionTracking();

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, 128, rates); // perf-allowed: one bounded M15 session window, new-bar gated.
   if(copied < strategy_opening_range_bars + 3)
      return false;
   ArraySetAsSeries(rates, true);

   const int session_key = DayKey(rates[1].time);
   if(session_key != g_session_key)
     {
      RemoveOurPendingOrders("new_broker_day");
      g_session_key = session_key;
      g_trade_submitted_today = false;
      g_close_inside_range = false;
      g_daily_setup_loaded = false;
      g_daily_setup_valid = false;
      LoadDailySetup();
     }
   else if(!g_daily_setup_loaded)
      LoadDailySetup();

   if(!BuildOpeningRange(rates, copied, session_key))
      return false;

   const double last_close = rates[1].close;
   if(g_active_ticket != 0)
     {
      g_close_inside_range = (last_close > g_opening_range_low && last_close < g_opening_range_high);
      return false;
     }
   g_close_inside_range = false;

   if(g_trade_submitted_today || HasOurPendingOrder())
      return false;

   const int last_closed_minute = MinuteOfDay(rates[1].time);
   const int open_minute = SessionOpenMinute();
   const int range_end_minute = open_minute + strategy_opening_range_bars * (PeriodSeconds(PERIOD_M15) / 60);
   if(last_closed_minute < range_end_minute || last_closed_minute >= SessionCloseMinute())
      return false;

   const double atr_m15 = QM_ATR(_Symbol, _Period, strategy_atr_period_m15, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr_m15 <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const int seconds_to_close = (SessionCloseMinute() - MinuteOfDay(TimeCurrent())) * 60;
   const int expiry = MathMax(60, seconds_to_close);

   if(last_close > g_opening_range_high && last_close > g_prior_d1_high)
     {
      const double entry_ref = ask;
      const double stop = NormalizeDouble(g_opening_range_low - strategy_stop_m15_atr_mult * atr_m15, _Digits);
      const double risk = entry_ref - stop;
      if(risk <= 0.0 || spread > strategy_spread_stop_fraction * risk)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = stop;
      req.tp = NormalizeDouble(entry_ref + strategy_target_r_mult * risk, _Digits);
      req.reason = "grimes_trendday_long";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = expiry;
      g_trade_submitted_today = true;
      return true;
     }

   if(last_close < g_opening_range_low && last_close < g_prior_d1_low)
     {
      const double entry_ref = bid;
      const double stop = NormalizeDouble(g_opening_range_high + strategy_stop_m15_atr_mult * atr_m15, _Digits);
      const double risk = stop - entry_ref;
      if(risk <= 0.0 || spread > strategy_spread_stop_fraction * risk)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = stop;
      req.tp = NormalizeDouble(entry_ref - strategy_target_r_mult * risk, _Digits);
      req.reason = "grimes_trendday_short";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = expiry;
      g_trade_submitted_today = true;
      return true;
     }

   return false;
  }

// Trade Management. Per tick, O(1): after 1.5R, trail to the cached prior
// three M15 lows/highs. The cache is advanced in Strategy_EntrySignal.
void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   if(!SelectOurPosition(ticket, ptype, open_price, sl))
     {
      ResetPositionTracking();
      return;
     }
   EnsurePositionTracking(ticket, ptype, open_price, sl);
   if(g_active_initial_r <= 0.0 || g_cached_trail_stop <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return;

   const double exit_price = g_active_is_long ? bid : ask;
   const double moved_r = g_active_is_long ? ((exit_price - g_active_entry) / g_active_initial_r)
                                           : ((g_active_entry - exit_price) / g_active_initial_r);
   if(moved_r < strategy_trail_trigger_r)
      return;

   const bool valid = g_active_is_long ? (g_cached_trail_stop < bid)
                                       : (g_cached_trail_stop > ask);
   const bool improves = (sl <= 0.0) ||
                         (g_active_is_long ? (g_cached_trail_stop > sl + point * 0.5)
                                           : (g_cached_trail_stop < sl - point * 0.5));
   if(valid && improves)
      QM_TM_MoveSL(ticket, g_cached_trail_stop, "grimes_trendday_prior3_trail");
  }

// Trade Close. Card exit: close at session close or when a closed M15 bar
// returns inside the first-hour opening range after entry.
bool Strategy_ExitSignal()
  {
   if(MinuteOfDay(TimeCurrent()) >= SessionCloseMinute())
     {
      RemoveOurPendingOrders("session_close");
      ulong ticket;
      ENUM_POSITION_TYPE ptype;
      double open_price, sl;
      return SelectOurPosition(ticket, ptype, open_price, sl);
     }

   if(g_close_inside_range)
     {
      ulong ticket;
      ENUM_POSITION_TYPE ptype;
      double open_price, sl;
      return SelectOurPosition(ticket, ptype, open_price, sl);
     }

   return false;
  }

// News Filter Hook (callable for P8/P9 news-impact phases). This EA has no
// custom event logic beyond the central framework news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10943_grimes-trendday\"}");
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
