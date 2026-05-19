#property strict
#property version   "5.0"
#property description "QM5_1059 Jegadeesh Short-Term Reversal Index Basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1059;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 22;

input group "Strategy"
input int    strategy_signal_hour_broker  = 22;
input int    strategy_return_d1_bars      = 5;
input int    strategy_atr_stop_period     = 14;
input double strategy_atr_stop_mult       = 3.0;
input int    strategy_vol_atr_period      = 20;
input double strategy_vol_max_atr_close   = 0.03;
input int    strategy_spread_median_bars  = 20;
input double strategy_spread_mult         = 5.0;
input int    strategy_min_rank_symbols    = 4;

const int STRATEGY_UNIVERSE_SIZE = 4;
string g_strategy_symbols[STRATEGY_UNIVERSE_SIZE] = {
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX"
};

int g_last_entry_week_key = 0;
int g_last_exit_week_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return idx;
  }

int Strategy_WeekKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 1000 + (dt.day_of_year / 7);
  }

bool Strategy_IsFridayRebalanceTime(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return (dt.day_of_week == 5 && dt.hour >= strategy_signal_hour_broker);
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

double Strategy_CurrentClose(const string symbol)
  {
   SymbolSelect(symbol, true);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid > 0.0)
      return bid;
   return iClose(symbol, PERIOD_D1, 0);
  }

bool Strategy_SymbolReturn5D(const string symbol, double &out_return)
  {
   out_return = 0.0;
   if(strategy_return_d1_bars <= 0)
      return false;

   const double recent_close = Strategy_CurrentClose(symbol);
   const double lookback_close = iClose(symbol, PERIOD_D1, strategy_return_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_return = (recent_close / lookback_close) - 1.0;
   return true;
  }

double Strategy_MedianSpreadPoints(const string symbol)
  {
   if(strategy_spread_median_bars <= 0)
      return 0.0;

   double spreads[64];
   int count = 0;
   const int bars = MathMin(strategy_spread_median_bars, 64);
   for(int shift = 1; shift <= bars; ++shift)
     {
      const long spread = iSpread(symbol, PERIOD_H1, shift);
      if(spread <= 0)
         continue;
      spreads[count] = (double)spread;
      ++count;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(spreads[j] < spreads[i])
           {
            const double tmp = spreads[i];
            spreads[i] = spreads[j];
            spreads[j] = tmp;
           }

   if((count % 2) == 1)
      return spreads[count / 2];
   return 0.5 * (spreads[(count / 2) - 1] + spreads[count / 2]);
  }

bool Strategy_SpreadAllowsEntry(const string symbol)
  {
   if(strategy_spread_mult <= 0.0)
      return true;

   const double median_spread = Strategy_MedianSpreadPoints(symbol);
   const long current_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(median_spread <= 0.0 || current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_VolatilityAllowsEntry(const string symbol)
  {
   const double close = Strategy_CurrentClose(symbol);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_vol_atr_period, 1);
   if(close <= 0.0 || atr <= 0.0)
      return false;
   return ((atr / close) <= strategy_vol_max_atr_close);
  }

int Strategy_ReversalDirection()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[STRATEGY_UNIVERSE_SIZE];
   int indexes[STRATEGY_UNIVERSE_SIZE];
   int count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      SymbolSelect(g_strategy_symbols[i], true);
      if(!Strategy_SpreadAllowsEntry(g_strategy_symbols[i]))
         continue;

      double score = 0.0;
      if(!Strategy_SymbolReturn5D(g_strategy_symbols[i], score))
         continue;

      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   if(count < strategy_min_rank_symbols)
      return 0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] < scores[i])
           {
            const double tmp_score = scores[i];
            scores[i] = scores[j];
            scores[j] = tmp_score;
            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }

   if(indexes[0] == current_index)
      return 1;
   if(indexes[count - 1] == current_index)
      return -1;
   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1059_STMR_WEEKLY";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsFridayRebalanceTime(broker_now))
      return false;

   const int week_key = Strategy_WeekKey(broker_now);
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const int direction = Strategy_ReversalDirection();
   if(direction == 0)
      return false;
   if(!Strategy_VolatilityAllowsEntry(_Symbol))
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_stop_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1059_STMR_LONG_BOTTOM1" : "QM5_1059_STMR_SHORT_TOP1";
   g_last_entry_week_key = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies weekly hold with hard 3x ATR stop only.
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsFridayRebalanceTime(broker_now))
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int week_key = Strategy_WeekKey(broker_now);
   if(week_key <= 0 || week_key == g_last_exit_week_key)
      return false;
   g_last_exit_week_key = week_key;
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      SymbolSelect(g_strategy_symbols[i], true);

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1059\",\"ea\":\"jegadeesh-stm-reversal-indices\"}");
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
   if(qm_friday_close_enabled && QM_FrameworkHandleFridayClose())
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
