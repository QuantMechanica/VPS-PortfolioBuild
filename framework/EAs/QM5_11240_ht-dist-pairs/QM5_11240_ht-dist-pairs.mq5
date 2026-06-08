#property strict
#property version   "5.0"
#property description "QM5_11240 Hudson Thames Distance Pair Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11240;
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
input int    strategy_formation_bars     = 252;
input double strategy_entry_z            = 2.0;
input double strategy_stop_z             = 4.0;
input int    strategy_max_hold_bars      = 60;

#define STRATEGY_PAIR_COUNT 4
#define STRATEGY_SYMBOL_COUNT 8
#define STRATEGY_TOP_PAIR_LIMIT 5

string g_pair_a[STRATEGY_PAIR_COUNT] = {"EURUSD.DWX", "AUDUSD.DWX", "XAUUSD.DWX", "NDX.DWX"};
string g_pair_b[STRATEGY_PAIR_COUNT] = {"GBPUSD.DWX", "NZDUSD.DWX", "XAGUSD.DWX", "WS30.DWX"};
int    g_pair_a_slot[STRATEGY_PAIR_COUNT] = {0, 2, 4, 6};
int    g_pair_b_slot[STRATEGY_PAIR_COUNT] = {1, 3, 5, 7};

string g_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "NZDUSD.DWX",
   "XAUUSD.DWX", "XAGUSD.DWX", "NDX.DWX", "WS30.DWX"
  };

bool     g_pair_valid[STRATEGY_PAIR_COUNT];
bool     g_pair_selected[STRATEGY_PAIR_COUNT];
double   g_pair_distance[STRATEGY_PAIR_COUNT];
double   g_pair_spread_now[STRATEGY_PAIR_COUNT];
double   g_pair_spread_prev[STRATEGY_PAIR_COUNT];
double   g_pair_spread_std[STRATEGY_PAIR_COUNT];
double   g_pair_range_a[STRATEGY_PAIR_COUNT];
double   g_pair_range_b[STRATEGY_PAIR_COUNT];
datetime g_pair_entry_time[STRATEGY_PAIR_COUNT];
int      g_active_pair = -1;
bool     g_state_ready = false;

int Strategy_PairIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      if(symbol == g_pair_a[i] || symbol == g_pair_b[i])
         return i;
     }
   return -1;
  }

bool Strategy_IsPairLeg(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   return (symbol == g_pair_a[pair_index] || symbol == g_pair_b[pair_index]);
  }

int Strategy_SlotForSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return qm_magic_slot_offset;
   if(symbol == g_pair_a[pair_index])
      return g_pair_a_slot[pair_index];
   if(symbol == g_pair_b[pair_index])
      return g_pair_b_slot[pair_index];
   return qm_magic_slot_offset;
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_11240_PAIR_ENGINE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_CopyCloses(const string symbol, const int count, double &closes[])
  {
   if(count < 2)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_D1, 1, count, closes); // perf-allowed: called only from the D1 new-bar refresh path.
   if(copied != count)
      return false;

   for(int i = 0; i < count; ++i)
     {
      if(closes[i] <= 0.0 || !MathIsValidNumber(closes[i]))
         return false;
     }
   return true;
  }

bool Strategy_MinMax(const double &values[], const int count, double &lo, double &hi)
  {
   lo = DBL_MAX;
   hi = -DBL_MAX;
   for(int i = 0; i < count; ++i)
     {
      lo = MathMin(lo, values[i]);
      hi = MathMax(hi, values[i]);
     }
   return (lo > 0.0 && hi > lo && MathIsValidNumber(lo) && MathIsValidNumber(hi));
  }

bool Strategy_ComputePairStats(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const int bars = MathMax(20, strategy_formation_bars);
   double closes_a[];
   double closes_b[];
   if(!Strategy_CopyCloses(g_pair_a[pair_index], bars, closes_a))
      return false;
   if(!Strategy_CopyCloses(g_pair_b[pair_index], bars, closes_b))
      return false;

   double min_a = 0.0, max_a = 0.0, min_b = 0.0, max_b = 0.0;
   if(!Strategy_MinMax(closes_a, bars, min_a, max_a))
      return false;
   if(!Strategy_MinMax(closes_b, bars, min_b, max_b))
      return false;

   const double range_a = max_a - min_a;
   const double range_b = max_b - min_b;
   if(range_a <= 0.0 || range_b <= 0.0)
      return false;

   double spreads[];
   ArrayResize(spreads, bars);
   double distance = 0.0;
   double sum_spread = 0.0;

   for(int i = 0; i < bars; ++i)
     {
      const double norm_a = (closes_a[i] - min_a) / range_a;
      const double norm_b = (closes_b[i] - min_b) / range_b;
      const double spread = norm_a - norm_b;
      if(!MathIsValidNumber(spread))
         return false;
      spreads[i] = spread;
      distance += spread * spread;
      sum_spread += spread;
     }

   const double mean = sum_spread / (double)bars;
   double var_sum = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double d = spreads[i] - mean;
      var_sum += d * d;
     }

   const double stdev = MathSqrt(var_sum / (double)MathMax(1, bars - 1));
   if(stdev <= 0.0 || !MathIsValidNumber(stdev))
      return false;

   g_pair_distance[pair_index] = distance;
   g_pair_spread_now[pair_index] = spreads[0];
   g_pair_spread_prev[pair_index] = spreads[1];
   g_pair_spread_std[pair_index] = stdev;
   g_pair_range_a[pair_index] = range_a;
   g_pair_range_b[pair_index] = range_b;
   return true;
  }

void Strategy_SelectTopPairs()
  {
   const int top_limit = MathMin(STRATEGY_TOP_PAIR_LIMIT, STRATEGY_PAIR_COUNT);
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      g_pair_selected[i] = false;
      if(!g_pair_valid[i])
         continue;

      int rank = 1;
      for(int j = 0; j < STRATEGY_PAIR_COUNT; ++j)
        {
         if(i == j || !g_pair_valid[j])
            continue;
         if(g_pair_distance[j] < g_pair_distance[i] ||
            (g_pair_distance[j] == g_pair_distance[i] && j < i))
            rank++;
        }
      g_pair_selected[i] = (rank <= top_limit);
     }
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_active_pair = Strategy_PairIndexForSymbol(_Symbol);

   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      g_pair_valid[i] = Strategy_ComputePairStats(i);
      g_pair_selected[i] = false;
     }

   Strategy_SelectTopPairs();

   if(g_active_pair < 0)
      return false;
   if(!g_pair_valid[g_active_pair] || !g_pair_selected[g_active_pair])
      return false;

   g_state_ready = true;
   return true;
  }

bool Strategy_IsRegisteredPairPosition(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   if(!Strategy_IsPairLeg(pair_index, symbol))
      return false;

   const int slot = Strategy_SlotForSymbol(pair_index, symbol);
   const int expected_magic = QM_MagicChecked(qm_ea_id, slot, symbol);
   return (expected_magic > 0 && (int)PositionGetInteger(POSITION_MAGIC) == expected_magic);
  }

int Strategy_OpenPairLegCount(const int pair_index)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsRegisteredPairPosition(pair_index))
         count++;
     }
   return count;
  }

datetime Strategy_EarliestPairOpenTime(const int pair_index)
  {
   datetime earliest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsRegisteredPairPosition(pair_index))
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

void Strategy_ClosePair(const int pair_index, const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsRegisteredPairPosition(pair_index))
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_PrepareLegRequest(const int pair_index,
                                const string symbol,
                                const bool buy_leg,
                                const double price_range,
                                QM_BasketOrderRequest &breq)
  {
   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0)
      return false;

   const double stdev = g_pair_spread_std[pair_index];
   const double stop_move_norm = MathMax(stdev, MathAbs(strategy_stop_z - strategy_entry_z) * stdev);
   const double stop_dist = price_range * stop_move_norm;
   if(stop_dist <= point || !MathIsValidNumber(stop_dist))
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double sl = buy_leg ? NormalizeDouble(entry - stop_dist, digits)
                             : NormalizeDouble(entry + stop_dist, digits);
   const double sl_points = MathAbs(entry - sl) / point;
   if(sl_points <= 0.0)
      return false;

   const double lots = QM_LotsForRisk(symbol, sl_points) * 0.5;
   if(lots <= 0.0)
      return false;

   breq.symbol = symbol;
   breq.type = buy_leg ? QM_BUY : QM_SELL;
   breq.price = 0.0;
   breq.sl = sl;
   breq.tp = 0.0;
   breq.lots = lots;
   breq.reason = buy_leg ? "QM5_11240_HT_DIST_PAIR_BUY_LEG"
                         : "QM5_11240_HT_DIST_PAIR_SELL_LEG";
   breq.symbol_slot = Strategy_SlotForSymbol(pair_index, symbol);
   breq.expiration_seconds = 0;
   return true;
  }

bool Strategy_OpenPair(const int pair_index, const int spread_direction)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || spread_direction == 0)
      return false;
   if(Strategy_OpenPairLegCount(pair_index) > 0)
      return false;

   const bool buy_a = (spread_direction > 0);
   const bool buy_b = !buy_a;

   QM_BasketOrderRequest req_a;
   QM_BasketOrderRequest req_b;
   if(!Strategy_PrepareLegRequest(pair_index, g_pair_a[pair_index], buy_a, g_pair_range_a[pair_index], req_a))
      return false;
   if(!Strategy_PrepareLegRequest(pair_index, g_pair_b[pair_index], buy_b, g_pair_range_b[pair_index], req_b))
      return false;

   ulong ticket_a = 0;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, req_a, ticket_a))
      return false;

   ulong ticket_b = 0;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, req_b, ticket_b))
     {
      Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
      return false;
     }

   g_pair_entry_time[pair_index] = TimeCurrent();
   return true;
  }

bool Strategy_CheckPairNews(const int pair_index, const datetime broker_time)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   for(int leg = 0; leg < 2; ++leg)
     {
      const string symbol = (leg == 0) ? g_pair_a[pair_index] : g_pair_b[pair_index];
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(symbol, broker_time, qm_news_temporal, qm_news_compliance))
            return false;
        }
      else if(!QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return true;

   const int expected_slot = Strategy_SlotForSymbol(pair_index, _Symbol);
   if(qm_magic_slot_offset != expected_slot)
      return true;

   return !g_state_ready;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   if(!g_state_ready || g_active_pair < 0)
      return false;
   if(Strategy_OpenPairLegCount(g_active_pair) > 0)
      return false;

   const double stdev = g_pair_spread_std[g_active_pair];
   const double threshold = strategy_entry_z * stdev;
   if(threshold <= 0.0)
      return false;

   int direction = 0;
   if(g_pair_spread_now[g_active_pair] >= threshold)
      direction = -1; // short spread: sell A, buy B.
   else if(g_pair_spread_now[g_active_pair] <= -threshold)
      direction = 1;  // long spread: buy A, sell B.
   else
      return false;

   Strategy_OpenPair(g_active_pair, direction);
   return false;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return;

   // If synchronized entry ever leaves a single leg, flatten the orphan leg.
   if(Strategy_OpenPairLegCount(pair_index) == 1)
      Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready || g_active_pair < 0)
      return false;
   if(Strategy_OpenPairLegCount(g_active_pair) <= 0)
      return false;

   const double stdev = g_pair_spread_std[g_active_pair];
   if(stdev <= 0.0)
      return false;

   if(MathAbs(g_pair_spread_now[g_active_pair]) >= strategy_stop_z * stdev)
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   if((g_pair_spread_prev[g_active_pair] < 0.0 && g_pair_spread_now[g_active_pair] >= 0.0) ||
      (g_pair_spread_prev[g_active_pair] > 0.0 && g_pair_spread_now[g_active_pair] <= 0.0))
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   datetime opened = g_pair_entry_time[g_active_pair];
   if(opened <= 0)
      opened = Strategy_EarliestPairOpenTime(g_active_pair);
   if(strategy_max_hold_bars > 0 && opened > 0 &&
      (TimeCurrent() - opened) >= strategy_max_hold_bars * PeriodSeconds(PERIOD_D1))
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_TIME_STOP);
      return false;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return true;

   if(QM_FrameworkFridayCloseNow(broker_time))
      Strategy_ClosePair(pair_index, QM_EXIT_FRIDAY_CLOSE);

   return !Strategy_CheckPairNews(pair_index, broker_time);
  }

int OnInit()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);

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
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_formation_bars + 5, 300));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11240\",\"strategy\":\"ht-dist-pairs\"}");
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
      Strategy_RefreshState();
     }

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if(!is_new_bar)
      return;

   QM_EntryRequest req;
   Strategy_EntrySignal(req);
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
