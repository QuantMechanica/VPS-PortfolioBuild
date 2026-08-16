#property strict
#property version   "5.0"
#property description "QM5_41019 WTI Fixed Week-Opening Segment Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41019 - WTI Fixed Week-Opening Segment Momentum
// -----------------------------------------------------------------------------
// Structural D1 crude-oil sleeve:
//   - require an exact prior-Friday, Monday, Tuesday, current-Wednesday sequence
//   - follow log(Tuesday close / prior-Friday close) on Wednesday
//   - consume one exact-Wednesday attempt before every fallible entry gate
//   - hold through the balance of the week and flatten Friday at broker 21
//   - repair malformed or prior-week carry with one frozen ATR hard stop
// Native MT5 calendar/OHLC/history only; no external runtime data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41019;
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
input int    strategy_entry_grace_minutes  = 180;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.5;
input int    strategy_max_hold_days         = 6;
input int    strategy_max_spread_points     = 1500;

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

bool Strategy_IsWednesday(const datetime value)
  {
   return (Strategy_DayOfWeek(value) == 3);
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
   if(!Strategy_IsWednesday(broker_now) ||
      Strategy_EntryWithinGrace(current_bar.time))
      return true;

   // Consume the initialization edge and persist the missed Wednesday
   // decision. Attaching late may not create a same-week retry.
   QM_IsNewBar(_Symbol, PERIOD_D1);
   const int date_key =
      Strategy_DateKey(broker_now);
   if(date_key == g_last_attempt_date_key)
      return true;
   return Strategy_RecordDateAttempt(date_key);
  }

bool Strategy_LoadOpeningSegment(const datetime current_bar_time,
                                 const datetime broker_now,
                                 double &opening_return,
                                 int &direction)
  {
   opening_return = 0.0;
   direction = 0;
   if(!Strategy_IsWednesday(broker_now) ||
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
                                PERIOD_D1,         // three-bar completed
                                1,                 // weekly sequence behind
                                3,                 // one QM_IsNewBar edge.
                                bars);
   if(copied != 3)
      return false;

   // Newest first: Tuesday, Monday, prior Friday. Day-of-week plus bounded
   // timestamp gaps rejects holiday shifts and stale/missing data while
   // tolerating the broker's one-hour DST transitions.
   const datetime tuesday_time = bars[0].time + label_offset;
   const datetime monday_time = bars[1].time + label_offset;
   const datetime friday_time = bars[2].time + label_offset;
   if(Strategy_DayOfWeek(tuesday_time) != 2 ||
      Strategy_DayOfWeek(monday_time) != 1 ||
      Strategy_DayOfWeek(friday_time) != 5)
      return false;
   if(!Strategy_GapHoursAllowed(current_session_time, tuesday_time, 20, 28) ||
      !Strategy_GapHoursAllowed(tuesday_time, monday_time, 20, 28) ||
      !Strategy_GapHoursAllowed(monday_time, friday_time, 68, 76))
      return false;

   for(int index = 0; index < 3; ++index)
     {
      if(bars[index].time <= 0 || bars[index].close <= 0.0 ||
         !MathIsValidNumber(bars[index].close))
         return false;
     }

   opening_return = MathLog(bars[0].close / bars[2].close);
   if(!MathIsValidNumber(opening_return))
      return false;
   if(opening_return > 0.0)
      direction = 1;
   else if(opening_return < 0.0)
      direction = -1;
   return true;
  }

bool Strategy_PositionDirectionIsValid(const datetime opened,
                                       const long position_type)
  {
   return (opened > 0 &&
           Strategy_DayOfWeek(opened) == 3 &&
           (position_type == POSITION_TYPE_BUY ||
            position_type == POSITION_TYPE_SELL));
  }

void Strategy_CloseExpiredPositions()
  {
   const datetime now = TimeCurrent();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;
   const int owned_count = Strategy_ManagedPositionCount();
   const int current_day =
      Strategy_DayOfWeek(now);

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
      bool should_close =
         (owned_count != 1 ||
          opened <= 0 || opened > now ||
          !Strategy_PositionDirectionIsValid(opened,
                                             position_type) ||
          volume <= 0.0 || !MathIsValidNumber(volume) ||
          open_price <= 0.0 || !MathIsValidNumber(open_price) ||
          stop_price <= 0.0 || !MathIsValidNumber(stop_price));

      // A Friday-close failure or closed-market Friday must not carry the
      // package into the next broker week. Retry throughout Sunday/Monday/
      // Tuesday until the position is flat.
      if(!should_close &&
         now > opened &&
         (current_day == 0 || current_day == 1 || current_day == 2))
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
   if(qm_ea_id != 41019 ||
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
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 6 ||
      strategy_max_spread_points != 1500)
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
   req.reason = "WTI_WEEK_OPEN_MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0 ||
      !Strategy_IsWednesday(broker_now))
      return false;

   const int date_key =
      Strategy_DateKey(broker_now);
   if(date_key <= 0 ||
      date_key == g_last_attempt_date_key)
      return false;

   // Consume before history, signal, spread, quote, news, stop, sizing, or
   // order gates. A blocked Wednesday attempt cannot retry after restart.
   if(!Strategy_RecordDateAttempt(date_key))
      return false;

   if(!Strategy_EntryWithinGrace(g_strategy_d1_bar_time))
      return false;

   if(Strategy_DateAlreadyEntered(date_key,
                                  broker_now))
      return false;

   double opening_return = 0.0;
   int direction = 0;
   if(!Strategy_LoadOpeningSegment(g_strategy_d1_bar_time,
                                   broker_now,
                                   opening_return,
                                   direction))
      return false;

   if(direction > 0)
     {
      req.type = QM_BUY;
      req.reason = "WTI_WEEK_OPEN_MOM_LONG";
     }
   else if(direction < 0)
     {
      req.type = QM_SELL;
      req.reason = "WTI_WEEK_OPEN_MOM_SHORT";
     }
   else
      return false;

   QM_LogEvent(QM_INFO,
               "STRATEGY_STATE",
               StringFormat("{\"date\":%d,\"opening_return\":%.12e,\"direction\":%d}",
                            date_key,
                            opening_return,
                            direction));

   const long spread_points =
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      spread_points > strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(_Symbol,
             PERIOD_D1,
             strategy_atr_period,
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
      qm_ea_id != 41019 ||
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
         "Approved WTI week-opening momentum card requires Friday 21 flattening"))
      return INIT_FAILED;

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_41019_WEEK_ATTEMPT_%d",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());
   if(!Strategy_PrimeLateSignalAttach())
      return INIT_FAILED;

   string warmup_symbols[1];
   warmup_symbols[0] = "XTIUSD.DWX";
   QM_SymbolGuardInit(warmup_symbols);
   QM_BasketWarmupHistory(warmup_symbols,
                          PERIOD_D1,
                          32);

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41019\",\"ea\":\"wti-wopen-mom\"}");
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

   // Lifecycle exits precede all entry-only gates and run on every tick so a
   // rejected next-bar close remains retryable.
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

   // EntrySignal deliberately consumes the exact Wednesday before this entry-only
   // news gate. Both news axes are locked OFF in the baseline.
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
