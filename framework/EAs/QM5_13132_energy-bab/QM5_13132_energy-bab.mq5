#property strict
#property version   "5.0"
#property description "QM5_13132 XTI XNG Betting Against Beta"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13132 - XTI/XNG Betting Against Beta
// -----------------------------------------------------------------------------
// Monthly paired energy factor:
//   - construct an inverse-volatility XTI/XNG D1 benchmark
//   - estimate each leg's 252-observation Dimson beta with five market lags
//   - shrink raw beta halfway toward one
//   - buy the lower-beta leg and short the higher-beta leg
//   - target equal beta exposure through inverse-beta notional sizing
// Runtime is Darwinex-native D1 OHLC and broker metadata only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                         = 13132;
input int    qm_magic_slot_offset             = 0;
input uint   qm_rng_seed                      = 42;

input group "Risk"
input double RISK_PERCENT                     = 0.0;
input double RISK_FIXED                       = 1000.0;
input double PORTFOLIO_WEIGHT                 = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours          = 336;
input string qm_news_min_impact               = "high";
input QM_NewsMode qm_news_mode_legacy         = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled          = false;
input int    qm_friday_close_hour_broker      = 21;

input group "Stress"
input double qm_stress_reject_probability     = 0.0;

input group "Strategy"
input int    strategy_beta_observations       = 252;
input int    strategy_dimson_lags             = 5;
input double strategy_beta_shrink_weight      = 0.5;
input int    strategy_history_bars            = 320;
input double strategy_min_beta                = 0.10;
input double strategy_max_beta_mismatch_pct   = 20.0;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input int    strategy_max_hold_days           = 35;
input int    strategy_xti_max_spread_pts      = 1500;
input int    strategy_xng_max_spread_pts      = 3000;
input int    strategy_deviation_points        = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_last_entry_month_key = 0;
datetime g_pair_entry_time = 0;

double g_cache_xti_raw_beta = 0.0;
double g_cache_xng_raw_beta = 0.0;
double g_cache_xti_beta = 0.0;
double g_cache_xng_beta = 0.0;
double g_cache_xti_benchmark_weight = 0.0;
double g_cache_xng_benchmark_weight = 0.0;
double g_cache_beta_difference = 0.0;
double g_cache_beta_mismatch_pct = 0.0;

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

bool Strategy_LoadSynchronizedReturns(double &xti_returns[],
                                      double &xng_returns[],
                                      double &xti_stddev,
                                      double &xng_stddev)
  {
   xti_stddev = 0.0;
   xng_stddev = 0.0;

   const int total_returns = strategy_beta_observations + strategy_dimson_lags;
   const int required_closes = total_returns + 1;
   if(total_returns <= 1 || required_closes > strategy_history_bars)
      return false;

   MqlRates xti_rates[];
   MqlRates xng_rates[];
   ArraySetAsSeries(xti_rates, true);
   ArraySetAsSeries(xng_rates, true);
   const int xti_count = CopyRates(g_leg_xti, PERIOD_D1, 1, required_closes, xti_rates); // perf-allowed: bounded monthly source window.
   const int xng_count = CopyRates(g_leg_xng, PERIOD_D1, 1, required_closes, xng_rates); // perf-allowed: bounded monthly source window.
   if(xti_count != required_closes || xng_count != required_closes)
      return false;

   if(ArrayResize(xti_returns, total_returns) != total_returns ||
      ArrayResize(xng_returns, total_returns) != total_returns)
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

   for(int j = 0; j < total_returns; ++j)
     {
      const int older_index = total_returns - j;
      const int newer_index = older_index - 1;
      const double xti_value = xti_rates[newer_index].close / xti_rates[older_index].close - 1.0;
      const double xng_value = xng_rates[newer_index].close / xng_rates[older_index].close - 1.0;
      if(!MathIsValidNumber(xti_value) || !MathIsValidNumber(xng_value))
         return false;
      xti_returns[j] = xti_value;
      xng_returns[j] = xng_value;
     }

   double xti_sum = 0.0;
   double xng_sum = 0.0;
   const int first_sample = strategy_dimson_lags;
   for(int i = 0; i < strategy_beta_observations; ++i)
     {
      const int index = first_sample + i;
      xti_sum += xti_returns[index];
      xng_sum += xng_returns[index];
     }
   const double xti_mean = xti_sum / (double)strategy_beta_observations;
   const double xng_mean = xng_sum / (double)strategy_beta_observations;

   double xti_ss = 0.0;
   double xng_ss = 0.0;
   for(int i = 0; i < strategy_beta_observations; ++i)
     {
      const int index = first_sample + i;
      const double xti_centered = xti_returns[index] - xti_mean;
      const double xng_centered = xng_returns[index] - xng_mean;
      xti_ss += xti_centered * xti_centered;
      xng_ss += xng_centered * xng_centered;
     }

   xti_stddev = MathSqrt(xti_ss / (double)(strategy_beta_observations - 1));
   xng_stddev = MathSqrt(xng_ss / (double)(strategy_beta_observations - 1));
   return (xti_stddev > 0.0 && xng_stddev > 0.0 &&
           MathIsValidNumber(xti_stddev) && MathIsValidNumber(xng_stddev));
  }

bool Strategy_DimsonBeta(const double &asset_returns[],
                         const double &market_returns[],
                         double &raw_beta)
  {
   raw_beta = 0.0;
   if(ArraySize(asset_returns) < strategy_beta_observations + strategy_dimson_lags ||
      ArraySize(market_returns) < strategy_beta_observations + strategy_dimson_lags)
      return false;

   // Locked source baseline: intercept plus current market return and five
   // lags. A fixed 7x8 augmented normal-equation matrix keeps the monthly
   // computation bounded and deterministic.
   double normal[7][8];
   for(int row = 0; row < 7; ++row)
      for(int col = 0; col < 8; ++col)
         normal[row][col] = 0.0;

   for(int sample = 0; sample < strategy_beta_observations; ++sample)
     {
      const int return_index = strategy_dimson_lags + sample;
      const double y = asset_returns[return_index];
      if(!MathIsValidNumber(y))
         return false;

      double x[7];
      x[0] = 1.0;
      for(int lag = 0; lag <= 5; ++lag)
        {
         x[lag + 1] = market_returns[return_index - lag];
         if(!MathIsValidNumber(x[lag + 1]))
            return false;
        }

      for(int row = 0; row < 7; ++row)
        {
         for(int col = 0; col < 7; ++col)
            normal[row][col] += x[row] * x[col];
         normal[row][7] += x[row] * y;
        }
     }

   for(int pivot_col = 0; pivot_col < 7; ++pivot_col)
     {
      int pivot_row = pivot_col;
      double pivot_abs = MathAbs(normal[pivot_col][pivot_col]);
      for(int candidate = pivot_col + 1; candidate < 7; ++candidate)
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
         for(int col = pivot_col; col < 8; ++col)
           {
            const double swap_value = normal[pivot_col][col];
            normal[pivot_col][col] = normal[pivot_row][col];
            normal[pivot_row][col] = swap_value;
           }
        }

      const double divisor = normal[pivot_col][pivot_col];
      if(MathAbs(divisor) <= 1.0e-16 || !MathIsValidNumber(divisor))
         return false;
      for(int col = pivot_col; col < 8; ++col)
         normal[pivot_col][col] /= divisor;

      for(int row = 0; row < 7; ++row)
        {
         if(row == pivot_col)
            continue;
         const double factor = normal[row][pivot_col];
         for(int col = pivot_col; col < 8; ++col)
            normal[row][col] -= factor * normal[pivot_col][col];
        }
     }

   for(int slope = 1; slope < 7; ++slope)
     {
      if(!MathIsValidNumber(normal[slope][7]))
         return false;
      raw_beta += normal[slope][7];
     }
   return MathIsValidNumber(raw_beta);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xti_raw_beta = 0.0;
   g_cache_xng_raw_beta = 0.0;
   g_cache_xti_beta = 0.0;
   g_cache_xng_beta = 0.0;
   g_cache_xti_benchmark_weight = 0.0;
   g_cache_xng_benchmark_weight = 0.0;
   g_cache_beta_difference = 0.0;
   g_cache_beta_mismatch_pct = 0.0;
   if(decision_bar_time <= 0)
      return false;

   double xti_returns[];
   double xng_returns[];
   double xti_stddev = 0.0;
   double xng_stddev = 0.0;
   if(!Strategy_LoadSynchronizedReturns(xti_returns,
                                        xng_returns,
                                        xti_stddev,
                                        xng_stddev))
      return false;

   const double xti_inverse_vol = 1.0 / xti_stddev;
   const double xng_inverse_vol = 1.0 / xng_stddev;
   const double inverse_vol_sum = xti_inverse_vol + xng_inverse_vol;
   if(inverse_vol_sum <= 0.0 || !MathIsValidNumber(inverse_vol_sum))
      return false;
   g_cache_xti_benchmark_weight = xti_inverse_vol / inverse_vol_sum;
   g_cache_xng_benchmark_weight = xng_inverse_vol / inverse_vol_sum;

   const int total_returns = strategy_beta_observations + strategy_dimson_lags;
   double market_returns[];
   if(ArrayResize(market_returns, total_returns) != total_returns)
      return false;
   for(int i = 0; i < total_returns; ++i)
     {
      market_returns[i] = g_cache_xti_benchmark_weight * xti_returns[i] +
                          g_cache_xng_benchmark_weight * xng_returns[i];
      if(!MathIsValidNumber(market_returns[i]))
         return false;
     }

   if(!Strategy_DimsonBeta(xti_returns, market_returns, g_cache_xti_raw_beta) ||
      !Strategy_DimsonBeta(xng_returns, market_returns, g_cache_xng_raw_beta))
      return false;

   g_cache_xti_beta = strategy_beta_shrink_weight * g_cache_xti_raw_beta +
                      (1.0 - strategy_beta_shrink_weight);
   g_cache_xng_beta = strategy_beta_shrink_weight * g_cache_xng_raw_beta +
                      (1.0 - strategy_beta_shrink_weight);
   if(g_cache_xti_beta < strategy_min_beta ||
      g_cache_xng_beta < strategy_min_beta ||
      !MathIsValidNumber(g_cache_xti_beta) ||
      !MathIsValidNumber(g_cache_xng_beta))
      return false;

   g_cache_beta_difference = g_cache_xti_beta - g_cache_xng_beta;
   if(!MathIsValidNumber(g_cache_beta_difference))
      return false;
   if(g_cache_beta_difference < -1.0e-12)
      pair_direction = 1;  // XTI is lower beta: long XTI, short XNG.
   else if(g_cache_beta_difference > 1.0e-12)
      pair_direction = -1; // XNG is lower beta: short XTI, long XNG.
   return true;
  }

bool Strategy_IsPairMagic(const long magic)
  {
   const int xti_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
   const int xng_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xng);
   return (magic == xti_magic || magic == xng_magic);
  }

bool Strategy_MonthAlreadyEntered(const int month_key)
  {
   if(month_key <= 0)
      return true;
   if(g_last_entry_month_key == month_key)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKeyForTime(opened) == month_key)
         return true;
     }

   MqlDateTime start_parts;
   ZeroMemory(start_parts);
   start_parts.year = month_key / 100;
   start_parts.mon = month_key % 100;
   start_parts.day = 1;
   const datetime month_start = StructToTime(start_parts);
   if(month_start <= 0 || !HistorySelect(month_start, TimeCurrent()))
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
      if(Strategy_MonthKeyForTime(deal_time) == month_key)
         return true;
     }
   return false;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   const datetime decision_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cached D1 timestamp on new-bar path.
   const datetime prior_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: exact broker-month transition check.
   const int current_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   const int prior_month_key = Strategy_MonthKeyForTime(prior_bar_time);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      current_month_key == prior_month_key)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadSignalState(decision_bar_time,
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

double Strategy_CurrentEntryPrice(const string symbol,
                                  const QM_OrderType type)
  {
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return 0.0;
   const double entry = QM_OrderTypeIsBuy(type) ? tick.ask : tick.bid;
   if(entry <= 0.0 || !MathIsValidNumber(entry))
      return 0.0;
   return entry;
  }

double Strategy_RiskWeightForBetaNotional(const string symbol,
                                          const QM_OrderType type,
                                          const double beta)
  {
   const double entry = Strategy_CurrentEntryPrice(symbol, type);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0 || beta < strategy_min_beta)
      return 0.0;
   const double relative_atr = atr / entry;
   const double weight = relative_atr / beta;
   if(weight <= 0.0 || !MathIsValidNumber(weight))
      return 0.0;
   return weight;
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

double Strategy_NotionalBetaExposure(const string symbol,
                                     const QM_OrderType type,
                                     const double lots,
                                     const double beta)
  {
   const double entry = Strategy_CurrentEntryPrice(symbol, type);
   const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(entry <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 ||
      lots <= 0.0 || beta <= 0.0)
      return 0.0;
   const double one_price_unit_value = tick_value / tick_size;
   const double exposure = lots * entry * one_price_unit_value * beta;
   if(exposure <= 0.0 || !MathIsValidNumber(exposure))
      return 0.0;
   return exposure;
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double lots,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || !Strategy_SpreadAllowed(symbol) || lots <= 0.0)
      return false;

   const double entry = Strategy_CurrentEntryPrice(symbol, type);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;

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
   if(g_cache_xti_beta < strategy_min_beta || g_cache_xng_beta < strategy_min_beta)
      return false;

   const bool long_xti_short_xng = (pair_direction > 0);
   const QM_OrderType xti_type = long_xti_short_xng ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_xti_short_xng ? QM_SELL : QM_BUY;
   const string reason = long_xti_short_xng ? "QM5_13132_LONG_XTI_SHORT_XNG_BAB"
                                            : "QM5_13132_SHORT_XTI_LONG_XNG_BAB";

   const double xti_risk_weight = Strategy_RiskWeightForBetaNotional(g_leg_xti,
                                                                      xti_type,
                                                                      g_cache_xti_beta);
   const double xng_risk_weight = Strategy_RiskWeightForBetaNotional(g_leg_xng,
                                                                      xng_type,
                                                                      g_cache_xng_beta);
   const double risk_weight_sum = xti_risk_weight + xng_risk_weight;
   if(xti_risk_weight <= 0.0 || xng_risk_weight <= 0.0 || risk_weight_sum <= 0.0)
      return false;

   const double xti_lots = Strategy_LotsForLeg(g_leg_xti,
                                                xti_risk_weight,
                                                risk_weight_sum);
   const double xng_lots = Strategy_LotsForLeg(g_leg_xng,
                                                xng_risk_weight,
                                                risk_weight_sum);
   if(xti_lots <= 0.0 || xng_lots <= 0.0)
      return false;

   const double xti_beta_exposure = Strategy_NotionalBetaExposure(g_leg_xti,
                                                                   xti_type,
                                                                   xti_lots,
                                                                   g_cache_xti_beta);
   const double xng_beta_exposure = Strategy_NotionalBetaExposure(g_leg_xng,
                                                                   xng_type,
                                                                   xng_lots,
                                                                   g_cache_xng_beta);
   const double max_beta_exposure = MathMax(xti_beta_exposure, xng_beta_exposure);
   if(xti_beta_exposure <= 0.0 || xng_beta_exposure <= 0.0 || max_beta_exposure <= 0.0)
      return false;
   g_cache_beta_mismatch_pct = 100.0 * MathAbs(xti_beta_exposure - xng_beta_exposure) /
                               max_beta_exposure;
   if(!MathIsValidNumber(g_cache_beta_mismatch_pct) ||
      g_cache_beta_mismatch_pct > strategy_max_beta_mismatch_pct)
      return false;

   if(!Strategy_OpenLeg(g_leg_xti, xti_type, xti_lots, reason))
      return false;
   if(Strategy_OpenLeg(g_leg_xng, xng_type, xng_lots, reason))
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
   if(strategy_beta_observations != 252 || strategy_dimson_lags != 5)
      return true;
   if(MathAbs(strategy_beta_shrink_weight - 0.5) > 1.0e-12)
      return true;
   if(strategy_history_bars < strategy_beta_observations + strategy_dimson_lags + 1 ||
      strategy_history_bars > 1000)
      return true;
   if(strategy_min_beta <= 0.0 || strategy_min_beta >= 1.0)
      return true;
   if(strategy_max_beta_mismatch_pct <= 0.0 || strategy_max_beta_mismatch_pct > 100.0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_hold_days <= 0)
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
   req.reason = "QM5_13132_XTI_XNG_BAB_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_month_key <= 0)
      return false;
   if(Strategy_MonthAlreadyEntered(g_cache_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;

   if(Strategy_OpenPair(g_cache_pair_direction))
      g_last_entry_month_key = g_cache_month_key;
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
      if(Strategy_MonthKeyForTime(entry_time) != g_cache_month_key)
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
                          MathMax(320, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13132\",\"ea\":\"energy-bab\"}");
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
