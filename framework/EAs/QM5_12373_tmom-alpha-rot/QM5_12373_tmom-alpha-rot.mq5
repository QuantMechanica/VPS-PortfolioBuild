#property strict
#property version   "5.0"
#property description "QM5_12373 ThewindMom Jensen Alpha Rotation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12373;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_returns       = 60;
input int    strategy_top_n                  = 3;
input double strategy_risk_free_rate         = 0.0;
input string strategy_benchmark_symbol       = "SP500.DWX";
input bool   strategy_alpha_positive_gate    = false;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 2.0;
input double strategy_max_spread_points      = 0.0;

#define QM5_12373_SYMBOL_COUNT 4

string g_symbols[QM5_12373_SYMBOL_COUNT] =
  {
   "GDAXI.DWX", "NDX.DWX", "WS30.DWX", "SP500.DWX"
  };

int g_slots[QM5_12373_SYMBOL_COUNT] = {0, 1, 2, 3};

int    g_cached_rank = 0;
double g_cached_alpha = 0.0;
bool   g_rank_ready = false;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_12373_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SymbolIndex(const string symbol)
  {
   for(int i = 0; i < QM5_12373_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

bool Strategy_SelectBasket()
  {
   bool ok = true;
   for(int i = 0; i < QM5_12373_SYMBOL_COUNT; ++i)
      ok = (SymbolSelect(g_symbols[i], true) && ok);
   return ok;
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

int Strategy_WeekKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 1000 + (dt.day_of_year / 7);
  }

bool Strategy_IsWeeklyRebalanceBar()
  {
   if(_Period != PERIOD_D1)
      return false;

   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: one D1 timestamp read for weekly alpha-rotation cadence.
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one D1 timestamp read for weekly alpha-rotation cadence.
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   return (Strategy_WeekKey(closed_bar) != Strategy_WeekKey(current_bar));
  }

bool Strategy_HistoryReady(const string symbol)
  {
   if(!QM_SymbolAssertOrLog(symbol))
      return false;
   SymbolSelect(symbol, true);
   const int min_bars = MathMax(strategy_lookback_returns + strategy_atr_period + 10, strategy_lookback_returns + 5);
   return (Bars(symbol, PERIOD_D1) >= min_bars); // perf-allowed: O(1) D1 basket warmup check inside closed-bar ranking.
  }

bool Strategy_ReturnAt(const string symbol, const int shift, double &out_return)
  {
   out_return = 0.0;
   const double c0 = iClose(symbol, PERIOD_D1, shift);     // perf-allowed: bespoke OLS return window, called once per D1 new bar.
   const double c1 = iClose(symbol, PERIOD_D1, shift + 1); // perf-allowed: bespoke OLS return window, called once per D1 new bar.
   if(c0 <= 0.0 || c1 <= 0.0)
      return false;
   out_return = (c0 / c1) - 1.0 - strategy_risk_free_rate;
   return true;
  }

bool Strategy_AlphaForSymbol(const string symbol, const string benchmark, double &out_alpha)
  {
   out_alpha = 0.0;
   const int lookback = MathMax(5, strategy_lookback_returns);
   if(!Strategy_HistoryReady(symbol) || !Strategy_HistoryReady(benchmark))
      return false;

   double mean_y = 0.0;
   double mean_x = 0.0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      double y = 0.0;
      double x = 0.0;
      if(!Strategy_ReturnAt(symbol, shift, y) || !Strategy_ReturnAt(benchmark, shift, x))
         return false;
      mean_y += y;
      mean_x += x;
     }
   mean_y /= (double)lookback;
   mean_x /= (double)lookback;

   double cov_xy = 0.0;
   double var_x = 0.0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      double y = 0.0;
      double x = 0.0;
      if(!Strategy_ReturnAt(symbol, shift, y) || !Strategy_ReturnAt(benchmark, shift, x))
         return false;
      cov_xy += (x - mean_x) * (y - mean_y);
      var_x += (x - mean_x) * (x - mean_x);
     }

   const double beta = (var_x > 0.0) ? (cov_xy / var_x) : 0.0;
   out_alpha = mean_y - beta * mean_x;
   return true;
  }

void Strategy_SortDescending(double &scores[], int &indexes[], const int count)
  {
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] > scores[i])
           {
            const double tmp_score = scores[i];
            scores[i] = scores[j];
            scores[j] = tmp_score;

            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }
  }

bool Strategy_UpdateRankCache()
  {
   g_cached_rank = 0;
   g_cached_alpha = 0.0;
   g_rank_ready = false;

   const int current_index = Strategy_CurrentSymbolIndex();
   const int benchmark_index = Strategy_SymbolIndex(strategy_benchmark_symbol);
   if(current_index < 0 || benchmark_index < 0)
      return false;

   double scores[QM5_12373_SYMBOL_COUNT];
   int indexes[QM5_12373_SYMBOL_COUNT];
   int count = 0;

   for(int i = 0; i < QM5_12373_SYMBOL_COUNT; ++i)
     {
      double alpha = 0.0;
      if(!Strategy_AlphaForSymbol(g_symbols[i], strategy_benchmark_symbol, alpha))
         return false;
      scores[count] = alpha;
      indexes[count] = i;
      ++count;
     }

   Strategy_SortDescending(scores, indexes, count);

   for(int rank = 0; rank < count; ++rank)
      if(indexes[rank] == current_index)
        {
         g_cached_rank = rank + 1;
         g_cached_alpha = scores[rank];
         g_rank_ready = true;
         return true;
        }

   return false;
  }

bool Strategy_SpreadBlocks()
  {
   if(strategy_max_spread_points <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   const double cap = strategy_max_spread_points * point;
   if(ask > bid && (ask - bid) > cap)
      return true;
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 12373)
      return true;

   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   if(qm_magic_slot_offset != g_slots[index])
      return true;
   if(Strategy_SymbolIndex(strategy_benchmark_symbol) < 0)
      return true;
   if(strategy_lookback_returns < 5 || strategy_top_n < 1 || strategy_top_n > QM5_12373_SYMBOL_COUNT)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(!Strategy_SelectBasket())
      return true;
   return Strategy_SpreadBlocks();
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(!Strategy_IsWeeklyRebalanceBar())
      return false;
   if(!Strategy_UpdateRankCache())
      return false;

   const int top_n = MathMin(QM5_12373_SYMBOL_COUNT, MathMax(1, strategy_top_n));
   if(g_cached_rank <= 0 || g_cached_rank > top_n)
      return false;
   if(strategy_alpha_positive_gate && g_cached_alpha <= 0.0)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= entry_price)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.reason = "QM5_12373_TOPN_OLS_ALPHA_LONG";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card defines only the initial ATR hard stop; no trailing, partial, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   if(!g_rank_ready)
      return false;

   const int top_n = MathMin(QM5_12373_SYMBOL_COUNT, MathMax(1, strategy_top_n));
   if(g_cached_rank <= 0 || g_cached_rank > top_n)
      return true;
   if(strategy_alpha_positive_gate && g_cached_alpha <= 0.0)
      return true;
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   Strategy_SelectBasket();

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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_lookback_returns + strategy_atr_period + 20);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12373\",\"ea\":\"tmom-alpha-rot\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
