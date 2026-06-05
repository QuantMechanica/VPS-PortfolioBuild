#property strict
#property version   "5.0"
#property description "QM5_10034 Robot Wealth Rolling Z-Score Pairs (v2 Optimized)"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10034;
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
input int    strategy_z_lookback_d1     = 100;
input double strategy_beta              = 0.4;
input double strategy_entry_z           = 1.0;
input double strategy_exit_z            = 0.0;
input double strategy_stop_z            = 3.0;
input int    strategy_atr_period_d1     = 20;
input double strategy_atr_sl_mult       = 3.0;
input int    strategy_time_stop_bars    = 30;
input int    strategy_half_life_lookback = 250;
input double strategy_max_half_life_days = 60.0;
input int    strategy_max_spread_points = 0;

#define STRATEGY_PAIR_COUNT 2

string g_pair_y[STRATEGY_PAIR_COUNT]      = {"SP500.DWX", "XAUUSD.DWX"};
string g_pair_x[STRATEGY_PAIR_COUNT]      = {"NDX.DWX",   "XAGUSD.DWX"};
int    g_pair_y_slot[STRATEGY_PAIR_COUNT] = {0, 2};
int    g_pair_x_slot[STRATEGY_PAIR_COUNT] = {1, 3};
double g_pair_x_weight[STRATEGY_PAIR_COUNT] = {-0.4, -0.4};
double g_pair_y_weight[STRATEGY_PAIR_COUNT] = {1.0, 1.0};

double   g_z_now = 0.0;
double   g_z_prev = 0.0;
double   g_spread_stdev = 0.0;
int      g_active_pair = -1;
datetime g_pair_entry_time = 0;
bool     g_state_ready = false;
bool     g_news_allows = true;

bool Strategy_HasDwxSuffix(const string symbol)
  {
   return (StringFind(symbol, ".DWX") == StringLen(symbol) - 4);
  }

int Strategy_PairIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      if(symbol == g_pair_y[i] || symbol == g_pair_x[i])
         return i;
     }
   return -1;
  }

bool Strategy_IsPairLeg(const int pair_index, const string symbol)
  {
   return (pair_index >= 0 && pair_index < STRATEGY_PAIR_COUNT &&
           (symbol == g_pair_y[pair_index] || symbol == g_pair_x[pair_index]));
  }

int Strategy_SlotForSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return qm_magic_slot_offset;
   if(symbol == g_pair_y[pair_index])
      return g_pair_y_slot[pair_index];
   if(symbol == g_pair_x[pair_index])
      return g_pair_x_slot[pair_index];
   return qm_magic_slot_offset;
  }

double Strategy_WeightForSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return 0.0;
   if(symbol == g_pair_y[pair_index])
      return g_pair_y_weight[pair_index];
   if(symbol == g_pair_x[pair_index])
      return g_pair_x_weight[pair_index];
   return 0.0;
  }

bool Strategy_CopyPairCloses(const int pair_index, const int count, double &y[], double &x[])
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || count < 20)
      return false;

   ArraySetAsSeries(y, true);
   ArraySetAsSeries(x, true);

   if(CopyClose(g_pair_y[pair_index], PERIOD_D1, 1, count, y) != count)
      return false;
   if(CopyClose(g_pair_x[pair_index], PERIOD_D1, 1, count, x) != count)
      return false;
   return true;
  }

double Strategy_SpreadAt(const int index, const double &y[], const double &x[])
  {
   if(y[index] <= 0.0 || x[index] <= 0.0)
      return 0.0;
   return y[index] - strategy_beta * x[index];
  }

bool Strategy_ComputeZScores(const int pair_index, double &z_now, double &z_prev, double &stdev)
  {
   z_now = 0.0;
   z_prev = 0.0;
   stdev = 0.0;

   const int lookback = MathMax(20, strategy_z_lookback_d1);
   double y[];
   double x[];
   if(!Strategy_CopyPairCloses(pair_index, lookback + 2, y, x))
      return false;

   double sum = 0.0;
   for(int i = 1; i <= lookback; ++i)
     {
      const double spread = Strategy_SpreadAt(i, y, x);
      if(spread == 0.0 || !MathIsValidNumber(spread))
         return false;
      sum += spread;
     }

   const double mean = sum / (double)lookback;
   double var_sum = 0.0;
   for(int i = 1; i <= lookback; ++i)
     {
      const double d = Strategy_SpreadAt(i, y, x) - mean;
      var_sum += d * d;
     }

   stdev = MathSqrt(var_sum / (double)MathMax(1, lookback - 1));
   if(stdev <= 0.0 || !MathIsValidNumber(stdev))
      return false;

   const double spread_now = Strategy_SpreadAt(0, y, x);
   const double spread_prev = Strategy_SpreadAt(1, y, x);
   z_now = (spread_now - mean) / stdev;
   z_prev = (spread_prev - mean) / stdev;
   return (MathIsValidNumber(z_now) && MathIsValidNumber(z_prev));
  }

bool Strategy_HalfLifeAllows(const int pair_index)
  {
   if(strategy_half_life_lookback < 30 || strategy_max_half_life_days <= 0.0)
      return true;

   double y[];
   double x[];
   if(!Strategy_CopyPairCloses(pair_index, strategy_half_life_lookback + 1, y, x))
      return false;

   double spreads[];
   ArrayResize(spreads, strategy_half_life_lookback);
   double mean = 0.0;
   for(int i = 0; i < strategy_half_life_lookback; ++i)
     {
      spreads[i] = Strategy_SpreadAt(i, y, x);
      if(spreads[i] == 0.0 || !MathIsValidNumber(spreads[i]))
         return false;
      mean += spreads[i];
     }
   mean /= (double)strategy_half_life_lookback;

   double num = 0.0;
   double den = 0.0;
   for(int i = 0; i < strategy_half_life_lookback - 1; ++i)
     {
      const double curr = spreads[i] - mean;
      const double lag = spreads[i + 1] - mean;
      num += curr * lag;
      den += lag * lag;
     }

   if(den <= DBL_EPSILON)
      return false;

   const double phi = num / den;
   if(!MathIsValidNumber(phi) || phi <= 0.0 || phi >= 1.0)
      return true;

   const double half_life = -MathLog(2.0) / MathLog(phi);
   return (MathIsValidNumber(half_life) && half_life <= strategy_max_half_life_days);
  }

bool Strategy_DataAllows(const int pair_index)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return false;
   if(!Strategy_HasDwxSuffix(g_pair_y[pair_index]) || !Strategy_HasDwxSuffix(g_pair_x[pair_index]))
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long y_spread = SymbolInfoInteger(g_pair_y[pair_index], SYMBOL_SPREAD);
      const long x_spread = SymbolInfoInteger(g_pair_x[pair_index], SYMBOL_SPREAD);
      if(y_spread <= 0 || x_spread <= 0 ||
         y_spread > strategy_max_spread_points || x_spread > strategy_max_spread_points)
         return false;
     }

   return true;
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_active_pair = Strategy_PairIndexForSymbol(_Symbol);
   if(g_active_pair < 0 || !Strategy_DataAllows(g_active_pair))
      return false;
   if(!Strategy_ComputeZScores(g_active_pair, g_z_now, g_z_prev, g_spread_stdev))
      return false;
   if(g_spread_stdev <= SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE))
      return false;
   if(!Strategy_HalfLifeAllows(g_active_pair))
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
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
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
         ++count;
     }
   return count;
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

bool Strategy_OpenPair(const int pair_index, const int spread_direction)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || spread_direction == 0)
      return false;

   string symbols[2] = {g_pair_y[pair_index], g_pair_x[pair_index]};
   double weights[2] = {g_pair_y_weight[pair_index], g_pair_x_weight[pair_index]};

   const double sum_abs = MathAbs(weights[0]) + MathAbs(weights[1]);
   if(sum_abs <= 0.0)
      return false;

   bool any_opened = false;
   for(int leg = 0; leg < 2; ++leg)
     {
      const string symbol = symbols[leg];
      const double weight = weights[leg];
      const bool buy_leg = (spread_direction * weight) > 0.0;
      const QM_OrderType type = buy_leg ? QM_BUY : QM_SELL;
      const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
      if(entry <= 0.0)
         continue;

      const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
      if(atr <= 0.0)
         continue;

      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      const double stop_dist = strategy_atr_sl_mult * atr;
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const double sl_points = (point > 0.0) ? stop_dist / point : 0.0;
      if(sl_points <= 0.0)
         continue;

      QM_BasketOrderRequest breq;
      breq.symbol = symbol;
      breq.type = type;
      breq.price = 0.0;
      breq.sl = buy_leg ? NormalizeDouble(entry - stop_dist, digits)
                         : NormalizeDouble(entry + stop_dist, digits);
      breq.tp = 0.0;
      breq.lots = QM_LotsForRisk(symbol, sl_points) * MathAbs(weight) / sum_abs;
      breq.reason = (spread_direction > 0) ? "QM5_10034_LONG_SPREAD_Z_CROSS_NEG"
                                           : "QM5_10034_SHORT_SPREAD_Z_CROSS_POS";
      breq.symbol_slot = Strategy_SlotForSymbol(pair_index, symbol);
      breq.expiration_seconds = 0;

      ulong ticket = 0;
      if(QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, breq, ticket))
         any_opened = true;
     }

   if(any_opened)
      g_pair_entry_time = TimeCurrent();
   return any_opened;
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

   // v2 optimization: data availability checked per-bar
   return !g_state_ready;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10034_RW_PAIRS_Z_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready || Strategy_OpenPairLegCount(g_active_pair) > 0)
      return false;

   int spread_direction = 0;
   if(g_z_prev >= -strategy_entry_z && g_z_now < -strategy_entry_z)
      spread_direction = 1;
   else if(g_z_prev <= strategy_entry_z && g_z_now > strategy_entry_z)
      spread_direction = -1;
   else
      return false;

   Strategy_OpenPair(g_active_pair, spread_direction);
   return false;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card baseline specifies platform SL, zero-line exit, z-stop, and time stop;
   // no trailing, break-even, partial cover, stacking, or rebalance.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready || Strategy_OpenPairLegCount(g_active_pair) <= 0)
      return false;

   if(MathAbs(g_z_now) >= strategy_stop_z)
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   if(strategy_exit_z <= 0.0)
     {
      if((g_z_prev < 0.0 && g_z_now >= 0.0) || (g_z_prev > 0.0 && g_z_now <= 0.0))
        {
         Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
         return false;
        }
     }
   else if(MathAbs(g_z_now) <= strategy_exit_z)
     {
      Strategy_ClosePair(g_active_pair, QM_EXIT_STRATEGY);
      return false;
     }

   if(strategy_time_stop_bars > 0 && g_pair_entry_time > 0)
     {
      const int held_seconds = (int)(TimeCurrent() - g_pair_entry_time);
      if(held_seconds >= strategy_time_stop_bars * 86400)
        {
         Strategy_ClosePair(g_active_pair, QM_EXIT_TIME_STOP);
         return false;
        }
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // v2 optimization: news state is cached per-bar.
   return !g_news_allows;
  }

bool Strategy_CheckAllNews(const datetime broker_time)
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return true;

   for(int leg = 0; leg < 2; ++leg)
     {
      const string symbol = (leg == 0) ? g_pair_y[pair_index] : g_pair_x[pair_index];
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

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      SymbolSelect(g_pair_y[i], true);
      SymbolSelect(g_pair_x[i], true);
     }
   // Note: g_pair_x_weight is set in each Strategy_OpenPair or similar if needed, 
   // but original EA had it in OnInit too.
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
      g_pair_x_weight[i] = -MathAbs(strategy_beta);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10034\",\"strategy\":\"rw-pairs-z\"}");
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
   
   // v2 optimization: only check new bar logic once.
   const bool is_new_bar = QM_IsNewBar();

   if(is_new_bar)
     {
      // Refresh news once per bar
      g_news_allows = Strategy_CheckAllNews(broker_now);
      
      QM_EquityStreamOnNewBar();
      Strategy_RefreshState();
     }

   if(!g_news_allows)
      return;

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

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
