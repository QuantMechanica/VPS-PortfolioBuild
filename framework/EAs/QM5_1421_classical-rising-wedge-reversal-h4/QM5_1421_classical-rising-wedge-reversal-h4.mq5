#property strict
#property version   "5.0"
#property description "QM5_1421 Classical Rising-Wedge Bearish Reversal H4"

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
input int    qm_ea_id                   = 1421;
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
input int    strategy_atr_period                 = 14;
input int    strategy_prior_lookback_bars        = 60;
input int    strategy_wedge_min_bars             = 30;
input int    strategy_wedge_max_bars             = 100;
input int    strategy_pivot_wing                 = 2;
input int    strategy_min_pivots                 = 3;
input double strategy_prior_slope_atr_per_bar    = 0.15;
input double strategy_prior_rally_atr_mult       = 5.0;
input double strategy_slope_ratio_min            = 1.30;
input double strategy_slope_ratio_max            = 4.00;
input double strategy_apex_min_frac              = 0.15;
input double strategy_apex_max_frac              = 0.70;
input double strategy_range_contraction_min      = 1.50;
input double strategy_pivot_span_frac            = 0.50;
input double strategy_entry_atr_buffer           = 0.50;
input double strategy_sl_atr_buffer              = 0.40;
input double strategy_max_sl_atr_mult            = 3.00;
input double strategy_tp_height_mult             = 0.75;
input double strategy_partial_progress           = 0.50;
input double strategy_partial_fraction           = 0.50;
input int    strategy_failure_bars               = 5;
input int    strategy_time_stop_bars             = 30;
input int    strategy_pending_valid_bars         = 10;
input int    strategy_reuse_guard_bars           = 20;
input double strategy_spread_atr_frac            = 0.20;
input int    strategy_macro_sma_period           = 50;
input int    strategy_macro_slope_bars           = 20;
input double strategy_macro_slope_atr_per_bar    = 0.05;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   static datetime reuse_block_until = 0;

   req.type = QM_SELL_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(TimeCurrent() < reuse_block_until)
      return false;

   if(strategy_atr_period <= 0 ||
      strategy_prior_lookback_bars <= 0 ||
      strategy_wedge_min_bars < 30 ||
      strategy_wedge_max_bars < strategy_wedge_min_bars ||
      strategy_wedge_max_bars > 120 ||
      strategy_pivot_wing != 2 ||
      strategy_min_pivots < 3)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_LIMIT ||
         order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT)
         return false;
     }

   const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_h4 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask > bid && (ask - bid) > strategy_spread_atr_frac * atr_h4)
      return false;

   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1);
   const double sma_then = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1 + strategy_macro_slope_bars);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma_now <= 0.0 || sma_then <= 0.0 || atr_d1 <= 0.0)
      return false;
   const double macro_slope = (sma_now - sma_then) / (double)strategy_macro_slope_bars;
   if(macro_slope > strategy_macro_slope_atr_per_bar * atr_d1)
      return false;

   const int needed_bars = strategy_wedge_max_bars + strategy_prior_lookback_bars + strategy_pivot_wing + 5;
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   // perf-allowed: bespoke Williams-fractal wedge geometry, called only after the framework new-bar gate.
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, needed_bars, rates);
   if(copied < strategy_wedge_max_bars + strategy_prior_lookback_bars)
      return false;

   const int latest_idx = copied - 1;
   for(int wedge_bars = strategy_wedge_max_bars; wedge_bars >= strategy_wedge_min_bars; --wedge_bars)
     {
      const int wedge_start = copied - wedge_bars;
      if(wedge_start < strategy_prior_lookback_bars)
         continue;

      int pivot_high_idx[128];
      int pivot_low_idx[128];
      double pivot_high_price[128];
      double pivot_low_price[128];
      int pivot_high_count = 0;
      int pivot_low_count = 0;

      for(int k = wedge_start + strategy_pivot_wing; k <= latest_idx - strategy_pivot_wing; ++k)
        {
         bool is_high_pivot = true;
         bool is_low_pivot = true;
         for(int w = 1; w <= strategy_pivot_wing; ++w)
           {
            if(rates[k].high <= rates[k - w].high || rates[k].high <= rates[k + w].high)
               is_high_pivot = false;
            if(rates[k].low >= rates[k - w].low || rates[k].low >= rates[k + w].low)
               is_low_pivot = false;
           }

         if(is_high_pivot && pivot_high_count < 128)
           {
            pivot_high_idx[pivot_high_count] = k;
            pivot_high_price[pivot_high_count] = rates[k].high;
            pivot_high_count++;
           }
         if(is_low_pivot && pivot_low_count < 128)
           {
            pivot_low_idx[pivot_low_count] = k;
            pivot_low_price[pivot_low_count] = rates[k].low;
            pivot_low_count++;
           }
        }

      if(pivot_high_count < strategy_min_pivots || pivot_low_count < strategy_min_pivots)
         continue;

      const int high_span = pivot_high_idx[pivot_high_count - 1] - pivot_high_idx[0];
      const int low_span = pivot_low_idx[pivot_low_count - 1] - pivot_low_idx[0];
      if((double)high_span < strategy_pivot_span_frac * (double)wedge_bars ||
         (double)low_span < strategy_pivot_span_frac * (double)wedge_bars)
         continue;

      double sum_x = 0.0;
      double sum_y = 0.0;
      double sum_xx = 0.0;
      double sum_xy = 0.0;
      for(int p = 0; p < pivot_high_count; ++p)
        {
         const double x = (double)(pivot_high_idx[p] - wedge_start);
         const double y = pivot_high_price[p];
         sum_x += x;
         sum_y += y;
         sum_xx += x * x;
         sum_xy += x * y;
        }
      double denom = (double)pivot_high_count * sum_xx - sum_x * sum_x;
      if(MathAbs(denom) <= 1e-12)
         continue;
      const double upper_slope = ((double)pivot_high_count * sum_xy - sum_x * sum_y) / denom;
      const double upper_intercept = (sum_y - upper_slope * sum_x) / (double)pivot_high_count;

      sum_x = 0.0;
      sum_y = 0.0;
      sum_xx = 0.0;
      sum_xy = 0.0;
      for(int p = 0; p < pivot_low_count; ++p)
        {
         const double x = (double)(pivot_low_idx[p] - wedge_start);
         const double y = pivot_low_price[p];
         sum_x += x;
         sum_y += y;
         sum_xx += x * x;
         sum_xy += x * y;
        }
      denom = (double)pivot_low_count * sum_xx - sum_x * sum_x;
      if(MathAbs(denom) <= 1e-12)
         continue;
      const double lower_slope = ((double)pivot_low_count * sum_xy - sum_x * sum_y) / denom;
      const double lower_intercept = (sum_y - lower_slope * sum_x) / (double)pivot_low_count;

      if(upper_slope <= 0.0 || lower_slope <= 0.0 || lower_slope <= upper_slope)
         continue;
      const double slope_ratio = lower_slope / upper_slope;
      if(slope_ratio < strategy_slope_ratio_min || slope_ratio > strategy_slope_ratio_max)
         continue;

      const double x_apex = (upper_intercept - lower_intercept) / (lower_slope - upper_slope);
      const double x_now = (double)(wedge_bars - 1);
      const double apex_frac = (x_apex - x_now) / (double)wedge_bars;
      if(apex_frac < strategy_apex_min_frac || apex_frac > strategy_apex_max_frac)
         continue;

      const int first_pivot_idx = (pivot_high_idx[0] < pivot_low_idx[0]) ? pivot_high_idx[0] : pivot_low_idx[0];
      const int prior_start = first_pivot_idx - strategy_prior_lookback_bars + 1;
      if(prior_start < 0)
         continue;

      double prior_sum_x = 0.0;
      double prior_sum_y = 0.0;
      double prior_sum_xx = 0.0;
      double prior_sum_xy = 0.0;
      double prior_high = -DBL_MAX;
      double prior_low = DBL_MAX;
      for(int p = 0; p < strategy_prior_lookback_bars; ++p)
        {
         const int idx = prior_start + p;
         const double x = (double)p;
         const double y = rates[idx].close;
         prior_sum_x += x;
         prior_sum_y += y;
         prior_sum_xx += x * x;
         prior_sum_xy += x * y;
         if(rates[idx].high > prior_high)
            prior_high = rates[idx].high;
         if(rates[idx].low < prior_low)
            prior_low = rates[idx].low;
        }
      const double prior_denom = (double)strategy_prior_lookback_bars * prior_sum_xx - prior_sum_x * prior_sum_x;
      if(MathAbs(prior_denom) <= 1e-12)
         continue;
      const double prior_slope = ((double)strategy_prior_lookback_bars * prior_sum_xy - prior_sum_x * prior_sum_y) / prior_denom;
      if(prior_slope < strategy_prior_slope_atr_per_bar * atr_h4)
         continue;
      if((prior_high - prior_low) < strategy_prior_rally_atr_mult * atr_h4)
         continue;

      double first_high = -DBL_MAX;
      double first_low = DBL_MAX;
      double last_high = -DBL_MAX;
      double last_low = DBL_MAX;
      for(int j = 0; j < 10; ++j)
        {
         const int first_idx = wedge_start + j;
         const int last_idx = latest_idx - 9 + j;
         if(rates[first_idx].high > first_high)
            first_high = rates[first_idx].high;
         if(rates[first_idx].low < first_low)
            first_low = rates[first_idx].low;
         if(rates[last_idx].high > last_high)
            last_high = rates[last_idx].high;
         if(rates[last_idx].low < last_low)
            last_low = rates[last_idx].low;
        }
      const double first_range = first_high - first_low;
      const double last_range = last_high - last_low;
      if(first_range <= 0.0 || last_range <= 0.0 || first_range / last_range < strategy_range_contraction_min)
         continue;

      bool prior_break = false;
      double wedge_high = -DBL_MAX;
      double wedge_low = DBL_MAX;
      for(int k = wedge_start; k <= latest_idx; ++k)
        {
         const double x = (double)(k - wedge_start);
         const double lower_tl = lower_intercept + lower_slope * x;
         if(rates[k].close < lower_tl)
            prior_break = true;
         if(rates[k].high > wedge_high)
            wedge_high = rates[k].high;
         if(rates[k].low < wedge_low)
            wedge_low = rates[k].low;
        }
      if(prior_break)
         continue;

      const double lower_now = lower_intercept + lower_slope * x_now;
      const double upper_now = upper_intercept + upper_slope * x_now;
      double entry = lower_now - strategy_entry_atr_buffer * atr_h4;
      double stop = upper_now + strategy_sl_atr_buffer * atr_h4;
      const double max_risk = strategy_max_sl_atr_mult * atr_h4;
      if((stop - entry) > max_risk)
         stop = entry + max_risk;
      const double take = entry - strategy_tp_height_mult * (wedge_high - wedge_low);

      entry = QM_StopRulesNormalizePrice(_Symbol, entry);
      stop = QM_StopRulesNormalizePrice(_Symbol, stop);
      const double target = QM_StopRulesNormalizePrice(_Symbol, take);
      if(entry <= 0.0 || stop <= entry || target <= 0.0 || target >= entry)
         continue;
      if(entry >= bid)
         continue;

      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = stop;
      req.tp = target;
      req.reason = "RISING_WEDGE_SELL_STOP";
      const int h4_seconds = PeriodSeconds(PERIOD_H4);
      req.expiration_seconds = strategy_pending_valid_bars * ((h4_seconds > 0) ? h4_seconds : 14400);
      reuse_block_until = TimeCurrent() + strategy_reuse_guard_bars * ((h4_seconds > 0) ? h4_seconds : 14400);
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || current_tp <= 0.0 || current_tp >= open_price || ask <= 0.0)
         continue;

      if(current_sl <= 0.0 || current_sl <= open_price + point * 0.5)
         continue;

      const double partial_trigger = open_price - (open_price - current_tp) * strategy_partial_progress;
      if(ask > partial_trigger)
         continue;

      const double lots_to_close = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_fraction);
      if(lots_to_close > 0.0)
         QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL);
      QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "rising_wedge_partial_be");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   const int seconds_per_h4 = (h4_seconds > 0) ? h4_seconds : 14400;
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(open_time <= 0 || open_price <= 0.0)
         continue;

      const int elapsed_seconds = (int)(now - open_time);
      if(elapsed_seconds >= strategy_time_stop_bars * seconds_per_h4)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
        }

      const int bars_since_entry = elapsed_seconds / seconds_per_h4;
      if(bars_since_entry <= strategy_failure_bars)
        {
         MqlRates last_bar[];
         ArraySetAsSeries(last_bar, false);
         // perf-allowed: one closed H4 bar read for the card's pattern-failure close.
         if(CopyRates(_Symbol, PERIOD_H4, 1, 1, last_bar) == 1)
           {
            const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
            const double failure_level = open_price + strategy_entry_atr_buffer * atr_h4;
            if(atr_h4 > 0.0 && last_bar[0].close > failure_level)
               QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
           }
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
