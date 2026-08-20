#property strict
#property version   "5.0"
#property description "QM5_41071 WTI Completed-Week Resumption Dominance"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41071 - WTI Completed-Week Resumption Dominance
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - reconstruct four consecutive completed broker-week-end closes
//   - calculate three adjacent, non-overlapping completed-week log returns
//   - require resume/counter/resume signs and strict resumed-move dominance
//   - consume the week before fallible gates; never enter late or retry
//   - follow the resumed sign until the next week with a fixed-risk hard stop
// Runtime uses MT5-native OHLC, calendar, history, and framework state only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 41071;
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
input int    strategy_history_bars          = 40;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult            = 3.5;
input int    strategy_max_hold_days         = 10;
input int    strategy_max_spread_points     = 1500;

const string g_strategy_symbol = "XTIUSD.DWX";

int      g_last_attempt_week_key = 0;
string   g_attempt_state_key      = "";
bool     g_decision_bar           = false;
bool     g_late_decision          = false;
int      g_decision_week_key     = 0;
datetime g_decision_bar_time      = 0;
int      g_decision_label_offset  = 0;
int      g_current_week_bar_count = 0;
bool     g_signal_valid           = false;
int      g_signal_direction       = 0;
double   g_resume_return          = 0.0;
double   g_counter_return         = 0.0;
double   g_oldest_return          = 0.0;
double   g_week_end_c1           = 0.0;
double   g_week_end_c2           = 0.0;
double   g_week_end_c3           = 0.0;
double   g_week_end_c4           = 0.0;
string   g_signal_state           = "idle";

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

int Strategy_WeekKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   if(parts.year < 1900 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31 ||
      parts.day_of_week < 0 || parts.day_of_week > 6)
      return 0;

   const int days_since_monday = (parts.day_of_week + 6) % 7;
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   const datetime day_start = StructToTime(parts);
   if(day_start <= 0)
      return 0;
   return Strategy_DateKeyForTime(
      day_start - (datetime)((long)days_since_monday * 86400L));
  }

int Strategy_NextWeekKey(const int week_key)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = week_key / 10000;
   parts.mon = (week_key / 100) % 100;
   parts.day = week_key % 100;
   if(parts.year < 1900 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;

   const datetime anchor = StructToTime(parts);
   if(anchor <= 0 ||
      Strategy_DateKeyForTime(anchor) != week_key ||
      Strategy_WeekKeyForTime(anchor) != week_key)
      return 0;
   return Strategy_WeekKeyForTime(anchor + (datetime)(7L * 86400L));
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
           (long)strategy_entry_grace_minutes * 60L);
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

bool Strategy_WeekAlreadyEntered(const int week_key)
  {
   if(week_key <= 0)
      return true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_WeekKeyForTime(opened) == week_key)
         return true;
     }

   const datetime now = TimeCurrent();
   const datetime history_start = now - (long)50 * 86400;
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
      if(Strategy_WeekKeyForTime(deal_time) == week_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_week_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_week_key = Strategy_WeekKeyForTime(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_week_key = (int)MathRound(stored);
   if(current_week_key > 0 && MathIsValidNumber(stored) &&
      stored_week_key >= 19000101 && stored_week_key <= current_week_key)
     {
      g_last_attempt_week_key = stored_week_key;
      return;
     }

   // Tester globals can outlive a later historical run. Remove malformed or
   // future state so the deterministic replay can establish its own ledger.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordWeekAttempt(const int week_key)
  {
   if(week_key <= 0 || g_attempt_state_key == "")
      return false;

   // Stay fail-closed in-process even if terminal persistence itself fails.
   g_last_attempt_week_key = week_key;
   return (GlobalVariableSet(g_attempt_state_key,
                             (double)week_key) > 0);
  }

void Strategy_ResetDecisionState()
  {
   g_decision_bar = false;
   g_late_decision = false;
   g_decision_week_key = 0;
   g_decision_bar_time = 0;
   g_decision_label_offset = 0;
   g_current_week_bar_count = 0;
   g_signal_valid = false;
   g_signal_direction = 0;
   g_resume_return = 0.0;
   g_counter_return = 0.0;
   g_oldest_return = 0.0;
   g_week_end_c1 = 0.0;
   g_week_end_c2 = 0.0;
   g_week_end_c3 = 0.0;
   g_week_end_c4 = 0.0;
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
   const int current_week_key =
      Strategy_WeekKeyForTime(normalized_current);
   if(current_week_key <= 0 ||
      current_week_key != Strategy_WeekKeyForTime(broker_now) ||
      Strategy_DateKeyForTime(normalized_current) !=
         Strategy_DateKeyForTime(broker_now))
      return;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded week-clock scan behind the sole QM_IsNewBar branch.
                PERIOD_D1,
                1,
                strategy_history_bars,
                bars);
   if(copied <= 0)
      return;

   int current_week_count = 0;
   while(current_week_count < copied &&
         Strategy_WeekKeyForTime(
            Strategy_NormalizedLabel(bars[current_week_count].time,
                                     label_offset)) == current_week_key)
      ++current_week_count;

   if(current_week_count >= copied)
      return;

   const int prior_week_key =
      Strategy_WeekKeyForTime(
         Strategy_NormalizedLabel(bars[current_week_count].time,
                                  label_offset));
   if(prior_week_key <= 0 ||
      Strategy_NextWeekKey(prior_week_key) != current_week_key)
      return;

   g_decision_bar = true;
   g_decision_week_key = current_week_key;
   g_decision_bar_time = current_bar.time;
   g_decision_label_offset = label_offset;
   g_current_week_bar_count = current_week_count;
   g_late_decision =
      (current_week_count > 0 ||
       !Strategy_EntryWithinGrace(current_bar.time, broker_now));
  }

bool Strategy_LoadResumptionSignal(const int current_week_key,
                                    const int label_offset,
                                    int &direction,
                                    double &resume_return,
                                    double &counter_return,
                                    double &oldest_return,
                                    double &week_end_c1,
                                    double &week_end_c2,
                                    double &week_end_c3,
                                    double &week_end_c4)
  {
   direction = 0;
   resume_return = 0.0;
   counter_return = 0.0;
   oldest_return = 0.0;
   week_end_c1 = 0.0;
   week_end_c2 = 0.0;
   week_end_c3 = 0.0;
   week_end_c4 = 0.0;
   if(current_week_key <= 0 ||
      (label_offset != 0 && label_offset != 86400))
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded endpoint scan behind the sole QM_IsNewBar branch.
                PERIOD_D1,
                1,
                strategy_history_bars,
                bars);
   if(copied < 4)
      return false;

   int week_keys[4] = {0, 0, 0, 0};
   double week_closes[4] = {0.0, 0.0, 0.0, 0.0};
   int found = 0;
   for(int index = 0; index < copied && found < 4; ++index)
     {
      if(bars[index].time <= 0)
         return false;
      if(index > 0 && bars[index - 1].time <= bars[index].time)
         return false;

      const datetime normalized =
         Strategy_NormalizedLabel(bars[index].time, label_offset);
      const int week_key = Strategy_WeekKeyForTime(normalized);
      if(week_key <= 0 || week_key == current_week_key)
         return false;

      if(found > 0 && week_key == week_keys[found - 1])
         continue;

      if(found == 0)
        {
         if(Strategy_NextWeekKey(week_key) != current_week_key)
            return false;
        }
      else if(Strategy_NextWeekKey(week_key) != week_keys[found - 1])
         return false;

      const double endpoint = bars[index].close;
      if(endpoint <= 0.0 || !MathIsValidNumber(endpoint))
         return false;
      week_keys[found] = week_key;
      week_closes[found] = endpoint;
      ++found;
     }

   if(found != 4)
      return false;

   week_end_c1 = week_closes[0];
   week_end_c2 = week_closes[1];
   week_end_c3 = week_closes[2];
   week_end_c4 = week_closes[3];

   resume_return = MathLog(week_end_c1 / week_end_c2);
   counter_return = MathLog(week_end_c2 / week_end_c3);
   oldest_return = MathLog(week_end_c3 / week_end_c4);
   if(!MathIsValidNumber(resume_return) ||
      !MathIsValidNumber(counter_return) ||
      !MathIsValidNumber(oldest_return))
      return false;

   if(oldest_return > 0.0 && counter_return < 0.0 &&
      resume_return > 0.0 &&
      MathAbs(resume_return) > MathAbs(counter_return))
      direction = 1;
   else if(oldest_return < 0.0 && counter_return > 0.0 &&
           resume_return < 0.0 &&
           MathAbs(resume_return) > MathAbs(counter_return))
      direction = -1;
   return true;
  }

void Strategy_PrepareDecisionSignal()
  {
   if(!g_decision_bar || g_decision_week_key <= 0 ||
      g_decision_bar_time <= 0)
      return;

   if(g_decision_week_key == g_last_attempt_week_key)
     {
      g_signal_state = "week_already_consumed";
      return;
     }

   // Consume before endpoint validation, signal, news, spread, quote, ATR,
   // sizing, or order gates. The broker-week clock is the prerequisite.
   if(!Strategy_RecordWeekAttempt(g_decision_week_key))
     {
      g_signal_state = "attempt_persist_failed";
      return;
     }

   if(Strategy_WeekAlreadyEntered(g_decision_week_key))
      g_signal_state = "entry_deal_already_exists";
   else if(g_late_decision)
      g_signal_state = "late_restart_consumed_flat";
   else
     {
      g_signal_valid =
         Strategy_LoadResumptionSignal(g_decision_week_key,
                                       g_decision_label_offset,
                                       g_signal_direction,
                                       g_resume_return,
                                       g_counter_return,
                                       g_oldest_return,
                                       g_week_end_c1,
                                       g_week_end_c2,
                                       g_week_end_c3,
                                       g_week_end_c4);
      if(!g_signal_valid)
         g_signal_state = "endpoint_validation_failed";
      else if(g_signal_direction > 0)
         g_signal_state = "positive_resumption_long";
      else if(g_signal_direction < 0)
         g_signal_state = "negative_resumption_short";
      else if(g_resume_return == 0.0 || g_counter_return == 0.0 ||
              g_oldest_return == 0.0)
         g_signal_state = "exact_zero_flat";
      else if((g_oldest_return > 0.0 && g_counter_return < 0.0 &&
               g_resume_return > 0.0) ||
              (g_oldest_return < 0.0 && g_counter_return > 0.0 &&
               g_resume_return < 0.0))
         g_signal_state = "resumption_not_dominant_flat";
      else
         g_signal_state = "path_mismatch_flat";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"week\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"completed_current_week_bars\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"oldest_return\":%.12e,\"counter_return\":%.12e,\"resume_return\":%.12e,\"c4\":%.8f,\"c3\":%.8f,\"c2\":%.8f,\"c1\":%.8f,\"state\":\"%s\"}",
                            g_decision_week_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_current_week_bar_count,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_direction,
                            g_oldest_return,
                            g_counter_return,
                            g_resume_return,
                            g_week_end_c4,
                            g_week_end_c3,
                            g_week_end_c2,
                            g_week_end_c1,
                            g_signal_state));
  }

// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41071 ||
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
      strategy_history_bars != 40 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 ||
      strategy_max_hold_days != 10 ||
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
   req.reason = "QM5_41071_WTI_WRESUME_DOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_decision_bar || g_late_decision ||
      g_decision_week_key <= 0 ||
      g_decision_week_key != g_last_attempt_week_key ||
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
      ? "WTI_WRESUME_DOM_LONG"
      : "WTI_WRESUME_DOM_SHORT";

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
   const int current_week_key =
      Strategy_WeekKeyForTime(normalized_current);
   const int opened_week_key = Strategy_WeekKeyForTime(opened);
   if(label_offset < 0 || current_week_key <= 0 ||
      opened_week_key <= 0 || opened <= 0 || opened > now)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   if(opened_week_key != current_week_key)
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
   if(!SymbolSelect(g_strategy_symbol, true) ||
      !Strategy_IsHostChart() || qm_ea_id != 41071 ||
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
      StringFormat("QM5_41071_WEEK_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_strategy_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41071\",\"ea\":\"wti-wresume-dom\"}");
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

   // Lifecycle repair and exact next-week closure precede entry-only gates
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
