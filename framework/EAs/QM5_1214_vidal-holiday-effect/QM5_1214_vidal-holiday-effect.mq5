#property strict
#property version   "5.0"
#property description "QM5_1214 Vidal-Garcia Holiday Effect Index Window"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1214;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period_h1       = 20;
input double strategy_atr_sl_mult         = 1.3;
input int    strategy_entry_hour_broker   = 10;
input int    strategy_exit_hour_broker    = 21;
input bool   strategy_us_close_only       = false;
input bool   strategy_eu_prepost_two_day  = false;
input int    strategy_min_h1_bars         = 120;
input int    strategy_min_hold_h1_bars    = 4;
input int    strategy_max_spread_points   = 300;

#define QM5_1214_SYMBOL_COUNT 4

string g_symbols[QM5_1214_SYMBOL_COUNT] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "GER40.DWX"};
int    g_slots[QM5_1214_SYMBOL_COUNT]   = {0, 1, 2, 3};

int g_last_entry_event_key = 0;
int g_last_exit_key = 0;

int Strategy_DateKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_DateFromKey(const int key)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = key / 10000;
   dt.mon = (key / 100) % 100;
   dt.day = key % 100;
   return StructToTime(dt);
  }

int Strategy_DayOfWeek(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.day_of_week;
  }

int Strategy_Hour(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour;
  }

bool Strategy_IsTradingWeekday(const datetime value)
  {
   const int dow = Strategy_DayOfWeek(value);
   return (dow >= 1 && dow <= 5);
  }

datetime Strategy_AddDays(const datetime value, const int days)
  {
   return Strategy_DateFromKey(Strategy_DateKey(value)) + days * 86400;
  }

datetime Strategy_PreviousWeekday(datetime value)
  {
   datetime candidate = Strategy_AddDays(value, -1);
   for(int i = 0; i < 10; ++i)
     {
      if(Strategy_IsTradingWeekday(candidate))
         return candidate;
      candidate -= 86400;
     }
   return 0;
  }

datetime Strategy_NextWeekday(datetime value)
  {
   datetime candidate = Strategy_AddDays(value, 1);
   for(int i = 0; i < 10; ++i)
     {
      if(Strategy_IsTradingWeekday(candidate))
         return candidate;
      candidate += 86400;
     }
   return 0;
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1214_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

bool Strategy_IsUsSymbol()
  {
   return (_Symbol == "SP500.DWX" || _Symbol == "NDX.DWX" || _Symbol == "WS30.DWX");
  }

bool Strategy_IsEuSymbol()
  {
   return (_Symbol == "GER40.DWX");
  }

bool Strategy_KeyInArray(const int key, const int &values[])
  {
   for(int i = 0; i < ArraySize(values); ++i)
      if(values[i] == key)
         return true;
   return false;
  }

bool Strategy_IsUsHolidayKey(const int key)
  {
   static int dates[] =
     {
      20210101,20210118,20210215,20210402,20210531,20210705,20210906,20211125,20211224,
      20220117,20220221,20220415,20220530,20220620,20220704,20220905,20221124,20221226,
      20230102,20230116,20230220,20230407,20230529,20230619,20230704,20230904,20231123,20231225,
      20240101,20240115,20240219,20240329,20240527,20240619,20240704,20240902,20241128,20241225,
      20250101,20250120,20250217,20250418,20250526,20250619,20250704,20250901,20251127,20251225,
      20260101,20260119,20260216,20260403,20260525,20260619,20260703,20260907,20261126,20261225,
      20270101,20270118,20270215,20270326,20270531,20270618,20270705,20270906,20271125,20271224,
      20280117,20280221,20280414,20280529,20280619,20280704,20280904,20281123,20281225,
      20290101,20290115,20290219,20290330,20290528,20290619,20290704,20290903,20291122,20291225,
      20300101,20300121,20300218,20300419,20300527,20300619,20300704,20300902,20301128,20301225,
      20310101,20310120,20310217,20310411,20310526,20310619,20310704,20310901,20311127,20311225,
      20320101,20320119,20320216,20320326,20320531,20320618,20320705,20320906,20321125,20321224,
      20330117,20330221,20330415,20330530,20330620,20330704,20330905,20331124,20331226,
      20340102,20340116,20340220,20340407,20340529,20340619,20340704,20340904,20341123,20341225,
      20350101,20350115,20350219,20350323,20350528,20350619,20350704,20350903,20351122,20351225
     };
   return Strategy_KeyInArray(key, dates);
  }

bool Strategy_IsEuHolidayKey(const int key)
  {
   static int dates[] =
     {
      20210101,20210402,20210405,20210501,20211224,20211231,
      20220415,20220418,20221226,
      20230407,20230410,20230501,20231225,20231226,
      20240101,20240329,20240401,20240501,20241224,20241225,20241226,20241231,
      20250101,20250418,20250421,20250501,20251224,20251225,20251226,20251231,
      20260101,20260403,20260406,20260501,20261224,20261225,20261231,
      20270101,20270326,20270329,20271224,20271231,
      20280414,20280417,20280501,20281225,20281226,
      20290330,20290402,20290501,20291224,20291225,20291226,20291231,
      20300101,20300419,20300422,20300501,20301224,20301225,20301226,20301231,
      20310101,20310411,20310414,20310501,20311224,20311225,20311226,20311231,
      20320101,20320326,20320329,20321224,20321231,
      20330415,20330418,20330501,20331226,
      20340407,20340410,20340501,20341225,20341226,
      20350101,20350323,20350326,20350501,20351224,20351225,20351226,20351231
     };
   return Strategy_KeyInArray(key, dates);
  }

bool Strategy_HasOpenPosition(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

int Strategy_CountH1BarsForDate(const int day_key)
  {
   int count = 0;
   for(int shift = 0; shift < 72; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_H1, shift);
      if(bar_time <= 0)
         break;
      if(Strategy_DateKey(bar_time) == day_key)
         ++count;
     }
   return count;
  }

bool Strategy_EntryWindow(int &event_key, int &entry_key, int &exit_key)
  {
   event_key = 0;
   entry_key = 0;
   exit_key = 0;

   const datetime current_h1 = iTime(_Symbol, PERIOD_H1, 0);
   if(current_h1 <= 0)
      return false;
   const int current_key = Strategy_DateKey(current_h1);

   if(Strategy_IsUsSymbol())
     {
      const datetime next_day = Strategy_NextWeekday(current_h1);
      if(next_day <= 0)
         return false;
      const int next_key = Strategy_DateKey(next_day);
      if(!Strategy_IsUsHolidayKey(next_key))
         return false;
      event_key = next_key;
      entry_key = current_key;
      exit_key = current_key;
      return true;
     }

   if(Strategy_IsEuSymbol())
     {
      const datetime previous_day = Strategy_PreviousWeekday(current_h1);
      const datetime next_day = Strategy_NextWeekday(current_h1);
      if(previous_day <= 0)
         return false;

      const int prev_key = Strategy_DateKey(previous_day);
      if(Strategy_IsEuHolidayKey(prev_key))
        {
         event_key = prev_key;
         entry_key = current_key;
         exit_key = current_key;
         return true;
        }

      if(strategy_eu_prepost_two_day && next_day > 0)
        {
         const int next_key = Strategy_DateKey(next_day);
         if(Strategy_IsEuHolidayKey(next_key))
           {
            event_key = next_key;
            entry_key = current_key;
            exit_key = Strategy_DateKey(Strategy_NextWeekday(next_day));
            return true;
           }
        }
     }

   return false;
  }

bool Strategy_OpenPositionExitDue()
  {
   const datetime current_h1 = iTime(_Symbol, PERIOD_H1, 0);
   if(current_h1 <= 0)
      return false;

   const int current_key = Strategy_DateKey(current_h1);
   if(current_key == g_last_exit_key)
      return false;

   datetime open_time = 0;
   if(!Strategy_HasOpenPosition(open_time))
      return false;

   int event_key = 0;
   int entry_key = 0;
   int exit_key = 0;
   if(Strategy_EntryWindow(event_key, entry_key, exit_key))
     {
      if(current_key >= exit_key && Strategy_Hour(current_h1) >= strategy_exit_hour_broker)
        {
         g_last_exit_key = current_key;
         return true;
        }
     }

   if(Strategy_DateKey(open_time) < current_key && Strategy_Hour(current_h1) >= strategy_exit_hour_broker)
     {
      g_last_exit_key = current_key;
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(_Period != PERIOD_H1)
      return true;
   if(qm_magic_slot_offset != Strategy_CurrentSymbolSlot())
      return true;
   if(strategy_atr_period_h1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_entry_hour_broker < 0 || strategy_entry_hour_broker > 23)
      return true;
   if(strategy_exit_hour_broker < 0 || strategy_exit_hour_broker > 23)
      return true;
   if(strategy_min_hold_h1_bars < 4)
      return true;
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(Bars(_Symbol, PERIOD_H1) < strategy_min_h1_bars)
      return false;

   datetime open_time = 0;
   if(Strategy_HasOpenPosition(open_time))
      return false;

   int event_key = 0;
   int entry_key = 0;
   int exit_key = 0;
   if(!Strategy_EntryWindow(event_key, entry_key, exit_key))
      return false;
   if(event_key == g_last_entry_event_key)
      return false;

   const datetime current_h1 = iTime(_Symbol, PERIOD_H1, 0);
   const int current_hour = Strategy_Hour(current_h1);
   const int target_entry_hour = (strategy_us_close_only && Strategy_IsUsSymbol()) ? MathMax(0, strategy_exit_hour_broker - 1) : strategy_entry_hour_broker;
   if(current_hour < target_entry_hour)
      return false;
   if(Strategy_CountH1BarsForDate(entry_key) < strategy_min_hold_h1_bars)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period_h1, 1);
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, req.sl))
      return false;

   req.reason = "QM5_1214_VIDAL_HOLIDAY";
   g_last_entry_event_key = event_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed initial ATR stop plus holiday-window exits only.
  }

bool Strategy_ExitSignal()
  {
   return Strategy_OpenPositionExitDue();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1214\",\"ea\":\"vidal-holiday-effect\"}");
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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
