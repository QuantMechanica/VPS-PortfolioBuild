#property strict
#property version   "5.0"
#property description "QM5_10881 NexusTrade all-weather momentum proxy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy card: QM5_10881 nt-aw-mom, G0 APPROVED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10881;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_lookback_d1_bars = 21;
input int    strategy_trend_sma_period          = 200;
input int    strategy_atr_period                = 14;
input double strategy_atr_sl_mult               = 2.5;
input int    strategy_min_history_d1_bars       = 221;
input int    strategy_max_spread_points         = 0;

#define STRATEGY_SYMBOL_COUNT 3

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] = {"SP500.DWX", "NDX.DWX", "WS30.DWX"};
int    g_strategy_slots[STRATEGY_SYMBOL_COUNT]   = {0, 1, 2};
int    g_last_entry_rebalance_key                = 0;
int    g_last_exit_rebalance_key                 = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_strategy_slots[idx];
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

datetime Strategy_CurrentD1BarTime()
  {
   return iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 month-boundary schedule read for monthly rebalance.
  }

bool Strategy_IsFirstTradingDayOfMonth()
  {
   if(_Period != PERIOD_D1)
      return false;

   const datetime current_bar = Strategy_CurrentD1BarTime();
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 month-boundary schedule read for monthly rebalance.
   if(current_bar <= 0 || closed_bar <= 0)
      return false;

   MqlDateTime current_dt;
   MqlDateTime closed_dt;
   TimeToStruct(current_bar, current_dt);
   TimeToStruct(closed_bar, closed_dt);
   return (current_dt.year != closed_dt.year || current_dt.mon != closed_dt.mon);
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

bool Strategy_HasMinimumHistory(const string symbol)
  {
   const int warmup = MathMax(strategy_min_history_d1_bars,
                              MathMax(strategy_trend_sma_period,
                                      strategy_momentum_lookback_d1_bars + 2));
   if(warmup <= 0)
      return false;

   const datetime t = iTime(symbol, PERIOD_D1, warmup); // perf-allowed: fixed warmup availability check on monthly D1 rebalance only.
   return (t > 0);
  }

bool Strategy_Roc21(const string symbol, double &out_roc)
  {
   out_roc = 0.0;
   if(strategy_momentum_lookback_d1_bars <= 0)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;
   if(!Strategy_HasMinimumHistory(symbol))
      return false;

   const double momentum = QM_Momentum(symbol,
                                       PERIOD_D1,
                                       strategy_momentum_lookback_d1_bars,
                                       1,
                                       PRICE_CLOSE);
   if(momentum <= 0.0)
      return false;

   out_roc = (momentum / 100.0) - 1.0;
   return true;
  }

bool Strategy_TrendOk(const string symbol)
  {
   if(strategy_trend_sma_period <= 0)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   return (QM_Sig_Price_Above_MA(symbol,
                                 PERIOD_D1,
                                 strategy_trend_sma_period,
                                 0.0,
                                 1) > 0);
  }

int Strategy_TopMomentumIndex(double &out_top_roc)
  {
   out_top_roc = -DBL_MAX;
   int top_idx = -1;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      double roc = 0.0;
      if(!Strategy_Roc21(g_strategy_symbols[i], roc))
         continue;
      if(roc > out_top_roc)
        {
         out_top_roc = roc;
         top_idx = i;
        }
     }

   return top_idx;
  }

bool Strategy_CurrentSymbolQualifies()
  {
   const int current_idx = Strategy_CurrentSymbolIndex();
   if(current_idx < 0)
      return false;

   double top_roc = 0.0;
   const int top_idx = Strategy_TopMomentumIndex(top_roc);
   if(top_idx != current_idx)
      return false;
   if(top_roc <= 0.0)
      return false;
   return Strategy_TrendOk(_Symbol);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   const int symbol_idx = Strategy_CurrentSymbolIndex();
   if(symbol_idx < 0)
      return true;

   if(g_strategy_slots[symbol_idx] != qm_magic_slot_offset)
      return true;

   if(strategy_momentum_lookback_d1_bars <= 0 ||
      strategy_trend_sma_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10881_MONTHLY_ROC21_TOP_INDEX";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   if(!Strategy_IsFirstTradingDayOfMonth())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(Strategy_CurrentD1BarTime());
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_CurrentSymbolQualifies())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed initial ATR stop only; no trailing, break-even, or partial close.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsFirstTradingDayOfMonth())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(Strategy_CurrentD1BarTime());
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;

   return !Strategy_CurrentSymbolQualifies();
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_SymbolGuardInit(g_strategy_symbols);
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(g_strategy_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10881\",\"ea\":\"QM5_10881_nt_aw_mom\"}");
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
