#property strict
#property version   "5.0"
#property description "QM5_1407 Classical Symmetric Triangle Breakout H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1407
// Classical Symmetric Triangle Breakout (H4)
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1407_classical-symmetric-triangle-breakout-h4.md
// Edwards & Magee Technical Analysis of Stock Trends 10th ed. Ch. 8
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1407;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

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
input int    strategy_pattern_min_bars               = 25;
input int    strategy_pattern_max_bars               = 80;
input int    strategy_min_high_pivots                = 3;
input int    strategy_min_low_pivots                 = 3;
input double strategy_slope_min_atr_factor           = 0.30;
input double strategy_slope_max_atr_factor           = 2.00;
input double strategy_slope_symmetry_ratio           = 0.40;
input double strategy_min_amplitude_atr              = 3.00;
input double strategy_apex_max_extension_pct         = 0.30;
input double strategy_breakout_buffer_atr            = 0.50;
input double strategy_sl_buffer_atr                  = 0.30;
input double strategy_sl_cap_atr                     = 3.00;
input double strategy_tp1_ratio                      = 0.50;
input int    strategy_time_stop_bars                 = 36;
input int    strategy_reuse_guard_bars               = 20;
input int    strategy_spread_lookback_bars           = 20;
input double strategy_spread_average_multiplier      = 1.50;

struct StrategyPivot
  {
   int    shift;
   double price;
  };

struct SymmetricTrianglePattern
  {
   int    start_shift;
   int    end_shift;
   double highest_high;
   double lowest_low;
   double supply_slope;
   double supply_intercept;
   double demand_slope;
   double demand_intercept;
   int    reference_shift;
   double apex_shift;
  };

bool     g_new_bar = false;
double   g_active_tp1_price = 0.0;
bool     g_tp1_done = false;
double   g_last_supply_slope = 0.0;
double   g_last_supply_intercept = 0.0;
double   g_last_demand_slope = 0.0;
double   g_last_demand_intercept = 0.0;
int      g_last_ref_shift = 0;

double Strategy_NormalizePrice(const double price)
  {
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &pos_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
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
      const long sample = (long)iSpread(_Symbol, strategy_tf, shift);
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

bool Strategy_IsFractalHigh(const int shift)
  {
   if(shift <= strategy_fractal_wing_bars)
      return false;
   const double center = iHigh(_Symbol, strategy_tf, shift);
   if(center <= 0.0)
      return false;
   for(int offset = 1; offset <= strategy_fractal_wing_bars; ++offset)
     {
      if(center <= iHigh(_Symbol, strategy_tf, shift - offset) ||
         center <= iHigh(_Symbol, strategy_tf, shift + offset))
         return false;
     }
   return true;
  }

bool Strategy_IsFractalLow(const int shift)
  {
   if(shift <= strategy_fractal_wing_bars)
      return false;
   const double center = iLow(_Symbol, strategy_tf, shift);
   if(center <= 0.0)
      return false;
   for(int offset = 1; offset <= strategy_fractal_wing_bars; ++offset)
     {
      if(center >= iLow(_Symbol, strategy_tf, shift - offset) ||
         center >= iLow(_Symbol, strategy_tf, shift + offset))
         return false;
     }
   return true;
  }

bool Strategy_LinearRegression(const StrategyPivot &pivots[],
                               const int oldest_shift,
                               double &slope,
                               double &intercept)
  {
   const int count_int = ArraySize(pivots);
   if(count_int < 2)
      return false;

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
      return false;

   slope = (count * sum_xy - sum_x * sum_y) / denominator;
   intercept = (sum_y - slope * sum_x) / count;
   return true;
  }

bool Strategy_FindSymmetricTriangle(const double atr,
                                    SymmetricTrianglePattern &pat)
  {
   if(atr <= 0.0)
      return false;

   const int first_confirmed_shift = strategy_fractal_wing_bars + 1;
   const int max_scan = MathMin(strategy_pivot_scan_bars, 250);

   StrategyPivot highs[];
   StrategyPivot lows[];
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);

   for(int shift = first_confirmed_shift; shift <= max_scan; ++shift)
     {
      if(Strategy_IsFractalHigh(shift))
        {
         const int count = ArraySize(highs);
         ArrayResize(highs, count + 1);
         highs[count].shift = shift;
         highs[count].price = iHigh(_Symbol, strategy_tf, shift);
        }
      if(Strategy_IsFractalLow(shift))
        {
         const int count = ArraySize(lows);
         ArrayResize(lows, count + 1);
         lows[count].shift = shift;
         lows[count].price = iLow(_Symbol, strategy_tf, shift);
        }
     }

   const int num_highs = ArraySize(highs);
   const int num_lows = ArraySize(lows);
   if(num_highs < strategy_min_high_pivots || num_lows < strategy_min_low_pivots)
      return false;

   for(int h_count = strategy_min_high_pivots; h_count <= MathMin(num_highs, 6); ++h_count)
     {
      for(int l_count = strategy_min_low_pivots; l_count <= MathMin(num_lows, 6); ++l_count)
        {
         StrategyPivot sub_highs[];
         StrategyPivot sub_lows[];
         ArrayResize(sub_highs, h_count);
         ArrayResize(sub_lows, l_count);

         for(int i = 0; i < h_count; ++i) sub_highs[i] = highs[i];
         for(int j = 0; j < l_count; ++j) sub_lows[j] = lows[j];

         bool strictly_descending = true;
         for(int i = 1; i < h_count; ++i)
           {
            if(sub_highs[i - 1].price > sub_highs[i].price + 0.20 * atr)
              {
               strictly_descending = false;
               break;
              }
           }
         if(!strictly_descending)
            continue;

         bool strictly_ascending = true;
         for(int j = 1; j < l_count; ++j)
           {
            if(sub_lows[j - 1].price < sub_lows[j].price - 0.20 * atr)
              {
               strictly_ascending = false;
               break;
              }
           }
         if(!strictly_ascending)
            continue;

         const int oldest_shift = MathMax(sub_highs[h_count - 1].shift, sub_lows[l_count - 1].shift);
         const int newest_shift = MathMin(sub_highs[0].shift, sub_lows[0].shift);
         const int pattern_len = oldest_shift - 1;
         if(pattern_len < strategy_pattern_min_bars || pattern_len > strategy_pattern_max_bars)
            continue;

         double supply_slope = 0.0, supply_intercept = 0.0;
         double demand_slope = 0.0, demand_intercept = 0.0;
         if(!Strategy_LinearRegression(sub_highs, oldest_shift, supply_slope, supply_intercept))
            continue;
         if(!Strategy_LinearRegression(sub_lows, oldest_shift, demand_slope, demand_intercept))
            continue;

         const double slope_scale = (atr / 50.0);
         if(slope_scale <= 0.0)
            continue;

         if(supply_slope > -strategy_slope_min_atr_factor * slope_scale ||
            supply_slope < -strategy_slope_max_atr_factor * slope_scale)
            continue;

         if(demand_slope < strategy_slope_min_atr_factor * slope_scale ||
            demand_slope > strategy_slope_max_atr_factor * slope_scale)
            continue;

         const double abs_sup = MathAbs(supply_slope);
         const double abs_dem = MathAbs(demand_slope);
         const double symmetry_ratio = MathAbs(supply_slope + demand_slope) / (abs_sup + abs_dem);
         if(symmetry_ratio > strategy_slope_symmetry_ratio)
            continue;

         double highest_h = -1.0;
         double lowest_l = 1e9;
         for(int s = 1; s <= oldest_shift; ++s)
           {
            const double h = iHigh(_Symbol, strategy_tf, s);
            const double l = iLow(_Symbol, strategy_tf, s);
            if(h > highest_h) highest_h = h;
            if(l < lowest_l) lowest_l = l;
           }
         const double amplitude = highest_h - lowest_l;
         if(amplitude < strategy_min_amplitude_atr * atr)
            continue;

         const double denom_apex = demand_slope - supply_slope;
         if(denom_apex <= 1e-12)
            continue;
         const double x_apex = (supply_intercept - demand_intercept) / denom_apex;
         const double apex_shift = (double)oldest_shift - x_apex;

         if(apex_shift < 1.0 - strategy_apex_max_extension_pct * (double)pattern_len)
            continue;

         bool prior_break_violated = false;
         for(int s = 2; s <= oldest_shift; ++s)
           {
            const double c = iClose(_Symbol, strategy_tf, s);
            const double x = (double)(oldest_shift - s);
            const double sup_line = supply_intercept + supply_slope * x;
            const double dem_line = demand_intercept + demand_slope * x;
            if(c > sup_line + 0.20 * atr || c < dem_line - 0.20 * atr)
              {
               prior_break_violated = true;
               break;
              }
           }
         if(prior_break_violated)
            continue;

         pat.start_shift = oldest_shift;
         pat.end_shift = newest_shift;
         pat.highest_high = highest_h;
         pat.lowest_low = lowest_l;
         pat.supply_slope = supply_slope;
         pat.supply_intercept = supply_intercept;
         pat.demand_slope = demand_slope;
         pat.demand_intercept = demand_intercept;
         pat.reference_shift = oldest_shift;
         pat.apex_shift = apex_shift;
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
      strategy_pattern_min_bars < 10 || strategy_pattern_max_bars < strategy_pattern_min_bars)
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
      Strategy_ReuseGuardActive() || !Strategy_SpreadAllowsEntry())
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double close1 = iClose(_Symbol, strategy_tf, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || close1 <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   SymmetricTrianglePattern pat;
   if(!Strategy_FindSymmetricTriangle(atr, pat))
      return false;

   const double x_bar1 = (double)(pat.reference_shift - 1);
   const double supply_line_bar1 = pat.supply_intercept + pat.supply_slope * x_bar1;
   const double demand_line_bar1 = pat.demand_intercept + pat.demand_slope * x_bar1;

   const double triangle_height = pat.highest_high - pat.lowest_low;
   if(triangle_height <= 0.0)
      return false;

   if(close1 > supply_line_bar1 + strategy_breakout_buffer_atr * atr)
     {
      const double entry = ask;
      const double structural_sl = pat.lowest_low - strategy_sl_buffer_atr * atr;
      const double sl = MathMax(structural_sl, entry - strategy_sl_cap_atr * atr);
      const double tp = entry + triangle_height;

      if(sl <= 0.0 || sl >= entry || tp <= entry)
         return false;

      g_active_tp1_price = entry + strategy_tp1_ratio * triangle_height;
      g_tp1_done = false;
      g_last_supply_slope = pat.supply_slope;
      g_last_supply_intercept = pat.supply_intercept;
      g_last_demand_slope = pat.demand_slope;
      g_last_demand_intercept = pat.demand_intercept;
      g_last_ref_shift = pat.reference_shift;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = Strategy_NormalizePrice(sl);
      req.tp = Strategy_NormalizePrice(tp);
      req.reason = "CLASSICAL_SYMMETRIC_TRIANGLE_BREAKOUT_LONG_H4";
      return true;
     }

   if(close1 < demand_line_bar1 - strategy_breakout_buffer_atr * atr)
     {
      const double entry = bid;
      const double structural_sl = pat.highest_high + strategy_sl_buffer_atr * atr;
      const double sl = MathMin(structural_sl, entry + strategy_sl_cap_atr * atr);
      const double tp = entry - triangle_height;

      if(sl <= entry || tp <= 0.0 || tp >= entry)
         return false;

      g_active_tp1_price = entry - strategy_tp1_ratio * triangle_height;
      g_tp1_done = false;
      g_last_supply_slope = pat.supply_slope;
      g_last_supply_intercept = pat.supply_intercept;
      g_last_demand_slope = pat.demand_slope;
      g_last_demand_intercept = pat.demand_intercept;
      g_last_ref_shift = pat.reference_shift;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = Strategy_NormalizePrice(sl);
      req.tp = Strategy_NormalizePrice(tp);
      req.reason = "CLASSICAL_SYMMETRIC_TRIANGLE_BREAKDOWN_SHORT_H4";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   if(!Strategy_SelectOurPosition(ticket, pos_type))
     {
      g_tp1_done = false;
      g_active_tp1_price = 0.0;
      return;
     }

   if(g_tp1_done || g_active_tp1_price <= 0.0)
      return;

   const bool is_buy = (pos_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const bool tp1_hit = is_buy ? (market >= g_active_tp1_price) : (market <= g_active_tp1_price);
   if(!tp1_hit)
      return;

   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double partial_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_ratio);
   if(partial_lots > 0.0 && partial_lots < volume)
      QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL);

   QM_TM_MoveSL(ticket, Strategy_NormalizePrice(open_price), "tp1_move_to_break_even");
   g_tp1_done = true;
  }

bool Strategy_ExitSignal()
  {
   if(!g_new_bar)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   if(!Strategy_SelectOurPosition(ticket, pos_type) || !PositionSelectByTicket(ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
   if(strategy_time_stop_bars > 0 && bars_since_open >= strategy_time_stop_bars)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double close1 = iClose(_Symbol, strategy_tf, 1);
   if(atr > 0.0 && close1 > 0.0 && g_last_ref_shift > 0)
     {
      const double x_now = (double)(g_last_ref_shift - 1);
      if(pos_type == POSITION_TYPE_BUY)
        {
         const double sup_line = g_last_supply_intercept + g_last_supply_slope * x_now;
         if(close1 < sup_line + 0.20 * atr)
            return true;
        }
      else
        {
         const double dem_line = g_last_demand_intercept + g_last_demand_slope * x_now;
         if(close1 > dem_line - 0.20 * atr)
            return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1407\",\"ea\":\"classical-symmetric-triangle-breakout-h4\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
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
