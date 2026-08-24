#property strict
#property version   "5.0"
#property description "QM5_12922 Ariel First-Half-of-Month Effect (Equity Index)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12922
// Strategy card: QM5_12922 ariel-first-half-month-idx, G0 APPROVED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 12922;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 3.0;
input int    strategy_hold_trading_days  = 9;
input bool   strategy_require_d1         = true;

const int STRATEGY_D1_LOOKBACK_LIMIT = 32;
const int STRATEGY_MACRO_DAY_LIMIT   = 4096;

enum StrategyMacroDayState
  {
   STRATEGY_MACRO_DATA_ERROR = -1,
   STRATEGY_MACRO_CLEAR      = 0,
   STRATEGY_MACRO_BLOCK      = 1
  };

int  g_strategy_last_month_key           = 0;
int  g_strategy_trading_day_index        = 0;
int  g_strategy_last_traded_month_key    = 0;
bool g_strategy_entry_deferred           = false;
bool g_strategy_entry_due                = false;
bool g_strategy_exit_due                 = false;
int  g_strategy_macro_day_keys[];
int  g_strategy_calendar_first_day_key   = 0;
int  g_strategy_calendar_last_day_key    = 0;
bool g_strategy_calendar_loaded          = false;

int Strategy_DayKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime Strategy_MonthStart(const int month_key)
  {
   if(month_key < 190001 || month_key > 299912)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = month_key / 100;
   parts.mon = month_key % 100;
   parts.day = 1;
   if(parts.mon < 1 || parts.mon > 12)
      return 0;
   return StructToTime(parts);
  }

datetime Strategy_DayStart(const int day_key)
  {
   if(day_key < 19000101 || day_key > 29991231)
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

// Count current-month D1 sessions through the framework calendar helper only.
// The fixed 32-bar cap exceeds every possible monthly trading-session count.
int Strategy_GetTradingDayOfMonth()
  {
   const int current_month = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   if(current_month <= 0)
      return 0;

   for(int shift = 0; shift < STRATEGY_D1_LOOKBACK_LIMIT; ++shift)
     {
      const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, shift);
      if(month_key <= 0)
         return 0;
      if(month_key != current_month)
         return shift;
     }
   return 0;
  }

bool Strategy_IsNamedMacroEvent(const string raw_currency,
                                const string raw_event_name)
  {
   const string currency = QM_NewsUpper(QM_NewsStripQuotes(raw_currency));
   const string event_name = QM_NewsUpper(QM_NewsStripQuotes(raw_event_name));
   if(currency == "USD")
     {
      if(event_name == "NON-FARM EMPLOYMENT CHANGE" ||
         event_name == "NONFARM PAYROLLS")
         return true;
      if(event_name == "FEDERAL FUNDS RATE" ||
         event_name == "FOMC STATEMENT" ||
         event_name == "FOMC ECONOMIC PROJECTIONS")
         return true;
     }
   if(currency == "EUR")
     {
      if(event_name == "MAIN REFINANCING RATE" ||
         event_name == "ECB PRESS CONFERENCE" ||
         StringFind(event_name, "ECB MONETARY POLICY") >= 0)
         return true;
     }
   return false;
  }

bool Strategy_OpenCalendarFile(const string path, int &handle)
  {
   handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
      handle = FileOpen(path,
                        FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      const string base = QM_NewsBasename(path);
      if(StringLen(base) > 0)
         handle = FileOpen(base,
                           FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON);
     }
   return (handle != INVALID_HANDLE);
  }

bool Strategy_PushMacroDay(const int day_key)
  {
   if(day_key <= 0)
      return false;
   const int count = ArraySize(g_strategy_macro_day_keys);
   if(count < 0 || count >= STRATEGY_MACRO_DAY_LIMIT)
      return false;
   if(count > 0 && g_strategy_macro_day_keys[count - 1] == day_key)
      return true;
   for(int index = 0; index < count; ++index)
      if(g_strategy_macro_day_keys[index] == day_key)
         return true;
   if(ArrayResize(g_strategy_macro_day_keys, count + 1) != count + 1)
      return false;
   g_strategy_macro_day_keys[count] = day_key;
   return true;
  }

bool Strategy_LoadTesterMacroCalendar()
  {
   ArrayResize(g_strategy_macro_day_keys, 0);
   g_strategy_calendar_first_day_key = 0;
   g_strategy_calendar_last_day_key = 0;
   g_strategy_calendar_loaded = false;

   string calendar_path = g_qm_news_calendar_path_primary;
   if(StringLen(QM_NewsTrim(calendar_path)) == 0)
      calendar_path = g_qm_news_base_dir + "\\news_calendar_2015_2025.csv";

   int handle = INVALID_HANDLE;
   if(!Strategy_OpenCalendarFile(calendar_path, handle))
      return false;

   bool first_line = true;
   int datetime_index = -1;
   int currency_index = -1;
   int event_index = -1;
   int impact_index = -1;
   int parsed_rows = 0;
   while(!FileIsEnding(handle))
     {
      const string line = FileReadString(handle);
      if(StringLen(line) == 0)
         continue;
      string fields[];
      if(!QM_NewsSplitCsvLine(line, fields))
         continue;
      const int field_count = ArraySize(fields);
      if(field_count <= 0)
         continue;

      if(first_line)
        {
         first_line = false;
         for(int index = 0; index < field_count; ++index)
           {
            const string header = QM_NewsUpper(QM_NewsStripQuotes(fields[index]));
            if(header == "DATETIME" || header == "DATETIME_UTC" || header == "UTC_DATETIME")
               datetime_index = index;
            else if(header == "CURRENCY")
               currency_index = index;
            else if(header == "EVENT" || header == "EVENT_NAME" || header == "NAME")
               event_index = index;
            else if(header == "IMPACT")
               impact_index = index;
           }
         if(datetime_index < 0 || currency_index < 0 || event_index < 0 || impact_index < 0)
           {
            FileClose(handle);
            return false;
           }
         continue;
        }

      if(datetime_index >= field_count || currency_index >= field_count ||
         event_index >= field_count || impact_index >= field_count)
         continue;
      datetime event_utc = 0;
      if(!QM_NewsParseDateTimeUTC(fields[datetime_index], event_utc))
         continue;
      const datetime event_broker = QM_UTCToBroker(event_utc);
      const int day_key = Strategy_DayKey(event_broker);
      if(day_key <= 0)
         continue;
      parsed_rows++;
      if(g_strategy_calendar_first_day_key == 0 || day_key < g_strategy_calendar_first_day_key)
         g_strategy_calendar_first_day_key = day_key;
      if(day_key > g_strategy_calendar_last_day_key)
         g_strategy_calendar_last_day_key = day_key;

      if(QM_NewsImpactUpper(fields[impact_index]) != "HIGH" ||
         !Strategy_IsNamedMacroEvent(fields[currency_index], fields[event_index]))
         continue;
      if(!Strategy_PushMacroDay(day_key))
        {
         FileClose(handle);
         return false;
        }
     }
   FileClose(handle);
   g_strategy_calendar_loaded = (parsed_rows > 0 &&
                                 g_strategy_calendar_first_day_key > 0 &&
                                 g_strategy_calendar_last_day_key >= g_strategy_calendar_first_day_key &&
                                 ArraySize(g_strategy_macro_day_keys) > 0);
   return g_strategy_calendar_loaded;
  }

StrategyMacroDayState Strategy_TesterMacroDayState(const int day_key)
  {
   if(!g_strategy_calendar_loaded || day_key < g_strategy_calendar_first_day_key ||
      day_key > g_strategy_calendar_last_day_key)
      return STRATEGY_MACRO_DATA_ERROR;
   const int count = ArraySize(g_strategy_macro_day_keys);
   if(count <= 0 || count > STRATEGY_MACRO_DAY_LIMIT)
      return STRATEGY_MACRO_DATA_ERROR;
   for(int index = 0; index < count; ++index)
      if(g_strategy_macro_day_keys[index] == day_key)
         return STRATEGY_MACRO_BLOCK;
   return STRATEGY_MACRO_CLEAR;
  }

StrategyMacroDayState Strategy_LiveMacroDayState(const int day_key)
  {
   const datetime day_start = Strategy_DayStart(day_key);
   if(day_start <= 0)
      return STRATEGY_MACRO_DATA_ERROR;

   MqlCalendarValue values[];
   const int count = CalendarValueHistory(values, day_start, day_start + 86399);
   if(count < 0 || count > ArraySize(values))
      return STRATEGY_MACRO_DATA_ERROR;
   if(count == 0)
      return QM_NewsLiveCalendarHealthy() ? STRATEGY_MACRO_CLEAR : STRATEGY_MACRO_DATA_ERROR;

   for(int index = 0; index < count; ++index)
     {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[index].event_id, event))
         return STRATEGY_MACRO_DATA_ERROR;
      if(event.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         return STRATEGY_MACRO_DATA_ERROR;
      if(Strategy_IsNamedMacroEvent(country.currency, event.name))
         return STRATEGY_MACRO_BLOCK;
     }
   return STRATEGY_MACRO_CLEAR;
  }

StrategyMacroDayState Strategy_MacroDayState(const int day_key)
  {
   if(day_key <= 0)
      return STRATEGY_MACRO_DATA_ERROR;
   if(MQLInfoInteger(MQL_TESTER))
      return Strategy_TesterMacroDayState(day_key);
   return Strategy_LiveMacroDayState(day_key);
  }

bool Strategy_AlreadyTradedThisMonth(const int month_key, bool &known)
  {
   known = false;
   if(g_strategy_last_traded_month_key == month_key)
     {
      known = true;
      return true;
     }
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
     {
      known = true;
      return true;
     }

   const datetime month_start = Strategy_MonthStart(month_key);
   const datetime now = TimeCurrent();
   if(month_start <= 0 || now < month_start || !HistorySelect(month_start, now))
      return false;
   const int deals = HistoryDealsTotal();
   if(deals < 0)
      return false;
   for(int index = deals - 1; index >= 0; --index)
     {
      const ulong ticket = HistoryDealGetTicket(index);
      if(ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != QM_FrameworkMagic())
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
        {
         known = true;
         return true;
        }
     }
   known = true;
   return false;
  }

bool Strategy_ReconstructCalendarState()
  {
   g_strategy_entry_due = false;
   g_strategy_entry_deferred = false;
   g_strategy_exit_due = false;

   const int day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   const int month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int trading_day = Strategy_GetTradingDayOfMonth();
   if(day_key <= 0 || month_key <= 0 || trading_day <= 0)
      return false;

   g_strategy_last_month_key = month_key;
   g_strategy_trading_day_index = trading_day;
   g_strategy_exit_due = (trading_day > MathMax(1, strategy_hold_trading_days));

   bool history_known = false;
   const bool already_traded = Strategy_AlreadyTradedThisMonth(month_key, history_known);
   if(!history_known)
      return false;
   if(already_traded)
      return true;

   if(trading_day == 1)
     {
      const StrategyMacroDayState macro_state = Strategy_MacroDayState(day_key);
      if(macro_state == STRATEGY_MACRO_DATA_ERROR)
         return false;
      g_strategy_entry_deferred = (macro_state == STRATEGY_MACRO_BLOCK);
      g_strategy_entry_due = !g_strategy_entry_deferred;
     }
   else if(trading_day == 2)
     {
      const int prior_day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1);
      const StrategyMacroDayState macro_state = Strategy_MacroDayState(prior_day_key);
      if(macro_state == STRATEGY_MACRO_DATA_ERROR)
         return false;
      g_strategy_entry_deferred = (macro_state == STRATEGY_MACRO_BLOCK);
      g_strategy_entry_due = g_strategy_entry_deferred;
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_require_d1 && _Period != PERIOD_D1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
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
   req.reason = (g_strategy_trading_day_index == 1) ? "ARIEL_FIRST_HALF_MONTH_T1" : "ARIEL_FIRST_HALF_MONTH_T2_DEFERRED";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_strategy_entry_due)
      return false;

   if(strategy_require_d1 && _Period != PERIOD_D1)
      return false;
   if(strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const double stop = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
   if(stop <= 0.0 || stop >= ask)
      return false;

   req.price = ask;
   req.sl = NormalizeDouble(stop, _Digits);
   req.tp = 0.0;
   return ((ask - req.sl) / point > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // No intra-trade trailing or partial management in baseline card.
  }

bool Strategy_ExitSignal()
  {
   if(strategy_require_d1 && _Period != PERIOD_D1)
      return false;
   if(!g_strategy_exit_due)
      return false;
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(qm_friday_close_enabled)
     {
      Print("QM5_12922: Friday close must remain disabled for the card-mandated T+1 through T+9 hold");
      return INIT_PARAMETERS_INCORRECT;
     }
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

   if(MQLInfoInteger(MQL_TESTER) && !Strategy_LoadTesterMacroCalendar())
     {
      QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING,
                  "{\"component\":\"ariel_named_macro_calendar\",\"reason\":\"load_failed\"}");
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }
   if(!Strategy_ReconstructCalendarState())
     {
      QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING,
                  "{\"component\":\"ariel_calendar_state\",\"reason\":\"restart_reconstruction_failed\"}");
      QM_FrameworkShutdown();
      return INIT_FAILED;
     }

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12922\",\"ea\":\"ariel-first-half-month-idx\"}");
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(QM_IsNewBar(_Symbol, PERIOD_D1))
     {
      QM_EquityStreamOnNewBar();
      if(!Strategy_ReconstructCalendarState())
        {
         QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING,
                     "{\"component\":\"ariel_calendar_state\",\"reason\":\"d1_reconstruction_failed\"}");
         return;
        }
     }

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(g_strategy_entry_due)
     {
      bool news_allows = true;
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
         news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
      else
         news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);

      if(!news_allows)
         return;

      QM_EntryRequest req;
      ZeroMemory(req);
      if(Strategy_EntrySignal(req))
        {
         ulong out_ticket = 0;
         if(QM_TM_OpenPosition(req, out_ticket))
           {
            g_strategy_last_traded_month_key = g_strategy_last_month_key;
            g_strategy_entry_deferred = false;
            g_strategy_entry_due = false;
           }
        }
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
