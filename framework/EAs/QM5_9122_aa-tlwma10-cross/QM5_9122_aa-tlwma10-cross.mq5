#property strict
#property version   "5.0"
#property description "QM5_9122 Alpha Architect Triple LWMA 10 Cross"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9122;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_lwma_period         = 10;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 2.5;
input int    strategy_warmup_bars         = 60;
input double strategy_max_spread_median_mult = 2.5;

const int STRATEGY_UNIVERSE_SIZE = 9;
string    g_universe_symbols[9] =
  {
   "SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "XAUUSD.DWX",
   "XTIUSD.DWX", "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX"
  };
int       g_universe_slots[9] = {0, 1, 2, 3, 4, 5, 6, 7, 8};

datetime  g_last_signal_d1_bar = 0;
int       g_cached_signal = 0;
bool      g_cached_signal_ready = false;
double    g_cached_close_1 = 0.0;
double    g_cached_tlwma_1 = 0.0;
double    g_cached_median_spread = 0.0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &ptype)
  {
   ptype = POSITION_TYPE_BUY;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

double Strategy_LWMA_Close(const int period, const int shift)
  {
   if(period <= 0 || shift < 0)
      return 0.0;

   double weighted = 0.0;
   double weight_sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double close = iClose(_Symbol, PERIOD_D1, shift + i);
      if(close <= 0.0)
         return 0.0;
      const double weight = (double)(period - i);
      weighted += close * weight;
      weight_sum += weight;
     }
   return (weight_sum > 0.0) ? (weighted / weight_sum) : 0.0;
  }

double Strategy_LWMA_Of_LWMA1(const int period, const int shift)
  {
   double weighted = 0.0;
   double weight_sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double v = Strategy_LWMA_Close(period, shift + i);
      if(v <= 0.0)
         return 0.0;
      const double weight = (double)(period - i);
      weighted += v * weight;
      weight_sum += weight;
     }
   return (weight_sum > 0.0) ? (weighted / weight_sum) : 0.0;
  }

double Strategy_TLWMA(const int period, const int shift)
  {
   double weighted = 0.0;
   double weight_sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double v = Strategy_LWMA_Of_LWMA1(period, shift + i);
      if(v <= 0.0)
         return 0.0;
      const double weight = (double)(period - i);
      weighted += v * weight;
      weight_sum += weight;
     }
   return (weight_sum > 0.0) ? (weighted / weight_sum) : 0.0;
  }

double Strategy_MedianSpreadD1(const int lookback)
  {
   if(lookback <= 0)
      return 0.0;

   double spreads[64];
   const int n = MathMin(lookback, 64);
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[count] = (double)spread;
      ++count;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 1; i < count; ++i)
     {
      const double key = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > key)
        {
         spreads[j + 1] = spreads[j];
         --j;
        }
      spreads[j + 1] = key;
     }

   const int mid = count / 2;
   if((count % 2) == 1)
      return spreads[mid];
   return (spreads[mid - 1] + spreads[mid]) * 0.5;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_median_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   if(g_cached_median_spread <= 0.0)
      return true;

   return ((double)current_spread <= g_cached_median_spread * strategy_max_spread_median_mult);
  }

void Strategy_RefreshDailySignal()
  {
   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar <= 0 || d1_bar == g_last_signal_d1_bar)
      return;

   g_last_signal_d1_bar = d1_bar;
   g_cached_signal = 0;
   g_cached_signal_ready = false;
   g_cached_close_1 = 0.0;
   g_cached_tlwma_1 = 0.0;
   g_cached_median_spread = 0.0;

   if(strategy_lwma_period <= 1 || strategy_warmup_bars < strategy_lwma_period * 3)
      return;
   if(Bars(_Symbol, PERIOD_D1) < strategy_warmup_bars + 3)
      return;

   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);
   const double close_2 = iClose(_Symbol, PERIOD_D1, 2);
   const double tlwma_1 = Strategy_TLWMA(strategy_lwma_period, 1);
   const double tlwma_2 = Strategy_TLWMA(strategy_lwma_period, 2);
   if(close_1 <= 0.0 || close_2 <= 0.0 || tlwma_1 <= 0.0 || tlwma_2 <= 0.0)
      return;

   g_cached_close_1 = close_1;
   g_cached_tlwma_1 = tlwma_1;
   g_cached_median_spread = Strategy_MedianSpreadD1(strategy_atr_period);
   g_cached_signal_ready = true;
   if(close_1 > tlwma_1 && close_2 <= tlwma_2)
      g_cached_signal = 1;
   else if(close_1 < tlwma_1 && close_2 >= tlwma_2)
      g_cached_signal = -1;
  }

bool Strategy_CloseCrossExit(const ENUM_POSITION_TYPE ptype)
  {
   if(!g_cached_signal_ready)
      return false;

   if(g_cached_close_1 <= 0.0 || g_cached_tlwma_1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return (g_cached_close_1 <= g_cached_tlwma_1);
   if(ptype == POSITION_TYPE_SELL)
      return (g_cached_close_1 >= g_cached_tlwma_1);
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return true;
   if(qm_magic_slot_offset != g_universe_slots[idx])
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
   req.reason = "QM5_9122_TLWMA10_CROSS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_RefreshDailySignal();
   if(!g_cached_signal_ready || g_cached_signal == 0)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   ENUM_POSITION_TYPE ptype;
   if(Strategy_HasOpenPosition(ptype))
      return false;

   const QM_OrderType side = (g_cached_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(side == QM_BUY && req.sl >= entry)
      return false;
   if(side == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (side == QM_BUY) ? "TLWMA10_CLOSE_CROSS_LONG" : "TLWMA10_CLOSE_CROSS_SHORT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_HasOpenPosition(ptype))
      return false;

   Strategy_RefreshDailySignal();
   return Strategy_CloseCrossExit(ptype);
  }

// News Filter Hook
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9122\",\"ea\":\"QM5_9122_aa_tlwma10_cross\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
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
