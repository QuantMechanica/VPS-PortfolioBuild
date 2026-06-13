#property strict
#property version   "5.0"
#property description "QM5_1048 Estrada Lazy 6-Month Country-Index Rotation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy card: QM5_1048 estrada-lazy-6m-rotation, G0 APPROVED.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1048;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_lookback_d1_bars     = 126;
input int    strategy_top_n                = 2;
input int    strategy_atr_period           = 14;
input double strategy_atr_sl_mult          = 4.0;
input bool   strategy_absolute_momentum    = false;
input int    strategy_max_spread_points    = 0;

#define STRATEGY_UNIVERSE_SIZE 4

string g_strategy_symbols[STRATEGY_UNIVERSE_SIZE] = {"NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"};
int    g_strategy_slots[STRATEGY_UNIVERSE_SIZE]   = {0, 1, 2, 3};
int    g_last_entry_rebalance_key = 0;
int    g_last_close_rebalance_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentMonthCandidateKey()
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.day > 7)
      return 0;
   if(now_dt.mon != 1 && now_dt.mon != 7)
      return 0;
   return now_dt.year * 100 + now_dt.mon;
  }

int Strategy_RebalanceExecutionKey()
  {
   datetime current_time[1];
   datetime previous_time[1];
   if(CopyTime(_Symbol, PERIOD_D1, 0, 1, current_time) != 1) // perf-allowed: one closed-bar schedule read inside new-bar entry gate.
      return 0;
   if(CopyTime(_Symbol, PERIOD_D1, 1, 1, previous_time) != 1) // perf-allowed: one closed-bar schedule read inside new-bar entry gate.
      return 0;

   MqlDateTime cur_dt;
   MqlDateTime prev_dt;
   TimeToStruct(current_time[0], cur_dt);
   TimeToStruct(previous_time[0], prev_dt);

   if(cur_dt.mon == 1 && prev_dt.mon == 12 && cur_dt.year == prev_dt.year + 1)
      return cur_dt.year * 100 + cur_dt.mon;
   if(cur_dt.mon == 7 && prev_dt.mon == 6 && cur_dt.year == prev_dt.year)
      return cur_dt.year * 100 + cur_dt.mon;
   return 0;
  }

double Strategy_TrailingReturn(const string symbol)
  {
   if(strategy_lookback_d1_bars <= 0)
      return -DBL_MAX;

   if(!SymbolSelect(symbol, true))
      return -DBL_MAX;

   double recent_close[1];
   double lookback_close[1];
   if(CopyClose(symbol, PERIOD_D1, 1, 1, recent_close) != 1) // perf-allowed: one value per universe symbol on D1 rebalance bars only.
      return -DBL_MAX;
   if(CopyClose(symbol, PERIOD_D1, strategy_lookback_d1_bars + 1, 1, lookback_close) != 1) // perf-allowed: fixed 6-month lookback proxy on D1 rebalance bars only.
      return -DBL_MAX;

   if(recent_close[0] <= 0.0 || lookback_close[0] <= 0.0)
      return -DBL_MAX;
   return (recent_close[0] / lookback_close[0]) - 1.0;
  }

int Strategy_NormalizedTopN()
  {
   int top_n = strategy_top_n;
   if(top_n < 1)
      top_n = 1;
   if(top_n > STRATEGY_UNIVERSE_SIZE)
      top_n = STRATEGY_UNIVERSE_SIZE;
   return top_n;
  }

bool Strategy_SymbolIsSelected(const string symbol)
  {
   double returns[STRATEGY_UNIVERSE_SIZE];
   int order[STRATEGY_UNIVERSE_SIZE];

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      returns[i] = Strategy_TrailingReturn(g_strategy_symbols[i]);
      order[i] = i;
     }

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE - 1; ++i)
     {
      for(int j = i + 1; j < STRATEGY_UNIVERSE_SIZE; ++j)
        {
         if(returns[order[j]] > returns[order[i]])
           {
            const int tmp = order[i];
            order[i] = order[j];
            order[j] = tmp;
           }
        }
     }

   const int top_n = Strategy_NormalizedTopN();
   for(int rank = 0; rank < top_n; ++rank)
     {
      const int idx = order[rank];
      if(g_strategy_symbols[idx] != symbol)
         continue;
      if(returns[idx] <= -DBL_MAX / 2.0)
         return false;
      if(strategy_absolute_momentum && returns[idx] < 0.0)
         return false;
      return true;
     }

   return false;
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
   const int symbol_idx = Strategy_CurrentSymbolIndex();
   if(symbol_idx < 0)
      return true;

   if(g_strategy_slots[symbol_idx] != qm_magic_slot_offset)
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
   req.reason = "QM5_1048_SEMIANNUAL_TOP_HALF";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;

   const int rebalance_key = Strategy_RebalanceExecutionKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SymbolIsSelected(_Symbol))
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
   // The card specifies no mid-cycle trailing, partial close, or break-even logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;

   const int rebalance_key = Strategy_CurrentMonthCandidateKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_close_rebalance_key)
      return false;

   g_last_close_rebalance_key = rebalance_key;
   return Strategy_HasOpenPosition();
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1048\",\"ea\":\"estrada-lazy-6m-rotation\"}");
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
