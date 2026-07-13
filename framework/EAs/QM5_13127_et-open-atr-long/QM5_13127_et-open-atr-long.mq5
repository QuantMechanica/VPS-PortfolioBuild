#property strict
#property version   "5.0"
#property description "QM5_13127 NDX Session-Open ATR Breakout Long"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13127;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 20;
input double strategy_entry_atr_mult      = 0.30;
input double strategy_target_atr_mult     = 0.60;
input int    strategy_final_order_minutes = 30;
input double strategy_min_band_spreads    = 4.0;
input int    strategy_session_start_hhmm  = 1630;
input int    strategy_session_end_hhmm    = 2300;

int g_session_day = -1;
bool g_session_attempted = false;

int Strategy_Hhmm(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   TimeToStruct(value, parts);
   return parts.hour * 100 + parts.min;
  }

int Strategy_MinutesOfDay(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
  }

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   TimeToStruct(value, parts);
   return parts.year * 1000 + parts.day_of_year;
  }

bool Strategy_InSession(const datetime now)
  {
   const int minute = Strategy_MinutesOfDay(Strategy_Hhmm(now));
   return minute >= Strategy_MinutesOfDay(strategy_session_start_hhmm) &&
          minute < Strategy_MinutesOfDay(strategy_session_end_hhmm);
  }

bool Strategy_PastFinalOrderWindow(const datetime now)
  {
   if(!Strategy_InSession(now))
      return true;
   const int minute = Strategy_MinutesOfDay(Strategy_Hhmm(now));
   const int final_start = Strategy_MinutesOfDay(strategy_session_end_hhmm) -
                           MathMax(0, strategy_final_order_minutes);
   return minute >= final_start;
  }

datetime Strategy_SessionStart(const datetime now)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   TimeToStruct(now, parts);
   parts.hour = strategy_session_start_hhmm / 100;
   parts.min = strategy_session_start_hhmm % 100;
   parts.sec = 0;
   return StructToTime(parts);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

int Strategy_PendingBuyStops()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
         ++count;
     }
   return count;
  }

void Strategy_DeletePendingBuyStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
         QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

bool Strategy_CurrentSpread(double &spread)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   spread = ask - bid;
   return true;
  }

int Strategy_SecondsUntilSessionEnd(const datetime now)
  {
   const int minute = Strategy_MinutesOfDay(Strategy_Hhmm(now));
   const int end_minute = Strategy_MinutesOfDay(strategy_session_end_hhmm);
   return MathMax(60, (end_minute - minute) * 60);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != "NDX.DWX" || _Period != PERIOD_M5 || qm_magic_slot_offset != 0)
      return true;
   if(Strategy_HasOpenPosition() || Strategy_PendingBuyStops() > 0)
      return false;
   if(Strategy_PastFinalOrderWindow(TimeCurrent()))
      return true;

   double spread = 0.0;
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0 || !Strategy_CurrentSpread(spread))
      return true;
   return strategy_entry_atr_mult * atr < strategy_min_band_spreads * spread;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   const datetime now = TimeCurrent();
   const int day_key = Strategy_DayKey(now);
   if(day_key != g_session_day)
     {
      g_session_day = day_key;
      g_session_attempted = false;
     }
   if(g_session_attempted || Strategy_HasOpenPosition() || Strategy_PendingBuyStops() > 0)
      return false;
   if(Strategy_PastFinalOrderWindow(now))
      return false;

   const datetime session_start = Strategy_SessionStart(now);
   const int session_shift = iBarShift(_Symbol, _Period, session_start, false);
   if(session_shift < 0)
      return false;
   const double session_open = iOpen(_Symbol, _Period, session_shift); // perf-allowed: one fixed session-anchor read on the new-bar path
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   double spread = 0.0;
   if(session_open <= 0.0 || atr <= 0.0 || !Strategy_CurrentSpread(spread))
      return false;

   const double band = strategy_entry_atr_mult * atr;
   const double entry = QM_TM_NormalizePrice(_Symbol, session_open + band);
   const double stop = QM_TM_NormalizePrice(_Symbol, session_open - band);
   const double target = QM_TM_NormalizePrice(_Symbol, entry + strategy_target_atr_mult * atr);
   if(band < strategy_min_band_spreads * spread || entry <= 0.0 || stop <= 0.0 ||
      stop >= entry || target <= entry)
      return false;

   g_session_attempted = true;
   req.type = QM_BUY_STOP;
   req.price = entry;
   req.sl = stop;
   req.tp = target;
   req.reason = "ET_OPEN_ATR_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = Strategy_SecondsUntilSessionEnd(now);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_PendingBuyStops() > 0 && Strategy_PastFinalOrderWindow(TimeCurrent()))
      Strategy_DeletePendingBuyStops("session_final_order_window");
  }

bool Strategy_ExitSignal()
  {
   return Strategy_HasOpenPosition() && !Strategy_InSession(TimeCurrent());
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   const datetime now = TimeCurrent();
   if(Strategy_NewsFilterHook(now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) == magic)
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, now, qm_news_mode_legacy);
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
