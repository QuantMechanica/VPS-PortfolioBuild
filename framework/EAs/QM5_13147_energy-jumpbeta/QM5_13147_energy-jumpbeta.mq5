#property strict
#property version   "5.0"
#property description "QM5_13147 XTI XNG Realized Common-Jump Beta Rank"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13147 - XTI/XNG Monthly Realized Common-Jump Beta Rank
// -----------------------------------------------------------------------------
// Price-native falsification of a commodity aggregate-jump-risk anomaly:
//   - form a 252-return inverse-volatility XTI/XNG energy benchmark
//   - flag benchmark innovations at least 2.0 standard deviations from mean
//   - estimate each leg's incremental beta to the realized jump factor while
//     controlling for the continuous benchmark return
//   - buy lower jump beta, short higher jump beta for one broker month
// This does not reproduce the source's option-derived equity-market jump factor.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13147;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_lookback_d1               = 252;
input double strategy_jump_z                    = 2.0;
input int    strategy_min_jump_days             = 6;
input int    strategy_history_bars             = 320;
input int    strategy_max_endpoint_gap_days    = 10;
input int    strategy_atr_period_d1             = 20;
input double strategy_atr_sl_mult               = 3.5;
input int    strategy_max_hold_days             = 40;
input int    strategy_xti_max_spread_pts        = 1500;
input int    strategy_xng_max_spread_pts        = 3000;
input int    strategy_deviation_points          = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_period_key = 0;
int      g_cache_decision_month_key = 0;
int      g_last_entry_period_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xti_jump_beta = 0.0;
double   g_cache_xng_jump_beta = 0.0;
double   g_cache_jump_beta_difference = 0.0;
double   g_cache_market_mean = 0.0;
double   g_cache_market_stddev = 0.0;
double   g_cache_xti_benchmark_weight = 0.0;
double   g_cache_xng_benchmark_weight = 0.0;
int      g_cache_jump_days = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xti)
      return 0;
   if(symbol == g_leg_xng)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xti && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_xti && strategy_xti_max_spread_pts > 0)
      return (spread_points <= strategy_xti_max_spread_pts);
   if(symbol == g_leg_xng && strategy_xng_max_spread_pts > 0)
      return (spread_points <= strategy_xng_max_spread_pts);
   return true;
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

int Strategy_OpenPairLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         ++count;
     }
   return count;
  }

datetime Strategy_CurrentPairEntryTime()
  {
   datetime earliest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

int Strategy_MonthKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   TimeToStruct(value, parts);
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_PeriodKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   TimeToStruct(value, parts);
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 12 + parts.mon - 1;
  }

bool Strategy_PairCompositionValid()
  {
   int xti_direction = 0;
   int xng_direction = 0;
   int xti_count = 0;
   int xng_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      if(symbol == g_leg_xti)
        {
         xti_direction = direction;
         ++xti_count;
        }
      else if(symbol == g_leg_xng)
        {
         xng_direction = direction;
         ++xng_count;
        }
     }
   return (xti_count == 1 && xng_count == 1 && xti_direction == -xng_direction);
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
   g_pair_entry_time = 0;
  }

bool Strategy_LoadSynchronizedReturns(const datetime decision_bar_time,
                                      double &xti_returns[],
                                      double &xng_returns[],
                                      double &market_returns[],
                                      double &market_mean,
                                      double &market_stddev)
  {
   market_mean = 0.0;
   market_stddev = 0.0;
   g_cache_xti_benchmark_weight = 0.0;
   g_cache_xng_benchmark_weight = 0.0;
   if(decision_bar_time <= 0 || strategy_lookback_d1 < 2)
      return false;

   const int required_closes = strategy_lookback_d1 + 1;
   if(required_closes > strategy_history_bars)
      return false;

   MqlRates xti_rates[];
   MqlRates xng_rates[];
   ArraySetAsSeries(xti_rates, true);
   ArraySetAsSeries(xng_rates, true);
   const int xti_count = CopyRates(g_leg_xti, PERIOD_D1, 1, required_closes, xti_rates); // perf-allowed: bounded monthly realized-jump source window.
   const int xng_count = CopyRates(g_leg_xng, PERIOD_D1, 1, required_closes, xng_rates); // perf-allowed: bounded monthly realized-jump source window.
   if(xti_count != required_closes || xng_count != required_closes)
      return false;
   if(xti_rates[0].time <= 0 || xti_rates[0].time != xng_rates[0].time ||
      xti_rates[0].time >= decision_bar_time)
      return false;
   const long endpoint_gap = (long)(decision_bar_time - xti_rates[0].time);
   if(endpoint_gap < 0 || endpoint_gap > (long)strategy_max_endpoint_gap_days * 86400)
      return false;

   if(ArrayResize(xti_returns, strategy_lookback_d1) != strategy_lookback_d1 ||
      ArrayResize(xng_returns, strategy_lookback_d1) != strategy_lookback_d1 ||
      ArrayResize(market_returns, strategy_lookback_d1) != strategy_lookback_d1)
      return false;

   for(int i = 0; i < required_closes; ++i)
     {
      if(xti_rates[i].time <= 0 || xti_rates[i].time != xng_rates[i].time)
         return false;
      if(xti_rates[i].close <= 0.0 || xng_rates[i].close <= 0.0 ||
         !MathIsValidNumber(xti_rates[i].close) ||
         !MathIsValidNumber(xng_rates[i].close))
         return false;
     }

   double xti_sum = 0.0;
   double xng_sum = 0.0;
   for(int sample = 0; sample < strategy_lookback_d1; ++sample)
     {
      const int older_index = strategy_lookback_d1 - sample;
      const int newer_index = older_index - 1;
      const double xti_value = xti_rates[newer_index].close /
                               xti_rates[older_index].close - 1.0;
      const double xng_value = xng_rates[newer_index].close /
                               xng_rates[older_index].close - 1.0;
      if(!MathIsValidNumber(xti_value) || !MathIsValidNumber(xng_value))
         return false;
      xti_returns[sample] = xti_value;
      xng_returns[sample] = xng_value;
      xti_sum += xti_value;
      xng_sum += xng_value;
     }

   const double xti_mean = xti_sum / (double)strategy_lookback_d1;
   const double xng_mean = xng_sum / (double)strategy_lookback_d1;
   double xti_ss = 0.0;
   double xng_ss = 0.0;
   for(int sample = 0; sample < strategy_lookback_d1; ++sample)
     {
      const double xti_centered = xti_returns[sample] - xti_mean;
      const double xng_centered = xng_returns[sample] - xng_mean;
      xti_ss += xti_centered * xti_centered;
      xng_ss += xng_centered * xng_centered;
     }

   const double xti_stddev = MathSqrt(xti_ss / (double)(strategy_lookback_d1 - 1));
   const double xng_stddev = MathSqrt(xng_ss / (double)(strategy_lookback_d1 - 1));
   if(xti_stddev <= 1.0e-12 || xng_stddev <= 1.0e-12 ||
      !MathIsValidNumber(xti_stddev) || !MathIsValidNumber(xng_stddev))
      return false;

   const double inverse_vol_sum = 1.0 / xti_stddev + 1.0 / xng_stddev;
   if(inverse_vol_sum <= 0.0 || !MathIsValidNumber(inverse_vol_sum))
      return false;
   g_cache_xti_benchmark_weight = (1.0 / xti_stddev) / inverse_vol_sum;
   g_cache_xng_benchmark_weight = (1.0 / xng_stddev) / inverse_vol_sum;

   double market_sum = 0.0;
   for(int sample = 0; sample < strategy_lookback_d1; ++sample)
     {
      market_returns[sample] = g_cache_xti_benchmark_weight * xti_returns[sample] +
                               g_cache_xng_benchmark_weight * xng_returns[sample];
      if(!MathIsValidNumber(market_returns[sample]))
         return false;
      market_sum += market_returns[sample];
     }
   market_mean = market_sum / (double)strategy_lookback_d1;

   double market_ss = 0.0;
   for(int sample = 0; sample < strategy_lookback_d1; ++sample)
     {
      const double centered = market_returns[sample] - market_mean;
      market_ss += centered * centered;
     }
   market_stddev = MathSqrt(market_ss / (double)(strategy_lookback_d1 - 1));
   return (market_stddev > 1.0e-12 && MathIsValidNumber(market_stddev));
  }

bool Strategy_JumpBeta(const double &asset_returns[],
                       const double &market_returns[],
                       const double market_mean,
                       const double market_stddev,
                       double &jump_beta,
                       int &jump_days)
  {
   jump_beta = 0.0;
   jump_days = 0;
   if(ArraySize(asset_returns) != strategy_lookback_d1 ||
      ArraySize(market_returns) != strategy_lookback_d1 ||
      market_stddev <= 0.0)
      return false;

   double normal[3][4];
   for(int row = 0; row < 3; ++row)
      for(int col = 0; col < 4; ++col)
         normal[row][col] = 0.0;

   const double jump_threshold = strategy_jump_z * market_stddev;
   for(int sample = 0; sample < strategy_lookback_d1; ++sample)
     {
      const double market_innovation = market_returns[sample] - market_mean;
      const bool is_jump = (MathAbs(market_innovation) >= jump_threshold);
      const double jump_factor = is_jump ? market_innovation : 0.0;
      if(is_jump)
         ++jump_days;

      double x[3];
      x[0] = 1.0;
      x[1] = market_returns[sample];
      x[2] = jump_factor;
      const double y = asset_returns[sample];
      if(!MathIsValidNumber(y) || !MathIsValidNumber(jump_factor))
         return false;

      for(int row = 0; row < 3; ++row)
        {
         for(int col = 0; col < 3; ++col)
            normal[row][col] += x[row] * x[col];
         normal[row][3] += x[row] * y;
        }
     }

   if(jump_days < strategy_min_jump_days)
      return false;

   for(int pivot_col = 0; pivot_col < 3; ++pivot_col)
     {
      int pivot_row = pivot_col;
      double pivot_abs = MathAbs(normal[pivot_col][pivot_col]);
      for(int candidate = pivot_col + 1; candidate < 3; ++candidate)
        {
         const double candidate_abs = MathAbs(normal[candidate][pivot_col]);
         if(candidate_abs > pivot_abs)
           {
            pivot_abs = candidate_abs;
            pivot_row = candidate;
           }
        }
      if(pivot_abs <= 1.0e-16 || !MathIsValidNumber(pivot_abs))
         return false;

      if(pivot_row != pivot_col)
        {
         for(int col = pivot_col; col < 4; ++col)
           {
            const double swap_value = normal[pivot_col][col];
            normal[pivot_col][col] = normal[pivot_row][col];
            normal[pivot_row][col] = swap_value;
           }
        }

      const double divisor = normal[pivot_col][pivot_col];
      if(MathAbs(divisor) <= 1.0e-16 || !MathIsValidNumber(divisor))
         return false;
      for(int col = pivot_col; col < 4; ++col)
         normal[pivot_col][col] /= divisor;

      for(int row = 0; row < 3; ++row)
        {
         if(row == pivot_col)
            continue;
         const double factor = normal[row][pivot_col];
         for(int col = pivot_col; col < 4; ++col)
            normal[row][col] -= factor * normal[pivot_col][col];
        }
     }

   jump_beta = normal[2][3];
   return MathIsValidNumber(jump_beta);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xti_jump_beta = 0.0;
   g_cache_xng_jump_beta = 0.0;
   g_cache_jump_beta_difference = 0.0;
   g_cache_market_mean = 0.0;
   g_cache_market_stddev = 0.0;
   g_cache_jump_days = 0;

   double xti_returns[];
   double xng_returns[];
   double market_returns[];
   if(!Strategy_LoadSynchronizedReturns(decision_bar_time,
                                        xti_returns,
                                        xng_returns,
                                        market_returns,
                                        g_cache_market_mean,
                                        g_cache_market_stddev))
      return false;

   int xti_jump_days = 0;
   int xng_jump_days = 0;
   if(!Strategy_JumpBeta(xti_returns,
                         market_returns,
                         g_cache_market_mean,
                         g_cache_market_stddev,
                         g_cache_xti_jump_beta,
                         xti_jump_days))
      return false;
   if(!Strategy_JumpBeta(xng_returns,
                         market_returns,
                         g_cache_market_mean,
                         g_cache_market_stddev,
                         g_cache_xng_jump_beta,
                         xng_jump_days))
      return false;
   if(xti_jump_days != xng_jump_days)
      return false;
   g_cache_jump_days = xti_jump_days;

   g_cache_jump_beta_difference = g_cache_xti_jump_beta - g_cache_xng_jump_beta;
   if(!MathIsValidNumber(g_cache_jump_beta_difference))
      return false;

   // The source's high-minus-low aggregate-jump-beta return is negative.
   if(g_cache_jump_beta_difference < -1.0e-12)
      pair_direction = 1;
   else if(g_cache_jump_beta_difference > 1.0e-12)
      pair_direction = -1;
   return true;
  }

bool Strategy_IsPairMagic(const long magic)
  {
   const int xti_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
   const int xng_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xng);
   return (magic == xti_magic || magic == xng_magic);
  }

bool Strategy_PeriodAlreadyEntered(const int period_key,
                                   const int decision_month_key)
  {
   if(period_key <= 0 || decision_month_key <= 0)
      return true;
   if(g_last_entry_period_key == period_key)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_PeriodKeyForTime(opened) == period_key)
         return true;
     }

   MqlDateTime start_parts;
   ZeroMemory(start_parts);
   start_parts.year = decision_month_key / 100;
   start_parts.mon = decision_month_key % 100;
   start_parts.day = 1;
   const datetime period_start = StructToTime(start_parts);
   if(period_start <= 0 || !HistorySelect(period_start, TimeCurrent()))
      return true;

   const int deal_count = HistoryDealsTotal();
   for(int i = deal_count - 1; i >= 0; --i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      const long magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!Strategy_IsPairMagic(magic))
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_PeriodKeyForTime(deal_time) == period_key)
         return true;
     }
   return false;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      current_month_key == prior_month_key)
      return;

   MqlRates decision_rates[1];
   // perf-allowed: one current D1 bar on the monthly new-bar path.
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, decision_rates) != 1 ||
      decision_rates[0].time <= 0)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_period_key = Strategy_PeriodKeyForTime(decision_rates[0].time);
   g_cache_decision_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadSignalState(decision_rates[0].time,
                                                   g_cache_pair_direction);
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;
   const long hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - entry_time) >= hold_seconds);
  }

double Strategy_LotsForLeg(const string symbol,
                           const double risk_weight,
                           const double risk_weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || risk_weight <= 0.0 || risk_weight_sum <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * risk_weight / risk_weight_sum;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   lots = MathFloor(lots / step) * step;
   if(lots < min_lot)
      return 0.0;
   return MathMin(max_lot, NormalizeDouble(lots, 8));
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double risk_weight,
                      const double risk_weight_sum,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || !Strategy_SpreadAllowed(symbol))
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;
   const double lots = Strategy_LotsForLeg(symbol, risk_weight, risk_weight_sum);
   if(lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? NormalizeDouble(entry - stop_dist, digits)
                                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                strategy_deviation_points,
                                req,
                                ticket);
  }

bool Strategy_OpenPair(const int pair_direction)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xng))
      return false;

   const bool long_xti_short_xng = (pair_direction > 0);
   const QM_OrderType xti_type = long_xti_short_xng ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_xti_short_xng ? QM_SELL : QM_BUY;
   const string reason = long_xti_short_xng ? "QM5_13147_LONG_XTI_SHORT_XNG_LOW_JBETA"
                                            : "QM5_13147_SHORT_XTI_LONG_XNG_LOW_JBETA";
   const double weight_sum = 2.0;

   if(!Strategy_OpenLeg(g_leg_xti, xti_type, 1.0, weight_sum, reason))
      return false;
   if(Strategy_OpenLeg(g_leg_xng, xng_type, 1.0, weight_sum, reason))
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_lookback_d1 != 252 || MathAbs(strategy_jump_z - 2.0) > 1.0e-12 ||
      strategy_min_jump_days != 6)
      return true;
   if(strategy_history_bars < 300 || strategy_history_bars > 400)
      return true;
   if(strategy_history_bars < strategy_lookback_d1 + 1)
      return true;
   if(strategy_max_endpoint_gap_days < 7 || strategy_max_endpoint_gap_days > 10)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   if(strategy_xti_max_spread_pts < 0 || strategy_xng_max_spread_pts < 0 ||
      strategy_deviation_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13147_XTI_XNG_JBETA_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_period_key <= 0 ||
      g_cache_decision_month_key <= 0)
      return false;
   if(Strategy_PeriodAlreadyEntered(g_cache_period_key,
                                    g_cache_decision_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;

   if(Strategy_OpenPair(g_cache_pair_direction))
      g_last_entry_period_key = g_cache_period_key;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return;
   if(open_legs != 2 || !Strategy_PairCompositionValid())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(g_monthly_rebalance_bar)
     {
      datetime entry_time = g_pair_entry_time;
      if(entry_time <= 0)
         entry_time = Strategy_CurrentPairEntryTime();
      if(Strategy_PeriodKeyForTime(entry_time) != g_cache_period_key)
        {
         Strategy_ClosePair(QM_EXIT_STRATEGY);
         return;
        }
     }

   if(Strategy_MaxHoldExceeded())
      Strategy_ClosePair(QM_EXIT_TIME_STOP);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xti,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xng,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return false;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xng, broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

int OnInit()
  {
   SymbolSelect(g_leg_xti, true);
   SymbolSelect(g_leg_xng, true);

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

   string basket_symbols[2] = {g_leg_xti, g_leg_xng};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(400, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13147\",\"ea\":\"energy-jumpbeta\"}");
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

   const bool new_bar = QM_IsNewBar();
   g_monthly_rebalance_bar = false;
   if(new_bar)
      Strategy_AdvanceSignal_OnNewBar();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!new_bar)
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
