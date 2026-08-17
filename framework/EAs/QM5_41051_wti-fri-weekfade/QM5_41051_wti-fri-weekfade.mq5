#property strict
#property version   "5.0"
#property description "QM5_41051 WTI Exact-Week Pullback Friday Bounce"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41051 - WTI Exact-Week Pullback / Friday Bounce
// -----------------------------------------------------------------------------
// Structural D1 crude-oil sleeve:
//   - require exact current Monday-Thursday completed broker sessions
//   - compute only ln(ThursdayClose / MondayOpen)
//   - buy the Friday session only when that completed formation is negative
//   - consume one exact-Friday attempt before every fallible entry gate
//   - flatten through framework Friday close; repair survivors next D1
//   - protect the one owned long with a frozen ATR hard stop
// Native MT5 calendar/OHLC/history only; no external runtime data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41051;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_grace_minutes = 180;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 3;
input int    strategy_max_spread_points    = 1500;

int      g_last_attempt_date_key = 0;
string   g_attempt_state_key     = "";
bool     g_strategy_new_d1_bar   = false;
datetime g_strategy_d1_bar_time  = 0;

// -----------------------------------------------------------------------------
// Deterministic strategy helpers.
// -----------------------------------------------------------------------------

bool Strategy_IsWtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DateKey(const datetime value)
  {
   if(value <= 0)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_DayOfWeek(const datetime value)
  {
   if(value <= 0)
      return -1;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return -1;
   return parts.day_of_week;
  }

bool Strategy_IsFriday(const datetime value)
  {
   return (Strategy_DayOfWeek(value) == 5);
  }

datetime Strategy_NormalizedSessionTime(const datetime label,
                                        const datetime broker_now)
  {
   if(label <= 0 || broker_now < label)
      return 0;
   const long elapsed = (long)(broker_now - label);
   if(elapsed >= 86400L && elapsed < 172800L)
      return label + (datetime)86400;
   return label;
  }

bool Strategy_GapHoursAllowed(const datetime newer,
                              const datetime older,
                              const long min_hours,
                              const long max_hours)
  {
   if(newer <= older || older <= 0 || min_hours < 0 ||
      max_hours < min_hours)
      return false;
   const long elapsed = (long)(newer - older);
   return (elapsed >= min_hours * 3600 &&
           elapsed <= max_hours * 3600);
  }

bool Strategy_EntryWithinGrace(const datetime current_bar)
  {
   if(current_bar <= 0)
      return false;
   const datetime now = TimeCurrent();
   if(now < current_bar)
      return false;
   const long elapsed = (long)(now - current_bar);
   // Energy D1 labels can be one calendar date behind the executable session.
   const long session_elapsed = elapsed % 86400L;
   return (session_elapsed <=
           (long)strategy_entry_grace_minutes * 60);
  }

bool Strategy_IsManagedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) ==
              QM_FrameworkMagic());
  }

bool Strategy_HasOpenPosition()
  {
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         return true;
     }
   return false;
  }

int Strategy_ManagedPositionCount()
  {
   int count = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         ++count;
     }
   return count;
  }

bool Strategy_DateAlreadyEntered(const int date_key,
                                 const datetime current_bar)
  {
   if(date_key <= 0 || current_bar <= 0)
      return true;
   if(Strategy_HasOpenPosition())
      return true;

   const datetime history_start =
      current_bar - (long)10 * 86400;
   if(history_start <= 0 ||
      !HistorySelect(history_start, TimeCurrent()))
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
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,
                                                DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_DateKey(deal_time) == date_key)
         return true;
     }
   return false;
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_last_attempt_date_key = 0;
   if(g_attempt_state_key == "" ||
      !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_date_key =
      Strategy_DateKey(reference_time);
   const double stored =
      GlobalVariableGet(g_attempt_state_key);
   const int stored_date_key =
      (int)MathRound(stored);
   if(current_date_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_date_key >= 19000101 &&
      stored_date_key <= current_date_key)
     {
      g_last_attempt_date_key = stored_date_key;
      return;
     }

   // Tester globals can survive a later historical run. A future marker must
   // not suppress the beginning of a deterministic replay.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordDateAttempt(const int date_key)
  {
   if(date_key <= 0 || g_attempt_state_key == "")
      return false;

   // Remain fail-closed in-process even when persistence itself fails.
   g_last_attempt_date_key = date_key;
   return (GlobalVariableSet(g_attempt_state_key,
                             (double)date_key) > 0);
  }

bool Strategy_PrimeLateSignalAttach()
  {
   MqlRates current_bar;
   ZeroMemory(current_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar))
      return true;
   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsFriday(broker_now) ||
      Strategy_EntryWithinGrace(current_bar.time))
      return true;

   // Consume the initialization edge and persist the missed Friday. A late
   // attachment may not create a same-session retry.
   QM_IsNewBar(_Symbol, PERIOD_D1);
   const int date_key = Strategy_DateKey(broker_now);
   if(date_key == g_last_attempt_date_key)
      return true;
   return Strategy_RecordDateAttempt(date_key);
  }

bool Strategy_LoadExactWeekFormation(const datetime current_bar_time,
                                     const datetime broker_now,
                                     double &formation_return,
                                     int &direction)
  {
   formation_return = 0.0;
   direction = 0;
   if(!Strategy_IsFriday(broker_now) ||
      current_bar_time <= 0 || broker_now < current_bar_time)
      return false;

   const long current_elapsed =
      (long)(broker_now - current_bar_time);
   const datetime label_offset =
      (current_elapsed >= 86400L && current_elapsed < 172800L)
      ? (datetime)86400
      : (datetime)0;
   const datetime current_session_time =
      current_bar_time + label_offset;
   if(Strategy_DateKey(current_session_time) !=
      Strategy_DateKey(broker_now) ||
      Strategy_DayOfWeek(current_session_time) != 5)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol,       // perf-allowed: exact four
                                PERIOD_D1,      // completed sessions behind
                                1,              // the sole new-D1 branch.
                                4,
                                bars);
   if(copied != 4)
      return false;

   // Newest first: Thursday, Wednesday, Tuesday, Monday. Apply the current
   // bar's single label offset uniformly and reject holidays/substitutions.
   datetime session_times[4];
   const int expected_days[4] = {4, 3, 2, 1};
   const int expected_offsets[4] = {1, 2, 3, 4};
   for(int index = 0; index < 4; ++index)
     {
      session_times[index] = bars[index].time + label_offset;
      if(bars[index].time <= 0 ||
         Strategy_DayOfWeek(session_times[index]) !=
            expected_days[index] ||
         Strategy_DateKey(session_times[index]) !=
            Strategy_DateKey(broker_now -
                             (long)expected_offsets[index] * 86400))
         return false;
     }

   if(!Strategy_GapHoursAllowed(current_session_time,
                                session_times[0],
                                20,
                                28))
      return false;
   for(int index = 0; index < 3; ++index)
     {
      if(!Strategy_GapHoursAllowed(session_times[index],
                                   session_times[index + 1],
                                   20,
                                   28))
         return false;
     }

   // Signal prices are completed Monday open (oldest bar) and Thursday close
   // (newest bar). No current-Friday price is read here.
   const double monday_open = bars[3].open;
   const double thursday_close = bars[0].close;
   if(monday_open <= 0.0 ||
      !MathIsValidNumber(monday_open) ||
      thursday_close <= 0.0 ||
      !MathIsValidNumber(thursday_close))
      return false;

   formation_return =
      MathLog(thursday_close / monday_open);
   if(!MathIsValidNumber(formation_return))
      return false;

   if(formation_return < 0.0)
      direction = 1;
   return true;
  }

bool Strategy_PositionStateIsValid(const datetime opened,
                                   const long position_type,
                                   const double volume,
                                   const double open_price,
                                   const double stop_price)
  {
   return (opened > 0 &&
           Strategy_DayOfWeek(opened) == 5 &&
           position_type == POSITION_TYPE_BUY &&
           volume > 0.0 && MathIsValidNumber(volume) &&
           open_price > 0.0 && MathIsValidNumber(open_price) &&
           stop_price > 0.0 && MathIsValidNumber(stop_price) &&
           stop_price < open_price);
  }

void Strategy_CloseExpiredPositions()
  {
   const datetime now = TimeCurrent();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;
   const int owned_count = Strategy_ManagedPositionCount();

   MqlRates current_bar;
   ZeroMemory(current_bar);
   const bool has_current_bar =
      QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar);
   const datetime current_session_time = has_current_bar
      ? Strategy_NormalizedSessionTime(current_bar.time, now)
      : (datetime)0;
   const int current_session_date_key =
      Strategy_DateKey(current_session_time);

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;

      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const long position_type =
         PositionGetInteger(POSITION_TYPE);
      const double volume =
         PositionGetDouble(POSITION_VOLUME);
      const double open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price =
         PositionGetDouble(POSITION_SL);
      const int opened_date_key = Strategy_DateKey(opened);
      bool should_close =
         (owned_count != 1 ||
          opened > now ||
          !Strategy_PositionStateIsValid(opened,
                                         position_type,
                                         volume,
                                         open_price,
                                         stop_price) ||
          opened_date_key <= 0);

      // Friday hour 21 is normal. A later normalized D1 date repairs any
      // missed framework close before another signal can be considered.
      if(!should_close &&
         current_session_date_key > opened_date_key)
         should_close = true;

      if(!should_close &&
         now >= opened &&
         (long)(now - opened) >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

// -----------------------------------------------------------------------------
// V5 strategy hooks.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsWtiD1())
     {
      PrintFormat("QM_INPUT_REJECT predicate=host_chart observed_symbol='%s' observed_period=%d required_symbol='XTIUSD.DWX' required_period=%d",
                  _Symbol, (int)_Period, (int)PERIOD_D1);
      return true;
     }
   if(!QM_InputRequireLong("qm_ea_id", qm_ea_id, 41051) ||
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
      !QM_InputRequireLong("strategy_entry_grace_minutes", strategy_entry_grace_minutes, 180) ||
      !QM_InputRequireLong("strategy_atr_period_d1", strategy_atr_period_d1, 20) ||
      !QM_InputRequireDouble("strategy_atr_sl_mult", strategy_atr_sl_mult, 3.0, 1.0e-12) ||
      !QM_InputRequireLong("strategy_max_hold_days", strategy_max_hold_days, 3) ||
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
   req.reason = "WTI_FRI_WEEKFADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0 ||
      !Strategy_IsFriday(broker_now))
      return false;

   const int date_key = Strategy_DateKey(broker_now);
   if(date_key <= 0 ||
      date_key == g_last_attempt_date_key)
      return false;

   // Consume before history, signal, news, spread, quote, ATR, sizing, or
   // order gates. A blocked Friday cannot retry after restart.
   if(!Strategy_RecordDateAttempt(date_key))
      return false;

   if(!Strategy_EntryWithinGrace(g_strategy_d1_bar_time))
      return false;
   if(Strategy_DateAlreadyEntered(date_key, broker_now))
      return false;

   double formation_return = 0.0;
   int direction = 0;
   if(!Strategy_LoadExactWeekFormation(g_strategy_d1_bar_time,
                                        broker_now,
                                        formation_return,
                                        direction))
      return false;

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"date\":%d,\"formation_return\":%.12e,\"direction\":%d}",
                            date_key,
                            formation_return,
                            direction));

   // Strictly negative completed formation is the only authorized state.
   if(direction != 1)
      return false;

   const long spread_points =
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      spread_points > strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(_Symbol,
             PERIOD_D1,
             strategy_atr_period_d1,
             1);
   if(atr_last <= 0.0 ||
      !MathIsValidNumber(atr_last))
      return false;

   const double entry_price =
      QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0 ||
      !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 ||
      !MathIsValidNumber(req.sl) ||
      req.sl >= entry_price)
      return false;

   req.reason = "WTI_FRI_WEEKFADE_LONG";
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
   if(!SymbolSelect(_Symbol, true))
     {
      Print("QM_INPUT_REJECT predicate=SymbolSelect observed=false required=true symbol='XTIUSD.DWX'");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!Strategy_IsWtiD1())
     {
      PrintFormat("QM_INPUT_REJECT predicate=host_chart observed_symbol='%s' observed_period=%d required_symbol='XTIUSD.DWX' required_period=%d",
                  _Symbol, (int)_Period, (int)PERIOD_D1);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!QM_InputRequireLong("qm_ea_id", qm_ea_id, 41051) ||
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
         QM_FRIDAY_CLOSE_CARD_RULE,
         "Approved WTI exact-week pullback card exits Friday 21; next D1 is repair"))
      return INIT_FAILED;

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41051_FRI_WEEKFADE_%d_%s_%d",
                   QM_FrameworkMagic(),
                   _Symbol,
                   (int)_Period);
   Strategy_LoadAttemptState(TimeCurrent());
   if(!Strategy_PrimeLateSignalAttach())
      return INIT_FAILED;

   string warmup_symbols[1];
   warmup_symbols[0] = "XTIUSD.DWX";
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          40);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41051\",\"ea\":\"wti-fri-weekfade\"}");
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
   if(!Strategy_IsWtiD1())
      return;

   g_strategy_new_d1_bar =
      QM_IsNewBar(_Symbol, PERIOD_D1);
   if(g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0)
     {
      MqlRates current_bar;
      ZeroMemory(current_bar);
      if(QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar))
         g_strategy_d1_bar_time = current_bar.time;
      else if(g_strategy_new_d1_bar)
         g_strategy_d1_bar_time = 0;
     }

   if(g_strategy_new_d1_bar)
      QM_EquityStreamOnNewBar();

   // Lifecycle repairs precede entry-only gates and run every tick so a
   // rejected close remains retryable.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket) ||
            !Strategy_IsManagedPosition())
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!g_strategy_new_d1_bar ||
      Strategy_NoTradeFilter())
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(!Strategy_EntrySignal(req))
      return;

   // EntrySignal consumes Friday before this entry-only news gate. Both axes
   // are card-locked OFF, but the framework contract remains explicit.
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
