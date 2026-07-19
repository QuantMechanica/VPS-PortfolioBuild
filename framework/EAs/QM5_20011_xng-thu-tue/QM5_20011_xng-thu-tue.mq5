#property strict
#property version   "5.0"
#property description "QM5_20011 XNG Thursday-Close to Tuesday-Close Calendar Carry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20011 - XNG Thursday-Close to Tuesday-Close Calendar Carry
// -----------------------------------------------------------------------------
// Source-explicit Meek-Hoelscher Natural Gas weekly package:
//   - enter long at Friday D1 open, the executable proxy for Thursday close
//   - hold across the weekend, Monday and Tuesday
//   - exit at Wednesday D1 open, the proxy for Tuesday close
//   - frozen ATR hard stop and seven-day stale guard are V5 risk overlays
// Runtime is MT5-native: D1 calendar, ATR, spread, deals and position state.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20011;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_dow            = 5;
input int    strategy_exit_dow             = 3;
input int    strategy_entry_grace_minutes  = 5;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 3.5;
input int    strategy_max_hold_days         = 7;
input int    strategy_max_spread_points     = 2500;

int      g_last_entry_week_key = 0;
string   g_attempt_state_key = "";
bool     g_strategy_new_d1_bar = false;
datetime g_strategy_d1_bar_time = 0;
bool     g_entry_decision_ready = false;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_IsManagedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
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

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return -1;
   return parts.day_of_week;
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_%d_XNG_THU_TUE_ATTEMPT_WEEK", qm_ea_id);
  }

void Strategy_LoadAttemptState()
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_entry_week_key = 0;
   const int current_week =
      QM_CalendarPeriodKey(PERIOD_W1, _Symbol, 0);
   if(current_week <= 0 || !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int stored_week = (int)GlobalVariableGet(g_attempt_state_key);
   if(stored_week > 0 && stored_week <= current_week)
      g_last_entry_week_key = stored_week;
   else
      GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordAttemptState(const int week_key)
  {
   if(week_key <= 0)
      return false;
   if(g_attempt_state_key == "")
      g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_entry_week_key = week_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)week_key) > 0);
  }

void Strategy_PrimeLateFridayAttach()
  {
   MqlRates current_bar;
   ZeroMemory(current_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar))
      return;
   if(Strategy_DayOfWeek(current_bar.time) != strategy_entry_dow)
      return;

   const datetime now = TimeCurrent();
   const long grace_seconds =
      (long)MathMax(0, strategy_entry_grace_minutes) * 60;
   if(now > current_bar.time &&
      (long)(now - current_bar.time) > grace_seconds)
     {
      // The framework's first QM_IsNewBar call returns true. Consume that
      // initialization edge when attaching after the approved opening window
      // so a restart cannot manufacture a mid-Friday entry.
      QM_IsNewBar(_Symbol, PERIOD_D1);
     }
  }

bool Strategy_WeekAlreadyAttempted(const int week_key,
                                   const datetime decision_bar_time)
  {
   if(week_key <= 0 || decision_bar_time <= 0)
      return true;
   if(g_last_entry_week_key == week_key)
      return true;
   if(Strategy_HasOpenPosition())
      return true;

   // Entry is Friday-only. Monday-to-current-Friday history therefore covers
   // every possible entry deal in this broker week without a hand-rolled
   // calendar-period key.
   const datetime history_start =
      decision_bar_time - (datetime)((long)4 * 86400);
   if(history_start <= 0 || !HistorySelect(history_start, TimeCurrent()))
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

bool Strategy_ConsumeFridayDecision()
  {
   g_entry_decision_ready = false;
   if(!g_strategy_new_d1_bar || g_strategy_d1_bar_time <= 0)
      return false;
   if(Strategy_DayOfWeek(g_strategy_d1_bar_time) != strategy_entry_dow)
      return false;

   const datetime now = TimeCurrent();
   const long grace_seconds =
      (long)MathMax(0, strategy_entry_grace_minutes) * 60;
   if(now < g_strategy_d1_bar_time ||
      (long)(now - g_strategy_d1_bar_time) > grace_seconds)
      return false;

   const int week_key =
      QM_CalendarPeriodKey(PERIOD_W1, _Symbol, 0);
   if(Strategy_WeekAlreadyAttempted(week_key, g_strategy_d1_bar_time))
      return false;

   // Consume the opening decision before the news gate. If news, spread,
   // history or broker state rejects the order, this source-defined opening
   // cannot be retried later in the Friday session or after a restart.
   if(!Strategy_RecordAttemptState(week_key))
      return false;
   g_entry_decision_ready = true;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_entry_dow != 5 || strategy_exit_dow != 3)
      return true;
   if(strategy_entry_grace_minutes != 5)
      return true;
   if(strategy_atr_period != 14 &&
      strategy_atr_period != 20 &&
      strategy_atr_period != 30)
      return true;
   if(strategy_atr_sl_mult != 2.5 &&
      strategy_atr_sl_mult != 3.5 &&
      strategy_atr_sl_mult != 4.5)
      return true;
   if(strategy_max_hold_days != 7)
      return true;
   if(strategy_max_spread_points != 1500 &&
      strategy_max_spread_points != 2500 &&
      strategy_max_spread_points != 3500)
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
   req.reason = "QM5_20011_XNG_THU_TUE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_entry_decision_ready || !g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0)
      return false;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points < 0 ||
      (strategy_max_spread_points > 0 &&
       spread_points > strategy_max_spread_points))
      return false;

   const double atr_last =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                QM_BUY,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl) ||
      req.sl >= entry_price)
      return false;

   req.reason = "XNG_THU_CLOSE_TUE_CLOSE_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   QM_FrameworkTrackOpenPositionMae();

   const datetime now = TimeCurrent();
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;
   const int current_dow =
      (g_strategy_new_d1_bar && g_strategy_d1_bar_time > 0) ?
      Strategy_DayOfWeek(g_strategy_d1_bar_time) : -1;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsManagedPosition())
         continue;

      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close =
         (opened <= 0 || (long)(now - opened) >= hold_seconds);

      if(!should_close && g_strategy_new_d1_bar &&
         g_strategy_d1_bar_time > opened)
        {
         const long elapsed_to_bar =
            (long)(g_strategy_d1_bar_time - opened);
         if(current_dow == strategy_exit_dow)
            should_close = true;
         else if(elapsed_to_bar >= (long)4 * 86400 &&
                 current_dow > strategy_exit_dow && current_dow <= 5)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
         "Source rule requires the Thursday-close through Tuesday-close weekend hold"))
      return INIT_FAILED;

   Strategy_LoadAttemptState();
   Strategy_PrimeLateFridayAttach();
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_20011\",\"ea\":\"xng-thu-tue\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   const bool entry_blocked = Strategy_NoTradeFilter();

   g_strategy_new_d1_bar = QM_IsNewBar(_Symbol, PERIOD_D1);
   g_strategy_d1_bar_time = 0;
   g_entry_decision_ready = false;
   if(g_strategy_new_d1_bar)
     {
      MqlRates current_bar;
      ZeroMemory(current_bar);
      if(QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar))
         g_strategy_d1_bar_time = current_bar.time;
      QM_EquityStreamOnNewBar();
     }

   // Scheduled and stale exits stay active through news blackouts and invalid
   // entry parameters. News policy gates only new risk below this point.
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

   if(entry_blocked || !g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0)
      return;

   // Consume the only authorized weekly decision before news gating. This
   // makes a news-blocked Friday open terminal and restart deterministic.
   if(!Strategy_ConsumeFridayDecision())
      return;

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
