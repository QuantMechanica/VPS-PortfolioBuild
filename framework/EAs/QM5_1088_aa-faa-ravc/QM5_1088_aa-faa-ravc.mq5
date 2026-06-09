#property strict
#property version   "5.0"
#property description "QM5_1088 Alpha Architect FAA RAVC Rotation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1088;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 0.33333333;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_rebalance_timeframe = PERIOD_MN1;
input int    strategy_lookback_months     = 4;
input int    strategy_top_n               = 3;
input int    strategy_atr_period          = 4;
input double strategy_atr_sl_mult         = 4.0;
input int    strategy_rebalance_day_max   = 7;

const int STRATEGY_UNIVERSE_SIZE = 7;
string g_universe_symbols[7] =
  {
   "SP500.DWX", "NDX.DWX", "GDAXI.DWX", "XAUUSD.DWX",
   "XTIUSD.DWX", "EURUSD.DWX", "USDJPY.DWX"
  };
int  g_universe_slots[7] = {0, 1, 2, 3, 4, 5, 6};
bool g_selected[7] = {false, false, false, false, false, false, false};
bool g_selection_ready = false;
int  g_selection_key = 0;

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

bool Strategy_RebalanceWindowOpen()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day >= 1 && dt.day <= strategy_rebalance_day_max);
  }

bool Strategy_CloseAt(const string symbol, const int shift, double &out_close)
  {
   out_close = iClose(symbol, strategy_rebalance_timeframe, shift); // perf-allowed bespoke monthly cross-asset history read
   return (out_close > 0.0);
  }

bool Strategy_MonthlyLogReturn(const string symbol, const int shift, double &out_return)
  {
   out_return = 0.0;

   double c0 = 0.0;
   double c1 = 0.0;
   if(!Strategy_CloseAt(symbol, shift, c0))
      return false;
   if(!Strategy_CloseAt(symbol, shift + 1, c1))
      return false;
   if(c1 <= 0.0)
      return false;

   out_return = MathLog(c0 / c1);
   return true;
  }

bool Strategy_RelativeMomentum(const string symbol, double &out_momentum)
  {
   out_momentum = 0.0;
   if(strategy_lookback_months < 1)
      return false;

   double recent_close = 0.0;
   double lookback_close = 0.0;
   if(!Strategy_CloseAt(symbol, 1, recent_close))
      return false;
   if(!Strategy_CloseAt(symbol, 1 + strategy_lookback_months, lookback_close))
      return false;
   if(lookback_close <= 0.0)
      return false;

   out_momentum = (recent_close / lookback_close) - 1.0;
   return true;
  }

bool Strategy_RealizedVolatility(const string symbol, double &out_volatility)
  {
   out_volatility = 0.0;
   if(strategy_lookback_months < 2)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   int count = 0;
   for(int shift = 1; shift <= strategy_lookback_months; ++shift)
     {
      double r = 0.0;
      if(!Strategy_MonthlyLogReturn(symbol, shift, r))
         return false;
      sum += r;
      sum_sq += r * r;
      ++count;
     }

   const double mean = sum / (double)count;
   const double variance = (sum_sq / (double)count) - (mean * mean);
   out_volatility = MathSqrt(MathMax(variance, 0.0));
   return true;
  }

bool Strategy_Correlation(const string symbol_a, const string symbol_b, double &out_corr)
  {
   out_corr = 0.0;
   if(strategy_lookback_months < 2)
      return false;

   double sum_a = 0.0;
   double sum_b = 0.0;
   double sum_aa = 0.0;
   double sum_bb = 0.0;
   double sum_ab = 0.0;
   int count = 0;

   for(int shift = 1; shift <= strategy_lookback_months; ++shift)
     {
      double ra = 0.0;
      double rb = 0.0;
      if(!Strategy_MonthlyLogReturn(symbol_a, shift, ra))
         return false;
      if(!Strategy_MonthlyLogReturn(symbol_b, shift, rb))
         return false;

      sum_a += ra;
      sum_b += rb;
      sum_aa += ra * ra;
      sum_bb += rb * rb;
      sum_ab += ra * rb;
      ++count;
     }

   const double cov = sum_ab - (sum_a * sum_b / (double)count);
   const double var_a = sum_aa - (sum_a * sum_a / (double)count);
   const double var_b = sum_bb - (sum_b * sum_b / (double)count);
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

   out_avg_corr = sum / (double)count;
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

void Strategy_ClearSelection()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      g_selected[i] = false;
   g_selection_ready = false;
  }

bool Strategy_RefreshSelection()
  {
   const int key = Strategy_RebalanceKey(TimeCurrent());
   if(g_selection_ready && g_selection_key == key)
      return true;

   Strategy_ClearSelection();

   double momentum[7];
   double volatility[7];
   double avg_corr[7];
   double composite[7];

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      if(!SymbolSelect(g_universe_symbols[i], true))
         return false;
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
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      g_selected[i] = (momentum[i] > 0.0 && composite[i] <= cutoff);

   g_selection_key = key;
   g_selection_ready = true;
   return true;
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
   req.reason = "QM5_1088_FAA_RAVC_LONG_TOP3";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return false;
   req.symbol_slot = g_universe_slots[idx];

   if(!Strategy_RebalanceWindowOpen())
      return false;
   if(!Strategy_RefreshSelection())
      return false;
   if(!g_selected[idx])
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Source exits by monthly rank/absolute-momentum rebalance; V5 ATR SL is set at entry.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return false;
   if(!g_selection_ready)
      return false;
   if(!Strategy_HasOpenPosition())
      return false;
   return !g_selected[idx];
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
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
