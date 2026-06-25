#property strict
#property version   "5.0"
#property description "QM5_12561 — Session-Open / Previous-Day-High Breakout (Intraday Index Trend)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12561  session-open-pdh-breakout
// Intraday M15 breakout: enter on close above max(OR_high, PDH) or below
// min(OR_low, PDL) within a 2-hour entry window after the opening range forms.
// ATR-sized stop, 2R target, BE at 1R, time stop after 8 bars, hard EOD exit.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 12561;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy — Signal"
input int    strategy_atr_period_m15       = 14;    // ATR lookback on M15
input int    strategy_atr_period_d1        = 14;    // ATR lookback on D1 for gap filter
input double strategy_sl_atr_buffer        = 0.3;   // SL beyond OR boundary: buffer_mult × ATR
input double strategy_sl_atr_cap           = 1.8;   // reject trade if stop distance > cap × ATR
input double strategy_tp_rr                = 2.0;   // take-profit R-multiple
input double strategy_be_r                 = 1.0;   // break-even trigger in R units
input int    strategy_time_stop_bars       = 8;     // M15 bars before time-stop check fires
input double strategy_time_stop_min_r      = 0.5;   // price must have reached this R to avoid time stop
input double strategy_entry_bar_min_range  = 0.5;   // breakout bar range >= this × ATR(M15)
input double strategy_session_range_factor = 0.8;   // current session range >= this × prior-day range
input double strategy_gap_atr_d1_mult      = 1.5;   // skip day if session gap > this × ATR(D1)

input group "Strategy — Session (override in setfile per symbol)"
// US indices (NDX.DWX, WS30.DWX): session_open_hour=16, session_open_minute=30
//   US equity open 09:30 ET = 16:30 broker (DXZ GMT+2/+3 and ET DST cancel out)
//   EOD exit 15 min before 23:00 broker (US close 16:00 ET = 23:00 broker)
// GDAXI.DWX: session_open_hour=10, session_open_minute=0,
//   eod_exit_hour=18, eod_exit_minute=15
//   Xetra open 09:00 CET = ~10:00 broker (most of year; see SPEC.md for DST note)
input int    strategy_session_open_hour    = 16;
input int    strategy_session_open_minute  = 30;
input int    strategy_eod_exit_hour        = 22;   // exit 15 min before US close (23:00 broker)
input int    strategy_eod_exit_minute      = 45;

// =============================================================================
// Intraday cached state — all updated per closed M15 bar (INTRADAY DISCIPLINE)
// =============================================================================

int      g_session_ymd        = 0;        // YYYYMMDD of the current session
double   g_prev_day_high      = 0.0;      // D1[1] high at session start
double   g_prev_day_low       = 0.0;      // D1[1] low at session start
double   g_or_high            = 0.0;      // opening range high
double   g_or_low             = 1.0e18;   // opening range low (large sentinel)
int      g_or_bar_count       = 0;        // M15 bars collected in OR window (target: 2)
bool     g_or_formed          = false;    // true once 2 OR bars seen
double   g_r_long             = 0.0;      // breakout level for longs = max(OR_high, PDH)
double   g_r_short            = 0.0;      // breakout level for shorts = min(OR_low, PDL)
double   g_session_high       = 0.0;      // session high since open (for range filter)
double   g_session_low        = 1.0e18;   // session low since open
double   g_prev_session_range = 0.0;      // prior session high-low range
bool     g_entry_done         = false;    // one entry per session flag
datetime g_entry_time         = 0;        // when we entered (for time stop)
double   g_entry_r_dist       = 0.0;      // original stop distance in price (1R)
bool     g_breakeven_set      = false;    // BE already moved flag
bool     g_gap_skip_today     = false;    // true if this day's gap is too large
int      g_peak_r_100         = 0;        // peak favorable excursion in R × 100

// =============================================================================
// Helpers
// =============================================================================

int BrokerDateYMD()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
}

// Build today's session-open datetime in broker time
datetime TodaySessionOpen()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = strategy_session_open_hour;
   dt.min  = strategy_session_open_minute;
   dt.sec  = 0;
   return StructToTime(dt);
}

// =============================================================================
// Strategy hooks
// =============================================================================

// No per-tick gate beyond gap-skip — all session/OR/entry-window checks are
// in Strategy_EntrySignal so that ManageOpenPosition / ExitSignal always run.
bool Strategy_NoTradeFilter()
{
   return false;
}

// Advance OR and session range from the just-closed M15 bar.
// Called once per new bar, after new-session reset.
void AdvancePerBarState(const datetime sess_open)
{
   // perf-allowed: bespoke structural OR / session state from raw OHLC
   datetime bar_time = iTime(_Symbol, PERIOD_M15, 1);
   if(bar_time < sess_open)
      return;

   double bar_high = iHigh(_Symbol, PERIOD_M15, 1);
   double bar_low  = iLow(_Symbol,  PERIOD_M15, 1);

   // Track session range
   if(bar_high > g_session_high) g_session_high = bar_high;
   if(bar_low  < g_session_low)  g_session_low  = bar_low;

   // Build OR from the first two M15 bars at session open (0-30 min window)
   if(!g_or_formed && bar_time < sess_open + 30 * 60 && g_or_bar_count < 2)
   {
      if(bar_high > g_or_high) g_or_high = bar_high;
      if(bar_low  < g_or_low)  g_or_low  = bar_low;
      g_or_bar_count++;
      if(g_or_bar_count == 2)
      {
         g_or_formed = true;
         g_r_long    = (g_prev_day_high > 0.0) ? MathMax(g_or_high, g_prev_day_high) : g_or_high;
         g_r_short   = (g_prev_day_low  > 0.0) ? MathMin(g_or_low,  g_prev_day_low)  : g_or_low;
      }
   }
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const datetime now        = TimeCurrent();
   const datetime sess_open  = TodaySessionOpen();
   const int      today_ymd  = BrokerDateYMD();

   // --- New session detection: reset state and load fresh D1 context ---
   if(today_ymd != g_session_ymd && now >= sess_open)
   {
      // Archive prior session range
      if(g_session_high > 0.0 && g_session_low < 1.0e17)
         g_prev_session_range = g_session_high - g_session_low;

      // Reset all per-session state
      g_or_high        = 0.0;
      g_or_low         = 1.0e18;
      g_or_bar_count   = 0;
      g_or_formed      = false;
      g_r_long         = 0.0;
      g_r_short        = 0.0;
      g_session_high   = 0.0;
      g_session_low    = 1.0e18;
      g_entry_done     = false;
      g_entry_time     = 0;
      g_entry_r_dist   = 0.0;
      g_breakeven_set  = false;
      g_gap_skip_today = false;
      g_peak_r_100     = 0;

      // Load previous D1 bar's high/low (perf-allowed: bespoke structural)
      g_prev_day_high = iHigh(_Symbol, PERIOD_D1, 1);
      g_prev_day_low  = iLow(_Symbol,  PERIOD_D1, 1);

      // Gap filter: skip day if overnight gap > gap_atr_d1_mult × ATR(D1)
      // Note: .DWX CFDs are continuous so this rarely fires, but is correct per card
      double d1_open_today  = iOpen(_Symbol,  PERIOD_D1, 0);  // perf-allowed
      double d1_close_yest  = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed
      double d1_atr         = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
      double gap            = MathAbs(d1_open_today - d1_close_yest);
      if(d1_atr > 0.0 && gap > strategy_gap_atr_d1_mult * d1_atr)
         g_gap_skip_today = true;

      g_session_ymd = today_ymd;
   }

   // Pre-session or gap-skip: do nothing
   if(now < sess_open || g_gap_skip_today)
      return false;

   // Advance OR / session-range state from the just-closed M15 bar
   AdvancePerBarState(sess_open);

   // Gate: OR must be formed, no entry yet, no open position for this magic
   if(!g_or_formed || g_entry_done)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Gate: check current bar is within the 2-hour entry window
   // Entry window = [sess_open + 30min, sess_open + 150min)
   datetime bar_time = iTime(_Symbol, PERIOD_M15, 1);  // perf-allowed
   if(bar_time < sess_open + 30 * 60 || bar_time >= sess_open + 150 * 60)
      return false;

   double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period_m15, 1);
   if(atr <= 0.0)
      return false;

   // perf-allowed: bespoke structural OHLC reads for breakout confirmation
   double bar_high  = iHigh(_Symbol,  PERIOD_M15, 1);
   double bar_low   = iLow(_Symbol,   PERIOD_M15, 1);
   double bar_close = iClose(_Symbol, PERIOD_M15, 1);
   double bar_range = bar_high - bar_low;

   // Expansion filter: breakout bar range must be meaningful
   if(bar_range < strategy_entry_bar_min_range * atr)
      return false;

   // Session-range filter vs prior day (skip if no prior session data yet)
   if(g_prev_session_range > 0.0)
   {
      double session_range = (g_session_high > 0.0 && g_session_low < 1.0e17)
                             ? g_session_high - g_session_low : 0.0;
      if(session_range < strategy_session_range_factor * g_prev_session_range)
         return false;
   }

   // Detect breakout direction
   bool long_bo  = (g_r_long  > 0.0  && bar_close > g_r_long);
   bool short_bo = (g_r_short > 0.0  && g_r_short < 1.0e17 && bar_close < g_r_short);

   if(!long_bo && !short_bo)
      return false;

   // Prefer long when both trigger simultaneously (rare edge case)
   if(long_bo && short_bo)
      short_bo = false;

   QM_OrderType order_type;
   double       sl_price, entry_est, stop_dist;

   if(long_bo)
   {
      order_type = QM_BUY;
      entry_est  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl_price   = g_or_low - strategy_sl_atr_buffer * atr;
      stop_dist  = entry_est - sl_price;
      if(stop_dist <= 0.0 || stop_dist > strategy_sl_atr_cap * atr)
         return false;
   }
   else
   {
      order_type = QM_SELL;
      entry_est  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl_price   = g_or_high + strategy_sl_atr_buffer * atr;
      stop_dist  = sl_price - entry_est;
      if(stop_dist <= 0.0 || stop_dist > strategy_sl_atr_cap * atr)
         return false;
   }

   double tp_price = QM_TakeRR(_Symbol, order_type, entry_est, sl_price, strategy_tp_rr);

   req.type              = order_type;
   req.price             = 0.0;       // market fill
   req.sl                = sl_price;
   req.tp                = tp_price;
   req.reason            = "OR_PDH_BO";
   req.symbol_slot       = 0;
   req.expiration_seconds = 0;

   // Cache entry metadata for management functions
   g_entry_time    = now;
   g_entry_r_dist  = stop_dist;
   g_breakeven_set = false;
   g_peak_r_100    = 0;
   g_entry_done    = true;

   return true;
}

void Strategy_ManageOpenPosition()
{
   if(g_entry_r_dist <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double cur_price  = PositionGetDouble(POSITION_PRICE_CURRENT);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double favorable;
      if(pos_type == POSITION_TYPE_BUY)
         favorable = cur_price - open_price;
      else
         favorable = open_price - cur_price;

      // Track peak favorable excursion (R × 100)
      int cur_r_100 = (int)(favorable * 100.0 / g_entry_r_dist);
      if(cur_r_100 > g_peak_r_100)
         g_peak_r_100 = cur_r_100;

      // Break-even: move SL to just beyond entry price once price reaches be_r × R
      if(!g_breakeven_set && favorable >= strategy_be_r * g_entry_r_dist)
      {
         double pt     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double new_sl = (pos_type == POSITION_TYPE_BUY)
                         ? open_price + pt
                         : open_price - pt;
         if(QM_TM_MoveSL(ticket, new_sl, "BE_1R"))
            g_breakeven_set = true;
      }

      // Time stop: if time_stop_bars bars elapsed and price never reached min_r
      if(g_entry_time > 0)
      {
         int secs_elapsed = (int)(TimeCurrent() - g_entry_time);
         if(secs_elapsed >= strategy_time_stop_bars * 900)
         {
            double peak_r = (double)g_peak_r_100 * 0.01;
            if(peak_r < strategy_time_stop_min_r)
            {
               QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
               break;
            }
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) == 0)
      return false;

   // Hard EOD exit: close position 15 min before session close
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int now_min  = dt.hour * 60 + dt.min;
   int exit_min = strategy_eod_exit_hour * 60 + strategy_eod_exit_minute;
   return (now_min >= exit_min);
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;  // defer to QM_NewsAllowsTrade
}

// =============================================================================
// Framework wiring — do NOT edit below this line
// =============================================================================

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
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
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
