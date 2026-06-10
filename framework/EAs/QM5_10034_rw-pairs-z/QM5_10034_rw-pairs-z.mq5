#property strict
#property version   "5.0"
#property description "QM5_10034 Robot Wealth Rolling Z-Score Pairs"

#include <QM/QM_Common.mqh>

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
input int    strategy_z_lookback_d1      = 100;
input double strategy_beta               = 0.40;
input double strategy_entry_z            = 1.00;
input double strategy_exit_z             = 0.00;
input double strategy_stop_z             = 3.00;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.00;
input int    strategy_time_stop_bars     = 30;
input int    strategy_half_life_lookback = 250;
input double strategy_max_half_life_days = 60.0;
input int    strategy_max_spread_points  = 0;

#define STRATEGY_PAIR_COUNT 2
#define STRATEGY_SYMBOL_COUNT 4

string g_pair_y[STRATEGY_PAIR_COUNT] = {"SP500.DWX", "XAUUSD.DWX"};
string g_pair_x[STRATEGY_PAIR_COUNT] = {"NDX.DWX",   "XAGUSD.DWX"};
int    g_pair_y_slot[STRATEGY_PAIR_COUNT] = {0, 2};
int    g_pair_x_slot[STRATEGY_PAIR_COUNT] = {1, 3};

bool     g_basket_scope_ready = false;
int      g_active_pair = -1;
bool     g_state_ready = false;
double   g_z_now = 0.0;
double   g_z_prev = 0.0;
double   g_spread_stdev = 0.0;
datetime g_pair_entry_time = 0;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10034_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_HasDwxSuffix(const string symbol)
  {
   const int n = StringLen(symbol);
   return (n > 4 && StringSubstr(symbol, n - 4) == ".DWX");
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

double Strategy_LegWeight(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return 0.0;
   if(symbol == g_pair_y[pair_index])
      return 1.0;
   if(symbol == g_pair_x[pair_index])
      return -MathAbs(strategy_beta);
   return 0.0;
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   string allowed[STRATEGY_SYMBOL_COUNT] = {"SP500.DWX", "NDX.DWX", "XAUUSD.DWX", "XAGUSD.DWX"};
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(allowed[i], true);

   QM_SymbolGuardInit(allowed);
   const int warmup = MathMax(strategy_half_life_lookback + 10, strategy_z_lookback_d1 + 10);
   QM_BasketWarmupHistory(allowed, PERIOD_D1, warmup);
   g_basket_scope_ready = true;
   return true;
  }

bool Strategy_CopyPairCloses(const int pair_index, const int count, double &y[], double &x[])
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || count < 20)
      return false;
   if(!Strategy_EnsureBasketScope())
      return false;
   if(!QM_SymbolAssertOrLog(g_pair_y[pair_index]) || !QM_SymbolAssertOrLog(g_pair_x[pair_index]))
      return false;

   ArraySetAsSeries(y, true);
   ArraySetAsSeries(x, true);
   if(CopyClose(g_pair_y[pair_index], PERIOD_D1, 1, count, y) != count) // perf-allowed: bounded D1 pair read, called only from QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_pair_x[pair_index], PERIOD_D1, 1, count, x) != count) // perf-allowed: bounded D1 pair read, called only from QM_IsNewBar-gated EntrySignal.
      return false;

   for(int i = 0; i < count; ++i)
     {
      if(y[i] <= 0.0 || x[i] <= 0.0)
         return false;
      if(!MathIsValidNumber(y[i]) || !MathIsValidNumber(x[i]))
         return false;
     }
   return true;
  }

double Strategy_SpreadAt(const int index, const double &y[], const double &x[])
  {
   return y[index] - MathAbs(strategy_beta) * x[index];
  }

bool Strategy_ZAtOffset(const int offset,
                        const int lookback,
                        const double &y[],
                        const double &x[],
                        double &z,
                        double &stdev)
  {
   z = 0.0;
   stdev = 0.0;
   if(offset < 0 || lookback < 20)
      return false;

   double sum = 0.0;
   for(int i = offset; i < offset + lookback; ++i)
     {
      const double spread = Strategy_SpreadAt(i, y, x);
      if(!MathIsValidNumber(spread))
         return false;
      sum += spread;
     }

   const double mean = sum / (double)lookback;
   double var_sum = 0.0;
   for(int i = offset; i < offset + lookback; ++i)
     {
      const double d = Strategy_SpreadAt(i, y, x) - mean;
      var_sum += d * d;
     }

   stdev = MathSqrt(var_sum / (double)MathMax(1, lookback - 1));
   if(stdev <= 0.0 || !MathIsValidNumber(stdev))
      return false;

   z = (Strategy_SpreadAt(offset, y, x) - mean) / stdev;
   return MathIsValidNumber(z);
  }

bool Strategy_ComputeZScores(const int pair_index, double &z_now, double &z_prev, double &stdev_now)
  {
   z_now = 0.0;
   z_prev = 0.0;
   stdev_now = 0.0;

   const int lookback = MathMax(20, strategy_z_lookback_d1);
   double y[];
   double x[];
   if(!Strategy_CopyPairCloses(pair_index, lookback + 1, y, x))
      return false;

   double stdev_prev = 0.0;
   if(!Strategy_ZAtOffset(0, lookback, y, x, z_now, stdev_now))
      return false;
   if(!Strategy_ZAtOffset(1, lookback, y, x, z_prev, stdev_prev))
      return false;

   const double y_tick = SymbolInfoDouble(g_pair_y[pair_index], SYMBOL_TRADE_TICK_SIZE);
   const double x_tick = SymbolInfoDouble(g_pair_x[pair_index], SYMBOL_TRADE_TICK_SIZE);
   const double noise_floor = MathMax(y_tick, MathAbs(strategy_beta) * x_tick);
   if(noise_floor > 0.0 && stdev_now <= noise_floor)
      return false;

   return true;
  }

bool Strategy_HalfLifeAllows(const int pair_index)
  {
   if(strategy_half_life_lookback < 30 || strategy_max_half_life_days <= 0.0)
      return true;

   const int lookback = strategy_half_life_lookback;
   double y[];
   double x[];
   if(!Strategy_CopyPairCloses(pair_index, lookback + 1, y, x))
      return false;

   double spreads[];
   ArrayResize(spreads, lookback + 1);
   double mean = 0.0;
   for(int i = 0; i <= lookback; ++i)
     {
      spreads[i] = Strategy_SpreadAt(i, y, x);
      if(!MathIsValidNumber(spreads[i]))
         return false;
      if(i < lookback)
         mean += spreads[i];
     }
   mean /= (double)lookback;

   double num = 0.0;
   double den = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double current = spreads[i] - mean;
      const double lagged = spreads[i + 1] - mean;
      num += current * lagged;
      den += lagged * lagged;
     }

   if(den <= DBL_EPSILON)
      return false;

   const double phi = num / den;
   if(!MathIsValidNumber(phi))
      return false;
   if(phi <= 0.0)
      return true;
   if(phi >= 1.0)
      return false;

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
      if(y_spread <= 0 || x_spread <= 0)
         return false;
      if(y_spread > strategy_max_spread_points || x_spread > strategy_max_spread_points)
         return false;
     }

   return true;
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_active_pair = Strategy_PairIndexForSymbol(_Symbol);
   g_z_now = 0.0;
   g_z_prev = 0.0;
   g_spread_stdev = 0.0;

   if(g_active_pair < 0 || !Strategy_DataAllows(g_active_pair))
      return false;
   if(!Strategy_ComputeZScores(g_active_pair, g_z_now, g_z_prev, g_spread_stdev))
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

bool Strategy_BuildLegRequest(const int pair_index,
                              const string symbol,
                              const int spread_direction,
                              QM_EntryRequest &req)
  {
   const double leg_weight = Strategy_LegWeight(pair_index, symbol);
   if(leg_weight == 0.0 || symbol != _Symbol)
      return false;

   const bool buy_leg = (spread_direction * leg_weight) > 0.0;
   const QM_OrderType type = buy_leg ? QM_BUY : QM_SELL;
   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const double stop_dist = strategy_atr_sl_mult * atr;
   const double sl_points = stop_dist / point;
   if(sl_points <= 0.0 || !MathIsValidNumber(sl_points))
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   req.type = type;
   req.price = 0.0;
   req.sl = buy_leg ? NormalizeDouble(entry - stop_dist, digits)
                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.reason = (spread_direction > 0) ? "QM5_10034_LONG_SPREAD_Z_CROSS_NEG"
                                       : "QM5_10034_SHORT_SPREAD_Z_CROSS_POS";
   req.symbol_slot = Strategy_SlotForSymbol(pair_index, symbol);
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_OpenPair(const int pair_index, const int spread_direction)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || spread_direction == 0)
      return false;
   if(Strategy_OpenPairLegCount(pair_index) > 0)
      return false;

   QM_EntryRequest req;
   if(!Strategy_BuildLegRequest(pair_index, _Symbol, spread_direction, req))
      return false;

   ulong ticket = 0;
   if(!QM_TM_OpenPosition(req, ticket))
      return false;

   g_pair_entry_time = TimeCurrent();
   return true;
  }

bool Strategy_NewsAllowsPair(const datetime broker_time)
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

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureBasketScope();

   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return true;

   if(qm_magic_slot_offset != Strategy_SlotForSymbol(pair_index, _Symbol))
      return true;

   return !Strategy_DataAllows(pair_index);
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if(!Strategy_RefreshState())
      return false;
   if(Strategy_OpenPairLegCount(g_active_pair) > 0)
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
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return;

   const int legs = Strategy_OpenPairLegCount(pair_index);
   if(legs <= 0)
      return;
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0 || Strategy_OpenPairLegCount(pair_index) <= 0 || !g_state_ready)
      return false;

   if(MathAbs(g_z_now) >= strategy_stop_z)
     {
      Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
      return false;
     }

   if(strategy_exit_z <= 0.0)
     {
      if((g_z_prev < 0.0 && g_z_now >= 0.0) || (g_z_prev > 0.0 && g_z_now <= 0.0))
        {
         Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
         return false;
        }
     }
   else if(MathAbs(g_z_now) <= strategy_exit_z)
     {
      Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
      return false;
     }

   if(strategy_time_stop_bars > 0 && g_pair_entry_time > 0)
     {
      const int held_seconds = (int)(TimeCurrent() - g_pair_entry_time);
      if(held_seconds >= strategy_time_stop_bars * 86400)
        {
         Strategy_ClosePair(pair_index, QM_EXIT_TIME_STOP);
         return false;
        }
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index >= 0 && QM_FrameworkFridayCloseNow(broker_time))
     {
      Strategy_ClosePair(pair_index, QM_EXIT_FRIDAY_CLOSE);
      return true;
     }

   return !Strategy_NewsAllowsPair(broker_time);
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
