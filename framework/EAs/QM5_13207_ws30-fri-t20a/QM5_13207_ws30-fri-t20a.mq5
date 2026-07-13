#property strict
#property version   "5.0"
#property description "QM5_13207 WS30 Friday PM Long Trend20D Align"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13207;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_bars          = 56;
input double strategy_stop_atr          = 1.0;
input int    strategy_entry_hhmm_ny     = 1330;
input int    strategy_exit_hhmm_ny      = 1600;
input int    strategy_weekday_ny        = 5;

int g_entry_day_key = 0;

const int STRATEGY_TREND_NEWEST_SHIFT = 1;
const int STRATEGY_TREND_OLDEST_SHIFT = 1921;

datetime Strategy_BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return utc_time + (QM_IsUSDSTUTC(utc_time) ? -4 : -5) * 3600;
  }

bool Strategy_NewYorkParts(const datetime broker_time, MqlDateTime &parts)
  {
   if(broker_time <= 0)
      return false;
   return TimeToStruct(Strategy_BrokerToNewYork(broker_time), parts);
  }

int Strategy_NewYorkDayKey(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_NewYorkParts(broker_time, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_NewYorkHhmm(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_NewYorkParts(broker_time, parts))
      return -1;
   return parts.hour * 100 + parts.min;
  }

bool Strategy_IsEntryTime(const datetime broker_time)
  {
   MqlDateTime parts;
   if(!Strategy_NewYorkParts(broker_time, parts))
      return false;
   return (parts.day_of_week == strategy_weekday_ny &&
           parts.hour * 100 + parts.min == strategy_entry_hhmm_ny);
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HadEntryToday(const datetime broker_now)
  {
   const int day_key = Strategy_NewYorkDayKey(broker_now);
   if(day_key <= 0 || !HistorySelect(broker_now - 3 * 86400, broker_now))
      return true;
   const int magic = QM_FrameworkMagic();
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = HistoryDealGetTicket(index);
      if(ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(Strategy_NewYorkDayKey(deal_time) == day_key)
         return true;
     }
   return false;
  }

double Strategy_SimpleATR(const int shift)
  {
   if(strategy_atr_bars <= 0 || shift < 1)
      return 0.0;
   double total = 0.0;
   for(int offset = 0; offset < strategy_atr_bars; ++offset)
     {
      const int bar_shift = shift + offset;
      const double high = iHigh(_Symbol, PERIOD_M15, bar_shift);
      const double low = iLow(_Symbol, PERIOD_M15, bar_shift);
      const double previous_close = iClose(_Symbol, PERIOD_M15, bar_shift + 1);
      if(high <= 0.0 || low <= 0.0 || previous_close <= 0.0 || high < low)
         return 0.0;
      total += MathMax(high - low,
                       MathMax(MathAbs(high - previous_close),
                               MathAbs(low - previous_close)));
     }
   return total / strategy_atr_bars;
  }

bool Strategy_Trend20dAlign()
  {
   // Called only on the locked Friday entry bar. Shifts count observed M15 bars.
   const datetime newest_time = iTime(_Symbol, PERIOD_M15, STRATEGY_TREND_NEWEST_SHIFT);
   const datetime oldest_time = iTime(_Symbol, PERIOD_M15, STRATEGY_TREND_OLDEST_SHIFT);
   if(newest_time <= 0 || oldest_time <= 0 || oldest_time >= newest_time)
      return false;

   const double newest_close = iClose(_Symbol, PERIOD_M15, STRATEGY_TREND_NEWEST_SHIFT);
   const double oldest_close = iClose(_Symbol, PERIOD_M15, STRATEGY_TREND_OLDEST_SHIFT);
   if(!MathIsValidNumber(newest_close) || !MathIsValidNumber(oldest_close) ||
      newest_close <= 0.0 || oldest_close <= 0.0)
      return false;

   const double signed_return = newest_close / oldest_close - 1.0;
   return (MathIsValidNumber(signed_return) && signed_return > 0.0);
  }

bool Strategy_LockedInputsValid()
  {
   return (qm_ea_id == 13207 && qm_magic_slot_offset == 0 &&
           strategy_atr_bars == 56 &&
           MathAbs(strategy_stop_atr - 1.0) <= 1e-12 &&
           strategy_entry_hhmm_ny == 1330 &&
           strategy_exit_hhmm_ny == 1600 &&
           strategy_weekday_ny == 5);
  }

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &request)
  {
   request.type = QM_BUY;
   request.price = 0.0;
   request.sl = 0.0;
   request.tp = 0.0;
   request.reason = "";
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0;

   const datetime current_bar_time = iTime(_Symbol, PERIOD_M15, 0);
   if(!Strategy_IsEntryTime(current_bar_time))
      return false;
   const int day_key = Strategy_NewYorkDayKey(current_bar_time);
   if(day_key <= 0 || g_entry_day_key == day_key || Strategy_HasOurPosition() ||
       Strategy_HadEntryToday(TimeCurrent()))
       return false;
   if(!Strategy_Trend20dAlign())
      return false;

   const double atr = Strategy_SimpleATR(1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || ask <= 0.0)
      return false;
   request.price = ask;
   request.sl = NormalizeDouble(ask - strategy_stop_atr * atr, _Digits);
   if(request.sl <= 0.0 || request.sl >= ask)
      return false;
   request.reason = "WS30_FRI_PM_T20A";
   g_entry_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;
   const datetime broker_now = TimeCurrent();
   const int current_day_key = Strategy_NewYorkDayKey(broker_now);
   const int position_day_key = Strategy_NewYorkDayKey(
      (datetime)PositionGetInteger(POSITION_TIME));
   if(current_day_key <= 0 || position_day_key <= 0 ||
      current_day_key != position_day_key)
      return true;
   return Strategy_NewYorkHhmm(broker_now) >= strategy_exit_hhmm_ny;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(_Symbol != "WS30.DWX" || _Period != PERIOD_M15 ||
      !Strategy_LockedInputsValid())
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13207_ws30-fri-t20a\"}");
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
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || QM_FrameworkHandleFridayClose() || Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest request;
   if(Strategy_EntrySignal(request))
     {
      ulong ticket = 0;
      QM_TM_OpenPosition(request, ticket);
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
