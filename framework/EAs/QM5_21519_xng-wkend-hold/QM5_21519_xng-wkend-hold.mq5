#property strict
#property version   "5.0"
#property description "QM5_21519 XNG pre-weekend to Monday hold"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_21519 - XNG pre-weekend to Monday structural hold
// -----------------------------------------------------------------------------
// One long-only XNG package per broker week:
//   - enter on the genuine Friday 21:00 broker H1 boundary
//   - hold across the closed-market weekend information window
//   - close at/after Monday 21:00, first later-week tick, or 96 hours
// The attempt is persisted before history/news/spread/order gates. Runtime uses
// native MT5 time, H1/D1 history, quote, spread, position, and deal state only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 21519;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

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
input int    strategy_entry_hour_broker   = 21;
input int    strategy_entry_grace_minutes = 5;
input int    strategy_exit_hour_broker    = 21;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.5;
input int    strategy_max_hold_hours       = 96;
input int    strategy_max_spread_points    = 1000;

bool     g_is_new_bar = false;
bool     g_entry_ready = false;
datetime g_current_h1_bar = 0;
datetime g_cached_week_key = 0;
datetime g_last_attempt_week_key = 0;
string   g_attempt_state_key = "";

bool Strategy_TimeParts(const datetime value, MqlDateTime &parts)
  {
   ZeroMemory(parts);
   return (value > 0 && TimeToStruct(value, parts));
  }

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(value, parts))
      return -1;
   return parts.day_of_week;
  }

int Strategy_Hour(const datetime value)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(value, parts))
      return -1;
   return parts.hour;
  }

bool Strategy_IsExpectedHost()
  {
   // Exact-symbol authority is enforced by the registered magic lookup in
   // OnInit; using _Symbol here keeps this single-symbol EA scope-clean.
   return (_Period == PERIOD_H1);
  }

bool Strategy_InputsLocked()
  {
   return (qm_ea_id == 21519 &&
           qm_magic_slot_offset == 0 &&
           MathAbs(RISK_PERCENT) <= 1.0e-12 &&
           MathAbs(RISK_FIXED - 1000.0) <= 1.0e-9 &&
           MathAbs(PORTFOLIO_WEIGHT - 1.0) <= 1.0e-12 &&
           qm_news_temporal == QM_NEWS_TEMPORAL_OFF &&
           qm_news_compliance == QM_NEWS_COMPLIANCE_NONE &&
           qm_news_mode_legacy == QM_NEWS_OFF &&
           !qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21 &&
           qm_stress_reject_probability >= 0.0 &&
           qm_stress_reject_probability <= 1.0 &&
           strategy_entry_hour_broker == 21 &&
           strategy_entry_grace_minutes == 5 &&
           strategy_exit_hour_broker == 21 &&
           strategy_atr_period_d1 == 20 &&
           MathAbs(strategy_atr_sl_mult - 3.5) <= 1.0e-12 &&
           strategy_max_hold_hours == 96 &&
           strategy_max_spread_points == 1000);
  }

int Strategy_OpenOwnedPositionCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         ++count;
     }
   return count;
  }

void Strategy_CloseAllOwned(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_EntryTimeValid(const datetime opened)
  {
   MqlDateTime parts;
   if(!Strategy_TimeParts(opened, parts))
      return false;
   return (parts.day_of_week == 5 &&
           parts.hour == strategy_entry_hour_broker);
  }

bool Strategy_CalendarExitReached(const datetime opened,
                                  const datetime broker_now)
  {
   if(opened <= 0 || broker_now <= opened)
      return false;

   const long elapsed = (long)(broker_now - opened);
   if(elapsed >= (long)strategy_max_hold_hours * 3600)
      return true;

   MqlDateTime now_parts;
   if(!Strategy_TimeParts(broker_now, now_parts))
      return true;

   if(now_parts.day_of_week == 1 &&
      now_parts.hour >= strategy_exit_hour_broker)
      return true;

   // A Tuesday-through-Thursday tick means the governed Monday cutoff was
   // missed (holiday, detach, or outage). Repair immediately, not at a fitted
   // later hour.
   if(now_parts.day_of_week >= 2 && now_parts.day_of_week <= 4)
      return true;

   return false;
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_XNG_WKEND_ATTEMPT_WEEK", qm_ea_id);
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_week_key = 0;
   if(reference_time <= 0 || !GlobalVariableCheck(g_attempt_state_key))
      return;

   const double stored_value = GlobalVariableGet(g_attempt_state_key);
   if(MathIsValidNumber(stored_value) && stored_value > 0.0 &&
      stored_value <= (double)reference_time)
      g_last_attempt_week_key = (datetime)MathRound(stored_value);
   else
      GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const datetime week_key)
  {
   if(week_key <= 0)
      return false;
   if(g_attempt_state_key == "")
      g_attempt_state_key = Strategy_AttemptStateKey();

   // Set the in-memory block first so a failed terminal-global write still
   // cannot retry during this attach. Fail closed instead of ordering when
   // durable persistence is unavailable.
   g_last_attempt_week_key = week_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)week_key) > 0);
  }

bool Strategy_HasEntryDealSince(const datetime week_key)
  {
   if(week_key <= 0 || !HistorySelect(week_key, TimeCurrent()))
      return true;

   const int magic = QM_FrameworkMagic();
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind == DEAL_ENTRY_IN || entry_kind == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

bool Strategy_PrepareFridayAttempt()
  {
   g_entry_ready = false;
   g_cached_week_key = 0;
   if(!g_is_new_bar || g_current_h1_bar <= 0)
      return false;

   MqlDateTime bar_parts;
   if(!Strategy_TimeParts(g_current_h1_bar, bar_parts) ||
      bar_parts.day_of_week != 5 ||
      bar_parts.hour != strategy_entry_hour_broker ||
      bar_parts.min != 0 || bar_parts.sec != 0)
      return false;

   const long opening_delay = (long)(TimeCurrent() - g_current_h1_bar);
   if(opening_delay < 0 ||
      opening_delay > (long)strategy_entry_grace_minutes * 60)
      return false;

   const datetime week_key = iTime(_Symbol, PERIOD_W1, 0); // perf-allowed: once on the governed Friday H1 boundary.
   if(week_key <= 0 || week_key > g_current_h1_bar ||
      week_key == g_last_attempt_week_key)
      return false;

   // The week is consumed before position, deal history, news, spread, quote,
   // ATR, sizing, stop, or order gates.
   if(!Strategy_RecordAttemptState(week_key))
      return false;

   g_cached_week_key = week_key;
   g_entry_ready = true;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   return (!Strategy_IsExpectedHost() || !Strategy_InputsLocked());
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_BUY;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "QM5_21519_XNG_WKEND_HOLD";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   if(!g_entry_ready || g_cached_week_key <= 0 ||
      g_cached_week_key != g_last_attempt_week_key)
      return false;
   if(Strategy_OpenOwnedPositionCount() > 0 ||
      Strategy_HasEntryDealSince(g_cached_week_key))
      return false;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 || spread_points > strategy_max_spread_points)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   const double atr_value =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price) ||
      atr_value <= 0.0 || !MathIsValidNumber(atr_value))
      return false;

   request.sl = QM_StopATRFromValue(_Symbol,
                                     QM_BUY,
                                     entry_price,
                                     atr_value,
                                     strategy_atr_sl_mult);
   request.sl = QM_StopRulesNormalizePrice(_Symbol, request.sl);
   if(request.sl <= 0.0 || !MathIsValidNumber(request.sl) ||
      request.sl >= entry_price)
      return false;

   request.reason = "XNG_FRIDAY_PRECLOSE_TO_MONDAY_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int owned_count = Strategy_OpenOwnedPositionCount();
   if(owned_count <= 0)
      return;
   if(owned_count != 1)
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }

   const int magic = QM_FrameworkMagic();
   const datetime broker_now = TimeCurrent();
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const double stop = PositionGetDouble(POSITION_SL);

      bool malformed = (symbol != _Symbol ||
                        position_type != POSITION_TYPE_BUY ||
                        opened <= 0 || !Strategy_EntryTimeValid(opened) ||
                        stop <= 0.0 || !MathIsValidNumber(stop));
      if(malformed)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      if(Strategy_CalendarExitReached(opened, broker_now))
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!Strategy_IsExpectedHost() || !Strategy_InputsLocked())
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolSelect(_Symbol, true))
      return INIT_FAILED;

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

   const int registered_magic =
      QM_MagicChecked(qm_ea_id, qm_magic_slot_offset, _Symbol);
   if(registered_magic != 215190000)
      return INIT_FAILED;

   g_attempt_state_key = Strategy_AttemptStateKey();
   if((bool)MQLInfoInteger(MQL_TESTER))
     {
      if(GlobalVariableCheck(g_attempt_state_key))
         GlobalVariableDel(g_attempt_state_key);
      g_last_attempt_week_key = 0;
     }
   else
      Strategy_LoadAttemptState(TimeCurrent());

   g_current_h1_bar = iTime(_Symbol, PERIOD_H1, 0); // perf-allowed: one restart anchor read.
   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_21519\",\"ea\":\"xng-wkend-hold\",\"signal\":\"friday_preclose_to_monday_long\"}");
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

   g_is_new_bar = QM_IsNewBar();
   g_entry_ready = false;
   g_cached_week_key = 0;
   if(g_is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      g_current_h1_bar = iTime(_Symbol, PERIOD_H1, 0); // perf-allowed: new-H1 lifecycle and entry anchor.
     }

   // Management and malformed-state repair run on every tick and before all
   // entry-only gates. Friday-close handling above is disabled by the locked
   // contract but remains wired for framework validation.
   Strategy_ManageOpenPosition();
   if(!Strategy_PrepareFridayAttempt())
      return;

   // The week is already consumed. Both news axes are locked OFF, but keep the
   // standard framework path so the executable contract is explicit.
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

   QM_EntryRequest request;
   ZeroMemory(request);
   if(Strategy_EntrySignal(request))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(request, out_ticket);
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
