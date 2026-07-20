#ifndef QM5_20009_ICT_LIQUIDITY_RULES_MQH
#define QM5_20009_ICT_LIQUIDITY_RULES_MQH

// Pure, closed-bar primitives for QM5_20009.  The including EA must include
// QM_Common.mqh first so the canonical broker/UTC and US-DST helpers exist.

enum ICT_StrategyMode
  {
   ICT_MODE_INDEX_MSS_FVG       = 0,
   ICT_MODE_FX_SESSION_SWEEP    = 1
  };

enum ICT_SessionKind
  {
   ICT_SESSION_NONE             = 0,
   ICT_SESSION_INDEX_AM         = 1,
   ICT_SESSION_LONDON           = 2,
   ICT_SESSION_NEW_YORK         = 3
  };

struct ICT_LevelRange
  {
   bool   valid;
   double high;
   double low;
   int    bars;
   uint   fingerprint;
  };

struct ICT_SequenceResult
  {
   bool            consumed;
   bool            ambiguous;
   bool            signal_valid;
   int             direction;
   ICT_SessionKind session;
   int             budget_key;
   int             ny_date_key;
   datetime        event_bar_time;
   datetime        penetration_bar_time;
   datetime        reclaim_bar_time;
   datetime        mss_bar_time;
   datetime        fvg_bar_time;
   double          swept_extreme;
   double          pivot_price;
   double          entry;
   double          stop;
   double          target;
   double          atr;
   double          observed_spread;
   int             session_end_minute;
   uint            frozen_level_hash;
   uint            reference_hash;
   string          outcome;
  };

void ICT_ResetRange(ICT_LevelRange &range)
  {
   range.valid = false;
   range.high = 0.0;
   range.low = 0.0;
   range.bars = 0;
   range.fingerprint = 0;
  }

void ICT_ResetSequence(ICT_SequenceResult &result)
  {
   result.consumed = false;
   result.ambiguous = false;
   result.signal_valid = false;
   result.direction = 0;
   result.session = ICT_SESSION_NONE;
   result.budget_key = 0;
   result.ny_date_key = 0;
   result.event_bar_time = 0;
   result.penetration_bar_time = 0;
   result.reclaim_bar_time = 0;
   result.mss_bar_time = 0;
   result.fvg_bar_time = 0;
   result.swept_extreme = 0.0;
   result.pivot_price = 0.0;
   result.entry = 0.0;
   result.stop = 0.0;
   result.target = 0.0;
   result.atr = 0.0;
   result.observed_spread = 0.0;
   result.session_end_minute = 0;
   result.frozen_level_hash = 0;
   result.reference_hash = 0;
   result.outcome = "NO_EVENT";
  }

datetime ICT_BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return utc_time + (QM_IsUSDSTUTC(utc_time) ? -4 : -5) * 3600;
  }

int ICT_DateKeyFromNY(const datetime ny_time)
  {
   MqlDateTime value;
   ZeroMemory(value);
   TimeToStruct(ny_time, value);
   return value.year * 10000 + value.mon * 100 + value.day;
  }

int ICT_NYDateKey(const datetime broker_time)
  {
   return ICT_DateKeyFromNY(ICT_BrokerToNewYork(broker_time));
  }

int ICT_NYMinute(const datetime broker_time)
  {
   MqlDateTime value;
   ZeroMemory(value);
   TimeToStruct(ICT_BrokerToNewYork(broker_time), value);
   return value.hour * 60 + value.min;
  }

int ICT_ShiftDateKey(const int date_key, const int days)
  {
   MqlDateTime value;
   ZeroMemory(value);
   value.year = date_key / 10000;
   value.mon = (date_key / 100) % 100;
   value.day = date_key % 100;
   value.hour = 12; // noon avoids edge behaviour in the synthetic NY wall clock.
   const datetime shifted = StructToTime(value) + days * 86400;
   return ICT_DateKeyFromNY(shifted);
  }

uint ICT_HashMix(const uint current, const uint value)
  {
   return (current ^ value) * 16777619;
  }

uint ICT_RangeFingerprint(const int key,
                          const int bars,
                          const double low,
                          const double high,
                          const double tick_size)
  {
   const double unit = (tick_size > 0.0) ? tick_size : 0.00000001;
   const long low_ticks = (long)MathRound(low / unit);
   const long high_ticks = (long)MathRound(high / unit);
   uint hash = 2166136261;
   hash = ICT_HashMix(hash, (uint)key);
   hash = ICT_HashMix(hash, (uint)bars);
   hash = ICT_HashMix(hash, (uint)(low_ticks & 0xffffffff));
   hash = ICT_HashMix(hash, (uint)(high_ticks & 0xffffffff));
   return hash;
  }

bool ICT_CollectNYRangeBounded(const MqlRates &rates[],
                               const int count,
                               const int scan_first_index,
                               const int scan_last_index,
                               const int ny_date_key,
                               const int start_minute,
                               const int end_minute,
                               const int expected_bars,
                               const double tick_size,
                               ICT_LevelRange &range)
  {
   ICT_ResetRange(range);
   const int first = MathMax(0, scan_first_index);
   const int last = MathMin(count - 1, scan_last_index);
   for(int i = first; i <= last; ++i)
     {
      if(ICT_NYDateKey(rates[i].time) != ny_date_key)
         continue;
      const int minute = ICT_NYMinute(rates[i].time);
      if(minute < start_minute || minute >= end_minute)
         continue;
      if(range.bars == 0)
        {
         range.high = rates[i].high;
         range.low = rates[i].low;
        }
      else
        {
         range.high = MathMax(range.high, rates[i].high);
         range.low = MathMin(range.low, rates[i].low);
        }
      ++range.bars;
     }

   // "Complete" is intentionally exact: a missing M1/M5 bar invalidates the
   // frozen reference instead of silently changing its statistical meaning.
   range.valid = (range.bars == expected_bars && range.high > range.low);
   if(range.valid)
      range.fingerprint = ICT_RangeFingerprint(ny_date_key,
                                               range.bars,
                                               range.low,
                                               range.high,
                                               tick_size);
   return range.valid;
  }

bool ICT_CollectNYRange(const MqlRates &rates[],
                        const int count,
                        const int ny_date_key,
                        const int start_minute,
                        const int end_minute,
                        const int expected_bars,
                        const double tick_size,
                        ICT_LevelRange &range)
  {
   return ICT_CollectNYRangeBounded(rates,
                                    count,
                                    0,
                                    count - 1,
                                    ny_date_key,
                                    start_minute,
                                    end_minute,
                                    expected_bars,
                                    tick_size,
                                    range);
  }

bool ICT_StrictPivotHigh(const MqlRates &rates[],
                         const int count,
                         const int index,
                         const int wing)
  {
   if(wing < 1 || index - wing < 0 || index + wing >= count)
      return false;
   for(int distance = 1; distance <= wing; ++distance)
      if(rates[index].high <= rates[index - distance].high ||
         rates[index].high <= rates[index + distance].high)
         return false;
   return true;
  }

bool ICT_StrictPivotLow(const MqlRates &rates[],
                        const int count,
                        const int index,
                        const int wing)
  {
   if(wing < 1 || index - wing < 0 || index + wing >= count)
      return false;
   for(int distance = 1; distance <= wing; ++distance)
      if(rates[index].low >= rates[index - distance].low ||
         rates[index].low >= rates[index + distance].low)
         return false;
   return true;
  }

int ICT_LatestPrePenetrationPivot(const MqlRates &rates[],
                                  const int count,
                                  const int penetration_index,
                                  const int wing,
                                  const bool want_high,
                                  const int history_first_index)
  {
   // The pivot's right wing must be closed before, not on, the penetration bar.
   const int first_pivot = MathMax(wing, history_first_index + wing);
   for(int i = penetration_index - wing - 1; i >= first_pivot; --i)
     {
      const bool found = want_high ? ICT_StrictPivotHigh(rates, count, i, wing)
                                   : ICT_StrictPivotLow(rates, count, i, wing);
      if(found)
         return i;
     }
   return -1;
  }

// Frozen v2 volatility definition: arithmetic mean of the latest 14 causal
// true ranges (SMA-TR14). This is intentionally not Wilder-smoothed ATR.
bool ICT_SMA_TR14At(const MqlRates &rates[],
                    const int count,
                    const int index,
                    const int history_first_index,
                    double &atr)
  {
   atr = 0.0;
   if(index - history_first_index < 14 || index >= count)
      return false;
   for(int i = index - 13; i <= index; ++i)
     {
      const double previous_close = rates[i - 1].close;
      const double true_range = MathMax(rates[i].high - rates[i].low,
                               MathMax(MathAbs(rates[i].high - previous_close),
                                       MathAbs(rates[i].low - previous_close)));
      if(true_range < 0.0 || !MathIsValidNumber(true_range))
         return false;
      atr += true_range;
     }
   atr /= 14.0;
   return atr > 0.0 && MathIsValidNumber(atr);
  }

bool ICT_IsEventBarInSession(const MqlRates &bar,
                             const int ny_date_key,
                             const int start_minute,
                             const int end_minute,
                             const int timeframe_seconds)
  {
   if(ICT_NYDateKey(bar.time) != ny_date_key)
      return false;
   const datetime close_time = bar.time + timeframe_seconds;
   if(ICT_NYDateKey(close_time) != ny_date_key)
      return false;
   const int open_minute = ICT_NYMinute(bar.time);
   const int close_minute = ICT_NYMinute(close_time);
   // Decisions happen only after close, so a bar closing exactly at the
   // half-open end is not an in-session event.
   return open_minute >= start_minute && close_minute < end_minute;
  }

bool ICT_FindReclaim(const MqlRates &rates[],
                     const int count,
                     const int penetration_index,
                     const int direction,
                     const double frozen_low,
                     const double frozen_high,
                     const int reclaim_bars,
                     const int ny_date_key,
                     const int session_start_minute,
                     const int session_end_minute,
                     const int timeframe_seconds,
                     const int event_last_index,
                     int &reclaim_index,
                     double &swept_extreme)
  {
   reclaim_index = -1;
   swept_extreme = (direction > 0) ? rates[penetration_index].low
                                   : rates[penetration_index].high;
   const int last = MathMin(MathMin(count - 1, event_last_index),
                            penetration_index + reclaim_bars);
   for(int i = penetration_index; i <= last; ++i)
     {
      if(!ICT_IsEventBarInSession(rates[i],
                                  ny_date_key,
                                  session_start_minute,
                                  session_end_minute,
                                  timeframe_seconds))
         break;
      if(direction > 0)
        {
         swept_extreme = MathMin(swept_extreme, rates[i].low);
         if(rates[i].close > frozen_low)
           {
            reclaim_index = i;
            return true;
           }
        }
      else
        {
         swept_extreme = MathMax(swept_extreme, rates[i].high);
         if(rates[i].close < frozen_high)
           {
            reclaim_index = i;
            return true;
           }
        }
     }
   return false;
  }

bool ICT_BuildSequence(const MqlRates &rates[],
                       const int count,
                       const int ny_date_key,
                       const int budget_key,
                       const ICT_SessionKind session,
                       const int session_start_minute,
                       const int session_end_minute,
                       const int timeframe_seconds,
                       const double frozen_low,
                       const double frozen_high,
                       const double target_long,
                       const double target_short,
                       const uint frozen_level_hash,
                       const uint reference_hash,
                       const int pivot_wing,
                       const int reclaim_bars,
                       const int max_bars_to_mss,
                       const double min_fvg_atr,
                       const double sl_buffer_atr,
                       const double min_rr,
                       const double tick_size,
                       const double point,
                       ICT_SequenceResult &result,
                       const int event_first_index,
                       const int event_last_index,
                       const int history_first_index)
  {
   ICT_ResetSequence(result);
   result.session = session;
   result.budget_key = budget_key;
   result.ny_date_key = ny_date_key;
   result.session_end_minute = session_end_minute;
   result.frozen_level_hash = frozen_level_hash;
   result.reference_hash = reference_hash;

   const int bounded_history_first = MathMax(0, history_first_index);
   const int bounded_event_first = MathMax(bounded_history_first,
                                           event_first_index);
   const int bounded_event_last = MathMin(count - 1, event_last_index);
   if(count < 20 || bounded_event_first > bounded_event_last ||
      frozen_low <= 0.0 || frozen_high <= frozen_low ||
      target_long <= 0.0 || target_short <= 0.0 || tick_size <= 0.0 || point <= 0.0)
     {
      result.outcome = "INVALID_FROZEN_LEVELS";
      return false;
     }

   int best_penetration = -1;
   int best_reclaim = -1;
   int best_direction = 0;
   double best_extreme = 0.0;

   for(int p = bounded_event_first; p <= bounded_event_last; ++p)
     {
      if(!ICT_IsEventBarInSession(rates[p],
                                  ny_date_key,
                                  session_start_minute,
                                  session_end_minute,
                                  timeframe_seconds))
         continue;

      const bool low_penetration = rates[p].low <= frozen_low - tick_size;
      const bool high_penetration = rates[p].high >= frozen_high + tick_size;
      if(low_penetration && high_penetration)
        {
         // A double-side penetration is an event immediately; it outranks any
         // candidate whose reclaim would only occur on a later bar.
         if(best_reclaim < 0 || p <= best_reclaim)
           {
            result.consumed = true;
            result.ambiguous = true;
            result.event_bar_time = rates[p].time;
            result.penetration_bar_time = rates[p].time;
            result.outcome = "AMBIGUOUS_DOUBLE_PENETRATION";
            return false;
           }
         break;
        }

      for(int side = 0; side < 2; ++side)
        {
         const int direction = (side == 0) ? 1 : -1;
         if((direction > 0 && !low_penetration) ||
            (direction < 0 && !high_penetration))
            continue;

         int reclaim_index = -1;
         double swept_extreme = 0.0;
         if(!ICT_FindReclaim(rates,
                             count,
                             p,
                             direction,
                             frozen_low,
                             frozen_high,
                             reclaim_bars,
                             ny_date_key,
                             session_start_minute,
                             session_end_minute,
                             timeframe_seconds,
                             bounded_event_last,
                             reclaim_index,
                             swept_extreme))
            continue;

         if(best_reclaim < 0 || reclaim_index < best_reclaim)
           {
            best_penetration = p;
            best_reclaim = reclaim_index;
            best_direction = direction;
            best_extreme = swept_extreme;
           }
         else if(reclaim_index == best_reclaim && direction != best_direction)
           {
            result.consumed = true;
            result.ambiguous = true;
            result.event_bar_time = rates[reclaim_index].time;
            result.reclaim_bar_time = rates[reclaim_index].time;
            result.outcome = "AMBIGUOUS_RECLAIM_TIE";
            return false;
           }
        }
     }

   if(best_reclaim < 0)
      return false;

   result.consumed = true; // the first chronological eligible reclaim owns budget.
   result.direction = best_direction;
   result.event_bar_time = rates[best_reclaim].time;
   result.penetration_bar_time = rates[best_penetration].time;
   result.reclaim_bar_time = rates[best_reclaim].time;
   result.swept_extreme = best_extreme;
   result.outcome = "RECLAIM_CONSUMED";

   const int pivot_index = ICT_LatestPrePenetrationPivot(rates,
                                                          count,
                                                          best_penetration,
                                                          pivot_wing,
                                                          best_direction > 0,
                                                          bounded_history_first);
   if(pivot_index < 0)
     {
      result.outcome = "NO_CONFIRMED_PRE_SWEEP_PIVOT";
      return false;
     }
   result.pivot_price = (best_direction > 0) ? rates[pivot_index].high
                                             : rates[pivot_index].low;

   int mss_index = -1;
   const int last_mss = MathMin(bounded_event_last,
                                best_reclaim + max_bars_to_mss);
   for(int i = best_reclaim + 1; i <= last_mss; ++i)
     {
      if(!ICT_IsEventBarInSession(rates[i],
                                  ny_date_key,
                                  session_start_minute,
                                  session_end_minute,
                                  timeframe_seconds))
         break;
      const bool shifted = (best_direction > 0)
                           ? rates[i].close > result.pivot_price
                           : rates[i].close < result.pivot_price;
      if(shifted)
        {
         mss_index = i;
         break;
        }
     }
   if(mss_index < 0)
     {
      result.outcome = "NO_LATER_MSS";
      return false;
     }
   result.mss_bar_time = rates[mss_index].time;

   int fvg_index = -1;
   double proximal_edge = 0.0;
   double fvg_atr = 0.0;
   for(int i = mss_index + 1; i <= bounded_event_last; ++i)
     {
      if(!ICT_IsEventBarInSession(rates[i],
                                  ny_date_key,
                                  session_start_minute,
                                  session_end_minute,
                                  timeframe_seconds))
         break;
       if(i - bounded_history_first < 2 ||
          !ICT_SMA_TR14At(rates,
                          count,
                          i,
                          bounded_history_first,
                          fvg_atr))
          continue;

       const double gap = (best_direction > 0)
                          ? rates[i].low - rates[i - 2].high
                          : rates[i - 2].low - rates[i].high;
       const double minimum_gap = min_fvg_atr * fvg_atr;
       const double comparison_epsilon =
          MathMax(1.0, MathAbs(minimum_gap)) * 1e-12;
       if(gap <= 0.0 || gap + comparison_epsilon < minimum_gap)
          continue;

      fvg_index = i;
      // Proximal means the edge first met by a retracement from displacement.
      proximal_edge = (best_direction > 0) ? rates[i].low : rates[i].high;
      break;
     }
   if(fvg_index < 0)
     {
      result.outcome = "NO_POST_MSS_FVG";
      return false;
     }

   double observed_spread = 0.0;
   for(int i = best_penetration; i <= fvg_index; ++i)
      observed_spread = MathMax(observed_spread, (double)rates[i].spread * point);
   const double stop_padding = MathMax(2.0 * observed_spread,
                                       sl_buffer_atr * fvg_atr);
   const double stop = (best_direction > 0) ? best_extreme - stop_padding
                                            : best_extreme + stop_padding;
   const double target = (best_direction > 0) ? target_long : target_short;
   const double risk = MathAbs(proximal_edge - stop);
   const double reward = (best_direction > 0) ? target - proximal_edge
                                              : proximal_edge - target;

   result.fvg_bar_time = rates[fvg_index].time;
   result.entry = proximal_edge;
   result.stop = stop;
   result.target = target;
   result.atr = fvg_atr;
   result.observed_spread = observed_spread;
   if(risk <= 0.0 || reward <= 0.0 || reward / risk + 1e-12 < min_rr)
     {
      result.outcome = "INVALID_FIXED_TARGET_OR_R";
      return false;
     }

   result.signal_valid = true;
   result.outcome = "EARLIEST_FVG_READY";
   return true;
  }

#endif // QM5_20009_ICT_LIQUIDITY_RULES_MQH
