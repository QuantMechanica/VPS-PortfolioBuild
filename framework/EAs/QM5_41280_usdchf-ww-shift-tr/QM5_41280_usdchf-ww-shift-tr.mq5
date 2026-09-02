#property strict
#property version   "5.0"
#property description "QM5_41280 USDCHF Weekly Mann-Whitney Location-Shift Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41280 - USDCHF Weekly Mann-Whitney Location-Shift Trend
// -----------------------------------------------------------------------------
// At most once per framework broker week:
//   - consume the week before every fallible entry gate
//   - read exactly twelve completed USDCHF D1 closes, oldest to newest
//   - split six older / six newer and count every strict cross-block pair
//   - continue at U_new >= 24 (long) or U_new <= 12 (short)
//   - attach a frozen 3.0 * ATR(20,D1) hard stop and no target
//   - flatten through the framework Friday close; seven days is stale repair
// Runtime uses native MT5/framework state only. No ML or external feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 41280;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal        = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_NONE;
input int                       qm_news_stale_max_hours = 336;
input string                    qm_news_min_impact      = "high";
input QM_NewsMode               qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_endpoint_count       = 12;
input int    strategy_block_size           = 6;
input int    strategy_u_lower              = 12;
input int    strategy_u_upper              = 24;
input int    strategy_history_bars_d1      = 128;
input int    strategy_entry_window_minutes = 360;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 7;
input int    strategy_max_spread_points    = 50;
input int    strategy_deviation_points     = 20;

struct Strategy_SignalMetrics
  {
   int    endpoint_count;
   int    block_size;
   int    u_new;
   int    u_old;
   int    newer_rank_sum;
   int    direction;
   double oldest_close;
   double newest_close;
   string older_path;
   string newer_path;
  };

const string g_symbol = "USDCHF.DWX";

int                    g_last_attempt_week_key = 0;
string                 g_attempt_state_key = "";
bool                   g_decision_bar = false;
bool                   g_late_decision = false;
int                    g_decision_week_key = 0;
datetime               g_decision_bar_time = 0;
bool                   g_signal_valid = false;
datetime               g_oldest_endpoint_time = 0;
datetime               g_newest_endpoint_time = 0;
string                 g_signal_state = "idle";
Strategy_SignalMetrics g_signal_metrics;

bool Strategy_IsExpectedHost()
  {
   return (_Symbol == g_symbol && _Period == PERIOD_D1);
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

bool Strategy_PositionEntryDealMatchesSide(const ulong position_id,
                                           const ENUM_POSITION_TYPE type)
  {
   if(position_id == 0 || !HistorySelectByPosition(position_id))
      return false;
   const int magic = QM_FrameworkMagic();
   bool found_entry = false;
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
      if((type == POSITION_TYPE_BUY && deal_type != DEAL_TYPE_BUY) ||
         (type == POSITION_TYPE_SELL && deal_type != DEAL_TYPE_SELL))
         return false;
      found_entry = true;
     }
   return found_entry;
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
      const ulong position_id =
         (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const double take_profit = PositionGetDouble(POSITION_TP);
      if((type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL) ||
         opened <= 0 || opened > TimeCurrent() ||
         volume <= 0.0 || !MathIsValidNumber(volume) ||
         open_price <= 0.0 || !MathIsValidNumber(open_price) ||
         stop_price <= 0.0 || !MathIsValidNumber(stop_price) ||
         take_profit != 0.0 || !MathIsValidNumber(take_profit))
         return false;
      if((type == POSITION_TYPE_BUY && stop_price >= open_price) ||
         (type == POSITION_TYPE_SELL && stop_price <= open_price))
         return false;
      return Strategy_PositionEntryDealMatchesSide(position_id, type);
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
   const long spread_points = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);
   return (spread_points >= 0 &&
           spread_points <= strategy_max_spread_points);
  }

int Strategy_WeekKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   const int shift = iBarShift(g_symbol, PERIOD_D1, value, false);
   if(shift < 0)
      return 0;
   return QM_CalendarPeriodKey(PERIOD_W1, g_symbol, shift);
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
   const datetime history_start = now - (long)21 * 86400L;
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
      if(Strategy_WeekKeyForTime(deal_time) == week_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState()
  {
   g_last_attempt_week_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;
   const int current_week_key =
      QM_CalendarPeriodKey(PERIOD_W1, g_symbol, 0);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_week_key = (int)MathRound(stored);
   if(current_week_key > 0 && MathIsValidNumber(stored) &&
      stored_week_key >= 1900000 &&
      stored_week_key <= current_week_key)
     {
      g_last_attempt_week_key = stored_week_key;
      return;
     }
   // A tester global from a future/prior historical run must not suppress the
   // current run. No valid current-or-past marker is cleared.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordWeekAttempt(const int week_key)
  {
   if(week_key <= 0 || g_attempt_state_key == "")
      return false;
   // Stay fail-closed in-process even if terminal persistence fails.
   g_last_attempt_week_key = week_key;
   if(GlobalVariableSet(g_attempt_state_key, (double)week_key) <= 0)
      return false;
   GlobalVariablesFlush();
   return true;
  }

bool Strategy_EntryWithinGrace(const datetime current_bar_time,
                               const datetime broker_now)
  {
   if(current_bar_time <= 0 || broker_now < current_bar_time)
      return false;
   const long elapsed = (long)(broker_now - current_bar_time);
   return (elapsed <=
           (long)strategy_entry_window_minutes * 60L);
  }

bool Strategy_LoadCompletedCloses(double &closes[],
                                  datetime &endpoint_times[])
  {
   if(strategy_endpoint_count != 12 ||
      strategy_block_size != 6 ||
      strategy_endpoint_count != 2 * strategy_block_size)
      return false;
   ArrayResize(closes, strategy_endpoint_count);
   ArrayResize(endpoint_times, strategy_endpoint_count);

   for(int index = 0; index < strategy_endpoint_count; ++index)
     {
      // Chronological output: shift 12 is oldest and shift 1 is newest.
      const int shift = strategy_endpoint_count - index;
      MqlRates bar;
      ZeroMemory(bar);
      if(shift <= 0 ||
         !QM_ReadBar(g_symbol, PERIOD_D1, shift, bar) ||
         bar.time <= 0 || bar.close <= 0.0 ||
         !MathIsValidNumber(bar.close))
         return false;
      closes[index] = bar.close;
      endpoint_times[index] = bar.time;
      if(index > 0 &&
         endpoint_times[index] <= endpoint_times[index - 1])
         return false;
     }

   for(int left = 0; left < strategy_endpoint_count; ++left)
     {
      for(int right = left + 1;
          right < strategy_endpoint_count;
          ++right)
        {
         if(endpoint_times[left] == endpoint_times[right] ||
            closes[left] == closes[right])
            return false;
        }
     }
   return true;
  }

bool Strategy_MannWhitneySignal(const double &closes[],
                                Strategy_SignalMetrics &metrics)
  {
   ZeroMemory(metrics);
   metrics.older_path = "";
   metrics.newer_path = "";
   metrics.endpoint_count = ArraySize(closes);
   metrics.block_size = strategy_block_size;

   if(strategy_endpoint_count != 12 ||
      strategy_block_size != 6 ||
      strategy_u_lower != 12 ||
      strategy_u_upper != 24 ||
      metrics.endpoint_count != strategy_endpoint_count ||
      strategy_endpoint_count != 2 * strategy_block_size)
      return false;

   for(int index = 0; index < strategy_endpoint_count; ++index)
     {
      if(closes[index] <= 0.0 || !MathIsValidNumber(closes[index]))
         return false;
      for(int other = index + 1;
          other < strategy_endpoint_count;
          ++other)
        {
         if(closes[index] == closes[other])
            return false;
        }

      if(index < strategy_block_size)
        {
         if(StringLen(metrics.older_path) > 0)
            metrics.older_path += ",";
         metrics.older_path += DoubleToString(closes[index], 10);
        }
      else
        {
         if(StringLen(metrics.newer_path) > 0)
            metrics.newer_path += ",";
         metrics.newer_path += DoubleToString(closes[index], 10);
        }
     }

   metrics.u_new = 0;
   metrics.u_old = 0;
   metrics.newer_rank_sum = 0;
   for(int newer = strategy_block_size;
       newer < strategy_endpoint_count;
       ++newer)
     {
      int combined_rank = 1;
      for(int other = 0; other < strategy_endpoint_count; ++other)
        {
         if(closes[other] < closes[newer])
            ++combined_rank;
        }
      if(combined_rank < 1 ||
         combined_rank > strategy_endpoint_count)
         return false;
      metrics.newer_rank_sum += combined_rank;

      for(int older = 0; older < strategy_block_size; ++older)
        {
         if(closes[newer] > closes[older])
            ++metrics.u_new;
         else if(closes[older] > closes[newer])
            ++metrics.u_old;
         else
            return false;
        }
     }

   const int pair_count = strategy_block_size * strategy_block_size;
   const int minimum_rank_sum =
      strategy_block_size * (strategy_block_size + 1) / 2;
   if(metrics.u_new < 0 || metrics.u_new > pair_count ||
      metrics.u_old < 0 || metrics.u_old > pair_count ||
      metrics.u_new + metrics.u_old != pair_count ||
      metrics.newer_rank_sum < minimum_rank_sum ||
      metrics.newer_rank_sum > minimum_rank_sum + pair_count ||
      metrics.newer_rank_sum - minimum_rank_sum != metrics.u_new ||
      StringLen(metrics.older_path) <= 0 ||
      StringLen(metrics.newer_path) <= 0)
      return false;

   metrics.oldest_close = closes[0];
   metrics.newest_close =
      closes[strategy_endpoint_count - 1];
   metrics.direction = 0;
   if(metrics.u_new >= strategy_u_upper)
      metrics.direction = 1;
   else if(metrics.u_new <= strategy_u_lower)
      metrics.direction = -1;
   return true;
  }

void Strategy_ResetDecisionState()
  {
   g_decision_bar = false;
   g_late_decision = false;
   g_decision_week_key = 0;
   g_decision_bar_time = 0;
   g_signal_valid = false;
   g_oldest_endpoint_time = 0;
   g_newest_endpoint_time = 0;
   g_signal_state = "idle";
   ZeroMemory(g_signal_metrics);
  }

void Strategy_PrepareWeeklySignal()
  {
   Strategy_ResetDecisionState();
   MqlRates current_bar;
   ZeroMemory(current_bar);
   if(!QM_ReadBar(g_symbol, PERIOD_D1, 0, current_bar) ||
      current_bar.time <= 0)
     {
      g_signal_state = "current_bar_invalid";
      return;
     }

   const int current_week_key =
      QM_CalendarPeriodKey(PERIOD_W1, g_symbol, 0);
   const int preceding_bar_week_key =
      QM_CalendarPeriodKey(PERIOD_W1, g_symbol, 1);
   if(current_week_key <= 0 || preceding_bar_week_key <= 0)
     {
      g_signal_state = "week_key_invalid";
      return;
     }
   if(current_week_key == g_last_attempt_week_key)
     {
      g_signal_state = "week_already_consumed";
      return;
     }

   // Consume before history, signal, news, spread, quote, ATR, sizing, margin,
   // or order checks. A flat or rejected state cannot retry this week.
   if(!Strategy_RecordWeekAttempt(current_week_key))
     {
      g_signal_state = "attempt_persist_failed";
      return;
     }

   g_decision_bar = true;
   g_decision_week_key = current_week_key;
   g_decision_bar_time = current_bar.time;
   const datetime broker_now = TimeCurrent();
   const bool genuine_transition =
      (current_week_key != preceding_bar_week_key);
   g_late_decision =
      (!genuine_transition ||
       !Strategy_EntryWithinGrace(current_bar.time, broker_now));

   if(Strategy_WeekAlreadyEntered(current_week_key))
      g_signal_state = "entry_deal_already_exists";
   else if(g_late_decision)
      g_signal_state = "late_restart_consumed_flat";
   else
     {
      double closes[];
      datetime endpoint_times[];
      const bool endpoints_valid =
         Strategy_LoadCompletedCloses(closes, endpoint_times);
      if(endpoints_valid &&
         ArraySize(endpoint_times) == strategy_endpoint_count)
        {
         g_oldest_endpoint_time = endpoint_times[0];
         g_newest_endpoint_time =
            endpoint_times[strategy_endpoint_count - 1];
        }
      g_signal_valid =
         endpoints_valid &&
         Strategy_MannWhitneySignal(closes, g_signal_metrics);
      if(!g_signal_valid)
         g_signal_state = "mann_whitney_validation_failed";
      else if(g_signal_metrics.direction == 0)
         g_signal_state = "mann_whitney_central_flat";
      else if(g_signal_metrics.direction > 0)
         g_signal_state = "newer_location_dominant_usdchf_long";
      else
         g_signal_state = "newer_location_trailing_usdchf_short";
     }

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_STATE",
      StringFormat(
         "{\"week_key\":%d,\"decision_bar\":%I64d,\"late\":%s,\"valid\":%s,\"direction\":%d,\"endpoint_count\":%d,\"block_size\":%d,\"u_new\":%d,\"u_old\":%d,\"u_complement\":%d,\"newer_rank_sum\":%d,\"older_closes\":\"%s\",\"newer_closes\":\"%s\",\"oldest_endpoint\":%I64d,\"newest_endpoint\":%I64d,\"state\":\"%s\"}",
         g_decision_week_key,
         (long)g_decision_bar_time,
         g_late_decision ? "true" : "false",
         g_signal_valid ? "true" : "false",
         g_signal_metrics.direction,
         g_signal_metrics.endpoint_count,
         g_signal_metrics.block_size,
         g_signal_metrics.u_new,
         g_signal_metrics.u_old,
         g_signal_metrics.u_new + g_signal_metrics.u_old,
         g_signal_metrics.newer_rank_sum,
         g_signal_metrics.older_path,
         g_signal_metrics.newer_path,
         (long)g_oldest_endpoint_time,
         (long)g_newest_endpoint_time,
         g_signal_state));
  }

// -----------------------------------------------------------------------------
// No Trade Filter.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsExpectedHost() ||
      qm_ea_id != 41280 || qm_magic_slot_offset != 0 ||
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
   if(!qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21 ||
      MathAbs(qm_stress_reject_probability) > 0.000000000001)
      return true;
   if(strategy_endpoint_count != 12 ||
      strategy_block_size != 6 ||
      strategy_u_lower != 12 ||
      strategy_u_upper != 24 ||
      strategy_history_bars_d1 != 128 ||
      strategy_entry_window_minutes != 360 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.0) > 0.000000000001 ||
      strategy_max_hold_days != 7 ||
      strategy_max_spread_points != 50 ||
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
   req.reason = "QM5_41280_USDCHF_WEEKLY_MANN_WHITNEY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_decision_bar || g_late_decision ||
      g_decision_week_key <= 0 ||
      g_decision_week_key != g_last_attempt_week_key ||
      !g_signal_valid ||
      (g_signal_metrics.direction != 1 &&
       g_signal_metrics.direction != -1))
      return false;
   if(Strategy_OwnedPositionCount() > 0 ||
      Strategy_WeekAlreadyEntered(g_decision_week_key) ||
      !Strategy_SpreadAllowed())
      return false;

   const double atr_value =
      QM_ATR(g_symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   req.type =
      (g_signal_metrics.direction > 0) ? QM_BUY : QM_SELL;
   req.reason = (g_signal_metrics.direction > 0)
      ? "USDCHF_WEEKLY_MANN_WHITNEY_LOCATION_SHIFT_LONG"
      : "USDCHF_WEEKLY_MANN_WHITNEY_LOCATION_SHIFT_SHORT";
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(g_symbol,
                                req.type,
                                entry_price,
                                atr_value,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(g_symbol, req.sl);
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

   const datetime opened = Strategy_CurrentEntryTime();
   const datetime now = TimeCurrent();
   if(opened <= 0 || opened > now)
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   const long hold_seconds =
      (long)strategy_max_hold_days * 86400L;
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

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!SymbolSelect(g_symbol, true) ||
      !Strategy_IsExpectedHost() ||
      qm_ea_id != 41280 ||
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

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     strategy_deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_D1,
         QM_FRIDAY_CLOSE_CARD_RULE,
         "Approved card mandates Friday close at broker hour 21"))
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
      StringFormat("QM5_41280_WEEK_ATTEMPT_%d",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState();
   Strategy_ResetDecisionState();

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_history_bars_d1);

   QM_LogEvent(
      QM_INFO,
      "INIT_OK",
      "{\"card\":\"QM5_41280\",\"ea\":\"usdchf-ww-shift-tr\",\"signal\":\"weekly_fixed_six_by_six_mann_whitney_location_shift\"}");
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
   // Q08 evidence lifecycle: no guard may skip open-position MAE sampling.
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   // Integrity and stale repair remain reachable before every entry-only gate.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseOwnedPositions(QM_EXIT_STRATEGY);
      return;
     }
   if(Strategy_NoTradeFilter())
      return;

   g_decision_bar = false;
   if(!QM_IsNewBar(g_symbol, PERIOD_D1))
      return;
   QM_EquityStreamOnNewBar();

   // This persists the week before history, signal, news, spread, quote, ATR,
   // sizing, margin, or order checks.
   Strategy_PrepareWeeklySignal();

   // The approved card locks all news modes OFF. Keep the normal framework
   // entry gate so any future non-approved input mutation still fails closed.
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
