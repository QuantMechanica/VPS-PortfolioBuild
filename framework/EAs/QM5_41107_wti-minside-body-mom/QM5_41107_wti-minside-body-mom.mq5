#property strict
#property version   "5.0"
#property description "QM5_41107 WTI Completed-Month Inside-Body Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41107 - WTI Completed-Month Inside-Body Momentum
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - aggregate two consecutive completed broker-calendar months
//   - require the newest full range strictly inside its parent range
//   - follow the contained month's own open-to-close body direction
//   - consume the month before fallible gates; never enter late or retry
//   - follow the completed inside-month body for one broker month
// Runtime uses MT5-native OHLC, calendar, history, and framework state only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 41107;
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
input int    strategy_history_bars_d1       = 70;
input int    strategy_min_month_sessions    = 17;
input int    strategy_max_month_sessions    = 23;
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
int      g_decision_label_offset   = 0;
int      g_current_month_bar_count = 0;
bool     g_signal_valid            = false;
int      g_signal_direction        = 0;
int      g_new_month_bars          = 0;
int      g_parent_month_bars       = 0;
double   g_new_high                = 0.0;
double   g_new_low                 = 0.0;
double   g_new_open                = 0.0;
double   g_new_close               = 0.0;
double   g_parent_high             = 0.0;
double   g_parent_low              = 0.0;
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
   const long session_elapsed = elapsed % 86400L;
   return (session_elapsed <=
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
      bar.open <= 0.0 || !MathIsValidNumber(bar.open) ||
      bar.high <= 0.0 || !MathIsValidNumber(bar.high) ||
      bar.low <= 0.0 || !MathIsValidNumber(bar.low) ||
      bar.close <= 0.0 || !MathIsValidNumber(bar.close))
      return false;
   if(bar.high < bar.low ||
      bar.high < MathMax(bar.open, bar.close) ||
      bar.low > MathMin(bar.open, bar.close))
      return false;
   return true;
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
   g_new_month_bars = 0;
   g_parent_month_bars = 0;
   g_new_high = 0.0;
   g_new_low = 0.0;
   g_new_open = 0.0;
   g_new_close = 0.0;
   g_parent_high = 0.0;
   g_parent_low = 0.0;
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

bool Strategy_LoadInsideBodySignal(const int current_month_key,
                                   const int label_offset,
                                   int &direction,
                                   int &new_month_bars,
                                   int &parent_month_bars,
                                   double &new_high,
                                   double &new_low,
                                   double &new_open,
                                   double &new_close,
                                   double &parent_high,
                                   double &parent_low)
  {
   direction = 0;
   new_month_bars = 0;
   parent_month_bars = 0;
   new_high = 0.0;
   new_low = 0.0;
   new_open = 0.0;
   new_close = 0.0;
   parent_high = 0.0;
   parent_low = 0.0;
   if(current_month_key <= 0 ||
      (label_offset != 0 && label_offset != 86400))
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded completed-month OHLC scan behind the sole QM_IsNewBar branch.
                PERIOD_D1,
                1,
                strategy_history_bars_d1,
                bars);
   if(copied < strategy_min_month_sessions * 2 + 1)
      return false;

   int month_keys[2] = {0, 0};
   int month_counts[2] = {0, 0};
   double month_highs[2] = {0.0, 0.0};
   double month_lows[2] = {0.0, 0.0};
   double month_opens[2] = {0.0, 0.0};
   double month_closes[2] = {0.0, 0.0};
   int month_last_date_keys[2] = {0, 0};
   int found_months = 0;
   bool parent_boundary_seen = false;

   for(int index = 0; index < copied; ++index)
     {
      if(bars[index].time <= 0)
         return false;
      if(index > 0 && bars[index - 1].time <= bars[index].time)
         return false;

      const datetime normalized =
         Strategy_NormalizedLabel(bars[index].time, label_offset);
      const int month_key = Strategy_MonthKeyForTime(normalized);
      if(month_key <= 0 || month_key == current_month_key)
         return false;

      if(found_months == 0 ||
         month_key != month_keys[found_months - 1])
        {
         if(found_months >= 2)
           {
            if(Strategy_NextMonthKey(month_key) != month_keys[1])
               return false;
            parent_boundary_seen = true;
            break;
           }

         if(found_months == 0)
           {
            if(Strategy_NextMonthKey(month_key) != current_month_key)
               return false;
           }
         else if(Strategy_NextMonthKey(month_key) !=
                 month_keys[found_months - 1])
            return false;

         month_keys[found_months] = month_key;
         ++found_months;
        }

      const int bucket = found_months - 1;
      if(bucket < 0 || bucket > 1 || !Strategy_BarOHLCValid(bars[index]))
         return false;
      const int session_date_key = Strategy_DateKeyForTime(normalized);
      if(session_date_key <= 0 ||
         (month_last_date_keys[bucket] > 0 &&
          session_date_key >= month_last_date_keys[bucket]))
         return false;
      month_last_date_keys[bucket] = session_date_key;
      if(month_counts[bucket] == 0)
        {
         month_highs[bucket] = bars[index].high;
         month_lows[bucket] = bars[index].low;
         month_closes[bucket] = bars[index].close;
        }
      else
        {
         month_highs[bucket] =
            MathMax(month_highs[bucket], bars[index].high);
         month_lows[bucket] =
            MathMin(month_lows[bucket], bars[index].low);
        }
      // CopyRates is a series (newest to oldest), so the last assigned open
      // is the chronologically first session open for this month.
      month_opens[bucket] = bars[index].open;
      ++month_counts[bucket];
      if(month_counts[bucket] > strategy_max_month_sessions)
         return false;
     }

   if(found_months != 2 || !parent_boundary_seen)
      return false;
   for(int bucket = 0; bucket < 2; ++bucket)
     {
      if(month_counts[bucket] < strategy_min_month_sessions ||
         month_counts[bucket] > strategy_max_month_sessions)
         return false;
      const double aggregate_range =
         month_highs[bucket] - month_lows[bucket];
      if(month_highs[bucket] <= 0.0 ||
         month_lows[bucket] <= 0.0 ||
         month_opens[bucket] <= 0.0 ||
         month_closes[bucket] <= 0.0 ||
         aggregate_range <= 0.0 ||
         !MathIsValidNumber(month_highs[bucket]) ||
         !MathIsValidNumber(month_lows[bucket]) ||
         !MathIsValidNumber(month_opens[bucket]) ||
         !MathIsValidNumber(month_closes[bucket]) ||
         !MathIsValidNumber(aggregate_range))
         return false;
     }

   new_month_bars = month_counts[0];
   parent_month_bars = month_counts[1];
   new_high = month_highs[0];
   new_low = month_lows[0];
   new_open = month_opens[0];
   new_close = month_closes[0];
   parent_high = month_highs[1];
   parent_low = month_lows[1];

   const bool inside = (new_high < parent_high && new_low > parent_low);
   if(inside && new_close > new_open)
      direction = 1;
   else if(inside && new_close < new_open)
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

   // Consume before OHLC validation, signal, news, spread, quote, ATR,
   // sizing, or order gates. The broker-month clock is the prerequisite.
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
         Strategy_LoadInsideBodySignal(g_decision_month_key,
                                           g_decision_label_offset,
                                           g_signal_direction,
                                           g_new_month_bars,
                                           g_parent_month_bars,
                                           g_new_high,
                                           g_new_low,
                                           g_new_open,
                                           g_new_close,
                                           g_parent_high,
                                           g_parent_low);
      if(!g_signal_valid)
         g_signal_state = "monthly_ohlc_validation_failed";
      else if(g_signal_direction > 0)
         g_signal_state = "inside_body_long";
      else if(g_signal_direction < 0)
         g_signal_state = "inside_body_short";
      else if(g_new_high == g_parent_high ||
              g_new_low == g_parent_low)
         g_signal_state = "containment_equality_flat";
      else if(g_new_high < g_parent_high &&
              g_new_low > g_parent_low)
         g_signal_state = "inside_body_equality_flat";
      else
         g_signal_state = "not_inside_flat";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"completed_current_month_bars\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"new_month_bars\":%d,\"parent_month_bars\":%d,\"new_high\":%.8f,\"new_low\":%.8f,\"new_open\":%.8f,\"new_close\":%.8f,\"parent_high\":%.8f,\"parent_low\":%.8f,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_current_month_bar_count,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_direction,
                            g_new_month_bars,
                            g_parent_month_bars,
                            g_new_high,
                            g_new_low,
                            g_new_open,
                            g_new_close,
                            g_parent_high,
                            g_parent_low,
                            g_signal_state));
  }

// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41107 ||
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
      strategy_history_bars_d1 != 70 ||
      strategy_min_month_sessions != 17 ||
      strategy_max_month_sessions != 23 ||
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
   req.reason = "QM5_41107_WTI_MINSIDE_BODY_MOM";
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
      ? "WTI_MINSIDE_BODY_MOM_LONG"
      : "WTI_MINSIDE_BODY_MOM_SHORT";

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
      !Strategy_IsHostChart() || qm_ea_id != 41107 ||
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
      StringFormat("QM5_41107_MONTH_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41107\",\"ea\":\"wti-minside-body-mom\"}");
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
