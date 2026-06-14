#property strict
#property version   "5.0"
#property description "QM5_1084 Chan XLE Basket Z-Score Arbitrage"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1084;
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
input int    strategy_lookback_d1       = 100;
input double strategy_entry_z           = 2.0;
input double strategy_exit_z            = 0.0;
input double strategy_stop_z            = 4.0;
input int    strategy_half_life_bars    = 20;
input int    strategy_atr_period_d1     = 20;
input double strategy_atr_sl_mult       = 4.0;
input int    strategy_max_spread_points = 250;
input double strategy_ndx_weight        = 0.3333333333;
input double strategy_ws30_weight       = 0.3333333333;
input double strategy_gdaxi_weight      = 0.3333333333;

#define STRATEGY_SYMBOL_COUNT 4

string g_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX"
  };

int g_slots[STRATEGY_SYMBOL_COUNT] = {0, 1, 2, 3};

double g_z_now = 0.0;
double g_z_prev = 0.0;
bool   g_state_ready = false;

int Strategy_SymbolIndex(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(g_symbols[i] == symbol)
         return i;
     }
   return -1;
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   const int index = Strategy_SymbolIndex(symbol);
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

double Strategy_HedgeWeight(const int index)
  {
   if(index == 1)
      return strategy_ndx_weight;
   if(index == 2)
      return strategy_ws30_weight;
   if(index == 3)
      return strategy_gdaxi_weight;
   return 1.0;
  }

double Strategy_LegWeight(const int index)
  {
   if(index == 0)
      return 1.0;
   return -Strategy_HedgeWeight(index);
  }

bool Strategy_SpreadsNormal()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      const long spread = SymbolInfoInteger(g_symbols[i], SYMBOL_SPREAD);
      if(spread <= 0 || spread > strategy_max_spread_points)
         return false;
     }
   return true;
  }

bool Strategy_CopyCloses(const int bars, double &c0[], double &c1[], double &c2[], double &c3[])
  {
   if(bars < 30)
      return false;

   ArraySetAsSeries(c0, true);
   ArraySetAsSeries(c1, true);
   ArraySetAsSeries(c2, true);
   ArraySetAsSeries(c3, true);

   // perf-allowed: fixed D1 basket window, called only after QM_IsNewBar(_Symbol, PERIOD_D1).
   if(CopyClose(g_symbols[0], PERIOD_D1, 1, bars, c0) != bars)
      return false;
   if(CopyClose(g_symbols[1], PERIOD_D1, 1, bars, c1) != bars)
      return false;
   if(CopyClose(g_symbols[2], PERIOD_D1, 1, bars, c2) != bars)
      return false;
   if(CopyClose(g_symbols[3], PERIOD_D1, 1, bars, c3) != bars)
      return false;

   for(int i = 0; i < bars; ++i)
     {
      if(c0[i] <= 0.0 || c1[i] <= 0.0 || c2[i] <= 0.0 || c3[i] <= 0.0)
         return false;
     }
   return true;
  }

bool Strategy_BuildSpread(const double &c0[], const double &c1[], const double &c2[], const double &c3[],
                          const int bars, double &spread[])
  {
   ArrayResize(spread, bars);
   ArraySetAsSeries(spread, true);

   for(int i = 0; i < bars; ++i)
     {
      spread[i] = c0[i]
                  - strategy_ndx_weight * c1[i]
                  - strategy_ws30_weight * c2[i]
                  - strategy_gdaxi_weight * c3[i];
      if(!MathIsValidNumber(spread[i]))
         return false;
     }
   return true;
  }

bool Strategy_CalculateZ(const double &spread[], const int lookback, double &z_now, double &z_prev)
  {
   z_now = 0.0;
   z_prev = 0.0;
   if(lookback < 20)
      return false;

   double mean = 0.0;
   for(int i = 1; i <= lookback; ++i)
      mean += spread[i];
   mean /= (double)lookback;

   double var = 0.0;
   for(int i = 1; i <= lookback; ++i)
     {
      const double d = spread[i] - mean;
      var += d * d;
     }

   const double sd = MathSqrt(var / MathMax(1, lookback - 1));
   if(sd <= 0.0 || !MathIsValidNumber(sd))
      return false;

   z_now = (spread[0] - mean) / sd;
   z_prev = (spread[1] - mean) / sd;
   return (MathIsValidNumber(z_now) && MathIsValidNumber(z_prev));
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_z_now = 0.0;
   g_z_prev = 0.0;

   const int lookback = MathMax(20, strategy_lookback_d1);
   const int bars = lookback + 2;

   double c0[];
   double c1[];
   double c2[];
   double c3[];
   if(!Strategy_CopyCloses(bars, c0, c1, c2, c3))
      return false;

   double spread[];
   if(!Strategy_BuildSpread(c0, c1, c2, c3, bars, spread))
      return false;

   if(!Strategy_CalculateZ(spread, lookback, g_z_now, g_z_prev))
      return false;

   g_state_ready = true;
   return true;
  }

bool Strategy_IsBasketPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int index = Strategy_SymbolIndex(symbol);
   if(index < 0)
      return false;

   const int magic = QM_MagicChecked(qm_ea_id, g_slots[index], symbol);
   return ((int)PositionGetInteger(POSITION_MAGIC) == magic);
  }

int Strategy_OpenBasketLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsBasketPosition())
         ++count;
     }
   return count;
  }

datetime Strategy_OldestBasketOpenTime()
  {
   datetime oldest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsBasketPosition())
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || opened < oldest)
         oldest = opened;
     }
   return oldest;
  }

int Strategy_BasketBarsHeld()
  {
   const datetime opened = Strategy_OldestBasketOpenTime();
   if(opened <= 0)
      return 0;

   const int shift = iBarShift(_Symbol, PERIOD_D1, opened, false);
   return (shift < 0) ? 0 : shift;
  }

void Strategy_CloseBasket(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsBasketPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

double Strategy_TotalAbsLegWeight()
  {
   double total = 0.0;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      total += MathAbs(Strategy_LegWeight(i));
   return total;
  }

int Strategy_SpreadDirection()
  {
   if(!g_state_ready)
      return 0;
   if(g_z_now <= -MathAbs(strategy_entry_z))
      return 1;
   if(g_z_now >= MathAbs(strategy_entry_z))
      return -1;
   return 0;
  }

bool Strategy_OpenLeg(const int index, const int spread_direction, const double weight_sum, const string reason)
  {
   if(index < 0 || index >= STRATEGY_SYMBOL_COUNT || spread_direction == 0 || weight_sum <= 0.0)
      return false;

   const string symbol = g_symbols[index];
   const double leg_weight = Strategy_LegWeight(index);
   const bool buy_leg = (spread_direction * leg_weight) > 0.0;
   const QM_OrderType side = buy_leg ? QM_BUY : QM_SELL;
   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const double stop_distance = atr * strategy_atr_sl_mult;
   QM_BasketOrderRequest breq;
   breq.symbol = symbol;
   breq.type = side;
   breq.price = 0.0;
   breq.sl = buy_leg ? (entry - stop_distance) : (entry + stop_distance);
   breq.tp = 0.0;
   breq.lots = QM_LotsForRisk(symbol, stop_distance / point) * MathAbs(leg_weight) / weight_sum;
   breq.reason = reason;
   breq.symbol_slot = g_slots[index];
   breq.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, breq, ticket);
  }

bool Strategy_OpenBasket(const int spread_direction)
  {
   if(spread_direction == 0 || Strategy_OpenBasketLegCount() > 0)
      return false;

   const double weight_sum = Strategy_TotalAbsLegWeight();
   if(weight_sum <= 0.0)
      return false;

   const string reason = (spread_direction > 0) ? "QM5_1084_LONG_SPREAD_Z_LE_NEG2"
                                                : "QM5_1084_SHORT_SPREAD_Z_GE_POS2";

   bool opened_any = false;
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(Strategy_OpenLeg(i, spread_direction, weight_sum, reason))
         opened_any = true;
     }
   return opened_any;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int host_index = Strategy_SymbolIndex(_Symbol);
   if(host_index < 0)
      return true;

   if(qm_magic_slot_offset != g_slots[host_index])
      return true;

   if(!Strategy_SpreadsNormal())
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1084_CHAN_BASKET_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int spread_direction = Strategy_SpreadDirection();
   if(spread_direction == 0)
      return false;

   Strategy_OpenBasket(spread_direction);
   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed basket legs with no averaging-in, no trailing, no BE, and no partial close.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!g_state_ready || Strategy_OpenBasketLegCount() <= 0)
      return false;

   if(MathAbs(g_z_now) >= MathAbs(strategy_stop_z))
     {
      Strategy_CloseBasket(QM_EXIT_STRATEGY);
      return false;
     }

   if(strategy_exit_z <= 0.0)
     {
      if((g_z_prev < 0.0 && g_z_now >= 0.0) || (g_z_prev > 0.0 && g_z_now <= 0.0))
        {
         Strategy_CloseBasket(QM_EXIT_STRATEGY);
         return false;
        }
     }
   else if(MathAbs(g_z_now) <= MathAbs(strategy_exit_z))
     {
      Strategy_CloseBasket(QM_EXIT_STRATEGY);
      return false;
     }

   const int max_hold = MathMax(1, strategy_half_life_bars * 3);
   if(Strategy_BasketBarsHeld() >= max_hold)
      Strategy_CloseBasket(QM_EXIT_TIME_STOP);

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(g_symbols[i], broker_time, qm_news_temporal, qm_news_compliance))
            return true;
        }
      else if(!QM_NewsAllowsTrade(g_symbols[i], broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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
   const int warmup_bars = (int)MathMax(300, strategy_lookback_d1 + 10);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, warmup_bars);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1084\",\"strategy\":\"chan-xle-basket-z2\"}");
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
     {
      Strategy_CloseBasket(QM_EXIT_FRIDAY_CLOSE);
      return;
     }

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();
   Strategy_RefreshState();
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
