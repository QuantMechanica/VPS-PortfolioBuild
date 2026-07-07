#property strict
#property version   "5.0"
#property description "QM5_1422 Classical Broadening Formation H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: Classical Broadening Formation Reversal (H4)
// Card: QM5_1422_classical-broadening-formation-h4, G0 APPROVED 2026-05-19.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1422;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period             = 14;
input int    strategy_pattern_min_bars       = 50;
input int    strategy_pattern_max_bars       = 150;
input int    strategy_pivot_span             = 2;
input double strategy_pivot_amplitude_atr    = 1.00;
input double strategy_divergence_atr_buffer  = 0.50;
input double strategy_slope_atr_per_bar_min  = 0.05;
input double strategy_divergence_ratio_min   = 1.20;
input double strategy_prior_break_atr_buffer = 0.50;
input int    strategy_pivot_recency_bars     = 20;
input double strategy_entry_atr_buffer       = 0.50;
input double strategy_sl_atr_buffer          = 0.50;
input double strategy_sl_atr_cap             = 4.00;
input double strategy_tp_measured_move       = 0.65;
input double strategy_partial_move_scale     = 0.50;
input double strategy_partial_close_fraction = 0.50;
input int    strategy_order_valid_bars       = 8;
input int    strategy_time_stop_bars         = 35;
input int    strategy_failure_exit_bars      = 5;
input int    strategy_reuse_guard_bars       = 30;
input double strategy_spread_atr_max         = 0.20;
input int    strategy_d1_atr_median_bars     = 60;
input double strategy_d1_atr_ratio_min       = 0.80;
input double strategy_d1_atr_ratio_max       = 2.00;
input int    strategy_news_blackout_h4_bars  = 2;

struct StrategyPivot
  {
   int      type;      // +1 high, -1 low
   int      idx;       // CopyRates series index, 0 = most recent closed bar
   double   x;         // chronological x inside the candidate pattern window
   double   price;
   datetime time;
  };

struct StrategyPattern
  {
   bool     valid;
   int      bars;
   double   atr;
   double   upper_now;
   double   lower_now;
   double   pattern_amplitude;
   double   buy_entry;
   double   sell_entry;
   double   buy_sl;
   double   sell_sl;
   double   buy_tp;
   double   sell_tp;
   double   buy_failure_level;
   double   sell_failure_level;
  };

bool     g_lifecycle_active       = false;
bool     g_partial_done           = false;
ulong    g_partial_ticket         = 0;
datetime g_pattern_reuse_until    = 0;
double   g_active_pattern_amp     = 0.0;
double   g_active_buy_failure     = 0.0;
double   g_active_sell_failure    = 0.0;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

void Strategy_AssignRequest(QM_EntryRequest &dst, const QM_EntryRequest &src)
  {
   dst.type = src.type;
   dst.price = src.price;
   dst.sl = src.sl;
   dst.tp = src.tp;
   dst.reason = src.reason;
   dst.symbol_slot = src.symbol_slot;
   dst.expiration_seconds = src.expiration_seconds;
  }

void Strategy_ResetPattern(StrategyPattern &pattern)
  {
   pattern.valid = false;
   pattern.bars = 0;
   pattern.atr = 0.0;
   pattern.upper_now = 0.0;
   pattern.lower_now = 0.0;
   pattern.pattern_amplitude = 0.0;
   pattern.buy_entry = 0.0;
   pattern.sell_entry = 0.0;
   pattern.buy_sl = 0.0;
   pattern.sell_sl = 0.0;
   pattern.buy_tp = 0.0;
   pattern.sell_tp = 0.0;
   pattern.buy_failure_level = 0.0;
   pattern.sell_failure_level = 0.0;
  }

bool Strategy_IsPendingStopType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_RemovePendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

void Strategy_RemoveExpiredPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   const int max_age = strategy_order_valid_bars * h4_seconds;
   if(magic <= 0 || h4_seconds <= 0 || max_age <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;

      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= max_age)
         QM_TM_RemovePendingOrder(ticket, "broadening_pending_expired");
     }
  }

bool Strategy_ReadH4Rates(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, count, rates); // perf-allowed: bounded bespoke broadening-pivot geometry; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   return (copied == count);
  }

bool Strategy_ReadLastClosedH4Close(double &close_price)
  {
   close_price = 0.0;
   MqlRates last_bar[];
   ArraySetAsSeries(last_bar, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, 1, last_bar); // perf-allowed: O(1) closed H4 failure-close read while a position is open; no warmup loop.
   if(copied != 1)
      return false;
   close_price = last_bar[0].close;
   return (close_price > 0.0);
  }

bool Strategy_IsHighPivot(const MqlRates &rates[], const int idx, const int side)
  {
   if(idx < side || idx + side >= ArraySize(rates))
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

bool Strategy_IsLowPivot(const MqlRates &rates[], const int idx, const int side)
  {
   if(idx < side || idx + side >= ArraySize(rates))
      return false;
   const double low = rates[idx].low;
   if(low <= 0.0)
      return false;

   for(int offset = 1; offset <= side; ++offset)
     {
      if(low >= rates[idx - offset].low)
         return false;
      if(low >= rates[idx + offset].low)
         return false;
     }
   return true;
  }

void Strategy_AddPivot(StrategyPivot &pivots[], int &count,
                       const int type, const int idx, const int bars,
                       const MqlRates &rates[])
  {
   if(count >= 256)
      return;
   pivots[count].type = type;
   pivots[count].idx = idx;
   pivots[count].x = (double)(bars - 1 - idx);
   pivots[count].price = (type > 0) ? rates[idx].high : rates[idx].low;
   pivots[count].time = rates[idx].time;
   count++;
  }

void Strategy_CollectRawPivots(const MqlRates &rates[], const int bars,
                               StrategyPivot &raw[], int &raw_count)
  {
   raw_count = 0;
   const int side = strategy_pivot_span;
   for(int idx = bars - 1 - side; idx >= side; --idx)
     {
      const bool is_high = Strategy_IsHighPivot(rates, idx, side);
      const bool is_low = Strategy_IsLowPivot(rates, idx, side);
      if(is_high && !is_low)
         Strategy_AddPivot(raw, raw_count, 1, idx, bars, rates);
      else if(is_low && !is_high)
         Strategy_AddPivot(raw, raw_count, -1, idx, bars, rates);
     }
  }

void Strategy_BuildAlternatingPivots(const StrategyPivot &raw[], const int raw_count,
                                     const double atr, StrategyPivot &alt[], int &alt_count)
  {
   alt_count = 0;
   if(raw_count <= 0 || atr <= 0.0)
      return;

   const double min_swing = strategy_pivot_amplitude_atr * atr;
   for(int i = 0; i < raw_count; ++i)
     {
      if(alt_count <= 0)
        {
         alt[0] = raw[i];
         alt_count = 1;
         continue;
        }

      const int last = alt_count - 1;
      if(raw[i].type == alt[last].type)
        {
         if((raw[i].type > 0 && raw[i].price > alt[last].price) ||
            (raw[i].type < 0 && raw[i].price < alt[last].price))
            alt[last] = raw[i];
         continue;
        }

      if(MathAbs(raw[i].price - alt[last].price) >= min_swing && alt_count < 256)
        {
         alt[alt_count] = raw[i];
         alt_count++;
        }
     }
  }

double Strategy_LineSlope(const StrategyPivot &a, const StrategyPivot &b)
  {
   const double dx = b.x - a.x;
   if(MathAbs(dx) <= 0.0)
      return 0.0;
   return (b.price - a.price) / dx;
  }

double Strategy_LineValue(const StrategyPivot &a, const double slope, const double x)
  {
   return a.price + slope * (x - a.x);
  }

bool Strategy_NoPriorBreak(const MqlRates &rates[], const int bars,
                           const StrategyPivot &upper_anchor,
                           const double upper_slope,
                           const StrategyPivot &lower_anchor,
                           const double lower_slope,
                           const double atr)
  {
   const double buffer = strategy_prior_break_atr_buffer * atr;
   for(int idx = bars - 1; idx >= 0; --idx)
     {
      const double x = (double)(bars - 1 - idx);
      const double upper = Strategy_LineValue(upper_anchor, upper_slope, x);
      const double lower = Strategy_LineValue(lower_anchor, lower_slope, x);
      const double close_price = rates[idx].close;
      if(close_price > upper + buffer)
         return false;
      if(close_price < lower - buffer)
         return false;
     }
   return true;
  }

bool Strategy_FinalizePattern(const MqlRates &rates[], const int bars,
                              const StrategyPivot &upper_anchor,
                              const double upper_slope,
                              const StrategyPivot &lower_anchor,
                              const double lower_slope,
                              const double max_high,
                              const double min_low,
                              const double atr,
                              StrategyPattern &pattern)
  {
   const double max_abs_slope = MathMax(MathAbs(upper_slope), MathAbs(lower_slope));
   if(max_abs_slope <= 0.0)
      return false;

   if(upper_slope <= strategy_slope_atr_per_bar_min * atr)
      return false;
   if(lower_slope >= -strategy_slope_atr_per_bar_min * atr)
      return false;

   const double divergence_ratio = MathAbs(upper_slope - lower_slope) / max_abs_slope;
   if(divergence_ratio < strategy_divergence_ratio_min)
      return false;
   if(!Strategy_NoPriorBreak(rates, bars, upper_anchor, upper_slope, lower_anchor, lower_slope, atr))
      return false;

   const double x_now = (double)bars;
   const double upper_now = Strategy_LineValue(upper_anchor, upper_slope, x_now);
   const double lower_now = Strategy_LineValue(lower_anchor, lower_slope, x_now);
   const double amplitude = max_high - min_low;
   if(upper_now <= 0.0 || lower_now <= 0.0 || amplitude <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   pattern.upper_now = upper_now;
   pattern.lower_now = lower_now;
   pattern.pattern_amplitude = amplitude;
   pattern.buy_entry = QM_StopRulesNormalizePrice(_Symbol, upper_now + strategy_entry_atr_buffer * atr);
   pattern.sell_entry = QM_StopRulesNormalizePrice(_Symbol, lower_now - strategy_entry_atr_buffer * atr);
   if(pattern.buy_entry <= ask || pattern.sell_entry >= bid)
      return false;

   double buy_sl = min_low - strategy_sl_atr_buffer * atr;
   double sell_sl = max_high + strategy_sl_atr_buffer * atr;
   if(pattern.buy_entry - buy_sl > strategy_sl_atr_cap * atr)
      buy_sl = pattern.buy_entry - strategy_sl_atr_cap * atr;
   if(sell_sl - pattern.sell_entry > strategy_sl_atr_cap * atr)
      sell_sl = pattern.sell_entry + strategy_sl_atr_cap * atr;

   pattern.buy_sl = QM_StopRulesNormalizePrice(_Symbol, buy_sl);
   pattern.sell_sl = QM_StopRulesNormalizePrice(_Symbol, sell_sl);
   pattern.buy_tp = QM_StopRulesNormalizePrice(_Symbol, pattern.buy_entry + strategy_tp_measured_move * amplitude);
   pattern.sell_tp = QM_StopRulesNormalizePrice(_Symbol, pattern.sell_entry - strategy_tp_measured_move * amplitude);
   pattern.buy_failure_level = QM_StopRulesNormalizePrice(_Symbol, upper_now - strategy_partial_move_scale * amplitude);
   pattern.sell_failure_level = QM_StopRulesNormalizePrice(_Symbol, lower_now + strategy_partial_move_scale * amplitude);

   if(pattern.buy_sl <= 0.0 || pattern.sell_sl <= 0.0 ||
      pattern.buy_tp <= 0.0 || pattern.sell_tp <= 0.0)
      return false;
   if(pattern.buy_sl >= pattern.buy_entry || pattern.buy_tp <= pattern.buy_entry)
      return false;
   if(pattern.sell_sl <= pattern.sell_entry || pattern.sell_tp >= pattern.sell_entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level > 0)
     {
      const double min_dist = stops_level * point;
      if(pattern.buy_entry - ask < min_dist || bid - pattern.sell_entry < min_dist)
         return false;
      if(MathAbs(pattern.buy_entry - pattern.buy_sl) < min_dist ||
         MathAbs(pattern.buy_tp - pattern.buy_entry) < min_dist ||
         MathAbs(pattern.sell_sl - pattern.sell_entry) < min_dist ||
         MathAbs(pattern.sell_entry - pattern.sell_tp) < min_dist)
         return false;
     }

   pattern.valid = true;
   pattern.bars = bars;
   pattern.atr = atr;
   return true;
  }

bool Strategy_EvaluateFivePivots(const StrategyPivot &p0,
                                 const StrategyPivot &p1,
                                 const StrategyPivot &p2,
                                 const StrategyPivot &p3,
                                 const StrategyPivot &p4,
                                 const MqlRates &rates[],
                                 const int bars,
                                 const double atr,
                                 StrategyPattern &pattern)
  {
   const double buffer = strategy_divergence_atr_buffer * atr;
   if(p4.idx > strategy_pivot_recency_bars)
      return false;

   if(p0.type == 1 && p1.type == -1 && p2.type == 1 && p3.type == -1 && p4.type == 1)
     {
      if(p2.price <= p0.price + buffer || p4.price <= p2.price + buffer)
         return false;
      if(p3.price >= p1.price - buffer)
         return false;

      const double upper_slope = Strategy_LineSlope(p0, p4);
      const double lower_slope = Strategy_LineSlope(p1, p3);
      const double max_high = MathMax(p0.price, MathMax(p2.price, p4.price));
      const double min_low = MathMin(p1.price, p3.price);
      return Strategy_FinalizePattern(rates, bars, p0, upper_slope, p1, lower_slope,
                                      max_high, min_low, atr, pattern);
     }

   if(p0.type == -1 && p1.type == 1 && p2.type == -1 && p3.type == 1 && p4.type == -1)
     {
      if(p2.price >= p0.price - buffer || p4.price >= p2.price - buffer)
         return false;
      if(p3.price <= p1.price + buffer)
         return false;

      const double upper_slope = Strategy_LineSlope(p1, p3);
      const double lower_slope = Strategy_LineSlope(p0, p4);
      const double max_high = MathMax(p1.price, p3.price);
      const double min_low = MathMin(p0.price, MathMin(p2.price, p4.price));
      return Strategy_FinalizePattern(rates, bars, p1, upper_slope, p0, lower_slope,
                                      max_high, min_low, atr, pattern);
     }

   return false;
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

bool Strategy_VolatilityRegimePass()
  {
   if(strategy_d1_atr_median_bars <= 0 ||
      strategy_d1_atr_ratio_min <= 0.0 ||
      strategy_d1_atr_ratio_max <= strategy_d1_atr_ratio_min)
      return false;

   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   double values[];
   ArrayResize(values, strategy_d1_atr_median_bars);
   for(int shift = 1; shift <= strategy_d1_atr_median_bars; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      if(atr <= 0.0)
         return false;
      values[shift - 1] = atr;
     }

   Strategy_SortDoubles(values);
   const int n = ArraySize(values);
   double median = 0.0;
   if((n % 2) == 1)
      median = values[n / 2];
   else
      median = 0.5 * (values[n / 2 - 1] + values[n / 2]);

   if(median <= 0.0)
      return false;

   const double ratio = current_atr / median;
   return (ratio >= strategy_d1_atr_ratio_min && ratio <= strategy_d1_atr_ratio_max);
  }

bool Strategy_CustomNewsBlocksEntry()
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

bool Strategy_FindPattern(StrategyPattern &pattern)
  {
   Strategy_ResetPattern(pattern);
   if(strategy_atr_period <= 0 || strategy_pivot_span != 2)
      return false;

   int min_bars = strategy_pattern_min_bars;
   int max_bars = strategy_pattern_max_bars;
   if(min_bars < 50)
      min_bars = 50;
   if(max_bars > 150)
      max_bars = 150;
   if(max_bars < min_bars)
      return false;

   const int history_bars = max_bars + strategy_pivot_span + 4;
   MqlRates rates[];
   if(!Strategy_ReadH4Rates(rates, history_bars))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   for(int bars = min_bars; bars <= max_bars; ++bars)
     {
      StrategyPivot raw[256];
      StrategyPivot alt[256];
      int raw_count = 0;
      int alt_count = 0;

      Strategy_CollectRawPivots(rates, bars, raw, raw_count);
      Strategy_BuildAlternatingPivots(raw, raw_count, atr, alt, alt_count);
      if(alt_count < 5)
         continue;

      StrategyPattern candidate;
      Strategy_ResetPattern(candidate);
      if(Strategy_EvaluateFivePivots(alt[alt_count - 5],
                                     alt[alt_count - 4],
                                     alt[alt_count - 3],
                                     alt[alt_count - 2],
                                     alt[alt_count - 1],
                                     rates,
                                     bars,
                                     atr,
                                     candidate))
        {
         pattern = candidate;
         return true;
        }
     }

   return false;
  }

bool Strategy_BuildStopRequest(const QM_OrderType type,
                               const double entry,
                               const double sl,
                               const double tp,
                               const int expiry_seconds,
                               const string reason,
                               QM_EntryRequest &req)
  {
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = type;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiry_seconds;

   if(req.type == QM_BUY_STOP)
      return (req.sl < req.price && req.tp > req.price);
   if(req.type == QM_SELL_STOP)
      return (req.sl > req.price && req.tp < req.price);
   return false;
  }

void Strategy_RegisterLifecycle(const StrategyPattern &pattern)
  {
   g_lifecycle_active = true;
   g_partial_done = false;
   g_partial_ticket = 0;
   g_active_pattern_amp = pattern.pattern_amplitude;
   g_active_buy_failure = pattern.buy_failure_level;
   g_active_sell_failure = pattern.sell_failure_level;
  }

void Strategy_MarkLifecycleDone()
  {
   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds > 0 && strategy_reuse_guard_bars > 0)
      g_pattern_reuse_until = TimeCurrent() + strategy_reuse_guard_bars * h4_seconds;

   g_lifecycle_active = false;
   g_partial_done = false;
   g_partial_ticket = 0;
   g_active_pattern_amp = 0.0;
   g_active_buy_failure = 0.0;
   g_active_sell_failure = 0.0;
  }

double Strategy_PositionPatternAmplitude(const double open_price, const double tp_price)
  {
   if(g_active_pattern_amp > 0.0)
      return g_active_pattern_amp;
   if(open_price <= 0.0 || tp_price <= 0.0 || strategy_tp_measured_move <= 0.0)
      return 0.0;
   return MathAbs(tp_price - open_price) / strategy_tp_measured_move;
  }

// No Trade Filter (time, spread, news): spread blocks new entries only.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition() || Strategy_HasPendingStops())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_spread_atr_max <= 0.0)
      return false;

   if(ask > bid && (ask - bid) > strategy_spread_atr_max * atr)
      return true;

   return false;
  }

// Trade Entry: 5-pivot broadening formation with OCO buy-stop/sell-stop.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return false;
   if(Strategy_HasOpenPosition() || Strategy_HasPendingStops())
      return false;
   if(g_pattern_reuse_until > 0 && TimeCurrent() < g_pattern_reuse_until)
      return false;
   if(Strategy_CustomNewsBlocksEntry())
      return false;
   if(!Strategy_VolatilityRegimePass())
      return false;

   StrategyPattern pattern;
   if(!Strategy_FindPattern(pattern) || !pattern.valid)
      return false;

   const int expiry_seconds = strategy_order_valid_bars * PeriodSeconds(PERIOD_H4);
   if(expiry_seconds <= 0)
      return false;

   QM_EntryRequest buy_req;
   QM_EntryRequest sell_req;
   if(!Strategy_BuildStopRequest(QM_BUY_STOP, pattern.buy_entry, pattern.buy_sl,
                                 pattern.buy_tp, expiry_seconds,
                                 "BROADENING_BUY_STOP", buy_req))
      return false;
   if(!Strategy_BuildStopRequest(QM_SELL_STOP, pattern.sell_entry, pattern.sell_sl,
                                 pattern.sell_tp, expiry_seconds,
                                 "BROADENING_SELL_STOP", sell_req))
      return false;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   Strategy_AssignRequest(req, sell_req);
   Strategy_RegisterLifecycle(pattern);
   return true;
  }

// Trade Management: OCO cleanup, partial close at 50% measured move, BE shift.
void Strategy_ManageOpenPosition()
  {
   Strategy_RemoveExpiredPendingStops();

   const bool has_open = Strategy_HasOpenPosition();
   if(has_open)
      Strategy_RemovePendingStops("oco_peer_cancel_after_fill");

   if(!has_open)
     {
      if(g_lifecycle_active && !Strategy_HasPendingStops())
         Strategy_MarkLifecycleDone();
      return;
     }

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(magic <= 0 || point <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double tp_price = PositionGetDouble(POSITION_TP);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || current_sl <= 0.0 || tp_price <= 0.0 ||
         volume <= 0.0 || market <= 0.0)
         continue;

      if(g_partial_ticket != ticket)
        {
         g_partial_ticket = ticket;
         g_partial_done = is_buy ? (current_sl >= open_price - point * 0.5)
                                 : (current_sl <= open_price + point * 0.5);
        }
      if(g_partial_done)
         continue;

      const double amplitude = Strategy_PositionPatternAmplitude(open_price, tp_price);
      if(amplitude <= 0.0)
         continue;

      const double trigger = is_buy ? (open_price + strategy_partial_move_scale * amplitude)
                                    : (open_price - strategy_partial_move_scale * amplitude);
      if((is_buy && market < trigger) || (!is_buy && market > trigger))
         continue;

      const double lots_to_close = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_close_fraction);
      bool partial_ok = false;
      if(lots_to_close > 0.0 && lots_to_close < volume)
         partial_ok = QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL);

      if(partial_ok || lots_to_close <= 0.0 || lots_to_close >= volume)
        {
         QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "broadening_partial_be");
         g_partial_done = true;
        }
     }
  }

// Trade Close: pattern-failure hard exit and 35-H4-bar time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(magic <= 0 || h4_seconds <= 0)
      return false;

   double last_close = 0.0;
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0)
         continue;
      const int bars_open = (int)((now - open_time) / h4_seconds);
      if(bars_open >= strategy_time_stop_bars)
         return true;

      if(bars_open <= strategy_failure_exit_bars)
        {
         if(last_close <= 0.0 && !Strategy_ReadLastClosedH4Close(last_close))
            continue;

         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         const double tp_price = PositionGetDouble(POSITION_TP);
         const double amplitude = Strategy_PositionPatternAmplitude(open_price, tp_price);
         if(amplitude <= 0.0)
            continue;

         double buy_failure = g_active_buy_failure;
         double sell_failure = g_active_sell_failure;
         if(buy_failure <= 0.0)
            buy_failure = open_price - strategy_partial_move_scale * amplitude;
         if(sell_failure <= 0.0)
            sell_failure = open_price + strategy_partial_move_scale * amplitude;

         if(ptype == POSITION_TYPE_BUY && last_close < buy_failure)
            return true;
         if(ptype == POSITION_TYPE_SELL && last_close > sell_failure)
            return true;
        }
     }

   return false;
  }

// News Filter Hook: callable for P8; entry-only custom blackout lives in EntrySignal.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1422\",\"ea\":\"classical-broadening-formation-h4\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows - the news gate below blocks NEW entries
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(Strategy_NewsFilterHook(broker_now))
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
