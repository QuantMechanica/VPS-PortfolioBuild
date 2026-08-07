#property strict
#property version   "5.0"
#property description "QM5_20152 sma-cross-pullback-h1 (V5)"

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
input int    strategy_sma_fast          = 100;
input int    strategy_sma_slow          = 200;
input int    strategy_stoch_k           = 14;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_os_level          = 25.0;
input double strategy_ob_level          = 75.0;
input double strategy_sl_pips           = 150.0;
input double strategy_tp_pips           = 300.0;
input double strategy_be_trigger_pips   = 150.0;

enum Strategy143ArmState
  {
   STR143_IDLE = 0,
   STR143_ARMED_LONG = 1,
   STR143_ARMED_SHORT = 2
  };

Strategy143ArmState g_str143_arm = STR143_IDLE;
datetime g_str143_arm_bar = 0;
datetime g_str143_last_entry_eval_bar = 0;
datetime g_str143_last_manage_eval_bar = 0;
datetime g_str143_last_fill_attempt_bar = 0;
datetime g_str143_last_be_attempt_bar = 0;
datetime g_str143_last_close_attempt_bar = 0;
datetime g_str143_last_data_log_bar = 0;
datetime g_str143_last_filter_log_bar = 0;
ulong    g_str143_position_id = 0;
bool     g_str143_episode_reconstructed = false;
bool     g_str143_fill_protection_exact = false;
bool     g_str143_be_latched = false;
bool     g_str143_be_done = false;
bool     g_str143_first_entry_eval_logged = false;

bool Strategy143_ConfigValid()
  {
   return (_Symbol == "EURUSD.DWX" &&
           _Period == PERIOD_H1 &&
           qm_magic_slot_offset == 0 &&
           strategy_sma_fast == 100 &&
           strategy_sma_slow == 200 &&
           strategy_stoch_k == 14 &&
           strategy_stoch_d == 3 &&
           strategy_stoch_slowing == 3 &&
           MathAbs(strategy_os_level - 25.0) < 1e-9 &&
           MathAbs(strategy_ob_level - 75.0) < 1e-9 &&
           MathAbs(strategy_sl_pips - 150.0) < 1e-9 &&
           MathAbs(strategy_tp_pips - 300.0) < 1e-9 &&
           MathAbs(strategy_be_trigger_pips - 150.0) < 1e-9);
  }

bool Strategy143_CurrentBar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) forming-H1 cadence
   return (bar_time > 0);
  }

void Strategy143_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str143_last_data_log_bar)
      return;
   g_str143_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-143\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

void Strategy143_LogEntryBlockOnce(const string reason,
                                   const long bars_available)
  {
   datetime forming_time = 0;
   if(!Strategy143_CurrentBar(forming_time) ||
      forming_time == g_str143_last_filter_log_bar)
      return;
   g_str143_last_filter_log_bar = forming_time;
   QM_LogEvent(
      QM_WARN,
      "ENTRY_BLOCK",
      StringFormat(
         "{\"strategy\":\"STR-143\",\"reason\":\"%s\",\"forming_time\":%I64d,\"bars_available\":%I64d}",
         QM_LoggerEscapeJson(reason),
         (long)forming_time,
         bars_available));
  }

bool Strategy143_IndicatorValid(const double value)
  {
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE &&
           value >= 0.0);
  }

double Strategy143_TradeTick()
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

double Strategy143_PipSize()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

double Strategy143_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy143_TradeTick();
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

bool Strategy143_NewsAllows(const datetime broker_time)
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

bool Strategy143_FindOwnPosition(
   ulong &ticket,
   ulong &position_id,
   ENUM_POSITION_TYPE &position_type,
   double &open_price,
   double &current_sl,
   double &current_tp)
  {
   ticket = 0;
   position_id = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   current_tp = 0.0;
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
      return true;
     }
   return false;
  }

bool Strategy143_HasOwnPosition()
  {
   ulong ticket = 0;
   ulong position_id = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_tp = 0.0;
   return Strategy143_FindOwnPosition(ticket,
                                      position_id,
                                      position_type,
                                      open_price,
                                      current_sl,
                                      current_tp);
  }

bool Strategy143_HandlesReady()
  {
   const int fast =
      QM_IndMA(_Symbol,
               PERIOD_H1,
               strategy_sma_fast,
               MODE_SMA,
               PRICE_CLOSE);
   const int slow =
      QM_IndMA(_Symbol,
               PERIOD_H1,
               strategy_sma_slow,
               MODE_SMA,
               PRICE_CLOSE);
   const int stoch =
      QM_IndStoch(_Symbol,
                  PERIOD_H1,
                  strategy_stoch_k,
                  strategy_stoch_d,
                  strategy_stoch_slowing);
   return (fast != INVALID_HANDLE &&
           slow != INVALID_HANDLE &&
           stoch != INVALID_HANDLE &&
           BarsCalculated(fast) >= 202 &&
           BarsCalculated(slow) >= 202 &&
           BarsCalculated(stoch) >= 202);
  }

bool Strategy143_ReadEpisodeBar(
   const int shift,
   double &fast_now,
   double &slow_now,
   double &fast_prev,
   double &slow_prev,
   double &k_now,
   double &k_prev,
   MqlRates &bar)
  {
   if(shift < 1)
      return false;
   fast_now =
      QM_SMA(_Symbol,
             PERIOD_H1,
             strategy_sma_fast,
             shift,
             PRICE_CLOSE);
   slow_now =
      QM_SMA(_Symbol,
             PERIOD_H1,
             strategy_sma_slow,
             shift,
             PRICE_CLOSE);
   fast_prev =
      QM_SMA(_Symbol,
             PERIOD_H1,
             strategy_sma_fast,
             shift + 1,
             PRICE_CLOSE);
   slow_prev =
      QM_SMA(_Symbol,
             PERIOD_H1,
             strategy_sma_slow,
             shift + 1,
             PRICE_CLOSE);
   // The final spec requires the pooled LOWHIGH K reader; D is not a trigger.
   k_now =
      QM_Stoch_K(_Symbol,
                 PERIOD_H1,
                 strategy_stoch_k,
                 strategy_stoch_d,
                 strategy_stoch_slowing,
                 shift);
   k_prev =
      QM_Stoch_K(_Symbol,
                 PERIOD_H1,
                 strategy_stoch_k,
                 strategy_stoch_d,
                 strategy_stoch_slowing,
                 shift + 1);
   return (Strategy143_IndicatorValid(fast_now) &&
           Strategy143_IndicatorValid(slow_now) &&
           Strategy143_IndicatorValid(fast_prev) &&
           Strategy143_IndicatorValid(slow_prev) &&
           Strategy143_IndicatorValid(k_now) &&
           Strategy143_IndicatorValid(k_prev) &&
           QM_ReadBar(_Symbol,
                      PERIOD_H1,
                      shift,
                      bar)); // perf-allowed: one sanctioned closed-H1 record
  }

int Strategy143_ApplyEpisodeBar(const double fast_now,
                                const double slow_now,
                                const double fast_prev,
                                const double slow_prev,
                                const double k_now,
                                const double k_prev,
                                const datetime bar_time,
                                const bool emit_diagnostics)
  {
   const bool bull_cross =
      (fast_now > slow_now &&
       fast_prev <= slow_prev);
   const bool bear_cross =
      (fast_now < slow_now &&
       fast_prev >= slow_prev);
   if(bull_cross)
     {
      g_str143_arm = STR143_ARMED_LONG;
      g_str143_arm_bar = bar_time;
      if(emit_diagnostics)
         QM_LogEvent(
            QM_INFO,
            "ENTRY_CANDIDATE_READY",
            StringFormat(
               "{\"strategy\":\"STR-143\",\"stage\":\"arm\",\"side\":\"BUY\",\"bar_time\":%I64d,\"sma_fast\":%.8f,\"sma_slow\":%.8f,\"stoch_k\":%.6f}",
               (long)bar_time,
               fast_now,
               slow_now,
               k_now));
      return 0; // same-bar stochastic movement is ineligible
     }
   if(bear_cross)
     {
      g_str143_arm = STR143_ARMED_SHORT;
      g_str143_arm_bar = bar_time;
      if(emit_diagnostics)
         QM_LogEvent(
            QM_INFO,
            "ENTRY_CANDIDATE_READY",
            StringFormat(
               "{\"strategy\":\"STR-143\",\"stage\":\"arm\",\"side\":\"SELL\",\"bar_time\":%I64d,\"sma_fast\":%.8f,\"sma_slow\":%.8f,\"stoch_k\":%.6f}",
               (long)bar_time,
               fast_now,
               slow_now,
               k_now));
      return 0;
     }

   if(g_str143_arm == STR143_ARMED_LONG)
     {
      if(fast_now <= slow_now)
        {
         g_str143_arm = STR143_IDLE;
         g_str143_arm_bar = 0;
         return 0;
        }
      if(bar_time > g_str143_arm_bar &&
         k_prev <= strategy_os_level &&
         k_now > strategy_os_level)
         {
          g_str143_arm = STR143_IDLE; // first trigger consumes the episode
          g_str143_arm_bar = 0;
          if(emit_diagnostics)
             QM_LogEvent(
                QM_INFO,
                "ENTRY_SIGNAL_FIRE",
                StringFormat(
                   "{\"strategy\":\"STR-143\",\"side\":\"BUY\",\"bar_time\":%I64d,\"sma_fast\":%.8f,\"sma_slow\":%.8f,\"stoch_k_prev\":%.6f,\"stoch_k\":%.6f}",
                   (long)bar_time,
                   fast_now,
                   slow_now,
                   k_prev,
                   k_now));
          return 1;
         }
     }
   else if(g_str143_arm == STR143_ARMED_SHORT)
     {
      if(fast_now >= slow_now)
        {
         g_str143_arm = STR143_IDLE;
         g_str143_arm_bar = 0;
         return 0;
        }
      if(bar_time > g_str143_arm_bar &&
         k_prev >= strategy_ob_level &&
         k_now < strategy_ob_level)
         {
          g_str143_arm = STR143_IDLE;
          g_str143_arm_bar = 0;
          if(emit_diagnostics)
             QM_LogEvent(
                QM_INFO,
                "ENTRY_SIGNAL_FIRE",
                StringFormat(
                   "{\"strategy\":\"STR-143\",\"side\":\"SELL\",\"bar_time\":%I64d,\"sma_fast\":%.8f,\"sma_slow\":%.8f,\"stoch_k_prev\":%.6f,\"stoch_k\":%.6f}",
                   (long)bar_time,
                   fast_now,
                   slow_now,
                   k_prev,
                   k_now));
          return -1;
         }
     }
   return 0;
  }

bool Strategy143_ReconstructEpisode(const datetime forming_time)
  {
   g_str143_arm = STR143_IDLE;
   g_str143_arm_bar = 0;
   const long available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H1,
                        SERIES_BARS_COUNT); // perf-allowed: bounded restart reconstruction
   int lookback = (int)MathMin((double)available - 2.0,
                               500.0);
   if(lookback < 202)
      return false;

   // Reconstruct only through bar 2. Bar 1 remains eligible for this call,
   // while every earlier trigger is consumed exactly once in its episode.
   for(int shift = lookback - 1; shift >= 2; --shift)
     {
      double fast_now = 0.0;
      double slow_now = 0.0;
      double fast_prev = 0.0;
      double slow_prev = 0.0;
      double k_now = 0.0;
      double k_prev = 0.0;
      MqlRates bar;
      if(!Strategy143_ReadEpisodeBar(shift,
                                     fast_now,
                                     slow_now,
                                     fast_prev,
                                     slow_prev,
                                     k_now,
                                     k_prev,
                                     bar))
        {
         Strategy143_LogDataMissing("episode_reconstruction",
                                    forming_time);
         return false;
        }
       Strategy143_ApplyEpisodeBar(fast_now,
                                   slow_now,
                                   fast_prev,
                                   slow_prev,
                                   k_now,
                                   k_prev,
                                   bar.time,
                                   false);
      }
   g_str143_episode_reconstructed = true;
   if(g_str143_arm != STR143_IDLE)
      QM_LogEvent(
         QM_INFO,
         "ENTRY_CANDIDATE_READY",
         StringFormat(
            "{\"strategy\":\"STR-143\",\"stage\":\"restart_reconstruction\",\"side\":\"%s\",\"arm_bar\":%I64d,\"forming_time\":%I64d,\"lookback\":%d}",
            g_str143_arm == STR143_ARMED_LONG ? "BUY" : "SELL",
            (long)g_str143_arm_bar,
            (long)forming_time,
            lookback));
   return true;
  }

bool Strategy143_EntryGeometryLegal(const bool buy_side,
                                    const double entry,
                                    const double sl,
                                    const double tp)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy143_TradeTick();
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 ||
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
      return (sl < entry && tp > entry &&
              entry - sl + tick * 0.1 >= minimum &&
              tp - entry + tick * 0.1 >= minimum);
   return (sl > entry && tp < entry &&
           sl - entry + tick * 0.1 >= minimum &&
           entry - tp + tick * 0.1 >= minimum);
  }

bool Strategy143_PositionStopLegal(
   const ENUM_POSITION_TYPE position_type,
   const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy143_TradeTick();
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
   if(Strategy143_HasOwnPosition())
      return false;
   if(!Strategy143_ConfigValid())
     {
      Strategy143_LogEntryBlockOnce("config_invalid", -1);
      return true;
     }
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
     {
      Strategy143_LogEntryBlockOnce("symbol_trade_disabled", -1);
      return true;
     }
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) warmup gate
   if(bars_available < 202)
     {
      Strategy143_LogEntryBlockOnce("bars_unready", bars_available);
      return true;
     }
   if(!Strategy143_HandlesReady())
     {
      Strategy143_LogEntryBlockOnce("indicator_handles_unready", bars_available);
      return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy143_CurrentBar(forming_time))
     {
      Strategy143_LogDataMissing("forming_h1_bar", 0);
      return false;
     }
   if(forming_time == g_str143_last_entry_eval_bar)
      return false;
   g_str143_last_entry_eval_bar = forming_time;

   if(!g_str143_first_entry_eval_logged)
     {
      g_str143_first_entry_eval_logged = true;
      QM_LogEvent(
         QM_INFO,
         "ENTRY_EVAL",
         StringFormat(
            "{\"strategy\":\"STR-143\",\"forming_time\":%I64d,\"episode_reconstructed\":%s,\"arm_state\":%d}",
            (long)forming_time,
            g_str143_episode_reconstructed ? "true" : "false",
            (int)g_str143_arm));
     }

   if(!Strategy143_ConfigValid() ||
      !Strategy143_HandlesReady())
      return false;
   if(!g_str143_episode_reconstructed &&
      !Strategy143_ReconstructEpisode(forming_time))
      return false;

   double fast_now = 0.0;
   double slow_now = 0.0;
   double fast_prev = 0.0;
   double slow_prev = 0.0;
   double k_now = 0.0;
   double k_prev = 0.0;
   MqlRates signal_bar;
   if(!Strategy143_ReadEpisodeBar(1,
                                  fast_now,
                                  slow_now,
                                  fast_prev,
                                  slow_prev,
                                  k_now,
                                  k_prev,
                                  signal_bar))
     {
      Strategy143_LogDataMissing("closed_h1_inputs",
                                 forming_time);
      return false;
     }

   const int direction =
      Strategy143_ApplyEpisodeBar(fast_now,
                                  slow_now,
                                  fast_prev,
                                  slow_prev,
                                  k_now,
                                  k_prev,
                                  signal_bar.time,
                                  true);
   if(direction == 0 ||
      Strategy143_HasOwnPosition())
      return false;

   const bool buy_side = (direction > 0);
   const double entry =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double pip = Strategy143_PipSize();
   if(entry <= 0.0 || pip <= 0.0)
      return false;
   const double sl =
      Strategy143_AlignPrice(
         buy_side
         ? entry - strategy_sl_pips * pip
         : entry + strategy_sl_pips * pip,
         buy_side ? -1 : 1);
   const double tp =
      Strategy143_AlignPrice(
         buy_side
         ? entry + strategy_tp_pips * pip
         : entry - strategy_tp_pips * pip,
         buy_side ? 1 : -1);
   if(!Strategy143_EntryGeometryLegal(buy_side,
                                      entry,
                                      sl,
                                      tp))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-143\",\"reason\":\"entry_geometry\",\"bar_time\":%I64d,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f}",
            (long)signal_bar.time,
            entry,
            sl,
            tp));
      return false;
     }

   req.type = buy_side ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason =
      buy_side
      ? "STR143_FIRST_PULLBACK_LONG"
      : "STR143_FIRST_PULLBACK_SHORT";
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
   if(!Strategy143_FindOwnPosition(ticket,
                                   position_id,
                                   position_type,
                                   open_price,
                                   current_sl,
                                   current_tp))
     {
      g_str143_position_id = 0;
      g_str143_fill_protection_exact = false;
      g_str143_be_latched = false;
      g_str143_be_done = false;
      g_str143_last_fill_attempt_bar = 0;
      g_str143_last_be_attempt_bar = 0;
      g_str143_last_close_attempt_bar = 0;
      return;
     }

   datetime forming_time = 0;
   if(!Strategy143_CurrentBar(forming_time))
      return;
   if(position_id != g_str143_position_id)
     {
      g_str143_position_id = position_id;
      g_str143_fill_protection_exact = false;
      g_str143_be_latched = false;
      g_str143_be_done = false;
      g_str143_last_fill_attempt_bar = 0;
      g_str143_last_be_attempt_bar = 0;
      g_str143_last_close_attempt_bar = 0;
      g_str143_last_manage_eval_bar = 0;
     }

   const bool buy_side =
      (position_type == POSITION_TYPE_BUY);
   const double pip = Strategy143_PipSize();
   const double tick = Strategy143_TradeTick();
   if(open_price <= 0.0 || pip <= 0.0 || tick <= 0.0)
      return;
   const double desired_sl =
      Strategy143_AlignPrice(
         buy_side
         ? open_price - strategy_sl_pips * pip
         : open_price + strategy_sl_pips * pip,
         buy_side ? -1 : 1);
   const double desired_tp =
      Strategy143_AlignPrice(
         buy_side
         ? open_price + strategy_tp_pips * pip
         : open_price - strategy_tp_pips * pip,
         buy_side ? 1 : -1);

   const bool stop_at_be_or_tighter =
      (current_sl > 0.0 &&
       (buy_side
        ? current_sl >= open_price - tick * 0.5
        : current_sl <= open_price + tick * 0.5));
   if(stop_at_be_or_tighter)
     {
      // Restart-safe: never mistake an already-confirmed BE stop for an
      // initial-stop mismatch and never widen it back to the 150-pip level.
      g_str143_fill_protection_exact = true;
      g_str143_be_latched = true;
      g_str143_be_done = true;
      if(MathAbs(current_tp - desired_tp) > tick * 0.5 &&
         forming_time != g_str143_last_fill_attempt_bar)
        {
         g_str143_last_fill_attempt_bar = forming_time;
         QM_TM_MoveTP(ticket,
                      desired_tp,
                      "STR143_EXACT_FILL_300PIP_TP");
        }
     }

   if(!g_str143_fill_protection_exact)
     {
      const bool exact =
         (MathAbs(current_sl - desired_sl) <= tick * 0.5 &&
          MathAbs(current_tp - desired_tp) <= tick * 0.5);
      if(exact)
         g_str143_fill_protection_exact = true;
      else
        {
         const bool would_widen =
            (current_sl > 0.0 &&
             (buy_side
              ? desired_sl < current_sl - tick * 0.5
              : desired_sl > current_sl + tick * 0.5));
         if(would_widen)
           {
            // Exact fill-relative protection cannot be restored by loosening.
            // Fail closed instead; a rejected close is retried next H1 bar.
            if(forming_time != g_str143_last_close_attempt_bar)
              {
               g_str143_last_close_attempt_bar = forming_time;
               QM_TM_ClosePosition(ticket,
                                   QM_EXIT_STRATEGY);
              }
            return;
           }
         if(forming_time == g_str143_last_fill_attempt_bar ||
            !Strategy143_EntryGeometryLegal(buy_side,
                                            open_price,
                                            desired_sl,
                                            desired_tp))
            return;
         g_str143_last_fill_attempt_bar = forming_time;
         if(QM_TM_SendSLTPModify(ticket,
                                desired_sl,
                                desired_tp,
                                "STR143_EXACT_FILL_150_300"))
            g_str143_fill_protection_exact = true;
         return;
        }
     }

   if(forming_time != g_str143_last_manage_eval_bar)
     {
      g_str143_last_manage_eval_bar = forming_time;
      MqlRates closed_bar;
      if(!QM_ReadBar(_Symbol,
                     PERIOD_H1,
                     1,
                     closed_bar)) // perf-allowed: one sanctioned closed-H1 BE record
        {
         Strategy143_LogDataMissing("be_closed_bar",
                                    forming_time);
         return;
        }
      const datetime position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(closed_bar.time + PeriodSeconds(PERIOD_H1) <=
         position_time)
         return; // the signal bar closed before the actual fill
      if((buy_side &&
          closed_bar.high + tick * 0.1 >=
             open_price + strategy_be_trigger_pips * pip) ||
         (!buy_side &&
          closed_bar.low - tick * 0.1 <=
             open_price - strategy_be_trigger_pips * pip))
         g_str143_be_latched = true;
     }

   if(!g_str143_be_latched || g_str143_be_done)
      return;
   const double be =
      Strategy143_AlignPrice(open_price,
                             buy_side ? -1 : 1);
   const bool already_done =
      (buy_side
       ? current_sl >= be - tick * 0.5
       : (current_sl > 0.0 &&
          current_sl <= be + tick * 0.5));
   if(already_done)
     {
      g_str143_be_done = true;
      return;
     }
   const bool tightens =
      (buy_side
       ? be > current_sl + tick * 0.5
       : (current_sl <= 0.0 ||
          be < current_sl - tick * 0.5));
   if(!tightens ||
      forming_time == g_str143_last_be_attempt_bar ||
      !Strategy143_PositionStopLegal(position_type, be))
      return;
   g_str143_last_be_attempt_bar = forming_time;
   if(QM_TM_MoveSL(ticket,
                   be,
                   "STR143_CLOSED_BAR_150PIP_BE"))
      g_str143_be_done = true;
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(Strategy143_NewsAllows(broker_time))
      return false;
   return !Strategy143_HasOwnPosition();
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
