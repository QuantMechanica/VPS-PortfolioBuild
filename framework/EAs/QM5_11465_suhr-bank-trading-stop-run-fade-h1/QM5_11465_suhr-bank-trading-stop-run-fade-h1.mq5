#property strict
#property version   "5.0"
#property description "QM5_11465 Suhr Bank Trading Stop Run Fade H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_11465 — Suhr Bank Trading Stop Run Fade (H1)
// -----------------------------------------------------------------------------
// Source: Sterling Suhr, "Bank Trading Stop Run Fade", in TradingPub's
// "6 Simple Strategies for Trading Forex" (~2015).
//
// Structural mechanic:
//   1. Prefer the previous completed D1 high/low; otherwise use the rolling
//      20-bar H1 high/low ending at shift 2.
//   2. Record a closed H1 bar that runs at least three pips beyond a level.
//   3. Require a later closed H1 bar to finish back inside that level.
//   4. During the five-bar sequence, enter only when market price is within
//      15 pips of the level.
//   5. Place the stop one pip beyond the recorded stop-run extreme and target
//      the nearest valid prior-D1/recent-10-bar opposite extreme.
//
// The state transition and bounded raw OHLC reads run only after the framework
// consumes QM_IsNewBar(). No indicators, ML, adaptive thresholds, or bespoke
// position sizing are used. The central framework supplies fixed-risk sizing,
// magic resolution, news controls, Friday close, and kill-switch handling.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11465;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

enum StrategyLevelMode
  {
   LEVEL_PRIOR_DAY_ONLY = 0,
   LEVEL_SWING_ONLY = 1,
   LEVEL_PRIOR_DAY_THEN_SWING = 2
  };

input group "Strategy"
input StrategyLevelMode strategy_level_mode           = LEVEL_PRIOR_DAY_THEN_SWING;
input int               strategy_swing_lookback_bars  = 20;
input int               strategy_target_lookback_bars = 10;
input int               strategy_stop_run_pips        = 3;
input int               strategy_pullback_window_pips = 15;
input int               strategy_max_sequence_bars    = 5;
input int               strategy_sl_buffer_pips       = 1;
input int               strategy_max_stop_pips        = 60;
input int               strategy_max_spread_pips      = 20;

enum StrategySetupState
  {
   SETUP_IDLE = 0,
   SETUP_STOP_RUN_SEEN = 1,
   SETUP_CONFIRMED = 2
  };

StrategySetupState g_setup_state = SETUP_IDLE;
int                 g_setup_direction = 0; // +1 long, -1 short
double              g_setup_level = 0.0;
double              g_setup_extreme = 0.0;
int                 g_setup_age_bars = 0;

void Strategy_ResetSetup()
  {
   g_setup_state = SETUP_IDLE;
   g_setup_direction = 0;
   g_setup_level = 0.0;
   g_setup_extreme = 0.0;
   g_setup_age_bars = 0;
  }

void Strategy_StartSetup(const int direction,
                         const double level,
                         const double extreme)
  {
   g_setup_state = SETUP_STOP_RUN_SEEN;
   g_setup_direction = direction;
   g_setup_level = level;
   g_setup_extreme = extreme;
   g_setup_age_bars = 0;
  }

bool Strategy_ReadSwingLevels(double &swing_high, double &swing_low)
  {
   swing_high = 0.0;
   swing_low = 0.0;

   if(strategy_swing_lookback_bars < 1)
      return false;

   for(int shift = 2; shift < 2 + strategy_swing_lookback_bars; ++shift)
     {
      const double bar_high = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded structural H1 read after new-bar gate
      const double bar_low  = iLow(_Symbol, PERIOD_H1, shift);  // perf-allowed: bounded structural H1 read after new-bar gate
      if(bar_high <= 0.0 || bar_low <= 0.0)
         return false;

      if(swing_high <= 0.0 || bar_high > swing_high)
         swing_high = bar_high;
      if(swing_low <= 0.0 || bar_low < swing_low)
         swing_low = bar_low;
     }

   return (swing_high > 0.0 && swing_low > 0.0 && swing_high > swing_low);
  }

bool Strategy_DetectStopRun()
  {
   const double threshold = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_run_pips);
   if(threshold <= 0.0)
      return false;

   const double bar_high = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: latest closed H1 bar, called after new-bar gate
   const double bar_low  = iLow(_Symbol, PERIOD_H1, 1);  // perf-allowed: latest closed H1 bar, called after new-bar gate
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high <= bar_low)
      return false;

   const bool use_prior = (strategy_level_mode == LEVEL_PRIOR_DAY_ONLY ||
                           strategy_level_mode == LEVEL_PRIOR_DAY_THEN_SWING);
   const bool use_swing = (strategy_level_mode == LEVEL_SWING_ONLY ||
                           strategy_level_mode == LEVEL_PRIOR_DAY_THEN_SWING);

   if(use_prior)
     {
      const double prior_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: one completed D1 structural level
      const double prior_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed: one completed D1 structural level
      if(prior_high > 0.0 && prior_low > 0.0 && prior_high > prior_low)
        {
         const bool long_run  = (bar_low < prior_low - threshold);
         const bool short_run = (bar_high > prior_high + threshold);

         // A single outside bar that sweeps both previous-day extremes has no
         // unambiguous fade direction, so it is deliberately skipped.
         if(long_run && short_run)
            return false;
         if(long_run)
           {
            Strategy_StartSetup(+1, prior_low, bar_low);
            return true;
           }
         if(short_run)
           {
            Strategy_StartSetup(-1, prior_high, bar_high);
            return true;
           }
        }
     }

   if(use_swing)
     {
      double swing_high = 0.0;
      double swing_low = 0.0;
      if(!Strategy_ReadSwingLevels(swing_high, swing_low))
         return false;

      const bool long_run  = (bar_low < swing_low - threshold);
      const bool short_run = (bar_high > swing_high + threshold);
      if(long_run && short_run)
         return false;
      if(long_run)
        {
         Strategy_StartSetup(+1, swing_low, bar_low);
         return true;
        }
      if(short_run)
        {
         Strategy_StartSetup(-1, swing_high, bar_high);
         return true;
        }
     }

   return false;
  }

bool Strategy_ReadTarget(const int direction,
                         const double entry,
                         double &target)
  {
   target = 0.0;
   if(strategy_target_lookback_bars < 1)
      return false;

   double recent_high = 0.0;
   double recent_low = 0.0;
   for(int shift = 1; shift <= strategy_target_lookback_bars; ++shift)
     {
      const double bar_high = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded structural target scan after new-bar gate
      const double bar_low  = iLow(_Symbol, PERIOD_H1, shift);  // perf-allowed: bounded structural target scan after new-bar gate
      if(bar_high <= 0.0 || bar_low <= 0.0)
         return false;

      if(recent_high <= 0.0 || bar_high > recent_high)
         recent_high = bar_high;
      if(recent_low <= 0.0 || bar_low < recent_low)
         recent_low = bar_low;
     }

   const double prior_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 target candidate
   const double prior_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed: completed D1 target candidate

   if(direction > 0)
     {
      if(recent_high > entry)
         target = recent_high;
      if(prior_high > entry && (target <= 0.0 || prior_high < target))
         target = prior_high;
     }
   else
     {
      if(recent_low > 0.0 && recent_low < entry)
         target = recent_low;
      if(prior_low > 0.0 && prior_low < entry && (target <= 0.0 || prior_low > target))
         target = prior_low;
     }

   return (target > 0.0);
  }

bool Strategy_BuildConfirmedEntry(QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double spread = ask - bid;
   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   const double pullback_window = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_pullback_window_pips);
   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double max_stop = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_stop_pips);
   if(max_spread <= 0.0 || pullback_window <= 0.0 || sl_buffer <= 0.0 || max_stop <= 0.0)
      return false;
   if(spread > max_spread)
      return false;

   const double entry = (g_setup_direction > 0) ? ask : bid;
   if(MathAbs(entry - g_setup_level) > pullback_window)
      return false;

   double sl = (g_setup_direction > 0)
               ? g_setup_extreme - sl_buffer
               : g_setup_extreme + sl_buffer;
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   const double stop_distance = (g_setup_direction > 0)
                                ? entry - sl
                                : sl - entry;
   if(stop_distance <= 0.0 || stop_distance > max_stop)
      return false;
   if(spread >= stop_distance)
      return false;

   double tp = 0.0;
   if(!Strategy_ReadTarget(g_setup_direction, entry, tp))
      return false;
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   if((g_setup_direction > 0 && tp <= entry) ||
      (g_setup_direction < 0 && tp >= entry))
      return false;

   req.type = (g_setup_direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (g_setup_direction > 0)
                ? "stop_run_fade_long"
                : "stop_run_fade_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_ResetSetup();
   return true;
  }

bool Strategy_AdvanceSetup(QM_EntryRequest &req)
  {
   if(g_setup_state == SETUP_IDLE)
      return false;

   ++g_setup_age_bars;
   if(strategy_max_sequence_bars < 1 ||
      g_setup_age_bars > strategy_max_sequence_bars)
     {
      Strategy_ResetSetup();
      return false;
     }

   const double closed_bar_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: confirmation read after new-bar gate
   if(closed_bar_close <= 0.0)
      return false;

   if(g_setup_state == SETUP_STOP_RUN_SEEN)
     {
      const bool confirmed = (g_setup_direction > 0)
                             ? (closed_bar_close > g_setup_level)
                             : (closed_bar_close < g_setup_level);
      if(!confirmed)
         return false;
      g_setup_state = SETUP_CONFIRMED;
     }

   return Strategy_BuildConfirmedEntry(req);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(_Period != PERIOD_H1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
     {
      Strategy_ResetSetup();
      return false;
     }

   if(g_setup_state != SETUP_IDLE)
     {
      if(Strategy_AdvanceSetup(req))
         return true;
      if(g_setup_state != SETUP_IDLE)
         return false;
     }

   Strategy_DetectStopRun();
   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — canonical V5 skeleton.
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
