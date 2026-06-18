#property strict
#property version   "5.0"
#property description "QM5_12395 Country Index Distance Pairs"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12395;
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
input int    strategy_formation_bars       = 120;
input int    strategy_trading_period_bars  = 20;
input double strategy_entry_stdev          = 0.5;
input double strategy_stop_stdev           = 2.5;
input int    strategy_max_active_pairs     = 3;
input int    strategy_stale_days           = 3;
input int    strategy_max_spread_points    = 0;

#define STRATEGY_SYMBOL_COUNT 5
#define STRATEGY_PAIR_COUNT 10

string g_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"
  };

int g_symbol_slots[STRATEGY_SYMBOL_COUNT] = {0, 1, 2, 3, 4};

int g_pair_a_index[STRATEGY_PAIR_COUNT] = {0, 0, 0, 0, 1, 1, 1, 2, 2, 3};
int g_pair_b_index[STRATEGY_PAIR_COUNT] = {1, 2, 3, 4, 2, 3, 4, 3, 4, 4};

bool   g_pair_valid[STRATEGY_PAIR_COUNT];
bool   g_pair_selected[STRATEGY_PAIR_COUNT];
double g_pair_distance[STRATEGY_PAIR_COUNT];
double g_pair_mean[STRATEGY_PAIR_COUNT];
double g_pair_stdev[STRATEGY_PAIR_COUNT];
double g_pair_spread_now[STRATEGY_PAIR_COUNT];
double g_pair_spread_prev[STRATEGY_PAIR_COUNT];
double g_pair_base_a[STRATEGY_PAIR_COUNT];
double g_pair_base_b[STRATEGY_PAIR_COUNT];

int  g_cycle_age_bars = 999999;
bool g_state_ready = false;

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

string Strategy_PairSymbolA(const int pair_index)
  {
   return g_symbols[g_pair_a_index[pair_index]];
  }

string Strategy_PairSymbolB(const int pair_index)
  {
   return g_symbols[g_pair_b_index[pair_index]];
  }

bool Strategy_PairContainsSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   return (Strategy_PairSymbolA(pair_index) == symbol || Strategy_PairSymbolB(pair_index) == symbol);
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12395_PAIR_ENGINE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_DataFresh(const string symbol)
  {
   long last_bar = 0;
   if(!SeriesInfoInteger(symbol, PERIOD_D1, SERIES_LASTBAR_DATE, last_bar))
      return false;
   if(last_bar <= 0)
      return false;
   const int max_age = MathMax(1, strategy_stale_days) * 86400;
   return ((TimeCurrent() - (datetime)last_bar) <= max_age);
  }

bool Strategy_CopyCloses(const string symbol, const int count, double &closes[])
  {
   if(count < 1 || !QM_SymbolAssertOrLog(symbol))
      return false;
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_D1, 1, count, closes); // perf-allowed: D1 formation-window copy, called only after the single QM_IsNewBar() gate.
   if(copied != count)
      return false;
   for(int i = 0; i < count; ++i)
      if(closes[i] <= 0.0 || !MathIsValidNumber(closes[i]))
         return false;
   return true;
  }

bool Strategy_ComputePairFormation(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;

   const string sym_a = Strategy_PairSymbolA(pair_index);
   const string sym_b = Strategy_PairSymbolB(pair_index);
   if(!Strategy_DataFresh(sym_a) || !Strategy_DataFresh(sym_b))
      return false;

   const int bars = MathMax(20, strategy_formation_bars);
   double closes_a[];
   double closes_b[];
   if(!Strategy_CopyCloses(sym_a, bars, closes_a))
      return false;
   if(!Strategy_CopyCloses(sym_b, bars, closes_b))
      return false;

   const double base_a = closes_a[bars - 1];
   const double base_b = closes_b[bars - 1];
   if(base_a <= 0.0 || base_b <= 0.0)
      return false;

   double spreads[];
   ArrayResize(spreads, bars);
   double sum_spread = 0.0;
   double distance = 0.0;
   for(int i = 0; i < bars; ++i)
     {
      const double spread = (closes_a[i] / base_a) - (closes_b[i] / base_b);
      if(!MathIsValidNumber(spread))
         return false;
      spreads[i] = spread;
      sum_spread += spread;
      distance += spread * spread;
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
   g_pair_mean[pair_index] = mean;
   g_pair_stdev[pair_index] = stdev;
   g_pair_base_a[pair_index] = base_a;
   g_pair_base_b[pair_index] = base_b;
   g_pair_spread_now[pair_index] = spreads[0];
   g_pair_spread_prev[pair_index] = spreads[1];
   return true;
  }

bool Strategy_UpdatePairSpread(const int pair_index)
  {
   const string sym_a = Strategy_PairSymbolA(pair_index);
   const string sym_b = Strategy_PairSymbolB(pair_index);
   if(!Strategy_DataFresh(sym_a) || !Strategy_DataFresh(sym_b))
      return false;

   double close_a[];
   double close_b[];
   if(!Strategy_CopyCloses(sym_a, 1, close_a))
      return false;
   if(!Strategy_CopyCloses(sym_b, 1, close_b))
      return false;
   if(g_pair_base_a[pair_index] <= 0.0 || g_pair_base_b[pair_index] <= 0.0)
      return false;

   g_pair_spread_prev[pair_index] = g_pair_spread_now[pair_index];
   g_pair_spread_now[pair_index] = (close_a[0] / g_pair_base_a[pair_index]) -
                                   (close_b[0] / g_pair_base_b[pair_index]);
   return MathIsValidNumber(g_pair_spread_now[pair_index]);
  }

void Strategy_SelectPairs()
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
      g_pair_selected[i] = false;

   const int max_pairs = MathMin(MathMax(1, strategy_max_active_pairs), STRATEGY_PAIR_COUNT);
   bool symbol_used[STRATEGY_SYMBOL_COUNT];
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      symbol_used[i] = false;

   for(int pick = 0; pick < max_pairs; ++pick)
     {
      int best = -1;
      double best_distance = DBL_MAX;
      for(int p = 0; p < STRATEGY_PAIR_COUNT; ++p)
        {
         if(!g_pair_valid[p] || g_pair_selected[p])
            continue;
         const int ai = g_pair_a_index[p];
         const int bi = g_pair_b_index[p];
         if(symbol_used[ai] || symbol_used[bi])
            continue;
         if(g_pair_distance[p] < best_distance)
           {
            best_distance = g_pair_distance[p];
            best = p;
           }
        }
      if(best < 0)
         return;
      g_pair_selected[best] = true;
      symbol_used[g_pair_a_index[best]] = true;
      symbol_used[g_pair_b_index[best]] = true;
     }
  }

void Strategy_ClosePair(const int pair_index, const QM_ExitReason reason)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!Strategy_PairContainsSymbol(pair_index, symbol))
         continue;

      const int expected_magic = QM_FrameworkMagic();
      if(expected_magic > 0 && (int)PositionGetInteger(POSITION_MAGIC) == expected_magic)
         QM_TM_ClosePosition(ticket, reason);
     }
  }

void Strategy_CloseAllPairs(const QM_ExitReason reason)
  {
   for(int p = 0; p < STRATEGY_PAIR_COUNT; ++p)
      Strategy_ClosePair(p, reason);
  }

bool Strategy_IsRegisteredPairPosition(const int pair_index)
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   if(!Strategy_PairContainsSymbol(pair_index, symbol))
      return false;
   const int expected_magic = QM_FrameworkMagic();
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

int Strategy_OpenPairCount()
  {
   int count = 0;
   for(int p = 0; p < STRATEGY_PAIR_COUNT; ++p)
      if(Strategy_OpenPairLegCount(p) >= 2)
         count++;
   return count;
  }

int Strategy_BestSelectedPairForChart()
  {
   int best = -1;
   double best_distance = DBL_MAX;
   for(int p = 0; p < STRATEGY_PAIR_COUNT; ++p)
     {
      if(!g_pair_selected[p] || !Strategy_PairContainsSymbol(p, _Symbol))
         continue;
      if(g_pair_distance[p] < best_distance)
        {
         best_distance = g_pair_distance[p];
         best = p;
        }
     }
   return best;
  }

double Strategy_NotionalPerLot(const string symbol, const double entry)
  {
   double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contract_size <= 0.0)
      contract_size = 1.0;
   return contract_size * entry;
  }

bool Strategy_PrepareLegRequest(const int pair_index,
                                const string symbol,
                                const bool buy_leg,
                                const double base_price,
                                QM_EntryRequest &req)
  {
   if(symbol != _Symbol)
      return false;

   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0 || base_price <= 0.0)
      return false;

   const double stop_dist = MathMax(point * 10.0, base_price * strategy_stop_stdev * g_pair_stdev[pair_index]);
   const double sl = buy_leg ? QM_TM_NormalizePrice(symbol, entry - stop_dist)
                             : QM_TM_NormalizePrice(symbol, entry + stop_dist);
   const double sl_points = MathAbs(entry - sl) / point;
   if(sl <= 0.0 || sl_points <= 0.0)
      return false;

   req.type = buy_leg ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = buy_leg ? "QM5_12395_COUNTRY_PAIR_BUY_LEG" : "QM5_12395_COUNTRY_PAIR_SELL_LEG";
   req.symbol_slot = Strategy_SymbolSlot(symbol);
   req.expiration_seconds = 0;
   return (QM_LotsForRisk(symbol, sl_points) > 0.0);
  }

bool Strategy_PrepareChartPairLeg(const int pair_index, const int spread_direction, QM_EntryRequest &req)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || spread_direction == 0)
      return false;
   if(Strategy_OpenPairCount() >= MathMax(1, strategy_max_active_pairs))
      return false;
   if(Strategy_OpenPairLegCount(pair_index) > 0)
      return false;

   const string sym_a = Strategy_PairSymbolA(pair_index);
   const string sym_b = Strategy_PairSymbolB(pair_index);
   const bool buy_a = (spread_direction > 0);
   const bool buy_b = !buy_a;

   if(_Symbol == sym_a)
      return Strategy_PrepareLegRequest(pair_index, sym_a, buy_a, g_pair_base_a[pair_index], req);
   if(_Symbol == sym_b)
      return Strategy_PrepareLegRequest(pair_index, sym_b, buy_b, g_pair_base_b[pair_index], req);
   return false;
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   if(g_cycle_age_bars >= MathMax(1, strategy_trading_period_bars))
     {
      Strategy_CloseAllPairs(QM_EXIT_TIME_STOP);
      for(int p = 0; p < STRATEGY_PAIR_COUNT; ++p)
        {
         g_pair_valid[p] = Strategy_ComputePairFormation(p);
         g_pair_selected[p] = false;
        }
      Strategy_SelectPairs();
      g_cycle_age_bars = 0;
      g_state_ready = true;
      return true;
     }

   for(int p = 0; p < STRATEGY_PAIR_COUNT; ++p)
      if(g_pair_valid[p])
         g_pair_valid[p] = Strategy_UpdatePairSpread(p);
   g_cycle_age_bars++;
   g_state_ready = true;
   return true;
  }

bool Strategy_CheckPairNews(const int pair_index, const datetime broker_time)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   for(int leg = 0; leg < 2; ++leg)
     {
      const string symbol = (leg == 0) ? Strategy_PairSymbolA(pair_index) : Strategy_PairSymbolB(pair_index);
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
   if(Strategy_SymbolIndex(_Symbol) < 0)
      return true;
   if(qm_magic_slot_offset != Strategy_SymbolSlot(_Symbol))
      return true;
   if(!g_state_ready)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 &&
         ((ask - bid) / point) > strategy_max_spread_points)
         return true;
     }

   const int pair_index = Strategy_BestSelectedPairForChart();
   if(pair_index >= 0 && !Strategy_CheckPairNews(pair_index, TimeCurrent()))
      return true;

   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   const int pair_index = Strategy_BestSelectedPairForChart();
   if(pair_index < 0)
      return false;
   if(Strategy_OpenPairLegCount(pair_index) > 0)
      return false;
   if(Strategy_OpenPairCount() >= MathMax(1, strategy_max_active_pairs))
      return false;

   const double stdev = g_pair_stdev[pair_index];
   if(stdev <= 0.0)
      return false;

   const double upper = g_pair_mean[pair_index] + strategy_entry_stdev * stdev;
   const double lower = g_pair_mean[pair_index] - strategy_entry_stdev * stdev;
   if(g_pair_spread_now[pair_index] > upper)
      return Strategy_PrepareChartPairLeg(pair_index, -1, req);
   if(g_pair_spread_now[pair_index] < lower)
      return Strategy_PrepareChartPairLeg(pair_index, 1, req);

   return false;
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

   for(int p = 0; p < STRATEGY_PAIR_COUNT; ++p)
     {
      if(Strategy_OpenPairLegCount(p) <= 0)
         continue;

      const double stdev = g_pair_stdev[p];
      if(stdev <= 0.0)
         continue;

      const double inner_upper = g_pair_mean[p] + strategy_entry_stdev * stdev;
      const double inner_lower = g_pair_mean[p] - strategy_entry_stdev * stdev;
      if(g_pair_spread_now[p] <= inner_upper && g_pair_spread_now[p] >= inner_lower)
        {
         Strategy_ClosePair(p, QM_EXIT_STRATEGY);
         continue;
        }

      const double stop_upper = g_pair_mean[p] + strategy_stop_stdev * stdev;
      const double stop_lower = g_pair_mean[p] - strategy_stop_stdev * stdev;
      if(g_pair_spread_now[p] >= stop_upper || g_pair_spread_now[p] <= stop_lower)
         Strategy_ClosePair(p, QM_EXIT_STRATEGY);
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(QM_FrameworkFridayCloseNow(broker_time))
      Strategy_CloseAllPairs(QM_EXIT_FRIDAY_CLOSE);

   const int pair_index = Strategy_BestSelectedPairForChart();
   if(pair_index < 0)
      return false;
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
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_formation_bars + 10, 300));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12395\",\"strategy\":\"country-pairs\"}");
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
