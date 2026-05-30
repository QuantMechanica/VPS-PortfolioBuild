#property strict
#property version   "5.0"
#property description "QM5_1102 Quantpedia Commodity Skewness Low Minus High"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1102;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_return_lookback_d1 = 252;
input int    strategy_min_bars_d1        = 270;
input int    strategy_min_nonzero_returns = 200;
input int    strategy_bucket_size        = 2;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 5.0;
input int    strategy_max_spread_points  = 0;

#define STRATEGY_UNIVERSE_COUNT 4

string g_strategy_universe[STRATEGY_UNIVERSE_COUNT] =
  {
   "XAUUSD.DWX", "XAGUSD.DWX", "XTIUSD.DWX", "XNGUSD.DWX"
  };

int g_last_entry_rebalance_day = 0;
int g_last_exit_rebalance_day = 0;

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_DifferentMonth(const datetime a, const datetime b)
  {
   MqlDateTime da;
   MqlDateTime db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year != db.year || da.mon != db.mon);
  }

bool Strategy_IsMonthlyRebalanceDay(int &rebalance_day_key)
  {
   rebalance_day_key = 0;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime last_closed_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || last_closed_d1 <= 0)
      return false;
   if(!Strategy_DifferentMonth(current_d1, last_closed_d1))
      return false;

   rebalance_day_key = Strategy_DayKey(last_closed_d1);
   return (rebalance_day_key > 0);
  }

int Strategy_CurrentSymbolSlot()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
      if(g_strategy_universe[i] == _Symbol)
         return i;
   return qm_magic_slot_offset;
  }

bool Strategy_SymbolInUniverse()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
      if(g_strategy_universe[i] == _Symbol)
         return true;
   return false;
  }

bool Strategy_ComputeSkewness(const string symbol, double &out_skew)
  {
   out_skew = 0.0;

   if(strategy_return_lookback_d1 <= 2)
      return false;
   if(strategy_return_lookback_d1 > 512)
      return false;
   if(strategy_min_bars_d1 < strategy_return_lookback_d1 + 1)
      return false;
   if(Bars(symbol, PERIOD_D1) < strategy_min_bars_d1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int needed = strategy_return_lookback_d1 + 1;
   if(CopyRates(symbol, PERIOD_D1, 1, needed, rates) != needed) // perf-allowed: called only from Strategy_EntrySignal after the framework QM_IsNewBar gate.
      return false;

   double returns[];
   ArrayResize(returns, strategy_return_lookback_d1);

   double sum = 0.0;
   int samples = 0;
   int nonzero = 0;
   for(int i = 0; i < strategy_return_lookback_d1; ++i)
     {
      const double c0 = rates[i].close;
      const double c1 = rates[i + 1].close;
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;

      const double r = MathLog(c0 / c1);
      returns[samples] = r;
      sum += r;
      if(MathAbs(r) > 1.0e-12)
         nonzero++;
      samples++;
     }

   if(samples != strategy_return_lookback_d1)
      return false;
   if(nonzero < strategy_min_nonzero_returns)
      return false;

   const double mean = sum / (double)samples;
   double second_sum = 0.0;
   double third_sum = 0.0;
   for(int i = 0; i < samples; ++i)
     {
      const double centered = returns[i] - mean;
      const double centered2 = centered * centered;
      second_sum += centered2;
      third_sum += centered2 * centered;
     }

   const double variance = second_sum / (double)samples;
   if(variance <= 0.0)
      return false;

   const double sigma = MathSqrt(variance);
   if(sigma <= 0.0)
      return false;

   out_skew = (third_sum / (double)samples) / (sigma * sigma * sigma);
   return MathIsValidNumber(out_skew);
  }

int Strategy_CurrentSymbolRankDirection()
  {
   string symbols[STRATEGY_UNIVERSE_COUNT];
   double skew[STRATEGY_UNIVERSE_COUNT];
   int eligible = 0;

   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
     {
      SymbolSelect(g_strategy_universe[i], true);
      double value = 0.0;
      if(!Strategy_ComputeSkewness(g_strategy_universe[i], value))
         continue;

      symbols[eligible] = g_strategy_universe[i];
      skew[eligible] = value;
      eligible++;
     }

   if(eligible < STRATEGY_UNIVERSE_COUNT)
      return 0;

   for(int i = 0; i < eligible - 1; ++i)
     {
      for(int j = i + 1; j < eligible; ++j)
        {
         if(skew[j] < skew[i])
           {
            const double tmp_skew = skew[i];
            skew[i] = skew[j];
            skew[j] = tmp_skew;

            const string tmp_symbol = symbols[i];
            symbols[i] = symbols[j];
            symbols[j] = tmp_symbol;
           }
        }
     }

   const int bucket = MathMax(1, MathMin(strategy_bucket_size, eligible / 2));
   for(int i = 0; i < bucket; ++i)
      if(symbols[i] == _Symbol)
         return 1;

   for(int i = eligible - bucket; i < eligible; ++i)
      if(symbols[i] == _Symbol)
         return -1;

   return 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1 && _Period != PERIOD_D1)
      return true;
   if(!Strategy_SymbolInUniverse())
      return true;
   if(strategy_max_spread_points > 0 &&
      SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   int rebalance_day_key = 0;
   if(!Strategy_IsMonthlyRebalanceDay(rebalance_day_key))
      return false;
   if(g_last_entry_rebalance_day == rebalance_day_key)
      return false;
   g_last_entry_rebalance_day = rebalance_day_key;

   const int direction = Strategy_CurrentSymbolRankDirection();
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "QM5_1102_SKEW_LOW_LONG" : "QM5_1102_SKEW_HIGH_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies only rebalance exits plus the hard ATR stop placed at entry.
  }

bool Strategy_ExitSignal()
  {
   int rebalance_day_key = 0;
   if(!Strategy_IsMonthlyRebalanceDay(rebalance_day_key))
      return false;
   if(g_last_exit_rebalance_day == rebalance_day_key)
      return false;

   g_last_exit_rebalance_day = rebalance_day_key;
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_COUNT; ++i)
      SymbolSelect(g_strategy_universe[i], true);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1102\",\"ea\":\"qp-comm-skew-low\"}");
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
