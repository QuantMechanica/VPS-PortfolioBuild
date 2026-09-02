#property strict
#property version   "5.0"
#property description "QM5_41316 WTI Monthly BDS2 Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41316 - WTI Monthly BDS2 Nonlinear-Dependence-Gated Trend
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - reconstruct forty-nine consecutive completed broker-month-end closes
//   - form forty-eight adjacent monthly log returns
//   - compute the statsmodels-aligned embedding-dimension-two BDS statistic
//   - qualify when absolute BDS2 reaches the locked normal-median divider
//   - follow twelve-month WTI momentum only when the path qualifies
//   - consume before fallible gates; never enter late or retry
// Runtime uses MT5-native XTIUSD.DWX price, calendar, ATR, and execution state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 41316;
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
input int    strategy_month_returns        = 48;
input int    strategy_embedding_dim        = 2;
input double strategy_distance_multiplier  = 1.5;
input double strategy_sample_variance_floor = 0.000000000000000001;
input double strategy_epsilon_floor        = 0.000000000001;
input double strategy_bds_variance_floor   = 0.000000000000000001;
input double strategy_abs_bds_boundary     = 0.6744897501960817;
input int    strategy_momentum_months       = 12;
input double strategy_direction_epsilon    = 0.000000000001;
input int    strategy_history_bars         = 1500;
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
   int return_count;
   bool bds_qualified;
   double return_mean;
   double sample_variance;
   double sample_sd;
   double epsilon;
   double c1_full;
   double k_full;
   double c1_truncated;
   double c2_joint;
   double bds_variance;
   double bds2;
   double momentum_12;
   string return_path;
   string correlation_path;
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
   const int endpoint_target = strategy_month_returns + 1;
   if(current_month_key <= 0 ||
      strategy_month_returns != 48 || endpoint_target != 49 ||
      strategy_history_bars != 1500 ||
      strategy_endpoint_stale_days != 10 ||
      (label_offset != 0 && label_offset != 86400))
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: one bounded forty-nine-month scan behind a consumed monthly attempt or monthly restart validation.
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

   if(endpoint_count != endpoint_target || endpoint_count != 49)
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

bool Strategy_BDS2Core(const double &values[],
                       double &return_mean,
                       double &sample_variance,
                       double &sample_sd,
                       double &epsilon,
                       double &c1_full,
                       double &k_full,
                       double &c1_truncated,
                       double &c2_joint,
                       double &bds_variance,
                       double &bds2,
                       string &correlation_path)
  {
   return_mean = 0.0;
   sample_variance = 0.0;
   sample_sd = 0.0;
   epsilon = 0.0;
   c1_full = 0.0;
   k_full = 0.0;
   c1_truncated = 0.0;
   c2_joint = 0.0;
   bds_variance = 0.0;
   bds2 = 0.0;
   correlation_path = "";

   const int value_count = ArraySize(values);
   if(value_count != 48 || strategy_month_returns != 48 ||
      strategy_embedding_dim != 2 ||
      MathAbs(strategy_distance_multiplier - 1.5) >
         0.000000000000001 ||
      strategy_sample_variance_floor != 0.000000000000000001 ||
      strategy_epsilon_floor != 0.000000000001 ||
      strategy_bds_variance_floor != 0.000000000000000001)
      return false;

   for(int index = 0; index < value_count; ++index)
     {
      if(!MathIsValidNumber(values[index]))
         return false;
      return_mean += values[index];
      if(!MathIsValidNumber(return_mean))
         return false;
     }
   return_mean /= (double)value_count;
   if(!MathIsValidNumber(return_mean))
      return false;

   double variance_numerator = 0.0;
   for(int index = 0; index < value_count; ++index)
     {
      const double centered = values[index] - return_mean;
      const double square = centered * centered;
      if(!MathIsValidNumber(centered) ||
         !MathIsValidNumber(square) || square < 0.0)
         return false;
      variance_numerator += square;
      if(!MathIsValidNumber(variance_numerator))
         return false;
     }
   sample_variance = variance_numerator / (double)(value_count - 1);
   if(!MathIsValidNumber(sample_variance) ||
      sample_variance <= strategy_sample_variance_floor)
      return false;
   sample_sd = MathSqrt(sample_variance);
   epsilon = strategy_distance_multiplier * sample_sd;
   if(!MathIsValidNumber(sample_sd) || sample_sd <= 0.0 ||
      !MathIsValidNumber(epsilon) ||
      epsilon <= strategy_epsilon_floor)
      return false;

   int indicators[48][48];
   int row_sums[48];
   int total_indicator_sum = 0;
   int full_pair_hits = 0;
   for(int left = 0; left < value_count; ++left)
     {
      row_sums[left] = 0;
      for(int right = 0; right < value_count; ++right)
        {
         const double distance = MathAbs(values[left] - values[right]);
         if(!MathIsValidNumber(distance))
            return false;
         // statsmodels uses a strict distance test; equality is not close.
         indicators[left][right] = (distance < epsilon) ? 1 : 0;
         row_sums[left] += indicators[left][right];
         total_indicator_sum += indicators[left][right];
         if(left < right)
            full_pair_hits += indicators[left][right];
        }
      if(indicators[left][left] != 1)
         return false;
     }

   const double full_pair_count =
      (double)value_count * (double)(value_count - 1) / 2.0;
   if(full_pair_count != 1128.0)
      return false;
   c1_full = (double)full_pair_hits / full_pair_count;

   double row_square_sum = 0.0;
   for(int index = 0; index < value_count; ++index)
      row_square_sum += (double)row_sums[index] *
                        (double)row_sums[index];
   const double k_denominator =
      (double)value_count * (double)(value_count - 1) *
      (double)(value_count - 2);
   if(k_denominator != 103776.0)
      return false;
   k_full = (row_square_sum -
             3.0 * (double)total_indicator_sum +
             2.0 * (double)value_count) / k_denominator;

   const int conditioned_count = value_count - 1;
   const double conditioned_pair_count =
      (double)conditioned_count * (double)(conditioned_count - 1) / 2.0;
   if(conditioned_count != 47 || conditioned_pair_count != 1081.0)
      return false;
   int truncated_pair_hits = 0;
   for(int left = 1; left < value_count; ++left)
      for(int right = left + 1; right < value_count; ++right)
         truncated_pair_hits += indicators[left][right];
   c1_truncated =
      (double)truncated_pair_hits / conditioned_pair_count;

   int joint_pair_hits = 0;
   for(int left = 0; left < conditioned_count; ++left)
      for(int right = left + 1; right < conditioned_count; ++right)
         joint_pair_hits +=
            indicators[left][right] * indicators[left + 1][right + 1];
   c2_joint = (double)joint_pair_hits / conditioned_pair_count;

   if(!MathIsValidNumber(c1_full) || c1_full < 0.0 || c1_full > 1.0 ||
      !MathIsValidNumber(k_full) || k_full < 0.0 || k_full > 1.0 ||
      !MathIsValidNumber(c1_truncated) ||
      c1_truncated < 0.0 || c1_truncated > 1.0 ||
      !MathIsValidNumber(c2_joint) || c2_joint < 0.0 || c2_joint > 1.0)
      return false;

   const double variance_effect = k_full - c1_full * c1_full;
   bds_variance = 4.0 * variance_effect * variance_effect;
   if(!MathIsValidNumber(bds_variance) ||
      bds_variance <= strategy_bds_variance_floor)
      return false;
   const double conditioned_effect =
      c2_joint - c1_truncated * c1_truncated;
   bds2 = MathSqrt((double)conditioned_count) * conditioned_effect /
          MathSqrt(bds_variance);
   if(!MathIsValidNumber(conditioned_effect) ||
      !MathIsValidNumber(bds2))
      return false;

   correlation_path =
      StringFormat("C1=%.16f,k=%.16f,C1T=%.16f,C2=%.16f",
                   c1_full,
                   k_full,
                   c1_truncated,
                   c2_joint);
   return (StringLen(correlation_path) > 0);
  }

bool Strategy_BDS2ReferenceSelfTest()
  {
   double reference_path[48];
   double affine_path[48];
   double constant_path[48];
   for(int index = 0; index < 48; ++index)
     {
      reference_path[index] =
         0.012 * MathSin(0.41 * (double)index) +
         0.006 * MathCos(0.17 * (double)index) +
         0.003 * (double)((index % 5) - 2) +
         0.00015 * (double)index;
      affine_path[index] = 3.0 + 7.0 * reference_path[index];
      constant_path[index] = 0.01;
     }

   double return_mean = 0.0;
   double sample_variance = 0.0;
   double sample_sd = 0.0;
   double epsilon = 0.0;
   double c1_full = 0.0;
   double k_full = 0.0;
   double c1_truncated = 0.0;
   double c2_joint = 0.0;
   double bds_variance = 0.0;
   double bds2 = 0.0;
   string correlation_path = "";
   if(!Strategy_BDS2Core(reference_path,
                         return_mean,
                         sample_variance,
                         sample_sd,
                         epsilon,
                         c1_full,
                         k_full,
                         c1_truncated,
                         c2_joint,
                         bds_variance,
                         bds2,
                         correlation_path) ||
      MathAbs(return_mean - 0.004221652227540728) > 0.000000000001 ||
      MathAbs(sample_variance - 0.000114021181450521) >
         0.000000000001 ||
      MathAbs(epsilon - 0.016017105177393062) > 0.000000000001 ||
      MathAbs(c1_full - 0.6870567375886525) > 0.000000000001 ||
      MathAbs(k_full - 0.4957600986740672) > 0.000000000001 ||
      MathAbs(c1_truncated - 0.6808510638297872) >
         0.000000000001 ||
      MathAbs(c2_joint - 0.5504162812210915) > 0.000000000001 ||
      MathAbs(bds_variance - 0.002249251656765691) >
         0.000000000001 ||
      MathAbs(bds2 - 12.555681198874424) > 0.000000001 ||
      StringLen(correlation_path) <= 0)
      return false;

   double affine_mean = 0.0;
   double affine_variance = 0.0;
   double affine_sd = 0.0;
   double affine_epsilon = 0.0;
   double affine_c1 = 0.0;
   double affine_k = 0.0;
   double affine_c1_truncated = 0.0;
   double affine_c2 = 0.0;
   double affine_bds_variance = 0.0;
   double affine_bds2 = 0.0;
   string affine_path_text = "";
   if(!Strategy_BDS2Core(affine_path,
                         affine_mean,
                         affine_variance,
                         affine_sd,
                         affine_epsilon,
                         affine_c1,
                         affine_k,
                         affine_c1_truncated,
                         affine_c2,
                         affine_bds_variance,
                         affine_bds2,
                         affine_path_text) ||
      MathAbs(affine_c1 - c1_full) > 0.000000000001 ||
      MathAbs(affine_k - k_full) > 0.000000000001 ||
      MathAbs(affine_c1_truncated - c1_truncated) >
         0.000000000001 ||
      MathAbs(affine_c2 - c2_joint) > 0.000000000001 ||
      MathAbs(affine_bds2 - bds2) > 0.000000001)
      return false;

   if(Strategy_BDS2Core(constant_path,
                        return_mean,
                        sample_variance,
                        sample_sd,
                        epsilon,
                        c1_full,
                        k_full,
                        c1_truncated,
                        c2_joint,
                        bds_variance,
                        bds2,
                        correlation_path))
      return false;
   return true;
  }

bool Strategy_BDS2Signal(const double &closes[],
                         Strategy_SignalMetrics &metrics)
  {
   ZeroMemory(metrics);
   metrics.return_path = "";
   metrics.correlation_path = "";
   metrics.endpoint_count = ArraySize(closes);
   metrics.return_count = strategy_month_returns;
   metrics.direction = 0;
   metrics.bds_qualified = false;

   if(strategy_month_returns != 48 ||
      strategy_embedding_dim != 2 ||
      MathAbs(strategy_distance_multiplier - 1.5) >
         0.000000000000001 ||
      strategy_sample_variance_floor != 0.000000000000000001 ||
      strategy_epsilon_floor != 0.000000000001 ||
      strategy_bds_variance_floor != 0.000000000000000001 ||
      MathAbs(strategy_abs_bds_boundary - 0.6744897501960817) >
         0.000000000000001 ||
      strategy_momentum_months != 12 ||
      MathAbs(strategy_direction_epsilon - 0.000000000001) >
         0.000000000000000001 ||
      metrics.endpoint_count != strategy_month_returns + 1)
      return false;

   for(int index = 0; index < metrics.endpoint_count; ++index)
     {
      if(closes[index] <= 0.0 || !MathIsValidNumber(closes[index]))
         return false;
     }

   double returns[48];
   for(int index = 0; index < strategy_month_returns; ++index)
     {
      if(index < 0 || index + 1 >= metrics.endpoint_count || index >= 48)
         return false;
      const double ratio = closes[index + 1] / closes[index];
      if(ratio <= 0.0 || !MathIsValidNumber(ratio))
         return false;
      returns[index] = MathLog(ratio);
      if(!MathIsValidNumber(returns[index]))
         return false;
      if(StringLen(metrics.return_path) > 0)
         metrics.return_path += ",";
      metrics.return_path += DoubleToString(returns[index], 12);
     }
   if(StringLen(metrics.return_path) <= 0)
      return false;

   if(!Strategy_BDS2Core(returns,
                         metrics.return_mean,
                         metrics.sample_variance,
                         metrics.sample_sd,
                         metrics.epsilon,
                         metrics.c1_full,
                         metrics.k_full,
                         metrics.c1_truncated,
                         metrics.c2_joint,
                         metrics.bds_variance,
                         metrics.bds2,
                         metrics.correlation_path))
      return false;
   metrics.bds_qualified =
      (MathAbs(metrics.bds2) >= strategy_abs_bds_boundary);

   metrics.momentum_12 = 0.0;
   const int momentum_start =
      strategy_month_returns - strategy_momentum_months;
   if(momentum_start != 36)
      return false;
   for(int index = momentum_start;
       index < strategy_month_returns;
       ++index)
     {
      if(index < 0 || index >= 48)
         return false;
      metrics.momentum_12 += returns[index];
     }
   metrics.oldest_close = closes[0];
   metrics.newest_close = closes[metrics.endpoint_count - 1];
   if(!MathIsValidNumber(metrics.momentum_12) ||
      metrics.oldest_close <= 0.0 || metrics.newest_close <= 0.0)
      return false;

   if(!metrics.bds_qualified)
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
      Strategy_BDS2Signal(closes, metrics);

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
            g_signal_metrics.endpoint_count == strategy_month_returns + 1)
           {
            g_oldest_endpoint_time = endpoint_times[0];
            g_newest_endpoint_time =
               endpoint_times[g_signal_metrics.endpoint_count - 1];
           }
        }

      g_signal_valid =
         endpoints_valid &&
         Strategy_BDS2Signal(closes, g_signal_metrics);
      if(!g_signal_valid)
         g_signal_state = "bds2_validation_failed";
      else if(!g_signal_metrics.bds_qualified)
         g_signal_state = "abs_bds2_below_boundary_consumed_flat";
      else if(g_signal_metrics.direction == 0)
         g_signal_state = "qualified_neutral_momentum_consumed_flat";
      else if(g_signal_metrics.direction > 0)
         g_signal_state = "bds2_qualified_positive_momentum_wti_long";
      else if(g_signal_metrics.direction < 0)
         g_signal_state = "bds2_qualified_negative_momentum_wti_short";
      else
         g_signal_state = "invalid_direction_flat";

      g_validation_month_key = g_decision_month_key;
      g_validation_signal_valid = g_signal_valid;
      g_validation_direction = g_signal_metrics.direction;
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"completed_current_month_bars\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"endpoint_count\":%d,\"return_count\":%d,\"return_mean\":%.12f,\"sample_variance\":%.16f,\"sample_sd\":%.16f,\"epsilon\":%.16f,\"c1_full\":%.16f,\"k_full\":%.16f,\"c1_truncated\":%.16f,\"c2_joint\":%.16f,\"bds_variance\":%.16f,\"bds2\":%.12f,\"bds_qualified\":%s,\"momentum_12\":%.12f,\"returns\":\"%s\",\"correlations\":\"%s\",\"oldest_close\":%.10f,\"newest_close\":%.10f,\"oldest_endpoint\":%I64d,\"newest_endpoint\":%I64d,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_current_month_bar_count,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_metrics.direction,
                            g_signal_metrics.endpoint_count,
                            g_signal_metrics.return_count,
                            g_signal_metrics.return_mean,
                            g_signal_metrics.sample_variance,
                            g_signal_metrics.sample_sd,
                            g_signal_metrics.epsilon,
                            g_signal_metrics.c1_full,
                            g_signal_metrics.k_full,
                            g_signal_metrics.c1_truncated,
                            g_signal_metrics.c2_joint,
                            g_signal_metrics.bds_variance,
                            g_signal_metrics.bds2,
                            g_signal_metrics.bds_qualified ? "true" : "false",
                            g_signal_metrics.momentum_12,
                            g_signal_metrics.return_path,
                            g_signal_metrics.correlation_path,
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
   if(!Strategy_IsHostChart() || qm_ea_id != 41316 ||
      qm_magic_slot_offset != 0 ||
      QM_FrameworkMagic() != 413160000 ||
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
   if(strategy_month_returns != 48 ||
      strategy_embedding_dim != 2 ||
      MathAbs(strategy_distance_multiplier - 1.5) >
         0.000000000000001 ||
      strategy_sample_variance_floor != 0.000000000000000001 ||
      strategy_epsilon_floor != 0.000000000001 ||
      strategy_bds_variance_floor != 0.000000000000000001 ||
      MathAbs(strategy_abs_bds_boundary - 0.6744897501960817) >
         0.000000000000001 ||
      strategy_momentum_months != 12 ||
      MathAbs(strategy_direction_epsilon -
              0.000000000001) >
         0.000000000000000001 ||
      strategy_history_bars != 1500 ||
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
   req.reason = "QM5_41316_WTI_BDS2";
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
      ? "WTI_BDS2_MOM_LONG"
      : "WTI_BDS2_MOM_SHORT";
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
      !Strategy_IsHostChart() || qm_ea_id != 41316 ||
      qm_magic_slot_offset != 0)
      return INIT_PARAMETERS_INCORRECT;
   if(!Strategy_BDS2ReferenceSelfTest())
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
         "Approved WTI monthly BDS2 trend holds through Fridays until the next broker month"))
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
      StringFormat("QM5_41316_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   g_entry_month_state_key =
      StringFormat("QM5_41316_ENTRY_MONTH_%d", QM_FrameworkMagic());
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
               "{\"card\":\"QM5_41316\",\"ea\":\"wti-bds2-tr\"}");
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
