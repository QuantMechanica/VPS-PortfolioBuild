#property strict
#property version   "5.0"
#property description "QM5_10995 FTMO Bollinger Reversal Reentry"

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
input int    qm_ea_id                   = 10995;
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
input int    strategy_bb_period              = 20;
input double strategy_bb_deviation           = 2.0;
input int    strategy_rsi_period             = 14;
input double strategy_rsi_long_max           = 35.0;
input double strategy_rsi_short_min          = 65.0;
input int    strategy_atr_period             = 14;
input double strategy_sl_atr_buffer_mult     = 0.25;
input double strategy_min_middle_target_r    = 1.0;
input double strategy_fallback_tp_r          = 1.5;
input int    strategy_reentry_window_bars    = 4;
input int    strategy_structure_lookback      = 100;
input int    strategy_bandwidth_lookback      = 250;
input double strategy_bandwidth_skip_percent = 90.0;
input double strategy_max_entry_risk_atr     = 2.0;
input int    strategy_time_exit_bars         = 30;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
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

   if(strategy_bb_period <= 1 || strategy_bb_deviation <= 0.0 ||
      strategy_rsi_period <= 1 || strategy_atr_period <= 0 ||
      strategy_sl_atr_buffer_mult < 0.0 || strategy_min_middle_target_r <= 0.0 ||
      strategy_fallback_tp_r <= 0.0 || strategy_reentry_window_bars <= 0 ||
      strategy_structure_lookback < 2 || strategy_bandwidth_lookback < 10 ||
      strategy_bandwidth_skip_percent <= 0.0 || strategy_bandwidth_skip_percent >= 100.0 ||
      strategy_max_entry_risk_atr <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed-bar read inside framework new-bar hook.
   const double lower1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double middle1 = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double atr1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(close1 <= 0.0 || lower1 <= 0.0 || upper1 <= 0.0 || middle1 <= 0.0 || atr1 <= 0.0)
      return false;

   const double current_width = upper1 - lower1;
   if(current_width <= 0.0)
      return false;

   int wider_or_equal = 0;
   int width_samples = 0;
   for(int shift = 1; shift <= strategy_bandwidth_lookback; ++shift)
     {
      const double upper = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, shift);
      const double lower = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, shift);
      const double width = upper - lower;
      if(width <= 0.0)
         return false;
      if(width >= current_width)
         wider_or_equal++;
      width_samples++;
     }
   if(width_samples < strategy_bandwidth_lookback)
      return false;
   const double width_percentile = 100.0 * (double)(width_samples - wider_or_equal + 1) / (double)width_samples;
   if(width_percentile >= strategy_bandwidth_skip_percent)
      return false;

   double current_100_low = DBL_MAX;
   double prior_100_low = DBL_MAX;
   double current_100_high = -DBL_MAX;
   double prior_100_high = -DBL_MAX;
   for(int shift = 1; shift <= strategy_structure_lookback; ++shift)
     {
      const double low_current = iLow(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded 100-bar structural scan inside framework new-bar hook.
      const double high_current = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded 100-bar structural scan inside framework new-bar hook.
      const double low_prior = iLow(_Symbol, PERIOD_H1, shift + 1); // perf-allowed: bounded 100-bar structural scan inside framework new-bar hook.
      const double high_prior = iHigh(_Symbol, PERIOD_H1, shift + 1); // perf-allowed: bounded 100-bar structural scan inside framework new-bar hook.
      if(low_current <= 0.0 || high_current <= 0.0 || low_prior <= 0.0 || high_prior <= 0.0)
         return false;
      if(low_current < current_100_low)
         current_100_low = low_current;
      if(low_prior < prior_100_low)
         prior_100_low = low_prior;
      if(high_current > current_100_high)
         current_100_high = high_current;
      if(high_prior > prior_100_high)
         prior_100_high = high_prior;
     }

   bool long_setup = false;
   bool short_setup = false;
   int long_setup_shift = -1;
   int short_setup_shift = -1;

   for(int shift = 2; shift <= strategy_reentry_window_bars + 1; ++shift)
     {
      const double setup_close = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded re-entry scan inside framework new-bar hook.
      const double setup_lower = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, shift);
      const double setup_upper = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, shift);
      const double setup_rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift);
      if(setup_close <= 0.0 || setup_lower <= 0.0 || setup_upper <= 0.0 || setup_rsi <= 0.0)
         return false;

      if(!long_setup && setup_close < setup_lower && setup_rsi < strategy_rsi_long_max)
        {
         long_setup = true;
         long_setup_shift = shift;
        }
      if(!short_setup && setup_close > setup_upper && setup_rsi > strategy_rsi_short_min)
        {
         short_setup = true;
         short_setup_shift = shift;
        }
     }

   if(long_setup && close1 >= lower1)
     {
      if(current_100_low < prior_100_low && close1 < prior_100_low)
         return false;

      double setup_low = DBL_MAX;
      for(int shift = 1; shift <= long_setup_shift; ++shift)
        {
         const double low = iLow(_Symbol, PERIOD_H1, shift); // perf-allowed: setup swing low over re-entry window only.
         if(low <= 0.0)
            return false;
         if(low < setup_low)
            setup_low = low;
        }

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, setup_low - strategy_sl_atr_buffer_mult * atr1);
      if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
         return false;

      const double risk = entry - sl;
      if(risk > strategy_max_entry_risk_atr * atr1)
         return false;

      double tp = 0.0;
      if(middle1 > entry && (middle1 - entry) >= strategy_min_middle_target_r * risk)
         tp = QM_StopRulesNormalizePrice(_Symbol, middle1);
      else
         tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_fallback_tp_r);
      if(tp <= entry)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "FTMO_BB_REV_LONG_REENTRY";
      return true;
     }

   if(short_setup && close1 <= upper1)
     {
      if(current_100_high > prior_100_high && close1 > prior_100_high)
         return false;

      double setup_high = -DBL_MAX;
      for(int shift = 1; shift <= short_setup_shift; ++shift)
        {
         const double high = iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: setup swing high over re-entry window only.
         if(high <= 0.0)
            return false;
         if(high > setup_high)
            setup_high = high;
        }

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, setup_high + strategy_sl_atr_buffer_mult * atr1);
      if(entry <= 0.0 || sl <= 0.0 || sl <= entry)
         return false;

      const double risk = sl - entry;
      if(risk > strategy_max_entry_risk_atr * atr1)
         return false;

      double tp = 0.0;
      if(middle1 < entry && (entry - middle1) >= strategy_min_middle_target_r * risk)
         tp = QM_StopRulesNormalizePrice(_Symbol, middle1);
      else
         tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_fallback_tp_r);
      if(tp >= entry || tp <= 0.0)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "FTMO_BB_REV_SHORT_REENTRY";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int hold_seconds = MathMax(1, strategy_time_exit_bars) * PeriodSeconds(PERIOD_H1);
   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed-bar exit read.
   const double lower1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   if(close1 <= 0.0 || lower1 <= 0.0 || upper1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && TimeCurrent() - opened_at >= hold_seconds)
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 < lower1)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 > upper1)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
