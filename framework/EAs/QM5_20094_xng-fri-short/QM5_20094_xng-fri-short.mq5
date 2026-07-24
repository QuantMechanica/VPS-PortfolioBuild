#property strict
#property version   "5.0"
#property description "QM5_20094 XNG Friday One-Session Short"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20094 - XNG Friday One-Session Short
// -----------------------------------------------------------------------------
// Borowski (2016) natural-gas weekday carrier:
//   - SELL only at the opening of a broker Friday D1 bar
//   - exit at the first following D1 bar, with a one-day stale guard
//   - consume the exact-day attempt before news, spread or order checks
//   - frozen completed-bar ATR hard stop; no TP or price-direction filter
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20094;
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
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_dow           = 5;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 2.75;
input int    strategy_max_hold_days        = 1;
input int    strategy_max_spread_points    = 2500;

const int STRATEGY_ENTRY_GRACE_MINUTES = 5;

int      g_last_attempt_day_key = 0;
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

int Strategy_DayKeyForTime(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
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

datetime Strategy_DayStartForKey(const int day_key)
  {
   if(day_key < 19000101)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = day_key / 10000;
   parts.mon = (day_key / 100) % 100;
   parts.day = day_key % 100;
   if(parts.mon < 1 || parts.mon > 12 || parts.day < 1 || parts.day > 31)
      return 0;
   return StructToTime(parts);
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_20094_XNG_FRI_ATTEMPT_%d",
                       QM_FrameworkMagic());
  }

void Strategy_LoadAttemptState(const datetime reference_time)
  {
   g_attempt_state_key = Strategy_AttemptStateKey();
   g_last_attempt_day_key = 0;
   if(!GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_day_key = Strategy_DayKeyForTime(reference_time);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_day_key = (int)MathRound(stored);
   if(current_day_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_day_key >= 19000101 &&
      stored_day_key <= current_day_key)
     {
      g_last_attempt_day_key = stored_day_key;
      return;
     }

   // Tester agents can retain terminal globals between historical runs. A
   // marker from a later calendar day must not suppress an earlier replay.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordDayAttempt(const int day_key)
  {
   if(day_key <= 0 || g_attempt_state_key == "")
      return false;

   // Keep the process fail-closed even if terminal-global persistence fails.
   g_last_attempt_day_key = day_key;
   return (GlobalVariableSet(g_attempt_state_key, (double)day_key) > 0);
  }

bool Strategy_DayAlreadyEntered(const int day_key)
  {
   if(day_key <= 0 || g_last_attempt_day_key == day_key)
      return true;
   if(Strategy_HasOpenPosition())
      return true;

   const datetime day_start = Strategy_DayStartForKey(day_key);
   if(day_start <= 0 || !HistorySelect(day_start, TimeCurrent()))
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
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_DayKeyForTime(deal_time) == day_key)
         return true;
     }
   return false;
  }

bool Strategy_PrimeLateFridayAttach()
  {
   MqlRates current_bar;
   ZeroMemory(current_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 0, current_bar))
      return true;
   if(Strategy_DayOfWeek(current_bar.time) != strategy_entry_dow)
      return true;

   const datetime now = TimeCurrent();
   const long grace_seconds =
      (long)STRATEGY_ENTRY_GRACE_MINUTES * 60;
   if(now >= current_bar.time &&
      (long)(now - current_bar.time) <= grace_seconds)
      return true;

   // QM_IsNewBar reports an initialization edge on first use. Consume it and
   // persist the missed Friday decision when attaching after the only
   // authorized opening window.
   QM_IsNewBar(_Symbol, PERIOD_D1);
   const int day_key = Strategy_DayKeyForTime(current_bar.time);
   if(day_key == g_last_attempt_day_key)
      return true;
   return Strategy_RecordDayAttempt(day_key);
  }

bool Strategy_ConsumeFridayDecision()
  {
   g_entry_decision_ready = false;
   if(!g_strategy_new_d1_bar || g_strategy_d1_bar_time <= 0)
      return false;
   if(Strategy_DayOfWeek(g_strategy_d1_bar_time) != strategy_entry_dow)
      return false;

   const int day_key = Strategy_DayKeyForTime(g_strategy_d1_bar_time);
   if(day_key <= 0 || g_last_attempt_day_key == day_key)
      return false;

   if(Strategy_DayAlreadyEntered(day_key))
     {
      Strategy_RecordDayAttempt(day_key);
      return false;
     }

   // Consume before news, spread, ATR, price and order checks. A blocked or
   // rejected Friday signal is terminal for that broker day.
   if(!Strategy_RecordDayAttempt(day_key))
      return false;
   g_entry_decision_ready = true;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_ea_id != 20094 || qm_magic_slot_offset != 0)
      return true;
   if(!qm_friday_close_enabled ||
      qm_friday_close_hour_broker != 21)
      return true;
   if(strategy_entry_dow != 5)
      return true;
   if(strategy_atr_period != 20)
      return true;
   if(MathAbs(strategy_atr_sl_mult - 2.75) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 1)
      return true;
   if(strategy_max_spread_points != 2500)
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
   req.reason = "XNG_FRI_ONE_SESSION_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_entry_decision_ready ||
      !g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0)
      return false;

   long spread_points = 0;
   if(!SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spread_points))
      return false;
   if(spread_points < 0 ||
      (strategy_max_spread_points > 0 &&
       spread_points > strategy_max_spread_points))
      return false;

   const double atr_last =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_SELL);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                QM_SELL,
                                entry_price,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl) ||
      req.sl <= entry_price)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
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
      bool should_close = (opened <= 0);

      // Keep this true after the boundary tick so a rejected close is retried
      // throughout the first following D1 bar.
      if(!should_close && g_strategy_d1_bar_time > opened)
         should_close = true;

      if(!should_close &&
         now >= opened &&
         (long)(now - opened) >= hold_seconds)
         should_close = true;

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
         QM_FRIDAY_CLOSE_CARD_RULE,
         "Approved Friday card retains Friday 21 broker-time flattening"))
      return INIT_FAILED;

   Strategy_LoadAttemptState(TimeCurrent());
   if(!Strategy_PrimeLateFridayAttach())
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_20094\",\"ea\":\"xng-fri-short\"}");
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   const bool entry_blocked = Strategy_NoTradeFilter();

   g_strategy_new_d1_bar = QM_IsNewBar(_Symbol, PERIOD_D1);
   g_entry_decision_ready = false;
   if(g_strategy_new_d1_bar || g_strategy_d1_bar_time <= 0)
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

   // Time exits precede all entry and news gates. The retained current-bar
   // timestamp keeps a failed next-D1 close retryable on later ticks.
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

   if(entry_blocked ||
      !g_strategy_new_d1_bar ||
      g_strategy_d1_bar_time <= 0)
      return;

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
