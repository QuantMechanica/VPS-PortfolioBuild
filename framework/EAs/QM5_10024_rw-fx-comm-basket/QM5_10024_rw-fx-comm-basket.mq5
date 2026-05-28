#property strict
#property version   "5.0"
#property description "QM5_10024 Robot Wealth FX Commodity Basket Stat Arb"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10024;
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
input int    strategy_z_lookback_d1     = 60;
input double strategy_entry_z           = 2.0;
input double strategy_exit_z            = 0.5;
input double strategy_stop_std_mult     = 2.5;
input int    strategy_time_stop_bars    = 20;
input int    strategy_atr_period_d1     = 14;
input double strategy_atr_sl_mult       = 2.0;
input int    strategy_max_spread_points = 50;
input double strategy_weight_audusd     = 1.0;
input double strategy_weight_nzdusd     = 1.0;
input double strategy_weight_usdcad     = -1.0;
input double strategy_weight_audnzd     = -1.0;

#define STRATEGY_LEG_COUNT 4

string g_leg_symbols[STRATEGY_LEG_COUNT] = {"AUDUSD.DWX", "NZDUSD.DWX", "USDCAD.DWX", "AUDNZD.DWX"};
int    g_leg_slots[STRATEGY_LEG_COUNT]   = {0, 1, 2, 3};
double g_leg_weights[STRATEGY_LEG_COUNT];

double g_z_now = 0.0;
double g_z_prev = 0.0;
double g_spread_stdev = 0.0;
bool   g_state_ready = false;

int Strategy_LegIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
      if(symbol == g_leg_symbols[i])
         return i;
   return -1;
  }

bool Strategy_HasDwxSuffix(const string symbol)
  {
   return (StringFind(symbol, ".DWX") == StringLen(symbol) - 4);
  }

double Strategy_AbsWeightSum()
  {
   double sum_abs = 0.0;
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
      sum_abs += MathAbs(g_leg_weights[i]);
   return sum_abs;
  }

bool Strategy_CopyLegCloses(const int count, double &c0[], double &c1[], double &c2[], double &c3[])
  {
   if(count < strategy_z_lookback_d1 + 2)
      return false;

   ArraySetAsSeries(c0, true);
   ArraySetAsSeries(c1, true);
   ArraySetAsSeries(c2, true);
   ArraySetAsSeries(c3, true);

   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
      SymbolSelect(g_leg_symbols[i], true);

   if(CopyClose(g_leg_symbols[0], PERIOD_D1, 1, count, c0) != count)
      return false;
   if(CopyClose(g_leg_symbols[1], PERIOD_D1, 1, count, c1) != count)
      return false;
   if(CopyClose(g_leg_symbols[2], PERIOD_D1, 1, count, c2) != count)
      return false;
   if(CopyClose(g_leg_symbols[3], PERIOD_D1, 1, count, c3) != count)
      return false;
   return true;
  }

double Strategy_SpreadAt(const int index, const double &c0[], const double &c1[],
                         const double &c2[], const double &c3[])
  {
   if(c0[index] <= 0.0 || c1[index] <= 0.0 || c2[index] <= 0.0 || c3[index] <= 0.0)
      return 0.0;

   return g_leg_weights[0] * MathLog(c0[index])
        + g_leg_weights[1] * MathLog(c1[index])
        + g_leg_weights[2] * MathLog(c2[index])
        + g_leg_weights[3] * MathLog(c3[index]);
  }

bool Strategy_ComputeZScores(double &z_now, double &z_prev, double &stdev)
  {
   z_now = 0.0;
   z_prev = 0.0;
   stdev = 0.0;

   const int lookback = MathMax(20, strategy_z_lookback_d1);
   double c0[];
   double c1[];
   double c2[];
   double c3[];
   if(!Strategy_CopyLegCloses(lookback + 2, c0, c1, c2, c3))
      return false;

   double sum = 0.0;
   for(int i = 1; i <= lookback; ++i)
     {
      const double spread = Strategy_SpreadAt(i, c0, c1, c2, c3);
      if(spread == 0.0 || !MathIsValidNumber(spread))
         return false;
      sum += spread;
     }

   const double mean = sum / (double)lookback;
   double var_sum = 0.0;
   for(int i = 1; i <= lookback; ++i)
     {
      const double d = Strategy_SpreadAt(i, c0, c1, c2, c3) - mean;
      var_sum += d * d;
     }

   stdev = MathSqrt(var_sum / (double)MathMax(1, lookback - 1));
   if(stdev <= 0.0 || !MathIsValidNumber(stdev))
      return false;

   const double spread_now = Strategy_SpreadAt(0, c0, c1, c2, c3);
   const double spread_prev = Strategy_SpreadAt(1, c0, c1, c2, c3);
   z_now = (spread_now - mean) / stdev;
   z_prev = (spread_prev - mean) / stdev;
   return (MathIsValidNumber(z_now) && MathIsValidNumber(z_prev));
  }

bool Strategy_DataAllows()
  {
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
     {
      const string symbol = g_leg_symbols[i];
      if(!Strategy_HasDwxSuffix(symbol))
         return false;
      if(!SymbolSelect(symbol, true))
         return false;
      if(iTime(symbol, PERIOD_D1, 1) <= 0)
         return false;
      if(strategy_max_spread_points > 0)
        {
         const long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
         if(spread <= 0 || spread > strategy_max_spread_points)
            return false;
        }
     }
   return true;
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   if(Strategy_LegIndexForSymbol(_Symbol) < 0)
      return false;
   if(!Strategy_DataAllows())
      return false;
   if(Strategy_AbsWeightSum() <= 0.0)
      return false;
   if(!Strategy_ComputeZScores(g_z_now, g_z_prev, g_spread_stdev))
      return false;
   g_state_ready = true;
   return true;
  }

bool Strategy_IsRegisteredBasketPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int leg = Strategy_LegIndexForSymbol(symbol);
   if(leg < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, g_leg_slots[leg], symbol));
  }

int Strategy_OpenBasketLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsRegisteredBasketPosition())
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
      if(!Strategy_IsRegisteredBasketPosition())
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(oldest == 0 || open_time < oldest)
         oldest = open_time;
     }
   return oldest;
  }

void Strategy_CloseBasket(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsRegisteredBasketPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_OpenBasket(const int spread_direction)
  {
   if(spread_direction == 0)
      return false;

   const double sum_abs = Strategy_AbsWeightSum();
   if(sum_abs <= 0.0)
      return false;

   bool any_opened = false;
   for(int leg = 0; leg < STRATEGY_LEG_COUNT; ++leg)
     {
      const string symbol = g_leg_symbols[leg];
      const double weight = g_leg_weights[leg];
      if(weight == 0.0)
         continue;

      const bool buy_leg = (spread_direction * weight) > 0.0;
      const QM_OrderType type = buy_leg ? QM_BUY : QM_SELL;
      const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
      if(entry <= 0.0)
         continue;

      const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(atr <= 0.0 || point <= 0.0)
         continue;

      const double stop_dist = strategy_atr_sl_mult * atr;
      const double sl_points = stop_dist / point;
      if(sl_points <= 0.0)
         continue;

      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      QM_BasketOrderRequest breq;
      breq.symbol = symbol;
      breq.type = type;
      breq.price = 0.0;
      breq.sl = buy_leg ? NormalizeDouble(entry - stop_dist, digits)
                         : NormalizeDouble(entry + stop_dist, digits);
      breq.tp = 0.0;
      breq.lots = QM_LotsForRisk(symbol, sl_points) * MathAbs(weight) / sum_abs;
      breq.reason = (spread_direction > 0) ? "QM5_10024_LONG_CHEAP_BASKET"
                                           : "QM5_10024_SHORT_RICH_BASKET";
      breq.symbol_slot = g_leg_slots[leg];
      breq.expiration_seconds = 0;

      ulong ticket = 0;
      if(QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, breq, ticket))
         any_opened = true;
     }
   return any_opened;
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int leg = Strategy_LegIndexForSymbol(_Symbol);
   if(leg < 0)
      return true;

   if(qm_magic_slot_offset != g_leg_slots[leg])
      return true;

   return !Strategy_DataAllows();
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10024_RW_FX_COMM_BASKET_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready || Strategy_OpenBasketLegCount() > 0)
      return false;

   int spread_direction = 0;
   if(g_z_prev >= -strategy_entry_z && g_z_now < -strategy_entry_z)
      spread_direction = 1;
   else if(g_z_prev <= strategy_entry_z && g_z_now > strategy_entry_z)
      spread_direction = -1;
   else
      return false;

   Strategy_OpenBasket(spread_direction);
   return false;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card baseline specifies basket z exits, a time stop, and per-leg ATR guards;
   // no trailing stop, break-even move, partial close, pyramiding, or rebalance.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready || Strategy_OpenBasketLegCount() <= 0)
      return false;

   if(MathAbs(g_z_now) <= strategy_exit_z)
     {
      Strategy_CloseBasket(QM_EXIT_STRATEGY);
      return false;
     }

   if(MathAbs(g_z_now) >= strategy_entry_z + strategy_stop_std_mult)
     {
      Strategy_CloseBasket(QM_EXIT_STRATEGY);
      return false;
     }

   if(strategy_time_stop_bars > 0)
     {
      const datetime oldest = Strategy_OldestBasketOpenTime();
      if(oldest > 0 && (int)(TimeCurrent() - oldest) >= strategy_time_stop_bars * 86400)
        {
         Strategy_CloseBasket(QM_EXIT_TIME_STOP);
         return false;
        }
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   for(int leg = 0; leg < STRATEGY_LEG_COUNT; ++leg)
     {
      const string symbol = g_leg_symbols[leg];
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(symbol, broker_time, qm_news_temporal, qm_news_compliance))
            return true;
        }
      else if(!QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   g_leg_weights[0] = strategy_weight_audusd;
   g_leg_weights[1] = strategy_weight_nzdusd;
   g_leg_weights[2] = strategy_weight_usdcad;
   g_leg_weights[3] = strategy_weight_audnzd;

   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
      SymbolSelect(g_leg_symbols[i], true);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10024\",\"strategy\":\"rw-fx-comm-basket\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   Strategy_RefreshState();
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
