#property strict
#property version   "5.0"
#property description "QM5_12512 bt Pair Spread Threshold Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12512;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    spread_lookback_bars       = 240;
input double fixed_beta                 = 1.0;
input double z_entry                    = 2.0;
input double z_exit                     = 0.25;
input double z_pair_stop                = 3.5;
input int    max_holding_bars           = 5;
input int    atr_period                 = 20;
input double atr_stop_mult              = 2.0;
input int    median_spread_bars         = 1440;
input double median_spread_multiple     = 2.0;

#define STRATEGY_PAIR_COUNT 3
#define STRATEGY_SYMBOL_COUNT 6

string g_asset1[STRATEGY_PAIR_COUNT] = {"EURUSD.DWX", "EURJPY.DWX", "AUDUSD.DWX"};
string g_asset2[STRATEGY_PAIR_COUNT] = {"GBPUSD.DWX", "GBPJPY.DWX", "NZDUSD.DWX"};
int    g_slot1[STRATEGY_PAIR_COUNT]  = {0, 2, 4};
int    g_slot2[STRATEGY_PAIR_COUNT]  = {1, 3, 5};

bool   g_basket_scope_ready = false;
int    g_active_pair = -1;
bool   g_state_ready = false;
double g_residual_now = 0.0;
double g_residual_mean = 0.0;
double g_residual_sd = 0.0;
double g_z_now = 0.0;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12512_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int Strategy_PairIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_PAIR_COUNT; ++i)
     {
      if(symbol == g_asset1[i] || symbol == g_asset2[i])
         return i;
     }
   return -1;
  }

int Strategy_SlotForSymbol(const int pair_index, const string symbol)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return qm_magic_slot_offset;
   if(symbol == g_asset1[pair_index])
      return g_slot1[pair_index];
   if(symbol == g_asset2[pair_index])
      return g_slot2[pair_index];
   return qm_magic_slot_offset;
  }

bool Strategy_IsPairLeg(const int pair_index, const string symbol)
  {
   return (pair_index >= 0 && pair_index < STRATEGY_PAIR_COUNT &&
           (symbol == g_asset1[pair_index] || symbol == g_asset2[pair_index]));
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   string allowed[STRATEGY_SYMBOL_COUNT] = {"EURUSD.DWX", "GBPUSD.DWX", "EURJPY.DWX", "GBPJPY.DWX", "AUDUSD.DWX", "NZDUSD.DWX"};
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(allowed[i], true);

   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, PERIOD_H1, MathMax(spread_lookback_bars + 10, 300));
   g_basket_scope_ready = true;
   return true;
  }

bool Strategy_CopyPairWindow(const int pair_index, const int count, double &x[], double &y[])
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || count < 30)
      return false;
   if(!Strategy_EnsureBasketScope())
      return false;
   if(!QM_SymbolAssertOrLog(g_asset1[pair_index]) || !QM_SymbolAssertOrLog(g_asset2[pair_index]))
      return false;

   datetime tx[];
   datetime ty[];
   ArraySetAsSeries(x, true);
   ArraySetAsSeries(y, true);
   ArraySetAsSeries(tx, true);
   ArraySetAsSeries(ty, true);

   // perf-allowed: called only after OnTick passes QM_IsNewBar(); bounded pair window.
   if(CopyClose(g_asset1[pair_index], (ENUM_TIMEFRAMES)_Period, 1, count, x) != count) // perf-allowed: bounded pair close read, called only from QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_asset2[pair_index], (ENUM_TIMEFRAMES)_Period, 1, count, y) != count) // perf-allowed: bounded pair close read, called only from QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyTime(g_asset1[pair_index], (ENUM_TIMEFRAMES)_Period, 1, count, tx) != count) // perf-allowed: bounded synchronization check, called only from QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyTime(g_asset2[pair_index], (ENUM_TIMEFRAMES)_Period, 1, count, ty) != count) // perf-allowed: bounded synchronization check, called only from QM_IsNewBar-gated EntrySignal.
      return false;

   for(int i = 0; i < count; ++i)
     {
      if(tx[i] != ty[i])
         return false;
      if(x[i] <= 0.0 || y[i] <= 0.0)
         return false;
      if(!MathIsValidNumber(x[i]) || !MathIsValidNumber(y[i]))
         return false;
     }
   return true;
  }

bool Strategy_RefreshState(const int pair_index)
  {
   g_active_pair = pair_index;
   g_state_ready = false;
   g_residual_now = 0.0;
   g_residual_mean = 0.0;
   g_residual_sd = 0.0;
   g_z_now = 0.0;

   const int count = MathMax(30, spread_lookback_bars);
   double x[];
   double y[];
   if(!Strategy_CopyPairWindow(pair_index, count, x, y))
      return false;

   double residuals[];
   ArrayResize(residuals, count);
   for(int i = 0; i < count; ++i)
     {
      residuals[i] = MathLog(x[i]) - fixed_beta * MathLog(y[i]);
      if(!MathIsValidNumber(residuals[i]))
         return false;
     }

   double sum = 0.0;
   for(int i = 0; i < count; ++i)
      sum += residuals[i];
   g_residual_mean = sum / (double)count;

   double var_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double d = residuals[i] - g_residual_mean;
      var_sum += d * d;
     }

   g_residual_sd = MathSqrt(var_sum / (double)MathMax(1, count - 1));
   if(g_residual_sd <= 0.0 || !MathIsValidNumber(g_residual_sd))
      return false;

   g_residual_now = residuals[0];
   g_z_now = (g_residual_now - g_residual_mean) / g_residual_sd;
   g_state_ready = MathIsValidNumber(g_z_now);
   return g_state_ready;
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

int Strategy_CurrentPairSide(const int pair_index)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsRegisteredPairPosition(pair_index))
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(symbol == g_asset1[pair_index])
         return (ptype == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

int Strategy_HeldBars(const int pair_index)
  {
   datetime first_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsRegisteredPairPosition(pair_index))
         continue;

      const datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(first_time == 0 || pos_time < first_time)
         first_time = pos_time;
     }

   if(first_time <= 0)
      return 0;

   const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds <= 0)
      return 0;
   return (int)((TimeCurrent() - first_time) / seconds);
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

bool Strategy_NewsAllowsPair(const int pair_index, const datetime broker_time)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT)
      return true;

   string symbols[2] = {g_asset1[pair_index], g_asset2[pair_index]};
   for(int i = 0; i < 2; ++i)
     {
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(symbols[i], broker_time, qm_news_temporal, qm_news_compliance))
            return false;
        }
      else if(!QM_NewsAllowsTrade(symbols[i], broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

bool Strategy_BuildLegRequest(const int pair_index,
                              const string symbol,
                              const int pair_side,
                              QM_BasketOrderRequest &req)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || pair_side == 0)
      return false;

   const bool is_asset1 = (symbol == g_asset1[pair_index]);
   const bool is_asset2 = (symbol == g_asset2[pair_index]);
   if(!is_asset1 && !is_asset2)
      return false;

   const bool buy_leg = is_asset1 ? (pair_side > 0) : (pair_side < 0);
   const QM_OrderType type = buy_leg ? QM_BUY : QM_SELL;
   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double atr = QM_ATR(symbol, PERIOD_H1, atr_period, 1);
   if(entry <= 0.0 || point <= 0.0 || atr <= 0.0)
      return false;

   const double stop_dist = atr_stop_mult * atr;
   const double sl_points = stop_dist / point;
   if(sl_points <= 0.0 || !MathIsValidNumber(sl_points))
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double lots = QM_LotsForRisk(symbol, sl_points) * 0.5;
   if(lots <= 0.0 || !MathIsValidNumber(lots))
      return false;

   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = buy_leg ? NormalizeDouble(entry - stop_dist, digits)
                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.lots = lots;
   req.reason = (pair_side > 0) ? "QM5_12512_LONG_SPREAD"
                                : "QM5_12512_SHORT_SPREAD";
   req.symbol_slot = Strategy_SlotForSymbol(pair_index, symbol);
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_OpenPair(const int pair_index, const int pair_side)
  {
   if(pair_index < 0 || pair_index >= STRATEGY_PAIR_COUNT || pair_side == 0)
      return false;
   if(Strategy_OpenPairLegCount(pair_index) > 0)
      return false;

   if(!Strategy_IsPairLeg(pair_index, _Symbol))
      return false;

   QM_BasketOrderRequest leg1;
   QM_BasketOrderRequest leg2;
   if(!Strategy_BuildLegRequest(pair_index, g_asset1[pair_index], pair_side, leg1))
      return false;
   if(!Strategy_BuildLegRequest(pair_index, g_asset2[pair_index], pair_side, leg2))
      return false;

   ulong ticket1 = 0;
   ulong ticket2 = 0;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, leg1, ticket1))
      return false;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, leg2, ticket2))
     {
      Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
      return false;
     }

   return true;
  }

bool Strategy_SpreadWithinMedian(const string symbol)
  {
   const long current = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(current <= 0)
      return true; // DWX zero-spread modeling is valid and must not fail closed.

   const int count = MathMax(24, median_spread_bars);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_H1, 1, count, rates) != count) // perf-allowed: bounded 60-day spread filter, called only after the new-bar gate.
      return false;

   double samples[];
   ArrayResize(samples, count);
   for(int i = 0; i < count; ++i)
      samples[i] = (double)rates[i].spread;
   ArraySort(samples);
   const double median = (count % 2 == 0)
                         ? 0.5 * (samples[count / 2 - 1] + samples[count / 2])
                         : samples[count / 2];
   return (median <= 0.0 || (double)current <= median_spread_multiple * median);
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureBasketScope();

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return true;

   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return true;

   if(qm_magic_slot_offset != Strategy_SlotForSymbol(pair_index, _Symbol))
      return true;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   if(now.day_of_week == 5 && (now.hour == 0 || now.hour == 23))
      return true;

   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return false;

   const int open_legs = Strategy_OpenPairLegCount(pair_index);
   if(!Strategy_RefreshState(pair_index))
     {
      if(open_legs > 0)
         Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
      return false;
     }
   if(!Strategy_SpreadWithinMedian(g_asset1[pair_index]) ||
      !Strategy_SpreadWithinMedian(g_asset2[pair_index]))
      return false;

   int signal_side = 0;
   if(g_z_now > z_entry)
      signal_side = -1; // rich spread: sell A, buy B.
   else if(g_z_now < -z_entry)
      signal_side = 1;  // cheap spread: buy A, sell B.

   if(open_legs > 0)
      return false;

   if(signal_side == 0)
      return false;

   Strategy_OpenPair(pair_index, signal_side);
   return false;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0)
      return;

   const int legs = Strategy_OpenPairLegCount(pair_index);
   if(legs == 1)
      Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   const int pair_index = Strategy_PairIndexForSymbol(_Symbol);
   if(pair_index < 0 || Strategy_OpenPairLegCount(pair_index) <= 0)
      return false;

   if(g_state_ready)
     {
      if(MathAbs(g_z_now) <= z_exit)
        {
         Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
         return false;
        }

      if(MathAbs(g_z_now) >= z_pair_stop)
        {
         Strategy_ClosePair(pair_index, QM_EXIT_STRATEGY);
         return false;
        }
     }

   if(max_holding_bars > 0 && Strategy_HeldBars(pair_index) >= max_holding_bars)
      Strategy_ClosePair(pair_index, QM_EXIT_TIME_STOP);

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

   return !Strategy_NewsAllowsPair(pair_index, broker_time);
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
