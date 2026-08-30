#property strict
#property version   "5.0"
#property description "QM5_41212 WTI Same-Calendar Bernoulli Sign-Score Seasonality"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41212 - WTI Same-Calendar Bernoulli Sign-Score Seasonality
// -----------------------------------------------------------------------------
// Structural D1 crude-oil sleeve:
//   - decide only at a genuine normalized broker-month boundary
//   - reconstruct the upcoming calendar month's completed return in Y-1..Y-10
//   - skip missing exact years without substitution and require at least five
//   - map each finite nonnegative return to one and each negative return to zero
//   - standardize the sign count against a Bernoulli p0=0.5 null
//   - follow only when the score is strictly beyond +/-1.0 plus tolerance
//   - consume one yyyymm attempt before every fallible entry gate
//   - renew at the next month boundary behind one frozen ATR hard stop
// Native MT5 calendar/OHLC/history only; no external runtime data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41212;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
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
input int    strategy_history_years       = 10;
input int    strategy_min_observations    = 5;
input double strategy_null_probability   = 0.5;
input double strategy_score_threshold     = 1.0;
input double strategy_signal_tolerance    = 1.0e-10;
input int    strategy_history_bars_d1     = 3000;
input int    strategy_entry_grace_minutes = 180;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.5;
input int    strategy_max_hold_days       = 40;
input int    strategy_max_spread_points   = 1500;

const string g_symbol = "XTIUSD.DWX";

int      g_last_attempt_month_key = 0;
string   g_attempt_state_key      = "";
bool     g_strategy_new_d1_bar    = false;
bool     g_decision_bar           = false;
datetime g_decision_bar_time      = 0;
int      g_decision_month_key     = 0;
int      g_decision_label_offset  = 0;
bool     g_signal_valid           = false;
int      g_signal_direction       = 0;
int      g_signal_sample_count    = 0;
int      g_signal_success_count   = 0;
double   g_signal_null_denominator = 0.0;
double   g_signal_sign_score      = 0.0;
string   g_signal_state           = "idle";

// -----------------------------------------------------------------------------
// Structural calendar helpers.
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
   if(!TimeToStruct(value, parts) || parts.year < 1900 ||
      parts.mon < 1 || parts.mon > 12 ||
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
   if(!TimeToStruct(value, parts) || parts.year < 1900 ||
      parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
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

   const long elapsed = (long)(broker_now - current_bar_time);
   if(elapsed < 86400L)
      return 0;
   if(elapsed < 172800L)
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

int Strategy_CurrentNormalizedMonthKey()
  {
   MqlRates current_bar;
   ZeroMemory(current_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar))
      return 0;

   const datetime broker_now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(current_bar.time, broker_now);
   const datetime normalized =
      Strategy_NormalizedLabel(current_bar.time, label_offset);
   if(label_offset < 0 || normalized <= 0 ||
      Strategy_DateKeyForTime(normalized) !=
         Strategy_DateKeyForTime(broker_now))
      return 0;
   return Strategy_MonthKeyForTime(normalized);
  }

void Strategy_ResetDecisionState()
  {
   g_decision_bar = false;
   g_decision_bar_time = 0;
   g_decision_month_key = 0;
   g_decision_label_offset = 0;
   g_signal_valid = false;
   g_signal_direction = 0;
   g_signal_sample_count = 0;
   g_signal_success_count = 0;
   g_signal_null_denominator = 0.0;
   g_signal_sign_score = 0.0;
   g_signal_state = "idle";
  }

void Strategy_DetectDecisionClockOnNewBar()
  {
   Strategy_ResetDecisionState();

   MqlRates current_bar;
   MqlRates previous_bar;
   ZeroMemory(current_bar);
   ZeroMemory(previous_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 1, previous_bar))
      return;

   const datetime broker_now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(current_bar.time, broker_now);
   if(label_offset < 0)
      return;

   const datetime current_session =
      Strategy_NormalizedLabel(current_bar.time, label_offset);
   const datetime previous_session =
      Strategy_NormalizedLabel(previous_bar.time, label_offset);
   if(current_session <= previous_session ||
      Strategy_DateKeyForTime(current_session) !=
         Strategy_DateKeyForTime(broker_now))
      return;

   const int current_month = Strategy_MonthKeyForTime(current_session);
   const int previous_month = Strategy_MonthKeyForTime(previous_session);
   if(current_month <= 0 || previous_month <= 0 ||
      Strategy_NextMonthKey(previous_month) != current_month)
      return;

   g_decision_bar = true;
   g_decision_bar_time = current_bar.time;
   g_decision_month_key = current_month;
   g_decision_label_offset = label_offset;
  }

// -----------------------------------------------------------------------------
// Ownership, durable attempt, and lifecycle helpers.
// -----------------------------------------------------------------------------

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

bool Strategy_HasOwnedPosition()
  {
   return (Strategy_OwnedPositionCount() > 0);
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

bool Strategy_MonthAlreadyEntered(const int month_key)
  {
   if(month_key <= 0 || Strategy_HasOwnedPosition())
      return true;

   MqlDateTime month_start_parts;
   ZeroMemory(month_start_parts);
   month_start_parts.year = month_key / 100;
   month_start_parts.mon = month_key % 100;
   month_start_parts.day = 1;
   const datetime month_start = StructToTime(month_start_parts);
   const datetime now = TimeCurrent();
   if(month_start <= 0 || now < month_start ||
      !HistorySelect(month_start, now))
      return true;

   const int magic = QM_FrameworkMagic();
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
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

   const int current_month_key = Strategy_MonthKeyForTime(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_month_key = (int)MathRound(stored);
   if(current_month_key > 0 && MathIsValidNumber(stored) &&
      stored_month_key >= 190001 &&
      stored_month_key <= current_month_key)
     {
      g_last_attempt_month_key = stored_month_key;
      return;
     }

   // Tester globals can survive a later historical run. A future or malformed
   // marker must not suppress the beginning of a deterministic replay.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordMonthAttempt(const int month_key)
  {
   if(month_key <= 0 || g_attempt_state_key == "")
      return false;

   // Remain fail-closed in-process even if terminal persistence fails.
   g_last_attempt_month_key = month_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)month_key) > 0);
  }

void Strategy_CloseExpiredPositions()
  {
   const int owned_count = Strategy_OwnedPositionCount();
   if(owned_count <= 0)
      return;

   const datetime now = TimeCurrent();
   const int current_month_key = Strategy_CurrentNormalizedMonthKey();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400L;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const int opened_month_key = Strategy_MonthKeyForTime(opened);

      bool should_close =
         (owned_count != 1 || current_month_key <= 0 ||
          (position_type != POSITION_TYPE_BUY &&
           position_type != POSITION_TYPE_SELL) ||
          opened <= 0 || opened > now || opened_month_key <= 0 ||
          volume <= 0.0 || !MathIsValidNumber(volume) ||
          open_price <= 0.0 || !MathIsValidNumber(open_price) ||
          stop_price <= 0.0 || !MathIsValidNumber(stop_price));

      if(!should_close && opened_month_key != current_month_key)
         should_close = true;
      if(!should_close && (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// -----------------------------------------------------------------------------
// Exact completed-month endpoint and Bernoulli sign-score helpers.
// -----------------------------------------------------------------------------

bool Strategy_CompletedMonthReturn(const MqlRates &rates[],
                                   const int count,
                                   const int target_month_key,
                                   const int label_offset,
                                   double &month_return)
  {
   month_return = 0.0;
   if(count < 3 || ArraySize(rates) < count || target_month_key <= 0 ||
      (label_offset != 0 && label_offset != 86400))
      return false;

   int first_index = -1;
   int last_index = -1;
   for(int index = 0; index < count; ++index)
     {
      const datetime normalized =
         Strategy_NormalizedLabel(rates[index].time, label_offset);
      if(Strategy_MonthKeyForTime(normalized) != target_month_key)
         continue;
      if(first_index < 0)
         first_index = index;
      last_index = index;
     }

   if(first_index <= 0 || last_index < first_index ||
      last_index + 1 >= count)
      return false;

   const int previous_month_key =
      Strategy_MonthKeyForTime(
         Strategy_NormalizedLabel(rates[first_index - 1].time,
                                  label_offset));
   const int following_month_key =
      Strategy_MonthKeyForTime(
         Strategy_NormalizedLabel(rates[last_index + 1].time,
                                  label_offset));
   if(previous_month_key != Strategy_PreviousMonthKey(target_month_key) ||
      following_month_key != Strategy_NextMonthKey(target_month_key))
      return false;

   if(rates[first_index - 1].time >= rates[first_index].time ||
      rates[last_index].time >= rates[last_index + 1].time)
      return false;

   for(int index = first_index; index <= last_index; ++index)
     {
      if(Strategy_MonthKeyForTime(
            Strategy_NormalizedLabel(rates[index].time,
                                     label_offset)) != target_month_key)
         return false;
      if(index > first_index &&
         rates[index - 1].time >= rates[index].time)
         return false;
     }

   const double prior_close = rates[first_index - 1].close;
   const double month_end_close = rates[last_index].close;
   if(prior_close <= 0.0 || month_end_close <= 0.0 ||
      !MathIsValidNumber(prior_close) ||
      !MathIsValidNumber(month_end_close))
      return false;

   month_return = MathLog(month_end_close / prior_close);
   return MathIsValidNumber(month_return);
  }

bool Strategy_BernoulliSignScoreSignal(const double &observations[],
                                         const int sample_count,
                                         int &success_count,
                                         double &null_denominator_value,
                                         double &score_value,
                                         int &direction)
  {
   success_count = 0;
   null_denominator_value = 0.0;
   score_value = 0.0;
   direction = 0;

   if(strategy_history_years != 10 ||
      strategy_min_observations != 5 ||
      MathAbs(strategy_null_probability - 0.5) > 1.0e-12 ||
      MathAbs(strategy_score_threshold - 1.0) > 1.0e-12 ||
      MathAbs(strategy_signal_tolerance - 1.0e-10) > 1.0e-16 ||
      sample_count < strategy_min_observations ||
      sample_count > strategy_history_years ||
      ArraySize(observations) < sample_count)
      return false;

   for(int index = 0; index < sample_count; ++index)
     {
      if(index >= ArraySize(observations) ||
         !MathIsValidNumber(observations[index]))
         return false;
      if(observations[index] >= 0.0)
         ++success_count;
     }
   if(success_count < 0 || success_count > sample_count)
      return false;

   const double expected_successes =
      (double)sample_count * strategy_null_probability;
   const double null_variance =
      (double)sample_count *
      strategy_null_probability *
      (1.0 - strategy_null_probability);
   if(!MathIsValidNumber(expected_successes) ||
      !MathIsValidNumber(null_variance) ||
      null_variance <= 0.0)
      return false;

   null_denominator_value = MathSqrt(null_variance);
   if(!MathIsValidNumber(null_denominator_value) ||
      null_denominator_value <= 0.0)
      return false;

   score_value =
      ((double)success_count - expected_successes) /
      null_denominator_value;
   if(!MathIsValidNumber(score_value))
      return false;

   const double upper_gate =
      strategy_score_threshold + strategy_signal_tolerance;
   const double lower_gate =
      -strategy_score_threshold - strategy_signal_tolerance;
   if(score_value > upper_gate)
      direction = 1;
   else if(score_value < lower_gate)
      direction = -1;
   return true;
  }

bool Strategy_LoadBernoulliSignScoreSignal(const datetime decision_bar_time,
                                           const int decision_month_key,
                                           const int label_offset,
                                           int &sample_count,
                                           int &success_count,
                                           double &null_denominator_value,
                                           double &score_value,
                                           int &direction)
  {
   sample_count = 0;
   success_count = 0;
   null_denominator_value = 0.0;
   score_value = 0.0;
   direction = 0;
   if(decision_bar_time <= 0 || decision_month_key <= 0 ||
      (label_offset != 0 && label_offset != 86400))
      return false;

   MqlDateTime decision_parts;
   ZeroMemory(decision_parts);
   const datetime normalized_decision =
      Strategy_NormalizedLabel(decision_bar_time, label_offset);
   if(!TimeToStruct(normalized_decision, decision_parts) ||
      decision_parts.year - strategy_history_years < 1900 ||
      decision_parts.mon < 1 || decision_parts.mon > 12)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const datetime latest_completed_time =
      (datetime)(decision_bar_time - 1);
   const int copied =
      CopyRates(_Symbol,               // perf-allowed: one bounded 3,000-bar
                PERIOD_D1,             // endpoint scan after a consumed
                latest_completed_time, // monthly decision attempt.
                strategy_history_bars_d1,
                rates);
   if(copied < 3 || copied > strategy_history_bars_d1 ||
      ArraySize(rates) < copied)
      return false;
   for(int index = 1; index < copied; ++index)
     {
      if(index >= ArraySize(rates) ||
         rates[index].time <= rates[index - 1].time)
         return false;
     }

   double observations[];
   if(ArrayResize(observations, strategy_history_years) !=
         strategy_history_years ||
      ArraySize(observations) < strategy_history_years)
      return false;

   for(int offset = 1; offset <= strategy_history_years; ++offset)
     {
      const int sample_month_key =
         (decision_parts.year - offset) * 100 + decision_parts.mon;
      double sample_return = 0.0;
      if(!Strategy_CompletedMonthReturn(rates,
                                        copied,
                                        sample_month_key,
                                        label_offset,
                                        sample_return))
         continue;
      if(sample_count < 0 || sample_count >= ArraySize(observations))
         return false;
      observations[sample_count] = sample_return;
      ++sample_count;
     }

   if(sample_count < strategy_min_observations)
      return false;

   return Strategy_BernoulliSignScoreSignal(observations,
                                            sample_count,
                                            success_count,
                                            null_denominator_value,
                                            score_value,
                                            direction);
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

   // Consume before history, sign-score arithmetic, news, spread, quote, ATR,
   // sizing, or order gates. A restart can never create a later retry.
   if(!Strategy_RecordMonthAttempt(g_decision_month_key))
     {
      g_signal_state = "attempt_persist_failed";
      return;
     }

   if(Strategy_MonthAlreadyEntered(g_decision_month_key))
      g_signal_state = "entry_deal_or_position_exists";
   else
     {
      g_signal_valid =
         Strategy_LoadBernoulliSignScoreSignal(
            g_decision_bar_time,
            g_decision_month_key,
            g_decision_label_offset,
            g_signal_sample_count,
            g_signal_success_count,
            g_signal_null_denominator,
            g_signal_sign_score,
            g_signal_direction);
      if(!g_signal_valid)
         g_signal_state = "endpoint_sample_or_sign_score_failed";
      else if(g_signal_direction > 0)
         g_signal_state = "sign_score_long";
      else if(g_signal_direction < 0)
         g_signal_state = "sign_score_short";
      else
         g_signal_state = "sign_score_band_flat";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"valid\":%s,\"samples\":%d,\"successes\":%d,\"null_denominator\":%.12g,\"sign_score\":%.12g,\"direction\":%d,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_signal_valid ? "true" : "false",
                            g_signal_sample_count,
                            g_signal_success_count,
                            g_signal_null_denominator,
                            g_signal_sign_score,
                            g_signal_direction,
                            g_signal_state));
  }

// -----------------------------------------------------------------------------
// Five strategy hooks.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
     {
      PrintFormat("QM_INPUT_REJECT predicate=host_chart observed_symbol='%s' observed_period=%d required_symbol='XTIUSD.DWX' required_period=%d",
                  _Symbol, (int)_Period, (int)PERIOD_D1);
      return true;
     }

   if(!QM_InputRequireLong("qm_ea_id", qm_ea_id, 41212) ||
      !QM_InputRequireLong("qm_magic_slot_offset", qm_magic_slot_offset, 0) ||
      !QM_InputRequireDouble("RISK_PERCENT", RISK_PERCENT, 0.0, 1.0e-12) ||
      !QM_InputRequireDouble("RISK_FIXED", RISK_FIXED, 1000.0, 1.0e-12) ||
      !QM_InputRequireDouble("PORTFOLIO_WEIGHT", PORTFOLIO_WEIGHT, 1.0, 1.0e-12) ||
      !QM_InputRequireLong("qm_news_temporal", qm_news_temporal, QM_NEWS_TEMPORAL_OFF) ||
      !QM_InputRequireLong("qm_news_compliance", qm_news_compliance, QM_NEWS_COMPLIANCE_NONE) ||
      !QM_InputRequireLong("qm_news_mode_legacy", qm_news_mode_legacy, QM_NEWS_OFF) ||
      !QM_InputRequireLong("qm_news_stale_max_hours", qm_news_stale_max_hours, 336) ||
      !QM_InputRequireString("qm_news_min_impact", qm_news_min_impact, "high") ||
      !QM_InputRequireLong("qm_friday_close_enabled", qm_friday_close_enabled, false) ||
      !QM_InputRequireLong("qm_friday_close_hour_broker", qm_friday_close_hour_broker, 21) ||
      !QM_InputRequireLong("strategy_history_years", strategy_history_years, 10) ||
      !QM_InputRequireLong("strategy_min_observations", strategy_min_observations, 5) ||
      !QM_InputRequireDouble("strategy_null_probability", strategy_null_probability, 0.5, 1.0e-12) ||
      !QM_InputRequireDouble("strategy_score_threshold", strategy_score_threshold, 1.0, 1.0e-12) ||
      !QM_InputRequireDouble("strategy_signal_tolerance", strategy_signal_tolerance, 0.0000000001, 1.0e-16) ||
      !QM_InputRequireLong("strategy_history_bars_d1", strategy_history_bars_d1, 3000) ||
      !QM_InputRequireLong("strategy_entry_grace_minutes", strategy_entry_grace_minutes, 180) ||
      !QM_InputRequireLong("strategy_atr_period_d1", strategy_atr_period_d1, 20) ||
      !QM_InputRequireDouble("strategy_atr_sl_mult", strategy_atr_sl_mult, 3.5, 1.0e-12) ||
      !QM_InputRequireLong("strategy_max_hold_days", strategy_max_hold_days, 40) ||
      !QM_InputRequireLong("strategy_max_spread_points", strategy_max_spread_points, 1500))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WTI_SAMECAL_SIGNSCORE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_strategy_new_d1_bar || !g_decision_bar ||
      g_decision_month_key <= 0 ||
      g_decision_month_key != g_last_attempt_month_key ||
      !g_signal_valid || g_signal_direction == 0 ||
      Strategy_HasOwnedPosition())
      return false;

   if(g_signal_direction > 0)
     {
      req.type = QM_BUY;
      req.reason = "WTI_SAMECAL_SIGNSCORE_LONG";
     }
   else
     {
      req.type = QM_SELL;
      req.reason = "WTI_SAMECAL_SIGNSCORE_SHORT";
     }

   const datetime normalized_decision =
      Strategy_NormalizedLabel(g_decision_bar_time,
                               g_decision_label_offset);
   const long opening_delay =
      (long)(TimeCurrent() - normalized_decision);
   if(normalized_decision <= 0 || opening_delay < 0 ||
      opening_delay > (long)strategy_entry_grace_minutes * 60L)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point_size <= 0.0 ||
      !MathIsValidNumber(bid) || !MathIsValidNumber(ask) ||
      !MathIsValidNumber(point_size) || ask < bid)
      return false;

   const double modeled_spread_points = (ask - bid) / point_size;
   if(!MathIsValidNumber(modeled_spread_points) ||
      modeled_spread_points < 0.0 ||
      modeled_spread_points > (double)strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl))
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseExpiredPositions();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - canonical V5 lifecycle.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!SymbolSelect(g_symbol, true) ||
      !Strategy_IsHostChart() || qm_ea_id != 41212 ||
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
         "Approved WTI same-calendar Bernoulli sign-score card holds to the next broker month"))
      return INIT_FAILED;

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41212_SAMECAL_SIGNSCORE_MONTH_ATTEMPT_%d",
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
               "{\"card\":\"QM5_41212\",\"ea\":\"wti-samecal-signscore\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(!Strategy_IsHostChart())
      return;

   g_strategy_new_d1_bar = QM_IsNewBar(_Symbol, PERIOD_D1);
   if(g_strategy_new_d1_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_DetectDecisionClockOnNewBar();
     }

   // Monthly and malformed lifecycle repair precedes every entry-only gate
   // and remains retryable on every tick.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(!g_strategy_new_d1_bar || Strategy_NoTradeFilter())
      return;

   if(g_decision_bar)
      Strategy_PrepareDecisionSignal();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(!Strategy_EntrySignal(req))
      return;

   // The exact yyyymm attempt is already durable before this entry-only news
   // gate. Both axes are locked OFF for the baseline.
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   ulong out_ticket = 0;
   QM_TM_OpenPosition(req, out_ticket);
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


