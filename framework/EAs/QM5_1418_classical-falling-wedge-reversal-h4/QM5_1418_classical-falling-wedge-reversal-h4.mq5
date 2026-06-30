#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
input int    qm_ea_id                   = 1418;
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
input int    strategy_atr_period                  = 14;
input int    strategy_wedge_min_bars              = 30;
input int    strategy_wedge_max_bars              = 100;
input int    strategy_prior_trend_bars            = 60;
input int    strategy_pivot_span                  = 2;
input double strategy_prior_slope_atr_per_bar_max = -0.15;
input double strategy_prior_drawdown_atr_min      = 5.0;
input double strategy_slope_ratio_min             = 1.30;
input double strategy_slope_ratio_max             = 4.00;
input double strategy_apex_distance_min           = 0.15;
input double strategy_apex_distance_max           = 0.70;
input double strategy_range_contraction_min       = 1.50;
input double strategy_pivot_variety_min           = 0.50;
input double strategy_entry_atr_buffer            = 0.50;
input double strategy_sl_atr_buffer               = 0.40;
input double strategy_sl_atr_cap                  = 3.00;
input double strategy_tp_height_fraction          = 0.75;
input double strategy_partial_height_fraction     = 0.50;
input double strategy_partial_close_fraction      = 0.50;
input int    strategy_order_valid_bars            = 10;
input int    strategy_time_stop_bars              = 30;
input int    strategy_failure_exit_bars           = 5;
input int    strategy_reuse_guard_bars            = 20;
input double strategy_spread_atr_max              = 0.20;
input int    strategy_macro_sma_period            = 50;
input int    strategy_macro_slope_bars            = 20;
input double strategy_macro_min_slope_atr         = -0.05;
input bool   strategy_news_blackout_enabled       = true;
input int    strategy_news_blackout_h4_bars       = 2;

datetime g_pattern_reuse_until = 0;
datetime g_pending_breakout_time = 0;
double   g_pending_upper_line = 0.0;
bool     g_position_tracking_active = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_spread_atr_max <= 0.0)
      return false;

   const double spread = ask - bid;
   if(ask > bid && spread > strategy_spread_atr_max * atr)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime now = TimeCurrent();
   if(g_pattern_reuse_until > 0 && now < g_pattern_reuse_until)
      return false;

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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

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
      if(order_type == ORDER_TYPE_BUY_STOP)
         return false;
     }

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double d1_sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1);
   const double d1_sma_old = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1 + strategy_macro_slope_bars);
   if(atr <= 0.0 || d1_atr <= 0.0 || d1_sma_now <= 0.0 || d1_sma_old <= 0.0)
      return false;

   const double macro_slope = (d1_sma_now - d1_sma_old) / (double)strategy_macro_slope_bars;
   if(macro_slope < strategy_macro_min_slope_atr * d1_atr)
      return false;

   int min_wedge = strategy_wedge_min_bars;
   int max_wedge = strategy_wedge_max_bars;
   if(min_wedge < 30)
      min_wedge = 30;
   if(max_wedge > 120)
      max_wedge = 120;
   if(max_wedge < min_wedge || strategy_prior_trend_bars < 10 || strategy_pivot_span != 2)
      return false;

   const int history_bars = max_wedge + strategy_prior_trend_bars + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, history_bars, rates); // perf-allowed: bespoke wedge geometry, entry hook is framework new-bar gated.
   if(copied < history_bars)
      return false;

   for(int n = min_wedge; n <= max_wedge; ++n)
     {
      double prior_sum_x = 0.0;
      double prior_sum_y = 0.0;
      double prior_sum_xx = 0.0;
      double prior_sum_xy = 0.0;
      double prior_high = -DBL_MAX;
      double prior_low = DBL_MAX;

      for(int p = 0; p < strategy_prior_trend_bars; ++p)
        {
         const int idx = n + strategy_prior_trend_bars - 1 - p;
         const double x = (double)p;
         const double close_price = rates[idx].close;
         prior_sum_x += x;
         prior_sum_y += close_price;
         prior_sum_xx += x * x;
         prior_sum_xy += x * close_price;
         if(rates[idx].high > prior_high)
            prior_high = rates[idx].high;
         if(rates[idx].low < prior_low)
            prior_low = rates[idx].low;
        }

      const double prior_count = (double)strategy_prior_trend_bars;
      const double prior_denom = prior_count * prior_sum_xx - prior_sum_x * prior_sum_x;
      if(MathAbs(prior_denom) <= 0.0)
         continue;
      const double prior_slope = (prior_count * prior_sum_xy - prior_sum_x * prior_sum_y) / prior_denom;
      if(prior_slope > strategy_prior_slope_atr_per_bar_max * atr)
         continue;
      if((prior_high - prior_low) < strategy_prior_drawdown_atr_min * atr)
         continue;

      double high_x[128];
      double high_y[128];
      double low_x[128];
      double low_y[128];
      int high_count = 0;
      int low_count = 0;
      double wedge_high = -DBL_MAX;
      double wedge_low = DBL_MAX;

      for(int j = 0; j < n; ++j)
        {
         if(rates[j].high > wedge_high)
            wedge_high = rates[j].high;
         if(rates[j].low < wedge_low)
            wedge_low = rates[j].low;
        }

      for(int j = 2; j <= n - 3; ++j)
        {
         const double x = (double)(n - 1 - j);
         if(rates[j].high > rates[j - 1].high &&
            rates[j].high > rates[j - 2].high &&
            rates[j].high > rates[j + 1].high &&
            rates[j].high > rates[j + 2].high &&
            high_count < 128)
           {
            high_x[high_count] = x;
            high_y[high_count] = rates[j].high;
            high_count++;
           }

         if(rates[j].low < rates[j - 1].low &&
            rates[j].low < rates[j - 2].low &&
            rates[j].low < rates[j + 1].low &&
            rates[j].low < rates[j + 2].low &&
            low_count < 128)
           {
            low_x[low_count] = x;
            low_y[low_count] = rates[j].low;
            low_count++;
           }
        }

      if(high_count < 3 || low_count < 3)
         continue;

      double sum_xh = 0.0;
      double sum_yh = 0.0;
      double sum_xxh = 0.0;
      double sum_xyh = 0.0;
      double min_high_x = DBL_MAX;
      double max_high_x = -DBL_MAX;
      for(int h = 0; h < high_count; ++h)
        {
         sum_xh += high_x[h];
         sum_yh += high_y[h];
         sum_xxh += high_x[h] * high_x[h];
         sum_xyh += high_x[h] * high_y[h];
         if(high_x[h] < min_high_x)
            min_high_x = high_x[h];
         if(high_x[h] > max_high_x)
            max_high_x = high_x[h];
        }

      double sum_xl = 0.0;
      double sum_yl = 0.0;
      double sum_xxl = 0.0;
      double sum_xyl = 0.0;
      double min_low_x = DBL_MAX;
      double max_low_x = -DBL_MAX;
      for(int l = 0; l < low_count; ++l)
        {
         sum_xl += low_x[l];
         sum_yl += low_y[l];
         sum_xxl += low_x[l] * low_x[l];
         sum_xyl += low_x[l] * low_y[l];
         if(low_x[l] < min_low_x)
            min_low_x = low_x[l];
         if(low_x[l] > max_low_x)
            max_low_x = low_x[l];
        }

      const double high_n = (double)high_count;
      const double low_n = (double)low_count;
      const double high_denom = high_n * sum_xxh - sum_xh * sum_xh;
      const double low_denom = low_n * sum_xxl - sum_xl * sum_xl;
      if(MathAbs(high_denom) <= 0.0 || MathAbs(low_denom) <= 0.0)
         continue;

      const double slope_up = (high_n * sum_xyh - sum_xh * sum_yh) / high_denom;
      const double intercept_up = (sum_yh - slope_up * sum_xh) / high_n;
      const double slope_lo = (low_n * sum_xyl - sum_xl * sum_yl) / low_denom;
      const double intercept_lo = (sum_yl - slope_lo * sum_xl) / low_n;
      if(slope_up >= 0.0 || slope_lo >= 0.0 || slope_up >= slope_lo)
         continue;

      const double slope_ratio = slope_up / slope_lo;
      if(slope_ratio < strategy_slope_ratio_min || slope_ratio > strategy_slope_ratio_max)
         continue;

      const double apex_denom = slope_up - slope_lo;
      if(MathAbs(apex_denom) <= 0.0)
         continue;
      const double apex_x = (intercept_lo - intercept_up) / apex_denom;
      const double apex_distance = (apex_x - (double)n) / (double)n;
      if(apex_distance < strategy_apex_distance_min || apex_distance > strategy_apex_distance_max)
         continue;

      double first_high = -DBL_MAX;
      double first_low = DBL_MAX;
      double last_high = -DBL_MAX;
      double last_low = DBL_MAX;
      for(int r = 0; r < 10; ++r)
        {
         const int first_idx = n - 1 - r;
         if(rates[first_idx].high > first_high)
            first_high = rates[first_idx].high;
         if(rates[first_idx].low < first_low)
            first_low = rates[first_idx].low;
         if(rates[r].high > last_high)
            last_high = rates[r].high;
         if(rates[r].low < last_low)
            last_low = rates[r].low;
        }

      const double first_range = first_high - first_low;
      const double last_range = last_high - last_low;
      if(first_range <= 0.0 || last_range <= 0.0 || first_range / last_range < strategy_range_contraction_min)
         continue;

      bool prior_break = false;
      for(int j = 0; j < n; ++j)
        {
         const double x = (double)(n - 1 - j);
         const double upper_line = intercept_up + slope_up * x;
         if(rates[j].close > upper_line)
           {
            prior_break = true;
            break;
           }
        }
      if(prior_break)
         continue;

      if((max_high_x - min_high_x) < strategy_pivot_variety_min * (double)n ||
         (max_low_x - min_low_x) < strategy_pivot_variety_min * (double)n)
         continue;

      const double upper_now = intercept_up + slope_up * (double)n;
      const double lower_now = intercept_lo + slope_lo * (double)n;
      const double entry_price = QM_StopRulesNormalizePrice(_Symbol, upper_now + strategy_entry_atr_buffer * atr);
      double sl_price = lower_now - strategy_sl_atr_buffer * atr;
      const double capped_sl = entry_price - strategy_sl_atr_cap * atr;
      if(sl_price < capped_sl)
         sl_price = capped_sl;
      sl_price = QM_StopRulesNormalizePrice(_Symbol, sl_price);
      const double tp_price = QM_StopRulesNormalizePrice(_Symbol, entry_price + strategy_tp_height_fraction * (wedge_high - wedge_low));

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry_price <= 0.0 || sl_price <= 0.0 || tp_price <= 0.0 || ask <= 0.0)
         continue;
      if(entry_price <= ask || sl_price >= entry_price || tp_price <= entry_price)
         continue;

      req.type = QM_BUY_STOP;
      req.price = entry_price;
      req.sl = sl_price;
      req.tp = tp_price;
      req.reason = StringFormat("falling_wedge_h4_n%d", n);
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = strategy_order_valid_bars * PeriodSeconds(PERIOD_H4);

      g_pending_breakout_time = now;
      g_pending_upper_line = upper_now;
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

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds <= 0)
      return;

   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      have_position = true;
      g_position_tracking_active = true;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double tp_price = PositionGetDouble(POSITION_TP);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(open_price <= 0.0 || tp_price <= open_price || bid <= 0.0 || volume <= 0.0)
         continue;

      const double trigger = open_price + ((tp_price - open_price) * strategy_partial_height_fraction / strategy_tp_height_fraction);
      if(bid >= trigger && current_sl < open_price)
        {
         const double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_close_fraction);
         if(partial_lots > 0.0 && partial_lots < volume)
           {
            if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
               QM_TM_MoveSL(ticket, open_price, "falling_wedge_partial_be");
           }
         else
           {
            QM_TM_MoveSL(ticket, open_price, "falling_wedge_minlot_be");
           }
        }
     }

   if(!have_position && g_position_tracking_active)
     {
      g_pattern_reuse_until = TimeCurrent() + strategy_reuse_guard_bars * h4_seconds;
      g_position_tracking_active = false;
      g_pending_breakout_time = 0;
      g_pending_upper_line = 0.0;
     }

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
      if(order_type != ORDER_TYPE_BUY_STOP)
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && TimeCurrent() - setup_time > strategy_order_valid_bars * h4_seconds)
         QM_TM_RemovePendingOrder(order_ticket, "falling_wedge_pending_stale");
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
   if(h4_seconds <= 0)
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0)
         continue;
      const int bars_open = (int)((TimeCurrent() - open_time) / h4_seconds);

      if(bars_open >= strategy_time_stop_bars)
        {
         g_pattern_reuse_until = TimeCurrent() + strategy_reuse_guard_bars * h4_seconds;
         return true;
        }

      if(bars_open <= strategy_failure_exit_bars)
        {
         double upper_line = g_pending_upper_line;
         if(upper_line <= 0.0)
           {
            const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
            if(open_price > 0.0 && atr > 0.0)
               upper_line = open_price - strategy_entry_atr_buffer * atr;
           }

         const double last_h4_close = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: O(1) failure-close check against stored breakout line.
         if(upper_line > 0.0 && last_h4_close > 0.0 && last_h4_close < upper_line)
           {
            g_pattern_reuse_until = TimeCurrent() + strategy_reuse_guard_bars * h4_seconds;
            return true;
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
   if(!strategy_news_blackout_enabled || strategy_news_blackout_h4_bars <= 0)
      return false;

   const int blackout_minutes = strategy_news_blackout_h4_bars * PeriodSeconds(PERIOD_H4) / 60;
   if(blackout_minutes <= 0)
      return false;

   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return QM_NewsInWindow(utc_time, _Symbol, blackout_minutes, blackout_minutes, qm_news_min_impact);
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
