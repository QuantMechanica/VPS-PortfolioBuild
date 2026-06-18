#property strict
#property version   "5.0"
#property description "QM5_12389 asset-rot-mom - monthly 12-month momentum asset rotation"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// QuantMechanica V5 EA - QM5_12389 asset-rot-mom
// Source: Papers With Backtest / Quantpedia implementation,
// Momentum Asset Allocation Strategy, source_id b7832a20-938e-5f24-b9d7-e0b2ab63b623.
//
// Basket EA: every host symbol ranks the same DWX universe on closed D1 bars
// once per calendar month. The host opens/holds only when it is in the top N by
// ROC(lookback). Long-only, one position per host magic.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12389;
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
input int    strategy_momentum_lookback_d1 = 252;  // source implementation: ROC(12 * 21)
input int    strategy_selection_count      = 3;    // hold the strongest three assets
input int    strategy_min_ready_symbols    = 5;    // require broad enough basket data
input int    strategy_atr_period           = 20;   // emergency stop ATR period
input double strategy_stop_atr_mult        = 3.0;  // emergency stop = ATR * mult
input bool   strategy_abs_momentum_filter  = false;// Q03 option: selected ROC must be positive
input bool   strategy_use_trailing_stop    = false;// optional card trailing stop
input double strategy_trail_atr_mult       = 4.0;  // optional ATR trailing stop
input int    strategy_spread_days          = 60;   // MedianSpread lookback
input double strategy_spread_median_mult   = 2.0;  // block current spread > median * mult

#define QM_ARM_MAX_SYMBOLS 8

string g_symbols[QM_ARM_MAX_SYMBOLS];
int    g_symbol_count = 0;
int    g_host_index = -1;

double g_roc[QM_ARM_MAX_SYMBOLS];
bool   g_ready_symbol[QM_ARM_MAX_SYMBOLS];
int    g_rank[QM_ARM_MAX_SYMBOLS];
int    g_ready_count = 0;
int    g_eval_month_key = 0;
bool   g_eval_ready = false;
bool   g_rebalance_bar = false;
double g_cached_median_spread_points = 0.0;

void ARM_BuildUniverse()
  {
   string u[] =
     {
      "SP500.DWX",
      "NDX.DWX",
      "WS30.DWX",
      "GDAXI.DWX",
      "XAUUSD.DWX",
      "XTIUSD.DWX"
     };
   g_symbol_count = ArraySize(u);
   if(g_symbol_count > QM_ARM_MAX_SYMBOLS)
      g_symbol_count = QM_ARM_MAX_SYMBOLS;
   for(int i = 0; i < g_symbol_count; ++i)
      g_symbols[i] = u[i];
  }

void ARM_BuildWarmupList(string &out[])
  {
   ArrayResize(out, g_symbol_count + 1);
   int n = 0;
   out[n++] = _Symbol;
   for(int i = 0; i < g_symbol_count; ++i)
     {
      bool duplicate = false;
      for(int j = 0; j < n; ++j)
        {
         if(out[j] == g_symbols[i])
           {
            duplicate = true;
            break;
           }
        }
      if(!duplicate)
         out[n++] = g_symbols[i];
     }
   ArrayResize(out, n);
  }

int ARM_MonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
  }

bool ARM_IsFirstTradableBarOfMonth()
  {
   const int key = ARM_MonthKey();
   return (key > 0 && key != g_eval_month_key);
  }

double ARM_ROC(const string sym, const int lookback)
  {
   if(lookback < 2)
      return 0.0;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int count = lookback + 1;
   const int got = CopyClose(sym, PERIOD_D1, 1, count, closes); // perf-allowed: bounded D1 ROC basket read after framework QM_IsNewBar gate and monthly cadence.
   if(got != count)
      return 0.0;

   const double recent = closes[0];
   const double past = closes[lookback];
   if(recent <= 0.0 || past <= 0.0)
      return 0.0;
   return (recent - past) / past;
  }

void ARM_UpdateMedianSpread()
  {
   g_cached_median_spread_points = 0.0;
   if(strategy_spread_days <= 0)
      return;

   MqlRates rates[];
   const int need = MathMin(strategy_spread_days, 120);
   // perf-allowed: bounded D1 spread snapshot for card MedianSpread(60D),
   // called only on monthly rebalance bars, never per tick.
   const int got = CopyRates(_Symbol, PERIOD_D1, 1, need, rates); // perf-allowed: bounded D1 spread snapshot on monthly rebalance bars only.
   if(got <= 0)
      return;

   double spreads[];
   ArrayResize(spreads, got);
   int n = 0;
   for(int i = 0; i < got; ++i)
     {
      if(rates[i].spread > 0)
         spreads[n++] = (double)rates[i].spread;
     }
   if(n <= 0)
      return; // .DWX often has zero modeled spread; fail open.
   ArrayResize(spreads, n);

   for(int a = 0; a < n; ++a)
      for(int b = a + 1; b < n; ++b)
         if(spreads[b] < spreads[a])
           {
            const double tmp = spreads[a];
            spreads[a] = spreads[b];
            spreads[b] = tmp;
           }

   if((n % 2) == 1)
      g_cached_median_spread_points = spreads[n / 2];
   else
      g_cached_median_spread_points = 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
  }

void ARM_AdvanceRank()
  {
   g_eval_ready = false;
   g_rebalance_bar = true;
   g_ready_count = 0;
   g_eval_month_key = ARM_MonthKey();

   for(int i = 0; i < g_symbol_count; ++i)
     {
      g_roc[i] = 0.0;
      g_ready_symbol[i] = false;
      g_rank[i] = -1;

      const double roc = ARM_ROC(g_symbols[i], strategy_momentum_lookback_d1);
      if(roc == 0.0)
         continue;

      g_roc[i] = roc;
      g_ready_symbol[i] = true;
      ++g_ready_count;
     }

   ARM_UpdateMedianSpread();

   if(g_ready_count < strategy_min_ready_symbols)
      return;

   int idx[QM_ARM_MAX_SYMBOLS];
   int n = 0;
   for(int i = 0; i < g_symbol_count; ++i)
      if(g_ready_symbol[i])
         idx[n++] = i;

   for(int a = 0; a < n; ++a)
      for(int b = a + 1; b < n; ++b)
         if(g_roc[idx[b]] > g_roc[idx[a]])
           {
            const int tmp = idx[a];
            idx[a] = idx[b];
            idx[b] = tmp;
           }

   for(int a = 0; a < n; ++a)
      g_rank[idx[a]] = a;

   g_eval_ready = true;
  }

bool ARM_HasOpenLong()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         return true;
     }
   return false;
  }

bool ARM_HostSelected(const bool allow_smaller_than_top3)
  {
   if(!g_eval_ready || g_host_index < 0)
      return false;
   if(g_ready_count < 2)
      return false;
   if(!g_ready_symbol[g_host_index])
      return false;
   if(strategy_abs_momentum_filter && g_roc[g_host_index] <= 0.0)
      return false;

   int target = strategy_selection_count;
   if(target < 1)
      target = 1;
   if(target > g_ready_count && allow_smaller_than_top3)
      target = g_ready_count;

   const int host_rank = g_rank[g_host_index];
   return (host_rank >= 0 && host_rank < target);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points <= 0)
      return false; // .DWX zero modeled spread must not fail closed.
   if(g_cached_median_spread_points <= 0.0)
      return false;
   return ((double)spread_points > strategy_spread_median_mult * g_cached_median_spread_points);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_rebalance_bar)
      return false;
   if(ARM_HasOpenLong())
      return false;
   if(!ARM_HostSelected(true))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "asset_rot_mom_monthly_top3";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   if(!strategy_use_trailing_stop)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!g_rebalance_bar)
      return false;
   if(!ARM_HasOpenLong())
      return false;
   return !ARM_HostSelected(true);
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring. Basket warmup and single-consume new-bar latching are needed
// for cross-symbol closed-bar ranking.
// -----------------------------------------------------------------------------

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

   ARM_BuildUniverse();
   g_host_index = -1;
   for(int i = 0; i < g_symbol_count; ++i)
      if(g_symbols[i] == _Symbol)
        {
         g_host_index = i;
         break;
        }

   string warmup[];
   ARM_BuildWarmupList(warmup);
   QM_SymbolGuardInit(warmup);
   QM_BasketWarmupHistory(warmup, PERIOD_D1, strategy_momentum_lookback_d1 + strategy_atr_period + strategy_spread_days + 10);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"ea\":\"QM5_12389_asset_rot_mom\",\"host\":\"%s\",\"host_idx\":%d,\"universe\":%d}",
                            _Symbol, g_host_index, g_symbol_count));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   g_rebalance_bar = false;

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

   const bool nb = QM_IsNewBar();
   if(nb && ARM_IsFirstTradableBarOfMonth())
      ARM_AdvanceRank();

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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!nb)
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
