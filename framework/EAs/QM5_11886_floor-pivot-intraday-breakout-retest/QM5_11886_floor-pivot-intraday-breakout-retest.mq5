#property strict
#property version   "5.0"
#property description "QM5_11886 floor-pivot-intraday-breakout-retest — M5 floor-pivot break+retest (EMA9/18 + H1 MACD)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11886 floor-pivot-intraday-breakout-retest
// -----------------------------------------------------------------------------
// Source: 202d107a — Anonymous "9 Forex Systems" compilation (~2010),
//         Forex Intraday Pivots Trading System chapter.
// Card: artifacts/cards_approved/QM5_11886_floor-pivot-intraday-breakout-retest.md
//       (g0_status APPROVED).
//
// Mechanics (M5 entry timeframe; closed-bar reads):
//   PIVOT STATE (per broker D1):
//     Classic floor pivots from the prior D1 bar OHLC (D1 shift 1, broker time):
//       P  = (H + L + C) / 3
//       R1 = 2P - L,  S1 = 2P - H
//       R2 = P + (H - L),  S2 = P - (H - L)
//       M1 = (S2 + S1)/2, M2 = (S1 + P)/2, M3 = (P + R1)/2, M4 = (R1 + R2)/2
//     Nine tradable levels (ascending): S2, S1, M1, M2, P, M3, R1, M4, R2.
//     Levels are static for the whole next broker day.
//
//   BREAK/RETEST STATE MACHINE (advanced once per closed M5 bar):
//     For each level, a *down-break* is armed when an M5 bar CLOSES below the
//     level by >= break_close_buffer_pips. While armed (within retrace_window
//     bars) the SHORT trigger EVENT fires when a later bar's HIGH retests the
//     level from below (within retrace_touch_tolerance_pips) WITHOUT the bar
//     closing back above it. Mirror for *up-break* -> LONG.
//     The pivot levels are STATE; the break is a latched condition; the retest
//     touch is the single trigger EVENT — never the same bar that broke. This
//     avoids the two-cross-same-bar zero-trade trap.
//
//   CONFIRMATION (at the retest bar, closed-bar reads):
//     SHORT: M5 EMA(9) < M5 EMA(18)  AND  H1 MACD signal line < 0.
//     LONG : M5 EMA(9) > M5 EMA(18)  AND  H1 MACD signal line > 0.
//
//   EXIT:
//     SL = 25 pips behind the broken level (above for shorts, below for longs).
//     TP = the next pivot level in the trade direction.
//     Otherwise flat at the end of the trade window.
//
//   FILTERS:
//     Trade window 07:00-17:00 UTC (London+NY overlap), converted to broker
//     time. One trade per pivot level per broker day (level locks once it
//     triggers). One open position per magic.
//
// Per-tick path is O(1): the state machine is advanced once per closed M5 bar
// in AdvanceState_OnNewBar(); Strategy_EntrySignal only reads cached arrays.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11886;
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
input int    strategy_ema_fast_period        = 9;     // M5 fast EMA (trend stack)
input int    strategy_ema_slow_period        = 18;    // M5 slow EMA (trend stack)
input int    strategy_macd_fast              = 12;    // H1 MACD fast EMA
input int    strategy_macd_slow              = 26;    // H1 MACD slow EMA
input int    strategy_macd_signal            = 9;     // H1 MACD signal period
input double strategy_break_close_buffer_pips = 3.0;  // close must clear level by >= this
input double strategy_retrace_touch_tol_pips = 3.0;   // retest touch tolerance at the level
input int    strategy_retrace_window_bars    = 6;     // bars after break to allow the retest
input double strategy_sl_pips_behind_level   = 25.0;  // stop distance behind the broken level
input int    strategy_trade_window_start_utc = 7;     // UTC hour: window open (inclusive)
input int    strategy_trade_window_end_utc   = 17;    // UTC hour: window close (exclusive)

// -----------------------------------------------------------------------------
// Cached strategy state (advanced by AdvanceState_OnNewBar on each closed M5 bar)
// -----------------------------------------------------------------------------
#define QM_PIV_COUNT 9   // S2,S1,M1,M2,P,M3,R1,M4,R2 (ascending price order)

// Level prices for the current broker day (ascending).
double   g_levels[QM_PIV_COUNT];
bool     g_levels_valid          = false;
datetime g_pivot_day             = 0;    // broker-day key (D1 bar-1 open) of g_levels

// Per-level break/retest state for the current broker day.
int      g_break_dir[QM_PIV_COUNT];      // +1 broke up (long-armed), -1 broke down, 0 none
int      g_break_age[QM_PIV_COUNT];      // closed M5 bars since the break was armed
bool     g_level_locked[QM_PIV_COUNT];   // one-trade-per-level-per-day lock

// Trigger latched by the state machine for Strategy_EntrySignal to consume.
bool     g_trigger_ready         = false;
int      g_trigger_dir           = 0;    // +1 long / -1 short
int      g_trigger_level_idx     = -1;
double   g_trigger_level_price   = 0.0;

// New-bar latch shared between exit and entry within one OnTick.
bool     g_new_bar_this_tick     = false;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

double PipSize()
  {
   // 1 pip = 10 points on 5/3-digit symbols, 1 point on 4/2-digit.
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

// Recompute classic floor pivots from the prior broker D1 bar. Returns false
// if the D1 history is not yet available. perf-allowed: single closed D1 read,
// gated to run only when the broker day rolls.
bool ComputePivotsForToday()
  {
   const datetime d1_open = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: prior D1 bar open (broker time)
   if(d1_open <= 0)
      return false;

   const double H = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: prior D1 OHLC
   const double L = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: prior D1 OHLC
   const double C = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: prior D1 OHLC
   if(H <= 0.0 || L <= 0.0 || C <= 0.0 || H < L)
      return false;

   const double P  = (H + L + C) / 3.0;
   const double R1 = 2.0 * P - L;
   const double S1 = 2.0 * P - H;
   const double R2 = P + (H - L);
   const double S2 = P - (H - L);
   const double M1 = (S2 + S1) / 2.0;
   const double M2 = (S1 + P)  / 2.0;
   const double M3 = (P  + R1) / 2.0;
   const double M4 = (R1 + R2) / 2.0;

   // Ascending price order: S2 < S1 < M1 < M2 < P < M3 < R1 < M4 < R2.
   g_levels[0] = S2;
   g_levels[1] = S1;
   g_levels[2] = M1;
   g_levels[3] = M2;
   g_levels[4] = P;
   g_levels[5] = M3;
   g_levels[6] = R1;
   g_levels[7] = M4;
   g_levels[8] = R2;

   g_pivot_day     = d1_open;
   g_levels_valid  = true;

   // New day -> reset per-level break/lock state.
   for(int i = 0; i < QM_PIV_COUNT; ++i)
     {
      g_break_dir[i]    = 0;
      g_break_age[i]    = 0;
      g_level_locked[i] = false;
     }
   return true;
  }

// Next pivot level in the trade direction (used as TP). Returns 0.0 if there is
// no further level (trade still allowed; TP omitted -> exits via SL / window).
double NextLevelPrice(const int level_idx, const int dir)
  {
   if(dir > 0)
     {
      if(level_idx + 1 < QM_PIV_COUNT)
         return g_levels[level_idx + 1];
     }
   else if(dir < 0)
     {
      if(level_idx - 1 >= 0)
         return g_levels[level_idx - 1];
     }
   return 0.0;
  }

// Advance the per-level break/retest state machine by exactly ONE closed M5 bar
// (the bar at shift 1). Latches at most one trigger into g_trigger_*.
// Called once per new closed M5 bar from OnTick.
void AdvanceState_OnNewBar()
  {
   g_trigger_ready       = false;
   g_trigger_dir         = 0;
   g_trigger_level_idx   = -1;
   g_trigger_level_price = 0.0;

   // (Re)compute pivots when the broker day rolls.
   const datetime cur_d1_open = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: day-roll key
   if(!g_levels_valid || cur_d1_open != g_pivot_day)
     {
      if(!ComputePivotsForToday())
         return;
     }
   if(!g_levels_valid)
      return;

   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar OHLC read
   const double h1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar OHLC read
   const double l1 = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar OHLC read
   if(c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0)
      return;

   const double pip = PipSize();
   const double break_buf = strategy_break_close_buffer_pips * pip;
   const double touch_tol = strategy_retrace_touch_tol_pips  * pip;

   // Confirmation states for THIS closed bar.
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double macd_sig = QM_MACD_Signal(_Symbol, PERIOD_H1,
                                          strategy_macd_fast, strategy_macd_slow,
                                          strategy_macd_signal, 1, PRICE_CLOSE);

   for(int i = 0; i < QM_PIV_COUNT; ++i)
     {
      const double lvl = g_levels[i];
      if(lvl <= 0.0)
         continue;

      // Age out / decay armed breaks.
      if(g_break_dir[i] != 0)
        {
         g_break_age[i]++;
         if(g_break_age[i] > strategy_retrace_window_bars)
           {
            g_break_dir[i] = 0;
            g_break_age[i] = 0;
           }
        }

      if(g_level_locked[i])
         continue;

      // ----- Retest trigger check on an ALREADY-armed break (prior bars) -----
      if(g_break_dir[i] == -1)
        {
         // Short: price retraces UP to the broken level from below.
         // Touch = bar high reaches within tolerance of the level but the bar
         // does NOT close back above the level.
         const bool touched = (h1 >= lvl - touch_tol && h1 <= lvl + touch_tol);
         if(touched && c1 <= lvl && ema_fast > 0.0 && ema_slow > 0.0 &&
            ema_fast < ema_slow && macd_sig < 0.0)
           {
            g_trigger_ready       = true;
            g_trigger_dir         = -1;
            g_trigger_level_idx   = i;
            g_trigger_level_price = lvl;
            // Latch first qualifying trigger; state machine continues but the
            // single-position guard means only one fires.
            break;
           }
        }
      else if(g_break_dir[i] == +1)
        {
         // Long: price retraces DOWN to the broken level from above.
         const bool touched = (l1 <= lvl + touch_tol && l1 >= lvl - touch_tol);
         if(touched && c1 >= lvl && ema_fast > 0.0 && ema_slow > 0.0 &&
            ema_fast > ema_slow && macd_sig > 0.0)
           {
            g_trigger_ready       = true;
            g_trigger_dir         = +1;
            g_trigger_level_idx   = i;
            g_trigger_level_price = lvl;
            break;
           }
        }

      // ----- Arm a NEW break on THIS closed bar (separate from the retest) ----
      // A break is the bar CLOSING through the level by >= buffer. The break and
      // its retest are necessarily different bars, so arming here and triggering
      // on a later bar cannot be a same-bar two-cross.
      if(g_break_dir[i] == 0)
        {
         if(c1 < lvl - break_buf)
           {
            g_break_dir[i] = -1;  // broke down -> short-armed (sell the retest)
            g_break_age[i] = 0;
           }
         else if(c1 > lvl + break_buf)
           {
            g_break_dir[i] = +1;  // broke up -> long-armed (buy the retest)
            g_break_age[i] = 0;
           }
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading outside the broker-time trade window (07:00-17:00 UTC ported to
// broker time, DST-aware). Cheap O(1).
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   const datetime utc_now     = QM_BrokerToUTC(broker_now);

   MqlDateTime ut;
   TimeToStruct(utc_now, ut);
   const int h = ut.hour;

   // Window is [start, end) in UTC.
   if(h < strategy_trade_window_start_utc || h >= strategy_trade_window_end_utc)
      return true; // outside window -> block

   return false;
  }

// Entry: consume the latched break+retest trigger. Caller guarantees
// QM_IsNewBar() == true. Only reads cached state — no per-tick lookback.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_trigger_ready || g_trigger_dir == 0 || g_trigger_level_idx < 0)
      return false;
   if(g_level_locked[g_trigger_level_idx])
      return false;

   const double pip      = PipSize();
   const double lvl      = g_trigger_level_price;
   const double sl_dist  = strategy_sl_pips_behind_level * pip;

   if(g_trigger_dir < 0)
     {
      // SHORT: SL above the broken level; TP = next level down.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, lvl + sl_dist);
      double tp = NextLevelPrice(g_trigger_level_idx, -1);
      if(tp > 0.0)
         tp = QM_StopRulesNormalizePrice(_Symbol, tp);
      else
         tp = 0.0; // no further level -> rely on SL / window exit

      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "floor_pivot_retest_short";
     }
   else
     {
      // LONG: SL below the broken level; TP = next level up.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, lvl - sl_dist);
      double tp = NextLevelPrice(g_trigger_level_idx, +1);
      if(tp > 0.0)
         tp = QM_StopRulesNormalizePrice(_Symbol, tp);
      else
         tp = 0.0;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "floor_pivot_retest_long";
     }

   // Lock the level for the rest of the broker day and consume the trigger.
   g_level_locked[g_trigger_level_idx] = true;
   g_trigger_ready = false;
   return true;
  }

// SL/TP are fixed at entry (level-based). No active management.
void Strategy_ManageOpenPosition()
  {
  }

// Time-stop: flatten when the trade window closes (price still flat exit via
// SL/TP otherwise). One event per tick check.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime ut;
   TimeToStruct(utc_now, ut);
   // Close any open position once we are at/after the window end.
   if(ut.hour >= strategy_trade_window_end_utc)
      return true;
   return false;
  }

// Defer to the central news filter.
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

   g_levels_valid       = false;
   g_pivot_day          = 0;
   g_trigger_ready      = false;
   for(int i = 0; i < QM_PIV_COUNT; ++i)
     {
      g_levels[i]       = 0.0;
      g_break_dir[i]    = 0;
      g_break_age[i]    = 0;
      g_level_locked[i] = false;
     }

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

   // Advance the closed-bar state machine FIRST so exit/entry see fresh state.
   // QM_IsNewBar() is single-consume per tick — latch it once and reuse.
   g_new_bar_this_tick = QM_IsNewBar();
   if(g_new_bar_this_tick)
      AdvanceState_OnNewBar();

   if(Strategy_NoTradeFilter())
     {
      // Still allow the time-stop exit even when entry is blocked by the window.
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
      return;
     }

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

   if(!g_new_bar_this_tick)
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
