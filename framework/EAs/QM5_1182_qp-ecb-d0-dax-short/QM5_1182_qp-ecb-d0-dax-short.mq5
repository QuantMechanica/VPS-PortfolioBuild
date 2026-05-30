#property strict
#property version   "5.0"
#property description "QM5_1182 Quantpedia ECB D0 DAX Short"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1182;
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
input double strategy_atr_sl_mult        = 1.5;
input bool   strategy_use_atr_stop       = true;
input bool   strategy_skip_large_gap     = false;
input double strategy_gap_atr_mult       = 1.0;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 3.0;
input int    strategy_min_d1_bars        = 80;
input int    strategy_entry_hour_broker  = 9;
input int    strategy_entry_min_broker   = 0;
input int    strategy_exit_hour_broker   = 17;
input int    strategy_exit_min_broker    = 30;

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

int g_last_entry_key = 0;
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

bool Strategy_IsEcbDateKey(const int key)
  {
   for(int i = 0; i < ECB_DATE_COUNT; ++i)
      if(g_ecb_dates[i] == key)
         return true;
   return false;
  }

int Strategy_MinutesOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_EntryMinute()
  {
   return strategy_entry_hour_broker * 60 + strategy_entry_min_broker;
  }

int Strategy_ExitMinute()
  {
   return strategy_exit_hour_broker * 60 + strategy_exit_min_broker;
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

bool Strategy_HasPreEcbPosition()
  {
   const int pre_ecb_magic = 11810000;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == pre_ecb_magic)
         return true;
     }
   return false;
  }

bool Strategy_D1HistoryReady()
  {
   if(iBars(_Symbol, PERIOD_D1) < strategy_min_d1_bars)
      return false;
   if(iOpen(_Symbol, PERIOD_D1, 0) <= 0.0)
      return false;
   if(iClose(_Symbol, PERIOD_D1, 1) <= 0.0)
      return false;
   return true;
  }

bool Strategy_ReadD1Atr(double &atr_value)
  {
   atr_value = 0.0;
   if(strategy_atr_period <= 0)
      return false;

   atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   return true;
  }

bool Strategy_GapAllowsTrade()
  {
   if(!strategy_skip_large_gap || strategy_gap_atr_mult <= 0.0)
      return true;

   double atr = 0.0;
   if(!Strategy_ReadD1Atr(atr))
      return false;

   const double today_open = iOpen(_Symbol, PERIOD_D1, 0);
   const double prev_close = iClose(_Symbol, PERIOD_D1, 1);
   if(today_open <= 0.0 || prev_close <= 0.0)
      return false;

   return MathAbs(today_open - prev_close) <= atr * strategy_gap_atr_mult;
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
   const datetime now = TimeCurrent();
   const int today_key = Strategy_DateKey(now);
   if(!Strategy_IsEcbDateKey(today_key))
      return false;

   const int minute = Strategy_MinutesOfDay(now);
   if(minute < Strategy_EntryMinute() || minute >= Strategy_ExitMinute())
      return false;

   event_key = today_key;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;
   if(_Symbol != STRATEGY_SYMBOL)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1182_ECB_D0_DAX_SHORT";
   req.symbol_slot = STRATEGY_SLOT;
   req.expiration_seconds = 0;

   int event_key = 0;
   if(!Strategy_TodayIsEntryWindow(event_key))
      return false;
   if(event_key == g_last_entry_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(Strategy_HasPreEcbPosition())
      return false;
   if(!Strategy_D1HistoryReady())
      return false;
   if(!Strategy_GapAllowsTrade())
      return false;
   if(!Strategy_SpreadAllowsTrade())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   if(strategy_use_atr_stop)
     {
      double atr = 0.0;
      if(!Strategy_ReadD1Atr(atr))
         return false;
      req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr, strategy_atr_sl_mult);
      if(req.sl <= entry)
         return false;
     }

   g_active_event_key = event_key;
   g_last_entry_key = event_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card authorizes only the initial D1 ATR stop and same-day time exit.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_M15 || !Strategy_HasOpenPosition())
      return false;

   const datetime now = TimeCurrent();
   const int current_key = Strategy_DateKey(now);
   if(current_key <= 0 || current_key == g_last_exit_key)
      return false;

   if(g_active_event_key > 0 && current_key > g_active_event_key)
     {
      g_last_exit_key = current_key;
      return true;
     }

   if(g_active_event_key > 0 && current_key == g_active_event_key &&
      Strategy_MinutesOfDay(now) >= Strategy_ExitMinute())
     {
      g_last_exit_key = current_key;
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   SymbolSelect(STRATEGY_SYMBOL, true);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1182\",\"ea\":\"qp-ecb-d0-dax-short\"}");
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
