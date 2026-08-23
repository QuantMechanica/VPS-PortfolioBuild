#property strict
#property version   "5.0"
#property description "QM5_41122 WTI Completed-Month Extreme-Sequence Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41122 - WTI Completed-Month Extreme-Sequence Momentum
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - reconstruct the immediately completed broker-calendar month
//   - require 17-23 valid completed sessions and an older-month boundary proof
//   - require one unique aggregate-high session and one unique aggregate-low
//   - BUY only for low-before-high plus positive first-open/last-close body
//   - SELL only for high-before-low plus negative first-open/last-close body
//   - consume the month before fallible gates; never enter late or retry
//   - hold until the first later broker month, with a 40-day stale repair
// Runtime uses MT5-native completed OHLC, calendar, history, and framework state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 41122;
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
input int    strategy_history_bars_d1       = 45;
input int    strategy_min_month_sessions    = 17;
input int    strategy_max_month_sessions    = 23;
input bool   strategy_require_unique_extremes = true;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult            = 3.5;
input int    strategy_max_hold_days         = 40;
input int    strategy_max_spread_points     = 1500;

const string g_symbol = "XTIUSD.DWX";

int      g_last_attempt_month_key = 0;
string   g_attempt_state_key       = "";
bool     g_decision_bar            = false;
bool     g_late_decision           = false;
int      g_decision_month_key      = 0;
datetime g_decision_bar_time       = 0;
int      g_current_month_bar_count = 0;
bool     g_signal_valid            = false;
int      g_signal_direction        = 0;
int      g_completed_month_bars    = 0;
double   g_month_open              = 0.0;
double   g_month_high              = 0.0;
double   g_month_low               = 0.0;
double   g_month_close             = 0.0;
int      g_high_index              = -1;
int      g_low_index               = -1;
int      g_high_occurrences        = 0;
int      g_low_occurrences         = 0;
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

   // Tester globals can outlive a later historical run. Remove malformed or
   // future state so deterministic replay can establish its own ledger.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordMonthAttempt(const int month_key)
  {
   if(month_key <= 0 || g_attempt_state_key == "")
      return false;

   // Stay fail-closed in-process even if terminal persistence itself fails.
   g_last_attempt_month_key = month_key;
   return (GlobalVariableSet(g_attempt_state_key,
                             (double)month_key) > 0);
  }

bool Strategy_BarOHLCValid(const MqlRates &bar)
  {
   if(bar.time <= 0 ||
      bar.open <= 0.0 || bar.high <= 0.0 ||
      bar.low <= 0.0 || bar.close <= 0.0 ||
      !MathIsValidNumber(bar.open) ||
      !MathIsValidNumber(bar.high) ||
      !MathIsValidNumber(bar.low) ||
      !MathIsValidNumber(bar.close))
      return false;
   if(bar.high < bar.open || bar.high < bar.low ||
      bar.high < bar.close || bar.low > bar.open ||
      bar.low > bar.high || bar.low > bar.close)
      return false;
   return true;
  }

void Strategy_ResetDecisionState()
  {
   g_decision_bar = false;
   g_late_decision = false;
   g_decision_month_key = 0;
   g_decision_bar_time = 0;
   g_current_month_bar_count = 0;
   g_signal_valid = false;
   g_signal_direction = 0;
   g_completed_month_bars = 0;
   g_month_open = 0.0;
   g_month_high = 0.0;
   g_month_low = 0.0;
   g_month_close = 0.0;
   g_high_index = -1;
   g_low_index = -1;
   g_high_occurrences = 0;
   g_low_occurrences = 0;
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
   const int current_month_key =
      Strategy_MonthKeyForTime(current_bar.time);
   if(current_month_key <= 0 ||
      current_month_key != Strategy_MonthKeyForTime(broker_now) ||
      Strategy_DateKeyForTime(current_bar.time) !=
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
         Strategy_MonthKeyForTime(bars[current_month_count].time) ==
            current_month_key)
      ++current_month_count;

   if(current_month_count >= copied)
      return;

   const int prior_month_key =
      Strategy_MonthKeyForTime(bars[current_month_count].time);
   if(prior_month_key <= 0 ||
      Strategy_NextMonthKey(prior_month_key) != current_month_key)
      return;

   g_decision_bar = true;
   g_decision_month_key = current_month_key;
   g_decision_bar_time = current_bar.time;
   g_current_month_bar_count = current_month_count;
   g_late_decision =
      (current_month_count > 0 ||
       !Strategy_EntryWithinGrace(current_bar.time, broker_now));
  }

bool Strategy_LoadExtremeSequenceSignal(const int current_month_key,
                                        int &direction,
                                        int &completed_month_bars,
                                        double &month_open,
                                        double &month_high,
                                        double &month_low,
                                        double &month_close,
                                        int &high_index,
                                        int &low_index,
                                        int &high_occurrences,
                                        int &low_occurrences)
  {
   direction = 0;
   completed_month_bars = 0;
   month_open = 0.0;
   month_high = 0.0;
   month_low = 0.0;
   month_close = 0.0;
   high_index = -1;
   low_index = -1;
   high_occurrences = 0;
   low_occurrences = 0;
   if(current_month_key <= 0)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded completed-month extreme-sequence scan behind the sole QM_IsNewBar branch.
                PERIOD_D1,
                1,
                strategy_history_bars_d1,
                bars);
   if(copied < strategy_min_month_sessions + 1)
      return false;

   MqlRates completed[];
   if(ArrayResize(completed,
                  strategy_max_month_sessions) !=
      strategy_max_month_sessions)
      return false;

   int prior_month_key = 0;
   int last_date_key = 0;
   bool older_boundary_seen = false;

   for(int index = 0; index < copied; ++index)
     {
      if(bars[index].time <= 0)
         return false;
      if(index > 0 && bars[index - 1].time <= bars[index].time)
         return false;

      const int month_key = Strategy_MonthKeyForTime(bars[index].time);
      const int date_key = Strategy_DateKeyForTime(bars[index].time);
      if(month_key <= 0 || date_key <= 0 || month_key == current_month_key)
         return false;

      if(prior_month_key == 0)
        {
         if(Strategy_NextMonthKey(month_key) != current_month_key)
            return false;
         prior_month_key = month_key;
        }

      if(month_key != prior_month_key)
        {
         if(Strategy_NextMonthKey(month_key) != prior_month_key)
            return false;
         older_boundary_seen = true;
         break;
        }

      if(last_date_key > 0 && date_key >= last_date_key)
         return false;
      last_date_key = date_key;

      if(completed_month_bars >= strategy_max_month_sessions ||
         !Strategy_BarOHLCValid(bars[index]))
         return false;
      completed[completed_month_bars] = bars[index];
      ++completed_month_bars;
     }

   if(!older_boundary_seen ||
      completed_month_bars < strategy_min_month_sessions ||
      completed_month_bars > strategy_max_month_sessions)
      return false;

   // completed[] is newest-first. Endpoints and chronological indices are
   // therefore taken from reversed array positions.
   month_open = completed[completed_month_bars - 1].open;
   month_close = completed[0].close;
   month_high = completed[0].high;
   month_low = completed[0].low;
   for(int raw_index = 1;
       raw_index < completed_month_bars;
       ++raw_index)
     {
      if(completed[raw_index].high > month_high)
         month_high = completed[raw_index].high;
      if(completed[raw_index].low < month_low)
         month_low = completed[raw_index].low;
     }

   if(month_high <= month_low || month_open < month_low ||
      month_open > month_high || month_close < month_low ||
      month_close > month_high ||
      !MathIsValidNumber(month_open) ||
      !MathIsValidNumber(month_high) ||
      !MathIsValidNumber(month_low) ||
      !MathIsValidNumber(month_close))
      return false;

   for(int chronological_index = 0;
       chronological_index < completed_month_bars;
       ++chronological_index)
     {
      const int raw_index =
         completed_month_bars - 1 - chronological_index;
      if(completed[raw_index].high == month_high)
        {
         ++high_occurrences;
         high_index = chronological_index;
        }
      if(completed[raw_index].low == month_low)
        {
         ++low_occurrences;
         low_index = chronological_index;
        }
     }

   if(strategy_require_unique_extremes &&
      (high_occurrences != 1 || low_occurrences != 1))
      return true;
   if(high_occurrences != 1 || low_occurrences != 1 ||
      high_index < 0 || low_index < 0 || high_index == low_index)
      return true;

   if(low_index < high_index && month_close > month_open)
      direction = 1;
   else if(high_index < low_index && month_close < month_open)
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

   // Consume before history validation, extreme calculation, news, spread,
   // quote, ATR, sizing, or order gates. The broker-month clock is the sole
   // prerequisite.
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
         Strategy_LoadExtremeSequenceSignal(g_decision_month_key,
                                             g_signal_direction,
                                             g_completed_month_bars,
                                             g_month_open,
                                             g_month_high,
                                             g_month_low,
                                             g_month_close,
                                             g_high_index,
                                             g_low_index,
                                             g_high_occurrences,
                                             g_low_occurrences);
      if(!g_signal_valid)
         g_signal_state = "completed_month_validation_failed";
      else if(g_signal_direction > 0)
         g_signal_state = "unique_low_before_high_body_up_long";
      else if(g_signal_direction < 0)
         g_signal_state = "unique_high_before_low_body_down_short";
      else if(g_high_occurrences != 1 || g_low_occurrences != 1)
         g_signal_state = "repeated_extreme_flat";
      else if(g_high_index == g_low_index)
         g_signal_state = "same_session_extremes_flat";
      else if(g_month_close == g_month_open)
         g_signal_state = "month_body_equality_flat";
      else
         g_signal_state = "extreme_order_body_disagreement_flat";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"completed_current_month_bars\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"completed_month_bars\":%d,\"month_open\":%.8f,\"month_high\":%.8f,\"month_low\":%.8f,\"month_close\":%.8f,\"high_index\":%d,\"low_index\":%d,\"high_occurrences\":%d,\"low_occurrences\":%d,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            g_current_month_bar_count,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_direction,
                            g_completed_month_bars,
                            g_month_open,
                            g_month_high,
                            g_month_low,
                            g_month_close,
                            g_high_index,
                            g_low_index,
                            g_high_occurrences,
                            g_low_occurrences,
                            g_signal_state));
  }

// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41122 ||
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
      MathAbs(qm_stress_reject_probability) > 1.0e-12)
      return true;
   if(strategy_entry_grace_minutes != 180 ||
      strategy_history_bars_d1 != 45 ||
      strategy_min_month_sessions != 17 ||
      strategy_max_month_sessions != 23 ||
      !strategy_require_unique_extremes ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 40 ||
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
   req.reason = "QM5_41122_WTI_MEXTREME_SEQUENCE_MOM";
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
      ? "WTI_MEXTREME_SEQUENCE_MOM_LONG"
      : "WTI_MEXTREME_SEQUENCE_MOM_SHORT";

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
   const datetime opened = Strategy_CurrentEntryTime();
   const int current_month_key =
      Strategy_MonthKeyForTime(current_bar.time);
   const int broker_month_key = Strategy_MonthKeyForTime(now);
   const int opened_month_key = Strategy_MonthKeyForTime(opened);
   if(current_month_key <= 0 || broker_month_key <= 0 ||
      current_month_key != broker_month_key ||
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
// Trade Close.
// -----------------------------------------------------------------------------

bool Strategy_ExitSignal()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook.
// -----------------------------------------------------------------------------

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
      !Strategy_IsHostChart() || qm_ea_id != 41122 ||
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

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41122_MONTH_ATTEMPT_%d_XTI_D1",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41122\",\"ea\":\"wti-mextreme-sequence-mom\"}");
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

   // Consume the framework bar edge exactly once. Bounded history scans are
   // reachable only from this closed-D1 branch.
   const bool new_bar = QM_IsNewBar();
   g_decision_bar = false;
   if(new_bar)
      Strategy_DetectDecisionClock_OnNewBar();

   // Lifecycle repair and exact next-month closure precede entry-only gates
   // and run every tick, so a failed close is retried until flat.
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
