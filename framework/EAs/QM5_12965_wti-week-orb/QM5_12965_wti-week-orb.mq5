#property strict
#property version   "5.1"
#property description "QM5_12965 WTI Weekly Opening Range Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12965 - WTI Weekly Opening Range Breakout
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - first completed D1 bar(s) of each broker week define the opening range
//   - later completed D1 closes can trigger one breakout entry per week
//   - exits on failed breakout, SMA failure, new-week boundary, or max hold
// Runtime uses MT5 OHLC/broker calendar only; no futures curve/API/CSV/feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12965;
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
input int    strategy_opening_days        = 1;
input int    strategy_signal_min_dow      = 2;
input int    strategy_signal_max_dow      = 4;
input int    strategy_atr_period          = 20;
input int    strategy_trend_period        = 60;
input double strategy_min_open_range_atr  = 0.45;
input double strategy_max_open_range_atr  = 2.75;
input double strategy_entry_buffer_atr    = 0.08;
input double strategy_min_close_location  = 0.60;
input double strategy_atr_sl_mult         = 2.40;
input double strategy_atr_tp_mult         = 3.50;
input int    strategy_max_hold_days       = 4;
input int    strategy_max_spread_points   = 1000;

int g_last_entry_week_key = 0;

// File-scope cache: refreshed exactly once per closed D1 bar by
// Strategy_ManageOpenPosition() -> Strategy_RefreshWeekState(). Strategy_EntrySignal()
// reads the same cache instead of re-running CopyRates/QM_ATR/QM_SMA a second
// time on the same bar (PERFORMANCE DISCIPLINE: cache per-bar state in file scope).
bool     g_week_ready           = false;
double   g_week_close_last      = 0.0;
double   g_week_opening_high    = 0.0;
double   g_week_opening_low     = 0.0;
double   g_week_atr_last        = 0.0;
double   g_week_sma_last        = 0.0;
double   g_week_open_range      = 0.0;
double   g_week_close_location  = 0.0;
int      g_week_signal_week_key = 0;
int      g_week_signal_dow      = -1;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

// Monday-anchored broker-week helpers (bespoke structural logic). The card's
// Crabel-style opening range must anchor to the weekend-gap reopen (normally
// Monday); QM_CalendarPeriodKey(PERIOD_W1)'s day_of_year/7 rolling bucket does
// not guarantee that anchor (its boundary drifts across weekdays year to
// year depending on where Jan-1 falls), which would misalign the opening box
// with the actual weekend gap the strategy's edge depends on. All inputs
// below are MqlRates.time values from a single CopyRates call (never a
// direct iTime() read) so no per-EA iTime-fed calendar key is introduced.
datetime Strategy_DateMidnight(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime Strategy_WeekStart(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int dow = dt.day_of_week;
   const int offset_days = (dow == 0) ? 6 : (dow - 1);
   return Strategy_DateMidnight(t) - offset_days * 86400;
  }

int Strategy_WeekKey(const datetime t)
  {
   const datetime start = Strategy_WeekStart(t);
   if(start <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(start, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DayOfWeek(const datetime t)
  {
   if(t <= 0)
      return -1;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

bool Strategy_SameWeek(const datetime t, const datetime week_start)
  {
   if(t <= 0 || week_start <= 0)
      return false;
   const datetime day = Strategy_DateMidnight(t);
   return (day >= week_start && day < week_start + 7 * 86400);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

// Single CopyRates + QM_ATR/QM_SMA pass per closed bar. Populates the week
// state via out-params; Strategy_RefreshWeekState() below stashes the result
// into the file-scope cache consumed by both management and entry.
bool Strategy_LoadWeekState(double &close_last,
                            double &opening_high,
                            double &opening_low,
                            double &atr_last,
                            double &sma_last,
                            double &open_range,
                            double &close_location,
                            int &signal_week_key,
                            int &signal_dow)
  {
   close_last = 0.0;
   opening_high = 0.0;
   opening_low = 0.0;
   atr_last = 0.0;
   sma_last = 0.0;
   open_range = 0.0;
   close_location = 0.0;
   signal_week_key = 0;
   signal_dow = -1;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 30, rates); // perf-allowed: bespoke weekly-range structural read, once per closed D1 bar (see QM_IsNewBar gate in OnTick).
   if(copied < strategy_opening_days + 1)
      return false;

   const datetime signal_time = rates[0].time;
   const datetime week_start = Strategy_WeekStart(signal_time);
   signal_week_key = Strategy_WeekKey(signal_time);
   signal_dow = Strategy_DayOfWeek(signal_time);
   if(week_start <= 0 || signal_week_key <= 0)
      return false;

   int week_bar_count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(!Strategy_SameWeek(rates[i].time, week_start))
         break;
      ++week_bar_count;
     }

   if(week_bar_count <= strategy_opening_days)
      return false;

   int used = 0;
   for(int idx = week_bar_count - 1; idx >= 0 && used < strategy_opening_days; --idx)
     {
      if(used == 0)
        {
         opening_high = rates[idx].high;
         opening_low = rates[idx].low;
        }
      else
        {
         if(rates[idx].high > opening_high)
            opening_high = rates[idx].high;
         if(rates[idx].low < opening_low)
            opening_low = rates[idx].low;
        }
      ++used;
     }

   if(used != strategy_opening_days || opening_high <= opening_low)
      return false;

   close_last = rates[0].close;
   const double high_last = rates[0].high;
   const double low_last = rates[0].low;
   const double range_last = high_last - low_last;
   open_range = opening_high - opening_low;
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(close_last <= 0.0 || high_last <= low_last || open_range <= 0.0)
      return false;
   if(atr_last <= 0.0 || sma_last <= 0.0 || range_last <= 0.0)
      return false;

   close_location = (close_last - low_last) / range_last;
   return MathIsValidNumber(close_location);
  }

void Strategy_RefreshWeekState()
  {
   g_week_ready = Strategy_LoadWeekState(g_week_close_last,
                                        g_week_opening_high,
                                        g_week_opening_low,
                                        g_week_atr_last,
                                        g_week_sma_last,
                                        g_week_open_range,
                                        g_week_close_location,
                                        g_week_signal_week_key,
                                        g_week_signal_dow);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = false;

      if(g_week_ready && g_week_signal_week_key > 0 && opened > 0)
        {
         const int open_week_key = Strategy_WeekKey(opened);
         if(open_week_key > 0 && g_week_signal_week_key != open_week_key)
            should_close = true;
        }
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(g_week_ready && pos_type == POSITION_TYPE_BUY)
        {
         if(g_week_close_last < g_week_opening_high || g_week_close_last < g_week_sma_last)
            should_close = true;
        }
      else if(g_week_ready && pos_type == POSITION_TYPE_SELL)
        {
         if(g_week_close_last > g_week_opening_low || g_week_close_last > g_week_sma_last)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_opening_days < 1 || strategy_opening_days > 3)
      return true;
   if(strategy_signal_min_dow < 1 || strategy_signal_max_dow > 5 || strategy_signal_min_dow > strategy_signal_max_dow)
      return true;
   if(strategy_atr_period <= 0 || strategy_trend_period <= 1)
      return true;
   if(strategy_min_open_range_atr <= 0.0 || strategy_max_open_range_atr <= strategy_min_open_range_atr)
      return true;
   if(strategy_entry_buffer_atr < 0.0)
      return true;
   if(strategy_min_close_location <= 0.5 || strategy_min_close_location > 1.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12965_WTI_WEEK_ORB";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   if(!g_week_ready)
      return false;

   if(g_week_signal_week_key <= 0 || g_week_signal_week_key == g_last_entry_week_key)
      return false;
   if(g_week_signal_dow < strategy_signal_min_dow || g_week_signal_dow > strategy_signal_max_dow)
      return false;
   if(g_week_open_range < strategy_min_open_range_atr * g_week_atr_last)
      return false;
   if(g_week_open_range > strategy_max_open_range_atr * g_week_atr_last)
      return false;

   const double buffer = strategy_entry_buffer_atr * g_week_atr_last;
   int direction = 0;
   if(g_week_close_last > g_week_opening_high + buffer &&
      g_week_close_last > g_week_sma_last &&
      g_week_close_location >= strategy_min_close_location)
      direction = 1;
   else if(g_week_close_last < g_week_opening_low - buffer &&
           g_week_close_last < g_week_sma_last &&
           g_week_close_location <= (1.0 - strategy_min_close_location))
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_tp_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (direction > 0) ? "WTI_WEEK_OPEN_RANGE_BREAKOUT_LONG" : "WTI_WEEK_OPEN_RANGE_BREAKOUT_SHORT";
   g_last_entry_week_key = g_week_signal_week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_RefreshWeekState();
   Strategy_CloseOpenPositionsIfNeeded();
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12965\",\"ea\":\"wti-week-orb\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Single QM_IsNewBar() consume for this tick; latched and reused below so
   // management/exit can be gated to run once per closed bar (this EA's
   // management does a CopyRates + ATR/SMA pass, not O(1) per-tick work)
   // without ever calling QM_IsNewBar() a second time this tick.
   const bool is_new_bar = QM_IsNewBar();

   if(is_new_bar)
      Strategy_ManageOpenPosition();

   if(is_new_bar && Strategy_ExitSignal())
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

   // News blackout gates NEW entries only (below); management/exits above
   // already ran regardless of news state, per the 2026-07-02 OnTick-ordering
   // audit finding: risk management must not be silenced during news
   // windows (this EA's positions carry real broker-side ATR SL/TP either
   // way, but the ordering rule is binding for all EAs, not just baskets).
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
