#property strict
#property version   "5.0"
#property description "QM5_41151 USDJPY Asia/Tokyo local-session inventory drift"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Approved card: QM5_41151_usdjpy-local-session-inventory-drift
// Source: Breedon & Ranaldo (2013), Intraday Patterns in FX Returns and Order Flow
// =============================================================================

#define STRATEGY_EA_ID             41151
#define STRATEGY_SESSION_OPEN_HOUR 9
#define STRATEGY_SESSION_END_HOUR  18
#define STRATEGY_NEWS_QUERY_COUNT  9

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = STRATEGY_EA_ID;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE60;
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
input int    strategy_atr_period_h1       = 14;
input double strategy_hard_stop_atr       = 1.5;

string g_attempt_state_key = "";
int    g_local_date_key = 0;
bool   g_local_date_consumed = true;
bool   g_closed_this_tick = false;

bool Strategy_DoubleEquals(const double lhs, const double rhs)
  {
   return (MathAbs(lhs - rhs) <= 1e-10);
  }

bool Strategy_ParametersValid()
  {
   return (qm_ea_id == STRATEGY_EA_ID &&
           qm_magic_slot_offset == 0 &&
           strategy_atr_period_h1 == 14 &&
           Strategy_DoubleEquals(strategy_hard_stop_atr, 1.5) &&
           Strategy_DoubleEquals(RISK_PERCENT, 0.0) &&
           MathIsValidNumber(RISK_FIXED) && RISK_FIXED > 0.0 &&
           MathIsValidNumber(PORTFOLIO_WEIGHT) &&
           PORTFOLIO_WEIGHT > 0.0 && PORTFOLIO_WEIGHT <= 1.0 &&
           MathIsValidNumber(qm_stress_reject_probability) &&
           qm_stress_reject_probability >= 0.0 &&
           qm_stress_reject_probability <= 1.0);
  }

datetime Strategy_UTCToTokyoLocal(const datetime utc_time)
  {
   if(utc_time <= 0)
      return 0;
   return utc_time + 9 * 3600;
  }

bool Strategy_TokyoLocalToUTC(const datetime local_time, datetime &utc_time)
  {
   utc_time = 0;
   if(local_time <= 0)
      return false;
   const datetime candidate = local_time - 9 * 3600;
   if(candidate <= 0 || Strategy_UTCToTokyoLocal(candidate) != local_time)
      return false;
   utc_time = candidate;
   return true;
  }

int Strategy_DateKey(const datetime local_time)
  {
   if(local_time <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(local_time, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

bool Strategy_CurrentTokyoTime(datetime &local_time)
  {
   local_time = Strategy_UTCToTokyoLocal(QM_BrokerToUTC(TimeCurrent()));
   return (local_time > 0);
  }

bool Strategy_HistoryConsumedDate(const int date_key, const datetime broker_now,
                                  bool &consumed)
  {
   consumed = true;
   if(date_key <= 0 || broker_now <= 0 ||
      !HistorySelect(broker_now - 4 * 86400, broker_now))
      return false;

   const long magic = (long)QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int index = 0; index < total; ++index)
     {
      const ulong deal = HistoryDealGetTicket(index);
      if(deal == 0 || HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_broker = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const datetime deal_local =
         Strategy_UTCToTokyoLocal(QM_BrokerToUTC(deal_broker));
      if(Strategy_DateKey(deal_local) == date_key)
        {
         consumed = true;
         return true;
        }
     }
   consumed = false;
   return true;
  }

bool Strategy_RefreshDateState(const datetime local_now)
  {
   const int date_key = Strategy_DateKey(local_now);
   if(date_key <= 0)
      return false;
   if(date_key == g_local_date_key)
      return true;

   g_local_date_key = date_key;
   g_local_date_consumed = true;

   bool consumed_from_history = true;
   if(!Strategy_HistoryConsumedDate(date_key, TimeCurrent(), consumed_from_history))
      return false;

   bool consumed_from_global = false;
   if(GlobalVariableCheck(g_attempt_state_key))
     {
      const double stored = GlobalVariableGet(g_attempt_state_key);
      if(!MathIsValidNumber(stored) || stored < 0.0)
         return false;
      consumed_from_global = ((int)MathRound(stored) == date_key);
     }
   g_local_date_consumed = (consumed_from_history || consumed_from_global);
   return true;
  }

bool Strategy_ConsumeDateBeforeSubmission()
  {
   if(g_local_date_key <= 0 || g_local_date_consumed)
      return false;
   ResetLastError();
   if(GlobalVariableSet(g_attempt_state_key, (double)g_local_date_key) == 0)
     {
      QM_LogEvent(QM_ERROR, "SESSION_ATTEMPT_STATE_FAILED",
                  StringFormat("{\"date_key\":%d,\"error\":%d}",
                               g_local_date_key, GetLastError()));
      return false;
     }
   g_local_date_consumed = true;
   GlobalVariablesFlush();
   return true;
  }

bool Strategy_IsEntryBar(const datetime local_bar_open)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(local_bar_open, parts))
      return false;
   return (parts.day_of_week >= MONDAY && parts.day_of_week <= FRIDAY &&
           parts.hour == STRATEGY_SESSION_OPEN_HOUR &&
           parts.min == 0 && parts.sec == 0);
  }

bool Strategy_SessionNewsClear(const datetime local_bar_open)
  {
   MqlDateTime anchor;
   ZeroMemory(anchor);
   if(!TimeToStruct(local_bar_open, anchor))
      return false;
   anchor.min = 0;
   anchor.sec = 0;

   // Query each trailing one-hour slice at 10:00..18:00 JST. The union is
   // exactly the owned [09:00,18:00] interval. Fresh fails closed when the
   // deterministic tester calendar or live calendar is stale/unavailable.
   for(int index = 0; index < STRATEGY_NEWS_QUERY_COUNT; ++index)
     {
      anchor.hour = STRATEGY_SESSION_OPEN_HOUR + index + 1;
      const datetime local_anchor = StructToTime(anchor);
      datetime utc_anchor = 0;
      if(!Strategy_TokyoLocalToUTC(local_anchor, utc_anchor))
         return false;
      const datetime broker_anchor = QM_UTCToBroker(utc_anchor);
      if(broker_anchor <= 0 ||
         !QM_NewsAllowsTrade2Fresh(_Symbol, broker_anchor,
                                   QM_NEWS_TEMPORAL_PRE60,
                                   QM_NEWS_COMPLIANCE_NONE))
         return false;
     }
   return true;
  }

void Strategy_CloseAllOwned(const QM_ExitReason reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
   g_closed_this_tick = true;
  }

bool Strategy_OwnershipIntegrityOK()
  {
   const int magic = QM_FrameworkMagic();
   int owned = 0;
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ++owned;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop = PositionGetDouble(POSITION_SL);
      const double target = PositionGetDouble(POSITION_TP);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(symbol != _Symbol || type != POSITION_TYPE_BUY ||
         !MathIsValidNumber(open_price) || open_price <= 0.0 ||
         !MathIsValidNumber(stop) || stop >= open_price ||
         !MathIsValidNumber(target) || target != 0.0 ||
         !MathIsValidNumber(volume) || volume <= 0.0)
         return false;
     }
   return (owned <= 1);
  }

bool Strategy_HasOwnedPosition()
  {
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

bool Strategy_ExitDue(const datetime local_now)
  {
   if(!Strategy_HasOwnedPosition())
      return false;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(local_now, parts))
      return true;
   return (Strategy_DateKey(local_now) != g_local_date_key ||
           parts.hour >= STRATEGY_SESSION_END_HOUR ||
           parts.hour < STRATEGY_SESSION_OPEN_HOUR);
  }

bool Strategy_BuildEntry(const datetime local_bar_open, QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   if(g_local_date_consumed || g_closed_this_tick ||
      Strategy_HasOwnedPosition() || !Strategy_IsEntryBar(local_bar_open) ||
      !Strategy_SessionNewsClear(local_bar_open))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period_h1, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(!MathIsValidNumber(atr) || atr <= 0.0 ||
      !MathIsValidNumber(bid) || !MathIsValidNumber(ask) ||
      !MathIsValidNumber(point) || bid <= 0.0 || ask < bid || point <= 0.0)
      return false;

   const double stop =
      QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_hard_stop_atr);
   const double stop_points = (ask - stop) / point;
   const long broker_stop_points =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(!MathIsValidNumber(stop) || stop >= bid ||
      !MathIsValidNumber(stop_points) || stop_points <= 0.0 ||
      (broker_stop_points > 0 && stop_points < (double)broker_stop_points) ||
      QM_LotsForRiskAtEntry(_Symbol, stop_points, ORDER_TYPE_BUY, ask) <= 0.0)
      return false;

   if(!Strategy_ConsumeDateBeforeSubmission())
      return false;

   req.type = QM_BUY;
   req.price = ask;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = "41151_tokyo_inventory_buy";
   return true;
  }

// -----------------------------------------------------------------------------
// Canonical five strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_OwnershipIntegrityOK())
     {
      QM_LogEvent(QM_ERROR, "SYMBOL_GUARD_VIOLATION",
                  "{\"detail\":\"ownership_integrity_fault\"}");
      Strategy_CloseAllOwned(QM_EXIT_KILLSWITCH);
      return true;
     }

   datetime local_now = 0;
   if(!Strategy_CurrentTokyoTime(local_now) ||
      !Strategy_RefreshDateState(local_now))
     {
      if(Strategy_HasOwnedPosition())
         Strategy_CloseAllOwned(QM_EXIT_KILLSWITCH);
      return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime bar_broker = iTime(_Symbol, PERIOD_H1, 0); // perf-allowed: one current-bar timestamp behind the new-bar gate.
   const datetime local_bar_open =
      Strategy_UTCToTokyoLocal(QM_BrokerToUTC(bar_broker));
   if(bar_broker <= 0 || local_bar_open <= 0 ||
      !Strategy_RefreshDateState(local_bar_open))
      return false;
   return Strategy_BuildEntry(local_bar_open, req);
  }

void Strategy_ManageOpenPosition()
  {
   // The approved card defines only the initial hard stop and the time exit.
  }

bool Strategy_ExitSignal()
  {
   datetime local_now = 0;
   if(!Strategy_CurrentTokyoTime(local_now))
      return Strategy_HasOwnedPosition();
   return Strategy_ExitDue(local_now);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The entry hook checks the complete owned interval with uncached freshness.
   return false;
  }

int OnInit()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1 || !Strategy_ParametersValid() ||
      !SymbolSelect(_Symbol, true))
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30, 30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_H1,
         QM_FRIDAY_CLOSE_CARD_RULE,
         "Approved Tokyo intraday card exits at 18:00 JST and retains the framework Friday fail-safe"))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   if(QM_MagicChecked(qm_ea_id, 0, _Symbol) <= 0)
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     20,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());
   string symbols[1];
   symbols[0] = _Symbol;
   QM_SymbolGuardInit(symbols);
   QM_BasketWarmupHistory(symbols, PERIOD_H1,
                          strategy_atr_period_h1 + 8);

   g_attempt_state_key =
      StringFormat("QM5_%d_TOKYO_ATTEMPT_%d", qm_ea_id, QM_FrameworkMagic());
   datetime local_now = 0;
   if(!Strategy_CurrentTokyoTime(local_now) ||
      !Strategy_RefreshDateState(local_now))
     {
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_41151\",\"session\":\"Asia/Tokyo 09:00-18:00\"}");
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
   g_closed_this_tick = false;

   if(!QM_KillSwitchCheck())
      return;
   if(Strategy_NewsFilterHook(TimeCurrent()))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseAllOwned(QM_EXIT_STRATEGY);
      return;
     }

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
      return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
     {
      ulong ticket = 0;
      QM_TM_OpenPosition(req, ticket);
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
