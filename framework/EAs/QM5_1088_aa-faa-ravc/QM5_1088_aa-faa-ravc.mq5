#property strict
#property version   "5.0"
#property description "QM5_1088 Alpha Architect FAA RAVC Rotation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1088;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.33333333;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_lookback_d1_bars   = 84;
input int    strategy_top_n              = 3;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 4.0;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 3.0;

const int STRATEGY_UNIVERSE_SIZE = 7;
string    g_universe_symbols[7] =
  {
   "SP500.DWX", "NDX.DWX", "GDAXI.DWX", "XAUUSD.DWX",
   "XTIUSD.DWX", "EURUSD.DWX", "USDJPY.DWX"
  };
int       g_universe_slots[7] = {0, 1, 2, 3, 4, 5, 6};
int       g_last_entry_rebalance_key = 0;
int       g_last_exit_rebalance_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsMonthEndClosedBar()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_H1, 1);
   const datetime current_bar = iTime(_Symbol, PERIOD_H1, 0);
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

bool Strategy_DailyLogReturn(const string symbol, const int shift, double &out_return)
  {
   out_return = 0.0;
   const double c0 = iClose(symbol, PERIOD_D1, shift);
   const double c1 = iClose(symbol, PERIOD_D1, shift + 1);
   if(c0 <= 0.0 || c1 <= 0.0)
      return false;

   out_return = MathLog(c0 / c1);
   return true;
  }

bool Strategy_RelativeMomentum(const string symbol, double &out_momentum)
  {
   out_momentum = 0.0;
   if(strategy_lookback_d1_bars <= 1)
      return false;

   SymbolSelect(symbol, true);
   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(symbol, PERIOD_D1, 1 + strategy_lookback_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_momentum = (recent_close / lookback_close) - 1.0;
   return true;
  }

bool Strategy_RealizedVolatility(const string symbol, double &out_volatility)
  {
   out_volatility = 0.0;
   if(strategy_lookback_d1_bars <= 1)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   int count = 0;
   for(int shift = 1; shift <= strategy_lookback_d1_bars; ++shift)
     {
      double r = 0.0;
      if(!Strategy_DailyLogReturn(symbol, shift, r))
         return false;
      sum += r;
      sum_sq += r * r;
      ++count;
     }

   if(count <= 1)
      return false;

   const double mean = sum / count;
   const double variance = (sum_sq / count) - (mean * mean);
   out_volatility = MathSqrt(MathMax(variance, 0.0));
   return true;
  }

bool Strategy_Correlation(const string symbol_a, const string symbol_b, double &out_corr)
  {
   out_corr = 0.0;
   if(strategy_lookback_d1_bars <= 1)
      return false;

   double sum_a = 0.0;
   double sum_b = 0.0;
   double sum_aa = 0.0;
   double sum_bb = 0.0;
   double sum_ab = 0.0;
   int count = 0;

   for(int shift = 1; shift <= strategy_lookback_d1_bars; ++shift)
     {
      double ra = 0.0;
      double rb = 0.0;
      if(!Strategy_DailyLogReturn(symbol_a, shift, ra))
         return false;
      if(!Strategy_DailyLogReturn(symbol_b, shift, rb))
         return false;

      sum_a += ra;
      sum_b += rb;
      sum_aa += ra * ra;
      sum_bb += rb * rb;
      sum_ab += ra * rb;
      ++count;
     }

   if(count <= 1)
      return false;

   const double cov = sum_ab - (sum_a * sum_b / count);
   const double var_a = sum_aa - (sum_a * sum_a / count);
   const double var_b = sum_bb - (sum_b * sum_b / count);
   if(var_a <= 0.0 || var_b <= 0.0)
      return false;

   out_corr = cov / MathSqrt(var_a * var_b);
   return true;
  }

bool Strategy_AverageCorrelation(const int symbol_index, double &out_avg_corr)
  {
   out_avg_corr = 0.0;
   if(symbol_index < 0 || symbol_index >= STRATEGY_UNIVERSE_SIZE)
      return false;

   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      if(i == symbol_index)
         continue;
      double corr = 0.0;
      if(!Strategy_Correlation(g_universe_symbols[symbol_index], g_universe_symbols[i], corr))
         return false;
      sum += corr;
      ++count;
     }

   if(count <= 0)
      return false;

   out_avg_corr = sum / count;
   return true;
  }

int Strategy_RankHigherIsBetter(const double &values[], const int count, const int idx)
  {
   int rank = 1;
   for(int i = 0; i < count; ++i)
      if(values[i] > values[idx])
         ++rank;
   return rank;
  }

int Strategy_RankLowerIsBetter(const double &values[], const int count, const int idx)
  {
   int rank = 1;
   for(int i = 0; i < count; ++i)
      if(values[i] < values[idx])
         ++rank;
   return rank;
  }

bool Strategy_Selected(const string symbol)
  {
   int current_index = -1;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == symbol)
         current_index = i;
   if(current_index < 0)
      return false;

   double momentum[7];
   double volatility[7];
   double avg_corr[7];
   double composite[7];

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      SymbolSelect(g_universe_symbols[i], true);
      if(!Strategy_RelativeMomentum(g_universe_symbols[i], momentum[i]))
         return false;
      if(!Strategy_RealizedVolatility(g_universe_symbols[i], volatility[i]))
         return false;
     }

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(!Strategy_AverageCorrelation(i, avg_corr[i]))
         return false;

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      const int mom_rank = Strategy_RankHigherIsBetter(momentum, STRATEGY_UNIVERSE_SIZE, i);
      const int vol_rank = Strategy_RankLowerIsBetter(volatility, STRATEGY_UNIVERSE_SIZE, i);
      const int cor_rank = Strategy_RankLowerIsBetter(avg_corr, STRATEGY_UNIVERSE_SIZE, i);
      composite[i] = (double)mom_rank + 0.5 * (double)vol_rank + 0.5 * (double)cor_rank;
     }

   if(momentum[current_index] <= 0.0)
      return false;

   int top_n = strategy_top_n;
   if(top_n < 1)
      top_n = 1;
   if(top_n > STRATEGY_UNIVERSE_SIZE)
      top_n = STRATEGY_UNIVERSE_SIZE;

   double sorted[7];
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      sorted[i] = composite[i];

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE - 1; ++i)
      for(int j = i + 1; j < STRATEGY_UNIVERSE_SIZE; ++j)
         if(sorted[j] < sorted[i])
           {
            const double tmp = sorted[i];
            sorted[i] = sorted[j];
            sorted[j] = tmp;
           }

   const double cutoff = sorted[top_n - 1];
   return (composite[current_index] <= cutoff);
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
   req.reason = "QM5_1088_FAA_RAVC_MONTHLY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthEndClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_H1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;
   if(!Strategy_Selected(_Symbol))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   req.reason = "QM5_1088_FAA_RAVC_LONG_TOP3";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Source uses monthly rank/absolute-momentum exits; V5 hard ATR SL is set at entry.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_H1)
      return false;
   if(!Strategy_IsMonthEndClosedBar())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(iTime(_Symbol, PERIOD_H1, 1));
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;

   return !Strategy_Selected(_Symbol);
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

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      SymbolSelect(g_universe_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1088\",\"ea\":\"aa-faa-ravc\"}");
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
