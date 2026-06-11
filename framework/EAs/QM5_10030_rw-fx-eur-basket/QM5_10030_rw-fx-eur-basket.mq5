#property strict
#property version   "5.0"
#property description "QM5_10030 Robot Wealth FX European Currency Basket"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10030;
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
input int    strategy_z_lookback_d1       = 60;
input double strategy_entry_z             = 2.0;
input double strategy_exit_z              = 0.50;
input double strategy_stop_std_mult       = 2.50;
input int    strategy_time_stop_bars      = 20;
input int    strategy_atr_period_d1       = 14;
input double strategy_atr_sl_mult         = 2.0;
input int    strategy_stationarity_bars   = 252;
input double strategy_stationarity_max_phi = 0.98;
input int    strategy_max_spread_points   = 60;
input double strategy_weight_eurusd       = 1.0;
input double strategy_weight_gbpusd       = 1.0;
input double strategy_weight_eurgbp       = 1.0;
input double strategy_weight_eurjpy       = 1.0;
input double strategy_weight_gbpjpy       = 1.0;
input double strategy_weight_usdchf       = 1.0;
input double strategy_weight_eurchf       = 1.0;

#define STRATEGY_LEG_COUNT 7

string g_leg_symbols[STRATEGY_LEG_COUNT] = {
   "EURUSD.DWX", "GBPUSD.DWX", "EURGBP.DWX", "EURJPY.DWX",
   "GBPJPY.DWX", "USDCHF.DWX", "EURCHF.DWX"
};
int g_leg_slots[STRATEGY_LEG_COUNT] = {0, 1, 2, 3, 4, 5, 6};
double g_leg_coeffs[STRATEGY_LEG_COUNT];

bool     g_basket_scope_ready = false;
bool     g_state_ready = false;
double   g_z_now = 0.0;
double   g_z_prev = 0.0;
double   g_spread_stdev = 0.0;
datetime g_last_entry_time = 0;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10030_RW_FX_EUR_BASKET_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int Strategy_LegIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
      if(symbol == g_leg_symbols[i])
         return i;
   return -1;
  }

double Strategy_AbsCoeffSum()
  {
   double sum_abs = 0.0;
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
      sum_abs += MathAbs(g_leg_coeffs[i]);
   return sum_abs;
  }

bool Strategy_HasDwxSuffix(const string symbol)
  {
   const int n = StringLen(symbol);
   return (n > 4 && StringSubstr(symbol, n - 4) == ".DWX");
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
      SymbolSelect(g_leg_symbols[i], true);

   QM_SymbolGuardInit(g_leg_symbols);
   const int warmup = MathMax(strategy_stationarity_bars + 5, strategy_z_lookback_d1 + 5);
   QM_BasketWarmupHistory(g_leg_symbols, PERIOD_D1, MathMax(300, warmup));
   g_basket_scope_ready = true;
   return true;
  }

bool Strategy_CopyLegCloses(const int count,
                            double &c0[], double &c1[], double &c2[], double &c3[],
                            double &c4[], double &c5[], double &c6[])
  {
   if(count < strategy_z_lookback_d1 + 2)
      return false;
   if(!Strategy_EnsureBasketScope())
      return false;

   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
      if(!QM_SymbolAssertOrLog(g_leg_symbols[i]))
         return false;

   ArraySetAsSeries(c0, true);
   ArraySetAsSeries(c1, true);
   ArraySetAsSeries(c2, true);
   ArraySetAsSeries(c3, true);
   ArraySetAsSeries(c4, true);
   ArraySetAsSeries(c5, true);
   ArraySetAsSeries(c6, true);

   if(CopyClose(g_leg_symbols[0], PERIOD_D1, 1, count, c0) != count) // perf-allowed: bounded D1 basket read, called only from framework QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_leg_symbols[1], PERIOD_D1, 1, count, c1) != count) // perf-allowed: bounded D1 basket read, called only from framework QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_leg_symbols[2], PERIOD_D1, 1, count, c2) != count) // perf-allowed: bounded D1 basket read, called only from framework QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_leg_symbols[3], PERIOD_D1, 1, count, c3) != count) // perf-allowed: bounded D1 basket read, called only from framework QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_leg_symbols[4], PERIOD_D1, 1, count, c4) != count) // perf-allowed: bounded D1 basket read, called only from framework QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_leg_symbols[5], PERIOD_D1, 1, count, c5) != count) // perf-allowed: bounded D1 basket read, called only from framework QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_leg_symbols[6], PERIOD_D1, 1, count, c6) != count) // perf-allowed: bounded D1 basket read, called only from framework QM_IsNewBar-gated EntrySignal.
      return false;

   return true;
  }

double Strategy_SpreadAt(const int index,
                         const double &c0[], const double &c1[], const double &c2[],
                         const double &c3[], const double &c4[], const double &c5[],
                         const double &c6[])
  {
   if(c0[index] <= 0.0 || c1[index] <= 0.0 || c2[index] <= 0.0 ||
      c3[index] <= 0.0 || c4[index] <= 0.0 || c5[index] <= 0.0 ||
      c6[index] <= 0.0)
      return 0.0;

   return g_leg_coeffs[0] * MathLog(c0[index])
        + g_leg_coeffs[1] * MathLog(c1[index])
        + g_leg_coeffs[2] * MathLog(c2[index])
        + g_leg_coeffs[3] * MathLog(c3[index])
        + g_leg_coeffs[4] * MathLog(c4[index])
        + g_leg_coeffs[5] * MathLog(c5[index])
        + g_leg_coeffs[6] * MathLog(c6[index]);
  }

bool Strategy_StationarityAllows(const int lookback,
                                 const double &c0[], const double &c1[], const double &c2[],
                                 const double &c3[], const double &c4[], const double &c5[],
                                 const double &c6[])
  {
   if(strategy_stationarity_bars < 30 || strategy_stationarity_max_phi <= 0.0)
      return true;

   const int n = MathMin(strategy_stationarity_bars, lookback - 1);
   if(n < 30)
      return false;

   double mean = 0.0;
   for(int i = 0; i <= n; ++i)
     {
      const double spread = Strategy_SpreadAt(i, c0, c1, c2, c3, c4, c5, c6);
      if(spread == 0.0 || !MathIsValidNumber(spread))
         return false;
      mean += spread;
     }
   mean /= (double)(n + 1);

   double num = 0.0;
   double den = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double current = Strategy_SpreadAt(i, c0, c1, c2, c3, c4, c5, c6) - mean;
      const double lagged = Strategy_SpreadAt(i + 1, c0, c1, c2, c3, c4, c5, c6) - mean;
      num += current * lagged;
      den += lagged * lagged;
     }
   if(den <= DBL_EPSILON)
      return false;

   const double phi = num / den;
   return (MathIsValidNumber(phi) && phi < strategy_stationarity_max_phi);
  }

bool Strategy_ComputeState(double &z_now, double &z_prev, double &stdev)
  {
   z_now = 0.0;
   z_prev = 0.0;
   stdev = 0.0;

   const int zlookback = MathMax(20, strategy_z_lookback_d1);
   const int required = MathMax(zlookback + 2, strategy_stationarity_bars + 2);

   double c0[], c1[], c2[], c3[], c4[], c5[], c6[];
   if(!Strategy_CopyLegCloses(required, c0, c1, c2, c3, c4, c5, c6))
      return false;

   if(!Strategy_StationarityAllows(required, c0, c1, c2, c3, c4, c5, c6))
      return false;

   double sum = 0.0;
   for(int i = 1; i <= zlookback; ++i)
     {
      const double spread = Strategy_SpreadAt(i, c0, c1, c2, c3, c4, c5, c6);
      if(spread == 0.0 || !MathIsValidNumber(spread))
         return false;
      sum += spread;
     }
   const double mean = sum / (double)zlookback;

   double var_sum = 0.0;
   for(int i = 1; i <= zlookback; ++i)
     {
      const double d = Strategy_SpreadAt(i, c0, c1, c2, c3, c4, c5, c6) - mean;
      var_sum += d * d;
     }
   stdev = MathSqrt(var_sum / (double)MathMax(1, zlookback - 1));
   if(stdev <= 0.0 || !MathIsValidNumber(stdev))
      return false;

   const double spread_now = Strategy_SpreadAt(0, c0, c1, c2, c3, c4, c5, c6);
   const double spread_prev = Strategy_SpreadAt(1, c0, c1, c2, c3, c4, c5, c6);
   z_now = (spread_now - mean) / stdev;
   z_prev = (spread_prev - mean) / stdev;
   return (MathIsValidNumber(z_now) && MathIsValidNumber(z_prev));
  }

bool Strategy_DataAllows()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return false;

   const int leg = Strategy_LegIndexForSymbol(_Symbol);
   if(leg < 0 || qm_magic_slot_offset != g_leg_slots[leg])
      return false;

   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
     {
      const string symbol = g_leg_symbols[i];
      if(!Strategy_HasDwxSuffix(symbol))
         return false;
      if(strategy_max_spread_points > 0)
        {
         const long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
         if(spread <= 0 || spread > strategy_max_spread_points)
            return false;
        }
     }
   return (Strategy_AbsCoeffSum() > 0.0);
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_z_now = 0.0;
   g_z_prev = 0.0;
   g_spread_stdev = 0.0;

   if(!Strategy_DataAllows())
      return false;
   if(!Strategy_ComputeState(g_z_now, g_z_prev, g_spread_stdev))
      return false;

   g_state_ready = true;
   return true;
  }

bool Strategy_HasCurrentLegPosition()
  {
   const int leg = Strategy_LegIndexForSymbol(_Symbol);
   if(leg < 0)
      return false;

   const int expected_magic = QM_MagicChecked(qm_ea_id, g_leg_slots[leg], _Symbol);
   if(expected_magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == expected_magic)
         return true;
     }
   return false;
  }

bool Strategy_CurrentLegPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

   const int leg = Strategy_LegIndexForSymbol(_Symbol);
   if(leg < 0)
      return false;

   const int expected_magic = QM_MagicChecked(qm_ea_id, g_leg_slots[leg], _Symbol);
   if(expected_magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != expected_magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_BuildLegRequest(const int spread_direction, QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   if(spread_direction == 0)
      return false;

   const int leg = Strategy_LegIndexForSymbol(_Symbol);
   if(leg < 0)
      return false;

   const double coeff = g_leg_coeffs[leg];
   if(coeff == 0.0)
      return false;

   const bool buy_leg = (spread_direction * coeff) > 0.0;
   const double entry = buy_leg ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const double stop_dist = strategy_atr_sl_mult * atr;
   const double sl_points = stop_dist / point;
   if(sl_points <= 0.0 || !MathIsValidNumber(sl_points))
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.type = buy_leg ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = buy_leg ? NormalizeDouble(entry - stop_dist, digits)
                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.reason = (spread_direction > 0) ? "QM5_10030_LONG_CHEAP_EUR_BASKET"
                                       : "QM5_10030_SHORT_RICH_EUR_BASKET";
   req.symbol_slot = g_leg_slots[leg];
   req.expiration_seconds = 0;
   return true;
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureBasketScope();
   return !Strategy_DataAllows();
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if(!Strategy_RefreshState())
      return false;
   if(Strategy_HasCurrentLegPosition())
      return false;

   int spread_direction = 0;
   if(g_z_now <= -MathAbs(strategy_entry_z))
      spread_direction = 1;
   else if(g_z_now >= MathAbs(strategy_entry_z))
      spread_direction = -1;
   else
      return false;

   if(!Strategy_BuildLegRequest(spread_direction, req))
      return false;

   g_last_entry_time = TimeCurrent();
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has fixed per-leg ATR guards and basket exits only.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_state_ready || !Strategy_HasCurrentLegPosition())
      return false;

   if(MathAbs(g_z_now) <= MathAbs(strategy_exit_z))
      return true;

   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_CurrentLegPosition(ptype, open_time))
      return false;

   if(strategy_time_stop_bars > 0 && open_time > 0 &&
      (int)(TimeCurrent() - open_time) >= strategy_time_stop_bars * 86400)
      return true;

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   if(is_long && g_z_now <= -MathAbs(strategy_entry_z) - MathAbs(strategy_stop_std_mult))
      return true;
   if(!is_long && g_z_now >= MathAbs(strategy_entry_z) + MathAbs(strategy_stop_std_mult))
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   for(int i = 0; i < STRATEGY_LEG_COUNT; ++i)
     {
      const string symbol = g_leg_symbols[i];
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
   g_leg_coeffs[0] = strategy_weight_eurusd;
   g_leg_coeffs[1] = strategy_weight_gbpusd;
   g_leg_coeffs[2] = strategy_weight_eurgbp;
   g_leg_coeffs[3] = strategy_weight_eurjpy;
   g_leg_coeffs[4] = strategy_weight_gbpjpy;
   g_leg_coeffs[5] = strategy_weight_usdchf;
   g_leg_coeffs[6] = strategy_weight_eurchf;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10030\",\"strategy\":\"rw-fx-eur-basket\"}");
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
