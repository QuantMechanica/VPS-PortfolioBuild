#property strict
#property version   "5.0"
#property description "QM5_10940 Grimes Nested Pullback"

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
input int    qm_ea_id                   = 10940;
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
input int    strategy_d1_fast_ema                  = 20;
input int    strategy_d1_slow_ema                  = 50;
input int    strategy_d1_pullback_bars             = 12;
input int    strategy_d1_impulse_bars              = 24;
input double strategy_pullback_min_fraction        = 0.25;
input double strategy_pullback_max_fraction        = 0.55;
input int    strategy_h4_atr_period                = 20;
input int    strategy_h4_pause_min_bars            = 3;
input int    strategy_h4_pause_max_bars            = 8;
input double strategy_pause_range_atr_mult         = 1.25;
input double strategy_stop_atr_mult                = 0.35;
input double strategy_max_stop_atr_mult            = 2.5;
input double strategy_target_r                     = 2.0;
input double strategy_breakeven_trigger_r          = 1.0;
input int    strategy_time_exit_bars               = 20;
input int    strategy_d1_atr_percentile_lookback   = 120;
input double strategy_d1_atr_min_percentile        = 20.0;
input double strategy_spread_stop_max_fraction     = 0.08;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no time-of-day filter. News and Friday close are framework gates;
   // setup-specific spread <= 8% of stop distance is enforced in EntrySignal.
   if(strategy_h4_pause_min_bars < 3 || strategy_h4_pause_max_bars > 8 ||
      strategy_h4_pause_min_bars > strategy_h4_pause_max_bars)
      return true;

   if(strategy_d1_pullback_bars < 3 || strategy_d1_impulse_bars < 3 ||
      strategy_h4_atr_period < 1 || strategy_d1_atr_percentile_lookback < 20)
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

   const int d1_count = strategy_d1_pullback_bars + strategy_d1_impulse_bars + 4;
   const int h4_count = strategy_h4_pause_max_bars + 2;
   if(d1_count < 20 || h4_count < 5)
      return false;

   MqlRates d1_rates[];
   MqlRates h4_rates[];
   ArrayResize(d1_rates, d1_count);
   ArrayResize(h4_rates, h4_count);

   // perf-allowed: bounded structural OHLC reads, called only by the framework
   // after QM_IsNewBar() passes.
   if(CopyRates(_Symbol, PERIOD_D1, 1, d1_count, d1_rates) != d1_count)
      return false;
   if(CopyRates(_Symbol, PERIOD_H4, 1, h4_count, h4_rates) != h4_count)
      return false;

   double atr_values[];
   ArrayResize(atr_values, strategy_d1_atr_percentile_lookback);
   for(int i = 0; i < strategy_d1_atr_percentile_lookback; ++i)
     {
      atr_values[i] = QM_ATR(_Symbol, PERIOD_D1, strategy_h4_atr_period, i + 1);
      if(atr_values[i] <= 0.0)
         return false;
     }
   ArraySort(atr_values);
   int percentile_index = (int)MathFloor((strategy_d1_atr_min_percentile / 100.0) *
                                         (strategy_d1_atr_percentile_lookback - 1));
   if(percentile_index < 0)
      percentile_index = 0;
   if(percentile_index >= strategy_d1_atr_percentile_lookback)
      percentile_index = strategy_d1_atr_percentile_lookback - 1;

   const double current_d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_h4_atr_period, 1);
   if(current_d1_atr <= 0.0 || current_d1_atr < atr_values[percentile_index])
      return false;

   const int d1_latest_idx = d1_count - 1;
   const double d1_close_1 = d1_rates[d1_latest_idx].close;
   const double d1_ema_fast_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_fast_ema, 1);
   const double d1_ema_slow_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_slow_ema, 1);
   if(d1_close_1 <= 0.0 || d1_ema_fast_1 <= 0.0 || d1_ema_slow_1 <= 0.0)
      return false;

   bool long_trend = (d1_close_1 > d1_ema_slow_1 && d1_ema_fast_1 > d1_ema_slow_1);
   bool short_trend = (d1_close_1 < d1_ema_slow_1 && d1_ema_fast_1 < d1_ema_slow_1);
   if(!long_trend && !short_trend)
      return false;

   double pullback_high = -DBL_MAX;
   double pullback_low = DBL_MAX;
   bool long_above_slow = true;
   bool short_below_slow = true;
   for(int shift = 1; shift <= strategy_d1_pullback_bars; ++shift)
     {
      const int idx = d1_count - shift;
      pullback_high = MathMax(pullback_high, d1_rates[idx].high);
      pullback_low = MathMin(pullback_low, d1_rates[idx].low);

      const double ema_slow = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_slow_ema, shift);
      if(ema_slow <= 0.0)
         return false;
      if(d1_rates[idx].close < ema_slow)
         long_above_slow = false;
      if(d1_rates[idx].close > ema_slow)
         short_below_slow = false;
     }

   double impulse_high = -DBL_MAX;
   double impulse_low = DBL_MAX;
   const int impulse_start_shift = strategy_d1_pullback_bars + 1;
   const int impulse_end_shift = strategy_d1_pullback_bars + strategy_d1_impulse_bars;
   for(int shift = impulse_start_shift; shift <= impulse_end_shift; ++shift)
     {
      const int idx = d1_count - shift;
      impulse_high = MathMax(impulse_high, d1_rates[idx].high);
      impulse_low = MathMin(impulse_low, d1_rates[idx].low);
     }

   const double impulse_range = impulse_high - impulse_low;
   if(impulse_range <= 0.0)
      return false;

   const int d1_shift2_idx = d1_count - 2;
   const int d1_shift3_idx = d1_count - 3;
   const double prior_2bar_high = MathMax(d1_rates[d1_shift2_idx].high, d1_rates[d1_shift3_idx].high);
   const double prior_2bar_low = MathMin(d1_rates[d1_shift2_idx].low, d1_rates[d1_shift3_idx].low);

   const double long_retrace = (impulse_high - pullback_low) / impulse_range;
   const double short_retrace = (pullback_high - impulse_low) / impulse_range;
   const bool long_d1_turn = (d1_close_1 > prior_2bar_high || d1_close_1 > d1_ema_fast_1);
   const bool short_d1_turn = (d1_close_1 < prior_2bar_low || d1_close_1 < d1_ema_fast_1);

   const bool long_context =
      long_trend &&
      long_above_slow &&
      long_retrace >= strategy_pullback_min_fraction &&
      long_retrace <= strategy_pullback_max_fraction &&
      long_d1_turn;

   const bool short_context =
      short_trend &&
      short_below_slow &&
      short_retrace >= strategy_pullback_min_fraction &&
      short_retrace <= strategy_pullback_max_fraction &&
      short_d1_turn;

   if(!long_context && !short_context)
      return false;

   const double h4_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_h4_atr_period, 1);
   if(h4_atr <= 0.0)
      return false;

   const int h4_breakout_idx = h4_count - 1;
   const double trigger_close = h4_rates[h4_breakout_idx].close;
   if(trigger_close <= 0.0)
      return false;

   double chosen_pause_high = 0.0;
   double chosen_pause_low = 0.0;
   bool long_breakout = false;
   bool short_breakout = false;

   for(int pause_bars = strategy_h4_pause_min_bars;
       pause_bars <= strategy_h4_pause_max_bars;
       ++pause_bars)
     {
      double pause_high = -DBL_MAX;
      double pause_low = DBL_MAX;
      bool closes_above_fast = true;
      bool closes_below_fast = true;

      for(int shift = 2; shift <= pause_bars + 1; ++shift)
        {
         const int idx = h4_count - shift;
         pause_high = MathMax(pause_high, h4_rates[idx].high);
         pause_low = MathMin(pause_low, h4_rates[idx].low);

         const double h4_ema_fast = QM_EMA(_Symbol, PERIOD_H4, strategy_d1_fast_ema, shift);
         if(h4_ema_fast <= 0.0)
            return false;
         if(h4_rates[idx].close <= h4_ema_fast)
            closes_above_fast = false;
         if(h4_rates[idx].close >= h4_ema_fast)
            closes_below_fast = false;
        }

      if((pause_high - pause_low) > strategy_pause_range_atr_mult * h4_atr)
         continue;

      if(long_context && closes_above_fast && trigger_close > pause_high)
        {
         chosen_pause_high = pause_high;
         chosen_pause_low = pause_low;
         long_breakout = true;
         break;
        }

      if(short_context && closes_below_fast && trigger_close < pause_low)
        {
         chosen_pause_high = pause_high;
         chosen_pause_low = pause_low;
         short_breakout = true;
         break;
        }
     }

   if(!long_breakout && !short_breakout)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(long_breakout)
     {
      const double entry = ask;
      const double sl = chosen_pause_low - strategy_stop_atr_mult * h4_atr;
      const double stop_distance = entry - sl;
      if(stop_distance <= 0.0 || stop_distance > strategy_max_stop_atr_mult * h4_atr)
         return false;
      if((ask - bid) > strategy_spread_stop_max_fraction * stop_distance)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry + strategy_target_r * stop_distance, _Digits);
      req.reason = "GRIMES_NESTED_PB_LONG";
      return true;
     }

   const double entry = bid;
   const double sl = chosen_pause_high + strategy_stop_atr_mult * h4_atr;
   const double stop_distance = sl - entry;
   if(stop_distance <= 0.0 || stop_distance > strategy_max_stop_atr_mult * h4_atr)
      return false;
   if((ask - bid) > strategy_spread_stop_max_fraction * stop_distance)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(entry - strategy_target_r * stop_distance, _Digits);
   req.reason = "GRIMES_NESTED_PB_SHORT";
   return true;

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || current_sl <= 0.0 || current_tp <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double original_r = MathAbs(current_tp - open_price) / strategy_target_r;
      if(original_r <= 0.0)
         continue;

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double gained = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(gained < strategy_breakeven_trigger_r * original_r)
         continue;

      const double target_sl = NormalizeDouble(open_price, _Digits);
      const bool improves = is_buy ? (current_sl < target_sl) : (current_sl > target_sl);
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "grimes_nested_pb_breakeven");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlRates last_h4[];
   ArrayResize(last_h4, 1);
   if(CopyRates(_Symbol, PERIOD_H4, 1, 1, last_h4) != 1)
      return false;

   const double h4_ema_fast = QM_EMA(_Symbol, PERIOD_H4, strategy_d1_fast_ema, 1);
   if(h4_ema_fast <= 0.0)
      return false;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);

      if(is_buy && last_h4[0].close < h4_ema_fast)
         return true;
      if(!is_buy && last_h4[0].close > h4_ema_fast)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(h4_seconds > 0 && open_time > 0)
        {
         const int held_bars = (int)((TimeCurrent() - open_time) / h4_seconds);
         if(held_bars >= strategy_time_exit_bars)
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
