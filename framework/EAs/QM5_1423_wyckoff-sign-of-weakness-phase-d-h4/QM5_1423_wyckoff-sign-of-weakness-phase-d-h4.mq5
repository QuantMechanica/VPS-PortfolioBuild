#property strict
#property version   "5.0"
#property description "QM5_1423 Wyckoff Sign of Weakness Distribution Phase D H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1423;
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
input int    strategy_atr_period                    = 14;
input int    strategy_range_lookback_bars            = 200;
input int    strategy_pivot_min_lookback_bars        = 80;
input int    strategy_range_duration_min_bars        = 60;
input double strategy_range_min_atr                  = 4.0;
input double strategy_range_max_atr                  = 12.0;
input double strategy_range_containment_pct          = 0.85;
input double strategy_range_containment_atr          = 0.5;
input int    strategy_prerange_slope_bars            = 80;
input double strategy_prerange_slope_atr_per_bar     = 0.10;
input int    strategy_utad_recent_bars               = 30;
input double strategy_utad_break_atr                 = 0.5;
input double strategy_sow_low_break_atr              = 0.5;
input double strategy_sow_first_break_atr            = 0.3;
input double strategy_sow_wide_spread_atr            = 1.5;
input double strategy_sow_close_near_low_pct         = 0.30;
input bool   strategy_volume_filter_enabled          = true;
input int    strategy_volume_mean_bars               = 20;
input double strategy_volume_mult                    = 1.30;
input double strategy_measured_move_mult             = 1.0;
input double strategy_partial_move_pct               = 0.50;
input double strategy_sl_utad_atr_buffer             = 0.40;
input double strategy_sl_max_atr                     = 4.0;
input int    strategy_time_stop_h4_bars              = 40;
input int    strategy_reuse_guard_h4_bars            = 60;
input bool   strategy_sequence_guard_enabled         = true;
input int    strategy_sequence_guard_h4_bars         = 80;
input double strategy_spread_max_atr                 = 0.20;
input int    strategy_macro_sma_period               = 200;
input int    strategy_macro_slope_bars               = 20;
input double strategy_macro_slope_atr_per_bar        = 0.05;
input int    strategy_news_pause_h4_bars             = 2;

struct WyckoffSetup
  {
   double   upper;
   double   lower;
   double   range_size;
   double   utad_high;
   datetime signal_bar_time;
  };

bool     g_pending_setup_valid = false;
double   g_pending_upper = 0.0;
double   g_pending_lower = 0.0;
double   g_pending_range = 0.0;
double   g_pending_utad_high = 0.0;
datetime g_pending_signal_time = 0;
datetime g_pattern_block_until = 0;

int RateIndex(const int shift, const int total)
  {
   if(shift < 1 || shift > total)
      return -1;
   return total - shift;
  }

double RateOpen(const MqlRates &rates[], const int total, const int shift)
  {
   const int idx = RateIndex(shift, total);
   return (idx >= 0) ? rates[idx].open : 0.0;
  }

double RateHigh(const MqlRates &rates[], const int total, const int shift)
  {
   const int idx = RateIndex(shift, total);
   return (idx >= 0) ? rates[idx].high : 0.0;
  }

double RateLow(const MqlRates &rates[], const int total, const int shift)
  {
   const int idx = RateIndex(shift, total);
   return (idx >= 0) ? rates[idx].low : 0.0;
  }

double RateClose(const MqlRates &rates[], const int total, const int shift)
  {
   const int idx = RateIndex(shift, total);
   return (idx >= 0) ? rates[idx].close : 0.0;
  }

long RateTickVolume(const MqlRates &rates[], const int total, const int shift)
  {
   const int idx = RateIndex(shift, total);
   return (idx >= 0) ? rates[idx].tick_volume : 0;
  }

datetime RateTime(const MqlRates &rates[], const int total, const int shift)
  {
   const int idx = RateIndex(shift, total);
   return (idx >= 0) ? rates[idx].time : 0;
  }

bool IsPivotHigh5(const MqlRates &rates[], const int total, const int shift)
  {
   if(shift < 3 || shift + 2 > total)
      return false;
   const double h = RateHigh(rates, total, shift);
   return (h > 0.0 &&
           h > RateHigh(rates, total, shift - 1) &&
           h > RateHigh(rates, total, shift - 2) &&
           h > RateHigh(rates, total, shift + 1) &&
           h > RateHigh(rates, total, shift + 2));
  }

bool IsPivotLow5(const MqlRates &rates[], const int total, const int shift)
  {
   if(shift < 3 || shift + 2 > total)
      return false;
   const double l = RateLow(rates, total, shift);
   return (l > 0.0 &&
           l < RateLow(rates, total, shift - 1) &&
           l < RateLow(rates, total, shift - 2) &&
           l < RateLow(rates, total, shift + 1) &&
           l < RateLow(rates, total, shift + 2));
  }

void InsertTop4(const double value, const int shift, double &values[], int &shifts[])
  {
   int replace = 0;
   double min_value = values[0];
   for(int i = 1; i < 4; ++i)
     {
      if(values[i] < min_value)
        {
         min_value = values[i];
         replace = i;
        }
     }
   if(value > min_value)
     {
      values[replace] = value;
      shifts[replace] = shift;
     }
  }

void InsertBottom4(const double value, const int shift, double &values[], int &shifts[])
  {
   int replace = 0;
   double max_value = values[0];
   for(int i = 1; i < 4; ++i)
     {
      if(values[i] > max_value)
        {
         max_value = values[i];
         replace = i;
        }
     }
   if(value < max_value)
     {
      values[replace] = value;
      shifts[replace] = shift;
     }
  }

bool FourValuesReady(const double &values[], const bool top_values)
  {
   for(int i = 0; i < 4; ++i)
     {
      if(top_values && values[i] <= -DBL_MAX * 0.5)
         return false;
      if(!top_values && values[i] >= DBL_MAX * 0.5)
         return false;
     }
   return true;
  }

double MedianOfFour(const double &values[])
  {
   double work[4];
   for(int i = 0; i < 4; ++i)
      work[i] = values[i];
   for(int i = 0; i < 3; ++i)
     {
      for(int j = i + 1; j < 4; ++j)
        {
         if(work[j] < work[i])
           {
            const double tmp = work[i];
            work[i] = work[j];
            work[j] = tmp;
           }
        }
     }
   return 0.5 * (work[1] + work[2]);
  }

bool LinearRegressionSlopeBeforeRange(const MqlRates &rates[],
                                      const int total,
                                      const int range_start_shift,
                                      const int slope_bars,
                                      double &out_slope)
  {
   out_slope = 0.0;
   if(range_start_shift <= 0 || slope_bars < 2 || range_start_shift + slope_bars > total)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   for(int i = 0; i < slope_bars; ++i)
     {
      const int shift = range_start_shift + slope_bars - i;
      const double close_price = RateClose(rates, total, shift);
      if(close_price <= 0.0)
         return false;
      const double x = (double)i;
      sum_x += x;
      sum_y += close_price;
      sum_xx += x * x;
      sum_xy += x * close_price;
     }

   const double n = (double)slope_bars;
   const double denom = (n * sum_xx) - (sum_x * sum_x);
   if(MathAbs(denom) <= 0.0)
      return false;
   out_slope = ((n * sum_xy) - (sum_x * sum_y)) / denom;
   return true;
  }

bool VolumeIsReliableForSymbol()
  {
   string sym = _Symbol;
   StringToUpper(sym);
   const int dot = StringFind(sym, ".");
   if(dot > 0)
      sym = StringSubstr(sym, 0, dot);

   if(sym == "XAUUSD" || sym == "XTIUSD" || sym == "NDX" || sym == "WS30")
      return true;
   if(StringLen(sym) == 6)
     {
      const string base = StringSubstr(sym, 0, 3);
      const string quote = StringSubstr(sym, 3, 3);
      if(base == "USD" || quote == "USD")
         return true;
     }
   return false;
  }

bool VolumeGatePasses(const MqlRates &rates[], const int total)
  {
   if(!strategy_volume_filter_enabled || !VolumeIsReliableForSymbol())
      return true;
   if(strategy_volume_mean_bars < 1 || 1 + strategy_volume_mean_bars > total)
      return false;

   const long current_volume = RateTickVolume(rates, total, 1);
   if(current_volume <= 0)
      return false;

   double volume_sum = 0.0;
   for(int shift = 2; shift <= strategy_volume_mean_bars + 1; ++shift)
     {
      const long v = RateTickVolume(rates, total, shift);
      if(v <= 0)
         return false;
      volume_sum += (double)v;
     }

   const double mean_volume = volume_sum / (double)strategy_volume_mean_bars;
   return ((double)current_volume >= strategy_volume_mult * mean_volume);
  }

bool MacroBiasAllowsShort()
  {
   if(strategy_macro_sma_period <= 1 || strategy_macro_slope_bars < 1)
      return false;

   const double sma_now = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1, PRICE_CLOSE);
   const double sma_then = QM_SMA(_Symbol, PERIOD_D1, strategy_macro_sma_period, 1 + strategy_macro_slope_bars, PRICE_CLOSE);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma_now <= 0.0 || sma_then <= 0.0 || atr_d1 <= 0.0)
      return false;

   const double slope = (sma_now - sma_then) / (double)strategy_macro_slope_bars;
   return (slope <= strategy_macro_slope_atr_per_bar * atr_d1);
  }

bool NewsPauseAllowsEntry()
  {
   if(strategy_news_pause_h4_bars <= 0)
      return true;
   const int seconds = PeriodSeconds(PERIOD_H4);
   if(seconds <= 0)
      return true;
   const int minutes = (strategy_news_pause_h4_bars * seconds) / 60;
   datetime utc_time = QM_BrokerToUTC(TimeCurrent());
   if(utc_time <= 0)
      utc_time = TimeGMT();
   return !QM_NewsInWindow(utc_time, _Symbol, minutes, minutes, qm_news_min_impact);
  }

bool FindTradingRange(const MqlRates &rates[],
                      const int total,
                      const double atr_h4,
                      double &out_upper,
                      double &out_lower,
                      int &out_range_start_shift)
  {
   out_upper = 0.0;
   out_lower = 0.0;
   out_range_start_shift = 0;

   if(strategy_range_lookback_bars < strategy_pivot_min_lookback_bars ||
      strategy_pivot_min_lookback_bars < 10 ||
      strategy_range_lookback_bars + strategy_prerange_slope_bars > total)
      return false;

   double top_highs[4];
   double bottom_lows[4];
   int top_shifts[4];
   int bottom_shifts[4];
   for(int i = 0; i < 4; ++i)
     {
      top_highs[i] = -DBL_MAX;
      bottom_lows[i] = DBL_MAX;
      top_shifts[i] = -1;
      bottom_shifts[i] = -1;
     }

   for(int shift = 3; shift <= strategy_range_lookback_bars - 2; ++shift)
     {
      if(IsPivotHigh5(rates, total, shift))
         InsertTop4(RateHigh(rates, total, shift), shift, top_highs, top_shifts);
      if(IsPivotLow5(rates, total, shift))
         InsertBottom4(RateLow(rates, total, shift), shift, bottom_lows, bottom_shifts);
     }

   if(!FourValuesReady(top_highs, true) || !FourValuesReady(bottom_lows, false))
      return false;

   out_upper = MedianOfFour(top_highs);
   out_lower = MedianOfFour(bottom_lows);
   if(out_upper <= out_lower)
      return false;

   const double range_size = out_upper - out_lower;
   if(range_size < strategy_range_min_atr * atr_h4 || range_size > strategy_range_max_atr * atr_h4)
      return false;

   int earliest_shift = 0;
   int latest_shift = strategy_range_lookback_bars;
   for(int i = 0; i < 4; ++i)
     {
      earliest_shift = MathMax(earliest_shift, top_shifts[i]);
      earliest_shift = MathMax(earliest_shift, bottom_shifts[i]);
      latest_shift = MathMin(latest_shift, top_shifts[i]);
      latest_shift = MathMin(latest_shift, bottom_shifts[i]);
     }
   if(earliest_shift - latest_shift < strategy_range_duration_min_bars)
      return false;
   if(earliest_shift < strategy_pivot_min_lookback_bars)
      return false;

   int contained = 0;
   int samples = 0;
   const double contain_low = out_lower - strategy_range_containment_atr * atr_h4;
   const double contain_high = out_upper + strategy_range_containment_atr * atr_h4;
   for(int shift = 1; shift <= strategy_range_lookback_bars; ++shift)
     {
      const double c = RateClose(rates, total, shift);
      if(c <= 0.0)
         continue;
      samples++;
      if(c >= contain_low && c <= contain_high)
         contained++;
     }
   if(samples <= 0)
      return false;
   if((double)contained / (double)samples < strategy_range_containment_pct)
      return false;

   out_range_start_shift = earliest_shift;
   return true;
  }

bool CurrentSowBarPasses(const MqlRates &rates[],
                         const int total,
                         const double lower,
                         const double atr_h4)
  {
   const double open_now = RateOpen(rates, total, 1);
   const double high_now = RateHigh(rates, total, 1);
   const double low_now = RateLow(rates, total, 1);
   const double close_now = RateClose(rates, total, 1);
   if(open_now <= 0.0 || high_now <= 0.0 || low_now <= 0.0 || close_now <= 0.0)
      return false;
   if(high_now <= low_now)
      return false;

   const double bar_range = high_now - low_now;
   if(low_now >= lower - strategy_sow_low_break_atr * atr_h4)
      return false;
   if(close_now >= lower)
      return false;
   if(bar_range < strategy_sow_wide_spread_atr * atr_h4)
      return false;
   if((close_now - low_now) / bar_range > strategy_sow_close_near_low_pct)
      return false;
   if(close_now >= open_now)
      return false;

   return VolumeGatePasses(rates, total);
  }

bool FirstBreakSinceUtad(const MqlRates &rates[],
                         const int total,
                         const int utad_shift,
                         const double lower,
                         const double atr_h4)
  {
   if(utad_shift <= 2)
      return true;
   const double prior_break = lower - strategy_sow_first_break_atr * atr_h4;
   for(int shift = 2; shift < utad_shift; ++shift)
     {
      const double c = RateClose(rates, total, shift);
      if(c > 0.0 && c < prior_break)
         return false;
     }
   return true;
  }

bool FindWyckoffSetup(WyckoffSetup &setup)
  {
   setup.upper = 0.0;
   setup.lower = 0.0;
   setup.range_size = 0.0;
   setup.utad_high = 0.0;
   setup.signal_bar_time = 0;

   if(strategy_atr_period < 1 || strategy_utad_recent_bars < 2)
      return false;

   const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_h4 <= 0.0)
      return false;

   const int needed = strategy_range_lookback_bars + strategy_prerange_slope_bars + strategy_volume_mean_bars + 10;
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, needed, rates); // perf-allowed: bespoke Wyckoff structure scan runs only after the framework QM_IsNewBar entry gate.
   if(copied < needed)
      return false;
   const int total = copied;

   double upper = 0.0;
   double lower = 0.0;
   int range_start_shift = 0;
   if(!FindTradingRange(rates, total, atr_h4, upper, lower, range_start_shift))
      return false;

   double pre_slope = 0.0;
   if(!LinearRegressionSlopeBeforeRange(rates, total, range_start_shift, strategy_prerange_slope_bars, pre_slope))
      return false;
   if(pre_slope < strategy_prerange_slope_atr_per_bar * atr_h4)
      return false;

   if(!CurrentSowBarPasses(rates, total, lower, atr_h4))
      return false;

   const int max_utad_shift = MathMin(strategy_utad_recent_bars, strategy_range_lookback_bars - 2);
   for(int utad_shift = 2; utad_shift <= max_utad_shift; ++utad_shift)
     {
      const double utad_high = RateHigh(rates, total, utad_shift);
      const double utad_close = RateClose(rates, total, utad_shift);
      if(!(utad_high > upper + strategy_utad_break_atr * atr_h4 && utad_close < upper))
         continue;
      if(!FirstBreakSinceUtad(rates, total, utad_shift, lower, atr_h4))
         continue;

      setup.upper = upper;
      setup.lower = lower;
      setup.range_size = upper - lower;
      setup.utad_high = utad_high;
      setup.signal_bar_time = RateTime(rates, total, 1);
      return true;
     }

   return false;
  }

string WyckoffStateKey(const ulong ticket, const string suffix)
  {
   return StringFormat("QM5_1423_%I64u_%s", ticket, suffix);
  }

double WyckoffStateGet(const ulong ticket, const string suffix, const double fallback)
  {
   const string key = WyckoffStateKey(ticket, suffix);
   if(GlobalVariableCheck(key))
      return GlobalVariableGet(key);
   return fallback;
  }

void WyckoffStateSet(const ulong ticket, const string suffix, const double value)
  {
   GlobalVariableSet(WyckoffStateKey(ticket, suffix), value);
  }

string NarrativeSemaphoreKey()
  {
   return StringFormat("wyckoff_phase_d_dist_active_%s", _Symbol);
  }

void MarkNarrativeSemaphore(const datetime signal_time)
  {
   datetime t = signal_time;
   if(t <= 0)
      t = TimeCurrent();
   GlobalVariableSet(NarrativeSemaphoreKey(), (double)t);
  }

bool RecentNarrativeSemaphore()
  {
   if(!strategy_sequence_guard_enabled)
      return false;
   if(strategy_sequence_guard_h4_bars <= 0)
      return false;
   if(!GlobalVariableCheck(NarrativeSemaphoreKey()))
      return false;
   const int seconds = PeriodSeconds(PERIOD_H4);
   if(seconds <= 0)
      return false;
   const datetime last_signal = (datetime)GlobalVariableGet(NarrativeSemaphoreKey());
   if(last_signal <= 0)
      return false;
   return (TimeCurrent() - last_signal < strategy_sequence_guard_h4_bars * seconds);
  }

bool RecentLpsyEntryExists()
  {
   if(!strategy_sequence_guard_enabled || strategy_sequence_guard_h4_bars <= 0)
      return false;
   const int seconds = PeriodSeconds(PERIOD_H4);
   if(seconds <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if((int)(pos_magic / 10000) != 1419)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         return true;
     }

   const datetime now = TimeCurrent();
   const datetime from_time = now - strategy_sequence_guard_h4_bars * seconds;
   if(!HistorySelect(from_time, now))
      return false;

   const int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const long deal_magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
      if((int)(deal_magic / 10000) != 1419)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      if((ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE) == DEAL_TYPE_SELL)
         return true;
     }

   return false;
  }

bool NarrativeGuardBlocksEntry()
  {
   if(RecentNarrativeSemaphore())
      return true;
   return RecentLpsyEntryExists();
  }

bool EnsureWyckoffState(const ulong ticket)
  {
   if(ticket == 0)
      return false;
   if(GlobalVariableCheck(WyckoffStateKey(ticket, "upper")))
      return true;
   if(!g_pending_setup_valid)
      return false;

   WyckoffStateSet(ticket, "upper", g_pending_upper);
   WyckoffStateSet(ticket, "lower", g_pending_lower);
   WyckoffStateSet(ticket, "range", g_pending_range);
   WyckoffStateSet(ticket, "utad_high", g_pending_utad_high);
   WyckoffStateSet(ticket, "signal_time", (double)g_pending_signal_time);
   WyckoffStateSet(ticket, "partial_done", 0.0);
   MarkNarrativeSemaphore(g_pending_signal_time);
   return true;
  }

bool PartialAlreadyDone(const ulong ticket)
  {
   return (WyckoffStateGet(ticket, "partial_done", 0.0) > 0.5);
  }

void MarkPartialDone(const ulong ticket)
  {
   WyckoffStateSet(ticket, "partial_done", 1.0);
  }

void BlockPatternReuseFromNow()
  {
   const int seconds = PeriodSeconds(PERIOD_H4);
   if(seconds > 0 && strategy_reuse_guard_h4_bars > 0)
      g_pattern_block_until = TimeCurrent() + strategy_reuse_guard_h4_bars * seconds;
  }

bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_h4 <= 0.0)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > strategy_spread_max_atr * atr_h4)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WYCKOFF_SOW_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(g_pattern_block_until > 0 && TimeCurrent() < g_pattern_block_until)
      return false;
   if(NarrativeGuardBlocksEntry())
      return false;
   if(!MacroBiasAllowsShort())
      return false;
   if(!NewsPauseAllowsEntry())
      return false;

   WyckoffSetup setup;
   if(!FindWyckoffSetup(setup))
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_h4 <= 0.0)
      return false;

   double sl_price = setup.utad_high + strategy_sl_utad_atr_buffer * atr_h4;
   const double max_sl = bid + strategy_sl_max_atr * atr_h4;
   if(sl_price > max_sl)
      sl_price = max_sl;
   if(sl_price <= bid)
      return false;

   const double tp_price = bid - strategy_measured_move_mult * setup.range_size;
   if(tp_price <= 0.0 || tp_price >= bid)
      return false;

   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl_price);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp_price);

   g_pending_setup_valid = true;
   g_pending_upper = setup.upper;
   g_pending_lower = setup.lower;
   g_pending_range = setup.range_size;
   g_pending_utad_high = setup.utad_high;
   g_pending_signal_time = setup.signal_bar_time;
   if(setup.signal_bar_time > 0 && strategy_reuse_guard_h4_bars > 0)
      g_pattern_block_until = setup.signal_bar_time + strategy_reuse_guard_h4_bars * PeriodSeconds(PERIOD_H4);

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
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      EnsureWyckoffState(ticket);

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double tp_price = PositionGetDouble(POSITION_TP);
      const double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || tp_price <= 0.0 || current_ask <= 0.0 || volume <= 0.0)
         continue;

      if(current_sl > 0.0 && current_sl <= open_price)
        {
         MarkPartialDone(ticket);
         continue;
        }
      if(PartialAlreadyDone(ticket))
         continue;

      const double half_target = open_price - strategy_partial_move_pct * (open_price - tp_price);
      if(current_ask > half_target)
         continue;

      if(QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL))
        {
         MarkPartialDone(ticket);
         if(current_sl <= 0.0 || current_sl > open_price)
            QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "wyckoff_sow_partial_be");
        }
     }
  }

bool Strategy_ExitSignal()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      EnsureWyckoffState(ticket);

      const double upper = WyckoffStateGet(ticket, "upper", g_pending_upper);
      const double atr_h4 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
      const double close_h4 = QM_SMA(_Symbol, PERIOD_H4, 1, 1, PRICE_CLOSE);
      if(upper > 0.0 && atr_h4 > 0.0 && close_h4 > upper + strategy_utad_break_atr * atr_h4)
        {
         BlockPatternReuseFromNow();
         return true;
        }

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int seconds = PeriodSeconds(PERIOD_H4);
      if(open_time > 0 && seconds > 0 && strategy_time_stop_h4_bars > 0)
        {
         if(TimeCurrent() - open_time >= strategy_time_stop_h4_bars * seconds)
           {
            BlockPatternReuseFromNow();
            return true;
           }
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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
