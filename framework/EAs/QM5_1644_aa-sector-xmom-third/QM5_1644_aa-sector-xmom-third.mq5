#property strict
#property version   "5.0"
#property description "QM5_1644 AA Sector/Index Proxy Cross-Sectional Momentum Thirds"

#include <QM/QM_Common.mqh>

#define STRATEGY_SYMBOL_COUNT 5
#define STRATEGY_MONTH_DEPTH  16

string g_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX"
  };

int g_symbol_slots[STRATEGY_SYMBOL_COUNT] = {0, 1, 2, 3, 4};

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1644;
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
input int    strategy_month_proxy_bars   = 21;
input int    strategy_roc_recent_months  = 3;
input int    strategy_roc_old_months     = 13;
input int    strategy_min_monthly_bars   = 14;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_max_long_slots     = 5;
input int    strategy_max_short_slots    = 5;
input double strategy_spread_mult        = 2.5;

double g_monthly_closes[STRATEGY_SYMBOL_COUNT][STRATEGY_MONTH_DEPTH];
int    g_target_position[STRATEGY_SYMBOL_COUNT];
double g_spread_points[20];
int    g_spread_idx = 0;
bool   g_spread_ready = false;
int    g_my_symbol_idx = -1;
int    g_last_month_key = -1;
bool   g_targets_ready = false;
bool   g_rebalance_happened = false;

int Strategy_SymbolIndex(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == symbol)
         return i;
   return -1;
  }

int Strategy_SymbolSlot(const string symbol)
  {
   const int idx = Strategy_SymbolIndex(symbol);
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_symbol_slots[idx];
  }

double Strategy_CurrentSpreadPoints(const string symbol)
  {
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return 0.0;
   if(ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

double Strategy_MedianSpreadPoints()
  {
   double vals[20];
   for(int i = 0; i < 20; ++i)
      vals[i] = g_spread_points[i];

   for(int i = 0; i < 19; ++i)
      for(int j = i + 1; j < 20; ++j)
         if(vals[j] < vals[i])
           {
            const double tmp = vals[i];
            vals[i] = vals[j];
            vals[j] = tmp;
           }

   return (vals[9] + vals[10]) * 0.5;
  }

bool Strategy_SpreadOk()
  {
   if(!g_spread_ready)
      return true;
   const double median_spread = Strategy_MedianSpreadPoints();
   const double current_spread = Strategy_CurrentSpreadPoints(_Symbol);
   if(current_spread > 0.0 && median_spread > 0.0 &&
      current_spread > strategy_spread_mult * median_spread)
      return false;
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

void Strategy_ResetTargets()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      g_target_position[i] = 0;
  }

void Strategy_ComputeTargetPositions()
  {
   Strategy_ResetTargets();
   g_targets_ready = false;

   const int recent_idx = MathMax(1, strategy_roc_recent_months) - 1;
   const int old_idx = MathMax(1, strategy_roc_old_months) - 1;
   if(recent_idx < 0 || recent_idx >= STRATEGY_MONTH_DEPTH ||
      old_idx < 0 || old_idx >= STRATEGY_MONTH_DEPTH ||
      strategy_min_monthly_bars > STRATEGY_MONTH_DEPTH - 1)
      return;

   double roc[STRATEGY_SYMBOL_COUNT];
   int rank[STRATEGY_SYMBOL_COUNT];
   int valid_count = 0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      rank[i] = i;
      const double recent_close = g_monthly_closes[i][recent_idx];
      const double old_close = g_monthly_closes[i][old_idx];
      if(recent_close > 0.0 && old_close > 0.0)
        {
         roc[i] = recent_close / old_close - 1.0;
         valid_count++;
        }
      else
         roc[i] = -DBL_MAX;
     }

   if(valid_count < STRATEGY_SYMBOL_COUNT)
      return;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT - 1; ++i)
      for(int j = i + 1; j < STRATEGY_SYMBOL_COUNT; ++j)
         if(roc[rank[j]] > roc[rank[i]])
           {
            const int tmp = rank[i];
            rank[i] = rank[j];
            rank[j] = tmp;
           }

   const int third = MathMax(1, valid_count / 3);
   const int long_count = MathMin(third, strategy_max_long_slots);
   const int short_count = MathMin(third, strategy_max_short_slots);

   for(int i = 0; i < long_count; ++i)
      g_target_position[rank[i]] = 1;
   for(int i = 0; i < short_count; ++i)
      g_target_position[rank[valid_count - 1 - i]] = -1;

   g_targets_ready = true;
  }

void Strategy_LoadMonthlyProxyHistory()
  {
   ArrayInitialize(g_monthly_closes, 0.0);
   const int month_bars = MathMax(1, strategy_month_proxy_bars);
   for(int s = 0; s < STRATEGY_SYMBOL_COUNT; ++s)
     {
      for(int m = 0; m < STRATEGY_MONTH_DEPTH; ++m)
        {
         const int shift = 1 + (m * month_bars);
         g_monthly_closes[s][m] = QM_SMA(g_symbols[s], PERIOD_D1, 1, shift);
        }
     }
   Strategy_ComputeTargetPositions();
  }

void Strategy_RecordCurrentMonthClose()
  {
   for(int d = STRATEGY_MONTH_DEPTH - 1; d > 0; --d)
      for(int s = 0; s < STRATEGY_SYMBOL_COUNT; ++s)
         g_monthly_closes[s][d] = g_monthly_closes[s][d - 1];

   for(int s = 0; s < STRATEGY_SYMBOL_COUNT; ++s)
     {
      const double close_last = QM_SMA(g_symbols[s], PERIOD_D1, 1, 1);
      if(close_last > 0.0)
         g_monthly_closes[s][0] = close_last;
     }
  }

void Strategy_AdvanceStateOnNewBar()
  {
   g_rebalance_happened = false;

   g_spread_points[g_spread_idx % 20] = Strategy_CurrentSpreadPoints(_Symbol);
   g_spread_idx++;
   if(g_spread_idx >= 20)
      g_spread_ready = true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int month_key = dt.year * 12 + dt.mon;
   if(g_last_month_key < 0)
     {
      g_last_month_key = month_key;
      g_rebalance_happened = g_targets_ready;
      return;
     }
   if(month_key == g_last_month_key)
      return;

   g_last_month_key = month_key;
   Strategy_RecordCurrentMonthClose();
   Strategy_ComputeTargetPositions();
   g_rebalance_happened = g_targets_ready;
   if(g_rebalance_happened)
     {
      const int my_target = (g_my_symbol_idx >= 0) ? g_target_position[g_my_symbol_idx] : 0;
      QM_LogEvent(QM_INFO, "MONTHLY_REBALANCE",
                  StringFormat("{\"my_target\":%d,\"month_key\":%d}", my_target, month_key));
     }
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(g_my_symbol_idx < 0)
      return true;
   if(qm_magic_slot_offset != Strategy_SymbolSlot(_Symbol))
      return true;
   if(!Strategy_SpreadOk())
      return true;
   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_rebalance_happened || !g_targets_ready || g_my_symbol_idx < 0)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const int target = g_target_position[g_my_symbol_idx];
   if(target == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.price = 0.0;
   req.tp = 0.0;

   if(target > 0)
     {
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "AA_XMOM_TOP_THIRD";
      return (req.sl > 0.0);
     }

   req.type = QM_SELL;
   req.sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
   req.reason = "AA_XMOM_BOTTOM_THIRD";
   return (req.sl > 0.0);
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_rebalance_happened || !g_targets_ready || g_my_symbol_idx < 0)
      return false;

   const int target = g_target_position[g_my_symbol_idx];
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

      const bool position_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      if(target > 0 && position_long)
         return false;
      if(target < 0 && !position_long)
         return false;
      return true;
     }
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   g_my_symbol_idx = Strategy_SymbolIndex(_Symbol);
   if(g_my_symbol_idx < 0)
     {
      Print("QM5_1644 INIT_FAILED: symbol not in approved universe: ", _Symbol);
      return INIT_FAILED;
     }
   if(qm_magic_slot_offset != Strategy_SymbolSlot(_Symbol))
     {
      Print("QM5_1644 INIT_FAILED: slot mismatch for ", _Symbol,
            " expected=", Strategy_SymbolSlot(_Symbol),
            " got=", qm_magic_slot_offset);
      return INIT_FAILED;
     }

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);

   ArrayInitialize(g_target_position, 0);
   ArrayInitialize(g_spread_points, 0.0);

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
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(360, strategy_month_proxy_bars * STRATEGY_MONTH_DEPTH + 20));
   Strategy_LoadMonthlyProxyHistory();

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"card\":\"QM5_1644\",\"strategy\":\"aa-sector-xmom-third\",\"symbol_index\":%d}",
                            g_my_symbol_idx));
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_AdvanceStateOnNewBar();
     }

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!is_new_bar)
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
