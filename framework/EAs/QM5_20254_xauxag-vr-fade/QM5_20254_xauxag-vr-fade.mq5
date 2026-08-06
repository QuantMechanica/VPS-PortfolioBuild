#property strict
#property version   "5.0"
#property description "QM5_20254 XAU XAG Anti-Persistent Ratio Fade"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20254 - XAU/XAG Anti-Persistent Ratio Fade
// -----------------------------------------------------------------------------
// Conditional precious-metal relative-value package:
//   - require significant q=2 anti-persistence in synchronized completed-month
//     XAU-minus-XAG log returns
//   - fade an extreme completed-D1 XAU/XAG log-price-ratio z-score
//   - close on completed-D1 ratio convergence or the next month boundary
// Runtime is Darwinex-native D1 close data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20254;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_vr_window_months         = 32;
input int    strategy_vr_q                     = 2;
input double strategy_significance_z           = 1.64485362695147;
input int    strategy_ratio_lookback_d1        = 60;
input double strategy_ratio_entry_z            = 1.5;
input double strategy_ratio_exit_z             = 0.25;
input int    strategy_history_bars             = 1200;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 35;
input int    strategy_xau_max_spread_pts       = 1500;
input int    strategy_xag_max_spread_pts       = 3000;
input int    strategy_deviation_points         = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_new_d1_bar = false;
bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_cache_period_key = 0;
int      g_last_entry_period_key = 0;
datetime g_cache_decision_bar_time = 0;
datetime g_pair_entry_time = 0;
double   g_cache_variance_ratio = 0.0;
double   g_cache_vr_z = 0.0;
double   g_cache_ratio_z = 0.0;
string   g_cache_signal_diagnostic = "UNINITIALIZED";

bool Strategy_NewsAllowsEntry(const datetime broker_time);

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xau)
      return 0;
   if(symbol == g_leg_xag)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xau && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_xau && strategy_xau_max_spread_pts > 0)
      return (spread_points <= strategy_xau_max_spread_pts);
   if(symbol == g_leg_xag && strategy_xag_max_spread_pts > 0)
      return (spread_points <= strategy_xag_max_spread_pts);
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
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts) || parts.year <= 0 ||
      parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_PeriodKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts) || parts.year <= 0 ||
      parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 12 + parts.mon;
  }

string Strategy_AttemptStateName()
  {
   return "QM5_20254_XAUXAG_VRFADE_ATTEMPT";
  }

bool Strategy_ConsumePeriodAttempt(const int period_key)
  {
   if(period_key <= 0)
      return false;

   const string state_name = Strategy_AttemptStateName();
   if(GlobalVariableCheck(state_name))
     {
      const double stored_value = GlobalVariableGet(state_name);
      if(!MathIsValidNumber(stored_value))
         return false;
      const int stored_period_key = (int)MathRound(stored_value);
      if(stored_period_key >= period_key)
         return false;
     }

   if(GlobalVariableSet(state_name, (double)period_key) <= 0)
      return false;
   GlobalVariablesFlush();
   return true;
  }

bool Strategy_IsPairMagic(const long magic)
  {
   const int xau_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xau);
   const int xag_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xag);
   return (magic == xau_magic || magic == xag_magic);
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
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
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
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_PeriodKeyForTime(deal_time) == period_key)
         return true;
     }
   return false;
  }

bool Strategy_PairCompositionValid(const int expected_pair_direction = 0)
  {
   int xau_direction = 0;
   int xag_direction = 0;
   int xau_count = 0;
   int xag_count = 0;
   bool stops_valid = true;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      const double stop_loss = PositionGetDouble(POSITION_SL);
      if(stop_loss <= 0.0 || !MathIsValidNumber(stop_loss))
         stops_valid = false;
      if(symbol == g_leg_xau)
        {
         xau_direction = direction;
         ++xau_count;
        }
      else if(symbol == g_leg_xag)
        {
         xag_direction = direction;
         ++xag_count;
        }
     }
   if(!stops_valid || xau_count != 1 || xag_count != 1 ||
      xau_direction != -xag_direction)
      return false;
   if(expected_pair_direction != 0 && xau_direction != expected_pair_direction)
      return false;
   return true;
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

int Strategy_NextMonthKey(const int month_key)
  {
   int year = month_key / 100;
   int month = month_key % 100;
   if(year < 1900 || month < 1 || month > 12)
      return 0;

   ++month;
   if(month > 12)
     {
      month = 1;
      ++year;
     }
   return year * 100 + month;
  }

bool Strategy_CollectMonthEnds(const string symbol,
                               const int current_month_key,
                               double &month_closes[],
                               datetime &month_times[],
                               int &month_keys[],
                               string &diagnostic)
  {
   diagnostic = "UNSET";
   const int needed_closes = strategy_vr_window_months + 1;
   if(current_month_key <= 0 ||
      strategy_vr_window_months != 32 ||
      strategy_vr_q != 2 ||
      needed_closes != 33)
     {
      diagnostic = "WINDOW_OR_PARAMETER_INVALID";
      return false;
     }

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(symbol, // perf-allowed: bounded completed-month D1 endpoint sample.
                PERIOD_D1,
                1,
                strategy_history_bars,
                bars);
   if(copied < needed_closes)
     {
      diagnostic = "INSUFFICIENT_D1_HISTORY";
      return false;
     }

   ArrayResize(month_closes, needed_closes);
   ArrayResize(month_times, needed_closes);
   ArrayResize(month_keys, needed_closes);
   ArrayInitialize(month_closes, 0.0);
   ArrayInitialize(month_times, 0);
   ArrayInitialize(month_keys, 0);

   int found = 0;
   int last_key = 0;
   for(int index = 0; index < copied && found < needed_closes; ++index)
     {
      const int month_key = Strategy_MonthKeyForTime(bars[index].time);
      // Initialization can make shift one fall inside the decision month.
      // Never admit that partial endpoint into the completed-month sample.
      if(month_key <= 0 ||
         month_key == current_month_key ||
         month_key == last_key)
         continue;
      if(bars[index].close <= 0.0 ||
         !MathIsValidNumber(bars[index].close))
        {
         diagnostic = "INVALID_MONTHLY_CLOSE";
         return false;
        }

      month_closes[found] = bars[index].close;
      month_times[found] = bars[index].time;
      month_keys[found] = month_key;
      last_key = month_key;
      ++found;
     }

   if(found != needed_closes)
     {
      diagnostic = "INSUFFICIENT_MONTHLY_ENDPOINTS";
      return false;
     }
   if(Strategy_NextMonthKey(month_keys[0]) != current_month_key)
     {
      diagnostic = "LATEST_MONTH_ENDPOINT_MISALIGNED";
      return false;
     }

   for(int index = 0; index < strategy_vr_window_months; ++index)
     {
      if(Strategy_NextMonthKey(month_keys[index + 1]) != month_keys[index])
        {
         diagnostic = "NONCONSECUTIVE_MONTHLY_ENDPOINTS";
         return false;
        }
     }

   diagnostic = "ENDPOINTS_READY";
   return true;
  }

bool Strategy_LoadMemoryState(const int current_month_key,
                              bool &anti_persistent)
  {
   anti_persistent = false;
   g_cache_variance_ratio = 0.0;
   g_cache_vr_z = 0.0;
   g_cache_signal_diagnostic = "UNSET";

   double xau_closes[];
   double xag_closes[];
   datetime xau_times[];
   datetime xag_times[];
   int xau_keys[];
   int xag_keys[];
   string diagnostic = "";

   if(!Strategy_CollectMonthEnds(g_leg_xau,
                                 current_month_key,
                                 xau_closes,
                                 xau_times,
                                 xau_keys,
                                 diagnostic))
     {
      g_cache_signal_diagnostic = "XAU_" + diagnostic;
      return false;
     }
   if(!Strategy_CollectMonthEnds(g_leg_xag,
                                 current_month_key,
                                 xag_closes,
                                 xag_times,
                                 xag_keys,
                                 diagnostic))
     {
      g_cache_signal_diagnostic = "XAG_" + diagnostic;
      return false;
     }

   const int needed_closes = strategy_vr_window_months + 1;
   for(int index = 0; index < needed_closes; ++index)
     {
      if(xau_keys[index] != xag_keys[index] ||
         xau_times[index] != xag_times[index])
        {
         g_cache_signal_diagnostic = "UNSYNCHRONIZED_MONTHLY_ENDPOINTS";
         return false;
        }
     }

   // Endpoint arrays are reverse chronological. Build the 32 relative
   // monthly returns chronologically so lag-one products implement q=2.
   double relative_returns[];
   ArrayResize(relative_returns, strategy_vr_window_months);
   ArrayInitialize(relative_returns, 0.0);
   for(int index = 0; index < strategy_vr_window_months; ++index)
     {
      const int older_index = strategy_vr_window_months - index;
      const int newer_index = older_index - 1;
      const double relative_return =
         MathLog(xau_closes[newer_index] / xau_closes[older_index]) -
         MathLog(xag_closes[newer_index] / xag_closes[older_index]);
      if(!MathIsValidNumber(relative_return))
        {
         g_cache_signal_diagnostic = "INVALID_RELATIVE_RETURN";
         return false;
        }
      relative_returns[index] = relative_return;
     }

   double sum = 0.0;
   for(int index = 0; index < strategy_vr_window_months; ++index)
      sum += relative_returns[index];
   const double mean = sum / (double)strategy_vr_window_months;
   if(!MathIsValidNumber(mean))
     {
      g_cache_signal_diagnostic = "INVALID_RETURN_MEAN";
      return false;
     }

   double squared_sum = 0.0;
   for(int index = 0; index < strategy_vr_window_months; ++index)
     {
      const double delta = relative_returns[index] - mean;
      squared_sum += delta * delta;
     }
   if(squared_sum <= 0.0 || !MathIsValidNumber(squared_sum))
     {
      g_cache_signal_diagnostic = "INVALID_RETURN_VARIANCE";
      return false;
     }

   double lag_cross_sum = 0.0;
   double robust_numerator = 0.0;
   for(int index = 1; index < strategy_vr_window_months; ++index)
     {
      const double current_delta = relative_returns[index] - mean;
      const double prior_delta = relative_returns[index - 1] - mean;
      lag_cross_sum += current_delta * prior_delta;
      robust_numerator += current_delta * current_delta *
                          prior_delta * prior_delta;
     }

   const double rho_one = lag_cross_sum / squared_sum;
   g_cache_variance_ratio = 1.0 + rho_one;
   const double robust_se =
      MathSqrt(robust_numerator / (squared_sum * squared_sum));
   if(robust_se <= 0.0 ||
      !MathIsValidNumber(robust_se) ||
      !MathIsValidNumber(g_cache_variance_ratio))
     {
      g_cache_signal_diagnostic = "INVALID_ROBUST_STANDARD_ERROR";
      return false;
     }

   g_cache_vr_z =
      (g_cache_variance_ratio - 1.0) / robust_se;
   if(!MathIsValidNumber(g_cache_vr_z))
     {
      g_cache_signal_diagnostic = "INVALID_VR_Z";
      return false;
     }

   if(g_cache_vr_z >= -strategy_significance_z)
     {
      g_cache_signal_diagnostic = "VR_NOT_ANTIPERSISTENT";
      return true;
     }

   anti_persistent = true;
   g_cache_signal_diagnostic = "MEMORY_GATE_READY";
   return true;
  }

bool Strategy_LoadRatioState(double &ratio_z,
                             string &diagnostic)
  {
   ratio_z = 0.0;
   diagnostic = "UNSET";
   if(strategy_ratio_lookback_d1 != 60)
     {
      diagnostic = "RATIO_WINDOW_INVALID";
      return false;
     }

   MqlRates xau_bars[];
   MqlRates xag_bars[];
   ArraySetAsSeries(xau_bars, true);
   ArraySetAsSeries(xag_bars, true);
   const int xau_copied =
      CopyRates(g_leg_xau, // perf-allowed: bounded completed-D1 sample on new-bar path.
                PERIOD_D1,
                1,
                strategy_ratio_lookback_d1,
                xau_bars);
   const int xag_copied =
      CopyRates(g_leg_xag, // perf-allowed: bounded completed-D1 sample on new-bar path.
                PERIOD_D1,
                1,
                strategy_ratio_lookback_d1,
                xag_bars);
   if(xau_copied != strategy_ratio_lookback_d1 ||
      xag_copied != strategy_ratio_lookback_d1)
     {
      diagnostic = "INSUFFICIENT_RATIO_HISTORY";
      return false;
     }

   double ratios[];
   ArrayResize(ratios, strategy_ratio_lookback_d1);
   ArrayInitialize(ratios, 0.0);
   double sum = 0.0;
   for(int index = 0; index < strategy_ratio_lookback_d1; ++index)
     {
      if(xau_bars[index].time != xag_bars[index].time)
        {
         diagnostic = "UNSYNCHRONIZED_D1_ENDPOINTS";
         return false;
        }
      if(xau_bars[index].close <= 0.0 ||
         xag_bars[index].close <= 0.0 ||
         !MathIsValidNumber(xau_bars[index].close) ||
         !MathIsValidNumber(xag_bars[index].close))
        {
         diagnostic = "INVALID_D1_CLOSE";
         return false;
        }

      const double ratio =
         MathLog(xau_bars[index].close) -
         MathLog(xag_bars[index].close);
      if(!MathIsValidNumber(ratio))
        {
         diagnostic = "INVALID_LOG_RATIO";
         return false;
        }
      ratios[index] = ratio;
      sum += ratio;
     }

   const double mean = sum / (double)strategy_ratio_lookback_d1;
   double squared_sum = 0.0;
   for(int index = 0; index < strategy_ratio_lookback_d1; ++index)
     {
      const double delta = ratios[index] - mean;
      squared_sum += delta * delta;
     }
   if(squared_sum <= 0.0 || !MathIsValidNumber(squared_sum))
     {
      diagnostic = "INVALID_RATIO_VARIANCE";
      return false;
     }

   const double sample_sd =
      MathSqrt(squared_sum / (double)(strategy_ratio_lookback_d1 - 1));
   if(sample_sd <= 0.0 || !MathIsValidNumber(sample_sd))
     {
      diagnostic = "INVALID_RATIO_STANDARD_DEVIATION";
      return false;
     }

   ratio_z = (ratios[0] - mean) / sample_sd;
   if(!MathIsValidNumber(ratio_z))
     {
      diagnostic = "INVALID_RATIO_Z";
      return false;
     }

   diagnostic = "RATIO_STATE_READY";
   return true;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_signal_valid = false;
   g_cache_pair_direction = 0;
   g_cache_ratio_z = 0.0;
   g_cache_month_key = 0;
   g_cache_period_key = 0;
   g_cache_decision_bar_time = 0;

   const datetime decision_bar_time =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cached timestamp on D1 new-bar path.
   const datetime prior_bar_time =
      iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: exact monthly D1 transition check.
   const int current_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   const int prior_month_key = Strategy_MonthKeyForTime(prior_bar_time);
   if(current_month_key <= 0 || prior_month_key <= 0)
      return;

   g_monthly_rebalance_bar = (current_month_key != prior_month_key);
   g_cache_month_key = current_month_key;
   g_cache_period_key = Strategy_PeriodKeyForTime(decision_bar_time);
   g_cache_decision_bar_time = decision_bar_time;
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
   ZeroMemory(req);
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
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket);
  }

bool Strategy_OpenPair(const int pair_direction)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xau) || !Strategy_SpreadAllowed(g_leg_xag))
      return false;

   const bool long_xau_short_xag = (pair_direction > 0);
   const QM_OrderType xau_type = long_xau_short_xag ? QM_BUY : QM_SELL;
   const QM_OrderType xag_type = long_xau_short_xag ? QM_SELL : QM_BUY;
   const string reason = long_xau_short_xag ? "QM5_20254_LONG_XAU_SHORT_XAG_RATIO"
                                            : "QM5_20254_SHORT_XAU_LONG_XAG_RATIO";
   const double weight_sum = 2.0;

   const bool xau_ok = Strategy_OpenLeg(g_leg_xau, xau_type, 1.0, weight_sum, reason);
   const bool xag_ok = Strategy_OpenLeg(g_leg_xag, xag_type, 1.0, weight_sum, reason);
   if(xau_ok && xag_ok &&
      Strategy_OpenPairLegCount() == 2 &&
      Strategy_PairCompositionValid(pair_direction))
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
   if(qm_ea_id != 20254 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(RISK_PERCENT != 0.0 || RISK_FIXED != 1000.0 ||
      PORTFOLIO_WEIGHT != 1.0)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 || qm_news_min_impact != "high")
      return true;
   if(qm_friday_close_enabled || qm_friday_close_hour_broker != 21 ||
      qm_stress_reject_probability != 0.0)
      return true;
   if(strategy_vr_window_months != 32 || strategy_vr_q != 2 ||
      MathAbs(strategy_significance_z - 1.64485362695147) > 1.0e-12)
      return true;
   if(strategy_ratio_lookback_d1 != 60 ||
      MathAbs(strategy_ratio_entry_z - 1.5) > 1.0e-12 ||
      MathAbs(strategy_ratio_exit_z - 0.25) > 1.0e-12 ||
      strategy_ratio_entry_z <= strategy_ratio_exit_z)
      return true;
   if(strategy_history_bars != 1200)
      return true;
   if(strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 35)
      return true;
   if(strategy_xau_max_spread_pts != 1500 ||
      strategy_xag_max_spread_pts != 3000 ||
      strategy_deviation_points != 20)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_20254_XAU_XAG_VRFADE_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_new_d1_bar || g_cache_month_key <= 0 ||
      g_cache_period_key <= 0 || g_cache_decision_bar_time <= 0)
      return false;
   if(Strategy_PeriodAlreadyEntered(g_cache_period_key, g_cache_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;

   bool anti_persistent = false;
   g_cache_signal_valid =
      Strategy_LoadMemoryState(g_cache_month_key,
                               anti_persistent);
   if(!g_cache_signal_valid)
     {
      if(g_monthly_rebalance_bar)
         QM_LogEvent(QM_WARN,
                     "ENTRY_REJECTED",
                     StringFormat("{\"result\":\"MEMORY_STATE_REJECTED\",\"reason\":\"XAU_XAG_VR_FADE\",\"detail\":\"%s\",\"month_key\":%d}",
                                  QM_LoggerEscapeJson(g_cache_signal_diagnostic),
                                  g_cache_month_key));
      return false;
     }
   if(!anti_persistent)
     {
      if(g_monthly_rebalance_bar)
         QM_LogEvent(QM_INFO,
                     "ENTRY_REJECTED",
                     StringFormat("{\"result\":\"VALID_FLAT_MEMORY_STATE\",\"reason\":\"XAU_XAG_VR_FADE\",\"month_key\":%d,\"variance_ratio\":%.10f,\"vr_z\":%.10f}",
                                  g_cache_month_key,
                                  g_cache_variance_ratio,
                                  g_cache_vr_z));
      return false;
     }

   string ratio_diagnostic = "";
   if(!Strategy_LoadRatioState(g_cache_ratio_z, ratio_diagnostic))
     {
      if(g_monthly_rebalance_bar)
         QM_LogEvent(QM_WARN,
                     "ENTRY_REJECTED",
                     StringFormat("{\"result\":\"RATIO_STATE_REJECTED\",\"reason\":\"XAU_XAG_VR_FADE\",\"detail\":\"%s\",\"month_key\":%d}",
                                  QM_LoggerEscapeJson(ratio_diagnostic),
                                  g_cache_month_key));
      return false;
     }
   if(MathAbs(g_cache_ratio_z) <= strategy_ratio_entry_z)
      return false;

   g_cache_pair_direction = (g_cache_ratio_z > 0.0) ? -1 : 1;
   if(!Strategy_ConsumePeriodAttempt(g_cache_period_key))
      return false;
   QM_LogEvent(QM_INFO,
               "ENTRY_ATTEMPT",
               StringFormat("{\"reason\":\"XAU_XAG_VR_FADE\",\"month_key\":%d,\"decision_bar\":%I64d,\"vr_z\":%.10f,\"ratio_z\":%.10f,\"pair_direction\":%d}",
                            g_cache_month_key,
                            (long)g_cache_decision_bar_time,
                            g_cache_vr_z,
                            g_cache_ratio_z,
                            g_cache_pair_direction));
   if(!Strategy_NewsAllowsEntry(TimeCurrent()))
      return false;

   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"reason\":\"XAU_XAG_VR_FADE\",\"month_key\":%d,\"variance_ratio\":%.10f,\"vr_z\":%.10f,\"ratio_z\":%.10f,\"pair_direction\":%d}",
                            g_cache_month_key,
                            g_cache_variance_ratio,
                            g_cache_vr_z,
                            g_cache_ratio_z,
                            g_cache_pair_direction));

   if(Strategy_OpenPair(g_cache_pair_direction))
      g_last_entry_period_key = g_cache_period_key;
   else
      QM_LogEvent(QM_WARN,
                  "ENTRY_REJECTED",
                  "{\"result\":\"BASKET_OPEN_FAILED\",\"reason\":\"XAU_XAG_VR_FADE\"}");
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
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(g_new_d1_bar)
     {
      double ratio_z = 0.0;
      string ratio_diagnostic = "";
      if(Strategy_LoadRatioState(ratio_z, ratio_diagnostic) &&
         MathAbs(ratio_z) <= strategy_ratio_exit_z)
        {
         QM_LogEvent(QM_INFO,
                     "PAIR_EXIT_Z",
                     StringFormat("{\"reason\":\"XAU_XAG_RATIO_CONVERGED\",\"ratio_z\":%.10f}",
                                  ratio_z));
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xau, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xag, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xau, broker_time, qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xag, broker_time, qm_news_mode_legacy))
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
   const string attempt_state_name = Strategy_AttemptStateName();
   const int current_period_key = Strategy_PeriodKeyForTime(TimeCurrent());
   if(current_period_key > 0 && GlobalVariableCheck(attempt_state_name))
     {
      const double stored_value = GlobalVariableGet(attempt_state_name);
      if(MathIsValidNumber(stored_value) &&
         (int)MathRound(stored_value) > current_period_key)
         GlobalVariableDel(attempt_state_name);
     }

   SymbolSelect(g_leg_xau, true);
   SymbolSelect(g_leg_xag, true);

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

   string basket_symbols[2] = {g_leg_xau, g_leg_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(450, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20254\",\"ea\":\"xauxag-vr-fade\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   g_new_d1_bar = QM_IsNewBar();
   g_monthly_rebalance_bar = false;
   if(g_new_d1_bar)
      Strategy_AdvanceSignal_OnNewBar();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_NoTradeFilter() || !g_new_d1_bar)
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
