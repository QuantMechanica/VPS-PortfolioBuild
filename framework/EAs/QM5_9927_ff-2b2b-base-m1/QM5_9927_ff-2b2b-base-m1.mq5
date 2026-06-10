#property strict
#property version   "5.0"
#property description "QM5_9927 ForexFactory 2B2B Base Scalper M1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9927;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_london_open_hour_broker = 10;
input int    strategy_london_open_min_broker  = 0;
input int    strategy_ny_open_hour_broker     = 16;
input int    strategy_ny_open_min_broker      = 30;
input int    strategy_session_minutes         = 180;
input int    strategy_atr_period              = 14;
input int    strategy_sweep_lookback          = 20;
input double strategy_sweep_atr_mult          = 0.15;
input int    strategy_break_lookback          = 5;
input int    strategy_max_break_bars          = 12;
input double strategy_keylevel_atr_m15_mult   = 0.60;
input double strategy_spread_atr_max          = 0.15;
input double strategy_sl_atr_mult             = 0.25;
input double strategy_rr_target               = 1.50;
input int    strategy_fx_tp_cap_pips          = 40;
input double strategy_xau_tp_atr_cap          = 3.00;
input int    strategy_time_stop_bars          = 45;
input int    strategy_news_blackout_minutes   = 15;

enum StrategySetupState
  {
   SETUP_IDLE = 0,
   SETUP_WAIT_BREAK1 = 1,
   SETUP_WAIT_BREAK2 = 2,
   SETUP_WAIT_RETEST = 3
  };

StrategySetupState g_long_state = SETUP_IDLE;
StrategySetupState g_short_state = SETUP_IDLE;
int    g_long_age_bars = 0;
int    g_short_age_bars = 0;
double g_recent_bull_base_low = 0.0;
double g_recent_bear_base_high = 0.0;
double g_long_base1_low = 0.0;
double g_long_base2_low = 0.0;
double g_long_break1_high = 0.0;
double g_long_break2_high = 0.0;
double g_short_base1_high = 0.0;
double g_short_base2_high = 0.0;
double g_short_break1_low = 0.0;
double g_short_break2_low = 0.0;
double g_active_base1_level = 0.0;
int    g_active_direction = 0;

double BarOpen(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iOpen(_Symbol, tf, shift); // perf-allowed: bounded structural OHLC read on closed-bar hooks.
  }

double BarHigh(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iHigh(_Symbol, tf, shift); // perf-allowed: bounded structural OHLC read on closed-bar hooks.
  }

double BarLow(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iLow(_Symbol, tf, shift); // perf-allowed: bounded structural OHLC read on closed-bar hooks.
  }

double BarClose(const ENUM_TIMEFRAMES tf, const int shift)
  {
   return iClose(_Symbol, tf, shift); // perf-allowed: bounded structural OHLC read on closed-bar hooks.
  }

double HighestHigh(const ENUM_TIMEFRAMES tf, const int start_shift, const int count)
  {
   if(count <= 0)
      return 0.0;
   double hi = -DBL_MAX;
   for(int i = 0; i < count; ++i)
     {
      const double value = BarHigh(tf, start_shift + i);
      if(value <= 0.0)
         return 0.0;
      hi = MathMax(hi, value);
     }
   return hi;
  }

double LowestLow(const ENUM_TIMEFRAMES tf, const int start_shift, const int count)
  {
   if(count <= 0)
      return 0.0;
   double lo = DBL_MAX;
   for(int i = 0; i < count; ++i)
     {
      const double value = BarLow(tf, start_shift + i);
      if(value <= 0.0)
         return 0.0;
      lo = MathMin(lo, value);
     }
   return lo;
  }

void ResetLongSetup()
  {
   g_long_state = SETUP_IDLE;
   g_long_age_bars = 0;
   g_long_base1_low = 0.0;
   g_long_base2_low = 0.0;
   g_long_break1_high = 0.0;
   g_long_break2_high = 0.0;
  }

void ResetShortSetup()
  {
   g_short_state = SETUP_IDLE;
   g_short_age_bars = 0;
   g_short_base1_high = 0.0;
   g_short_base2_high = 0.0;
   g_short_break1_low = 0.0;
   g_short_break2_low = 0.0;
  }

int MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool InMinuteWindow(const int minute_now, const int start_minute, const int duration_minutes)
  {
   if(duration_minutes <= 0)
      return false;
   const int end_minute = start_minute + duration_minutes;
   if(end_minute <= 1440)
      return (minute_now >= start_minute && minute_now < end_minute);
   return (minute_now >= start_minute || minute_now < (end_minute - 1440));
  }

bool InTradingSession(const datetime broker_time)
  {
   const int minute_now = MinutesOfDay(broker_time);
   const int london_start = strategy_london_open_hour_broker * 60 + strategy_london_open_min_broker;
   const int ny_start = strategy_ny_open_hour_broker * 60 + strategy_ny_open_min_broker;
   return InMinuteWindow(minute_now, london_start, strategy_session_minutes) ||
          InMinuteWindow(minute_now, ny_start, strategy_session_minutes);
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

bool NearLongKeyLevel(const double price, const double atr_m15)
  {
   if(price <= 0.0 || atr_m15 <= 0.0)
      return false;
   const double threshold = strategy_keylevel_atr_m15_mult * atr_m15;
   const double h1_support = LowestLow(PERIOD_H1, 1, strategy_sweep_lookback);
   const double h4_support = LowestLow(PERIOD_H4, 1, strategy_sweep_lookback);
   const double prior_session_low = BarLow(PERIOD_D1, 1);
   return (h1_support > 0.0 && MathAbs(price - h1_support) <= threshold) ||
          (h4_support > 0.0 && MathAbs(price - h4_support) <= threshold) ||
          (prior_session_low > 0.0 && MathAbs(price - prior_session_low) <= threshold);
  }

bool NearShortKeyLevel(const double price, const double atr_m15)
  {
   if(price <= 0.0 || atr_m15 <= 0.0)
      return false;
   const double threshold = strategy_keylevel_atr_m15_mult * atr_m15;
   const double h1_resistance = HighestHigh(PERIOD_H1, 1, strategy_sweep_lookback);
   const double h4_resistance = HighestHigh(PERIOD_H4, 1, strategy_sweep_lookback);
   const double prior_session_high = BarHigh(PERIOD_D1, 1);
   return (h1_resistance > 0.0 && MathAbs(price - h1_resistance) <= threshold) ||
          (h4_resistance > 0.0 && MathAbs(price - h4_resistance) <= threshold) ||
          (prior_session_high > 0.0 && MathAbs(price - prior_session_high) <= threshold);
  }

double PipSize()
  {
   if(StringFind(_Symbol, "JPY") >= 0)
      return 0.01;
   if(StringFind(_Symbol, "XAU") >= 0)
      return 0.10;
   return 0.0001;
  }

bool FillLongRequest(QM_EntryRequest &req, const double atr_m1)
  {
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0 || atr_m1 <= 0.0 || g_long_base2_low <= 0.0)
      return false;

   const double sl = g_long_base2_low - strategy_sl_atr_mult * atr_m1;
   const double risk = entry - sl;
   if(sl <= 0.0 || risk <= 0.0)
      return false;

   double tp_dist = strategy_rr_target * risk;
   if(StringFind(_Symbol, "XAU") >= 0)
      tp_dist = MathMin(tp_dist, strategy_xau_tp_atr_cap * atr_m1);
   else
      tp_dist = MathMin(tp_dist, strategy_fx_tp_cap_pips * PipSize());

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = entry + tp_dist;
   req.reason = "FF_2B2B_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_active_base1_level = g_long_base1_low;
   g_active_direction = 1;
   return true;
  }

bool FillShortRequest(QM_EntryRequest &req, const double atr_m1)
  {
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr_m1 <= 0.0 || g_short_base2_high <= 0.0)
      return false;

   const double sl = g_short_base2_high + strategy_sl_atr_mult * atr_m1;
   const double risk = sl - entry;
   if(sl <= 0.0 || risk <= 0.0)
      return false;

   double tp_dist = strategy_rr_target * risk;
   if(StringFind(_Symbol, "XAU") >= 0)
      tp_dist = MathMin(tp_dist, strategy_xau_tp_atr_cap * atr_m1);
   else
      tp_dist = MathMin(tp_dist, strategy_fx_tp_cap_pips * PipSize());

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = entry - tp_dist;
   req.reason = "FF_2B2B_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_active_base1_level = g_short_base1_high;
   g_active_direction = -1;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M1)
      return true;
   if(!InTradingSession(TimeCurrent()))
      return true;

   const double atr_m1 = QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr_m1 <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   if((ask - bid) > strategy_spread_atr_max * atr_m1)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOurOpenPosition())
      return false;

   const double o1 = BarOpen(PERIOD_M1, 1);
   const double h1 = BarHigh(PERIOD_M1, 1);
   const double l1 = BarLow(PERIOD_M1, 1);
   const double c1 = BarClose(PERIOD_M1, 1);
   const double prior_high = BarHigh(PERIOD_M1, 2);
   const double prior_low = BarLow(PERIOD_M1, 2);
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 || prior_high <= 0.0 || prior_low <= 0.0)
      return false;

   const double prior_bull_base_low = g_recent_bull_base_low;
   const double prior_bear_base_high = g_recent_bear_base_high;
   const double atr_m1 = QM_ATR(_Symbol, PERIOD_M1, strategy_atr_period, 1);
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr_m1 <= 0.0 || atr_m15 <= 0.0)
      return false;

   if(g_long_state != SETUP_IDLE)
      g_long_age_bars++;
   if(g_short_state != SETUP_IDLE)
      g_short_age_bars++;

   if(g_long_state != SETUP_IDLE && c1 < g_long_base1_low)
      ResetLongSetup();
   if(g_short_state != SETUP_IDLE && c1 > g_short_base1_high)
      ResetShortSetup();

   const double swing_low = LowestLow(PERIOD_M1, 2, strategy_sweep_lookback);
   const double swing_high = HighestHigh(PERIOD_M1, 2, strategy_sweep_lookback);
   const bool long_sweep = (swing_low > 0.0 &&
                            l1 < swing_low - strategy_sweep_atr_mult * atr_m1 &&
                            c1 > swing_low &&
                            NearLongKeyLevel(c1, atr_m15));
   const bool short_sweep = (swing_high > 0.0 &&
                             h1 > swing_high + strategy_sweep_atr_mult * atr_m1 &&
                             c1 < swing_high &&
                             NearShortKeyLevel(c1, atr_m15));

   if(g_long_state == SETUP_IDLE && long_sweep)
     {
      g_long_state = SETUP_WAIT_BREAK1;
      g_long_age_bars = 0;
     }
   else if(g_long_state == SETUP_WAIT_BREAK1)
     {
      if(g_long_age_bars > strategy_max_break_bars)
         ResetLongSetup();
      else
        {
         const double break_high = HighestHigh(PERIOD_M1, 2, strategy_break_lookback);
         if(break_high > 0.0 && c1 > break_high && c1 > o1)
           {
            g_long_base1_low = (prior_bull_base_low > 0.0) ? prior_bull_base_low : BarLow(PERIOD_M1, 2);
            g_long_base2_low = l1;
            g_long_break1_high = h1;
            g_long_state = SETUP_WAIT_BREAK2;
            g_long_age_bars = 0;
           }
        }
     }
   else if(g_long_state == SETUP_WAIT_BREAK2)
     {
      if(g_long_age_bars > strategy_max_break_bars)
         ResetLongSetup();
      else
        {
         g_long_base2_low = (g_long_base2_low > 0.0) ? MathMin(g_long_base2_low, l1) : l1;
         if(c1 > g_long_break1_high && c1 > o1)
           {
            g_long_break2_high = h1;
            g_long_state = SETUP_WAIT_RETEST;
            g_long_age_bars = 0;
           }
        }
     }
   else if(g_long_state == SETUP_WAIT_RETEST)
     {
      const bool touched_zone = (l1 <= g_long_break2_high && h1 >= g_long_base2_low);
      if(touched_zone && c1 > o1 && c1 >= g_long_base2_low)
        {
         const bool ok = FillLongRequest(req, atr_m1);
         ResetLongSetup();
         if(ok)
            return true;
        }
     }

   if(g_short_state == SETUP_IDLE && short_sweep)
     {
      g_short_state = SETUP_WAIT_BREAK1;
      g_short_age_bars = 0;
     }
   else if(g_short_state == SETUP_WAIT_BREAK1)
     {
      if(g_short_age_bars > strategy_max_break_bars)
         ResetShortSetup();
      else
        {
         const double break_low = LowestLow(PERIOD_M1, 2, strategy_break_lookback);
         if(break_low > 0.0 && c1 < break_low && c1 < o1)
           {
            g_short_base1_high = (prior_bear_base_high > 0.0) ? prior_bear_base_high : BarHigh(PERIOD_M1, 2);
            g_short_base2_high = h1;
            g_short_break1_low = l1;
            g_short_state = SETUP_WAIT_BREAK2;
            g_short_age_bars = 0;
           }
        }
     }
   else if(g_short_state == SETUP_WAIT_BREAK2)
     {
      if(g_short_age_bars > strategy_max_break_bars)
         ResetShortSetup();
      else
        {
         g_short_base2_high = (g_short_base2_high > 0.0) ? MathMax(g_short_base2_high, h1) : h1;
         if(c1 < g_short_break1_low && c1 < o1)
           {
            g_short_break2_low = l1;
            g_short_state = SETUP_WAIT_RETEST;
            g_short_age_bars = 0;
           }
        }
     }
   else if(g_short_state == SETUP_WAIT_RETEST)
     {
      const bool touched_zone = (h1 >= g_short_break2_low && l1 <= g_short_base2_high);
      if(touched_zone && c1 < o1 && c1 <= g_short_base2_high)
        {
         const bool ok = FillShortRequest(req, atr_m1);
         ResetShortSetup();
         if(ok)
            return true;
        }
     }

   if(c1 > prior_high)
      g_recent_bull_base_low = l1;
   if(c1 < prior_low)
      g_recent_bear_base_high = h1;

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card defines fixed SL/TP plus discretionary close only; no trailing or partial exits.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double c1 = BarClose(PERIOD_M1, 1);
   const int max_hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_M1);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(max_hold_seconds > 0 && open_time > 0 && TimeCurrent() - open_time >= max_hold_seconds)
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(c1 > 0.0 && g_active_base1_level > 0.0)
        {
         if(ptype == POSITION_TYPE_BUY && c1 < g_active_base1_level)
            return true;
         if(ptype == POSITION_TYPE_SELL && c1 > g_active_base1_level)
            return true;
        }
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(HasOurOpenPosition())
      return false;
   if(!g_qm_news_loaded)
     {
      if(!QM_NewsInit("D:\\QM\\data\\news_calendar",
                      qm_news_stale_max_hours,
                      strategy_news_blackout_minutes,
                      strategy_news_blackout_minutes,
                      qm_news_min_impact))
         return true;
     }
   if(!g_qm_news_available)
      return true;

   datetime utc_time = QM_BrokerToUTC(broker_time);
   if(utc_time <= 0)
      utc_time = TimeGMT();
   return QM_NewsInWindow(utc_time,
                          _Symbol,
                          strategy_news_blackout_minutes,
                          strategy_news_blackout_minutes,
                          "HIGH");
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
