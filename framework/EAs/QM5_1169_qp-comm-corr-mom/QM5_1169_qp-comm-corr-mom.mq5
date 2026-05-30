#property strict
#property version   "5.0"
#property description "QM5_1169 Quantpedia Commodity Correlation Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1169;
input int    qm_magic_slot_offset        = 0;

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
input int    strategy_momentum_lookback_d1_bars = 252;
input int    strategy_short_corr_d1_bars         = 20;
input int    strategy_long_corr_d1_bars          = 250;
input int    strategy_min_history_d1_bars        = 270;
input int    strategy_rank_slots_each_side       = 2;
input int    strategy_atr_period                 = 20;
input double strategy_atr_sl_mult                = 5.0;
input int    strategy_spread_median_days         = 20;
input double strategy_spread_mult                = 3.0;

const int STRATEGY_UNIVERSE_SIZE = 4;
string    g_universe_symbols[4] = {"XAUUSD.DWX", "XAGUSD.DWX", "XTIUSD.DWX", "XNGUSD.DWX"};
int       g_universe_slots[4]   = {0, 1, 2, 3};
int       g_last_entry_rebalance_key = 0;
int       g_last_exit_rebalance_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_universe_slots[idx];
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthEndClosedBar()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
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

bool Strategy_HasRequiredUniverseHistory()
  {
   if(strategy_min_history_d1_bars <= 0)
      return false;

   const int required = MathMax(strategy_min_history_d1_bars,
                                MathMax(strategy_momentum_lookback_d1_bars + 2,
                                        strategy_long_corr_d1_bars + 2));
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      SymbolSelect(g_universe_symbols[i], true);
      if(iBars(g_universe_symbols[i], PERIOD_D1) < required)
         return false;
     }
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

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_SymbolReturn(const string symbol, double &out_return)
  {
   out_return = 0.0;
   if(strategy_momentum_lookback_d1_bars <= 0)
      return false;

   SymbolSelect(symbol, true);
   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(symbol, PERIOD_D1, 1 + strategy_momentum_lookback_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_return = (recent_close / lookback_close) - 1.0;
   return true;
  }

bool Strategy_ReturnAtShift(const string symbol, const int shift, double &out_return)
  {
   out_return = 0.0;
   const double close_now = iClose(symbol, PERIOD_D1, shift);
   const double close_prev = iClose(symbol, PERIOD_D1, shift + 1);
   if(close_now <= 0.0 || close_prev <= 0.0)
      return false;
   out_return = (close_now / close_prev) - 1.0;
   return true;
  }

bool Strategy_Correlation(const string symbol_a, const string symbol_b, const int bars, double &out_corr)
  {
   out_corr = 0.0;
   if(bars < 2)
      return false;

   double sum_a = 0.0;
   double sum_b = 0.0;
   double values_a[512];
   double values_b[512];
   if(bars > 512)
      return false;

   for(int i = 0; i < bars; ++i)
     {
      double ret_a = 0.0;
      double ret_b = 0.0;
      if(!Strategy_ReturnAtShift(symbol_a, i + 1, ret_a))
         return false;
      if(!Strategy_ReturnAtShift(symbol_b, i + 1, ret_b))
         return false;
      values_a[i] = ret_a;
      values_b[i] = ret_b;
      sum_a += ret_a;
      sum_b += ret_b;
     }

   const double mean_a = sum_a / bars;
   const double mean_b = sum_b / bars;
   double covariance = 0.0;
   double variance_a = 0.0;
   double variance_b = 0.0;

   for(int i = 0; i < bars; ++i)
     {
      const double da = values_a[i] - mean_a;
      const double db = values_b[i] - mean_b;
      covariance += da * db;
      variance_a += da * da;
      variance_b += db * db;
     }

   if(variance_a <= 0.0 || variance_b <= 0.0)
      return false;

   out_corr = covariance / MathSqrt(variance_a * variance_b);
   return true;
  }

bool Strategy_AveragePairwiseCorrelation(const int bars, double &out_average)
  {
   out_average = 0.0;
   int count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE - 1; ++i)
      for(int j = i + 1; j < STRATEGY_UNIVERSE_SIZE; ++j)
        {
         double corr = 0.0;
         if(!Strategy_Correlation(g_universe_symbols[i], g_universe_symbols[j], bars, corr))
            return false;
         out_average += corr;
         ++count;
        }

   if(count <= 0)
      return false;
   out_average /= count;
   return true;
  }

bool Strategy_CorrelationFilterActive()
  {
   if(!Strategy_HasRequiredUniverseHistory())
      return false;

   double short_corr = 0.0;
   double long_corr = 0.0;
   if(!Strategy_AveragePairwiseCorrelation(strategy_short_corr_d1_bars, short_corr))
      return false;
   if(!Strategy_AveragePairwiseCorrelation(strategy_long_corr_d1_bars, long_corr))
      return false;

   return (short_corr > long_corr);
  }

int Strategy_RankDirection()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;
   if(!Strategy_CorrelationFilterActive())
      return 0;

   double scores[4];
   int indexes[4];
   int count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      double score = 0.0;
      if(!Strategy_SymbolReturn(g_universe_symbols[i], score))
         continue;
      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   if(count < STRATEGY_UNIVERSE_SIZE)
      return 0;

   const int slots = MathMin(strategy_rank_slots_each_side, count / 2);
   if(slots <= 0)
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

   for(int i = 0; i < slots; ++i)
      if(indexes[i] == current_index)
         return -1;

   for(int i = count - slots; i < count; ++i)
      if(indexes[i] == current_index)
         return 1;

   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_rank_slots_each_side <= 0)
      return true;
   if(strategy_short_corr_d1_bars <= 1 || strategy_long_corr_d1_bars <= strategy_short_corr_d1_bars)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1169_COMM_CORR_MOM";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthEndClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_RankDirection();
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1169_COMM_CORR_MOM_LONG" : "QM5_1169_COMM_CORR_MOM_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies a hard ATR stop and monthly rebalance exit only.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_IsMonthEndClosedBar())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_D1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;
   return true;
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

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      SymbolSelect(g_universe_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1169\",\"ea\":\"qp-comm-corr-mom\"}");
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
