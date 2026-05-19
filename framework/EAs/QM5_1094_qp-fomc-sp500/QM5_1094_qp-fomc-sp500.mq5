#property strict
#property version   "5.0"
#property description "QM5_1094 Quantpedia FOMC Meeting Effect - SP500"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1094;
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
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input int    strategy_time_stop_days     = 3;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 3.0;

const int STRATEGY_SYMBOLS = 3;
string g_strategy_symbols[3] = {"SP500.DWX", "NDX.DWX", "WS30.DWX"};
int    g_strategy_slots[3]   = {0, 1, 2};

const int FOMC_DATE_COUNT = 72;
int g_fomc_dates[72] =
  {
   20180131, 20180321, 20180502, 20180613, 20180801, 20180926, 20181108, 20181219,
   20190130, 20190320, 20190501, 20190619, 20190731, 20190918, 20191030, 20191211,
   20200129, 20200429, 20200610, 20200729, 20200916, 20201105, 20201216,
   20210127, 20210317, 20210428, 20210616, 20210728, 20210922, 20211103, 20211215,
   20220126, 20220316, 20220504, 20220615, 20220727, 20220921, 20221102, 20221214,
   20230201, 20230322, 20230503, 20230614, 20230726, 20230920, 20231101, 20231213,
   20240131, 20240320, 20240501, 20240612, 20240731, 20240918, 20241107, 20241218,
   20250129, 20250319, 20250507, 20250618, 20250730, 20250917, 20251029, 20251210,
   20260128, 20260318, 20260429, 20260617, 20260729, 20260916, 20261028, 20261209
  };

int g_last_entry_key = 0;
int g_last_exit_key = 0;
int g_active_meeting_key = 0;

int Strategy_DateKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
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

bool Strategy_IsFomcDateKey(const int key)
  {
   for(int i = 0; i < FOMC_DATE_COUNT; ++i)
      if(g_fomc_dates[i] == key)
         return true;
   return false;
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOLS; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
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

int Strategy_NextTradingDateKeyAfterClosedBar()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(current_bar <= 0)
      return 0;
   return Strategy_DateKey(current_bar);
  }

bool Strategy_LastClosedBarIsOneTradingDayBeforeFomc(int &meeting_key)
  {
   meeting_key = 0;
   const int next_key = Strategy_NextTradingDateKeyAfterClosedBar();
   if(next_key <= 0 || !Strategy_IsFomcDateKey(next_key))
      return false;

   const datetime prior_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(prior_bar <= 0)
      return false;

   meeting_key = next_key;
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

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1094_PRE_FOMC_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   int meeting_key = 0;
   if(!Strategy_LastClosedBarIsOneTradingDayBeforeFomc(meeting_key))
      return false;
   if(meeting_key == g_last_entry_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsTrade())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.symbol_slot = g_strategy_slots[Strategy_CurrentSymbolIndex()];
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   g_active_meeting_key = meeting_key;
   g_last_entry_key = meeting_key;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // The card specifies only a hard ATR stop; no trailing, partial, or BE logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1 || !Strategy_HasOpenPosition())
      return false;

   const int current_key = Strategy_DateKey(iTime(_Symbol, PERIOD_D1, 0));
   if(current_key <= 0 || current_key == g_last_exit_key)
      return false;

   int meeting_key = g_active_meeting_key;
   if(meeting_key <= 0)
     {
      const int entry_key = Strategy_OpenPositionEntryKey();
      for(int i = 0; i < FOMC_DATE_COUNT; ++i)
         if(g_fomc_dates[i] >= entry_key)
           {
            meeting_key = g_fomc_dates[i];
            break;
           }
     }

   if(meeting_key > 0 && current_key > meeting_key)
     {
      g_last_exit_key = current_key;
      return true;
     }

   if(meeting_key > 0 && strategy_time_stop_days > 0)
     {
      const datetime meeting_time = Strategy_DateFromKey(meeting_key);
      const datetime current_time = Strategy_DateFromKey(current_key);
      if(current_time > meeting_time + (datetime)(strategy_time_stop_days * 86400))
        {
         g_last_exit_key = current_key;
         return true;
        }
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   for(int i = 0; i < STRATEGY_SYMBOLS; ++i)
      SymbolSelect(g_strategy_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1094\",\"ea\":\"qp-fomc-sp500\"}");
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
