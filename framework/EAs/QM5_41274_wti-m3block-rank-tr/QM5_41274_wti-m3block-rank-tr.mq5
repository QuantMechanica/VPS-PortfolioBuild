#property strict
#property version   "5.0"
#property description "QM5_41274 WTI Completed-Month Three-Block Ordinal Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41274 - WTI Completed-Month Three-Block Ordinal Trend
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - reconstruct the immediately completed broker month (17..23 sessions)
//   - take its final fifteen chronological closes in fixed 5/5/5 blocks
//   - reject any close pair tied within half a symbol point
//   - count all 75 earlier-block/later-block ordinal comparisons
//   - continue long above the strict midpoint and short below it
//   - consume before fallible gates; never enter late or retry
// Runtime uses MT5-native XTIUSD.DWX price, calendar, ATR, and execution state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 41274;
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
input int    strategy_month_sessions_min    = 17;
input int    strategy_month_sessions_max    = 23;
input int    strategy_close_count           = 15;
input int    strategy_block_size            = 5;
input int    strategy_comparison_count      = 75;
input int    strategy_center_doubled        = 75;
input double strategy_tie_points            = 0.5;
input int    strategy_history_bars_d1       = 120;
input int    strategy_entry_window_minutes  = 180;
input int    strategy_atr_period_d1          = 20;
input double strategy_atr_sl_mult            = 3.5;
input int    strategy_max_hold_days          = 40;
input int    strategy_max_spread_points      = 1500;
input int    strategy_deviation_points       = 20;

const string g_symbol = "XTIUSD.DWX";

struct Strategy_SignalMetrics
  {
   int direction;
   int completed_month_key;
   int session_count;
   int close_count;
   int comparison_count;
   int win_count;
   bool close_tie;
   string close_path;
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
// Completed-month reconstruction and exact ordinal score.
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
         if(!Strategy_BarCloseValid(bars[index]) ||
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

   // newest_closes[0] is the final session. Reverse only the final fifteen.
   for(int index = 0; index < strategy_close_count; ++index)
     {
      const int reverse_index = strategy_close_count - 1 - index;
      if(reverse_index < 0 || reverse_index >= session_count)
         return false;
      closes[index] = newest_closes[reverse_index];
      if(closes[index] <= 0.0 || !MathIsValidNumber(closes[index]))
         return false;
     }
   completed_month_key = prior_month_key;
   return true;
  }

bool Strategy_OrdinalSupportValid()
  {
   int loop_comparisons = 0;
   for(int earlier_block = 0; earlier_block < 2; ++earlier_block)
      for(int later_block = earlier_block + 1; later_block < 3; ++later_block)
         for(int earlier_index = 0; earlier_index < 5; ++earlier_index)
            for(int later_index = 0; later_index < 5; ++later_index)
               ++loop_comparisons;

   int long_states = 0;
   int short_states = 0;
   int flat_states = 0;
   for(int wins = 0; wins <= 75; ++wins)
     {
      if(2 * wins > 75)
         ++long_states;
      else if(2 * wins < 75)
         ++short_states;
      else
         ++flat_states;
     }
   return (loop_comparisons == 75 &&
           long_states == 38 && short_states == 38 && flat_states == 0);
  }

bool Strategy_OrdinalSignal(const double &closes[],
                            const int completed_month_key,
                            const int session_count,
                            Strategy_SignalMetrics &metrics)
  {
   ZeroMemory(metrics);
   metrics.close_path = "";
   metrics.completed_month_key = completed_month_key;
   metrics.session_count = session_count;
   metrics.close_count = ArraySize(closes);
   if(strategy_close_count != 15 || strategy_block_size != 5 ||
      strategy_comparison_count != 75 || strategy_center_doubled != 75 ||
      MathAbs(strategy_tie_points - 0.5) > 0.000000000001 ||
      metrics.close_count != strategy_close_count ||
      completed_month_key <= 0 ||
      session_count < strategy_month_sessions_min ||
      session_count > strategy_month_sessions_max ||
      !g_support_contract_valid)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || !MathIsValidNumber(point))
      return false;
   const double tie_distance = strategy_tie_points * point;
   if(tie_distance <= 0.0 || !MathIsValidNumber(tie_distance))
      return false;

   for(int index = 0; index < metrics.close_count; ++index)
     {
      if(closes[index] <= 0.0 || !MathIsValidNumber(closes[index]))
         return false;
      if(StringLen(metrics.close_path) > 0)
         metrics.close_path += ",";
      metrics.close_path += DoubleToString(closes[index], _Digits);
     }
   metrics.oldest_close = closes[0];
   metrics.newest_close = closes[metrics.close_count - 1];

   for(int left = 0; left < metrics.close_count - 1; ++left)
      for(int right = left + 1; right < metrics.close_count; ++right)
        {
         if(MathAbs(closes[left] - closes[right]) <= tie_distance)
           {
            metrics.close_tie = true;
            return true;
           }
        }

   for(int earlier_block = 0; earlier_block < 2; ++earlier_block)
     {
      for(int later_block = earlier_block + 1; later_block < 3; ++later_block)
        {
         for(int earlier_index = 0;
             earlier_index < strategy_block_size;
             ++earlier_index)
           {
            const int x = earlier_block * strategy_block_size + earlier_index;
            for(int later_index = 0;
                later_index < strategy_block_size;
                ++later_index)
              {
               const int y = later_block * strategy_block_size + later_index;
               if(x < 0 || y < 0 ||
                  x >= metrics.close_count || y >= metrics.close_count)
                  return false;
               ++metrics.comparison_count;
               if(closes[y] > closes[x])
                  ++metrics.win_count;
              }
           }
        }
     }

   if(metrics.comparison_count != strategy_comparison_count ||
      metrics.win_count < 0 ||
      metrics.win_count > metrics.comparison_count)
      return false;
   if(2 * metrics.win_count > strategy_center_doubled)
      metrics.direction = 1;
   else if(2 * metrics.win_count < strategy_center_doubled)
      metrics.direction = -1;
   else
      return false;
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
      Strategy_OrdinalSignal(closes,
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
         Strategy_OrdinalSignal(closes,
                                completed_month_key,
                                session_count,
                                g_signal_metrics);
      if(!g_signal_valid)
         g_signal_state = "ordinal_validation_failed";
      else if(g_signal_metrics.close_tie)
         g_signal_state = "ordinal_close_tie_flat";
      else if(g_signal_metrics.direction > 0)
         g_signal_state = "ordinal_wti_long";
      else if(g_signal_metrics.direction < 0)
         g_signal_state = "ordinal_wti_short";
      else
         g_signal_state = "invalid_direction_flat";

      g_validation_month_key = g_decision_month_key;
      g_validation_signal_valid = g_signal_valid;
      g_validation_direction = g_signal_metrics.direction;
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"completed_month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"completed_current_month_bars\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"session_count\":%d,\"close_count\":%d,\"comparison_count\":%d,\"win_count\":%d,\"close_tie\":%s,\"closes\":\"%s\",\"oldest_close\":%.10f,\"newest_close\":%.10f,\"state\":\"%s\"}",
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
                            g_signal_metrics.comparison_count,
                            g_signal_metrics.win_count,
                            g_signal_metrics.close_tie ? "true" : "false",
                            g_signal_metrics.close_path,
                            g_signal_metrics.oldest_close,
                            g_signal_metrics.newest_close,
                            g_signal_state));
  }

// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41274 ||
      qm_magic_slot_offset != 0 || qm_rng_seed != 42 ||
      QM_FrameworkMagic() != 412740000)
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
      strategy_close_count != 15 ||
      strategy_block_size != 5 ||
      strategy_comparison_count != 75 ||
      strategy_center_doubled != 75 ||
      MathAbs(strategy_tie_points - 0.5) > 0.000000000001 ||
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
// Trade Entry.
// -----------------------------------------------------------------------------

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_41274_WTI_M3BLOCK_RANK_TR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_decision_bar || g_late_decision ||
      g_decision_month_key <= 0 ||
      g_decision_month_key != g_last_attempt_month_key ||
      !g_signal_valid || g_signal_metrics.close_tie ||
      g_signal_metrics.direction == 0)
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
      ? "WTI_M3BLOCK_RANK_TR_LONG"
      : "WTI_M3BLOCK_RANK_TR_SHORT";
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
      !Strategy_IsHostChart() || qm_ea_id != 41274 ||
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
         "Approved WTI monthly ordinal trend holds through Fridays until the next broker month"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   g_support_contract_valid = Strategy_OrdinalSupportValid();
   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41274_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41274\",\"ea\":\"wti-m3block-rank-tr\"}");
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
