#property strict
#property version   "5.0"
#property description "QM5_12972 GDAXI pre-ECB announcement drift"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12972 - GDAXI Pre-ECB Drift
// -----------------------------------------------------------------------------
// Low-frequency event anomaly:
//   - load local historical news calendar once at init
//   - key on EUR Main Refinancing Rate events
//   - buy the M30 bar ending about 24h before the event
//   - exit on the last M30 bar ending at least 30m before the event
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12972;
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
input int    strategy_pre_event_exit_minutes = 30;
input int    strategy_atr_period = 20;
input double strategy_atr_sl_mult = 3.0;
input int    strategy_max_hold_hours = 30;
input int    strategy_max_spread_points = 0;
input string strategy_calendar_file = "D:\\QM\\data\\news_calendar\\news_calendar_2015_2025.csv";
input string strategy_event_name_filter = "Main Refinancing Rate";

datetime g_ecb_event_utc[];
datetime g_ecb_event_broker[];
long     g_last_entry_event_key = 0;
bool     g_calendar_loaded = false;

bool Strategy_IsTarget()
  {
   return (_Symbol == "GDAXI.DWX" && _Period == PERIOD_M30 && qm_magic_slot_offset == 0);
  }

int Strategy_PeriodSeconds()
  {
   const int seconds = PeriodSeconds(PERIOD_M30);
   return (seconds > 0 ? seconds : 1800);
  }

datetime Strategy_FloorToM30(const datetime value)
  {
   const int seconds = Strategy_PeriodSeconds();
   return (datetime)(((long)value / seconds) * seconds);
  }

long Strategy_DateTimeKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (long)dt.year * 100000000L + (long)dt.mon * 1000000L + (long)dt.day * 10000L + (long)dt.hour * 100L + (long)dt.min;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_WideSpread()
  {
   if(strategy_max_spread_points <= 0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points > strategy_max_spread_points);
  }

bool Strategy_EventNameMatches(const string raw_name)
  {
   string event_name = QM_NewsUpper(QM_NewsStripQuotes(raw_name));
   string filter = QM_NewsUpper(QM_NewsTrim(strategy_event_name_filter));
   if(StringLen(filter) <= 0)
      return false;
   return (StringFind(event_name, filter) >= 0);
  }

bool Strategy_PushEcbEvent(const datetime event_utc)
  {
   if(event_utc <= 0)
      return false;
   const int n = ArraySize(g_ecb_event_utc);
   ArrayResize(g_ecb_event_utc, n + 1);
   ArrayResize(g_ecb_event_broker, n + 1);
   g_ecb_event_utc[n] = event_utc;
   g_ecb_event_broker[n] = QM_UTCToBroker(event_utc);
   return true;
  }

int Strategy_OpenCalendarFile()
  {
   int handle = FileOpen(strategy_calendar_file, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(handle != INVALID_HANDLE)
      return handle;

   handle = FileOpen(strategy_calendar_file, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON);
   if(handle != INVALID_HANDLE)
      return handle;

   const string base = QM_NewsBasename(strategy_calendar_file);
   if(StringLen(base) > 0 && base != strategy_calendar_file)
      handle = FileOpen(base, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON);
   return handle;
  }

bool Strategy_LoadEcbEvents()
  {
   ArrayResize(g_ecb_event_utc, 0);
   ArrayResize(g_ecb_event_broker, 0);
   g_calendar_loaded = false;

   const int handle = Strategy_OpenCalendarFile();
   if(handle == INVALID_HANDLE)
     {
      QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING, "{\"reason\":\"ecb_calendar_file_missing\"}");
      return false;
     }

   bool first_line = true;
   int loaded = 0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringLen(line) <= 0)
         continue;

      string fields[];
      if(!QM_NewsSplitCsvLine(line, fields))
         continue;

      if(first_line)
        {
         first_line = false;
         string header0 = QM_NewsUpper(QM_NewsStripQuotes(fields[0]));
         if(StringFind(header0, "DATE") >= 0 || StringFind(header0, "TIME") >= 0)
            continue;
        }

      if(ArraySize(fields) < 4)
         continue;

      const string currency = QM_NewsUpper(QM_NewsStripQuotes(fields[1]));
      if(currency != "EUR")
         continue;
      if(!Strategy_EventNameMatches(fields[2]))
         continue;
      if(QM_NewsImpactRank(QM_NewsImpactUpper(fields[3])) < QM_NewsImpactRank("HIGH"))
         continue;

      datetime event_utc = 0;
      if(!QM_NewsParseDateTimeUTC(fields[0], event_utc))
         continue;
      if(Strategy_PushEcbEvent(event_utc))
         loaded++;
     }

   FileClose(handle);
   g_calendar_loaded = (loaded > 0);

   const string payload = StringFormat("{\"events\":%d,\"filter\":\"%s\"}",
                                       loaded,
                                       QM_LoggerEscapeJson(strategy_event_name_filter));
   QM_LogEvent(g_calendar_loaded ? QM_INFO : QM_ERROR,
               g_calendar_loaded ? "ECB_SIGNAL_CALENDAR_LOADED" : SETUP_DATA_MISSING,
               payload);
   return g_calendar_loaded;
  }

datetime Strategy_EntryTimeBroker(const int index)
  {
   if(index < 0 || index >= ArraySize(g_ecb_event_broker))
      return 0;
   return Strategy_FloorToM30(g_ecb_event_broker[index] - strategy_pre_event_entry_hours * 3600);
  }

datetime Strategy_ExitTimeBroker(const int index)
  {
   if(index < 0 || index >= ArraySize(g_ecb_event_broker))
      return 0;
   return Strategy_FloorToM30(g_ecb_event_broker[index] - strategy_pre_event_exit_minutes * 60);
  }

int Strategy_FindEntryEvent(const datetime broker_now)
  {
   const int window_seconds = Strategy_PeriodSeconds();
   const int n = ArraySize(g_ecb_event_broker);
   for(int i = 0; i < n; ++i)
     {
      const datetime entry_time = Strategy_EntryTimeBroker(i);
      const datetime exit_time = Strategy_ExitTimeBroker(i);
      if(entry_time <= 0 || exit_time <= entry_time)
         continue;
      if(broker_now >= entry_time && broker_now < entry_time + window_seconds)
         return i;
      if(entry_time > broker_now + window_seconds)
         break;
     }
   return -1;
  }

int Strategy_FindOpenPositionEvent(const datetime broker_now)
  {
   const int n = ArraySize(g_ecb_event_broker);
   for(int i = 0; i < n; ++i)
     {
      const datetime event_time = g_ecb_event_broker[i];
      const datetime entry_time = Strategy_EntryTimeBroker(i);
      if(entry_time <= 0 || event_time <= 0)
         continue;
      if(broker_now < entry_time)
         break;
      if(broker_now <= event_time + 2 * 3600)
         return i;
     }
   return -1;
  }

bool Strategy_PositionExceededMaxHold()
  {
   const int max_hold_seconds = MathMax(1, strategy_max_hold_hours) * 3600;
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= max_hold_seconds)
         return true;
     }
   return false;
  }

bool Strategy_ShouldExitForEvent()
  {
   const datetime broker_now = TimeCurrent();
   const int event_index = Strategy_FindOpenPositionEvent(broker_now);
   if(event_index >= 0)
     {
      const datetime exit_time = Strategy_ExitTimeBroker(event_index);
      if(exit_time > 0 && broker_now >= exit_time)
         return true;
     }
   return Strategy_PositionExceededMaxHold();
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(!g_calendar_loaded)
      return true;
   if(strategy_pre_event_entry_hours <= 0 || strategy_pre_event_exit_minutes <= 0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_hours <= 0)
      return true;
   if(Strategy_WideSpread())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "GDAXI_PRE_ECB_DRIFT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   const int event_index = Strategy_FindEntryEvent(TimeCurrent());
   if(event_index < 0)
      return false;

   const long event_key = Strategy_DateTimeKey(g_ecb_event_broker[event_index]);
   if(event_key <= 0 || event_key == g_last_entry_event_key)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   g_last_entry_event_key = event_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   return Strategy_ShouldExitForEvent();
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

   if(!Strategy_LoadEcbEvents())
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12972\",\"ea\":\"gdaxi-pre-ecb-drift\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

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
