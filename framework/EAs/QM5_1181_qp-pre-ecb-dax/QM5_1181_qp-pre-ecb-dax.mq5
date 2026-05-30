#property strict
#property version   "5.0"
#property description "QM5_1181 Quantpedia Pre-ECB DAX Drift"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1181;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.0;
input bool   strategy_use_atr_stop       = true;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 3.0;
input int    strategy_min_d1_bars        = 80;
input int    strategy_time_stop_days     = 3;

const string STRATEGY_SYMBOL = "GER40.DWX";
const int    STRATEGY_SLOT   = 0;

const int ECB_DATE_COUNT = 50;
int g_ecb_dates[50] =
  {
   20210121, 20210311, 20210422, 20210610, 20210722, 20210909, 20211028, 20211216,
   20220203, 20220310, 20220414, 20220609, 20220721, 20220908, 20221027, 20221215,
   20230202, 20230316, 20230504, 20230615, 20230727, 20230914, 20231026, 20231214,
   20240125, 20240307, 20240411, 20240606, 20240718, 20240912, 20241017, 20241212,
   20250130, 20250306, 20250417, 20250605, 20250724, 20250911, 20251030, 20251218,
   20260205, 20260319, 20260430, 20260610, 20260723, 20260910, 20261029, 20261217,
   20270204, 20270318
  };

int g_last_entry_event_key = 0;
int g_last_exit_key = 0;
int g_active_event_key = 0;

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

bool Strategy_IsTradingWeekday(const datetime value)
  {
   const int dow = Strategy_DayOfWeek(value);
   return (dow >= 1 && dow <= 5);
  }

datetime Strategy_NextWeekday(datetime value)
  {
   datetime candidate = Strategy_DateFromKey(Strategy_DateKey(value)) + 86400;
   for(int i = 0; i < 7; ++i)
     {
      if(Strategy_IsTradingWeekday(candidate))
         return candidate;
      candidate += 86400;
     }
   return 0;
  }

bool Strategy_IsEcbDateKey(const int key)
  {
   for(int i = 0; i < ECB_DATE_COUNT; ++i)
      if(g_ecb_dates[i] == key)
         return true;
   return false;
  }

bool Strategy_HasOpenPosition()
  {
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
      return true;
     }
   return false;
  }

int Strategy_OpenPositionEntryKey()
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
      return Strategy_DateKey((datetime)PositionGetInteger(POSITION_TIME));
     }
   return 0;
  }

bool Strategy_D1HistoryReady()
  {
   if(iBars(_Symbol, PERIOD_D1) < strategy_min_d1_bars)
      return false;
   if(iClose(_Symbol, PERIOD_D1, 1) <= 0.0)
      return false;
   if(iClose(_Symbol, PERIOD_D1, 2) <= 0.0)
      return false;
   if(iClose(_Symbol, PERIOD_D1, 3) <= 0.0)
      return false;
   return true;
  }

double Strategy_MedianDailySpreadPoints()
  {
   const int n = strategy_spread_median_days;
   if(n <= 0 || n > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsTrade()
  {
   if(strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0)
      return true;

   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_TodayIsEntryWindow(int &event_key)
  {
   event_key = 0;
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0)
      return false;

   const datetime next_trading_day = Strategy_NextWeekday(current_d1);
   if(next_trading_day <= 0)
      return false;

   const int next_key = Strategy_DateKey(next_trading_day);
   if(!Strategy_IsEcbDateKey(next_key))
      return false;

   event_key = next_key;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1181_PRE_ECB_DAX_LONG";
   req.symbol_slot = STRATEGY_SLOT;
   req.expiration_seconds = 0;

   int event_key = 0;
   if(!Strategy_TodayIsEntryWindow(event_key))
      return false;
   if(event_key == g_last_entry_event_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_D1HistoryReady())
      return false;
   if(!Strategy_SpreadAllowsTrade())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   if(strategy_use_atr_stop)
     {
      req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
      if(req.sl <= 0.0 || req.sl >= entry)
         return false;
     }

   g_active_event_key = event_key;
   g_last_entry_event_key = event_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card authorizes only the initial ATR stop and fixed event-window exit.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1 || !Strategy_HasOpenPosition())
      return false;

   const int current_key = Strategy_DateKey(iTime(_Symbol, PERIOD_D1, 0));
   if(current_key <= 0 || current_key == g_last_exit_key)
      return false;

   int event_key = g_active_event_key;
   if(event_key <= 0)
     {
      const int entry_key = Strategy_OpenPositionEntryKey();
      for(int i = 0; i < ECB_DATE_COUNT; ++i)
         if(g_ecb_dates[i] >= entry_key)
           {
            event_key = g_ecb_dates[i];
            break;
           }
     }

   if(event_key > 0 && current_key >= event_key)
     {
      g_last_exit_key = current_key;
      return true;
     }

   if(event_key > 0 && strategy_time_stop_days > 0)
     {
      const datetime event_time = Strategy_DateFromKey(event_key);
      const datetime current_time = Strategy_DateFromKey(current_key);
      if(current_time > event_time + (datetime)(strategy_time_stop_days * 86400))
        {
         g_last_exit_key = current_key;
         return true;
        }
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   SymbolSelect(STRATEGY_SYMBOL, true);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1181\",\"ea\":\"qp-pre-ecb-dax\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
