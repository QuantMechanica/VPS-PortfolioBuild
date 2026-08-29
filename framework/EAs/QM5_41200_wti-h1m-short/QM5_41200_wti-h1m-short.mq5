#property strict
#property version   "5.0"
#property description "QM5_41200 WTI First-Half-of-Month Short"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41200 - WTI First-Half-of-Month Short
// -----------------------------------------------------------------------------
// Structural D1 crude-oil sleeve:
//   - detect only a genuine normalized broker-month boundary
//   - accept native D1 labels or one uniform +1-calendar-day energy offset
//   - consume one yyyymm attempt before every fallible entry-only gate
//   - sell once, then close on the first later normalized D1 day >= 16
//   - retain a frozen ATR hard stop and a 20-day survivor repair
// Native MT5 calendar/OHLC/state only; no external runtime data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                              = 41200;
input int    qm_magic_slot_offset                  = 0;
input uint   qm_rng_seed                           = 42;

input group "Risk"
input double RISK_PERCENT                          = 0.0;
input double RISK_FIXED                            = 1000.0;
input double PORTFOLIO_WEIGHT                      = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = false;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
input int    strategy_exit_calendar_day            = 16;
input int    strategy_entry_latest_day             = 5;
input int    strategy_boundary_attach_max_minutes  = 180;
input int    strategy_atr_period_d1                 = 20;
input double strategy_atr_sl_mult                   = 2.75;
input int    strategy_max_hold_days                 = 20;
input int    strategy_max_spread_points             = 2500;

const string g_symbol = "XTIUSD.DWX";

int      g_last_attempt_month_key = 0;
string   g_attempt_state_key      = "";
bool     g_strategy_new_d1_bar    = false;
bool     g_current_session_valid  = false;
datetime g_current_session_time   = 0;
int      g_current_month_key      = 0;
int      g_current_calendar_day   = 0;
bool     g_ordinary_exit_due      = false;

bool     g_decision_bar           = false;
datetime g_decision_bar_time      = 0;
datetime g_decision_session_time  = 0;
int      g_decision_month_key     = 0;
int      g_decision_calendar_day  = 0;
int      g_decision_label_offset  = -1;
long     g_decision_attach_age    = -1;
bool     g_decision_label_valid   = false;
bool     g_entry_ready            = false;
string   g_signal_state           = "idle";

// -----------------------------------------------------------------------------
// Structural calendar helpers.
// -----------------------------------------------------------------------------

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_symbol && _Period == PERIOD_D1);
  }

bool Strategy_TimeParts(const datetime value, MqlDateTime &parts)
  {
   ZeroMemory(parts);
   return (value > 0 && TimeToStruct(value, parts) &&
           parts.year >= 1900 && parts.mon >= 1 && parts.mon <= 12 &&
           parts.day >= 1 && parts.day <= 31);
  }

int Strategy_DateKeyForTime(const datetime value)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_MonthKeyForTime(const datetime value)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(value, parts))
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_DayForTime(const datetime value)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(value, parts))
      return 0;
   return parts.day;
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

bool Strategy_IsAdjacentMonthBoundary(const datetime current_raw,
                                      const datetime previous_raw,
                                      const int label_offset,
                                      const int required_current_month)
  {
   const datetime current_session =
      Strategy_NormalizedLabel(current_raw, label_offset);
   const datetime previous_session =
      Strategy_NormalizedLabel(previous_raw, label_offset);
   const int current_month = Strategy_MonthKeyForTime(current_session);
   const int previous_month = Strategy_MonthKeyForTime(previous_session);
   return (current_session > previous_session && current_month > 0 &&
           current_month == required_current_month && previous_month > 0 &&
           Strategy_NextMonthKey(previous_month) == current_month);
  }

void Strategy_ResetDecisionState()
  {
   g_current_session_valid = false;
   g_current_session_time = 0;
   g_current_month_key = 0;
   g_current_calendar_day = 0;
   g_ordinary_exit_due = false;

   g_decision_bar = false;
   g_decision_bar_time = 0;
   g_decision_session_time = 0;
   g_decision_month_key = 0;
   g_decision_calendar_day = 0;
   g_decision_label_offset = -1;
   g_decision_attach_age = -1;
   g_decision_label_valid = false;
   g_entry_ready = false;
   g_signal_state = "idle";
  }

void Strategy_SetInvalidBoundaryDecision(const MqlRates &current_bar,
                                         const MqlRates &previous_bar,
                                         const datetime broker_now)
  {
   const int broker_month = Strategy_MonthKeyForTime(broker_now);
   const int broker_day = Strategy_DayForTime(broker_now);
   if(broker_month <= 0 || broker_day < 1 ||
      broker_day > strategy_entry_latest_day)
      return;

   const bool raw_boundary =
      Strategy_IsAdjacentMonthBoundary(current_bar.time,
                                       previous_bar.time,
                                       0,
                                       broker_month);
   const bool shifted_boundary =
      Strategy_IsAdjacentMonthBoundary(current_bar.time,
                                       previous_bar.time,
                                       86400,
                                       broker_month);
   if(!raw_boundary && !shifted_boundary)
      return;

   // The opening transition is recognizable, but neither allowed convention
   // maps the current bar to today's broker date. Consume this broker month
   // flat instead of attaching later or inventing a third offset.
   g_decision_bar = true;
   g_decision_bar_time = current_bar.time;
   g_decision_month_key = broker_month;
   g_decision_calendar_day = broker_day;
   g_decision_label_valid = false;
   g_signal_state = "invalid_label_convention";
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
   const datetime current_session =
      Strategy_NormalizedLabel(current_bar.time, label_offset);
   const datetime previous_session =
      Strategy_NormalizedLabel(previous_bar.time, label_offset);

   if(label_offset < 0 || current_session <= previous_session ||
      Strategy_DateKeyForTime(current_session) !=
         Strategy_DateKeyForTime(broker_now))
     {
      Strategy_SetInvalidBoundaryDecision(current_bar,
                                          previous_bar,
                                          broker_now);
      return;
     }

   g_current_session_valid = true;
   g_current_session_time = current_session;
   g_current_month_key = Strategy_MonthKeyForTime(current_session);
   g_current_calendar_day = Strategy_DayForTime(current_session);
   g_ordinary_exit_due =
      (g_current_calendar_day >= strategy_exit_calendar_day);

   const int previous_month = Strategy_MonthKeyForTime(previous_session);
   if(g_current_month_key <= 0 || previous_month <= 0 ||
      Strategy_NextMonthKey(previous_month) != g_current_month_key)
      return;

   g_decision_bar = true;
   g_decision_bar_time = current_bar.time;
   g_decision_session_time = current_session;
   g_decision_month_key = g_current_month_key;
   g_decision_calendar_day = g_current_calendar_day;
   g_decision_label_offset = label_offset;
   g_decision_attach_age = (long)(broker_now - current_session);
   g_decision_label_valid = true;
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
      stored_month_key >= 190001 && stored_month_key <= current_month_key)
     {
      g_last_attempt_month_key = stored_month_key;
      return;
     }

   // Tester globals can survive a later historical replay. Future or malformed
   // state must never suppress the beginning of a deterministic replay.
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
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const int opened_month_key = Strategy_MonthKeyForTime(opened);

      bool should_close =
         (owned_count != 1 || !g_current_session_valid ||
          position_type != POSITION_TYPE_SELL ||
          opened <= 0 || opened > now || opened_month_key <= 0 ||
          volume <= 0.0 || !MathIsValidNumber(volume) ||
          open_price <= 0.0 || !MathIsValidNumber(open_price) ||
          stop_price <= open_price || !MathIsValidNumber(stop_price));

      if(!should_close && opened_month_key != g_current_month_key)
         should_close = true;
      if(!should_close && g_ordinary_exit_due &&
         g_current_session_time > opened)
         should_close = true;
      if(!should_close && (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
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

   // Recover an already-entered month from positions/deals before replacing a
   // lost terminal marker. The recovered result is still persisted before any
   // news, spread, quote, ATR, sizing, margin, or submission gate.
   const bool already_entered =
      Strategy_MonthAlreadyEntered(g_decision_month_key);
   if(!Strategy_RecordMonthAttempt(g_decision_month_key))
     {
      g_signal_state = "attempt_persist_failed";
      return;
     }

   if(already_entered)
      g_signal_state = "entry_deal_position_or_history_failure";
   else if(!g_decision_label_valid)
      g_signal_state = "invalid_label_convention";
   else if(g_decision_calendar_day < 1 ||
           g_decision_calendar_day > strategy_entry_latest_day)
      g_signal_state = "opening_session_after_day_ceiling";
   else if(g_decision_attach_age < 0 ||
           g_decision_attach_age >
              (long)strategy_boundary_attach_max_minutes * 60L)
      g_signal_state = "boundary_attach_too_late";
   else if(Strategy_HasOwnedPosition())
      g_signal_state = "owned_position_remains";
   else
     {
      g_entry_ready = true;
      g_signal_state = "first_half_short_ready";
     }

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"month\":%d,\"decision_bar\":%I64d,\"normalized_session\":%I64d,\"label_offset_seconds\":%d,\"label_valid\":%s,\"calendar_day\":%d,\"attach_age_seconds\":%I64d,\"entry_ready\":%s,\"state\":\"%s\"}",
                            g_decision_month_key,
                            (long)g_decision_bar_time,
                            (long)g_decision_session_time,
                            g_decision_label_offset,
                            g_decision_label_valid ? "true" : "false",
                            g_decision_calendar_day,
                            g_decision_attach_age,
                            g_entry_ready ? "true" : "false",
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

   if(!QM_InputRequireLong("qm_ea_id", qm_ea_id, 41200) ||
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
      !QM_InputRequireLong("strategy_exit_calendar_day", strategy_exit_calendar_day, 16) ||
      !QM_InputRequireLong("strategy_entry_latest_day", strategy_entry_latest_day, 5) ||
      !QM_InputRequireLong("strategy_boundary_attach_max_minutes", strategy_boundary_attach_max_minutes, 180) ||
      !QM_InputRequireLong("strategy_atr_period_d1", strategy_atr_period_d1, 20) ||
      !QM_InputRequireDouble("strategy_atr_sl_mult", strategy_atr_sl_mult, 2.75, 1.0e-12) ||
      !QM_InputRequireLong("strategy_max_hold_days", strategy_max_hold_days, 20) ||
      !QM_InputRequireLong("strategy_max_spread_points", strategy_max_spread_points, 2500))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "WTI_H1M_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_strategy_new_d1_bar || !g_decision_bar ||
      g_decision_month_key <= 0 ||
      g_decision_month_key != g_last_attempt_month_key ||
      !g_entry_ready || Strategy_HasOwnedPosition())
      return false;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      spread_points > strategy_max_spread_points)
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
   if(req.sl <= entry_price || !MathIsValidNumber(req.sl))
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
      !Strategy_IsHostChart() || qm_ea_id != 41200 ||
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
         "Approved WTI first-half-month card holds through the first later normalized D1 day at least 16"))
      return INIT_FAILED;

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41200_WTI_H1M_MONTH_ATTEMPT_%d",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());

   string warmup_symbols[1];
   warmup_symbols[0] = g_symbol;
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          strategy_atr_period_d1 + 5);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41200\",\"ea\":\"wti-h1m-short\"}");
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

   // Malformed, ordinary day-16, and stale repair precede every entry-only
   // gate. The ordinary-exit latch remains true so close failures retry.
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

   // The exact broker yyyymm attempt is durable before this entry-only news
   // gate. Both news axes are locked OFF for the baseline.
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
