#property strict
#property version   "5.0"
#property description "QM5_12930 Classical Ascending Triangle Breakout H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12930 Classical Ascending Triangle Breakout (H4)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/
//       QM5_12930_classical-ascending-triangle-breakout-h4.md
// Baseline is bullish-only. The card's optional failed-break reverse is not
// exposed because the card does not define its reverse-side stop or target.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12930;
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
input ENUM_TIMEFRAMES strategy_tf                    = PERIOD_H4;
input int    strategy_atr_period                     = 14;
input int    strategy_fractal_wing_bars              = 2;
input int    strategy_pivot_scan_bars                = 200;
input int    strategy_resistance_lookback_bars       = 80;
input int    strategy_resistance_min_separation      = 8;
input int    strategy_resistance_max_separation      = 60;
input double strategy_resistance_tolerance_atr       = 0.50;
input double strategy_support_min_rise_atr           = 0.50;
input double strategy_support_slope_min_atr          = 0.10;
input double strategy_support_slope_max_atr          = 0.50;
input int    strategy_pattern_min_bars               = 25;
input int    strategy_pattern_max_bars               = 80;
input double strategy_min_contraction_fraction       = 0.50;
input double strategy_breakout_buffer_atr            = 0.50;
input bool   strategy_volume_confirmation            = false;
input int    strategy_volume_lookback_bars           = 20;
input double strategy_volume_multiplier              = 1.20;
input bool   strategy_macro_bias_enabled             = true;
input int    strategy_macro_sma_period               = 200;
input double strategy_initial_sl_buffer_atr          = 0.50;
input double strategy_initial_sl_cap_atr             = 3.00;
input int    strategy_time_stop_bars                 = 60;
input int    strategy_reuse_guard_bars               = 30;
input int    strategy_spread_lookback_bars           = 20;
input double strategy_spread_average_multiplier      = 1.50;

bool g_new_bar = false;

struct StrategyPivot
  {
   int shift;
   double price;
  };

bool Strategy_SelectOurPosition(ulong &ticket)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      return true;
     }
   return false;
  }

bool Strategy_ReuseGuardActive()
  {
   if(strategy_reuse_guard_bars <= 0)
      return false;

   const datetime now = TimeCurrent();
   if(!HistorySelect(now - 60 * 24 * 60 * 60, now))
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime entry_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const int bars_since_entry = iBarShift(_Symbol, strategy_tf, entry_time, false);
      if(bars_since_entry >= 0 && bars_since_entry < strategy_reuse_guard_bars)
         return true;
     }
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_lookback_bars <= 0 || strategy_spread_average_multiplier <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   double spread_sum = 0.0;
   int spread_count = 0;
   for(int shift = 1; shift <= strategy_spread_lookback_bars; ++shift)
     {
      const long sample = (long)iSpread(_Symbol, strategy_tf, shift); // perf-allowed: bounded closed-H4 spread average
      if(sample <= 0)
         continue;
      spread_sum += (double)sample;
      ++spread_count;
     }
   if(spread_count == 0)
      return true;

   const double average_spread = spread_sum / (double)spread_count;
   return ((double)current_spread <= strategy_spread_average_multiplier * average_spread);
  }

bool Strategy_VolumeAllowsEntry()
  {
   if(!strategy_volume_confirmation)
      return true;
   if(strategy_volume_lookback_bars < 1 || strategy_volume_multiplier <= 0.0)
      return false;

   const long signal_volume = iVolume(_Symbol, strategy_tf, 1); // perf-allowed: card-authorized closed-H4 tick volume
   if(signal_volume <= 0)
      return false;

   double volume_sum = 0.0;
   int volume_count = 0;
   for(int shift = 2; shift < 2 + strategy_volume_lookback_bars; ++shift)
     {
      const long sample = iVolume(_Symbol, strategy_tf, shift); // perf-allowed: bounded closed-H4 volume average
      if(sample <= 0)
         continue;
      volume_sum += (double)sample;
      ++volume_count;
     }
   if(volume_count == 0)
      return false;

   return ((double)signal_volume >
           strategy_volume_multiplier * volume_sum / (double)volume_count);
  }

bool Strategy_IsFractalHigh(const int shift)
  {
   if(shift <= strategy_fractal_wing_bars)
      return false;
   const double center = iHigh(_Symbol, strategy_tf, shift); // perf-allowed: Williams-fractal structural scan on new H4 bars
   if(center <= 0.0)
      return false;
   for(int offset = 1; offset <= strategy_fractal_wing_bars; ++offset)
     {
      if(center <= iHigh(_Symbol, strategy_tf, shift - offset) || // perf-allowed: fixed 2-bar Williams-fractal wing
         center <= iHigh(_Symbol, strategy_tf, shift + offset)) // perf-allowed: fixed 2-bar Williams-fractal wing
         return false;
     }
   return true;
  }

bool Strategy_IsFractalLow(const int shift)
  {
   if(shift <= strategy_fractal_wing_bars)
      return false;
   const double center = iLow(_Symbol, strategy_tf, shift); // perf-allowed: Williams-fractal structural scan on new H4 bars
   if(center <= 0.0)
      return false;
   for(int offset = 1; offset <= strategy_fractal_wing_bars; ++offset)
     {
      if(center >= iLow(_Symbol, strategy_tf, shift - offset) || // perf-allowed: fixed 2-bar Williams-fractal wing
         center >= iLow(_Symbol, strategy_tf, shift + offset)) // perf-allowed: fixed 2-bar Williams-fractal wing
         return false;
     }
   return true;
  }

int Strategy_CollectSupportPivots(const int older_resistance_shift,
                                  StrategyPivot &pivots[])
  {
   ArrayResize(pivots, 0);
   const int first_confirmed_shift = strategy_fractal_wing_bars + 1;
   for(int shift = first_confirmed_shift; shift < older_resistance_shift; ++shift)
     {
      if(!Strategy_IsFractalLow(shift))
         continue;
      const int count = ArraySize(pivots);
      ArrayResize(pivots, count + 1);
      pivots[count].shift = shift;
      pivots[count].price = iLow(_Symbol, strategy_tf, shift); // perf-allowed: confirmed support-pivot value
     }
   return ArraySize(pivots);
  }

double Strategy_SupportRegressionSlope(const StrategyPivot &pivots[])
  {
   const int count_int = ArraySize(pivots);
   if(count_int < 2)
      return 0.0;

   const int oldest_shift = pivots[count_int - 1].shift;
   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   for(int i = 0; i < count_int; ++i)
     {
      const double x = (double)(oldest_shift - pivots[i].shift);
      const double y = pivots[i].price;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double count = (double)count_int;
   const double denominator = count * sum_xx - sum_x * sum_x;
   if(MathAbs(denominator) <= 1e-12)
      return 0.0;
   return (count * sum_xy - sum_x * sum_y) / denominator;
  }

bool Strategy_FindAscendingTriangle(const double atr,
                                    double &resistance_level,
                                    double &older_support_level,
                                    int &older_support_shift,
                                    double &support_slope)
  {
   if(atr <= 0.0)
      return false;

   const int first_confirmed_shift = strategy_fractal_wing_bars + 1;
   const int resistance_limit = MathMin(
      strategy_resistance_lookback_bars,
      strategy_pivot_scan_bars - strategy_fractal_wing_bars);

   for(int newer_high_shift = first_confirmed_shift;
       newer_high_shift <= resistance_limit - strategy_resistance_min_separation;
       ++newer_high_shift)
     {
      if(!Strategy_IsFractalHigh(newer_high_shift))
         continue;
      const double newer_high = iHigh(_Symbol, strategy_tf, newer_high_shift); // perf-allowed: confirmed resistance pivot
      const int older_high_limit = MathMin(
         resistance_limit,
         newer_high_shift + strategy_resistance_max_separation);

      for(int older_high_shift = newer_high_shift + strategy_resistance_min_separation;
          older_high_shift <= older_high_limit;
          ++older_high_shift)
        {
         if(!Strategy_IsFractalHigh(older_high_shift))
            continue;
         const double older_high = iHigh(_Symbol, strategy_tf, older_high_shift); // perf-allowed: confirmed resistance pivot
         if(MathAbs(newer_high - older_high) > strategy_resistance_tolerance_atr * atr)
            continue;

         StrategyPivot supports[];
         const int support_count = Strategy_CollectSupportPivots(older_high_shift, supports);
         if(support_count < 2)
            continue;

         const StrategyPivot recent_support = supports[0];
         const StrategyPivot older_support = supports[support_count - 1];
         if(recent_support.price <=
            older_support.price + strategy_support_min_rise_atr * atr)
            continue;

         const double slope = Strategy_SupportRegressionSlope(supports);
         if(slope < strategy_support_slope_min_atr * atr ||
            slope > strategy_support_slope_max_atr * atr)
            continue;

         const int pattern_bars = MathMax(older_high_shift, older_support.shift) - 1;
         if(pattern_bars < strategy_pattern_min_bars ||
            pattern_bars > strategy_pattern_max_bars)
            continue;

         const double resistance = 0.5 * (newer_high + older_high);
         if(resistance <= older_support.price)
            continue;
         const double contraction_threshold = older_support.price +
            strategy_min_contraction_fraction * (resistance - older_support.price);
         if(recent_support.price <= contraction_threshold)
            continue;

         const double projected_support = older_support.price +
            slope * (double)(older_support.shift - 1);
         if(projected_support <= 0.0 || projected_support >= resistance)
            continue;

         resistance_level = resistance;
         older_support_level = older_support.price;
         older_support_shift = older_support.shift;
         support_slope = slope;
         return true;
        }
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_tf || strategy_tf != PERIOD_H4)
      return true;
   if(strategy_atr_period < 2 || strategy_fractal_wing_bars != 2 ||
      strategy_pivot_scan_bars < 200 || strategy_resistance_lookback_bars > 80 ||
      strategy_resistance_min_separation < 1 ||
      strategy_resistance_max_separation < strategy_resistance_min_separation ||
      strategy_pattern_min_bars < 1 ||
      strategy_pattern_max_bars < strategy_pattern_min_bars ||
      strategy_macro_sma_period < 2)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0 ||
      Strategy_ReuseGuardActive() || !Strategy_SpreadAllowsEntry() ||
      !Strategy_VolumeAllowsEntry())
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double close1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: single card-authorized closed-H4 breakout close
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || close1 <= 0.0 || ask <= 0.0)
      return false;

   if(strategy_macro_bias_enabled)
     {
      const double macro_sma = QM_SMA(
         _Symbol, strategy_tf, strategy_macro_sma_period, 1);
      if(macro_sma <= 0.0 || close1 <= macro_sma)
         return false;
     }

   double resistance = 0.0;
   double older_support = 0.0;
   int older_support_shift = 0;
   double support_slope = 0.0;
   if(!Strategy_FindAscendingTriangle(
      atr, resistance, older_support, older_support_shift, support_slope))
      return false;

   if(close1 <= resistance + strategy_breakout_buffer_atr * atr)
      return false;

   const double entry = ask;
   const double support_at_entry = older_support +
      support_slope * (double)(older_support_shift - 1);
   const double structural_sl = support_at_entry - strategy_initial_sl_buffer_atr * atr;
   const double sl = MathMax(structural_sl, entry - strategy_initial_sl_cap_atr * atr);
   const double triangle_height = resistance - older_support;
   const double tp = entry + triangle_height;
   if(sl <= 0.0 || sl >= entry || triangle_height <= 0.0 || tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp = QM_TM_NormalizePrice(_Symbol, tp);
   req.reason = "CLASSICAL_ASCENDING_TRIANGLE_BREAKOUT_H4";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, partial, or break-even rule.
  }

bool Strategy_ExitSignal()
  {
   if(!g_new_bar || strategy_time_stop_bars <= 0)
      return false;

   ulong ticket = 0;
   if(!Strategy_SelectOurPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;
   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
   return (bars_since_open >= strategy_time_stop_bars);
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

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_12930\",\"ea\":\"classical-ascending-triangle-breakout-h4\"}");
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

   g_new_bar = QM_IsNewBar(_Symbol, strategy_tf);
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(
         _Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !g_new_bar)
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
