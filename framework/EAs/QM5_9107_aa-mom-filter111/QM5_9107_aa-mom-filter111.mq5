#property strict
#property version   "5.0"
#property description "QM5_9107 Alpha Architect Filtered 11-1 Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9107;
input int    qm_magic_slot_offset        = 14;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_mom_11_1_recent_shift = 1;
input int    strategy_mom_11_1_past_shift   = 12;
input int    strategy_mom_10_0_recent_shift = 0;
input int    strategy_mom_10_0_past_shift   = 10;
input int    strategy_min_monthly_bars      = 24;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 3.0;
input int    strategy_spread_median_days    = 20;
input double strategy_spread_mult           = 2.5;
input bool   strategy_enable_short_mode     = false;
input string strategy_universe_symbols      = "AUDCAD.DWX,AUDCHF.DWX,AUDJPY.DWX,AUDNZD.DWX,AUDUSD.DWX,CADCHF.DWX,CADJPY.DWX,CHFJPY.DWX,EURAUD.DWX,EURCAD.DWX,EURCHF.DWX,EURGBP.DWX,EURJPY.DWX,EURNZD.DWX,EURUSD.DWX,GBPAUD.DWX,GBPCAD.DWX,GBPCHF.DWX,GBPJPY.DWX,GBPNZD.DWX,GBPUSD.DWX,GDAXI.DWX,NDX.DWX,NZDCAD.DWX,NZDCHF.DWX,NZDJPY.DWX,NZDUSD.DWX,SP500.DWX,UK100.DWX,USDCAD.DWX,USDCHF.DWX,USDJPY.DWX,WS30.DWX,XAGUSD.DWX,XAUUSD.DWX,XNGUSD.DWX,XTIUSD.DWX";

string g_universe[];
double g_median_spread_points = 0.0;
int    g_last_entry_key       = 0;
int    g_last_exit_key        = 0;

int MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

bool LoadUniverse()
  {
   string parts[];
   const int count = StringSplit(strategy_universe_symbols, ',', parts);
   if(count <= 0)
      return false;

   ArrayResize(g_universe, count);
   for(int i = 0; i < count; ++i)
     {
      StringTrimLeft(parts[i]);
      StringTrimRight(parts[i]);
      g_universe[i] = parts[i];
     }
   return true;
  }

int CurrentSymbolIndex()
  {
   for(int i = 0; i < ArraySize(g_universe); ++i)
      if(g_universe[i] == _Symbol)
         return i;
   return -1;
  }

bool HasCurrentSymbolPosition()
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

bool IsFirstH1BarOfMonth()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_H1, 0);
   const datetime prior_bar = iTime(_Symbol, PERIOD_H1, 1);
   if(current_bar <= 0 || prior_bar <= 0)
      return false;
   return (MonthKey(current_bar) != MonthKey(prior_bar));
  }

bool MomentumValue(const string symbol, const int recent_shift, const int past_shift, double &out_value)
  {
   out_value = 0.0;
   if(Bars(symbol, PERIOD_MN1) < strategy_min_monthly_bars)
      return false;

   const double recent_close = iClose(symbol, PERIOD_MN1, recent_shift);
   const double past_close = iClose(symbol, PERIOD_MN1, past_shift);
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;

   out_value = recent_close / past_close - 1.0;
   return true;
  }

int ValidUniverseCountForWindow(const int recent_shift, const int past_shift)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(g_universe); ++i)
     {
      double value = 0.0;
      if(MomentumValue(g_universe[i], recent_shift, past_shift, value))
         count++;
     }
   return count;
  }

bool IsTopDecile(const string symbol, const int recent_shift, const int past_shift)
  {
   double symbol_value = 0.0;
   if(!MomentumValue(symbol, recent_shift, past_shift, symbol_value))
      return false;

   const int valid_count = ValidUniverseCountForWindow(recent_shift, past_shift);
   if(valid_count <= 0)
      return false;

   const int top_count = MathMax(1, (int)MathCeil((double)valid_count * 0.10));
   int rank = 1;
   for(int i = 0; i < ArraySize(g_universe); ++i)
     {
      double other_value = 0.0;
      if(!MomentumValue(g_universe[i], recent_shift, past_shift, other_value))
         continue;
      if(other_value > symbol_value)
         rank++;
     }
   return (rank <= top_count);
  }

bool IsBottomDecile(const string symbol, const int recent_shift, const int past_shift)
  {
   double symbol_value = 0.0;
   if(!MomentumValue(symbol, recent_shift, past_shift, symbol_value))
      return false;

   const int valid_count = ValidUniverseCountForWindow(recent_shift, past_shift);
   if(valid_count <= 0)
      return false;

   const int bottom_count = MathMax(1, (int)MathCeil((double)valid_count * 0.10));
   int rank = 1;
   for(int i = 0; i < ArraySize(g_universe); ++i)
     {
      double other_value = 0.0;
      if(!MomentumValue(g_universe[i], recent_shift, past_shift, other_value))
         continue;
      if(other_value < symbol_value)
         rank++;
     }
   return (rank <= bottom_count);
  }

int PersistentBucketDirection()
  {
   if(IsTopDecile(_Symbol, strategy_mom_11_1_recent_shift, strategy_mom_11_1_past_shift) &&
      IsTopDecile(_Symbol, strategy_mom_10_0_recent_shift, strategy_mom_10_0_past_shift))
      return 1;

   if(strategy_enable_short_mode &&
      IsBottomDecile(_Symbol, strategy_mom_11_1_recent_shift, strategy_mom_11_1_past_shift) &&
      IsBottomDecile(_Symbol, strategy_mom_10_0_recent_shift, strategy_mom_10_0_past_shift))
      return -1;

   return 0;
  }

void RefreshSpreadMedian()
  {
   const int n = MathMin(strategy_spread_median_days, 64);
   if(n <= 0)
     {
      g_median_spread_points = 0.0;
      return;
     }

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      count++;
     }

   if(count <= 0)
     {
      g_median_spread_points = 0.0;
      return;
     }

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double temp = values[i];
            values[i] = values[j];
            values[j] = temp;
           }

   g_median_spread_points = ((count % 2) == 1)
                            ? values[count / 2]
                            : 0.5 * (values[count / 2 - 1] + values[count / 2]);
  }

bool SpreadAllowsEntry()
  {
   if(g_median_spread_points <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= g_median_spread_points * strategy_spread_mult);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;
   if(ArraySize(g_universe) <= 0 || CurrentSymbolIndex() < 0)
      return true;
   if(g_median_spread_points <= 0.0 || QM_IsNewBar(_Symbol, PERIOD_D1))
      RefreshSpreadMedian();
   return !SpreadAllowsEntry();
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_9107_FILTERED_11_1_MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!IsFirstH1BarOfMonth())
      return false;

   const datetime current_month = iTime(_Symbol, PERIOD_MN1, 0);
   const int rebalance_key = MonthKey(current_month);
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_key)
      return false;
   g_last_entry_key = rebalance_key;

   if(HasCurrentSymbolPosition())
      return false;

   const int direction = PersistentBucketDirection();
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_9107_LONG_TOP_DECILE_PERSIST" : "QM5_9107_SHORT_BOTTOM_DECILE_PERSIST";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!HasCurrentSymbolPosition())
      return false;
   if(!IsFirstH1BarOfMonth())
      return false;

   const datetime current_month = iTime(_Symbol, PERIOD_MN1, 0);
   const int rebalance_key = MonthKey(current_month);
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_key)
      return false;
   g_last_exit_key = rebalance_key;

   return (PersistentBucketDirection() == 0);
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!LoadUniverse())
      return INIT_FAILED;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   RefreshSpreadMedian();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9107\",\"ea\":\"aa-mom-filter111\"}");
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
