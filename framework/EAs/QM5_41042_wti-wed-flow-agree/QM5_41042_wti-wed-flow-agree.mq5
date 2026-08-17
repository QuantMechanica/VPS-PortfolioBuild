#property strict
#property version   "5.0"
#property description "QM5_41042 WTI Standard-Wednesday Strict Flow-Agreement Continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41042 - WTI Standard-Wednesday Strict Flow-Agreement Continuation
// -----------------------------------------------------------------------------
// Structural D1 crude-oil sleeve:
//   - require exact completed Monday-Tuesday-Wednesday broker sessions
//   - split Wednesday into close-to-open and open-to-close log-return streams
//   - enter Thursday only when both nonzero streams have the same strict sign,
//     following the reconciled completed Wednesday move
//   - consume one exact-Thursday attempt before every fallible entry gate
//   - flatten at the first later D1 boundary; Friday close is a fail-safe
//   - repair malformed or stale carry behind one frozen ATR hard stop
// Native MT5 calendar/OHLC/history only; no external runtime data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41042;
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
input double strategy_reconcile_tolerance  = 1.0e-10;

int      g_last_attempt_date_key = 0;
string   g_attempt_state_key     = "";
bool     g_strategy_new_d1_bar   = false;
datetime g_strategy_d1_bar_time  = 0;

// -----------------------------------------------------------------------------
// Strategy hooks - mechanically frozen from the approved card.
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

bool Strategy_IsThursday(const datetime value)
  {
   return (Strategy_DayOfWeek(value) == 4);
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
   // Factory energy D1 bars may be labelled with the preceding calendar
   // date. Modulo one day measures time since the executable session open for
   // either that convention or a native same-day label.
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

   // Remain fail-closed in-process even when terminal persistence fails.
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
   if(!Strategy_IsThursday(broker_now) ||
      Strategy_EntryWithinGrace(current_bar.time))
      return true;

   // Consume the initialization edge and persist the missed Thursday
   // decision. Attaching late may not create a same-day retry.
   QM_IsNewBar(_Symbol, PERIOD_D1);
   const int date_key =
      Strategy_DateKey(broker_now);
   if(date_key == g_last_attempt_date_key)
      return true;
   return Strategy_RecordDateAttempt(date_key);
  }

bool Strategy_LoadWednesdayFlowAgreement(const datetime current_bar_time,
                                    const datetime broker_now,
                                    double &overnight_flow,
                                    double &session_flow,
                                    double &day_return,
                                    double &total_flow,
                                    int &direction)
  {
   overnight_flow = 0.0;
   session_flow = 0.0;
   day_return = 0.0;
   total_flow = 0.0;
   direction = 0;
   if(!Strategy_IsThursday(broker_now) ||
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
      Strategy_DateKey(broker_now))
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol,          // perf-allowed: exact
                                PERIOD_D1,         // three completed bars:
                                1,                 // Wednesday, Tuesday,
                                3,                 // and Monday.
                                bars);
   if(copied != 3)
      return false;

   // Newest first: Wednesday, Tuesday, Monday. Apply the current bar's one
   // uniform energy-label offset to all completed bars. Weekday, calendar
   // offset, and bounded-gap checks reject holidays and substitutions while
   // tolerating one-hour broker DST transitions.
   datetime session_times[3];
   const int expected_days[3] = {3, 2, 1};
   const int expected_offsets[3] = {1, 2, 3};
   for(int index = 0; index < 3; ++index)
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
   for(int index = 0; index < 2; ++index)
     {
      if(!Strategy_GapHoursAllowed(session_times[index],
                                   session_times[index + 1],
                                   20,
                                   28))
         return false;
     }

   // Only the authorized completed Wednesday open/close and Tuesday close
   // are price endpoints. Monday proves exact sequence identity only.
   if(bars[0].open <= 0.0 ||
      !MathIsValidNumber(bars[0].open) ||
      bars[0].close <= 0.0 ||
      !MathIsValidNumber(bars[0].close) ||
      bars[1].close <= 0.0 ||
      !MathIsValidNumber(bars[1].close))
      return false;

   overnight_flow =
      MathLog(bars[0].open / bars[1].close);
   session_flow =
      MathLog(bars[0].close / bars[0].open);
   day_return =
      MathLog(bars[0].close / bars[1].close);
   total_flow = overnight_flow + session_flow;
   if(!MathIsValidNumber(overnight_flow) ||
      !MathIsValidNumber(session_flow) ||
      !MathIsValidNumber(day_return) ||
      !MathIsValidNumber(total_flow))
      return false;

   if(MathAbs(total_flow - day_return) >
      strategy_reconcile_tolerance)
      return false;

   // Strict multiplication implements the card's nonzero same-sign gate.
   if(overnight_flow * session_flow <= 0.0)
      return true;

   // Follow the completed Wednesday displacement; magnitude never changes risk.
   if(total_flow > 0.0)
      direction = 1;
   else if(total_flow < 0.0)
      direction = -1;
   return true;
  }

bool Strategy_PositionDirectionIsValid(const datetime opened,
                                       const long position_type)
  {
   return (opened > 0 &&
           Strategy_DayOfWeek(opened) == 4 &&
           (position_type == POSITION_TYPE_BUY ||
            position_type == POSITION_TYPE_SELL));
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
      const int opened_date_key =
         Strategy_DateKey(opened);
      bool should_close =
         (owned_count != 1 ||
          opened <= 0 || opened > now ||
          !Strategy_PositionDirectionIsValid(opened,
                                             position_type) ||
          volume <= 0.0 || !MathIsValidNumber(volume) ||
          open_price <= 0.0 || !MathIsValidNumber(open_price) ||
          stop_price <= 0.0 || !MathIsValidNumber(stop_price) ||
          opened_date_key <= 0);

      // The ordinary exit is the first observable D1 session date strictly
      // later than the entry date (normally Friday open).
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

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsWtiD1())
      return true;
   if(qm_ea_id != 41042 ||
      qm_magic_slot_offset != 0)
      return true;
   if(MathAbs(RISK_PERCENT) > 1.0e-12 ||
      MathAbs(RISK_FIXED - 1000.0) > 1.0e-12 ||
      MathAbs(PORTFOLIO_WEIGHT - 1.0) > 1.0e-12)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 ||
      qm_news_min_impact != "high")
      return true;
   if(!qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21)
      return true;
   if(strategy_entry_grace_minutes != 180 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.0) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 3 ||
      strategy_max_spread_points != 1500 ||
      MathAbs(strategy_reconcile_tolerance - 1.0e-10) > 1.0e-20)
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
   req.reason = "WTI_WED_FLOW_AGREE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0 ||
      !Strategy_IsThursday(broker_now))
      return false;

   const int date_key =
      Strategy_DateKey(broker_now);
   if(date_key <= 0 ||
      date_key == g_last_attempt_date_key)
      return false;

   // Consume before history, signal, spread, quote, news, stop, sizing, or
   // order gates. A blocked Thursday attempt cannot retry after restart.
   if(!Strategy_RecordDateAttempt(date_key))
      return false;

   if(!Strategy_EntryWithinGrace(g_strategy_d1_bar_time))
      return false;

   if(Strategy_DateAlreadyEntered(date_key,
                                  broker_now))
      return false;

   double overnight_flow = 0.0;
   double session_flow = 0.0;
   double day_return = 0.0;
   double total_flow = 0.0;
   int direction = 0;
   if(!Strategy_LoadWednesdayFlowAgreement(g_strategy_d1_bar_time,
                                  broker_now,
                                  overnight_flow,
                                  session_flow,
                                  day_return,
                                  total_flow,
                                  direction))
      return false;

   if(direction > 0)
     {
      req.type = QM_BUY;
      req.reason = "WTI_WED_FLOW_AGREE_LONG";
     }
   else if(direction < 0)
     {
      req.type = QM_SELL;
      req.reason = "WTI_WED_FLOW_AGREE_SHORT";
     }
   else
      return false;

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"date\":%d,\"overnight_flow\":%.12e,\"session_flow\":%.12e,\"day_return\":%.12e,\"total_flow\":%.12e,\"direction\":%d}",
                            date_key,
                            overnight_flow,
                            session_flow,
                            day_return,
                            total_flow,
                            direction));

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
      !MathIsValidNumber(req.sl))
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
   if(!SymbolSelect("XTIUSD.DWX", true) ||
      !Strategy_IsWtiD1() ||
      qm_ea_id != 41042 ||
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
         QM_FRIDAY_CLOSE_CARD_RULE,
         "Approved WTI Wednesday flow-agreement card exits next D1; Friday 21 is fail-safe"))
      return INIT_FAILED;

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41042_WED_FLOW_AGREE_THURSDAY_ATTEMPT_%d",
                   QM_FrameworkMagic());
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
               "{\"card\":\"QM5_41042\",\"ea\":\"wti-wed-flow-agree\"}");
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

   // Lifecycle repairs precede all entry-only gates and run on every tick so
   // a rejected close remains retryable.
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

   // EntrySignal deliberately consumes the exact Thursday before this entry-
   // only news gate. Both news axes are locked OFF in the baseline.
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
