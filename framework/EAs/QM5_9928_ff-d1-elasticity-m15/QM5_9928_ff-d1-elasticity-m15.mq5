#property strict
#property version   "5.0"
#property description "QM5_9928 ForexFactory D1 Elasticity Pullback M15"

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
input int    qm_ea_id                   = 9928;
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
input int    strategy_stoch_k_period       = 14;
input int    strategy_stoch_d_period       = 3;
input int    strategy_stoch_slowing        = 3;
input double strategy_elasticity_points    = 35.0;
input double strategy_turn_points          = 8.0;
input double strategy_oversold             = 20.0;
input double strategy_overbought           = 80.0;
input int    strategy_h4_slope_bars        = 3;
input double strategy_h4_flat_low          = 45.0;
input double strategy_h4_flat_high         = 55.0;
input double strategy_h4_flat_slope_points = 3.0;
input int    strategy_swing_lookback       = 20;
input int    strategy_sweep_window         = 8;
input int    strategy_h1_impulse_lookback  = 24;
input double strategy_retrace_min_pct      = 45.0;
input double strategy_retrace_max_pct      = 62.0;
input int    strategy_atr_period           = 14;
input double strategy_sl_atr_buffer        = 0.35;
input double strategy_tp_rr                = 1.5;
input int    strategy_max_hold_bars        = 24;
input double strategy_trail_atr_mult       = 1.0;
input int    strategy_be_buffer_pips       = 0;
input int    strategy_max_spread_points    = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return true;
     }

   const double h4_k_1 = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period,
                                    strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double h4_k_prev = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period,
                                       strategy_stoch_d_period, strategy_stoch_slowing,
                                       1 + strategy_h4_slope_bars);
   const double h4_slope = h4_k_1 - h4_k_prev;
   if(h4_k_1 >= strategy_h4_flat_low &&
      h4_k_1 <= strategy_h4_flat_high &&
      MathAbs(h4_slope) <= strategy_h4_flat_slope_points)
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

   if(strategy_stoch_k_period < 2 ||
      strategy_stoch_d_period < 1 ||
      strategy_stoch_slowing < 1 ||
      strategy_h4_slope_bars < 1 ||
      strategy_swing_lookback < 2 ||
      strategy_sweep_window < 2 ||
      strategy_h1_impulse_lookback < 3 ||
      strategy_atr_period < 1 ||
      strategy_sl_atr_buffer <= 0.0 ||
      strategy_tp_rr <= 0.0)
      return false;

   if(QM_EntryHasOpenPosition(QM_FrameworkMagic(), _Symbol))
      return false;

   const double m15_k_1 = QM_Stoch_K(_Symbol, PERIOD_M15, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double m15_k_2 = QM_Stoch_K(_Symbol, PERIOD_M15, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double m15_k_3 = QM_Stoch_K(_Symbol, PERIOD_M15, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 3);
   const double h4_k_1 = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period,
                                    strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double h4_k_prev = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period,
                                       strategy_stoch_d_period, strategy_stoch_slowing,
                                       1 + strategy_h4_slope_bars);
   const double h4_slope = h4_k_1 - h4_k_prev;

   const bool long_elasticity = (h4_slope > 0.0 &&
                                 (h4_k_1 - m15_k_1) >= strategy_elasticity_points &&
                                 ((m15_k_2 < strategy_oversold && m15_k_1 >= strategy_oversold) ||
                                  ((m15_k_1 - m15_k_3) >= strategy_turn_points)));
   const bool short_elasticity = (h4_slope < 0.0 &&
                                  (m15_k_1 - h4_k_1) >= strategy_elasticity_points &&
                                  ((m15_k_2 > strategy_overbought && m15_k_1 <= strategy_overbought) ||
                                   ((m15_k_3 - m15_k_1) >= strategy_turn_points)));
   if(!long_elasticity && !short_elasticity)
      return false;

   const int m15_need = strategy_swing_lookback + strategy_sweep_window + 3;
   MqlRates m15_rates[];
   ArraySetAsSeries(m15_rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 1, m15_need, m15_rates) < m15_need) // perf-allowed: bounded closed-bar sweep structure, called only from the skeleton new-bar gate
      return false;

   double sweep_low = 0.0;
   double sweep_high = 0.0;
   bool long_sweep = false;
   bool short_sweep = false;

   for(int shift = 2; shift <= strategy_sweep_window; ++shift)
     {
      const int idx = shift - 1;
      double prior_low = DBL_MAX;
      double prior_high = -DBL_MAX;
      for(int j = idx + 1; j <= idx + strategy_swing_lookback; ++j)
        {
         prior_low = MathMin(prior_low, m15_rates[j].low);
         prior_high = MathMax(prior_high, m15_rates[j].high);
        }

      if(!long_sweep &&
         m15_rates[idx].low < prior_low &&
         m15_rates[idx].close > prior_low &&
         m15_rates[0].close > m15_rates[idx].close)
        {
         long_sweep = true;
         sweep_low = m15_rates[idx].low;
        }

      if(!short_sweep &&
         m15_rates[idx].high > prior_high &&
         m15_rates[idx].close < prior_high &&
         m15_rates[0].close < m15_rates[idx].close)
        {
         short_sweep = true;
         sweep_high = m15_rates[idx].high;
        }
     }

   const int h1_need = strategy_h1_impulse_lookback + 1;
   MqlRates h1_rates[];
   ArraySetAsSeries(h1_rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 1, h1_need, h1_rates) < h1_need) // perf-allowed: bounded closed-bar H1 impulse leg scan, called only from the skeleton new-bar gate
      return false;

   double h1_low = DBL_MAX;
   double h1_high = -DBL_MAX;
   int h1_low_idx = -1;
   int h1_high_idx = -1;
   for(int i = 0; i < strategy_h1_impulse_lookback; ++i)
     {
      if(h1_rates[i].low < h1_low)
        {
         h1_low = h1_rates[i].low;
         h1_low_idx = i;
        }
      if(h1_rates[i].high > h1_high)
        {
         h1_high = h1_rates[i].high;
         h1_high_idx = i;
        }
     }

   const double h1_range = h1_high - h1_low;
   const double current_close = m15_rates[0].close;
   bool long_retrace = false;
   bool short_retrace = false;
   double long_retrace_anchor = 0.0;
   double short_retrace_anchor = 0.0;
   if(h1_range > 0.0 && h1_low_idx >= 0 && h1_high_idx >= 0)
     {
      if(h1_low_idx > h1_high_idx)
        {
         const double long_retrace_pct = 100.0 * (h1_high - current_close) / h1_range;
         long_retrace = (long_retrace_pct >= strategy_retrace_min_pct &&
                         long_retrace_pct <= strategy_retrace_max_pct);
         long_retrace_anchor = h1_high - (strategy_retrace_max_pct / 100.0) * h1_range;
        }
      if(h1_high_idx > h1_low_idx)
        {
         const double short_retrace_pct = 100.0 * (current_close - h1_low) / h1_range;
         short_retrace = (short_retrace_pct >= strategy_retrace_min_pct &&
                          short_retrace_pct <= strategy_retrace_max_pct);
         short_retrace_anchor = h1_low + (strategy_retrace_max_pct / 100.0) * h1_range;
        }
     }

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double buffer = strategy_sl_atr_buffer * atr;

   if(long_elasticity && (long_sweep || long_retrace))
     {
      const double anchor = long_sweep ? sweep_low : long_retrace_anchor;
      const double sl = NormalizeDouble(anchor - buffer, _Digits);
      if(ask <= 0.0 || sl <= 0.0 || ask <= sl)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = long_sweep ? "D1_ELASTICITY_LONG_SWEEP" : "D1_ELASTICITY_LONG_RETRACE";
      return true;
     }

   if(short_elasticity && (short_sweep || short_retrace))
     {
      const double anchor = short_sweep ? sweep_high : short_retrace_anchor;
      const double sl = NormalizeDouble(anchor + buffer, _Digits);
      if(bid <= 0.0 || sl <= bid)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = short_sweep ? "D1_ELASTICITY_SHORT_SWEEP" : "D1_ELASTICITY_SHORT_RETRACE";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   if(magic <= 0 || point <= 0.0 || pip_factor <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double risk_distance = MathAbs(open_price - current_sl);
      if(risk_distance <= 0.0)
         continue;

      const double current_price = (ptype == POSITION_TYPE_BUY)
                                   ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const bool reached_one_r = (ptype == POSITION_TYPE_BUY)
                                 ? ((current_price - open_price) >= risk_distance)
                                 : ((open_price - current_price) >= risk_distance);
      if(!reached_one_r)
         continue;

      const int trigger_pips = (int)MathCeil(risk_distance / (point * pip_factor));
      QM_TM_MoveToBreakEven(ticket, trigger_pips, strategy_be_buffer_pips);
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double k1 = QM_Stoch_K(_Symbol, PERIOD_M15, strategy_stoch_k_period,
                                strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const int hold_seconds_limit = strategy_max_hold_bars * PeriodSeconds(PERIOD_M15);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && k1 >= strategy_overbought)
         return true;
      if(ptype == POSITION_TYPE_SELL && k1 <= strategy_oversold)
         return true;

      if(hold_seconds_limit > 0)
        {
         const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened_at > 0 && (TimeCurrent() - opened_at) >= hold_seconds_limit)
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
