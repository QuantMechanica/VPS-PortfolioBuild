#property strict
#property version   "5.0"
#property description "QM5_1424 Bressert Short Cycle Counting H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1424;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_cycle_window_bars       = 800;
input int    strategy_atr_period              = 14;
input int    strategy_pivot_side_bars         = 2;
input int    strategy_pivot_swing_window      = 20;
input double strategy_pivot_atr_mult          = 2.5;
input int    strategy_min_pivots              = 6;
input double strategy_iqr_max_ratio           = 0.40;
input int    strategy_cycle_min_bars          = 20;
input int    strategy_cycle_max_bars          = 120;
input double strategy_projection_min_mult     = 0.75;
input double strategy_projection_max_mult     = 1.30;
input double strategy_rally_atr_mult          = 1.5;
input double strategy_retrace_min             = 0.382;
input double strategy_retrace_max             = 0.786;
input double strategy_local_high_cycle_frac   = 0.20;
input double strategy_tp_amplitude_mult       = 0.80;
input double strategy_partial_close_fraction  = 0.50;
input double strategy_partial_move_fraction   = 0.50;
input double strategy_time_exit_cycle_mult    = 1.50;
input int    strategy_time_exit_max_bars      = 60;
input int    strategy_failure_first_bars      = 8;
input double strategy_sl_atr_mult             = 0.5;
input double strategy_sl_max_atr_mult         = 2.5;
input double strategy_spread_atr_mult         = 0.25;
input int    strategy_macro_sma_period        = 100;
input int    strategy_macro_slope_bars        = 20;
input double strategy_macro_slope_atr_mult    = 0.03;
input int    strategy_news_blackout_h4_bars   = 2;

struct StrategyCycleState
  {
   bool     valid;
   int      pivot_count;
   int      last_pivot_idx;
   int      previous_pivot_idx;
   datetime last_pivot_time;
   double   median_cycle;
   double   iqr_ratio;
   int      bars_since_last_pivot;
   double   atr_h4;
   double   signal_high;
   double   failure_level;
   double   prior_amplitude;
   string   reject_reason;
  };

datetime g_reuse_block_pivot_time = 0;
datetime g_reuse_block_entry_time = 0;
double   g_reuse_block_cycle_bars = 0.0;
double   g_active_cycle_bars      = 0.0;
double   g_active_failure_level   = 0.0;
ulong    g_partial_ticket         = 0;
bool     g_partial_done           = false;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

void Strategy_InitCycleState(StrategyCycleState &state)
  {
   state.valid = false;
   state.pivot_count = 0;
   state.last_pivot_idx = -1;
   state.previous_pivot_idx = -1;
   state.last_pivot_time = 0;
   state.median_cycle = 0.0;
   state.iqr_ratio = 0.0;
   state.bars_since_last_pivot = 0;
   state.atr_h4 = 0.0;
   state.signal_high = 0.0;
   state.failure_level = 0.0;
   state.prior_amplitude = 0.0;
   state.reject_reason = "";
  }

bool Strategy_ReadH4Rates(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, count, rates); // perf-allowed: bespoke Bressert cycle/pivot scan; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   return (copied == count);
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_IsHighPivot(const MqlRates &rates[], const int idx, const int side)
  {
   if(idx < side)
      return false;
   if(idx + side >= ArraySize(rates))
      return false;

   const double high = rates[idx].high;
   if(high <= 0.0)
      return false;

   for(int offset = 1; offset <= side; ++offset)
     {
      if(high <= rates[idx - offset].high)
         return false;
      if(high <= rates[idx + offset].high)
         return false;
     }
   return true;
  }

double Strategy_WindowLow(const MqlRates &rates[], const int center_idx, const int half_window)
  {
   const int total = ArraySize(rates);
   int from_idx = center_idx - half_window;
   int to_idx = center_idx + half_window;
   if(from_idx < 0)
      from_idx = 0;
   if(to_idx >= total)
      to_idx = total - 1;

   double lowest = DBL_MAX;
   for(int i = from_idx; i <= to_idx; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
  }

double Strategy_LowestBetween(const MqlRates &rates[], const int idx_a, const int idx_b)
  {
   int from_idx = idx_a;
   int to_idx = idx_b;
   if(from_idx > to_idx)
     {
      const int tmp = from_idx;
      from_idx = to_idx;
      to_idx = tmp;
     }
   const int total = ArraySize(rates);
   if(from_idx < 0)
      from_idx = 0;
   if(to_idx >= total)
      to_idx = total - 1;

   double lowest = DBL_MAX;
   for(int i = from_idx; i <= to_idx; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
  }

bool Strategy_IsHighestRecent(const MqlRates &rates[], const int bars)
  {
   const int total = ArraySize(rates);
   int lookback = bars;
   if(lookback < 1)
      lookback = 1;
   if(lookback > total)
      lookback = total;

   const double current_high = rates[0].high;
   for(int i = 1; i < lookback; ++i)
     {
      if(rates[i].high > current_high)
         return false;
     }
   return true;
  }

void Strategy_SortDoubles(double &values[])
  {
   const int n = ArraySize(values);
   for(int i = 1; i < n; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }
  }

double Strategy_PercentileSorted(const double &values[], const double percentile)
  {
   const int n = ArraySize(values);
   if(n <= 0)
      return 0.0;
   if(n == 1)
      return values[0];

   double pct = percentile;
   if(pct < 0.0)
      pct = 0.0;
   if(pct > 1.0)
      pct = 1.0;

   const double pos = pct * (double)(n - 1);
   const int lo = (int)MathFloor(pos);
   int hi = lo + 1;
   if(hi >= n)
      hi = n - 1;
   const double frac = pos - (double)lo;
   return values[lo] + (values[hi] - values[lo]) * frac;
  }

bool Strategy_MacroBiasPass()
  {
   if(strategy_macro_sma_period <= 0 || strategy_macro_slope_bars <= 0)
      return false;

   const int old_shift = 1 + strategy_macro_slope_bars;
   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1);
   const double sma_old = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, old_shift);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma_now <= 0.0 || sma_old <= 0.0 || atr_d1 <= 0.0)
      return false;

   const double slope_per_bar = (sma_now - sma_old) / (double)strategy_macro_slope_bars;
   const double allowed_up_slope = strategy_macro_slope_atr_mult * atr_d1;
   return (slope_per_bar <= allowed_up_slope);
  }

bool Strategy_ReUseGuardBlocks(const StrategyCycleState &state)
  {
   if(g_reuse_block_pivot_time <= 0 || g_reuse_block_entry_time <= 0)
      return false;

   if(state.last_pivot_time == g_reuse_block_pivot_time)
      return true;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds <= 0 || g_reuse_block_cycle_bars <= 0.0)
      return false;

   const double elapsed_bars = (double)(TimeCurrent() - g_reuse_block_entry_time) / (double)h4_seconds;
   return (elapsed_bars < 0.50 * g_reuse_block_cycle_bars);
  }

bool Strategy_NewsBlackoutBlocks()
  {
   if(strategy_news_blackout_h4_bars <= 0)
      return false;
   if(!QM_NewsIsAvailable())
      return false;

   datetime utc_time = QM_BrokerToUTC(TimeCurrent());
   if(utc_time <= 0)
      utc_time = TimeGMT();

   const int minutes = strategy_news_blackout_h4_bars * PeriodSeconds(PERIOD_H4) / 60;
   if(minutes <= 0)
      return false;

   return QM_NewsInWindow(utc_time, _Symbol, minutes, minutes, "HIGH");
  }

bool Strategy_ComputeCycleState(StrategyCycleState &state)
  {
   Strategy_InitCycleState(state);
   if(strategy_cycle_window_bars < 100 || strategy_atr_period <= 0 || strategy_pivot_side_bars != 2)
     {
      state.reject_reason = "invalid_inputs";
      return false;
     }

   const int required = strategy_cycle_window_bars + strategy_pivot_swing_window + strategy_pivot_side_bars + strategy_macro_slope_bars + 10;
   MqlRates rates[];
   if(!Strategy_ReadH4Rates(rates, required))
     {
      state.reject_reason = "rates_unavailable";
      return false;
     }

   int pivots[];
   ArrayResize(pivots, 0);

   int start_idx = strategy_cycle_window_bars - 1;
   const int max_idx = ArraySize(rates) - strategy_pivot_side_bars - 1;
   if(start_idx > max_idx)
      start_idx = max_idx;
   if(start_idx <= strategy_pivot_side_bars)
     {
      state.reject_reason = "insufficient_bars";
      return false;
     }

   for(int idx = start_idx; idx >= strategy_pivot_side_bars; --idx)
     {
      if(!Strategy_IsHighPivot(rates, idx, strategy_pivot_side_bars))
         continue;

      const double atr_at_pivot = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, idx + 1);
      if(atr_at_pivot <= 0.0)
         continue;

      const double low_window = Strategy_WindowLow(rates, idx, strategy_pivot_swing_window);
      if(low_window <= 0.0)
         continue;

      if((rates[idx].high - low_window) < strategy_pivot_atr_mult * atr_at_pivot)
         continue;

      const int n = ArraySize(pivots);
      ArrayResize(pivots, n + 1);
      pivots[n] = idx;
     }

   const int pivot_count = ArraySize(pivots);
   state.pivot_count = pivot_count;
   if(pivot_count < strategy_min_pivots)
     {
      state.reject_reason = "too_few_significant_pivots";
      return false;
     }

   double distances[];
   ArrayResize(distances, pivot_count - 1);
   for(int i = 1; i < pivot_count; ++i)
      distances[i - 1] = (double)(pivots[i - 1] - pivots[i]);
   Strategy_SortDoubles(distances);

   const double median = Strategy_PercentileSorted(distances, 0.50);
   const double q1 = Strategy_PercentileSorted(distances, 0.25);
   const double q3 = Strategy_PercentileSorted(distances, 0.75);
   if(median <= 0.0)
     {
      state.reject_reason = "median_cycle_zero";
      return false;
     }

   const double iqr_ratio = (q3 - q1) / median;
   if(iqr_ratio > strategy_iqr_max_ratio)
     {
      state.reject_reason = "cycle_iqr_too_wide";
      return false;
     }
   if(median < (double)strategy_cycle_min_bars || median > (double)strategy_cycle_max_bars)
     {
      state.reject_reason = "median_cycle_out_of_bounds";
      return false;
     }

   const int last_idx = pivots[pivot_count - 1];
   const int prev_idx = pivots[pivot_count - 2];
   const int bars_since = last_idx;
   if((double)bars_since < strategy_projection_min_mult * median ||
      (double)bars_since > strategy_projection_max_mult * median)
     {
      state.reject_reason = "outside_projection_band";
      return false;
     }

   const double atr_now = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_now <= 0.0)
     {
      state.reject_reason = "atr_unavailable";
      return false;
     }

   const double lowest_since_last = Strategy_LowestBetween(rates, 0, last_idx);
   const double rally = rates[0].high - lowest_since_last;
   if(rally < strategy_rally_atr_mult * atr_now)
     {
      state.reject_reason = "rally_too_small";
      return false;
     }

   const double swing_den = rates[last_idx].high - lowest_since_last;
   if(swing_den <= 0.0)
     {
      state.reject_reason = "swing_denominator_zero";
      return false;
     }

   const double retrace = rally / swing_den;
   if(retrace < strategy_retrace_min || retrace > strategy_retrace_max)
     {
      state.reject_reason = "rally_retrace_outside_band";
      return false;
     }

   int local_high_bars = (int)MathRound(strategy_local_high_cycle_frac * median);
   if(local_high_bars < 1)
      local_high_bars = 1;
   if(!Strategy_IsHighestRecent(rates, local_high_bars))
     {
      state.reject_reason = "not_recent_cycle_high";
      return false;
     }

   if(!(rates[0].close < rates[0].open &&
        rates[0].close < rates[1].close &&
        rates[0].high >= rates[1].high))
     {
      state.reject_reason = "bearish_reversal_bar_missing";
      return false;
     }

   const double prior_cycle_low = Strategy_LowestBetween(rates, last_idx, prev_idx);
   const double prior_amplitude = rates[last_idx].high - prior_cycle_low;
   if(prior_amplitude <= 0.0)
     {
      state.reject_reason = "prior_amplitude_zero";
      return false;
     }

   state.valid = true;
   state.last_pivot_idx = last_idx;
   state.previous_pivot_idx = prev_idx;
   state.last_pivot_time = rates[last_idx].time;
   state.median_cycle = median;
   state.iqr_ratio = iqr_ratio;
   state.bars_since_last_pivot = bars_since;
   state.atr_h4 = atr_now;
   state.signal_high = rates[0].high;
   state.failure_level = rates[0].high + strategy_sl_atr_mult * atr_now;
   state.prior_amplitude = prior_amplitude;
   return true;
  }

double Strategy_EntryReferencePrice(const double fallback_close)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid > 0.0)
      return bid;
   return fallback_close;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return false;

   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return false;
   if(Strategy_HasOurPosition())
      return false;
   if(Strategy_NewsBlackoutBlocks())
      return false;
   if(!Strategy_MacroBiasPass())
      return false;

   StrategyCycleState state;
   if(!Strategy_ComputeCycleState(state))
      return false;
   if(!state.valid)
      return false;
   if(Strategy_ReUseGuardBlocks(state))
      return false;

   const double entry_ref = Strategy_EntryReferencePrice(state.signal_high);
   if(entry_ref <= 0.0)
      return false;

   double sl = state.failure_level;
   const double max_sl_distance = strategy_sl_max_atr_mult * state.atr_h4;
   if(max_sl_distance > 0.0 && (sl - entry_ref) > max_sl_distance)
      sl = entry_ref + max_sl_distance;
   if(sl <= entry_ref)
      return false;

   const double tp = entry_ref - strategy_tp_amplitude_mult * state.prior_amplitude;
   if(tp <= 0.0 || tp >= entry_ref)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = "BRESSERT_CYCLE_CREST_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_reuse_block_pivot_time = state.last_pivot_time;
   g_reuse_block_entry_time = TimeCurrent();
   g_reuse_block_cycle_bars = state.median_cycle;
   g_active_cycle_bars = state.median_cycle;
   g_active_failure_level = state.failure_level;
   g_partial_ticket = 0;
   g_partial_done = false;
   return true;
  }

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
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_tp <= 0.0 || current_tp >= open_price || ask <= 0.0 || point <= 0.0)
         continue;

      if(g_partial_ticket != ticket)
        {
         g_partial_ticket = ticket;
         g_partial_done = (current_sl > 0.0 && current_sl <= open_price + point * 0.5);
        }
      if(g_partial_done)
         continue;

      const double partial_trigger = open_price - (open_price - current_tp) * strategy_partial_move_fraction;
      if(ask > partial_trigger)
         continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double requested = volume * strategy_partial_close_fraction;
      const double lots_to_close = QM_TM_NormalizeVolume(_Symbol, requested);
      bool partial_ok = false;
      if(lots_to_close > 0.0 && lots_to_close < volume)
         partial_ok = QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL);

      if(partial_ok || lots_to_close <= 0.0)
        {
         QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "bressert_partial_or_minlot_be");
         g_partial_done = true;
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds <= 0)
      return false;

   double cycle_bars = g_active_cycle_bars;
   if(cycle_bars <= 0.0)
      cycle_bars = (double)strategy_time_exit_max_bars / MathMax(1.0, strategy_time_exit_cycle_mult);

   double hold_limit = strategy_time_exit_cycle_mult * cycle_bars;
   if(hold_limit > (double)strategy_time_exit_max_bars)
      hold_limit = (double)strategy_time_exit_max_bars;
   if(hold_limit <= 0.0)
      return false;

   const datetime now = TimeCurrent();
   const double h4_close = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: single closed H4 close for card pattern-failure exit; Strategy_ExitSignal must not consume QM_IsNewBar before entry.

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const double bars_held = (double)(now - open_time) / (double)h4_seconds;
      if(bars_held >= hold_limit)
         return true;
      if(g_active_failure_level > 0.0 &&
         bars_held <= (double)strategy_failure_first_bars &&
         h4_close > g_active_failure_level)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
