#property strict
#property version   "5.0"
#property description "QM5_1619 Alpha Architect Overnight Momentum Hold"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1619;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_entry_hhmm_broker   = 2300;
input int    strategy_exit_hhmm_broker    = 0100;
input bool   strategy_skip_friday_entry   = true;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 2.5;
input double strategy_spread_median_mult  = 2.5;
input int    strategy_spread_lookback_d1  = 20;
input int    strategy_max_spread_points   = 0;

const int STRATEGY_UNIVERSE_SIZE = 5;
string g_universe_symbols[5] =
  {
   "SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"
  };

datetime g_last_entry_day = 0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

datetime Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool Strategy_IsFriday(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return (dt.day_of_week == FRIDAY);
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
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

double Strategy_ROC_12_1(const string symbol)
  {
   if(Bars(symbol, PERIOD_MN1) < 14)
      return 0.0;

   const double recent_close = iClose(symbol, PERIOD_MN1, 2);
   const double lookback_close = iClose(symbol, PERIOD_MN1, 13);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return 0.0;

   return (recent_close / lookback_close) - 1.0;
  }

bool Strategy_IsSelectedTopThird()
  {
   if(Strategy_CurrentSymbolIndex() < 0)
      return false;

   const double own_momentum = Strategy_ROC_12_1(_Symbol);
   if(own_momentum <= 0.0)
      return false;

   int positive_count = 0;
   int better_count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      const double momentum = Strategy_ROC_12_1(g_universe_symbols[i]);
      if(momentum <= 0.0)
         continue;
      positive_count++;
      if(momentum > own_momentum)
         better_count++;
     }

   if(positive_count <= 0)
      return false;

   const int selected_n = (int)MathMax(1.0, MathCeil((double)positive_count / 3.0));
   return (better_count < selected_n);
  }

double Strategy_MedianSpreadD1()
  {
   const int n = MathMax(1, strategy_spread_lookback_d1);
   double spreads[];
   ArrayResize(spreads, n);

   int samples = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const int spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[samples] = (double)spread;
      samples++;
     }

   if(samples <= 0)
      return 0.0;

   ArrayResize(spreads, samples);
   ArraySort(spreads);
   const int mid = samples / 2;
   if((samples % 2) == 1)
      return spreads[mid];
   return (spreads[mid - 1] + spreads[mid]) / 2.0;
  }

bool Strategy_SpreadAllowsEntry()
  {
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
      return false;

   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
      return false;

   const double median_spread = Strategy_MedianSpreadD1();
   if(median_spread <= 0.0)
      return true;

   return ((double)spread <= strategy_spread_median_mult * median_spread);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
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
   req.reason = "AA_OVERNIGHT_MOM_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(Strategy_Hhmm(broker_now) != strategy_entry_hhmm_broker)
      return false;

   if(strategy_skip_friday_entry && Strategy_IsFriday(broker_now))
      return false;

   const datetime day_key = Strategy_DayKey(broker_now);
   if(g_last_entry_day == day_key)
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   if(!Strategy_IsSelectedTopThird())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(ask <= 0.0 || atr_d1 <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= ask)
      return false;

   g_last_entry_day = day_key;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies only emergency ATR stop plus next-session-open time exit.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   const int hhmm = Strategy_Hhmm(broker_now);
   if(hhmm < strategy_exit_hhmm_broker)
      return false;

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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_DayKey(open_time) != Strategy_DayKey(broker_now))
         return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1624_aa_overnight_mom\"}");
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
