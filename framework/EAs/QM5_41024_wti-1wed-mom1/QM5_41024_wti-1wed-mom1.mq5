#property strict
#property version   "5.0"
#property description "QM5_41024 WTI First-Wednesday Prior-Month Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41024 - WTI First-Wednesday / Prior-Month Momentum
// -----------------------------------------------------------------------------
// D1 structural crude-oil sleeve:
//   - decide only on the first genuine Wednesday of each broker month
//   - follow the immediately completed calendar month's WTI return sign
//   - consume the month before fallible gates; never shift, retry, or backfill
//   - close at the first following D1 boundary with a fixed-risk ATR stop
// Runtime uses MT5-native OHLC, calendar, history, and framework state only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 41024;
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
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_entry_dow              = 3;
input int    strategy_first_week_last_dom     = 7;
input int    strategy_return_months           = 1;
input int    strategy_hold_bars               = 1;
input int    strategy_entry_grace_minutes    = 180;
input int    strategy_history_bars            = 100;
input int    strategy_atr_period             = 20;
input double strategy_atr_sl_mult            = 3.0;
input int    strategy_max_hold_days          = 5;
input int    strategy_max_spread_points      = 1500;

const string g_strategy_symbol = "XTIUSD.DWX";

int      g_last_attempt_month_key  = 0;
string   g_attempt_state_key       = "";
bool     g_decision_bar            = false;
bool     g_late_decision           = false;
int      g_decision_month_key      = 0;
datetime g_decision_bar_time       = 0;
int      g_decision_label_offset   = 0;
bool     g_signal_valid            = false;
int      g_signal_direction        = 0;
double   g_prior_month_return      = 0.0;
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
   if(year < 1900)
      return 0;
   return year * 100 + month;
  }

int Strategy_DayOfWeekForTime(const datetime value)
  {
   if(value <= 0)
      return -1;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return -1;
   return parts.day_of_week;
  }

int Strategy_DayOfMonthForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   return parts.day;
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
      return ((type == POSITION_TYPE_BUY || type == POSITION_TYPE_SELL) &&
              opened > 0 && opened <= TimeCurrent() &&
              volume > 0.0 && MathIsValidNumber(volume) &&
              open_price > 0.0 && MathIsValidNumber(open_price));
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

   // Tester globals can outlive a later historical run. Remove malformed or
   // future state so the deterministic replay can establish its own ledger.
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
   g_signal_valid = false;
   g_signal_direction = 0;
   g_prior_month_return = 0.0;
   g_signal_state = "idle";
  }

void Strategy_DetectDecisionClock_OnNewBar()
  {
   Strategy_ResetDecisionState();

   MqlRates current_bar;
   MqlRates prior_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 1, prior_bar) ||
      current_bar.time <= 0 || prior_bar.time <= 0 ||
      prior_bar.time >= current_bar.time)
      return;

   const datetime broker_now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(current_bar.time, broker_now);
   if(label_offset < 0)
      return;

   const datetime normalized_current =
      Strategy_NormalizedLabel(current_bar.time, label_offset);
   const datetime normalized_prior =
      Strategy_NormalizedLabel(prior_bar.time, label_offset);
   const int current_month_key =
      Strategy_MonthKeyForTime(normalized_current);
   if(current_month_key <= 0 ||
      current_month_key != Strategy_MonthKeyForTime(broker_now) ||
      Strategy_DateKeyForTime(normalized_current) !=
         Strategy_DateKeyForTime(broker_now) ||
      normalized_prior <= 0 || normalized_prior >= normalized_current ||
      Strategy_DayOfWeekForTime(normalized_current) != strategy_entry_dow ||
      Strategy_DayOfMonthForTime(normalized_current) < 1 ||
      Strategy_DayOfMonthForTime(normalized_current) >
         strategy_first_week_last_dom ||
      Strategy_DayOfWeekForTime(normalized_prior) != 2)
      return;

   g_decision_bar = true;
   g_decision_month_key = current_month_key;
   g_decision_bar_time = current_bar.time;
   g_decision_label_offset = label_offset;
   g_late_decision =
      !Strategy_EntryWithinGrace(current_bar.time, broker_now);
  }

bool Strategy_LoadPriorMonthSignal(const int current_month_key,
                                   const int label_offset,
                                   int &direction,
                                   double &prior_month_return)
  {
   direction = 0;
   prior_month_return = 0.0;
   if(current_month_key <= 0 || strategy_return_months != 1 ||
      (label_offset != 0 && label_offset != 86400))
      return false;

   const int prior_month_key =
      Strategy_PreviousMonthKey(current_month_key);
   const int prior_prior_month_key =
      Strategy_PreviousMonthKey(prior_month_key);
   if(prior_month_key <= 0 || prior_prior_month_key <= 0 ||
      Strategy_NextMonthKey(prior_month_key) != current_month_key ||
      Strategy_NextMonthKey(prior_prior_month_key) != prior_month_key)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, // perf-allowed: bounded completed-month endpoint scan behind the sole QM_IsNewBar branch.
                                PERIOD_D1,
                                1,
                                strategy_history_bars,
                                bars);
   if(copied < 2)
      return false;

   bool found_prior = false;
   bool found_prior_prior = false;
   double prior_month_end = 0.0;
   double prior_prior_month_end = 0.0;
   datetime prior_month_end_time = 0;
   datetime prior_prior_month_end_time = 0;

   for(int index = 0; index < copied; ++index)
     {
      if(bars[index].time <= 0 ||
         (index > 0 && bars[index - 1].time <= bars[index].time))
         return false;

      const datetime normalized =
         Strategy_NormalizedLabel(bars[index].time, label_offset);
      const int month_key = Strategy_MonthKeyForTime(normalized);
      if(month_key <= 0)
         return false;

      if(month_key == current_month_key)
        {
         if(found_prior || found_prior_prior)
            return false;
         continue;
        }
      if(month_key == prior_month_key)
        {
         if(found_prior_prior)
            return false;
         if(!found_prior)
           {
            prior_month_end = bars[index].close;
            prior_month_end_time = bars[index].time;
            found_prior = true;
           }
         continue;
        }
      if(month_key == prior_prior_month_key)
        {
         if(!found_prior)
            return false;
         prior_prior_month_end = bars[index].close;
         prior_prior_month_end_time = bars[index].time;
         found_prior_prior = true;
         break;
        }

      // Encountering any other month before both endpoints proves that the
      // expected consecutive month is absent; do not bridge a history gap.
      return false;
     }

   if(!found_prior || !found_prior_prior ||
      prior_month_end_time <= prior_prior_month_end_time ||
      prior_month_end <= 0.0 || prior_prior_month_end <= 0.0 ||
      !MathIsValidNumber(prior_month_end) ||
      !MathIsValidNumber(prior_prior_month_end))
      return false;

   prior_month_return =
      MathLog(prior_month_end / prior_prior_month_end);
   if(!MathIsValidNumber(prior_month_return))
      return false;

   if(prior_month_return > 0.0)
      direction = 1;
   else if(prior_month_return < 0.0)
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

   // Consume before endpoint validation, signal, news, spread, quote, ATR,
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
          Strategy_LoadPriorMonthSignal(g_decision_month_key,
                                        g_decision_label_offset,
                                        g_signal_direction,
                                        g_prior_month_return);
       if(!g_signal_valid)
          g_signal_state = "endpoint_validation_failed";
       else if(g_signal_direction > 0)
          g_signal_state = "prior_month_positive_long";
       else if(g_signal_direction < 0)
          g_signal_state = "prior_month_negative_short";
       else if(g_prior_month_return == 0.0)
          g_signal_state = "exact_zero_flat";
       else
          g_signal_state = "invalid_direction_flat";
      }

   QM_LogEvent(QM_INFO,
               "MONTHLY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"label_offset_seconds\":%d,\"late\":%s,\"valid\":%s,\"signal\":%d,\"prior_month_return\":%.12e,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            g_decision_label_offset,
                            g_late_decision ? "true" : "false",
                            g_signal_valid ? "true" : "false",
                            g_signal_direction,
                            g_prior_month_return,
                            g_signal_state));
  }

// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41024 ||
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
   if(!qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21 ||
      MathAbs(qm_stress_reject_probability) > 1.0e-12)
      return true;
   if(strategy_entry_dow != 3 ||
      strategy_first_week_last_dom != 7 ||
      strategy_return_months != 1 ||
      strategy_hold_bars != 1 ||
      strategy_entry_grace_minutes != 180 ||
      strategy_history_bars != 100 ||
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.0) > 1.0e-12 ||
      strategy_max_hold_days != 5 ||
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
   req.reason = "QM5_41024_WTI_1WED_MOM1";
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
      ? "WTI_1WED_MOM1_LONG"
      : "WTI_1WED_MOM1_SHORT";

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
   const int current_date_key =
      Strategy_DateKeyForTime(normalized_current);
   const int opened_date_key = Strategy_DateKeyForTime(opened);
   if(label_offset < 0 || current_date_key <= 0 ||
      opened_date_key <= 0 || opened <= 0 || opened > now)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }

   // The normalized WTI label and the broker position time share the same
   // calendar date on entry. Any later D1 label is the exact one-bar exit.
   if(current_date_key != opened_date_key)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_TIME_STOP);
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
      !Strategy_IsHostChart() || qm_ea_id != 41024 ||
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
      StringFormat("QM5_41024_1WED_ATTEMPT_%d", QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_strategy_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41024\",\"ea\":\"wti-1wed-mom1\"}");
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

   // Lifecycle repair and the exact next-D1 close precede entry-only gates
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
