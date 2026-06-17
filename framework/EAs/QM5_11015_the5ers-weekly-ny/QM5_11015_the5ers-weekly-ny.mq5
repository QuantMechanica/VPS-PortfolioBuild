#property strict
#property version   "5.0"
#property description "QM5_11015 the5ers-weekly-ny — Tue/Wed NY weekly continuation breakout (H1 forex)"

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11015 the5ers-weekly-ny
// -----------------------------------------------------------------------------
// Source: The5ers blog "Never Stop Searching for the Best Trading Strategy"
//         (interview subject Cristian B.). Card:
//         artifacts/cards_approved/QM5_11015_the5ers-weekly-ny.md (g0 APPROVED).
//
// Mechanics (H1, max ONE entry per symbol per week; closed-bar reads @ shift 1):
//   Weekday gate : Tuesday OR Wednesday only (never Monday), in BROKER time.
//   Session gate : New-York-session broker-hour window. DXZ broker clock is
//                  NY-Close DST-aware, so NY cash open 09:30 ET maps to a
//                  ~constant broker hour (~16:30). Window is parameterised in
//                  broker hours (default 16..22) and read from the setfile.
//   Weekly open  : open of the first H1 bar of the current broker week (Monday).
//   Pre-NY range : high/low of bars from Monday open through this day's NY open.
//   D1 bias      : bullish if close(D1,1) > SMA(D1,sma) AND price > weekly open;
//                  bearish if close(D1,1) < SMA(D1,sma) AND price < weekly open.
//   Session move : NY-open price vs current-day open must exceed 0.5*ATR(H1)
//                  in the trade direction (Asian/London net move continuation).
//   Trigger      : latest H1 close breaks the pre-NY range high (long) / low
//                  (short), plus an optional breakout buffer in ATR multiples.
//   Stop         : structure (pre-NY range extreme) OR 1.5*ATR, whichever is
//                  CLOSER, but never tighter than 1.0*ATR.
//   Take profit  : R-multiple (default 2.0R) off the chosen stop distance.
//   Exits        : (a) structure exit — H1 closes back inside the broken range;
//                  (b) calendar exit  — close by Friday cutoff broker hour;
//                  (c) time stop      — close after N H1 bars (default 36).
//   One/week     : a week anchor (Monday 00:00 broker) + taken-flag persisted in
//                  file scope blocks a second weekly entry across restarts via
//                  re-derivation from open positions / GlobalVariable latch.
//
// All session/weekly timing is derived from the BAR TIMESTAMP in broker time
// (never a fixed wall-clock). Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; the framework wiring below MUST stay intact.
// =============================================================================

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
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Session / weekday gating (BROKER hours; DXZ broker is NY-Close DST-aware).
input int    strategy_ny_start_hour     = 16;     // NY-session start (broker hour; ~09:30 ET)
input int    strategy_ny_end_hour       = 22;     // NY-session end (broker hour, exclusive)
// D1 directional bias.
input int    strategy_sma_period        = 20;     // D1 SMA bias period (P3 sweep {20,50})
// Volatility / session-move / breakout.
input int    strategy_atr_period        = 14;     // H1 ATR period (filter / stop / sizing)
input double strategy_session_move_atr   = 0.5;   // NY-open vs day-open net move, in ATR
input double strategy_breakout_buf_atr   = 0.0;   // breakout buffer in ATR (P3 sweep {0,0.1,0.25})
// Stop / target.
input double strategy_sl_atr_mult        = 1.5;   // ATR stop cap multiple
input double strategy_sl_atr_floor       = 1.0;   // minimum stop distance in ATR
input double strategy_tp_rr              = 2.0;   // take-profit R-multiple (P3 sweep {1.5,2.0,2.5})
// Exits.
input int    strategy_time_stop_bars     = 36;    // close after N H1 bars if no TP/SL
input int    strategy_friday_exit_hour   = 18;    // calendar exit broker hour on Friday

// -----------------------------------------------------------------------------
// File-scope per-week state. Re-derived from the bar timestamp on each new bar;
// the "taken this week" flag prevents a second weekly entry across restarts.
// -----------------------------------------------------------------------------
datetime g_week_anchor       = 0;     // Monday 00:00 broker of the active week
bool     g_week_entry_taken  = false; // an entry already fired this week
double   g_active_range_high = 0.0;   // broken pre-NY range high (for structure exit, long)
double   g_active_range_low  = 0.0;   // broken pre-NY range low  (for structure exit, short)
int      g_entry_bar_index   = -1;    // bar index (since anchor) when the entry fired
datetime g_entry_bar_time    = 0;     // bar-open time of the entry, for the time stop

// Monday 00:00 (broker) of the week containing broker_time.
datetime WeekAnchorBroker(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   // MqlDateTime.day_of_week: 0=Sunday..6=Saturday. Days since Monday:
   const int days_since_monday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   // Midnight of the current broker day:
   const datetime day_midnight = broker_time - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   return day_midnight - (datetime)(days_since_monday * 86400);
  }

// Reset the per-week latch when a new broker week begins.
void RefreshWeekState(const datetime bar_broker_time)
  {
   const datetime anchor = WeekAnchorBroker(bar_broker_time);
   if(anchor != g_week_anchor)
     {
      g_week_anchor       = anchor;
      g_week_entry_taken  = false;
      g_active_range_high = 0.0;
      g_active_range_low  = 0.0;
      g_entry_bar_index   = -1;
      g_entry_bar_time    = 0;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap per-tick gate: weekday + NY-session window in broker time, plus a
// fail-open spread guard. Heavy signal work stays on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   // Gate off the CURRENT H1 bar-open time (broker time), not the live tick,
   // so the window is bar-aligned and DST-correct via the broker clock.
   const datetime bar_broker = iTime(_Symbol, _Period, 0); // perf-allowed: single read
   if(bar_broker <= 0)
      return true;

   MqlDateTime dt;
   TimeToStruct(bar_broker, dt);

   // Weekday: Tuesday(2) or Wednesday(3) only. Never Monday(1). 0=Sun..6=Sat.
   if(dt.day_of_week != 2 && dt.day_of_week != 3)
      return true;

   // NY-session broker-hour window.
   if(strategy_ny_start_hour <= strategy_ny_end_hour)
     {
      if(dt.hour < strategy_ny_start_hour || dt.hour >= strategy_ny_end_hour)
         return true;
     }
   else // wrap-safe (defensive; default window does not wrap)
     {
      if(dt.hour < strategy_ny_start_hour && dt.hour >= strategy_ny_end_hour)
         return true;
     }

   // Fail-open spread guard: only a genuinely wide spread blocks. .DWX models
   // zero spread (ask==bid) — never block on that.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value > 0.0)
        {
         const double cap = strategy_sl_atr_mult * atr_value; // spread vs stop scale
         if((ask - bid) > cap)
            return true;
        }
     }

   return false;
  }

// Tue/Wed NY weekly-continuation breakout. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const datetime bar_broker = iTime(_Symbol, _Period, 0); // perf-allowed: single read
   if(bar_broker <= 0)
      return false;

   RefreshWeekState(bar_broker);
   if(g_week_entry_taken)
      return false; // one entry per symbol per week

   // --- Weekly open: first H1 bar at/after the week anchor (Monday 00:00). ---
   // Walk back from the last closed bar until the bar before the anchor; the
   // first bar on/after the anchor carries the weekly open. Bounded to one week
   // of H1 bars (<=168) so this is cheap on the closed-bar path.
   double weekly_open = 0.0;
   for(int s = 1; s <= 200; ++s)
     {
      const datetime ts = iTime(_Symbol, _Period, s); // perf-allowed: single read
      if(ts <= 0)
         break;
      if(ts < g_week_anchor)
         break;
      weekly_open = iOpen(_Symbol, _Period, s); // perf-allowed: single read
     }
   if(weekly_open <= 0.0)
      return false;

   // --- Current-day open (broker calendar day of the forming bar). ---
   MqlDateTime bdt;
   TimeToStruct(bar_broker, bdt);
   const datetime day_midnight = bar_broker - (bdt.hour * 3600 + bdt.min * 60 + bdt.sec);
   double day_open = 0.0;
   for(int s = 1; s <= 48; ++s)
     {
      const datetime ts = iTime(_Symbol, _Period, s);
      if(ts <= 0)
         break;
      if(ts < day_midnight)
         break;
      day_open = iOpen(_Symbol, _Period, s);
     }
   if(day_open <= 0.0)
      return false;

   // --- Pre-NY range: high/low from Monday open through the bar that opens the
   //     NY session today (the current closed bar at shift 1 is the NY-open bar
   //     given the session gate). Scan shifts whose bar-open >= week anchor and
   //     bar-open < current bar-open (i.e. everything before this trigger bar). ---
   double range_high = -DBL_MAX;
   double range_low  =  DBL_MAX;
   bool   have_range = false;
   for(int s = 1; s <= 200; ++s)
     {
      const datetime ts = iTime(_Symbol, _Period, s);
      if(ts <= 0)
         break;
      if(ts < g_week_anchor)
         break;
      const double hi = iHigh(_Symbol, _Period, s);
      const double lo = iLow(_Symbol, _Period, s);
      if(hi <= 0.0 || lo <= 0.0)
         continue;
      if(hi > range_high) range_high = hi;
      if(lo < range_low)  range_low  = lo;
      have_range = true;
     }
   if(!have_range || range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   // --- ATR (H1) for session-move filter, breakout buffer, and the stop. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- D1 directional bias. ---
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single read
   const double d1_sma   = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   if(d1_close <= 0.0 || d1_sma <= 0.0)
      return false;

   // --- Latest closed H1 bar (the breakout / NY-open bar). ---
   const double brk_close = iClose(_Symbol, _Period, 1); // perf-allowed: single read
   const double ny_open   = iOpen(_Symbol, _Period, 1);  // NY-session bar open (perf-allowed)
   if(brk_close <= 0.0 || ny_open <= 0.0)
      return false;

   const double buffer       = strategy_breakout_buf_atr * atr_value;
   const double session_move = ny_open - day_open; // Asian/London net move proxy

   // --- LONG ---
   const bool bias_bull = (d1_close > d1_sma) && (brk_close > weekly_open);
   if(bias_bull &&
      session_move >= (strategy_session_move_atr * atr_value) &&
      brk_close > (range_high + buffer))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // Stop: structure (range low) OR 1.5*ATR, whichever is CLOSER to entry,
      // but never tighter than the ATR floor.
      const double struct_dist = entry - range_low;
      const double atr_cap     = strategy_sl_atr_mult * atr_value;
      const double atr_floor   = strategy_sl_atr_floor * atr_value;
      double sl_dist = MathMin(struct_dist, atr_cap);
      if(sl_dist < atr_floor)
         sl_dist = atr_floor;
      if(sl_dist <= 0.0)
         return false;

      const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_BUY, entry, sl_dist);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "the5ers_weekly_ny_long";

      g_week_entry_taken  = true;
      g_active_range_high = range_high;
      g_active_range_low  = 0.0;
      g_entry_bar_time    = bar_broker;
      return true;
     }

   // --- SHORT ---
   const bool bias_bear = (d1_close < d1_sma) && (brk_close < weekly_open);
   if(bias_bear &&
      session_move <= -(strategy_session_move_atr * atr_value) &&
      brk_close < (range_low - buffer))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double struct_dist = range_high - entry;
      const double atr_cap     = strategy_sl_atr_mult * atr_value;
      const double atr_floor   = strategy_sl_atr_floor * atr_value;
      double sl_dist = MathMin(struct_dist, atr_cap);
      if(sl_dist < atr_floor)
         sl_dist = atr_floor;
      if(sl_dist <= 0.0)
         return false;

      const double sl = QM_StopRulesStopFromDistance(_Symbol, QM_SELL, entry, sl_dist);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "the5ers_weekly_ny_short";

      g_week_entry_taken  = true;
      g_active_range_low  = range_low;
      g_active_range_high = 0.0;
      g_entry_bar_time    = bar_broker;
      return true;
     }

   return false;
  }

// No active SL/TP management beyond the fixed structure/ATR stop and RR target.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits: structure re-entry, Friday calendar cutoff, time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const datetime bar_broker = iTime(_Symbol, _Period, 0); // perf-allowed: single read
   if(bar_broker > 0)
     {
      MqlDateTime dt;
      TimeToStruct(bar_broker, dt);
      // Calendar exit: Friday(5) at/after the cutoff broker hour.
      if(dt.day_of_week == 5 && dt.hour >= strategy_friday_exit_hour)
         return true;
     }

   // Time stop: close after N H1 bars since entry.
   if(g_entry_bar_time > 0 && strategy_time_stop_bars > 0)
     {
      const int held_bars = (int)((bar_broker - g_entry_bar_time) / (PeriodSeconds(_Period)));
      if(held_bars >= strategy_time_stop_bars)
         return true;
     }

   // Structure exit: H1 closes back inside the broken range.
   const double brk_close = iClose(_Symbol, _Period, 1); // perf-allowed: single read
   if(brk_close > 0.0)
     {
      // Long: close back below the broken range high.
      if(g_active_range_high > 0.0 && brk_close < g_active_range_high)
         return true;
      // Short: close back above the broken range low.
      if(g_active_range_low > 0.0 && brk_close > g_active_range_low)
         return true;
     }

   return false;
  }

// Defer to the central two-axis news filter.
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
