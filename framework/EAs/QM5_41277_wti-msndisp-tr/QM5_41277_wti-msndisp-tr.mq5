#property strict
#property version   "5.0"
#property description "QM5_41277 WTI Completed-Month Sn-Core Dispersion Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41277 - WTI Completed-Month Sn-Core Dispersion Trend
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - reconstruct the immediately completed broker month (17..23 sessions)
//   - take its final seventeen chronological closes
//   - form sixteen adjacent log returns and verify endpoint identity
//   - for every return, sort its 15 leave-one-out absolute distances
//   - take each raw eighth inner value, then the raw eighth of 16 inner values
//   - omit Sn consistency and finite-sample multipliers by construction
//   - continue only at an inclusive three-core boundary
//   - consume before fallible gates; never enter late or retry
// Runtime uses MT5-native XTIUSD.DWX price, calendar, ATR, and execution state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 41277;
input int    qm_magic_slot_offset           = 0;
input uint   qm_rng_seed                    = 42;

input group "Risk"
input double RISK_PERCENT                   = 0.0;
input double RISK_FIXED                     = 1000.0;
input double PORTFOLIO_WEIGHT               = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours        = 336;
input string qm_news_min_impact             = "high";
input QM_NewsMode qm_news_mode_legacy       = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled        = false;
input int    qm_friday_close_hour_broker    = 21;

input group "Stress"
input double qm_stress_reject_probability   = 0.0;

input group "Strategy"
input int    strategy_month_sessions_min     = 17;
input int    strategy_month_sessions_max     = 23;
input int    strategy_close_count            = 17;
input int    strategy_return_count           = 16;
input int    strategy_inner_distance_count   = 15;
input int    strategy_inner_median_one_based = 8;
input int    strategy_outer_count            = 16;
input int    strategy_outer_lomed_one_based  = 8;
input double strategy_sn_core_floor          = 0.000000000001;
input double strategy_net_core_multiplier    = 3.0;
input double strategy_endpoint_tolerance     = 0.0000000001;
input int    strategy_history_bars_d1        = 120;
input int    strategy_entry_window_minutes   = 180;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input int    strategy_max_hold_days           = 40;
input int    strategy_max_spread_points       = 1500;
input int    strategy_deviation_points        = 20;

const string g_symbol = "XTIUSD.DWX";

struct Strategy_SignalMetrics
  {
   int direction;
   int completed_month_key;
   int session_count;
   int close_count;
   int return_count;
   int directed_distance_count;
   int inner_count;
   int inner_index_zero_based;
   int outer_index_zero_based;
   double net_return;
   double endpoint_return;
   double endpoint_error;
   double sn_core;
   double threshold;
   string close_path;
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
int      g_validation_month_key    = 0;
bool     g_validation_signal_valid = false;
int      g_validation_direction    = 0;
string   g_signal_state            = "idle";
bool     g_support_contract_valid  = false;

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

int Strategy_PreviousMonthKey(const int month_key)
  {
   int year = month_key / 100;
   int month = month_key % 100;
   if(year < 1900 || month < 1 || month > 12)
      return 0;
   --month;
   if(month < 1)
     {
      month = 12;
      --year;
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
   return (elapsed <= (long)strategy_entry_window_minutes * 60L);
  }

bool Strategy_IsOwnedPosition()
  {
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
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
   return (GlobalVariableSet(g_attempt_state_key, (double)month_key) > 0);
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
   g_signal_metrics.close_path = "";
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
                strategy_history_bars_d1,
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

// -----------------------------------------------------------------------------
// Completed-month reconstruction and exact raw Sn-core score.
// -----------------------------------------------------------------------------

bool Strategy_LoadCompletedMonthCloses(const int current_month_key,
                                       const int label_offset,
                                       double &closes[],
                                       int &completed_month_key,
                                       int &session_count)
  {
   ArrayResize(closes, 0);
   completed_month_key = 0;
   session_count = 0;
   if(current_month_key <= 0 ||
      (label_offset != 0 && label_offset != 86400) ||
      strategy_history_bars_d1 != 120)
      return false;

   const int prior_month_key = Strategy_PreviousMonthKey(current_month_key);
   const int older_month_key = Strategy_PreviousMonthKey(prior_month_key);
   if(prior_month_key <= 0 || older_month_key <= 0 ||
      Strategy_NextMonthKey(prior_month_key) != current_month_key ||
      Strategy_NextMonthKey(older_month_key) != prior_month_key)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: one bounded completed-month scan behind a consumed monthly attempt or restart validation.
                PERIOD_D1,
                1,
                strategy_history_bars_d1,
                bars);
   if(copied < strategy_month_sessions_min + 1)
      return false;

   double newest_closes[];
   if(ArrayResize(newest_closes, strategy_month_sessions_max) !=
      strategy_month_sessions_max)
      return false;

   bool prior_started = false;
   bool older_boundary_seen = false;
   int last_session_date_key = 0;
   for(int index = 0; index < copied; ++index)
     {
      if(index > 0 && bars[index - 1].time <= bars[index].time)
         return false;
      const datetime normalized =
         Strategy_NormalizedLabel(bars[index].time, label_offset);
      const int month_key = Strategy_MonthKeyForTime(normalized);
      if(normalized <= 0 || month_key <= 0)
         return false;

      if(month_key == current_month_key && !prior_started)
         continue;
      if(month_key == prior_month_key)
        {
         prior_started = true;
         if(!Strategy_BarCloseValid(bars[index]))
            return false;
         if(session_count < 0 ||
            session_count >= strategy_month_sessions_max ||
            session_count >= ArraySize(newest_closes))
            return false;
         const int date_key = Strategy_DateKeyForTime(normalized);
         if(date_key <= 0 ||
            (last_session_date_key > 0 && date_key >= last_session_date_key))
            return false;
         last_session_date_key = date_key;
         newest_closes[session_count] = bars[index].close;
         ++session_count;
         continue;
        }
      if(prior_started && month_key == older_month_key)
        {
         older_boundary_seen = true;
         break;
        }
      return false;
     }

   if(!prior_started || !older_boundary_seen ||
      session_count < strategy_month_sessions_min ||
      session_count > strategy_month_sessions_max ||
      session_count < strategy_close_count)
      return false;
   if(ArrayResize(closes, strategy_close_count) != strategy_close_count)
      return false;

   // newest_closes[0] is the final session. Reverse only the final seventeen.
   for(int index = 0; index < strategy_close_count; ++index)
     {
      const int reverse_index = strategy_close_count - 1 - index;
      if(reverse_index < 0 ||
         reverse_index >= strategy_month_sessions_max ||
         reverse_index >= session_count ||
         reverse_index >= ArraySize(newest_closes))
         return false;
      closes[index] = newest_closes[reverse_index];
      if(closes[index] <= 0.0 || !MathIsValidNumber(closes[index]))
         return false;
     }
   completed_month_key = prior_month_key;
   return true;
  }

bool Strategy_SnSupportValid()
  {
   int directed_count = 0;
   for(int subject = 0; subject < 16; ++subject)
      for(int peer = 0; peer < 16; ++peer)
         if(peer != subject)
            ++directed_count;

   return (directed_count == 240 &&
           strategy_inner_distance_count == 15 &&
           strategy_inner_median_one_based == 8 &&
           strategy_outer_count == 16 &&
           strategy_outer_lomed_one_based == 8 &&
           strategy_inner_median_one_based - 1 == 7 &&
           strategy_outer_lomed_one_based - 1 == 7);
  }

bool Strategy_SnSignal(const double &closes[],
                       const int completed_month_key,
                       const int session_count,
                       Strategy_SignalMetrics &metrics)
  {
   ZeroMemory(metrics);
   metrics.close_path = "";
   metrics.completed_month_key = completed_month_key;
   metrics.session_count = session_count;
   metrics.close_count = ArraySize(closes);
   metrics.inner_index_zero_based = strategy_inner_median_one_based - 1;
   metrics.outer_index_zero_based = strategy_outer_lomed_one_based - 1;

   if(strategy_close_count != 17 ||
      strategy_return_count != 16 ||
      strategy_inner_distance_count != 15 ||
      strategy_inner_median_one_based != 8 ||
      strategy_outer_count != 16 ||
      strategy_outer_lomed_one_based != 8 ||
      MathAbs(strategy_sn_core_floor - 0.000000000001) >
         0.000000000000000001 ||
      MathAbs(strategy_net_core_multiplier - 3.0) >
         0.000000000001 ||
      MathAbs(strategy_endpoint_tolerance - 0.0000000001) >
         0.00000000000001 ||
      metrics.close_count != 17 ||
      metrics.inner_index_zero_based != 7 ||
      metrics.outer_index_zero_based != 7 ||
      completed_month_key <= 0 ||
      session_count < strategy_month_sessions_min ||
      session_count > strategy_month_sessions_max ||
      !g_support_contract_valid)
      return false;

   for(int index = 0; index < 17; ++index)
     {
      if(index < 0 || index >= metrics.close_count ||
         closes[index] <= 0.0 || !MathIsValidNumber(closes[index]))
         return false;
      if(StringLen(metrics.close_path) > 0)
         metrics.close_path += ",";
      metrics.close_path += DoubleToString(closes[index], _Digits);
     }

   double log_returns[16];
   for(int index = 0; index < 16; ++index)
     {
      if(index < 0 || index + 1 >= metrics.close_count)
         return false;
      const double ratio = closes[index + 1] / closes[index];
      if(ratio <= 0.0 || !MathIsValidNumber(ratio))
         return false;
      const double value = MathLog(ratio);
      if(!MathIsValidNumber(value))
         return false;
      log_returns[index] = value;
      metrics.net_return += value;
      ++metrics.return_count;
     }
   if(metrics.return_count != strategy_return_count)
      return false;

   const double endpoint_ratio = closes[16] / closes[0];
   if(endpoint_ratio <= 0.0 || !MathIsValidNumber(endpoint_ratio))
      return false;
   metrics.endpoint_return = MathLog(endpoint_ratio);
   metrics.endpoint_error =
      MathAbs(metrics.net_return - metrics.endpoint_return);
   if(!MathIsValidNumber(metrics.endpoint_return) ||
      !MathIsValidNumber(metrics.endpoint_error) ||
      metrics.endpoint_error > strategy_endpoint_tolerance)
      return false;

   double inner_medians[16];
   double distances[15];
   for(int subject = 0; subject < 16; ++subject)
     {
      int local_count = 0;
      for(int peer = 0; peer < 16; ++peer)
        {
         if(peer == subject)
            continue;
         if(subject < 0 || subject >= 16 ||
            peer < 0 || peer >= 16 ||
            local_count < 0 || local_count >= 15)
            return false;
         const double distance =
            MathAbs(log_returns[subject] - log_returns[peer]);
         if(distance < 0.0 || !MathIsValidNumber(distance))
            return false;
         distances[local_count] = distance;
         ++local_count;
         ++metrics.directed_distance_count;
        }
      if(local_count != strategy_inner_distance_count)
         return false;

      ArraySort(distances);
      for(int index = 0; index < 15; ++index)
        {
         if(distances[index] < 0.0 ||
            !MathIsValidNumber(distances[index]) ||
            (index > 0 && distances[index] < distances[index - 1]))
            return false;
        }
      inner_medians[subject] = distances[7];
      if(inner_medians[subject] < 0.0 ||
         !MathIsValidNumber(inner_medians[subject]))
         return false;
      ++metrics.inner_count;
     }

   if(metrics.directed_distance_count != 240 ||
      metrics.inner_count != strategy_outer_count)
      return false;

   ArraySort(inner_medians);
   for(int index = 0; index < 16; ++index)
     {
      if(inner_medians[index] < 0.0 ||
         !MathIsValidNumber(inner_medians[index]) ||
         (index > 0 && inner_medians[index] < inner_medians[index - 1]))
         return false;
     }

   // Raw Sn core only: deliberately omit consistency and finite-sample corrections.
   metrics.sn_core = inner_medians[7];
   if(!MathIsValidNumber(metrics.sn_core) ||
      metrics.sn_core <= strategy_sn_core_floor)
      return true;

   metrics.threshold =
      strategy_net_core_multiplier * metrics.sn_core;
   if(metrics.threshold <= 0.0 ||
      !MathIsValidNumber(metrics.threshold))
      return false;

   // The boundary is intentionally inclusive in both directions.
   if(metrics.net_return >= metrics.threshold)
      metrics.direction = 1;
   else if(metrics.net_return <= -metrics.threshold)
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
   int completed_month_key = 0;
   int session_count = 0;
   Strategy_SignalMetrics metrics;
   const bool valid =
      Strategy_LoadCompletedMonthCloses(current_month_key,
                                        label_offset,
                                        closes,
                                        completed_month_key,
                                        session_count) &&
      Strategy_SnSignal(closes,
                             completed_month_key,
                             session_count,
                             metrics);
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
      int completed_month_key = 0;
      int session_count = 0;
      const bool history_valid =
         Strategy_LoadCompletedMonthCloses(g_decision_month_key,
                                           g_decision_label_offset,
                                           closes,
                                           completed_month_key,
                                           session_count);
      g_signal_valid =
         history_valid &&
         Strategy_SnSignal(closes,
                           completed_month_key,
                           session_count,
                           g_signal_metrics);
      if(!g_signal_valid)
         g_signal_state = "sn_validation_failed";
      else if(g_signal_metrics.sn_core <= strategy_sn_core_floor)
         g_signal_state = "sn_core_floor_flat";
      else if(g_signal_metrics.direction > 0)
         g_signal_state = "sn_core_wti_long";
      else if(g_signal_metrics.direction < 0)
         g_signal_state = "sn_core_wti_short";
      else
         g_signal_state = "three_sn_core_boundary_flat";

      g_validation_month_key = g_decision_month_key;
      g_validation_signal_valid = g_signal_valid;
      g_validation_direction = g_signal_metrics.direction;
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"completed_month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"completed_current_month_bars\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"session_count\":%d,\"close_count\":%d,\"return_count\":%d,\"directed_distance_count\":%d,\"inner_count\":%d,\"inner_index_zero_based\":%d,\"outer_index_zero_based\":%d,\"net_return\":%.12f,\"endpoint_return\":%.12f,\"endpoint_error\":%.12f,\"sn_core\":%.12f,\"threshold\":%.12f,\"closes\":\"%s\",\"state\":\"%s\"}",
                            g_decision_month_key,
                            g_signal_metrics.completed_month_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_current_month_bar_count,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_metrics.direction,
                            g_signal_metrics.session_count,
                            g_signal_metrics.close_count,
                            g_signal_metrics.return_count,
                            g_signal_metrics.directed_distance_count,
                            g_signal_metrics.inner_count,
                            g_signal_metrics.inner_index_zero_based,
                            g_signal_metrics.outer_index_zero_based,
                            g_signal_metrics.net_return,
                            g_signal_metrics.endpoint_return,
                            g_signal_metrics.endpoint_error,
                            g_signal_metrics.sn_core,
                            g_signal_metrics.threshold,
                            g_signal_metrics.close_path,
                            g_signal_state));
  }

// -----------------------------------------------------------------------------
// No Trade Filter.// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41277 ||
      qm_magic_slot_offset != 0 || qm_rng_seed != 42 ||
      QM_FrameworkMagic() != 412770000)
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
   if(strategy_month_sessions_min != 17 ||
      strategy_month_sessions_max != 23 ||
      strategy_close_count != 17 ||
      strategy_return_count != 16 ||
      strategy_inner_distance_count != 15 ||
      strategy_inner_median_one_based != 8 ||
      strategy_outer_count != 16 ||
      strategy_outer_lomed_one_based != 8 ||
      MathAbs(strategy_sn_core_floor - 0.000000000001) >
         0.000000000000000001 ||
      MathAbs(strategy_net_core_multiplier - 3.0) >
         0.000000000001 ||
      MathAbs(strategy_endpoint_tolerance - 0.0000000001) >
         0.00000000000001 ||
      !g_support_contract_valid ||
      strategy_history_bars_d1 != 120 ||
      strategy_entry_window_minutes != 180 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 0.000000000001 ||
      strategy_max_hold_days != 40 ||
      strategy_max_spread_points != 1500 ||
      strategy_deviation_points != 20)
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry.// -----------------------------------------------------------------------------
// Trade Entry.
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_41277_WTI_MSNDISP_TR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_decision_bar || g_late_decision ||
      g_decision_month_key <= 0 ||
      g_decision_month_key != g_last_attempt_month_key ||
       !g_signal_valid || g_signal_metrics.direction == 0)
      return false;
   if(Strategy_OwnedPositionCount() > 0 ||
      !Strategy_SpreadAllowed())
      return false;

   const double atr_value =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.type = (g_signal_metrics.direction > 0) ? QM_BUY : QM_SELL;
    req.reason = (g_signal_metrics.direction > 0)
       ? "WTI_MSNDISP_TR_LONG"
       : "WTI_MSNDISP_TR_SHORT";
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
   const datetime normalized_current =
      Strategy_NormalizedLabel(current_bar.time, label_offset);
   const datetime opened = Strategy_CurrentEntryTime();
   const int current_month_key =
      Strategy_MonthKeyForTime(normalized_current);
   const int opened_month_key = Strategy_MonthKeyForTime(opened);
   if(label_offset < 0 || current_month_key <= 0 ||
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
      !Strategy_IsHostChart() || qm_ea_id != 41277 ||
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
         "Approved WTI monthly Sn-core trend holds through Fridays until the next broker month"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   g_support_contract_valid = Strategy_SnSupportValid();
   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41277_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41277\",\"ea\":\"wti-msndisp-tr\"}");
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

