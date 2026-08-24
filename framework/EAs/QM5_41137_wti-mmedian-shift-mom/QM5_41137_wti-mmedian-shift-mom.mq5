#property strict
#property version   "5.0"
#property description "QM5_41137 WTI Two-Completed-Month Median-Location Shift Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41137 - WTI Two-Completed-Month Median-Location Shift Momentum
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - reconstruct the two immediately completed broker-calendar months
//   - transform every accepted daily close to an independent log-price level
//   - sort each complete monthly sample independently without rounding
//   - calculate the ordinary odd/even sample median for each month
//   - follow the strict newest-minus-parent median-location shift
//   - consume the month before fallible gates; never enter late or retry
//   - hold the robust two-month location direction for one broker month
// Runtime uses MT5-native completed closes, calendar, and framework state only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 41137;
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
input int    strategy_entry_grace_minutes  = 180;
input int    strategy_history_bars_d1      = 70;
input int    strategy_min_month_sessions   = 17;
input int    strategy_max_month_sessions   = 23;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_max_hold_days        = 40;
input int    strategy_max_spread_points    = 1500;
input int    strategy_deviation_points     = 20;

const string g_symbol = "XTIUSD.DWX";

int      g_last_attempt_month_key = 0;
string   g_attempt_state_key       = "";
bool     g_decision_bar            = false;
bool     g_late_decision           = false;
int      g_decision_month_key      = 0;
datetime g_decision_bar_time       = 0;
int      g_decision_label_offset   = 0;
int      g_current_month_bar_count = 0;
bool     g_signal_valid            = false;
int      g_signal_direction        = 0;
int      g_newest_month_key        = 0;
int      g_parent_month_key        = 0;
int      g_newest_month_sessions   = 0;
int      g_parent_month_sessions   = 0;
double   g_newest_median           = 0.0;
double   g_parent_median           = 0.0;
double   g_median_shift            = 0.0;
string   g_signal_state            = "idle";

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
   return (elapsed <=
           (long)strategy_entry_grace_minutes * 60L);
  }

bool Strategy_IsOwnedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == g_symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
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
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
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
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points >= 0 &&
           spread_points <= strategy_max_spread_points);
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
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != g_symbol)
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

bool Strategy_ReconcileAttemptState(const datetime reference_time)
  {
   const int current_month_key = Strategy_MonthKeyForTime(reference_time);
   if(reference_time <= 0 || current_month_key <= 0)
      return false;

   int greatest_month_key = g_last_attempt_month_key;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const int opened_month_key = Strategy_MonthKeyForTime(opened);
      if(opened <= 0 || opened > reference_time || opened_month_key <= 0 ||
         opened_month_key > current_month_key)
         return false;
      if(opened_month_key > greatest_month_key)
         greatest_month_key = opened_month_key;
     }

   const datetime history_start = reference_time - (long)100 * 86400;
   if(history_start <= 0 || !HistorySelect(history_start, reference_time))
      return false;
   const int magic = QM_FrameworkMagic();
   const int deal_count = HistoryDealsTotal();
   for(int index = deal_count - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0 ||
         (int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != g_symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      const int deal_month_key = Strategy_MonthKeyForTime(deal_time);
      if(deal_time <= 0 || deal_time > reference_time ||
         deal_month_key <= 0 || deal_month_key > current_month_key)
         return false;
      if(deal_month_key > greatest_month_key)
         greatest_month_key = deal_month_key;
     }

   if(greatest_month_key > g_last_attempt_month_key)
      return Strategy_RecordMonthAttempt(greatest_month_key);
   return true;
  }

bool Strategy_BarCloseValid(const MqlRates &bar)
  {
   return (bar.time > 0 &&
           bar.close > 0.0 &&
           MathIsValidNumber(bar.close));
  }

bool Strategy_NormalizedD1Label(const datetime raw_label,
                                const int label_offset,
                                datetime &normalized_label,
                                int &date_key,
                                int &month_key)
  {
   normalized_label = 0;
   date_key = 0;
   month_key = 0;
   if(raw_label <= 0 || (label_offset != 0 && label_offset != 86400))
      return false;

   MqlDateTime raw_parts;
   ZeroMemory(raw_parts);
   if(!TimeToStruct(raw_label, raw_parts) ||
      raw_parts.hour != 0 || raw_parts.min != 0 || raw_parts.sec != 0)
      return false;

   normalized_label = Strategy_NormalizedLabel(raw_label, label_offset);
   MqlDateTime normalized_parts;
   ZeroMemory(normalized_parts);
   if(normalized_label <= 0 ||
      !TimeToStruct(normalized_label, normalized_parts) ||
      normalized_parts.hour != 0 || normalized_parts.min != 0 ||
      normalized_parts.sec != 0 || normalized_parts.day_of_week < 1 ||
      normalized_parts.day_of_week > 5)
      return false;

   date_key = Strategy_DateKeyForTime(normalized_label);
   month_key = Strategy_MonthKeyForTime(normalized_label);
   return (date_key > 0 && month_key > 0);
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
   g_signal_direction = 0;
   g_newest_month_key = 0;
   g_parent_month_key = 0;
   g_newest_month_sessions = 0;
   g_parent_month_sessions = 0;
   g_newest_median = 0.0;
   g_parent_median = 0.0;
   g_median_shift = 0.0;
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
   datetime normalized_current = 0;
   int current_date_key = 0;
   int current_month_key = 0;
   if(!Strategy_NormalizedD1Label(current_bar.time,
                                  label_offset,
                                  normalized_current,
                                  current_date_key,
                                  current_month_key) ||
      normalized_current > broker_now || current_month_key <= 0 ||
      current_month_key != Strategy_MonthKeyForTime(broker_now) ||
      current_date_key != Strategy_DateKeyForTime(broker_now))
      return;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded month-clock scan behind the sole QM_IsNewBar branch.
                PERIOD_D1,
                1,
                strategy_history_bars_d1,
                bars);
   if(copied <= 0)
      return;

   int current_month_count = 0;
   int prior_month_key = 0;
   int last_date_key = current_date_key;
   for(int index = 0; index < copied; ++index)
     {
      datetime normalized_label = 0;
      int date_key = 0;
      int month_key = 0;
      if(!Strategy_BarCloseValid(bars[index]) ||
         (index > 0 && bars[index - 1].time <= bars[index].time) ||
         !Strategy_NormalizedD1Label(bars[index].time,
                                     label_offset,
                                     normalized_label,
                                     date_key,
                                     month_key) ||
         normalized_label >= normalized_current ||
         date_key >= last_date_key)
         return;
      last_date_key = date_key;
      if(month_key == current_month_key)
        {
         ++current_month_count;
         continue;
        }
      prior_month_key = month_key;
      break;
     }
   if(current_month_count >= copied || prior_month_key <= 0)
      return;

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

bool Strategy_OrdinarySampleMedian(double &values[],
                                   const int count,
                                   double &median)
  {
   median = 0.0;
   if(count <= 0 || ArraySize(values) < count ||
      ArrayResize(values, count) != count)
      return false;

   for(int index = 0; index < count; ++index)
      if(!MathIsValidNumber(values[index]))
         return false;

   ArraySort(values);
   for(int index = 1; index < count; ++index)
      if(values[index] < values[index - 1])
         return false;

   const int middle = count / 2;
   if((count % 2) == 1)
      median = values[middle];
   else
      median = 0.5 * (values[middle - 1] + values[middle]);
   return MathIsValidNumber(median);
  }

bool Strategy_LoadMonthlyMedianShiftSignal(
      const int current_month_key,
      const int label_offset,
      int &newest_month_key,
      int &parent_month_key,
      int &newest_month_sessions,
      int &parent_month_sessions,
      double &newest_median,
      double &parent_median,
      double &median_shift,
      int &direction)
  {
   newest_month_key = 0;
   parent_month_key = 0;
   newest_month_sessions = 0;
   parent_month_sessions = 0;
   newest_median = 0.0;
   parent_median = 0.0;
   median_shift = 0.0;
   direction = 0;

   if(current_month_key <= 0 ||
      (label_offset != 0 && label_offset != 86400) ||
      strategy_history_bars_d1 < 70 ||
      strategy_min_month_sessions != 17 ||
      strategy_max_month_sessions != 23 ||
      strategy_min_month_sessions > strategy_max_month_sessions)
      return false;

   MqlRates bars[];
   double newest_log_prices[];
   double parent_log_prices[];
   ArraySetAsSeries(bars, true);
   if(ArrayResize(newest_log_prices,
                  strategy_max_month_sessions) !=
      strategy_max_month_sessions ||
      ArrayResize(parent_log_prices,
                  strategy_max_month_sessions) !=
      strategy_max_month_sessions)
      return false;

   const int copied =
      CopyRates(_Symbol, // perf-allowed: one bounded two-month scan behind a consumed monthly attempt.
                PERIOD_D1,
                1,
                strategy_history_bars_d1,
                bars);
   if(copied != strategy_history_bars_d1 ||
      copied < 2 * strategy_min_month_sessions + 1)
      return false;

   int index = 0;
   int last_date_key = 0;
   const datetime broker_now = TimeCurrent();

   while(index < copied)
     {
      if(index > 0 && bars[index - 1].time <= bars[index].time)
         return false;
      if(!Strategy_BarCloseValid(bars[index]))
         return false;

      datetime normalized_label = 0;
      int date_key = 0;
      int month_key = 0;
      if(!Strategy_NormalizedD1Label(bars[index].time,
                                     label_offset,
                                     normalized_label,
                                     date_key,
                                     month_key) ||
         normalized_label >= broker_now ||
         month_key == current_month_key ||
         (last_date_key > 0 && date_key >= last_date_key))
         return false;

      if(index == 0)
        {
         newest_month_key = month_key;
         if(Strategy_NextMonthKey(newest_month_key) != current_month_key)
            return false;
        }
      if(month_key != newest_month_key)
         break;
      if(newest_month_sessions >= strategy_max_month_sessions ||
         newest_month_sessions >= ArraySize(newest_log_prices))
         return false;

      const double log_price = MathLog(bars[index].close);
      if(!MathIsValidNumber(log_price))
         return false;
      newest_log_prices[newest_month_sessions] = log_price;
      ++newest_month_sessions;
      last_date_key = date_key;
      ++index;
     }

   if(newest_month_sessions < strategy_min_month_sessions ||
      newest_month_sessions > strategy_max_month_sessions ||
      index >= copied)
      return false;

   datetime normalized_parent = 0;
   int parent_date_key = 0;
   int observed_parent_key = 0;
   if(!Strategy_BarCloseValid(bars[index]) ||
      bars[index - 1].time <= bars[index].time ||
      !Strategy_NormalizedD1Label(bars[index].time,
                                  label_offset,
                                  normalized_parent,
                                  parent_date_key,
                                  observed_parent_key) ||
      normalized_parent >= broker_now ||
      parent_date_key >= last_date_key ||
      Strategy_NextMonthKey(observed_parent_key) != newest_month_key)
      return false;
   parent_month_key = observed_parent_key;

   while(index < copied)
     {
      if(index > 0 && bars[index - 1].time <= bars[index].time)
         return false;
      if(!Strategy_BarCloseValid(bars[index]))
         return false;

      datetime normalized_label = 0;
      int date_key = 0;
      int month_key = 0;
      if(!Strategy_NormalizedD1Label(bars[index].time,
                                     label_offset,
                                     normalized_label,
                                     date_key,
                                     month_key) ||
         normalized_label >= broker_now ||
         month_key == current_month_key ||
         date_key >= last_date_key)
         return false;
      if(month_key != parent_month_key)
         break;
      if(parent_month_sessions >= strategy_max_month_sessions ||
         parent_month_sessions >= ArraySize(parent_log_prices))
         return false;

      const double log_price = MathLog(bars[index].close);
      if(!MathIsValidNumber(log_price))
         return false;
      parent_log_prices[parent_month_sessions] = log_price;
      ++parent_month_sessions;
      last_date_key = date_key;
      ++index;
     }

   if(parent_month_sessions < strategy_min_month_sessions ||
      parent_month_sessions > strategy_max_month_sessions ||
      index >= copied)
      return false;

   // The next older normalized label proves that the parent month was not
   // truncated by the bounded history request.
   datetime normalized_older = 0;
   int older_date_key = 0;
   int older_month_key = 0;
   if(!Strategy_BarCloseValid(bars[index]) ||
      bars[index - 1].time <= bars[index].time ||
      !Strategy_NormalizedD1Label(bars[index].time,
                                  label_offset,
                                  normalized_older,
                                  older_date_key,
                                  older_month_key) ||
      normalized_older >= broker_now ||
      older_date_key >= last_date_key ||
      Strategy_NextMonthKey(older_month_key) != parent_month_key)
      return false;

   if(!Strategy_OrdinarySampleMedian(newest_log_prices,
                                     newest_month_sessions,
                                     newest_median) ||
      !Strategy_OrdinarySampleMedian(parent_log_prices,
                                     parent_month_sessions,
                                     parent_median))
      return false;

   median_shift = newest_median - parent_median;
   if(!MathIsValidNumber(median_shift))
      return false;
   if(newest_median > parent_median)
      direction = 1;
   else if(newest_median < parent_median)
      direction = -1;
   return true;
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
   // or order gates. The normalized broker-month clock is the sole prerequisite.
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
      g_signal_valid =
         Strategy_LoadMonthlyMedianShiftSignal(
            g_decision_month_key,
            g_decision_label_offset,
            g_newest_month_key,
            g_parent_month_key,
            g_newest_month_sessions,
            g_parent_month_sessions,
            g_newest_median,
            g_parent_median,
            g_median_shift,
            g_signal_direction);
      if(!g_signal_valid)
         g_signal_state = "monthly_median_shift_validation_failed";
      else if(g_signal_direction == 0)
         g_signal_state = "equal_monthly_medians_flat";
      else if(g_signal_direction > 0)
         g_signal_state = "newest_median_above_parent_long";
      else if(g_signal_direction < 0)
         g_signal_state = "newest_median_below_parent_short";
      else
         g_signal_state = "invalid_direction_flat";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"completed_current_month_bars\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"newest_month\":%d,\"parent_month\":%d,\"newest_month_sessions\":%d,\"parent_month_sessions\":%d,\"newest_median\":%.12e,\"parent_median\":%.12e,\"median_shift\":%.12e,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_current_month_bar_count,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_direction,
                            g_newest_month_key,
                            g_parent_month_key,
                            g_newest_month_sessions,
                            g_parent_month_sessions,
                            g_newest_median,
                            g_parent_median,
                            g_median_shift,
                            g_signal_state));
  }
// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41137 ||
      qm_magic_slot_offset != 0 || qm_rng_seed != 42)
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
   if(strategy_entry_grace_minutes != 180 ||
      strategy_history_bars_d1 != 70 ||
      strategy_min_month_sessions != 17 ||
      strategy_max_month_sessions != 23 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 0.000000000001 ||
      strategy_max_hold_days != 40 ||
      strategy_max_spread_points != 1500 ||
      strategy_deviation_points != 20)
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
   req.reason = "QM5_41137_WTI_MMEDIAN_SHIFT_MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_decision_bar || g_late_decision ||
      g_decision_month_key <= 0 ||
      g_decision_month_key != g_last_attempt_month_key ||
      !g_signal_valid || g_signal_direction == 0)
      return false;
   if(Strategy_OwnedPositionCount() > 0 || !Strategy_SpreadAllowed())
      return false;

   const double atr_value =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.type = (g_signal_direction > 0) ? QM_BUY : QM_SELL;
   req.reason = (g_signal_direction > 0)
      ? "WTI_MMEDIAN_SHIFT_MOM_LONG"
      : "WTI_MMEDIAN_SHIFT_MOM_SHORT";
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
      return;
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
   datetime normalized_current = 0;
   int current_date_key = 0;
   int current_month_key = 0;
   const bool normalized_label_valid =
      Strategy_NormalizedD1Label(current_bar.time,
                                 label_offset,
                                 normalized_current,
                                 current_date_key,
                                 current_month_key);
   const datetime opened = Strategy_CurrentEntryTime();
   const int opened_month_key = Strategy_MonthKeyForTime(opened);
   if(label_offset < 0 || !normalized_label_valid ||
      normalized_current > now || current_date_key <= 0 ||
      current_month_key <= 0 ||
      opened_month_key <= 0 || opened <= 0 || opened > now)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   if(opened_month_key != current_month_key)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;
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
      !Strategy_IsHostChart() || qm_ea_id != 41137 ||
      qm_magic_slot_offset != 0)
      return INIT_PARAMETERS_INCORRECT;

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
         "Approved WTI two-completed-month median-location-shift position holds through Fridays until the next broker month"))
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
      StringFormat("QM5_41137_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());
   if(!Strategy_ReconcileAttemptState(TimeCurrent()))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41137\",\"ea\":\"wti-mmedian-shift-mom\"}");
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
