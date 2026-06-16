#property strict
#property version   "5.0"
#property description "QM5_10930 Grimes NR7 Opening Range Breakout"
// Strategy Card: QM5_10930 (grimes-nr7-orb), G0 APPROVED 2026-05-22.
// Source: Adam H. Grimes NR7 + S&P intraday opening-range breakout articles.

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10930;
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
input int    strategy_atr_period                = 20;
input int    strategy_nr7_lookback_days         = 7;
input int    strategy_opening_range_bars        = 4;
input double strategy_entry_buffer_atr_mult     = 0.10;
input double strategy_stop_buffer_atr_mult      = 0.20;
input double strategy_max_open_range_atr_mult   = 2.00;
input double strategy_target_r_mult             = 2.00;
input double strategy_breakeven_trigger_r       = 1.00;
input double strategy_trail_trigger_r           = 1.50;
input int    strategy_trail_lookback_bars       = 3;
input double strategy_spread_stop_fraction      = 0.10;
input int    strategy_exit_bars_before_day_end  = 2;
input int    strategy_session_open_hhmm_ny       = 930;  // NY cash-open HHMM anchoring the opening range

int      g_session_key             = 0;
bool     g_daily_setup_loaded       = false;
bool     g_daily_setup_valid        = false;
double   g_prior_d1_high            = 0.0;
double   g_prior_d1_low             = 0.0;
bool     g_trade_submitted_today    = false;
double   g_opening_range_high       = 0.0;
double   g_opening_range_low        = 0.0;
double   g_cached_trail_stop        = 0.0;
ulong    g_active_ticket            = 0;
double   g_active_entry             = 0.0;
double   g_active_initial_r         = 0.0;
bool     g_active_is_long           = false;
bool     g_active_be_done           = false;

// Convert a broker timestamp to a DST-aware New-York MqlDateTime. US index CFDs
// trade ~24h on DWX, so the broker-calendar midnight is the dead overnight window,
// not the cash open. Anchoring the opening range to the NY session is what makes
// the Grimes gap-above-prior-high setup register at all.
void BrokerToNyStruct(const datetime broker_time, MqlDateTime &ny_dt)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_off_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   const datetime ny = utc + (ny_off_hours * 3600);
   ZeroMemory(ny_dt);
   TimeToStruct(ny, ny_dt);
  }

// Session key = NY trading date (YYYYMMDD), so an overnight broker-calendar
// rollover does not split or mis-anchor the opening range.
int DayKey(const datetime t)
  {
   MqlDateTime ny;
   BrokerToNyStruct(t, ny);
   return ny.year * 10000 + ny.mon * 100 + ny.day;
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime ny;
   BrokerToNyStruct(t, ny);
   return ny.hour * 60 + ny.min;
  }

int NyHhmm(const datetime t)
  {
   MqlDateTime ny;
   BrokerToNyStruct(t, ny);
   return ny.hour * 100 + ny.min;
  }

double TrueRange(const MqlRates &rates[], const int idx)
  {
   const double prev_close = rates[idx + 1].close;
   const double hl = rates[idx].high - rates[idx].low;
   const double hc = MathAbs(rates[idx].high - prev_close);
   const double lc = MathAbs(rates[idx].low - prev_close);
   return MathMax(hl, MathMax(hc, lc));
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
   g_active_be_done = false;
   g_cached_trail_stop = 0.0;
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
   g_active_be_done = false;
   g_cached_trail_stop = 0.0;
   g_trade_submitted_today = true;
  }

bool LoadDailySetup()
  {
   g_daily_setup_loaded = true;
   g_daily_setup_valid = false;
   g_prior_d1_high = 0.0;
   g_prior_d1_low = 0.0;

   if(strategy_nr7_lookback_days < 2)
      return false;

   MqlRates d1[];
   ArraySetAsSeries(d1, true);
   const int need = strategy_nr7_lookback_days + 1;
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, need, d1); // perf-allowed: bounded D1 NR7 window, new-bar gated.
   if(copied < need)
      return false;
   ArraySetAsSeries(d1, true);

   g_prior_d1_high = d1[0].high;
   g_prior_d1_low = d1[0].low;
   if(g_prior_d1_high <= 0.0 || g_prior_d1_low <= 0.0 || g_prior_d1_high <= g_prior_d1_low)
      return false;

   const double prior_tr = TrueRange(d1, 0);
   if(prior_tr <= 0.0)
      return false;

   for(int i = 1; i < strategy_nr7_lookback_days; ++i)
     {
      const double tr = TrueRange(d1, i);
      if(tr <= 0.0)
         return false;
      if(tr < prior_tr - 1e-8)
         return false;
     }

   g_daily_setup_valid = true;
   return true;
  }

bool BuildOpeningRange(const MqlRates &rates[],
                       const int copied,
                       const int session_key,
                       bool &long_setup,
                       bool &short_setup)
  {
   long_setup = false;
   short_setup = false;
   g_opening_range_high = 0.0;
   g_opening_range_low = 0.0;

   if(!g_daily_setup_valid || strategy_opening_range_bars < 1)
      return false;

   int counted = 0;
   double first_open = 0.0;
   double first_close = 0.0;
   double range_high = -DBL_MAX;
   double range_low = DBL_MAX;
   bool long_closes_ok = true;
   bool short_closes_ok = true;

   for(int i = copied - 1; i >= 1; --i)
     {
      if(DayKey(rates[i].time) != session_key)
         continue;
      // Anchor the opening range to the NY cash open; ignore the overnight
      // session that precedes it within the same NY trading date.
      if(NyHhmm(rates[i].time) < strategy_session_open_hhmm_ny)
         continue;
      counted++;
      if(counted == 1)
        {
         first_open = rates[i].open;
         first_close = rates[i].close;
        }
      if(counted <= strategy_opening_range_bars)
        {
         range_high = MathMax(range_high, rates[i].high);
         range_low = MathMin(range_low, rates[i].low);
         if(rates[i].close < g_prior_d1_high)
            long_closes_ok = false;
         if(rates[i].close > g_prior_d1_low)
            short_closes_ok = false;
        }
     }

   if(counted < strategy_opening_range_bars)
      return false;
   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   if((range_high - range_low) > strategy_max_open_range_atr_mult * atr)
      return false;

   g_opening_range_high = range_high;
   g_opening_range_low = range_low;

   long_setup = (first_open > g_prior_d1_high || first_close > g_prior_d1_high) && long_closes_ok;
   short_setup = (first_open < g_prior_d1_low || first_close < g_prior_d1_low) && short_closes_ok;
   return (long_setup || short_setup);
  }

void UpdateCachedTrailStop()
  {
   g_cached_trail_stop = 0.0;
   if(g_active_ticket == 0 || strategy_trail_lookback_bars < 1)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, strategy_trail_lookback_bars, rates); // perf-allowed: bounded 3-bar trail window, new-bar gated.
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
// setup-specific time and spread gates require the computed opening-range stop.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M15)
      return true;
   if(strategy_atr_period <= 0 ||
      strategy_nr7_lookback_days < 2 ||
      strategy_opening_range_bars < 1 ||
      strategy_entry_buffer_atr_mult < 0.0 ||
      strategy_stop_buffer_atr_mult < 0.0 ||
      strategy_max_open_range_atr_mult <= 0.0 ||
      strategy_target_r_mult <= 0.0 ||
      strategy_breakeven_trigger_r <= 0.0 ||
      strategy_trail_trigger_r < strategy_breakeven_trigger_r ||
      strategy_trail_lookback_bars < 1 ||
      strategy_spread_stop_fraction <= 0.0 ||
      strategy_exit_bars_before_day_end < 1 ||
      strategy_session_open_hhmm_ny < 0 ||
      strategy_session_open_hhmm_ny > 2359)
      return true;
   return false;
  }

// Trade Entry. Called once per closed M15 bar by the framework. It advances
// cached day/opening-range/trailing state and emits at most one order per day.
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
      return false;
     }
   ResetPositionTracking();

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, 128, rates); // perf-allowed: one current-day M15 window, new-bar gated.
   if(copied < strategy_opening_range_bars + 2)
      return false;
   ArraySetAsSeries(rates, true);

   const int session_key = DayKey(rates[1].time);
   if(session_key != g_session_key)
     {
      RemoveOurPendingOrders("new_broker_day");
      g_session_key = session_key;
      g_trade_submitted_today = false;
      g_daily_setup_loaded = false;
      g_daily_setup_valid = false;
      LoadDailySetup();
     }
   else if(!g_daily_setup_loaded)
      LoadDailySetup();

   if(g_trade_submitted_today || HasOurPendingOrder())
      return false;

   bool long_setup = false;
   bool short_setup = false;
   if(!BuildOpeningRange(rates, copied, session_key, long_setup, short_setup))
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const int seconds_to_day_end = (24 * 60 - MinuteOfDay(TimeCurrent())) * 60;
   const int expiry = MathMax(60, seconds_to_day_end - strategy_exit_bars_before_day_end * PeriodSeconds(PERIOD_M15));

   if(long_setup)
     {
      const double trigger = NormalizeDouble(g_opening_range_high + strategy_entry_buffer_atr_mult * atr, _Digits);
      const double stop = NormalizeDouble(g_opening_range_low - strategy_stop_buffer_atr_mult * atr, _Digits);
      const double entry_ref = (ask >= trigger) ? ask : trigger;
      const double risk = entry_ref - stop;
      if(risk <= 0.0 || spread > strategy_spread_stop_fraction * risk)
         return false;

      req.type = (ask >= trigger) ? QM_BUY : QM_BUY_STOP;
      req.price = (req.type == QM_BUY) ? 0.0 : trigger;
      req.sl = stop;
      req.tp = NormalizeDouble(entry_ref + strategy_target_r_mult * risk, _Digits);
      req.reason = "grimes_nr7_orb_long";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = expiry;
      g_trade_submitted_today = true;
      return true;
     }

   if(short_setup)
     {
      const double trigger = NormalizeDouble(g_opening_range_low - strategy_entry_buffer_atr_mult * atr, _Digits);
      const double stop = NormalizeDouble(g_opening_range_high + strategy_stop_buffer_atr_mult * atr, _Digits);
      const double entry_ref = (bid <= trigger) ? bid : trigger;
      const double risk = stop - entry_ref;
      if(risk <= 0.0 || spread > strategy_spread_stop_fraction * risk)
         return false;

      req.type = (bid <= trigger) ? QM_SELL : QM_SELL_STOP;
      req.price = (req.type == QM_SELL) ? 0.0 : trigger;
      req.sl = stop;
      req.tp = NormalizeDouble(entry_ref - strategy_target_r_mult * risk, _Digits);
      req.reason = "grimes_nr7_orb_short";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = expiry;
      g_trade_submitted_today = true;
      return true;
     }

   return false;
  }

// Trade Management. Per tick, O(1): move to breakeven at 1R, then use the
// cached prior-3-bar stop after 1.5R. Cache is advanced in Strategy_EntrySignal.
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
   if(g_active_initial_r <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return;

   const double exit_price = g_active_is_long ? bid : ask;
   const double moved_r = g_active_is_long ? ((exit_price - g_active_entry) / g_active_initial_r)
                                           : ((g_active_entry - exit_price) / g_active_initial_r);

   if(!g_active_be_done && moved_r >= strategy_breakeven_trigger_r)
     {
      const double be = NormalizeDouble(g_active_entry, _Digits);
      const bool improves = (sl <= 0.0) ||
                            (g_active_is_long ? (be > sl + point * 0.5)
                                              : (be < sl - point * 0.5));
      if(improves && QM_TM_MoveSL(ticket, be, "nr7_orb_breakeven"))
        {
         g_active_be_done = true;
         sl = be;
        }
     }

   if(moved_r < strategy_trail_trigger_r || g_cached_trail_stop <= 0.0)
      return;

   const bool valid = g_active_is_long ? (g_cached_trail_stop < bid)
                                       : (g_cached_trail_stop > ask);
   const bool improves = (sl <= 0.0) ||
                         (g_active_is_long ? (g_cached_trail_stop > sl + point * 0.5)
                                           : (g_cached_trail_stop < sl - point * 0.5));
   if(valid && improves)
      QM_TM_MoveSL(ticket, g_cached_trail_stop, "nr7_orb_prior3_trail");
  }

// Trade Close. Card exit: close any open trade two M15 bars before broker day end.
bool Strategy_ExitSignal()
  {
   const int cutoff_minute = 24 * 60 - strategy_exit_bars_before_day_end * (PeriodSeconds(PERIOD_M15) / 60);
   if(MinuteOfDay(TimeCurrent()) < cutoff_minute)
      return false;

   RemoveOurPendingOrders("broker_day_exit_cutoff");
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price, sl;
   return SelectOurPosition(ticket, ptype, open_price, sl);
  }

// News Filter Hook (callable for P8/P9 news-impact phases). This EA has no
// custom event logic beyond the central framework news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10930_grimes-nr7-orb\"}");
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
