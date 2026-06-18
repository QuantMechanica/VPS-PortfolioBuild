#property strict
#property version   "5.0"
#property description "QM5_12374 ThewindMom R-Squared Selectivity Rotation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12374;
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
input int    strategy_lookback_returns       = 60;
input int    strategy_top_n                  = 3;
input int    strategy_rebalance_interval_d1  = 5;
input int    strategy_min_warmup_returns     = 80;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 2.0;
input bool   strategy_use_directional_overlay = false;
input int    strategy_directional_return_bars = 20;
input string strategy_benchmark_symbol       = "SP500.DWX";

#define STRATEGY_SYMBOL_COUNT 4

string g_symbols[STRATEGY_SYMBOL_COUNT] = {"GDAXI.DWX", "NDX.DWX", "WS30.DWX", "SP500.DWX"};
int    g_slots[STRATEGY_SYMBOL_COUNT]   = {0, 1, 2, 3};

bool   g_state_ready = false;
bool   g_is_selected = false;
int    g_bars_since_rebalance = 1000000;
double g_last_selectivity = 0.0;
int    g_last_rank = -1;

int Strategy_SymbolIndex(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == symbol)
         return i;
   return -1;
  }

int Strategy_ActiveTopN()
  {
   if(strategy_top_n < 1)
      return 1;
   if(strategy_top_n > STRATEGY_SYMBOL_COUNT)
      return STRATEGY_SYMBOL_COUNT;
   return strategy_top_n;
  }

int Strategy_ActiveLookback()
  {
   if(strategy_lookback_returns < 2)
      return 2;
   return strategy_lookback_returns;
  }

int Strategy_ActiveWarmup()
  {
   int warmup = strategy_min_warmup_returns;
   const int lookback = Strategy_ActiveLookback();
   if(warmup < lookback)
      warmup = lookback;
   return warmup;
  }

bool Strategy_CopyCloses(const string symbol, const int count, double &closes[])
  {
   if(count < 3)
      return false;
   ArrayResize(closes, count);
   ArraySetAsSeries(closes, true);
   return (CopyClose(symbol, PERIOD_D1, 1, count, closes) == count); // perf-allowed: bounded D1 basket close read; called only from Strategy_EntrySignal after the framework QM_IsNewBar gate.
  }

double Strategy_ReturnAt(const double &closes[], const int index)
  {
   if(closes[index] <= 0.0 || closes[index + 1] <= 0.0)
      return 0.0;
   return (closes[index] / closes[index + 1]) - 1.0;
  }

bool Strategy_ComputeR2(const string symbol,
                        const double &benchmark_closes[],
                        const int lookback,
                        double &r2,
                        double &selectivity)
  {
   r2 = 0.0;
   selectivity = 0.0;

   double closes[];
   const int close_count = Strategy_ActiveWarmup() + 1;
   if(!Strategy_CopyCloses(symbol, close_count, closes))
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      sum_x += Strategy_ReturnAt(benchmark_closes, i);
      sum_y += Strategy_ReturnAt(closes, i);
     }

   const double mean_x = sum_x / (double)lookback;
   const double mean_y = sum_y / (double)lookback;

   double var_x = 0.0;
   double cov_xy = 0.0;
   double ss_tot = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double x = Strategy_ReturnAt(benchmark_closes, i);
      const double y = Strategy_ReturnAt(closes, i);
      const double dx = x - mean_x;
      const double dy = y - mean_y;
      var_x += dx * dx;
      cov_xy += dx * dy;
      ss_tot += dy * dy;
     }

   if(ss_tot <= 0.0)
     {
      r2 = 0.0;
      selectivity = 1.0;
      return true;
     }

   double ss_res = 0.0;
   if(var_x <= 0.0)
     {
      ss_res = ss_tot;
     }
   else
     {
      const double beta = cov_xy / var_x;
      const double alpha = mean_y - beta * mean_x;
      for(int i = 0; i < lookback; ++i)
        {
         const double x = Strategy_ReturnAt(benchmark_closes, i);
         const double y = Strategy_ReturnAt(closes, i);
         const double y_pred = alpha + beta * x;
         const double err = y - y_pred;
         ss_res += err * err;
        }
     }

   r2 = 1.0 - (ss_res / ss_tot);
   selectivity = 1.0 - r2;
   return (MathIsValidNumber(r2) && MathIsValidNumber(selectivity));
  }

bool Strategy_PassesDirectionalOverlay()
  {
   if(!strategy_use_directional_overlay)
      return true;

   const int bars = (strategy_directional_return_bars < 1) ? 1 : strategy_directional_return_bars;
   double closes[];
   if(!Strategy_CopyCloses(_Symbol, bars + 1, closes))
      return false;
   if(closes[0] <= 0.0 || closes[bars] <= 0.0)
      return false;
   return (closes[0] > closes[bars]);
  }

void Strategy_RefreshSelection()
  {
   g_state_ready = false;
   g_is_selected = false;
   g_last_selectivity = 0.0;
   g_last_rank = -1;

   const int my_index = Strategy_SymbolIndex(_Symbol);
   if(my_index < 0)
      return;
   if(qm_magic_slot_offset != g_slots[my_index])
      return;

   const int lookback = Strategy_ActiveLookback();
   const int close_count = Strategy_ActiveWarmup() + 1;
   double benchmark_closes[];
   if(!Strategy_CopyCloses(strategy_benchmark_symbol, close_count, benchmark_closes))
      return;

   double selectivity[STRATEGY_SYMBOL_COUNT];
   bool valid[STRATEGY_SYMBOL_COUNT];
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      selectivity[i] = -DBL_MAX;
      valid[i] = false;

      double r2 = 0.0;
      double sel = 0.0;
      if(Strategy_ComputeR2(g_symbols[i], benchmark_closes, lookback, r2, sel))
        {
         selectivity[i] = sel;
         valid[i] = true;
        }
     }

   if(!valid[my_index])
      return;

   int rank = 0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(i == my_index || !valid[i])
         continue;
      if(selectivity[i] > selectivity[my_index])
         ++rank;
     }

   g_last_rank = rank;
   g_last_selectivity = selectivity[my_index];
   g_is_selected = (rank < Strategy_ActiveTopN()) && Strategy_PassesDirectionalOverlay();
   g_state_ready = true;

   QM_LogEvent(QM_INFO, "RSQ_REBALANCE",
               StringFormat("{\"symbol\":\"%s\",\"selected\":%s,\"rank\":%d,\"top_n\":%d,\"selectivity\":%.8f,\"lookback\":%d}",
                            QM_LoggerEscapeJson(_Symbol),
                            g_is_selected ? "true" : "false",
                            rank,
                            Strategy_ActiveTopN(),
                            g_last_selectivity,
                            lookback));
  }

void Strategy_AdvanceStateOnD1Bar()
  {
   ++g_bars_since_rebalance;
   if(g_bars_since_rebalance < strategy_rebalance_interval_d1 && g_state_ready)
      return;

   g_bars_since_rebalance = 0;
   Strategy_RefreshSelection();
  }

bool Strategy_HasOurPosition()
  {
   const long magic = (long)QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   const int my_index = Strategy_SymbolIndex(_Symbol);
   if(my_index < 0)
      return true;
   if(qm_magic_slot_offset != g_slots[my_index])
      return true;
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_AdvanceStateOnD1Bar();

   if(!g_state_ready || !g_is_selected)
      return false;
   if(Strategy_HasOurPosition())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - (atr * strategy_atr_sl_mult));
   req.tp = 0.0;
   req.reason = "QM5_12374_RSQ_SELECTIVITY_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && req.sl < ask);
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready)
      return false;
   if(g_is_selected)
      return false;
   return Strategy_HasOurPosition();
  }

// News Filter Hook (callable for P8 News Impact phase).
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, Strategy_ActiveWarmup() + 10);

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
