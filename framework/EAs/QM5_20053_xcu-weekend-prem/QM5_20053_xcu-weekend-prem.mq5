#property strict
#property version   "5.0"
#property description "QM5_20053 copper weekend premium"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20053;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

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
input int    strategy_entry_hour_broker    = 21;
input int    strategy_entry_grace_minutes  = 5;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 3.0;
input int    strategy_max_hold_days         = 4;
input int    strategy_max_spread_points     = 1000;

bool   g_attempt_armed = false;
int    g_last_attempt_day = 0;
string g_attempt_key = "";

bool Strategy_TimeParts(const datetime value, MqlDateTime &parts)
  {
   ZeroMemory(parts);
   return (value > 0 && TimeToStruct(value, parts));
  }

int Strategy_DayKey(const MqlDateTime &parts)
  {
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

bool Strategy_IsTarget()
  {
   return (_Symbol == "XCUUSD.DWX" && _Period == PERIOD_H1 &&
           qm_magic_slot_offset == 0);
  }

bool Strategy_InputsValid()
  {
   return (qm_ea_id == 20053 && strategy_entry_dow == 5 &&
           strategy_entry_hour_broker == 21 &&
           strategy_entry_grace_minutes == 5 &&
           strategy_atr_period_d1 == 20 &&
           MathAbs(strategy_atr_sl_mult - 3.0) <= 1.0e-12 &&
           strategy_max_hold_days == 4 &&
           strategy_max_spread_points == 1000 &&
           !qm_friday_close_enabled &&
           qm_friday_close_hour_broker == 21);
  }

bool Strategy_HasPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket != 0 && PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_SpreadOK()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(ask > bid && (ask - bid) / point > (double)strategy_max_spread_points)
      return false;
   return true;
  }

void Strategy_LoadAttemptState()
  {
   g_attempt_key = StringFormat("QM5_%d_XCU_WKEND_ATTEMPT", qm_ea_id);
   g_last_attempt_day = 0;
   if(GlobalVariableCheck(g_attempt_key))
      g_last_attempt_day = (int)GlobalVariableGet(g_attempt_key);
  }

bool Strategy_RecordAttempt(const int day_key)
  {
   if(day_key <= 0 || day_key == g_last_attempt_day)
      return false;
   g_last_attempt_day = day_key;
   return (GlobalVariableSet(g_attempt_key, (double)day_key) > 0);
  }

// No Trade Filter (time, spread, news): consume the weekly attempt before the
// framework news gate. Only the first eligible tick can arm the entry path.
bool Strategy_NoTradeFilter()
  {
   g_attempt_armed = false;
   if(!Strategy_IsTarget() || !Strategy_InputsValid() || Strategy_HasPosition())
      return true;

   MqlDateTime now;
   if(!Strategy_TimeParts(TimeCurrent(), now) ||
      now.day_of_week != strategy_entry_dow ||
      now.hour != strategy_entry_hour_broker ||
      now.min >= strategy_entry_grace_minutes)
      return true;

   g_attempt_armed = Strategy_RecordAttempt(Strategy_DayKey(now));
   return !g_attempt_armed;
  }

// Trade Entry: one long market order with the card's D1 ATR hard stop.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "XCU_WEEKEND_PREM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_attempt_armed || Strategy_HasPosition() || !Strategy_SpreadOK())
      return false;

   const double entry = QM_EntryMarketPrice(QM_BUY);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr_d1 <= 0.0)
      return false;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_d1,
                                strategy_atr_sl_mult);
   return (req.sl > 0.0);
  }

// Trade Management: no trailing, break-even, partial close, or scale-in.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: first Monday H1 boundary, with a four-calendar-day stale guard.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   MqlDateTime now;
   if(!Strategy_TimeParts(TimeCurrent(), now))
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now.day_of_week == 1 && now.hour == 0)
         return true;
      if(opened > 0 &&
         (long)(TimeCurrent() - opened) >=
         (long)strategy_max_hold_days * 86400L)
         return true;
     }
   return false;
  }

// News Filter Hook: P8 remains callable; central framework logic gates entries.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!Strategy_IsTarget() || !Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT,
                        RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   Strategy_LoadAttemptState();
   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_20053\",\"ea\":\"xcu-weekend-prem\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket != 0 && PositionSelectByTicket(ticket) &&
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            (int)PositionGetInteger(POSITION_MAGIC) == magic)
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(Strategy_NoTradeFilter())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows || !QM_IsNewBar())
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
