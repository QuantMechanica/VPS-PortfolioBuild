#property strict
#property version   "5.0"
#property description "QM5_20292 FX Carry-Unwind Basket"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20292 - FX Carry-Unwind Basket
// -----------------------------------------------------------------------------
// Weekly crisis-alpha basket:
//   - measure a seven-major 21/252 realized-FX-volatility stress ratio
//   - rank six CHF/JPY crosses by positive broker carry per ATR-risk dollar
//   - reverse the two strongest current carry directions during high stress
// Runtime inputs are registered .DWX D1 OHLC and native MT5 symbol metadata.
// No policy-rate file, fixed carry direction, price-momentum fallback, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20292;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rv_window_d1             = 21;
input int    strategy_rv_baseline_observations = 252;
input int    strategy_min_valid_signal_symbols = 5;
input double strategy_stress_entry_ratio       = 1.50;
input double strategy_stress_exit_ratio        = 1.10;
input int    strategy_selected_legs            = 2;
input int    strategy_atr_period_d1             = 20;
input double strategy_atr_sl_mult               = 2.5;
input int    strategy_max_hold_d1_bars          = 5;
input int    strategy_spread_history_d1         = 20;
input double strategy_spread_mult               = 3.0;
input int    strategy_history_bars              = 320;
input int    strategy_max_endpoint_gap_days     = 10;
input int    strategy_deviation_points          = 20;

#define QM5_20292_TARGET_COUNT 6
#define QM5_20292_SIGNAL_COUNT 7
#define QM5_20292_PACKAGE_LEGS 2

string g_target_symbols[QM5_20292_TARGET_COUNT] =
  {
   "AUDCHF.DWX", "AUDJPY.DWX", "GBPCHF.DWX",
   "GBPJPY.DWX", "NZDCHF.DWX", "NZDJPY.DWX"
  };

string g_signal_symbols[QM5_20292_SIGNAL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "NZDUSD.DWX",
   "USDJPY.DWX", "USDCHF.DWX", "USDCAD.DWX"
  };

struct StrategyCarryCandidate
  {
   int    target_index;
   int    favorable_direction;
   double carry_cash_per_lot;
   double atr_cash_per_lot;
   double score;
  };

string   g_host_symbol = "AUDCHF.DWX";
string   g_week_attempt_state_key = "";
int      g_last_attempt_week_key = 0;
int      g_current_week_key = 0;
bool     g_week_entry_bar = false;
bool     g_week_attempt_recorded = false;
bool     g_new_d1_bar = false;
bool     g_stress_valid = false;
double   g_stress_ratio = 0.0;
int      g_stress_valid_symbols = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   for(int i = 0; i < QM5_20292_TARGET_COUNT; ++i)
      if(g_target_symbols[i] == symbol)
         return i;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_host_symbol && _Period == PERIOD_D1 &&
           qm_magic_slot_offset == 0);
  }

bool Strategy_Median(double &values[], const int count, double &out_median)
  {
   out_median = 0.0;
   if(count <= 0 || ArraySize(values) < count)
      return false;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double swap_value = values[i];
            values[i] = values[j];
            values[j] = swap_value;
           }

   if((count % 2) == 1)
      out_median = values[count / 2];
   else
      out_median = 0.5 * (values[(count / 2) - 1] + values[count / 2]);
   return (out_median > 0.0 && MathIsValidNumber(out_median));
  }

void Strategy_LoadAttemptState()
  {
   g_last_attempt_week_key = 0;
   if(g_week_attempt_state_key == "" ||
      !GlobalVariableCheck(g_week_attempt_state_key))
      return;

   const int current_key = QM_CalendarPeriodKey(PERIOD_W1, g_host_symbol, 0);
   const double stored = GlobalVariableGet(g_week_attempt_state_key);
   const int stored_key = (int)MathRound(stored);
   if(current_key > 0 && MathIsValidNumber(stored) &&
      stored_key >= 1900000 && stored_key <= current_key)
     {
      g_last_attempt_week_key = stored_key;
      return;
     }

   // Tester globals can outlive a later historical rerun. A future marker
   // must never suppress an earlier deterministic rerun.
   GlobalVariableDel(g_week_attempt_state_key);
  }

bool Strategy_RecordWeekAttempt(const int week_key)
  {
   if(week_key <= 0 || g_week_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_week_attempt_state_key, (double)week_key) <= 0)
      return false;
   GlobalVariablesFlush();
   g_last_attempt_week_key = week_key;
   return true;
  }

bool Strategy_RealizedVolRatio(const string symbol,
                               const datetime decision_bar_time,
                               double &out_ratio)
  {
   out_ratio = 0.0;
   if(decision_bar_time <= 0 || strategy_rv_window_d1 < 2 ||
      strategy_rv_baseline_observations < 2)
      return false;

   const int required_closes = strategy_rv_window_d1 +
                               strategy_rv_baseline_observations + 1;
   const int requested = MathMax(strategy_history_bars, required_closes);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, requested, rates); // perf-allowed: one bounded D1 copy per signal symbol on a new host D1 bar.
   if(copied < required_closes)
      return false;

   const datetime newest_completed_time = rates[0].time;
   if(newest_completed_time <= 0 || newest_completed_time >= decision_bar_time)
      return false;
   const long endpoint_gap = (long)(decision_bar_time - newest_completed_time);
   const long maximum_gap = (long)strategy_max_endpoint_gap_days * 86400;
   if(endpoint_gap < 0 || endpoint_gap > maximum_gap)
      return false;

   const int return_count = required_closes - 1;
   double returns[];
   if(ArrayResize(returns, return_count) != return_count)
      return false;

   for(int i = 0; i < return_count; ++i)
     {
      const MqlRates newer = rates[i];
      const MqlRates older = rates[i + 1];
      if(newer.time <= older.time || older.time <= 0 ||
         newer.close <= 0.0 || older.close <= 0.0 ||
         !MathIsValidNumber(newer.close) ||
         !MathIsValidNumber(older.close))
         return false;
      returns[i] = MathLog(newer.close / older.close);
      if(!MathIsValidNumber(returns[i]))
         return false;
     }

   const int window_count = strategy_rv_baseline_observations + 1;
   double rolling_vols[];
   if(ArrayResize(rolling_vols, window_count) != window_count)
      return false;

   double rolling_sum = 0.0;
   double rolling_sq_sum = 0.0;
   for(int i = 0; i < strategy_rv_window_d1; ++i)
     {
      rolling_sum += returns[i];
      rolling_sq_sum += returns[i] * returns[i];
     }

   for(int start = 0; start < window_count; ++start)
     {
      if(start > 0)
        {
         const double leaving = returns[start - 1];
         const double entering = returns[start + strategy_rv_window_d1 - 1];
         rolling_sum += entering - leaving;
         rolling_sq_sum += entering * entering - leaving * leaving;
        }

      const double n = (double)strategy_rv_window_d1;
      double variance_numerator = rolling_sq_sum - rolling_sum * rolling_sum / n;
      if(variance_numerator < 0.0 && variance_numerator > -1.0e-18)
         variance_numerator = 0.0;
      const double variance = variance_numerator / (n - 1.0);
      if(variance <= 0.0 || !MathIsValidNumber(variance))
         return false;
      rolling_vols[start] = MathSqrt(variance) * MathSqrt(252.0);
      if(rolling_vols[start] <= 0.0 ||
         !MathIsValidNumber(rolling_vols[start]))
         return false;
     }

   double baseline_values[];
   if(ArrayResize(baseline_values,
                  strategy_rv_baseline_observations) !=
      strategy_rv_baseline_observations)
      return false;
   for(int i = 0; i < strategy_rv_baseline_observations; ++i)
      baseline_values[i] = rolling_vols[i + 1];

   double baseline_median = 0.0;
   if(!Strategy_Median(baseline_values,
                       strategy_rv_baseline_observations,
                       baseline_median))
      return false;
   out_ratio = rolling_vols[0] / baseline_median;
   return (out_ratio > 0.0 && MathIsValidNumber(out_ratio));
  }

bool Strategy_GlobalStress(const datetime decision_bar_time,
                           double &out_ratio,
                           int &out_valid_symbols)
  {
   out_ratio = 0.0;
   out_valid_symbols = 0;
   double ratios[QM5_20292_SIGNAL_COUNT];
   for(int i = 0; i < QM5_20292_SIGNAL_COUNT; ++i)
     {
      double ratio = 0.0;
      if(!Strategy_RealizedVolRatio(g_signal_symbols[i],
                                    decision_bar_time,
                                    ratio))
         continue;
      ratios[out_valid_symbols] = ratio;
      ++out_valid_symbols;
     }
   if(out_valid_symbols < strategy_min_valid_signal_symbols)
      return false;
   return Strategy_Median(ratios, out_valid_symbols, out_ratio);
  }

void Strategy_AdvanceStateOnNewBar()
  {
   g_week_entry_bar = false;
   g_week_attempt_recorded = false;
   g_stress_valid = false;
   g_stress_ratio = 0.0;
   g_stress_valid_symbols = 0;

   MqlRates host_bar;
   if(!QM_ReadBar(g_host_symbol, PERIOD_D1, 0, host_bar) ||
      host_bar.time <= 0)
      return;

   const int current_week_key =
      QM_CalendarPeriodKey(PERIOD_W1, g_host_symbol, 0);
   const int prior_week_key =
      QM_CalendarPeriodKey(PERIOD_W1, g_host_symbol, 1);
   g_current_week_key = current_week_key;
   if(current_week_key > 0 && prior_week_key > 0 &&
      current_week_key != prior_week_key)
     {
      g_week_entry_bar = true;
      if(current_week_key != g_last_attempt_week_key)
         g_week_attempt_recorded =
            Strategy_RecordWeekAttempt(current_week_key);
     }

   // The attempt marker above is durable before any weekly entry history or
   // signal check. This same cache also serves daily open-package exits.
   g_stress_valid = Strategy_GlobalStress(host_bar.time,
                                           g_stress_ratio,
                                           g_stress_valid_symbols);
  }

bool Strategy_IsOwnedPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) ==
           QM_MagicChecked(qm_ea_id, slot, symbol));
  }

int Strategy_OpenPackageLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedPosition())
         ++count;
     }
   return count;
  }

bool Strategy_PackageCompositionValid()
  {
   int slot_counts[QM5_20292_TARGET_COUNT] = {0, 0, 0, 0, 0, 0};
   int total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const int slot = Strategy_SlotForSymbol(
         PositionGetString(POSITION_SYMBOL));
      if(slot < 0)
         return false;
      ++slot_counts[slot];
      ++total;
     }

   if(total != QM5_20292_PACKAGE_LEGS)
      return false;
   int distinct = 0;
   for(int i = 0; i < QM5_20292_TARGET_COUNT; ++i)
     {
      if(slot_counts[i] > 1)
         return false;
      if(slot_counts[i] == 1)
         ++distinct;
     }
   return (distinct == QM5_20292_PACKAGE_LEGS);
  }

void Strategy_ClosePackage(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

int Strategy_MaxHeldD1Bars()
  {
   int maximum = -1;
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const int held = QM_TM_HeldPeriods(symbol, PERIOD_D1, opened);
      if(held < 0)
         return -1;
      if(!found || held > maximum)
         maximum = held;
      found = true;
     }
   return found ? maximum : -1;
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long current_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true; // .DWX Model-4 zero modeled spread is valid.
   if(strategy_spread_history_d1 <= 0 || strategy_spread_mult <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1,
                                strategy_spread_history_d1, rates); // perf-allowed: bounded entry-only spread history.
   if(copied < strategy_spread_history_d1)
      return false;
   double spreads[];
   if(ArrayResize(spreads, strategy_spread_history_d1) !=
      strategy_spread_history_d1)
      return false;
   int positive_count = 0;
   for(int i = 0; i < strategy_spread_history_d1; ++i)
      if(rates[i].spread > 0)
        {
         spreads[positive_count] = (double)rates[i].spread;
         ++positive_count;
        }
   if(positive_count == 0)
      return true;

   double median_spread = 0.0;
   if(!Strategy_Median(spreads, positive_count, median_spread))
      return false;
   return ((double)current_spread <= strategy_spread_mult * median_spread);
  }

bool Strategy_RolloverMetadataComparable(const string symbol)
  {
   const long triple_day =
      SymbolInfoInteger(symbol, SYMBOL_SWAP_ROLLOVER3DAYS);
   if(triple_day < (long)SUNDAY || triple_day > (long)SATURDAY)
      return false;

   double multipliers[7];
   multipliers[0] = SymbolInfoDouble(symbol, SYMBOL_SWAP_SUNDAY);
   multipliers[1] = SymbolInfoDouble(symbol, SYMBOL_SWAP_MONDAY);
   multipliers[2] = SymbolInfoDouble(symbol, SYMBOL_SWAP_TUESDAY);
   multipliers[3] = SymbolInfoDouble(symbol, SYMBOL_SWAP_WEDNESDAY);
   multipliers[4] = SymbolInfoDouble(symbol, SYMBOL_SWAP_THURSDAY);
   multipliers[5] = SymbolInfoDouble(symbol, SYMBOL_SWAP_FRIDAY);
   multipliers[6] = SymbolInfoDouble(symbol, SYMBOL_SWAP_SATURDAY);
   bool ordinary_day_exists = false;
   for(int i = 0; i < 7; ++i)
     {
      if(!MathIsValidNumber(multipliers[i]) || multipliers[i] < 0.0)
         return false;
      if(MathAbs(multipliers[i] - 1.0) <= 1.0e-12)
         ordinary_day_exists = true;
     }
   return ordinary_day_exists;
  }

bool Strategy_CurrencyToAccountFactor(const string symbol,
                                      const string currency,
                                      const double reference_price,
                                      double &out_factor)
  {
   out_factor = 0.0;
   const string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
   if(currency == "" || account_currency == "")
      return false;
   if(currency == account_currency)
     {
      out_factor = 1.0;
      return true;
     }

   const double contract_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   const double tick_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   if(tick_value <= 0.0)
      tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(contract_size <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 ||
      reference_price <= 0.0)
      return false;

   const string profit_currency =
      SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   const string base_currency =
      SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   const double profit_to_account =
      tick_value / (contract_size * tick_size);
   if(profit_to_account <= 0.0 ||
      !MathIsValidNumber(profit_to_account))
      return false;
   if(currency == profit_currency)
      out_factor = profit_to_account;
   else if(currency == base_currency)
      out_factor = reference_price * profit_to_account;
   else
      return false;
   return (out_factor > 0.0 && MathIsValidNumber(out_factor));
  }

bool Strategy_SwapCashPerLot(const string symbol,
                             const int direction,
                             double &out_cash)
  {
   out_cash = 0.0;
   if(direction != 1 && direction != -1)
      return false;
   if(!Strategy_RolloverMetadataComparable(symbol))
      return false;

   const ENUM_SYMBOL_SWAP_MODE mode =
      (ENUM_SYMBOL_SWAP_MODE)SymbolInfoInteger(symbol, SYMBOL_SWAP_MODE);
   if(mode == SYMBOL_SWAP_MODE_DISABLED)
      return false;
   const double raw_swap = (direction > 0)
      ? SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG)
      : SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
   if(!MathIsValidNumber(raw_swap))
      return false;

   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double reference_price = (bid > 0.0 && ask > 0.0)
      ? 0.5 * (bid + ask)
      : MathMax(bid, ask);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double tick_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = (raw_swap >= 0.0)
      ? SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT)
      : SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tick_value <= 0.0)
      tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   const double contract_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(reference_price <= 0.0 || point <= 0.0 || tick_size <= 0.0 ||
      tick_value <= 0.0 || contract_size <= 0.0)
      return false;

   if(mode == SYMBOL_SWAP_MODE_POINTS ||
      mode == SYMBOL_SWAP_MODE_REOPEN_CURRENT ||
      mode == SYMBOL_SWAP_MODE_REOPEN_BID)
      out_cash = raw_swap * point / tick_size * tick_value;
   else if(mode == SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT)
      out_cash = raw_swap;
   else if(mode == SYMBOL_SWAP_MODE_CURRENCY_SYMBOL)
     {
      double factor = 0.0;
      if(!Strategy_CurrencyToAccountFactor(
            symbol,
            SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE),
            reference_price,
            factor))
         return false;
      out_cash = raw_swap * factor;
     }
   else if(mode == SYMBOL_SWAP_MODE_CURRENCY_MARGIN)
     {
      double factor = 0.0;
      if(!Strategy_CurrencyToAccountFactor(
            symbol,
            SymbolInfoString(symbol, SYMBOL_CURRENCY_MARGIN),
            reference_price,
            factor))
         return false;
      out_cash = raw_swap * factor;
     }
   else if(mode == SYMBOL_SWAP_MODE_INTEREST_CURRENT ||
           mode == SYMBOL_SWAP_MODE_INTEREST_OPEN)
     {
      double factor = 0.0;
      if(!Strategy_CurrencyToAccountFactor(
            symbol,
            SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT),
            reference_price,
            factor))
         return false;
      const double annual_profit_currency =
         contract_size * reference_price * raw_swap / 100.0;
      out_cash = annual_profit_currency / 360.0 * factor;
     }
   else
      return false;

   return MathIsValidNumber(out_cash);
  }

bool Strategy_CarryCandidate(const int target_index,
                             StrategyCarryCandidate &candidate)
  {
   candidate.target_index = target_index;
   candidate.favorable_direction = 0;
   candidate.carry_cash_per_lot = 0.0;
   candidate.atr_cash_per_lot = 0.0;
   candidate.score = 0.0;
   if(target_index < 0 || target_index >= QM5_20292_TARGET_COUNT)
      return false;
   const string symbol = g_target_symbols[target_index];

   double long_cash = 0.0;
   double short_cash = 0.0;
   if(!Strategy_SwapCashPerLot(symbol, 1, long_cash) ||
      !Strategy_SwapCashPerLot(symbol, -1, short_cash))
      return false;

   if(long_cash > short_cash && long_cash > 0.0)
     {
      candidate.favorable_direction = 1;
      candidate.carry_cash_per_lot = long_cash;
     }
   else if(short_cash > long_cash && short_cash > 0.0)
     {
      candidate.favorable_direction = -1;
      candidate.carry_cash_per_lot = short_cash;
     }
   else
      return false;

   const double atr = QM_ATR(symbol, PERIOD_D1,
                             strategy_atr_period_d1, 1);
   const double tick_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tick_value <= 0.0)
      tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(atr <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0)
      return false;
   candidate.atr_cash_per_lot = atr / tick_size * tick_value;
   if(candidate.atr_cash_per_lot <= 0.0 ||
      !MathIsValidNumber(candidate.atr_cash_per_lot))
      return false;
   candidate.score = candidate.carry_cash_per_lot /
                     candidate.atr_cash_per_lot;
   return (candidate.score > 0.0 && MathIsValidNumber(candidate.score));
  }

bool Strategy_CandidatePrecedes(const StrategyCarryCandidate &left,
                                const StrategyCarryCandidate &right)
  {
   if(left.score > right.score + 1.0e-15)
      return true;
   if(right.score > left.score + 1.0e-15)
      return false;
   return (StringCompare(g_target_symbols[left.target_index],
                         g_target_symbols[right.target_index]) < 0);
  }

int Strategy_RankCarryCandidates(StrategyCarryCandidate &candidates[])
  {
   int count = 0;
   for(int i = 0; i < QM5_20292_TARGET_COUNT; ++i)
     {
      StrategyCarryCandidate candidate;
      if(!Strategy_CarryCandidate(i, candidate))
         continue;
      candidates[count] = candidate;
      ++count;
     }

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(!Strategy_CandidatePrecedes(candidates[i], candidates[j]))
           {
            const StrategyCarryCandidate swap_candidate = candidates[i];
            candidates[i] = candidates[j];
            candidates[j] = swap_candidate;
           }
   return count;
  }

double Strategy_LotsForLeg(const string symbol,
                           const double stop_distance,
                           const double risk_weight)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0 || stop_distance <= 0.0 || risk_weight <= 0.0)
      return 0.0;
   const double sl_points = stop_distance / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * risk_weight;
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

bool Strategy_PrepareLeg(const StrategyCarryCandidate &candidate,
                         QM_BasketOrderRequest &request)
  {
   const int index = candidate.target_index;
   if(index < 0 || index >= QM5_20292_TARGET_COUNT ||
      (candidate.favorable_direction != 1 &&
       candidate.favorable_direction != -1))
      return false;
   const string symbol = g_target_symbols[index];
   if(!Strategy_SpreadAllowed(symbol))
      return false;

   const int unwind_direction = -candidate.favorable_direction;
   const QM_OrderType type = (unwind_direction > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_OrderTypeIsBuy(type)
      ? SymbolInfoDouble(symbol, SYMBOL_ASK)
      : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1,
                             strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;
   const double stop_distance = strategy_atr_sl_mult * atr;
   const double risk_weight = 1.0 / (double)QM5_20292_PACKAGE_LEGS;
   const double lots = Strategy_LotsForLeg(symbol,
                                           stop_distance,
                                           risk_weight);
   if(lots <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   request.symbol = symbol;
   request.type = type;
   request.price = 0.0;
   request.sl = QM_OrderTypeIsBuy(type)
      ? NormalizeDouble(entry - stop_distance, digits)
      : NormalizeDouble(entry + stop_distance, digits);
   request.tp = 0.0;
   request.lots = lots;
   request.reason = (unwind_direction > 0)
      ? "QM5_20292_CARRY_UNWIND_BUY"
      : "QM5_20292_CARRY_UNWIND_SELL";
   request.symbol_slot = index;
   request.expiration_seconds = 0;
   return (request.sl > 0.0);
  }

bool Strategy_OpenCarryUnwindPackage()
  {
   if(Strategy_OpenPackageLegCount() > 0 ||
      strategy_selected_legs != QM5_20292_PACKAGE_LEGS)
      return false;

   StrategyCarryCandidate candidates[QM5_20292_TARGET_COUNT];
   const int valid_count = Strategy_RankCarryCandidates(candidates);
   if(valid_count < strategy_selected_legs)
      return false;

   QM_BasketOrderRequest requests[QM5_20292_PACKAGE_LEGS];
   for(int i = 0; i < QM5_20292_PACKAGE_LEGS; ++i)
      if(!Strategy_PrepareLeg(candidates[i], requests[i]))
         return false;

   ulong first_ticket = 0;
   if(!QM_BasketOpenPosition(qm_ea_id,
                             qm_news_mode_legacy,
                             strategy_deviation_points,
                             requests[0],
                             first_ticket))
      return false;

   ulong second_ticket = 0;
   if(QM_BasketOpenPosition(qm_ea_id,
                            qm_news_mode_legacy,
                            strategy_deviation_points,
                            requests[1],
                            second_ticket))
      return true;

   Strategy_ClosePackage(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(qm_ea_id != 20292 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(MathAbs(RISK_PERCENT) > 1.0e-12 ||
      MathAbs(RISK_FIXED - 1000.0) > 1.0e-12 ||
      MathAbs(PORTFOLIO_WEIGHT - 1.0) > 1.0e-12)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high")
      return true;
   if(!qm_friday_close_enabled || qm_friday_close_hour_broker != 21 ||
      MathAbs(qm_stress_reject_probability) > 1.0e-12)
      return true;
   if(strategy_rv_window_d1 != 21 ||
      strategy_rv_baseline_observations != 252 ||
      strategy_min_valid_signal_symbols != 5 ||
      MathAbs(strategy_stress_entry_ratio - 1.50) > 1.0e-12 ||
      MathAbs(strategy_stress_exit_ratio - 1.10) > 1.0e-12 ||
      strategy_selected_legs != 2 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 2.5) > 1.0e-12 ||
      strategy_max_hold_d1_bars != 5 ||
      strategy_spread_history_d1 != 20 ||
      MathAbs(strategy_spread_mult - 3.0) > 1.0e-12 ||
      strategy_history_bars != 320 ||
      strategy_max_endpoint_gap_days != 10 ||
      strategy_deviation_points != 20)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_BUY;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "QM5_20292_FX_CARRY_UNWIND_HOST";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(!g_week_entry_bar || !g_week_attempt_recorded ||
      g_current_week_key <= 0)
      return false;
   if(Strategy_OpenPackageLegCount() > 0)
      return false;
   if(!g_stress_valid ||
      g_stress_valid_symbols < strategy_min_valid_signal_symbols ||
      g_stress_ratio < strategy_stress_entry_ratio)
      return false;
   if(Strategy_NewsFilterHook(TimeCurrent()))
      return false;

   Strategy_OpenCarryUnwindPackage();
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int open_legs = Strategy_OpenPackageLegCount();
   if(open_legs <= 0)
      return;
   if(open_legs != QM5_20292_PACKAGE_LEGS ||
      !Strategy_PackageCompositionValid())
     {
      Strategy_ClosePackage(QM_EXIT_STRATEGY);
      return;
     }

   if(!g_new_d1_bar)
      return;
   if(!g_stress_valid || g_stress_ratio <= strategy_stress_exit_ratio)
     {
      Strategy_ClosePackage(QM_EXIT_STRATEGY);
      return;
     }

   const int held_bars = Strategy_MaxHeldD1Bars();
   if(held_bars >= strategy_max_hold_d1_bars)
      Strategy_ClosePackage(QM_EXIT_TIME_STOP);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   for(int i = 0; i < QM5_20292_TARGET_COUNT; ++i)
     {
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
         qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(g_target_symbols[i],
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance))
            return false;
        }
      else if(!QM_NewsAllowsTrade(g_target_symbols[i],
                                  broker_time,
                                  qm_news_mode_legacy))
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
   if(!Strategy_IsHostChart() || qm_ea_id != 20292 ||
      qm_magic_slot_offset != 0)
      return INIT_PARAMETERS_INCORRECT;

   for(int i = 0; i < QM5_20292_TARGET_COUNT; ++i)
      if(!SymbolSelect(g_target_symbols[i], true))
         return INIT_FAILED;
   for(int i = 0; i < QM5_20292_SIGNAL_COUNT; ++i)
      if(!SymbolSelect(g_signal_symbols[i], true))
         return INIT_FAILED;

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

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_week_attempt_state_key =
      StringFormat("QM5_20292_WEEK_ATTEMPT_%d",
                   QM_MagicChecked(qm_ea_id, 0, g_host_symbol));
   Strategy_LoadAttemptState();

   QM_SymbolGuardInit(g_target_symbols);
   QM_BasketWarmupHistory(g_target_symbols,
                          PERIOD_D1,
                          MathMax(400, strategy_history_bars));
   QM_BasketWarmupHistory(g_signal_symbols,
                          PERIOD_D1,
                          MathMax(400, strategy_history_bars));

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_20292\",\"ea\":\"fx-carry-unwind\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO,
               "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: sample floating P&L before every early return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   g_new_d1_bar = QM_IsNewBar();
   if(g_new_d1_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_AdvanceStateOnNewBar();
     }

   // Package lifecycle and orphan repair precede the entry-only news gate.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_ClosePackage(QM_EXIT_STRATEGY);
      return;
     }
   if(!g_new_d1_bar)
      return;

   QM_EntryRequest request;
   ZeroMemory(request);
   if(Strategy_EntrySignal(request))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(request, out_ticket);
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
