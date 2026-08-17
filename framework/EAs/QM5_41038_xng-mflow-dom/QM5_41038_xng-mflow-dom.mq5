#property strict
#property version   "5.0"
#property description "QM5_41038 XNG Monthly Opposed-Flow Dominance"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41038 - XNG Monthly Opposed-Flow Dominance
// -----------------------------------------------------------------------------
// Direct XNGUSD.DWX D1 structural sleeve:
//   - decide once at the first executable D1 tick of a normalized broker month
//   - decompose every completed prior-month interval into close/open flows
//   - require accumulated overnight and session components to oppose strictly
//   - reconcile their sum to the completed month-end-to-month-end log return
//   - follow the larger absolute component until the next normalized broker month
//   - one persisted attempt, fixed-dollar ATR risk, no Friday flattening
// Runtime uses MT5-native OHLC/calendar/history only; no external data or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41038;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

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
input int    strategy_min_prior_month_bars = 15;
input int    strategy_max_prior_month_bars = 25;
input int    strategy_entry_grace_minutes  = 180;
input int    strategy_history_bars          = 90;
input double strategy_reconcile_tolerance   = 1.0e-10;
input int    strategy_atr_period             = 20;
input double strategy_atr_sl_mult            = 3.5;
input int    strategy_max_hold_days          = 40;
input int    strategy_max_spread_points      = 3000;

const string g_strategy_symbol = "XNGUSD.DWX";

int      g_last_attempt_month_key  = 0;
string   g_attempt_state_key       = "";
bool     g_decision_bar            = false;
bool     g_late_decision           = false;
int      g_decision_month_key      = 0;
datetime g_decision_bar_time       = 0;
int      g_decision_label_offset   = 0;
int      g_current_month_bar_count = 0;
bool     g_signal_valid            = false;
int      g_signal_direction        = 0;
int      g_prior_month_bar_count   = 0;
double   g_overnight_flow          = 0.0;
double   g_session_flow            = 0.0;
double   g_month_return            = 0.0;
double   g_total_flow              = 0.0;
string   g_signal_state            = "idle";

// -----------------------------------------------------------------------------
// Structural helpers.
// -----------------------------------------------------------------------------

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_strategy_symbol && _Period == PERIOD_D1);
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

bool Strategy_EntryWithinGrace(const datetime current_bar_time,
                               const datetime broker_now)
  {
   if(current_bar_time <= 0 || broker_now < current_bar_time)
      return false;
   const long elapsed = (long)(broker_now - current_bar_time);
   const long session_elapsed = elapsed % 86400L;
   return (session_elapsed <=
           (long)strategy_entry_grace_minutes * 60);
  }

bool Strategy_IsOwnedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == g_strategy_symbol &&
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
      const bool direction_valid =
         (type == POSITION_TYPE_BUY || type == POSITION_TYPE_SELL);
      const bool stop_valid =
         (stop_price > 0.0 && MathIsValidNumber(stop_price) &&
          ((type == POSITION_TYPE_BUY && stop_price < open_price) ||
           (type == POSITION_TYPE_SELL && stop_price > open_price)));
      return (direction_valid && opened > 0 && opened <= TimeCurrent() &&
              volume > 0.0 && MathIsValidNumber(volume) &&
              open_price > 0.0 && MathIsValidNumber(open_price) &&
              stop_valid);
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
   const datetime history_start = now - (long)45 * 86400;
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
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != g_strategy_symbol)
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
      stored_month_key >= 190001 && stored_month_key <= current_month_key)
     {
      g_last_attempt_month_key = stored_month_key;
      return;
     }

   // Tester globals can outlive a later historical replay. Remove malformed
   // or future state so the deterministic replay can establish its own ledger.
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
   g_prior_month_bar_count = 0;
   g_overnight_flow = 0.0;
   g_session_flow = 0.0;
   g_month_return = 0.0;
   g_total_flow = 0.0;
   g_signal_state = "idle";
  }

void Strategy_DetectDecisionClock()
  {
   Strategy_ResetDecisionState();

   MqlRates current_bar;
   ZeroMemory(current_bar);
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
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded month-clock scan behind a D1 decision/initialization gate.
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

bool Strategy_LoadMonthlyFlowSignal(const int current_month_key,
                                    const int label_offset,
                                    int &direction,
                                    int &prior_month_bar_count,
                                    double &overnight_flow,
                                    double &session_flow,
                                    double &month_return,
                                    double &total_flow)
  {
   direction = 0;
   prior_month_bar_count = 0;
   overnight_flow = 0.0;
   session_flow = 0.0;
   month_return = 0.0;
   total_flow = 0.0;
   if(current_month_key <= 0 ||
      strategy_min_prior_month_bars != 15 ||
      strategy_max_prior_month_bars != 25 ||
      strategy_min_prior_month_bars > strategy_max_prior_month_bars ||
      (label_offset != 0 && label_offset != 86400))
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded completed-month endpoint scan behind one monthly attempt.
                                PERIOD_D1,
                                1,
                                strategy_history_bars,
                                bars);
   if(copied < strategy_min_prior_month_bars + 1)
      return false;

   const int prior_month_key =
      Strategy_MonthKeyForTime(
         Strategy_NormalizedLabel(bars[0].time, label_offset));
   if(prior_month_key <= 0 ||
      Strategy_NextMonthKey(prior_month_key) != current_month_key)
      return false;

   while(prior_month_bar_count < copied &&
         Strategy_MonthKeyForTime(
            Strategy_NormalizedLabel(bars[prior_month_bar_count].time,
                                     label_offset)) == prior_month_key)
     {
      const MqlRates bar = bars[prior_month_bar_count];
      if(bar.time <= 0 || bar.open <= 0.0 || bar.close <= 0.0 ||
         !MathIsValidNumber(bar.open) ||
         !MathIsValidNumber(bar.close))
         return false;
      if(prior_month_bar_count > 0 &&
         bars[prior_month_bar_count - 1].time <= bar.time)
         return false;
      ++prior_month_bar_count;
     }

   if(prior_month_bar_count < strategy_min_prior_month_bars ||
      prior_month_bar_count > strategy_max_prior_month_bars ||
      prior_month_bar_count >= copied)
      return false;

   const MqlRates anchor = bars[prior_month_bar_count];
   const int prior_prior_month_key =
      Strategy_MonthKeyForTime(
         Strategy_NormalizedLabel(anchor.time, label_offset));
   if(anchor.time <= 0 || anchor.close <= 0.0 ||
      !MathIsValidNumber(anchor.close) ||
      bars[prior_month_bar_count - 1].time <= anchor.time ||
      prior_prior_month_key <= 0 ||
      Strategy_NextMonthKey(prior_prior_month_key) != prior_month_key)
      return false;

   for(int index = prior_month_bar_count - 1; index >= 0; --index)
     {
      const double prior_close = bars[index + 1].close;
      const double day_open = bars[index].open;
      const double day_close = bars[index].close;
      if(prior_close <= 0.0 || day_open <= 0.0 || day_close <= 0.0 ||
         !MathIsValidNumber(prior_close) ||
         !MathIsValidNumber(day_open) ||
         !MathIsValidNumber(day_close))
         return false;

      const double overnight_return = MathLog(day_open / prior_close);
      const double intraday_return = MathLog(day_close / day_open);
      if(!MathIsValidNumber(overnight_return) ||
         !MathIsValidNumber(intraday_return))
         return false;
      overnight_flow += overnight_return;
      session_flow += intraday_return;
     }

   month_return = MathLog(bars[0].close / anchor.close);
   total_flow = overnight_flow + session_flow;
   if(!MathIsValidNumber(overnight_flow) ||
      !MathIsValidNumber(session_flow) ||
      !MathIsValidNumber(month_return) ||
      !MathIsValidNumber(total_flow))
      return false;
   if(MathAbs(total_flow - month_return) >
      strategy_reconcile_tolerance)
      return false;

   // The approved edge trades only strict public/session disagreement, then
   // follows the sign of the larger absolute component. Equal magnitude is
   // deliberately flat. The reconciled total is an arithmetic audit identity;
   // its sign is the consequence of this locked dominance rule.
   const bool strict_opposition =
      ((overnight_flow < 0.0 && session_flow > 0.0) ||
       (overnight_flow > 0.0 && session_flow < 0.0));
   if(!strict_opposition)
      return true;

   const double overnight_abs = MathAbs(overnight_flow);
   const double session_abs = MathAbs(session_flow);
   if(session_abs > overnight_abs)
      direction = (session_flow > 0.0) ? 1 : -1;
   else if(overnight_abs > session_abs)
      direction = (overnight_flow > 0.0) ? 1 : -1;
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

   // Consume before endpoint validation, signal, news, spread, quote, ATR,
   // sizing, or order gates. Month-clock identification is the prerequisite.
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
         Strategy_LoadMonthlyFlowSignal(g_decision_month_key,
                                        g_decision_label_offset,
                                        g_signal_direction,
                                        g_prior_month_bar_count,
                                        g_overnight_flow,
                                        g_session_flow,
                                        g_month_return,
                                        g_total_flow);
      if(!g_signal_valid)
         g_signal_state = "endpoint_or_reconciliation_failed";
      else if(g_signal_direction > 0)
        {
         g_signal_state =
            (MathAbs(g_session_flow) > MathAbs(g_overnight_flow))
            ? "opposition_session_dominant_long"
            : "opposition_overnight_dominant_long";
        }
      else if(g_signal_direction < 0)
        {
         g_signal_state =
            (MathAbs(g_session_flow) > MathAbs(g_overnight_flow))
            ? "opposition_session_dominant_short"
            : "opposition_overnight_dominant_short";
        }
      else if(g_overnight_flow == 0.0 || g_session_flow == 0.0)
         g_signal_state = "exact_zero_flat";
      else if((g_overnight_flow > 0.0 && g_session_flow > 0.0) ||
              (g_overnight_flow < 0.0 && g_session_flow < 0.0))
         g_signal_state = "component_agreement_flat";
      else
         g_signal_state = "opposition_equal_magnitude_flat";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"completed_current_month_bars\":%d,\"prior_month_bars\":%d,\"late\":%s,\"valid\":%s,\"direction\":%d,\"overnight_flow\":%.12e,\"session_flow\":%.12e,\"month_return\":%.12e,\"total_flow\":%.12e,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_current_month_bar_count,
                            g_prior_month_bar_count,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_direction,
                            g_overnight_flow,
                            g_session_flow,
                            g_month_return,
                            g_total_flow,
                            g_signal_state));
  }

bool Strategy_PrimeLateMonthAttach()
  {
   Strategy_DetectDecisionClock();
   if(!g_decision_bar || !g_late_decision ||
      g_decision_month_key <= 0 ||
      g_decision_month_key == g_last_attempt_month_key)
      return true;

   if(!Strategy_RecordMonthAttempt(g_decision_month_key))
      return false;

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"late\":true,\"state\":\"late_init_consumed_flat\"}",
                            g_decision_month_key));
   return true;
  }

// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
     {
      PrintFormat("QM_INPUT_REJECT predicate=host_chart observed_symbol='%s' observed_period=%d required_symbol='%s' required_period=%d",
                  _Symbol, (int)_Period, g_strategy_symbol, (int)PERIOD_D1);
      return true;
     }
   if(!QM_InputRequireLong("qm_ea_id", qm_ea_id, 41038) ||
      !QM_InputRequireLong("qm_magic_slot_offset", qm_magic_slot_offset, 0) ||
      !QM_InputRequireLong("qm_rng_seed", qm_rng_seed, 42) ||
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
      !QM_InputRequireDouble("qm_stress_reject_probability", qm_stress_reject_probability, 0.0, 1.0e-12) ||
      !QM_InputRequireLong("strategy_min_prior_month_bars", strategy_min_prior_month_bars, 15) ||
      !QM_InputRequireLong("strategy_max_prior_month_bars", strategy_max_prior_month_bars, 25) ||
      !QM_InputRequireLong("strategy_entry_grace_minutes", strategy_entry_grace_minutes, 180) ||
      !QM_InputRequireLong("strategy_history_bars", strategy_history_bars, 90) ||
      !QM_InputRequireDouble("strategy_reconcile_tolerance", strategy_reconcile_tolerance, 0.0000000001, 1.0e-20) ||
      !QM_InputRequireLong("strategy_atr_period", strategy_atr_period, 20) ||
      !QM_InputRequireDouble("strategy_atr_sl_mult", strategy_atr_sl_mult, 3.5, 1.0e-12) ||
      !QM_InputRequireLong("strategy_max_hold_days", strategy_max_hold_days, 40) ||
      !QM_InputRequireLong("strategy_max_spread_points", strategy_max_spread_points, 3000))
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
   req.reason = "QM5_41038_XNG_MFLOW_DOM";
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
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.type = (g_signal_direction > 0) ? QM_BUY : QM_SELL;
   req.reason = (g_signal_direction > 0)
      ? "XNG_MFLOW_DOM_LONG"
      : "XNG_MFLOW_DOM_SHORT";

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
   if(!Strategy_OwnedPositionStateValid())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   MqlRates current_bar;
   ZeroMemory(current_bar);
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
   if(!SymbolSelect(_Symbol, true))
     {
      PrintFormat("QM_INPUT_REJECT predicate=SymbolSelect observed=false required=true symbol='%s'", g_strategy_symbol);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!Strategy_IsHostChart())
     {
      PrintFormat("QM_INPUT_REJECT predicate=host_chart observed_symbol='%s' observed_period=%d required_symbol='%s' required_period=%d",
                  _Symbol, (int)_Period, g_strategy_symbol, (int)PERIOD_D1);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!QM_InputRequireLong("qm_ea_id", qm_ea_id, 41038) ||
      !QM_InputRequireLong("qm_magic_slot_offset", qm_magic_slot_offset, 0))
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
         "Approved monthly flow-divergence card holds through Fridays until next broker month"))
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
      StringFormat("QM5_41038_MFLOW_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_strategy_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars);

   if(!Strategy_PrimeLateMonthAttach())
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41038\",\"ea\":\"xng-mflow-dom\"}");
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

   // Lifecycle repairs run on every tick and precede all entry-only gates.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();
   Strategy_DetectDecisionClock();
   Strategy_PrepareDecisionSignal();

   if(Strategy_NoTradeFilter())
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(!Strategy_EntrySignal(req))
      return;

   // The month attempt is already consumed before this entry-only gate.
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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
