#property strict
#property version   "5.0"
#property description "QM5_41017 WTI Exact Day-of-Month Counter-Regime"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_41017 - WTI Exact Day-of-Month / Counter-Regime Agreement
// -----------------------------------------------------------------------------
// Structural D1 crude-oil sleeve:
//   - exact broker day 8: BUY only with negative completed 252-D1 return
//   - exact broker day 26: SELL only with positive completed 252-D1 return
//   - never shift a missing numbered date to another session
//   - one persisted, consumed attempt per exact date before fallible gates
//   - first-following-D1 exit, one-day stale repair, and frozen ATR stop
// Native MT5 calendar/OHLC/history only; no external runtime data or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 41017;
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
input int    strategy_long_day             = 8;
input int    strategy_short_day            = 26;
input int    strategy_momentum_lookback_d1 = 252;
input double strategy_min_abs_return_pct   = 0.0;
input int    strategy_entry_grace_minutes  = 5;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 2.75;
input int    strategy_max_hold_days         = 1;
input int    strategy_max_spread_points     = 2500;

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

int Strategy_DayOfMonth(const datetime value)
  {
   if(value <= 0)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   return parts.day;
  }

bool Strategy_IsSignalDate(const datetime value)
  {
   const int day = Strategy_DayOfMonth(value);
   return (day == strategy_long_day ||
           day == strategy_short_day);
  }

bool Strategy_EntryWithinGrace(const datetime current_bar)
  {
   if(current_bar <= 0)
      return false;
   const datetime now = TimeCurrent();
   if(now < current_bar)
      return false;
   return ((long)(now - current_bar) <=
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

bool Strategy_DateAlreadyEntered(const int date_key,
                                 const datetime current_bar)
  {
   if(date_key <= 0 || current_bar <= 0)
      return true;
   if(Strategy_HasOpenPosition())
      return true;

   const datetime history_start =
      current_bar - (long)4 * 86400;
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
   if(!Strategy_IsSignalDate(current_bar.time) ||
      Strategy_EntryWithinGrace(current_bar.time))
      return true;

   // Consume the initialization edge and persist the missed exact-date
   // decision. Attaching late may not create a same-day retry.
   QM_IsNewBar(_Symbol, PERIOD_D1);
   const int date_key =
      Strategy_DateKey(current_bar.time);
   if(date_key == g_last_attempt_date_key)
      return true;
   return Strategy_RecordDateAttempt(date_key);
  }

bool Strategy_LoadMomentum(double &momentum,
                           int &direction)
  {
   momentum = 0.0;
   direction = 0;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int required =
      strategy_momentum_lookback_d1 + 1;
   const int copied =
      CopyClose(_Symbol, // perf-allowed: bounded completed D1 state sample.
                PERIOD_D1,
                1,
                required,
                closes);
   if(copied < required)
      return false;

   const double close_recent = closes[0];
   const double close_past =
      closes[strategy_momentum_lookback_d1];
   if(close_recent <= 0.0 || close_past <= 0.0 ||
      !MathIsValidNumber(close_recent) ||
      !MathIsValidNumber(close_past))
      return false;

   momentum = MathLog(close_recent / close_past);
   if(!MathIsValidNumber(momentum))
      return false;

   const double threshold =
      MathMax(0.0, strategy_min_abs_return_pct) / 100.0;
   if(momentum > threshold)
      direction = 1;
   else if(momentum < -threshold)
      direction = -1;
   return true;
  }

bool Strategy_PositionDirectionIsValid(const datetime opened,
                                       const long position_type)
  {
   const int open_day =
      Strategy_DayOfMonth(opened);
   if(open_day == strategy_long_day)
      return (position_type == POSITION_TYPE_BUY);
   if(open_day == strategy_short_day)
      return (position_type == POSITION_TYPE_SELL);
   return false;
  }

void Strategy_CloseExpiredPositions()
  {
   if(g_strategy_d1_bar_time <= 0)
      return;

   const datetime now = TimeCurrent();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;

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
      bool should_close =
         (opened <= 0 ||
          !Strategy_PositionDirectionIsValid(opened,
                                             position_type));

      // Retain this condition throughout the next bar so rejected closes are
      // retried on later ticks.
      if(!should_close &&
         g_strategy_d1_bar_time > opened)
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
   if(qm_ea_id != 41017 ||
      qm_magic_slot_offset != 0)
      return true;
   if(MathAbs(RISK_PERCENT) > 1.0e-12 ||
      MathAbs(RISK_FIXED - 1000.0) > 1.0e-12 ||
      MathAbs(PORTFOLIO_WEIGHT - 1.0) > 1.0e-12)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF)
      return true;
   if(!qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21)
      return true;
   if(strategy_long_day != 8 ||
      strategy_short_day != 26)
      return true;
   if(strategy_momentum_lookback_d1 != 252 ||
      MathAbs(strategy_min_abs_return_pct) > 1.0e-12)
      return true;
   if(strategy_entry_grace_minutes != 5 ||
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 2.75) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 1 ||
      strategy_max_spread_points != 2500)
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
   req.reason = "WTI_DOM_COUNTERREGIME";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0 ||
      !Strategy_IsSignalDate(g_strategy_d1_bar_time) ||
      !Strategy_EntryWithinGrace(g_strategy_d1_bar_time))
      return false;

   const int date_key =
      Strategy_DateKey(g_strategy_d1_bar_time);
   if(date_key <= 0 ||
      date_key == g_last_attempt_date_key)
      return false;

   // Consume before history, signal, spread, quote, news, stop, sizing, or
   // order gates. A blocked exact-date attempt cannot retry after restart.
   if(!Strategy_RecordDateAttempt(date_key))
      return false;

   if(Strategy_DateAlreadyEntered(date_key,
                                  g_strategy_d1_bar_time))
      return false;

   double momentum = 0.0;
   int direction = 0;
   if(!Strategy_LoadMomentum(momentum, direction))
      return false;

   const int signal_day =
      Strategy_DayOfMonth(g_strategy_d1_bar_time);
   if(signal_day == strategy_long_day &&
      direction == -1)
     {
      req.type = QM_BUY;
      req.reason = "WTI_DOM8_NEG252_LONG";
     }
   else if(signal_day == strategy_short_day &&
           direction == 1)
     {
      req.type = QM_SELL;
      req.reason = "WTI_DOM26_POS252_SHORT";
     }
   else
      return false;

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
         "Approved WTI exact-date counter-regime card requires Friday 21 flattening"))
      return INIT_FAILED;

   g_attempt_state_key =
      StringFormat("QM5_41017_DATE_ATTEMPT_%d",
                   QM_FrameworkMagic());
   Strategy_LoadAttemptState(TimeCurrent());
   if(!Strategy_PrimeLateSignalAttach())
      return INIT_FAILED;

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_41017\",\"ea\":\"wti-dom-ctrreg\"}");
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

   // EntrySignal deliberately consumes the exact date before this entry-only
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
