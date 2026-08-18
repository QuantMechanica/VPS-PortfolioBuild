#property strict
#property version   "5.0"
#property description "QM5_41061 WTI Completed-Week NR7 Expansion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41061 - WTI Completed-Week NR7 Expansion
// -----------------------------------------------------------------------------
// Normalize the broker's energy D1 labels, form exact Monday-Friday weeks,
// and require the immediately prior week to be the strict narrowest of seven
// valid complete weeks.  A completed close in the following week beyond that
// week's full high-low range enters in the expansion direction.  The position
// is fixed-risk, hard-stopped, and flat by Friday 21 broker time.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41061;
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
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_week_lookback        = 7;
input int    strategy_history_bars         = 90;
input int    strategy_entry_min_dow        = 2;
input int    strategy_entry_max_dow        = 5;
input int    strategy_entry_grace_minutes  = 180;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_max_hold_days        = 8;
input int    strategy_max_spread_points    = 1500;

const string g_symbol = "XTIUSD.DWX";

bool     g_is_new_d1_bar          = false;
datetime g_current_raw_bar        = 0;
datetime g_current_normalized_bar = 0;
datetime g_latest_completed_raw   = 0;
int      g_label_offset_seconds   = -1;
int      g_signal_week_key        = 0;
int      g_last_attempt_week_key  = 0;
string   g_attempt_state_key      = "";

// -----------------------------------------------------------------------------
// Calendar and normalized-label helpers.
// -----------------------------------------------------------------------------

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts) ||
      parts.year < 1900 || parts.mon < 1 || parts.mon > 12 ||
      parts.day < 1 || parts.day > 31)
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return -1;
   return parts.day_of_week;
  }

datetime Strategy_Monday(const datetime value)
  {
   const int day = Strategy_DayOfWeek(value);
   if(day < 0)
      return 0;
   const int days_since_monday = (day + 6) % 7;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   const datetime midnight = StructToTime(parts);
   if(midnight <= 0)
      return 0;
   return midnight - (datetime)(days_since_monday * 86400);
  }

int Strategy_WeekKey(const datetime value)
  {
   return Strategy_DayKey(Strategy_Monday(value));
  }

datetime Strategy_NormalizedLabel(const datetime raw_label,
                                  const int label_offset)
  {
   if(raw_label <= 0 || (label_offset != 0 && label_offset != 86400))
      return 0;
   return raw_label + (datetime)label_offset;
  }

int Strategy_LabelOffsetSeconds(const datetime current_raw,
                                const datetime broker_now)
  {
   if(current_raw <= 0 || broker_now < current_raw)
      return -1;
   const int raw_date = Strategy_DayKey(current_raw);
   const int broker_date = Strategy_DayKey(broker_now);
   if(raw_date <= 0 || broker_date <= 0)
      return -1;
   if(raw_date == broker_date)
      return 0;
   if(Strategy_DayKey(current_raw + (datetime)86400) == broker_date)
      return 86400;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_symbol && _Period == PERIOD_D1 &&
           qm_magic_slot_offset == 0);
  }

// -----------------------------------------------------------------------------
// Ownership, attempt state, and lifecycle.
// -----------------------------------------------------------------------------

long Strategy_Magic()
  {
   return (long)QM_MagicChecked(qm_ea_id, 0, g_symbol);
  }

bool Strategy_IsOwnedPosition()
  {
   return (PositionGetInteger(POSITION_MAGIC) == Strategy_Magic());
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

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_41061_WTI_WEEKNR7_ATTEMPT_%I64d",
                       Strategy_Magic());
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_week_key = 0;
   const int current_date = Strategy_DayKey(reference_time);
   if(current_date <= 0 || g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_date = (int)MathRound(stored);
   if(MathIsValidNumber(stored) && stored_date >= 19000101 &&
      stored_date <= current_date)
     {
      g_last_attempt_week_key = stored_date;
      return;
     }

   // Tester globals can survive a later historical run.  Never let a future
   // or malformed marker suppress a deterministic replay.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const int week_key)
  {
   if(week_key <= 0)
      return false;
   if(g_attempt_state_key == "")
      g_attempt_state_key = Strategy_AttemptStateKey();

   // Fail closed in-process even if terminal persistence itself fails.
   g_last_attempt_week_key = week_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)week_key) > 0);
  }

bool Strategy_WeekHasOwnedEntry(const int week_key,
                                const datetime broker_now)
  {
   if(week_key <= 0 || broker_now <= 0)
      return true;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;
      if(Strategy_WeekKey(
            (datetime)PositionGetInteger(POSITION_TIME)) == week_key)
         return true;
     }

   const datetime history_start = broker_now - (datetime)(10 * 86400);
   if(history_start <= 0 || !HistorySelect(history_start, broker_now))
      return true;
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0 ||
         HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != Strategy_Magic() ||
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != g_symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      if(Strategy_WeekKey(
            (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME)) ==
         week_key)
         return true;
     }
   return false;
  }

bool Strategy_FridayExitReached(const datetime broker_now)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(broker_now <= 0 || !TimeToStruct(broker_now, parts))
      return false;
   return (parts.day_of_week == 5 &&
           parts.hour >= qm_friday_close_hour_broker);
  }

void Strategy_RepairAndManageOwnedPositions()
  {
   const int owned_count = Strategy_OwnedPositionCount();
   if(owned_count <= 0)
      return;

   const datetime broker_now = TimeCurrent();
   const int current_week = Strategy_WeekKey(broker_now);
   const long max_hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400L;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsOwnedPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const int opened_week = Strategy_WeekKey(opened);

      bool malformed =
         (owned_count != 1 || symbol != g_symbol ||
          (type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL) ||
          opened <= 0 || opened > broker_now || opened_week <= 0 ||
          volume <= 0.0 || !MathIsValidNumber(volume) ||
          open_price <= 0.0 || !MathIsValidNumber(open_price) ||
          stop_price <= 0.0 || !MathIsValidNumber(stop_price));
      if(malformed)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }
      if(Strategy_FridayExitReached(broker_now))
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_FRIDAY_CLOSE);
         continue;
        }
      if(current_week <= 0 || current_week != opened_week)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }
      if((long)(broker_now - opened) >= max_hold_seconds)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

// -----------------------------------------------------------------------------
// Exact decision clock and weekly NR7 state.
// -----------------------------------------------------------------------------

void Strategy_ResetDecisionState()
  {
   g_current_normalized_bar = 0;
   g_latest_completed_raw = 0;
   g_label_offset_seconds = -1;
   g_signal_week_key = 0;
  }

bool Strategy_DecisionClockReady()
  {
   Strategy_ResetDecisionState();
   if(!g_is_new_d1_bar || g_current_raw_bar <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(g_current_raw_bar, broker_now);
   const datetime normalized_current =
      Strategy_NormalizedLabel(g_current_raw_bar, label_offset);
   if(label_offset < 0 || normalized_current <= 0 ||
      Strategy_DayKey(normalized_current) != Strategy_DayKey(broker_now))
      return false;

   const long elapsed = (long)(broker_now - g_current_raw_bar);
   if(elapsed < 0L ||
      elapsed > (long)strategy_entry_grace_minutes * 60L)
      return false;

   const int decision_day = Strategy_DayOfWeek(normalized_current);
   if(decision_day < strategy_entry_min_dow ||
      decision_day > strategy_entry_max_dow)
      return false;

   MqlRates completed;
   ZeroMemory(completed);
   if(!QM_ReadBar(g_symbol, PERIOD_D1, 1, completed))
      return false;
   const datetime normalized_completed =
      Strategy_NormalizedLabel(completed.time, label_offset);
   if(normalized_completed <= 0 ||
      Strategy_DayKey(normalized_completed) !=
         Strategy_DayKey(normalized_current - (datetime)86400) ||
      Strategy_WeekKey(normalized_completed) !=
         Strategy_WeekKey(normalized_current))
      return false;

   const int week_key = Strategy_WeekKey(normalized_current);
   if(week_key <= 0 || week_key == g_last_attempt_week_key ||
      Strategy_WeekHasOwnedEntry(week_key, broker_now))
      return false;

   g_current_normalized_bar = normalized_current;
   g_latest_completed_raw = completed.time;
   g_label_offset_seconds = label_offset;
   g_signal_week_key = week_key;
   return true;
  }

bool Strategy_LoadWeeklyNr7(double &prior_low,
                            double &prior_high,
                            double &prior_range,
                            double &latest_close,
                            int &direction)
  {
   prior_low = 0.0;
   prior_high = 0.0;
   prior_range = 0.0;
   latest_close = 0.0;
   direction = 0;
   if(g_current_normalized_bar <= 0 || g_latest_completed_raw <= 0 ||
      g_signal_week_key <= 0 ||
      (g_label_offset_seconds != 0 && g_label_offset_seconds != 86400))
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied =
      CopyRates(g_symbol,       // perf-allowed: one bounded entry-only scan.
                PERIOD_D1,
                1,
                strategy_history_bars,
                rates);
   if(copied != strategy_history_bars || rates[0].time <= 0 ||
      rates[0].time != g_latest_completed_raw)
      return false;

   const datetime latest_normalized =
      Strategy_NormalizedLabel(rates[0].time, g_label_offset_seconds);
   if(Strategy_WeekKey(latest_normalized) != g_signal_week_key ||
      Strategy_DayKey(latest_normalized) !=
         Strategy_DayKey(g_current_normalized_bar - (datetime)86400) ||
      rates[0].close <= 0.0 || !MathIsValidNumber(rates[0].close))
      return false;
   latest_close = rates[0].close;

   const int prior_week =
      Strategy_WeekKey(g_current_normalized_bar - (datetime)(7 * 86400));
   if(prior_week <= 0)
      return false;

   const int MAX_WEEK_GROUPS = 32;
   int week_keys[32];
   int week_counts[32];
   int week_masks[32];
   bool week_invalid[32];
   double week_lows[32];
   double week_highs[32];
   int group_count = 0;

   for(int index = 0; index < copied; ++index)
     {
      const MqlRates bar = rates[index];
      const datetime normalized =
         Strategy_NormalizedLabel(bar.time, g_label_offset_seconds);
      if(normalized <= 0 || bar.high <= 0.0 || bar.low <= 0.0 ||
         bar.close <= 0.0 || !MathIsValidNumber(bar.high) ||
         !MathIsValidNumber(bar.low) ||
         !MathIsValidNumber(bar.close) || bar.high < bar.low)
         return false;

      const int week_key = Strategy_WeekKey(normalized);
      if(week_key <= 0)
         return false;
      if(week_key == g_signal_week_key)
         continue;

      int group = -1;
      for(int probe = 0; probe < group_count; ++probe)
        {
         if(week_keys[probe] == week_key)
           {
            group = probe;
            break;
           }
        }
      if(group < 0)
        {
         if(group_count >= MAX_WEEK_GROUPS)
            return false;
         group = group_count++;
         week_keys[group] = week_key;
         week_counts[group] = 0;
         week_masks[group] = 0;
         week_invalid[group] = false;
         week_lows[group] = bar.low;
         week_highs[group] = bar.high;
        }

      const int day = Strategy_DayOfWeek(normalized);
      if(day < 1 || day > 5)
        {
         week_invalid[group] = true;
         continue;
        }
      const int day_bit = (1 << day);
      if((week_masks[group] & day_bit) != 0)
        {
         week_invalid[group] = true;
         continue;
        }
      week_masks[group] |= day_bit;
      ++week_counts[group];
      week_lows[group] = MathMin(week_lows[group], bar.low);
      week_highs[group] = MathMax(week_highs[group], bar.high);
     }

   const int COMPLETE_WEEK_MASK = 62;
   if(group_count <= 0 || week_keys[0] != prior_week ||
      week_invalid[0] || week_counts[0] != 5 ||
      week_masks[0] != COMPLETE_WEEK_MASK)
      return false;

   prior_low = week_lows[0];
   prior_high = week_highs[0];
   prior_range = prior_high - prior_low;
   if(prior_low <= 0.0 || prior_high <= 0.0 || prior_range <= 0.0 ||
      !MathIsValidNumber(prior_range))
      return false;

   int selected_weeks = 1;
   for(int group = 1;
       group < group_count && selected_weeks < strategy_week_lookback;
       ++group)
     {
      if(week_invalid[group] || week_counts[group] != 5 ||
         week_masks[group] != COMPLETE_WEEK_MASK)
         continue;
      const double older_range = week_highs[group] - week_lows[group];
      if(week_lows[group] <= 0.0 || week_highs[group] <= 0.0 ||
         older_range <= 0.0 || !MathIsValidNumber(older_range))
         continue;
      if(!(prior_range < older_range))
         return false;
      ++selected_weeks;
     }
   if(selected_weeks != strategy_week_lookback)
      return false;

   if(latest_close > prior_high)
      direction = 1;
   else if(latest_close < prior_low)
      direction = -1;
   return true;
  }

// -----------------------------------------------------------------------------
// Five V5 strategy hooks.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
     {
      PrintFormat("QM_INPUT_REJECT predicate=host_chart observed_symbol='%s' observed_period=%d required_symbol='XTIUSD.DWX' required_period=%d",
                  _Symbol, (int)_Period, (int)PERIOD_D1);
      return true;
     }

   if(!QM_InputRequireLong("qm_ea_id", qm_ea_id, 41061) ||
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
      !QM_InputRequireLong("qm_friday_close_enabled", qm_friday_close_enabled, true) ||
      !QM_InputRequireLong("qm_friday_close_hour_broker", qm_friday_close_hour_broker, 21) ||
      !QM_InputRequireDouble("qm_stress_reject_probability", qm_stress_reject_probability, 0.0, 1.0e-12) ||
      !QM_InputRequireLong("strategy_week_lookback", strategy_week_lookback, 7) ||
      !QM_InputRequireLong("strategy_history_bars", strategy_history_bars, 90) ||
      !QM_InputRequireLong("strategy_entry_min_dow", strategy_entry_min_dow, 2) ||
      !QM_InputRequireLong("strategy_entry_max_dow", strategy_entry_max_dow, 5) ||
      !QM_InputRequireLong("strategy_entry_grace_minutes", strategy_entry_grace_minutes, 180) ||
      !QM_InputRequireLong("strategy_atr_period_d1", strategy_atr_period_d1, 20) ||
      !QM_InputRequireDouble("strategy_atr_sl_mult", strategy_atr_sl_mult, 3.5, 1.0e-12) ||
      !QM_InputRequireLong("strategy_max_hold_days", strategy_max_hold_days, 8) ||
      !QM_InputRequireLong("strategy_max_spread_points", strategy_max_spread_points, 1500))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   ZeroMemory(request);
   request.type = QM_BUY;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "WTI_WEEKNR7";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(g_signal_week_key <= 0 ||
      g_signal_week_key == g_last_attempt_week_key ||
      Strategy_OwnedPositionCount() > 0)
      return false;

   double prior_low = 0.0;
   double prior_high = 0.0;
   double prior_range = 0.0;
   double latest_close = 0.0;
   int direction = 0;
   if(!Strategy_LoadWeeklyNr7(prior_low,
                              prior_high,
                              prior_range,
                              latest_close,
                              direction) ||
      direction == 0)
      return false;

   // The signal is fully known.  Consume this broker week before spread,
   // quote, ATR, sizing, news, or order submission can fail.
   if(!Strategy_RecordAttemptState(g_signal_week_key))
      return false;

   request.type = (direction > 0) ? QM_BUY : QM_SELL;
   request.reason = (direction > 0)
                    ? "WTI_WEEKNR7_LONG" : "WTI_WEEKNR7_SHORT";

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"week\":%d,\"label_offset_seconds\":%d,\"prior_low\":%.12e,\"prior_high\":%.12e,\"prior_range\":%.12e,\"latest_completed_close\":%.12e,\"direction\":%d}",
                            g_signal_week_key,
                            g_label_offset_seconds,
                            prior_low,
                            prior_high,
                            prior_range,
                            latest_close,
                            direction));

   const long spread_points = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      spread_points > strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(g_symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   const double entry_price = QM_EntryMarketPrice(request.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   request.sl = QM_StopATRFromValue(g_symbol,
                                    request.type,
                                    entry_price,
                                    atr_last,
                                    strategy_atr_sl_mult);
   request.sl = QM_StopRulesNormalizePrice(g_symbol, request.sl);
   if(request.sl <= 0.0 || !MathIsValidNumber(request.sl) ||
      (request.type == QM_BUY && request.sl >= entry_price) ||
      (request.type == QM_SELL && request.sl <= entry_price))
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_RepairAndManageOwnedPositions();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

bool Strategy_PrimeLateSignalAttach()
  {
   const datetime broker_now = TimeCurrent();
   const int label_offset =
      Strategy_LabelOffsetSeconds(g_current_raw_bar, broker_now);
   const datetime normalized_current =
      Strategy_NormalizedLabel(g_current_raw_bar, label_offset);
   const int day = Strategy_DayOfWeek(normalized_current);
   const long elapsed = (long)(broker_now - g_current_raw_bar);
   if(label_offset < 0 || day < strategy_entry_min_dow ||
      day > strategy_entry_max_dow || elapsed < 0L ||
      elapsed > (long)strategy_entry_grace_minutes * 60L)
     {
      // A late attachment must not backfill the current D1 bar.  A later bar
      // in the week can still present its own completed-close observation.
      QM_IsNewBar(g_symbol, PERIOD_D1);
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Framework wiring - canonical V5 lifecycle.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!SymbolSelect(g_symbol, true) || !Strategy_IsHostChart() ||
      qm_ea_id != 41061 || qm_magic_slot_offset != 0)
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
         QM_FRIDAY_CLOSE_CARD_RULE,
         "Approved WTI completed-week NR7 expansion is flat Friday 21"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   if(Strategy_NoTradeFilter() || Strategy_Magic() <= 0 ||
      Strategy_Magic() != (long)QM_FrameworkMagic())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars +
                          strategy_atr_period_d1 + 10);

   g_current_raw_bar =
      iTime(g_symbol, PERIOD_D1, 0); // perf-allowed: restart anchor.
   Strategy_LoadAttemptState(TimeCurrent());
   if(!Strategy_PrimeLateSignalAttach())
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41061\",\"ea\":\"wti-week-nr7-brk\"}");
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

   g_is_new_d1_bar = QM_IsNewBar(g_symbol, PERIOD_D1);
   if(g_is_new_d1_bar || g_current_raw_bar <= 0)
     {
      g_current_raw_bar =
         iTime(g_symbol, PERIOD_D1, 0); // perf-allowed: new-bar anchor.
      if(g_is_new_d1_bar)
         QM_EquityStreamOnNewBar();
     }

   // Lifecycle repair remains reachable on every tick before entry-only
   // history, spread, news, and execution gates.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   if(Strategy_OwnedPositionCount() > 0 || !g_is_new_d1_bar ||
      Strategy_NoTradeFilter() || !Strategy_DecisionClockReady())
      return;

   QM_EntryRequest request;
   ZeroMemory(request);
   if(!Strategy_EntrySignal(request))
      return;

   // Attempt state is already durable before this intentionally disabled
   // news surface and before order submission.
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(g_symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(g_symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   ulong out_ticket = 0;
   QM_TM_OpenPosition(request, out_ticket);
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
