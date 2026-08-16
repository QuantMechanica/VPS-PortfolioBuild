#property strict
#property version   "5.0"
#property description "QM5_20150 emacross-stochhook-fib-h4 (V5)"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 9999;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
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
input int    strategy_ema_fast          = 20;
input int    strategy_ema_slow          = 50;
input int    strategy_stoch_k           = 14;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 1;
input double strategy_ob_level          = 80.0;
input double strategy_os_level          = 20.0;
input double strategy_sl_buffer_pips    = 10.0;

enum Strategy137ArmState
  {
   STR137_IDLE = 0,
   STR137_ARMED_LONG = 1,
   STR137_ARMED_SHORT = 2
  };

Strategy137ArmState g_str137_arm = STR137_IDLE;
datetime g_str137_arm_bar = 0;
bool     g_str137_opposite_extreme_seen = false;
double   g_str137_arm_impulse_start = 0.0;
double   g_str137_arm_impulse_end = 0.0;
int      g_str137_stoch_handle = INVALID_HANDLE;
int      g_str137_ema_fast_handle = INVALID_HANDLE;
int      g_str137_ema_slow_handle = INVALID_HANDLE;
datetime g_str137_last_entry_eval_bar = 0;
datetime g_str137_last_manage_eval_bar = 0;
datetime g_str137_last_close_attempt_bar = 0;
datetime g_str137_last_modify_attempt_bar = 0;
datetime g_str137_last_data_log_bar = 0;
datetime g_str137_signal_cache_bar = 0;
datetime g_str137_signal_reserved_for_exit_bar = 0;
ulong    g_str137_position_id = 0;
int      g_str137_active_direction = 0;
double   g_str137_active_impulse_start = 0.0;
double   g_str137_active_impulse_end = 0.0;
int      g_str137_fib_step = -1;
bool     g_str137_opposite_close_pending = false;
int      g_str137_signal_cache_direction = 0;
double   g_str137_signal_cache_start = 0.0;
double   g_str137_signal_cache_end = 0.0;

bool Strategy137_SymbolSlotValid()
  {
   if(_Symbol == "EURUSD.DWX")
      return (qm_magic_slot_offset == 0);
   if(_Symbol == "USDJPY.DWX")
      return (qm_magic_slot_offset == 1);
   return false;
  }

bool Strategy137_ConfigValid()
  {
   return (_Period == PERIOD_H4 &&
           Strategy137_SymbolSlotValid() &&
           strategy_ema_fast == 20 &&
           strategy_ema_slow == 50 &&
           strategy_stoch_k == 14 &&
           strategy_stoch_d == 3 &&
           strategy_stoch_slowing == 1 &&
           MathAbs(strategy_ob_level - 80.0) < 1e-9 &&
           MathAbs(strategy_os_level - 20.0) < 1e-9 &&
           MathAbs(strategy_sl_buffer_pips - 10.0) < 1e-9);
  }

bool Strategy137_CurrentBar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H4,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) forming-H4 cadence
   return (bar_time > 0);
  }

void Strategy137_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str137_last_data_log_bar)
      return;
   g_str137_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-137\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

bool Strategy137_IndicatorValid(const double value)
  {
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE &&
           value >= 0.0);
  }

double Strategy137_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick =
         SymbolInfoDouble(_Symbol,
                          SYMBOL_POINT);
   return tick;
  }

double Strategy137_PipSize()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

double Strategy137_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy137_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol,
                               units * tick);
  }

bool Strategy137_NewsAllows(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol,
                             broker_time,
                             qm_news_mode_legacy);
  }

int Strategy137_CloseCloseStochHandle()
  {
   const string key =
      StringFormat("STR137_STOCH_CC|%s|%d|%d|%d|%d",
                   _Symbol,
                   (int)PERIOD_H4,
                   strategy_stoch_k,
                   strategy_stoch_d,
                   strategy_stoch_slowing);
   int handle = QM_IndicatorsLookup(key);
   if(handle != INVALID_HANDLE)
      return handle;
   handle =
      iStochastic(_Symbol, // perf-allowed: STO_CLOSECLOSE is strategy identity, unavailable via QM_IndStoch (STO_LOWHIGH only); QM_IndicatorsRegister-pooled, not lazy
                  PERIOD_H4,
                  strategy_stoch_k,
                  strategy_stoch_d,
                  strategy_stoch_slowing,
                  MODE_SMA,
                  STO_CLOSECLOSE); // perf-allowed: CLOSE/CLOSE is strategy identity; pool-registered 20138 pattern
   return QM_IndicatorsRegister(key, handle);
  }

bool Strategy137_EnsureHandles()
  {
   if(g_str137_stoch_handle == INVALID_HANDLE)
      g_str137_stoch_handle =
         Strategy137_CloseCloseStochHandle();
   if(g_str137_ema_fast_handle == INVALID_HANDLE)
      g_str137_ema_fast_handle =
         QM_IndMA(_Symbol,
                  PERIOD_H4,
                  strategy_ema_fast,
                  MODE_EMA,
                  PRICE_CLOSE);
   if(g_str137_ema_slow_handle == INVALID_HANDLE)
      g_str137_ema_slow_handle =
         QM_IndMA(_Symbol,
                  PERIOD_H4,
                  strategy_ema_slow,
                  MODE_EMA,
                  PRICE_CLOSE);
   return (g_str137_stoch_handle != INVALID_HANDLE &&
           g_str137_ema_fast_handle != INVALID_HANDLE &&
           g_str137_ema_slow_handle != INVALID_HANDLE);
  }

bool Strategy137_HandlesReady()
  {
   return (Strategy137_EnsureHandles() &&
           BarsCalculated(g_str137_stoch_handle) >= 510 &&
           BarsCalculated(g_str137_ema_fast_handle) >= 510 &&
           BarsCalculated(g_str137_ema_slow_handle) >= 510);
  }

bool Strategy137_FindOwnPosition(
   ulong &ticket,
   ulong &position_id,
   ENUM_POSITION_TYPE &position_type,
   double &open_price,
   double &current_sl,
   double &current_tp,
   datetime &position_time)
  {
   ticket = 0;
   position_id = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   current_tp = 0.0;
   position_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_id =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl =
         PositionGetDouble(POSITION_SL);
      current_tp =
         PositionGetDouble(POSITION_TP);
      position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy137_HasOwnPosition()
  {
   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   datetime position_time = 0;
   return Strategy137_FindOwnPosition(ticket,
                                      position_id,
                                      position_type,
                                      open_price,
                                      current_sl,
                                      current_tp,
                                      position_time);
  }

bool Strategy137_ReadEpisodeBar(
   const int shift,
   double &fast_now,
   double &slow_now,
   double &fast_prev,
   double &slow_prev,
   double &k_now,
   double &d_now,
   double &k_prev,
   double &d_prev,
   MqlRates &bar)
  {
   if(shift < 1)
      return false;
   fast_now =
      QM_IndicatorReadBuffer(
         g_str137_ema_fast_handle,
         0,
         shift); // perf-allowed: pooled closed-H4 EMA
   slow_now =
      QM_IndicatorReadBuffer(
         g_str137_ema_slow_handle,
         0,
         shift); // perf-allowed: pooled closed-H4 EMA
   fast_prev =
      QM_IndicatorReadBuffer(
         g_str137_ema_fast_handle,
         0,
         shift + 1); // perf-allowed: pooled closed-H4 EMA predecessor
   slow_prev =
      QM_IndicatorReadBuffer(
         g_str137_ema_slow_handle,
         0,
         shift + 1); // perf-allowed: pooled closed-H4 EMA predecessor
   k_now =
      QM_IndicatorReadBuffer(
         g_str137_stoch_handle,
         0,
         shift); // perf-allowed: pooled CLOSE/CLOSE K, closed shift
   d_now =
      QM_IndicatorReadBuffer(
         g_str137_stoch_handle,
         1,
         shift); // perf-allowed: pooled CLOSE/CLOSE D, closed shift
   k_prev =
      QM_IndicatorReadBuffer(
         g_str137_stoch_handle,
         0,
         shift + 1); // perf-allowed: pooled CLOSE/CLOSE K predecessor
   d_prev =
      QM_IndicatorReadBuffer(
         g_str137_stoch_handle,
         1,
         shift + 1); // perf-allowed: pooled CLOSE/CLOSE D predecessor
   return (Strategy137_IndicatorValid(fast_now) &&
           Strategy137_IndicatorValid(slow_now) &&
           Strategy137_IndicatorValid(fast_prev) &&
           Strategy137_IndicatorValid(slow_prev) &&
           Strategy137_IndicatorValid(k_now) &&
           Strategy137_IndicatorValid(d_now) &&
           Strategy137_IndicatorValid(k_prev) &&
           Strategy137_IndicatorValid(d_prev) &&
           fast_now > 0.0 &&
           slow_now > 0.0 &&
           fast_prev > 0.0 &&
           slow_prev > 0.0 &&
           QM_ReadBar(_Symbol,
                      PERIOD_H4,
                      shift,
                      bar)); // perf-allowed: one sanctioned closed-H4 record
  }

bool Strategy137_FindImpulseStart(const int cross_shift,
                                  const bool long_side,
                                  double &impulse_start,
                                  const datetime forming_time)
  {
   impulse_start = 0.0;
   MqlRates cross_bar;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_H4,
                  cross_shift,
                  cross_bar)) // perf-allowed: sanctioned cross-bar anchor read
      return false;
   impulse_start =
      long_side ? cross_bar.low : cross_bar.high;

   bool boundary_found = false;
   for(int offset = 1; offset <= 500; ++offset)
     {
      const int shift = cross_shift + offset;
      const double fast =
         QM_IndicatorReadBuffer(
            g_str137_ema_fast_handle,
            0,
            shift); // perf-allowed: capped preceding-regime EMA scan
      const double slow =
         QM_IndicatorReadBuffer(
            g_str137_ema_slow_handle,
            0,
            shift); // perf-allowed: capped preceding-regime EMA scan
      MqlRates bar;
      if(!Strategy137_IndicatorValid(fast) ||
         !Strategy137_IndicatorValid(slow) ||
         fast <= 0.0 || slow <= 0.0 ||
         !QM_ReadBar(_Symbol,
                     PERIOD_H4,
                     shift,
                     bar)) // perf-allowed: capped sanctioned regime record
        {
         Strategy137_LogDataMissing("impulse_regime_scan",
                                    forming_time);
         return false;
        }
      const bool still_opposite =
         long_side ? (fast <= slow) : (fast >= slow);
      if(!still_opposite)
        {
         boundary_found = true;
         break;
        }
      impulse_start =
         long_side
         ? MathMin(impulse_start, bar.low)
         : MathMax(impulse_start, bar.high);
     }
   if(!boundary_found)
     {
      QM_LogEvent(
         QM_WARN,
         SETUP_DATA_MISSING,
         StringFormat(
            "{\"strategy\":\"STR-137\",\"component\":\"regime_walk_cap_500\",\"cross_shift\":%d,\"bar_time\":%I64d}",
            cross_shift,
            (long)forming_time));
      return false;
     }
   return (impulse_start > 0.0);
  }

int Strategy137_ApplyEpisodeBar(
   const int shift,
   const double fast_now,
   const double slow_now,
   const double fast_prev,
   const double slow_prev,
   const double k_now,
   const double d_now,
   const double k_prev,
   const double d_prev,
   const MqlRates &bar,
   const datetime forming_time,
   double &signal_start,
   double &signal_end)
  {
   signal_start = 0.0;
   signal_end = 0.0;
   const bool bull_cross =
      (fast_now > slow_now &&
       fast_prev <= slow_prev);
   const bool bear_cross =
      (fast_now < slow_now &&
       fast_prev >= slow_prev);
   if(bull_cross)
     {
      g_str137_arm = STR137_IDLE;
      g_str137_arm_bar = 0;
      g_str137_opposite_extreme_seen = false;
      if(k_now < strategy_ob_level ||
         !Strategy137_FindImpulseStart(shift,
                                       true,
                                       g_str137_arm_impulse_start,
                                       forming_time))
         return 0;
      g_str137_arm = STR137_ARMED_LONG;
      g_str137_arm_bar = bar.time;
      g_str137_arm_impulse_end = bar.high;
      return 0;
     }
   if(bear_cross)
     {
      g_str137_arm = STR137_IDLE;
      g_str137_arm_bar = 0;
      g_str137_opposite_extreme_seen = false;
      if(k_now > strategy_os_level ||
         !Strategy137_FindImpulseStart(shift,
                                       false,
                                       g_str137_arm_impulse_start,
                                       forming_time))
         return 0;
      g_str137_arm = STR137_ARMED_SHORT;
      g_str137_arm_bar = bar.time;
      g_str137_arm_impulse_end = bar.low;
      return 0;
     }

   if(g_str137_arm == STR137_ARMED_LONG)
     {
      if(fast_now <= slow_now)
        {
         g_str137_arm = STR137_IDLE;
         g_str137_arm_bar = 0;
         g_str137_opposite_extreme_seen = false;
         return 0;
        }
      g_str137_arm_impulse_end =
         MathMax(g_str137_arm_impulse_end,
                 bar.high);
      if(k_now <= strategy_os_level)
         g_str137_opposite_extreme_seen = true;
      const bool hook =
         (g_str137_opposite_extreme_seen &&
          k_prev <= d_prev &&
          k_now > d_now &&
          MathMin(k_now, d_now) <= strategy_os_level);
      if(!hook)
         return 0;
      signal_start = g_str137_arm_impulse_start;
      signal_end = g_str137_arm_impulse_end;
      g_str137_arm = STR137_IDLE; // first hook consumes accept or reject
      g_str137_arm_bar = 0;
      g_str137_opposite_extreme_seen = false;
      return 1;
     }

   if(g_str137_arm == STR137_ARMED_SHORT)
     {
      if(fast_now >= slow_now)
        {
         g_str137_arm = STR137_IDLE;
         g_str137_arm_bar = 0;
         g_str137_opposite_extreme_seen = false;
         return 0;
        }
      g_str137_arm_impulse_end =
         MathMin(g_str137_arm_impulse_end,
                 bar.low);
      if(k_now >= strategy_ob_level)
         g_str137_opposite_extreme_seen = true;
      const bool hook =
         (g_str137_opposite_extreme_seen &&
          k_prev >= d_prev &&
          k_now < d_now &&
          MathMax(k_now, d_now) >= strategy_ob_level);
      if(!hook)
         return 0;
      signal_start = g_str137_arm_impulse_start;
      signal_end = g_str137_arm_impulse_end;
      g_str137_arm = STR137_IDLE;
      g_str137_arm_bar = 0;
      g_str137_opposite_extreme_seen = false;
      return -1;
     }
   return 0;
  }

bool Strategy137_ReconstructThroughBar2(
   const datetime forming_time)
  {
   g_str137_arm = STR137_IDLE;
   g_str137_arm_bar = 0;
   g_str137_opposite_extreme_seen = false;
   g_str137_arm_impulse_start = 0.0;
   g_str137_arm_impulse_end = 0.0;

   const long available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H4,
                        SERIES_BARS_COUNT); // perf-allowed: bounded episode reconstruction
   int lookback = (int)MathMin((double)available - 2.0,
                               510.0);
   if(lookback < 60)
      return false;
   for(int shift = lookback - 1; shift >= 2; --shift)
     {
      double fast_now = 0.0;
      double slow_now = 0.0;
      double fast_prev = 0.0;
      double slow_prev = 0.0;
      double k_now = 0.0;
      double d_now = 0.0;
      double k_prev = 0.0;
      double d_prev = 0.0;
      MqlRates bar;
      if(!Strategy137_ReadEpisodeBar(shift,
                                     fast_now,
                                     slow_now,
                                     fast_prev,
                                     slow_prev,
                                     k_now,
                                     d_now,
                                     k_prev,
                                     d_prev,
                                     bar))
        {
         Strategy137_LogDataMissing("episode_reconstruction",
                                    forming_time);
         return false;
        }
      double ignored_start = 0.0;
      double ignored_end = 0.0;
      Strategy137_ApplyEpisodeBar(shift,
                                  fast_now,
                                  slow_now,
                                  fast_prev,
                                  slow_prev,
                                  k_now,
                                  d_now,
                                  k_prev,
                                  d_prev,
                                  bar,
                                  forming_time,
                                  ignored_start,
                                  ignored_end);
     }
   return true;
  }

bool Strategy137_EvaluateLatestSignal(
   const datetime forming_time)
  {
   if(forming_time > 0 &&
      forming_time == g_str137_signal_cache_bar)
      return true;
   g_str137_signal_cache_bar = 0;
   g_str137_signal_cache_direction = 0;
   g_str137_signal_cache_start = 0.0;
   g_str137_signal_cache_end = 0.0;
   if(!Strategy137_ConfigValid() ||
      !Strategy137_HandlesReady() ||
      !Strategy137_ReconstructThroughBar2(forming_time))
      return false;

   double fast_now = 0.0;
   double slow_now = 0.0;
   double fast_prev = 0.0;
   double slow_prev = 0.0;
   double k_now = 0.0;
   double d_now = 0.0;
   double k_prev = 0.0;
   double d_prev = 0.0;
   MqlRates signal_bar;
   if(!Strategy137_ReadEpisodeBar(1,
                                  fast_now,
                                  slow_now,
                                  fast_prev,
                                  slow_prev,
                                  k_now,
                                  d_now,
                                  k_prev,
                                  d_prev,
                                  signal_bar))
     {
      Strategy137_LogDataMissing("closed_h4_inputs",
                                 forming_time);
      return false;
     }
   g_str137_signal_cache_direction =
      Strategy137_ApplyEpisodeBar(
         1,
         fast_now,
         slow_now,
         fast_prev,
         slow_prev,
         k_now,
         d_now,
         k_prev,
         d_prev,
         signal_bar,
         forming_time,
         g_str137_signal_cache_start,
         g_str137_signal_cache_end);
   g_str137_signal_cache_bar = forming_time;
   return true;
  }

int Strategy137_FibStepForClose(const int direction,
                                const double impulse_start,
                                const double impulse_end,
                                const double close_price)
  {
   const double length =
      MathAbs(impulse_end - impulse_start);
   if(direction == 0 ||
      impulse_start <= 0.0 ||
      impulse_end <= 0.0 ||
      length <= 0.0 ||
      close_price <= 0.0)
      return -1;
   double ratios[10] =
      {1.0, 1.272, 1.618, 2.0, 2.618,
       3.0, 3.618, 4.0, 4.618, 5.0};
   int reached = -1;
   const double tick = Strategy137_TradeTick();
   for(int i = 0; i < 10; ++i)
     {
      const double level =
         impulse_start +
         (double)direction * ratios[i] * length;
      const bool qualifies =
         direction > 0
         ? close_price + tick * 0.1 >= level
         : close_price - tick * 0.1 <= level;
      if(qualifies)
         reached = i;
     }
   return reached;
  }

bool Strategy137_RecoverPositionState(
   const ENUM_POSITION_TYPE position_type,
   const datetime position_time,
   const datetime forming_time)
  {
   const Strategy137ArmState saved_arm = g_str137_arm;
   const datetime saved_arm_bar = g_str137_arm_bar;
   const bool saved_seen = g_str137_opposite_extreme_seen;
   const double saved_start = g_str137_arm_impulse_start;
   const double saved_end = g_str137_arm_impulse_end;

   g_str137_arm = STR137_IDLE;
   g_str137_arm_bar = 0;
   g_str137_opposite_extreme_seen = false;
   g_str137_arm_impulse_start = 0.0;
   g_str137_arm_impulse_end = 0.0;

   const int wanted_direction =
      position_type == POSITION_TYPE_BUY ? 1 : -1;
   int found_direction = 0;
   double found_start = 0.0;
   double found_end = 0.0;
   const long available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H4,
                        SERIES_BARS_COUNT); // perf-allowed: bounded position-anchor recovery
   const int lookback =
      (int)MathMin((double)available - 2.0,
                   510.0);
   for(int shift = lookback - 1; shift >= 1; --shift)
     {
      double fast_now = 0.0;
      double slow_now = 0.0;
      double fast_prev = 0.0;
      double slow_prev = 0.0;
      double k_now = 0.0;
      double d_now = 0.0;
      double k_prev = 0.0;
      double d_prev = 0.0;
      MqlRates bar;
      if(!Strategy137_ReadEpisodeBar(shift,
                                     fast_now,
                                     slow_now,
                                     fast_prev,
                                     slow_prev,
                                     k_now,
                                     d_now,
                                     k_prev,
                                     d_prev,
                                     bar))
         break;
      if(bar.time >= position_time)
         continue;
      double candidate_start = 0.0;
      double candidate_end = 0.0;
      const int direction =
         Strategy137_ApplyEpisodeBar(
            shift,
            fast_now,
            slow_now,
            fast_prev,
            slow_prev,
            k_now,
            d_now,
            k_prev,
            d_prev,
            bar,
            forming_time,
            candidate_start,
            candidate_end);
      if(direction == wanted_direction)
        {
         found_direction = direction;
         found_start = candidate_start;
         found_end = candidate_end;
        }
     }

   g_str137_arm = saved_arm;
   g_str137_arm_bar = saved_arm_bar;
   g_str137_opposite_extreme_seen = saved_seen;
   g_str137_arm_impulse_start = saved_start;
   g_str137_arm_impulse_end = saved_end;

   if(found_direction == 0 ||
      found_start <= 0.0 ||
      found_end <= 0.0 ||
      MathAbs(found_end - found_start) <= 0.0)
      return false;
   g_str137_active_direction = found_direction;
   g_str137_active_impulse_start = found_start;
   g_str137_active_impulse_end = found_end;
   g_str137_fib_step = -1;

   // Rebuild the highest close-qualified ladder step since actual entry.
   for(int shift = 500; shift >= 1; --shift)
     {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol,
                     PERIOD_H4,
                     shift,
                     bar)) // perf-allowed: bounded sanctioned post-entry close scan
         continue;
      const datetime bar_close =
         bar.time + PeriodSeconds(PERIOD_H4);
      if(bar_close <= position_time)
         continue;
      const int reached =
         Strategy137_FibStepForClose(
            g_str137_active_direction,
            g_str137_active_impulse_start,
            g_str137_active_impulse_end,
            bar.close);
      if(reached > g_str137_fib_step)
         g_str137_fib_step = reached;
     }
   return true;
  }

bool Strategy137_EntryStopLegal(const bool buy_side,
                                const double entry,
                                const double sl)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy137_TradeTick();
   if(entry <= 0.0 || sl <= 0.0 ||
      point <= 0.0 || tick <= 0.0)
      return false;
   const long broker_level =
      MathMax(SymbolInfoInteger(_Symbol,
                                SYMBOL_TRADE_STOPS_LEVEL),
              SymbolInfoInteger(_Symbol,
                                SYMBOL_TRADE_FREEZE_LEVEL));
   const double minimum =
      MathMax(tick,
              (double)broker_level * point);
   if(buy_side)
      return (sl < entry &&
              entry - sl + tick * 0.1 >= minimum);
   return (sl > entry &&
           sl - entry + tick * 0.1 >= minimum);
  }

bool Strategy137_PositionStopLegal(
   const ENUM_POSITION_TYPE position_type,
   const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy137_TradeTick();
   if(candidate <= 0.0 || point <= 0.0 || tick <= 0.0)
      return false;
   const long broker_level =
      MathMax(SymbolInfoInteger(_Symbol,
                                SYMBOL_TRADE_STOPS_LEVEL),
              SymbolInfoInteger(_Symbol,
                                SYMBOL_TRADE_FREEZE_LEVEL));
   const double minimum =
      MathMax(tick,
              (double)broker_level * point);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 &&
              candidate < bid &&
              bid - candidate + tick * 0.1 >= minimum);
     }
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 &&
           candidate > ask &&
           candidate - ask + tick * 0.1 >= minimum);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy137_HasOwnPosition())
      return false;
   if(!Strategy137_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H4,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) deep-history gate
   return (bars_available < 510 ||
           !Strategy137_HandlesReady());
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy137_CurrentBar(forming_time))
     {
      Strategy137_LogDataMissing("forming_h4_bar", 0);
      return false;
     }
   if(forming_time == g_str137_last_entry_eval_bar)
      return false;
   g_str137_last_entry_eval_bar = forming_time;
   if(!Strategy137_EvaluateLatestSignal(forming_time))
      return false;
   const int direction =
      g_str137_signal_cache_direction;
   const double signal_start =
      g_str137_signal_cache_start;
   const double signal_end =
      g_str137_signal_cache_end;
   if(direction == 0)
      return false;
   if(forming_time ==
      g_str137_signal_reserved_for_exit_bar)
      return false; // an opposite setup used for exit cannot reverse

   ulong position_ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   datetime position_time = 0;
   if(Strategy137_FindOwnPosition(position_ticket,
                                  position_id,
                                  position_type,
                                  open_price,
                                  current_sl,
                                  current_tp,
                                  position_time))
     {
      const int held_direction =
         position_type == POSITION_TYPE_BUY ? 1 : -1;
      if(direction == -held_direction)
         g_str137_opposite_close_pending = true;
      return false; // consumed; never reverse on the same setup
     }

   const double length =
      MathAbs(signal_end - signal_start);
   const bool buy_side = (direction > 0);
   const double entry =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double pip = Strategy137_PipSize();
   const double sl =
      Strategy137_AlignPrice(
         buy_side
         ? signal_start - strategy_sl_buffer_pips * pip
         : signal_start + strategy_sl_buffer_pips * pip,
         buy_side ? -1 : 1);
   if(length <= 0.0 || pip <= 0.0 ||
      !Strategy137_EntryStopLegal(buy_side,
                                  entry,
                                  sl))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-137\",\"reason\":\"impulse_or_stop_geometry\",\"bar_time\":%I64d,\"start\":%.8f,\"end\":%.8f,\"entry\":%.8f,\"sl\":%.8f}",
            (long)forming_time,
            signal_start,
            signal_end,
            entry,
            sl));
      return false;
     }

   g_str137_active_direction = direction;
   g_str137_active_impulse_start = signal_start;
   g_str137_active_impulse_end = signal_end;
   g_str137_fib_step = -1;
   req.type = buy_side ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason =
      buy_side
      ? "STR137_FIRST_HOOK_LONG"
      : "STR137_FIRST_HOOK_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   datetime position_time = 0;
   if(!Strategy137_FindOwnPosition(ticket,
                                   position_id,
                                   position_type,
                                   open_price,
                                   current_sl,
                                   current_tp,
                                   position_time))
     {
      g_str137_position_id = 0;
      g_str137_last_manage_eval_bar = 0;
      g_str137_last_close_attempt_bar = 0;
      g_str137_last_modify_attempt_bar = 0;
      g_str137_opposite_close_pending = false;
      return;
     }

   datetime forming_time = 0;
   if(!Strategy137_CurrentBar(forming_time))
      return;
   if(position_id != g_str137_position_id)
     {
      g_str137_position_id = position_id;
      g_str137_last_manage_eval_bar = 0;
      g_str137_last_close_attempt_bar = 0;
      g_str137_last_modify_attempt_bar = 0;
      g_str137_opposite_close_pending = false;
      const int held_direction =
         position_type == POSITION_TYPE_BUY ? 1 : -1;
      if(g_str137_active_direction != held_direction ||
         g_str137_active_impulse_start <= 0.0 ||
         g_str137_active_impulse_end <= 0.0)
        {
         if(!Strategy137_HandlesReady() ||
            !Strategy137_RecoverPositionState(position_type,
                                              position_time,
                                              forming_time))
           {
            Strategy137_LogDataMissing("position_fib_anchors",
                                       forming_time);
            return; // the hard server stop remains authoritative
           }
        }
     }

   if(Strategy137_EvaluateLatestSignal(forming_time))
     {
      const int held_direction =
         position_type == POSITION_TYPE_BUY ? 1 : -1;
      if(g_str137_signal_cache_direction ==
         -held_direction)
        {
         g_str137_opposite_close_pending = true;
         g_str137_signal_reserved_for_exit_bar =
            forming_time;
        }
     }

   if(g_str137_opposite_close_pending)
     {
      if(forming_time == g_str137_last_close_attempt_bar)
         return;
      g_str137_last_close_attempt_bar = forming_time;
      if(QM_TM_ClosePosition(ticket,
                             QM_EXIT_OPPOSITE_SIGNAL))
         g_str137_opposite_close_pending = false;
      return;
     }
   if(forming_time == g_str137_last_manage_eval_bar)
      return;
   g_str137_last_manage_eval_bar = forming_time;

   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_H4,
                  1,
                  closed_bar)) // perf-allowed: one sanctioned close-qualified ladder record
     {
      Strategy137_LogDataMissing("fib_closed_bar",
                                 forming_time);
      return;
     }
   const datetime closed_bar_end =
      closed_bar.time + PeriodSeconds(PERIOD_H4);
   if(closed_bar_end <= position_time)
      return;

   const int reached =
      Strategy137_FibStepForClose(
         g_str137_active_direction,
         g_str137_active_impulse_start,
         g_str137_active_impulse_end,
         closed_bar.close);
   if(reached > g_str137_fib_step)
      g_str137_fib_step = reached;
   if(g_str137_fib_step < 0)
      return;

   double ratios[10] =
      {1.0, 1.272, 1.618, 2.0, 2.618,
       3.0, 3.618, 4.0, 4.618, 5.0};
   double raw_candidate = open_price; // close beyond F(1) -> BE
   if(g_str137_fib_step >= 1)
     {
      const int prior_index =
         (g_str137_fib_step - 1 > 8)
         ? 8
         : g_str137_fib_step - 1;
      raw_candidate =
         g_str137_active_impulse_start +
         (double)g_str137_active_direction *
         ratios[prior_index] *
         MathAbs(g_str137_active_impulse_end -
                 g_str137_active_impulse_start);
     }
   const bool buy_side =
      (position_type == POSITION_TYPE_BUY);
   const double candidate =QM_TM_NormalizePrice(_Symbol, Strategy137_AlignPrice(raw_candidate,
                             buy_side ? -1 : 1));
   const double tick = Strategy137_TradeTick();
   const bool tightens =
      (candidate > 0.0 && tick > 0.0 &&
       (buy_side
        ? candidate > current_sl + tick * 0.5
        : (current_sl <= 0.0 ||
           candidate < current_sl - tick * 0.5)));
   if(!tightens ||
      forming_time == g_str137_last_modify_attempt_bar ||
      !Strategy137_PositionStopLegal(position_type,
                                     candidate))
      return;
   g_str137_last_modify_attempt_bar = forming_time;
   QM_TM_MoveSL(ticket,
                candidate,
                "STR137_CLOSE_QUALIFIED_FIB_RATCHET");
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(Strategy137_NewsAllows(broker_time))
      return false;
   return !Strategy137_HasOwnPosition();
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
