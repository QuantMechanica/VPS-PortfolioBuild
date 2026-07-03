#property strict
#property version   "5.0"
#property description "QM5_12971 SPX Pre-FOMC Drift"

#include <QM/QM_Common.mqh>

#define QM12971_SYMBOL "SP500.DWX"
#define QM12971_TF PERIOD_M30

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12971;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pre_event_entry_hours = 24;
input int    strategy_pre_event_exit_min    = 30;
input int    strategy_atr_period            = 14;
input double strategy_sizing_stop_atr_mult  = 6.0;
input string strategy_calendar_path         = "D:\\QM\\data\\news_calendar\\news_calendar_2015_2025.csv";

datetime g_fomc_events[];
datetime g_active_event_utc = 0;
datetime g_last_entry_event_utc = 0;
bool     g_fomc_calendar_loaded = false;

bool QM12971_OpenCalendarFile(const string path, int &handle)
  {
   handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(handle == INVALID_HANDLE)
      handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      const string base = QM_NewsBasename(path);
      if(StringLen(base) > 0 && base != path)
         handle = FileOpen(base, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON);
     }
   return (handle != INVALID_HANDLE);
  }

bool QM12971_PushUniqueEvent(const datetime event_utc)
  {
   if(event_utc <= 0)
      return false;
   const int n = ArraySize(g_fomc_events);
   for(int i = 0; i < n; ++i)
     {
      if(g_fomc_events[i] == event_utc)
         return false;
     }
   ArrayResize(g_fomc_events, n + 1);
   g_fomc_events[n] = event_utc;
   return true;
  }

void QM12971_SortEvents()
  {
   const int n = ArraySize(g_fomc_events);
   for(int i = 1; i < n; ++i)
     {
      const datetime value = g_fomc_events[i];
      int j = i - 1;
      while(j >= 0 && g_fomc_events[j] > value)
        {
         g_fomc_events[j + 1] = g_fomc_events[j];
         --j;
        }
      g_fomc_events[j + 1] = value;
     }
  }

bool QM12971_LoadFomcEvents()
  {
   ArrayResize(g_fomc_events, 0);
   int handle = INVALID_HANDLE;
   if(!QM12971_OpenCalendarFile(strategy_calendar_path, handle))
     {
      QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING,
                  StringFormat("{\"component\":\"fomc_calendar\",\"path\":\"%s\"}",
                               QM_LoggerEscapeJson(strategy_calendar_path)));
      return false;
     }

   bool first_line = true;
   int rows = 0;
   while(!FileIsEnding(handle))
     {
      const string line = FileReadString(handle);
      if(StringLen(line) == 0)
         continue;

      string fields[];
      if(!QM_NewsSplitCsvLine(line, fields))
         continue;

      if(first_line)
        {
         first_line = false;
         const string header0 = QM_NewsUpper(QM_NewsStripQuotes(fields[0]));
         if(header0 == "DATETIME")
            continue;
        }

      if(ArraySize(fields) < 11)
         continue;

      const string currency = QM_NewsUpper(QM_NewsStripQuotes(fields[1]));
      const string event_name = QM_NewsUpper(QM_NewsStripQuotes(fields[2]));
      const string is_fomc = QM_NewsStripQuotes(fields[10]);
      if(currency != "USD" || is_fomc != "1")
         continue;
      if(StringFind(event_name, "FEDERAL FUNDS RATE") < 0)
         continue;

      datetime event_utc = 0;
      if(!QM_NewsParseDateTimeUTC(fields[0], event_utc))
         continue;
      if(QM12971_PushUniqueEvent(event_utc))
         ++rows;
     }

   FileClose(handle);
   QM12971_SortEvents();
   if(rows <= 0)
     {
      QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING,
                  "{\"component\":\"fomc_calendar\",\"reason\":\"no_federal_funds_events\"}");
      return false;
     }

   QM_LogEvent(QM_INFO, "FOMC_CALENDAR_LOADED",
               StringFormat("{\"events\":%d,\"first\":%I64d,\"last\":%I64d}",
                            rows,
                            (long)g_fomc_events[0],
                            (long)g_fomc_events[ArraySize(g_fomc_events) - 1]));
   return true;
  }

bool QM12971_FindTradableEvent(const datetime utc_now, datetime &event_utc)
  {
   event_utc = 0;
   const int n = ArraySize(g_fomc_events);
   const int entry_seconds = MathMax(1, strategy_pre_event_entry_hours) * 3600;
   const int exit_seconds = MathMax(1, strategy_pre_event_exit_min) * 60;
   for(int i = 0; i < n; ++i)
     {
      const datetime ev = g_fomc_events[i];
      if(ev <= g_last_entry_event_utc)
         continue;
      const datetime entry_from = ev - entry_seconds;
      const datetime exit_at = ev - exit_seconds;
      if(utc_now >= entry_from && utc_now < exit_at)
        {
         event_utc = ev;
         return true;
        }
      if(ev > utc_now + entry_seconds)
         break;
     }
   return false;
  }

datetime QM12971_InferOpenEvent(const datetime utc_now)
  {
   if(g_active_event_utc > 0)
      return g_active_event_utc;
   const int n = ArraySize(g_fomc_events);
   const int entry_seconds = MathMax(1, strategy_pre_event_entry_hours) * 3600;
   for(int i = 0; i < n; ++i)
     {
      const datetime ev = g_fomc_events[i];
      if(utc_now >= ev - entry_seconds && utc_now < ev)
         return ev;
      if(ev > utc_now + entry_seconds)
         break;
     }
   return 0;
  }

bool QM12971_HasOwnedPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

double QM12971_CurrentEntryPrice()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask > 0.0)
      return ask;
   const double last = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
   if(last > 0.0)
      return last;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid > 0.0)
      return bid;
   return 0.0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Symbol != QM12971_SYMBOL)
      return true;
   if((ENUM_TIMEFRAMES)_Period != QM12971_TF)
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   return !g_fomc_calendar_loaded;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM12971_HasOwnedPosition())
      return false;

   datetime event_utc = 0;
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(!QM12971_FindTradableEvent(utc_now, event_utc))
      return false;

   const double entry = QM12971_CurrentEntryPrice();
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sizing_stop_atr_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;
   req.reason = StringFormat("pre_fomc_%I64d", (long)event_utc);
   g_active_event_utc = event_utc;
   g_last_entry_event_utc = event_utc;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!QM12971_HasOwnedPosition())
     {
      g_active_event_utc = 0;
      return false;
     }

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   const datetime event_utc = QM12971_InferOpenEvent(utc_now);
   if(event_utc <= 0)
      return false;

   const datetime exit_at = event_utc - MathMax(1, strategy_pre_event_exit_min) * 60;
   if(utc_now >= exit_at)
     {
      g_active_event_utc = event_utc;
      return true;
     }
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

   if(!QM12971_LoadFomcEvents())
      return INIT_FAILED;
   g_fomc_calendar_loaded = true;

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_12971_spx-pre-fomc-drift\",\"scope\":\"SP500.DWX_M30_pre_fomc\"}");
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
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
