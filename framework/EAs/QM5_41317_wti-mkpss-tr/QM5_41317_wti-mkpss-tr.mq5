#property strict
#property version   "5.0"
#property description "QM5_41317 WTI Monthly KPSS Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41317 - WTI Monthly KPSS Nonstationarity-Gated Trend
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - reconstruct sixty consecutive completed broker-month-end closes
//   - form sixty natural-log price levels and demean them
//   - compute constant-only KPSS with fixed lag-four Bartlett covariance
//   - qualify at the inclusive source ten-percent critical value
//   - follow newest twelve-month WTI direction only when the path qualifies
//   - consume before fallible gates; never enter late or retry
// Runtime uses MT5-native XTIUSD.DWX price, calendar, ATR, and execution state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 41317;
input int    qm_magic_slot_offset          = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_level_count          = 60;
input int    strategy_covariance_lags      = 4;
input double strategy_residual_energy_floor = 0.000000000000000001;
input double strategy_long_run_variance_floor = 0.000000000000000001;
input double strategy_kpss_boundary        = 0.347;
input int    strategy_momentum_months       = 12;
input double strategy_direction_epsilon    = 0.000000000001;
input int    strategy_history_bars         = 1800;
input int    strategy_entry_grace_minutes  = 180;
input int    strategy_endpoint_stale_days  = 10;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_stale_days           = 40;
input int    strategy_max_spread_points    = 1500;

const string g_symbol = "XTIUSD.DWX";

struct Strategy_SignalMetrics
  {
   int direction;
   int endpoint_count;
   int level_count;
   bool kpss_qualified;
   double level_mean;
   double residual_energy;
   double eta;
   double lag1_cross;
   double lag2_cross;
   double lag3_cross;
   double lag4_cross;
   double long_run_variance;
   double kpss;
   double momentum_12;
   string level_path;
   string covariance_path;
   double oldest_close;
   double newest_close;
  };

int      g_last_attempt_month_key = 0;
string   g_attempt_state_key       = "";
bool     g_decision_bar            = false;
bool     g_late_decision           = false;
int      g_decision_month_key      = 0;
datetime g_decision_bar_time       = 0;
int      g_decision_label_offset   = 0;
int      g_current_month_bar_count = 0;
bool     g_signal_valid            = false;
Strategy_SignalMetrics g_signal_metrics;
datetime g_oldest_endpoint_time    = 0;
datetime g_newest_endpoint_time    = 0;
int      g_validation_month_key    = 0;
bool     g_validation_signal_valid = false;
int      g_validation_direction    = 0;
string   g_signal_state            = "idle";
string   g_entry_month_state_key    = "";
int      g_entry_month_key          = 0;

// -----------------------------------------------------------------------------
// Structural helpers.
// -----------------------------------------------------------------------------

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_symbol && _Period == PERIOD_D1);
  }

int Strategy_DateKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   if(parts.year < 1900 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_MonthKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   if(parts.year < 1900 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
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

int Strategy_LabelOffsetSeconds(const datetime current_bar_time,
                                const datetime broker_now)
  {
   if(current_bar_time <= 0 || broker_now < current_bar_time)
      return -1;
   const int raw_date = Strategy_DateKeyForTime(current_bar_time);
   const int broker_date = Strategy_DateKeyForTime(broker_now);
   if(raw_date <= 0 || broker_date <= 0)
      return -1;
   if(raw_date == broker_date)
      return 0;
   if(Strategy_DateKeyForTime(current_bar_time + (datetime)86400) ==
      broker_date)
      return 86400;
   return -1;
  }

datetime Strategy_NormalizedLabel(const datetime raw_label,
                                  const int label_offset)
  {
   if(raw_label <= 0 || (label_offset != 0 && label_offset != 86400))
      return 0;
   return raw_label + (datetime)label_offset;
  }

bool Strategy_EntryWithinGrace(const datetime current_bar_time,
                               const datetime broker_now)
  {
   if(current_bar_time <= 0 || broker_now < current_bar_time)
      return false;
   const long elapsed = (long)(broker_now - current_bar_time);
   return (elapsed <= (long)strategy_entry_grace_minutes * 60L);
  }

bool Strategy_IsOwnedPosition()
  {
   return ((int)PositionGetInteger(POSITION_MAGIC) ==
           QM_FrameworkMagic());
  }

int Strategy_OwnedPositionCount()
  {
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsOwnedPosition())
         ++count;
     }
   return count;
  }

bool Strategy_HasForeignSymbolPosition()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == g_symbol &&
         !Strategy_IsOwnedPosition())
         return true;
     }
   return false;
  }

bool Strategy_OwnedPositionStateValid()
  {
   if(Strategy_OwnedPositionCount() != 1)
      return false;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_symbol)
         return false;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const double take_profit = PositionGetDouble(POSITION_TP);
      if(take_profit != 0.0 || !MathIsValidNumber(take_profit))
         return false;
      if((type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL) ||
         opened <= 0 || opened > TimeCurrent() ||
         volume <= 0.0 || !MathIsValidNumber(volume) ||
         open_price <= 0.0 || !MathIsValidNumber(open_price) ||
         stop_price <= 0.0 || !MathIsValidNumber(stop_price))
         return false;
      if(type == POSITION_TYPE_BUY && stop_price >= open_price)
         return false;
      if(type == POSITION_TYPE_SELL && stop_price <= open_price)
         return false;
      return true;
     }
   return false;
  }

datetime Strategy_CurrentEntryTime()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      return (datetime)PositionGetInteger(POSITION_TIME);
     }
   return 0;
  }

void Strategy_LoadEntryMonthState(const datetime reference_time)
  {
   g_entry_month_key = 0;
   if(g_entry_month_state_key == "" ||
      !GlobalVariableCheck(g_entry_month_state_key))
      return;
   const int current_month_key = Strategy_MonthKeyForTime(reference_time);
   const double stored = GlobalVariableGet(g_entry_month_state_key);
   const int stored_month_key = (int)MathRound(stored);
   if(current_month_key > 0 && MathIsValidNumber(stored) &&
      stored_month_key >= 190001 && stored_month_key <= current_month_key)
     {
      g_entry_month_key = stored_month_key;
      return;
     }
   GlobalVariableDel(g_entry_month_state_key);
  }

bool Strategy_RecordEntryMonth(const int month_key)
  {
   if(month_key <= 0 || g_entry_month_state_key == "")
      return false;
   g_entry_month_key = month_key;
   return (GlobalVariableSet(g_entry_month_state_key,
                             (double)month_key) > 0);
  }

bool Strategy_RecoverEntryMonthFromDeals(
   const ulong position_id,
   const ENUM_POSITION_TYPE position_type,
   int &entry_month_key)
  {
   entry_month_key = 0;
   if(position_id == 0 || !HistorySelectByPosition(position_id))
      return false;
   const int magic = QM_FrameworkMagic();
   const int deal_count = HistoryDealsTotal();
   for(int index = 0; index < deal_count; ++index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != g_symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      if((position_type == POSITION_TYPE_BUY &&
          deal_type != DEAL_TYPE_BUY) ||
         (position_type == POSITION_TYPE_SELL &&
          deal_type != DEAL_TYPE_SELL))
         return false;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      const int deal_month_key = Strategy_MonthKeyForTime(deal_time);
      if(deal_month_key <= 0)
         return false;
      if(entry_month_key != 0 && entry_month_key != deal_month_key)
         return false;
      entry_month_key = deal_month_key;
     }
   return (entry_month_key > 0);
  }

bool Strategy_ResolveEntryMonth(int &entry_month_key)
  {
   entry_month_key = 0;
   if(Strategy_OwnedPositionCount() != 1)
      return false;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const int opened_month_key = Strategy_MonthKeyForTime(opened);
      const ulong position_id =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(opened_month_key <= 0 || position_id == 0)
         return false;

      if(g_entry_month_key > 0)
        {
         if(g_entry_month_key != opened_month_key)
            return false;
         entry_month_key = g_entry_month_key;
         return true;
        }

      int recovered_month_key = 0;
      if(!Strategy_RecoverEntryMonthFromDeals(position_id,
                                              position_type,
                                              recovered_month_key) ||
         recovered_month_key != opened_month_key ||
         !Strategy_RecordEntryMonth(recovered_month_key))
         return false;
      entry_month_key = recovered_month_key;
      return true;
     }
   return false;
  }

void Strategy_CloseOwnedPositions(const QM_ExitReason reason)
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_SpreadAllowed()
  {
   MqlTick tick;
   ZeroMemory(tick);
   if(!SymbolInfoTick(_Symbol, tick) ||
      tick.bid <= 0.0 || tick.ask <= 0.0 ||
      !MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask) ||
      tick.ask < tick.bid)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || !MathIsValidNumber(point))
      return false;
   const double spread_points = (tick.ask - tick.bid) / point;
   return (MathIsValidNumber(spread_points) && spread_points >= 0.0 &&
           spread_points <= (double)strategy_max_spread_points);
  }

bool Strategy_MonthAlreadyEntered(const int month_key)
  {
   if(month_key <= 0)
      return true;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKeyForTime(opened) == month_key)
         return true;
     }

   const datetime now = TimeCurrent();
   const datetime history_start = now - (long)100 * 86400;
   if(history_start <= 0 || !HistorySelect(history_start, now))
      return true;
   const int magic = QM_FrameworkMagic();
   const int deal_count = HistoryDealsTotal();
   for(int index = deal_count - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_MonthKeyForTime(deal_time) == month_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_month_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;
   const int current_month_key =
      Strategy_MonthKeyForTime(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_month_key = (int)MathRound(stored);
   if(current_month_key > 0 && MathIsValidNumber(stored) &&
      stored_month_key >= 190001 &&
      stored_month_key <= current_month_key)
     {
      g_last_attempt_month_key = stored_month_key;
      return;
     }
   // Tester globals can outlive a later historical run.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordMonthAttempt(const int month_key)
  {
   if(month_key <= 0 || g_attempt_state_key == "")
      return false;
   // Stay fail-closed in-process even if terminal persistence fails.
   g_last_attempt_month_key = month_key;
   return (GlobalVariableSet(g_attempt_state_key,
                             (double)month_key) > 0);
  }

bool Strategy_BarCloseValid(const MqlRates &bar)
  {
   return (bar.time > 0 &&
           bar.close > 0.0 &&
           MathIsValidNumber(bar.close));
  }

void Strategy_ResetDecisionState()
  {
   g_decision_bar = false;
   g_late_decision = false;
   g_decision_month_key = 0;
   g_decision_bar_time = 0;
   g_decision_label_offset = 0;
   g_current_month_bar_count = 0;
   g_signal_valid = false;
   ZeroMemory(g_signal_metrics);
   g_oldest_endpoint_time = 0;
   g_newest_endpoint_time = 0;
   g_signal_state = "idle";
  }

void Strategy_DetectDecisionClock_OnNewBar()
  {
   Strategy_ResetDecisionState();
   MqlRates current_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar) ||
      current_bar.time <= 0)
      return;

   const datetime broker_now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(current_bar.time, broker_now);
   if(label_offset < 0)
      return;
   const datetime normalized_current =
      Strategy_NormalizedLabel(current_bar.time, label_offset);
   const int current_month_key =
      Strategy_MonthKeyForTime(normalized_current);
   if(current_month_key <= 0 ||
      current_month_key != Strategy_MonthKeyForTime(broker_now) ||
      Strategy_DateKeyForTime(normalized_current) !=
         Strategy_DateKeyForTime(broker_now))
      return;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded month-clock scan behind the sole QM_IsNewBar branch.
                PERIOD_D1,
                1,
                strategy_history_bars,
                bars);
   if(copied <= 0)
      return;

   int current_month_count = 0;
   while(current_month_count < copied &&
         Strategy_MonthKeyForTime(
            Strategy_NormalizedLabel(bars[current_month_count].time,
                                     label_offset)) == current_month_key)
      ++current_month_count;
   if(current_month_count >= copied)
      return;

   const int prior_month_key =
      Strategy_MonthKeyForTime(
         Strategy_NormalizedLabel(bars[current_month_count].time,
                                  label_offset));
   if(prior_month_key <= 0 ||
      Strategy_NextMonthKey(prior_month_key) != current_month_key)
      return;

   g_decision_bar = true;
   g_decision_month_key = current_month_key;
   g_decision_bar_time = current_bar.time;
   g_decision_label_offset = label_offset;
   g_current_month_bar_count = current_month_count;
   g_late_decision =
      (current_month_count > 0 ||
       !Strategy_EntryWithinGrace(current_bar.time, broker_now));
  }

bool Strategy_LoadMonthlyEndpoints(const int current_month_key,
                                   const int label_offset,
                                   double &closes[],
                                   datetime &endpoint_times[])
  {
   ArrayResize(closes, 0);
   ArrayResize(endpoint_times, 0);
   const int endpoint_target = strategy_level_count;
   if(current_month_key <= 0 ||
      strategy_level_count != 60 || endpoint_target != 60 ||
      strategy_history_bars != 1800 ||
      strategy_endpoint_stale_days != 10 ||
      (label_offset != 0 && label_offset != 86400))
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: one bounded sixty-month scan behind a consumed monthly attempt or monthly restart validation.
                PERIOD_D1,
                1,
                strategy_history_bars,
                bars);
   if(copied <= 0)
      return false;

   double reverse_closes[];
   datetime reverse_times[];
   int reverse_month_keys[];
   if(ArrayResize(reverse_closes, endpoint_target) != endpoint_target ||
      ArrayResize(reverse_times, endpoint_target) != endpoint_target ||
      ArrayResize(reverse_month_keys, endpoint_target) != endpoint_target)
      return false;

   int endpoint_count = 0;
   int last_month_key = 0;
   bool completed_history_started = false;
   for(int index = 0;
       index < copied && endpoint_count < endpoint_target;
       ++index)
     {
      if(index > 0 && bars[index - 1].time <= bars[index].time)
         return false;
      if(!Strategy_BarCloseValid(bars[index]))
         return false;

      const datetime normalized_label =
         Strategy_NormalizedLabel(bars[index].time, label_offset);
      const int month_key =
         Strategy_MonthKeyForTime(normalized_label);
      if(normalized_label <= 0 || month_key <= 0)
         return false;

      if(month_key == current_month_key)
        {
         if(completed_history_started)
            return false;
         continue;
        }
      completed_history_started = true;

      if(endpoint_count <= 0 || month_key != last_month_key)
        {
         if(endpoint_count == 0)
           {
            if(Strategy_NextMonthKey(month_key) != current_month_key)
               return false;
           }
         else if(Strategy_NextMonthKey(month_key) != last_month_key)
            return false;

         if(endpoint_count < 0 ||
            endpoint_count >= ArraySize(reverse_closes))
            return false;
         if(endpoint_count >= ArraySize(reverse_times))
            return false;
         if(endpoint_count >= ArraySize(reverse_month_keys))
            return false;
         reverse_closes[endpoint_count] = bars[index].close;
         reverse_times[endpoint_count] = normalized_label;
         reverse_month_keys[endpoint_count] = month_key;
         last_month_key = month_key;
         ++endpoint_count;
        }
     }

   if(endpoint_count != endpoint_target || endpoint_count != 60)
      return false;

   const datetime broker_now = TimeCurrent();
   const long newest_age = (long)(broker_now - reverse_times[0]);
   if(broker_now <= 0 || reverse_times[0] <= 0 ||
      newest_age < 0 ||
      newest_age > (long)strategy_endpoint_stale_days * 86400L)
      return false;

   if(ArrayResize(closes, endpoint_count) != endpoint_count ||
      ArrayResize(endpoint_times, endpoint_count) != endpoint_count)
      return false;

   int chronological_month_keys[];
   if(ArrayResize(chronological_month_keys, endpoint_count) !=
      endpoint_count)
      return false;
   for(int index = 0; index < endpoint_count; ++index)
     {
      const int reverse_index = endpoint_count - 1 - index;
      if(reverse_index < 0 ||
         reverse_index >= ArraySize(reverse_closes))
         return false;
      if(reverse_index >= ArraySize(reverse_times))
         return false;
      if(reverse_index >= ArraySize(reverse_month_keys))
         return false;
      closes[index] = reverse_closes[reverse_index];
      endpoint_times[index] = reverse_times[reverse_index];
      chronological_month_keys[index] =
         reverse_month_keys[reverse_index];
      if(closes[index] <= 0.0 ||
         !MathIsValidNumber(closes[index]) ||
         endpoint_times[index] <= 0 ||
         (index > 0 &&
          endpoint_times[index] <= endpoint_times[index - 1]))
         return false;
      if(index > 0 &&
         Strategy_NextMonthKey(chronological_month_keys[index - 1]) !=
            chronological_month_keys[index])
         return false;
     }

   if(Strategy_NextMonthKey(
         chronological_month_keys[endpoint_count - 1]) !=
      current_month_key)
      return false;
   return true;
  }

bool Strategy_KPSSCore(const double &levels[],
                       double &level_mean,
                       double &residual_energy,
                       double &eta,
                       double &lag1_cross,
                       double &lag2_cross,
                       double &lag3_cross,
                       double &lag4_cross,
                       double &long_run_variance,
                       double &kpss,
                       string &covariance_path)
  {
   level_mean = 0.0;
   residual_energy = 0.0;
   eta = 0.0;
   lag1_cross = 0.0;
   lag2_cross = 0.0;
   lag3_cross = 0.0;
   lag4_cross = 0.0;
   long_run_variance = 0.0;
   kpss = 0.0;
   covariance_path = "";

   const int level_count = ArraySize(levels);
   if(level_count != 60 || strategy_level_count != 60 ||
      strategy_covariance_lags != 4 ||
      strategy_residual_energy_floor != 0.000000000000000001 ||
      strategy_long_run_variance_floor != 0.000000000000000001)
      return false;

   for(int index = 0; index < level_count; ++index)
     {
      if(!MathIsValidNumber(levels[index]))
         return false;
      level_mean += levels[index];
      if(!MathIsValidNumber(level_mean))
         return false;
     }
   level_mean /= (double)level_count;
   if(!MathIsValidNumber(level_mean))
      return false;

   double residuals[60];
   double partial_sum = 0.0;
   double eta_numerator = 0.0;
   for(int index = 0; index < level_count; ++index)
     {
      residuals[index] = levels[index] - level_mean;
      const double residual_square = residuals[index] * residuals[index];
      partial_sum += residuals[index];
      const double partial_square = partial_sum * partial_sum;
      if(!MathIsValidNumber(residuals[index]) ||
         !MathIsValidNumber(residual_square) || residual_square < 0.0 ||
         !MathIsValidNumber(partial_sum) ||
         !MathIsValidNumber(partial_square) || partial_square < 0.0)
         return false;
      residual_energy += residual_square;
      eta_numerator += partial_square;
      if(!MathIsValidNumber(residual_energy) ||
         !MathIsValidNumber(eta_numerator))
         return false;
     }
   if(residual_energy <= strategy_residual_energy_floor)
      return false;
   eta = eta_numerator /
         ((double)level_count * (double)level_count);
   if(!MathIsValidNumber(eta) || eta < 0.0)
      return false;

   double lag_cross[4];
   double long_run_numerator = residual_energy;
   for(int lag = 1; lag <= strategy_covariance_lags; ++lag)
     {
      lag_cross[lag - 1] = 0.0;
      for(int index = lag; index < level_count; ++index)
        {
         const double product = residuals[index] * residuals[index - lag];
         if(!MathIsValidNumber(product))
            return false;
         lag_cross[lag - 1] += product;
         if(!MathIsValidNumber(lag_cross[lag - 1]))
            return false;
        }
      const double weight =
         1.0 - (double)lag / (double)(strategy_covariance_lags + 1);
      if(!MathIsValidNumber(weight) || weight <= 0.0 || weight >= 1.0)
         return false;
      long_run_numerator += 2.0 * weight * lag_cross[lag - 1];
      if(!MathIsValidNumber(long_run_numerator))
         return false;
     }
   lag1_cross = lag_cross[0];
   lag2_cross = lag_cross[1];
   lag3_cross = lag_cross[2];
   lag4_cross = lag_cross[3];
   long_run_variance = long_run_numerator / (double)level_count;
   if(!MathIsValidNumber(long_run_variance) ||
      long_run_variance <= strategy_long_run_variance_floor)
      return false;

   kpss = eta / long_run_variance;
   if(!MathIsValidNumber(kpss) || kpss < 0.0)
      return false;
   covariance_path =
      StringFormat("lag1=%.16f,lag2=%.16f,lag3=%.16f,lag4=%.16f",
                   lag1_cross,
                   lag2_cross,
                   lag3_cross,
                   lag4_cross);
   return (StringLen(covariance_path) > 0);
  }

bool Strategy_KPSSReferenceSelfTest()
  {
   double stationary_path[60];
   double trending_path[60];
   double shifted_path[60];
   double constant_path[60];
   for(int index = 0; index < 60; ++index)
     {
      stationary_path[index] =
         4.2 + 0.02 * MathSin(0.71 * (double)index) +
         0.01 * MathCos(0.23 * (double)index);
      trending_path[index] =
         4.0 + 0.012 * (double)index +
         0.025 * MathSin(0.31 * (double)index) +
         0.007 * MathCos(0.13 * (double)index);
      shifted_path[index] = trending_path[index] + 3.0;
      constant_path[index] = 4.2;
     }

   double level_mean = 0.0;
   double residual_energy = 0.0;
   double eta = 0.0;
   double lag1_cross = 0.0;
   double lag2_cross = 0.0;
   double lag3_cross = 0.0;
   double lag4_cross = 0.0;
   double long_run_variance = 0.0;
   double kpss = 0.0;
   string covariance_path = "";
   if(!Strategy_KPSSCore(stationary_path,
                         level_mean,
                         residual_energy,
                         eta,
                         lag1_cross,
                         lag2_cross,
                         lag3_cross,
                         lag4_cross,
                         long_run_variance,
                         kpss,
                         covariance_path) ||
      MathAbs(level_mean - 4.2012656466414855) > 0.000000000001 ||
      MathAbs(eta - 0.000035705149216046106) > 0.000000000001 ||
      MathAbs(long_run_variance - 0.0005902870983839596) >
         0.000000000001 ||
      MathAbs(kpss - 0.06048776826360729) > 0.000000000001 ||
      kpss >= strategy_kpss_boundary ||
      StringLen(covariance_path) <= 0)
      return false;

   if(!Strategy_KPSSCore(trending_path,
                         level_mean,
                         residual_energy,
                         eta,
                         lag1_cross,
                         lag2_cross,
                         lag3_cross,
                         lag4_cross,
                         long_run_variance,
                         kpss,
                         covariance_path) ||
      MathAbs(level_mean - 4.355042807880309) > 0.000000000001 ||
      MathAbs(eta - 0.25320831609291167) > 0.000000000001 ||
      MathAbs(long_run_variance - 0.1944633107748587) >
         0.000000000001 ||
      MathAbs(kpss - 1.302087859576069) > 0.000000000001 ||
      kpss < strategy_kpss_boundary ||
      MathAbs((trending_path[59] - trending_path[47]) -
              0.10242055751093648) > 0.000000000001)
      return false;

   double shifted_mean = 0.0;
   double shifted_energy = 0.0;
   double shifted_eta = 0.0;
   double shifted_lag1 = 0.0;
   double shifted_lag2 = 0.0;
   double shifted_lag3 = 0.0;
   double shifted_lag4 = 0.0;
   double shifted_long_run_variance = 0.0;
   double shifted_kpss = 0.0;
   string shifted_covariance_path = "";
   if(!Strategy_KPSSCore(shifted_path,
                         shifted_mean,
                         shifted_energy,
                         shifted_eta,
                         shifted_lag1,
                         shifted_lag2,
                         shifted_lag3,
                         shifted_lag4,
                         shifted_long_run_variance,
                         shifted_kpss,
                         shifted_covariance_path) ||
      MathAbs(shifted_energy - residual_energy) > 0.000000000001 ||
      MathAbs(shifted_eta - eta) > 0.000000000001 ||
      MathAbs(shifted_long_run_variance - long_run_variance) >
         0.000000000001 ||
      MathAbs(shifted_kpss - kpss) > 0.000000000001)
      return false;

   if(Strategy_KPSSCore(constant_path,
                        level_mean,
                        residual_energy,
                        eta,
                        lag1_cross,
                        lag2_cross,
                        lag3_cross,
                        lag4_cross,
                        long_run_variance,
                        kpss,
                        covariance_path))
      return false;
   return true;
  }

bool Strategy_KPSSSignal(const double &closes[],
                         Strategy_SignalMetrics &metrics)
  {
   ZeroMemory(metrics);
   metrics.level_path = "";
   metrics.covariance_path = "";
   metrics.endpoint_count = ArraySize(closes);
   metrics.level_count = strategy_level_count;
   metrics.direction = 0;
   metrics.kpss_qualified = false;

   if(strategy_level_count != 60 ||
      strategy_covariance_lags != 4 ||
      strategy_residual_energy_floor != 0.000000000000000001 ||
      strategy_long_run_variance_floor != 0.000000000000000001 ||
      MathAbs(strategy_kpss_boundary - 0.347) >
         0.000000000000001 ||
      strategy_momentum_months != 12 ||
      MathAbs(strategy_direction_epsilon - 0.000000000001) >
         0.000000000000000001 ||
      metrics.endpoint_count != strategy_level_count)
      return false;

   double levels[60];
   for(int index = 0; index < metrics.endpoint_count; ++index)
     {
      if(index < 0 || index >= 60 ||
         closes[index] <= 0.0 || !MathIsValidNumber(closes[index]))
         return false;
      levels[index] = MathLog(closes[index]);
      if(!MathIsValidNumber(levels[index]))
         return false;
      if(StringLen(metrics.level_path) > 0)
         metrics.level_path += ",";
      metrics.level_path += DoubleToString(levels[index], 12);
     }
   if(StringLen(metrics.level_path) <= 0)
      return false;

   if(!Strategy_KPSSCore(levels,
                         metrics.level_mean,
                         metrics.residual_energy,
                         metrics.eta,
                         metrics.lag1_cross,
                         metrics.lag2_cross,
                         metrics.lag3_cross,
                         metrics.lag4_cross,
                         metrics.long_run_variance,
                         metrics.kpss,
                         metrics.covariance_path))
      return false;
   metrics.kpss_qualified =
      (metrics.kpss >= strategy_kpss_boundary);

   const int momentum_start =
      strategy_level_count - strategy_momentum_months - 1;
   if(momentum_start != 47)
      return false;
   metrics.momentum_12 =
      levels[strategy_level_count - 1] - levels[momentum_start];
   metrics.oldest_close = closes[0];
   metrics.newest_close = closes[metrics.endpoint_count - 1];
   if(!MathIsValidNumber(metrics.momentum_12) ||
      metrics.oldest_close <= 0.0 || metrics.newest_close <= 0.0)
      return false;

   if(!metrics.kpss_qualified)
      return true;
   if(metrics.momentum_12 > strategy_direction_epsilon)
      metrics.direction = 1;
   else if(metrics.momentum_12 < -strategy_direction_epsilon)
      metrics.direction = -1;
   return true;
  }
bool Strategy_ExpectedDirectionForMonth(const int current_month_key,
                                        const int label_offset,
                                        int &direction)
  {
   direction = 0;
   if(current_month_key <= 0)
      return false;
   if(g_decision_month_key == current_month_key &&
      g_signal_valid && g_signal_metrics.direction != 0)
     {
      direction = g_signal_metrics.direction;
      return true;
     }
   if(g_validation_month_key == current_month_key)
     {
      direction = g_validation_direction;
      return (g_validation_signal_valid && direction != 0);
     }

   double closes[];
   datetime endpoint_times[];
   Strategy_SignalMetrics metrics;
   const bool valid =
      Strategy_LoadMonthlyEndpoints(current_month_key,
                                    label_offset,
                                    closes,
                                    endpoint_times) &&
       Strategy_KPSSSignal(closes, metrics);

   g_validation_month_key = current_month_key;
   g_validation_signal_valid = valid;
   g_validation_direction = valid ? metrics.direction : 0;
   direction = g_validation_direction;
   return (valid && direction != 0);
  }

bool Strategy_OwnedPositionDirectionMatches(const int direction)
  {
   if(direction == 0)
      return false;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return ((direction > 0 && type == POSITION_TYPE_BUY) ||
              (direction < 0 && type == POSITION_TYPE_SELL));
     }
   return false;
  }

void Strategy_PrepareDecisionSignal()
  {
   if(!g_decision_bar || g_decision_month_key <= 0 ||
      g_decision_bar_time <= 0)
      return;
   if(g_decision_month_key == g_last_attempt_month_key)
     {
      g_signal_state = "month_already_consumed";
      return;
     }

   // Consume before history, arithmetic, news, spread, quote, ATR, sizing,
   // margin, or order gates. The broker-month clock is the sole prerequisite.
   if(!Strategy_RecordMonthAttempt(g_decision_month_key))
     {
      g_signal_state = "attempt_persist_failed";
      return;
     }

   if(Strategy_MonthAlreadyEntered(g_decision_month_key))
      g_signal_state = "entry_deal_already_exists";
   else if(g_late_decision)
      g_signal_state = "late_restart_consumed_flat";
   else
     {
      double closes[];
      datetime endpoint_times[];
      const bool endpoints_valid =
         Strategy_LoadMonthlyEndpoints(g_decision_month_key,
                                       g_decision_label_offset,
                                       closes,
                                       endpoint_times);
      if(endpoints_valid)
        {
         g_signal_metrics.endpoint_count = ArraySize(closes);
         if(ArraySize(endpoint_times) == g_signal_metrics.endpoint_count &&
             g_signal_metrics.endpoint_count == strategy_level_count)
           {
            g_oldest_endpoint_time = endpoint_times[0];
            g_newest_endpoint_time =
               endpoint_times[g_signal_metrics.endpoint_count - 1];
           }
        }

      g_signal_valid =
         endpoints_valid &&
          Strategy_KPSSSignal(closes, g_signal_metrics);
      if(!g_signal_valid)
         g_signal_state = "kpss_validation_failed";
      else if(!g_signal_metrics.kpss_qualified)
         g_signal_state = "kpss_below_boundary_consumed_flat";
      else if(g_signal_metrics.direction == 0)
         g_signal_state = "qualified_neutral_momentum_consumed_flat";
      else if(g_signal_metrics.direction > 0)
         g_signal_state = "kpss_qualified_positive_momentum_wti_long";
      else if(g_signal_metrics.direction < 0)
         g_signal_state = "kpss_qualified_negative_momentum_wti_short";
      else
         g_signal_state = "invalid_direction_flat";

      g_validation_month_key = g_decision_month_key;
      g_validation_signal_valid = g_signal_valid;
      g_validation_direction = g_signal_metrics.direction;
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"completed_current_month_bars\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"endpoint_count\":%d,\"level_count\":%d,\"level_mean\":%.12f,\"residual_energy\":%.16f,\"eta\":%.16f,\"lag1_cross\":%.16f,\"lag2_cross\":%.16f,\"lag3_cross\":%.16f,\"lag4_cross\":%.16f,\"long_run_variance\":%.16f,\"kpss\":%.12f,\"kpss_qualified\":%s,\"momentum_12\":%.12f,\"levels\":\"%s\",\"covariances\":\"%s\",\"oldest_close\":%.10f,\"newest_close\":%.10f,\"oldest_endpoint\":%I64d,\"newest_endpoint\":%I64d,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_current_month_bar_count,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_metrics.direction,
                            g_signal_metrics.endpoint_count,
                            g_signal_metrics.level_count,
                            g_signal_metrics.level_mean,
                            g_signal_metrics.residual_energy,
                            g_signal_metrics.eta,
                            g_signal_metrics.lag1_cross,
                            g_signal_metrics.lag2_cross,
                            g_signal_metrics.lag3_cross,
                            g_signal_metrics.lag4_cross,
                            g_signal_metrics.long_run_variance,
                            g_signal_metrics.kpss,
                            g_signal_metrics.kpss_qualified ? "true" : "false",
                            g_signal_metrics.momentum_12,
                            g_signal_metrics.level_path,
                            g_signal_metrics.covariance_path,
                            g_signal_metrics.oldest_close,
                            g_signal_metrics.newest_close,
                            (long)g_oldest_endpoint_time,
                            (long)g_newest_endpoint_time,
                            g_signal_state));
  }
// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41317 ||
      qm_magic_slot_offset != 0 ||
      QM_FrameworkMagic() != 413170000 ||
      qm_rng_seed != 42)
      return true;
   if(RISK_PERCENT != 0.0 || RISK_FIXED != 1000.0 ||
      PORTFOLIO_WEIGHT != 1.0)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high")
      return true;
   if(qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21 ||
      MathAbs(qm_stress_reject_probability) > 0.000000000001)
      return true;
   if(strategy_level_count != 60 ||
      strategy_covariance_lags != 4 ||
      strategy_residual_energy_floor != 0.000000000000000001 ||
      strategy_long_run_variance_floor != 0.000000000000000001 ||
      MathAbs(strategy_kpss_boundary - 0.347) >
         0.000000000000001 ||
      strategy_momentum_months != 12 ||
      MathAbs(strategy_direction_epsilon -
              0.000000000001) >
         0.000000000000000001 ||
      strategy_history_bars != 1800 ||
      strategy_entry_grace_minutes != 180 ||
      strategy_endpoint_stale_days != 10 ||
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 0.000000000001 ||
      strategy_stale_days != 40 ||
      strategy_max_spread_points != 1500)
      return true;
   return false;
  }
// -----------------------------------------------------------------------------
// Trade Entry.
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_41317_WTI_KPSS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_decision_bar || g_late_decision ||
      g_decision_month_key <= 0 ||
      g_decision_month_key != g_last_attempt_month_key ||
      !g_signal_valid || g_signal_metrics.direction == 0)
      return false;
   if(Strategy_OwnedPositionCount() > 0 ||
      Strategy_HasForeignSymbolPosition() ||
      !Strategy_SpreadAllowed())
      return false;

   const double atr_value =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.type =
      (g_signal_metrics.direction > 0) ? QM_BUY : QM_SELL;
   req.reason = (g_signal_metrics.direction > 0)
      ? "WTI_KPSS_MOM_LONG"
      : "WTI_KPSS_MOM_SHORT";
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_value,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if((req.type == QM_BUY && req.sl >= entry_price) ||
      (req.type == QM_SELL && req.sl <= entry_price))
      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management.
// -----------------------------------------------------------------------------

void Strategy_ManageOpenPosition()
  {
   const int owned_count = Strategy_OwnedPositionCount();
   if(owned_count <= 0)
     {
      if(g_entry_month_key > 0)
        {
         g_entry_month_key = 0;
         if(g_entry_month_state_key != "")
            GlobalVariableDel(g_entry_month_state_key);
        }
      return;
     }
   if(owned_count != 1 || !Strategy_OwnedPositionStateValid())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   MqlRates current_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar) ||
      current_bar.time <= 0)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   const datetime now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(current_bar.time, now);
   const datetime normalized_current =
      Strategy_NormalizedLabel(current_bar.time, label_offset);
   const datetime opened = Strategy_CurrentEntryTime();
   const int current_month_key =
      Strategy_MonthKeyForTime(normalized_current);
   int entry_month_key = 0;
   if(label_offset < 0 || current_month_key <= 0 ||
      opened <= 0 || opened > now ||
      !Strategy_ResolveEntryMonth(entry_month_key) ||
      entry_month_key <= 0)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   if(entry_month_key != current_month_key)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   int expected_direction = 0;
   if(!Strategy_ExpectedDirectionForMonth(current_month_key,
                                          label_offset,
                                          expected_direction) ||
      !Strategy_OwnedPositionDirectionMatches(expected_direction))
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   const long hold_seconds =
      (long)MathMax(1, strategy_stale_days) * 86400;
   if((long)(now - opened) >= hold_seconds)
      Strategy_CloseOwnedPositions(QM_EXIT_TIME_STOP);
  }
// -----------------------------------------------------------------------------
// Trade Close and news hooks.
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

// -----------------------------------------------------------------------------
// Framework wiring.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!SymbolSelect(g_symbol, true) ||
      !Strategy_IsHostChart() || qm_ea_id != 41317 ||
      qm_magic_slot_offset != 0)
      return INIT_PARAMETERS_INCORRECT;
   if(!Strategy_KPSSReferenceSelfTest())
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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_DISABLED,
         "Approved WTI monthly KPSS trend holds through Fridays until the next broker month"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41317_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   g_entry_month_state_key =
      StringFormat("QM5_41317_ENTRY_MONTH_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());
   Strategy_LoadEntryMonthState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41317\",\"ea\":\"wti-mkpss-tr\"}");
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
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   g_decision_bar = false;
   if(new_bar)
      Strategy_DetectDecisionClock_OnNewBar();

   // Lifecycle repair and next-month closure precede entry-only gates and
   // run every tick, so a failed close is retried until flat.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(!new_bar)
      return;
   if(g_decision_bar)
      Strategy_PrepareDecisionSignal();

   // Attempt persistence happens before this entry-only news check. Both
   // axes are card-locked OFF.
   if(Strategy_NewsFilterHook(broker_now))
      return;

   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket) &&
         !Strategy_RecordEntryMonth(g_decision_month_key))
         Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
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
