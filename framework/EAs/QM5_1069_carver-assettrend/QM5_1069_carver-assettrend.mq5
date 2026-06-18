#property strict
#property version   "5.0"
#property description "QM5_1069 Carver Asset-Class Aggregate Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1069;
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
input int    strategy_fast_period       = 32;
input int    strategy_slow_period       = 128;
input int    strategy_vol_span          = 25;
input double strategy_forecast_scalar   = 1.0;
input double strategy_entry_forecast    = 2.0;
input double strategy_forecast_cap      = 20.0;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 2.5;
input int    strategy_min_group_symbols = 3;
input int    strategy_spread_days       = 20;

#define STRATEGY_SYMBOL_COUNT 9
#define STRATEGY_FX_COUNT 6
#define STRATEGY_INDEX_START 6
#define STRATEGY_INDEX_COUNT 3

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX",
   "NZDUSD.DWX", "USDJPY.DWX", "USDCAD.DWX",
   "GDAXI.DWX", "NDX.DWX", "WS30.DWX"
  };

int g_strategy_slots[STRATEGY_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6, 7, 8};

bool   g_state_ready = false;
double g_group_forecast = 0.0;
bool   g_exit_pending = false;
double g_median_spread_points = 0.0;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1069_CARVER_ASSETTREND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int Strategy_IndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(symbol == g_strategy_symbols[i])
         return i;
   return -1;
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   const int idx = Strategy_IndexForSymbol(symbol);
   if(idx < 0)
      return -1;
   return g_strategy_slots[idx];
  }

bool Strategy_GroupForSymbol(const string symbol, int &start, int &count)
  {
   start = -1;
   count = 0;

   const int idx = Strategy_IndexForSymbol(symbol);
   if(idx < 0)
      return false;

   if(idx < STRATEGY_FX_COUNT)
     {
      start = 0;
      count = STRATEGY_FX_COUNT;
      return true;
     }

   start = STRATEGY_INDEX_START;
   count = STRATEGY_INDEX_COUNT;
   return true;
  }

int Strategy_WarmupBars()
  {
   return MathMax(300, strategy_slow_period + strategy_vol_span + strategy_atr_period + 20);
  }

bool Strategy_DataAllows()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return false;

   const int expected_slot = Strategy_SlotForSymbol(_Symbol);
   if(expected_slot < 0 || qm_magic_slot_offset != expected_slot)
      return false;

   int group_start = -1;
   int group_count = 0;
   if(!Strategy_GroupForSymbol(_Symbol, group_start, group_count))
      return false;

   return (group_count >= strategy_min_group_symbols);
  }

bool Strategy_CurrentPosition(ENUM_POSITION_TYPE &ptype)
  {
   ptype = POSITION_TYPE_BUY;
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_CopyCloses(const string symbol, const int count, double &closes[])
  {
   if(count <= 2)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   ArrayResize(closes, count);
   const int got = CopyClose(symbol, PERIOD_D1, 1, count, closes); // perf-allowed: bounded D1 basket read, called only from the framework QM_IsNewBar-gated EntrySignal.
   return (got == count);
  }

double Strategy_MedianSpreadPoints()
  {
   if(strategy_spread_days <= 0)
      return 0.0;

   int spreads[];
   ArrayResize(spreads, strategy_spread_days);
   const int got = CopySpread(_Symbol, PERIOD_D1, 1, strategy_spread_days, spreads); // perf-allowed: bounded D1 spread snapshot, called only from the framework QM_IsNewBar-gated EntrySignal.
   if(got <= 0)
      return 0.0;

   double values[];
   int count = 0;
   ArrayResize(values, got);
   for(int i = 0; i < got; ++i)
     {
      if(spreads[i] <= 0)
         continue;
      values[count] = (double)spreads[i];
      count++;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[count / 2 - 1] + values[count / 2]);
  }

bool Strategy_ComputeGroupForecast(double &forecast)
  {
   forecast = 0.0;
   if(strategy_fast_period <= 1 ||
      strategy_slow_period <= strategy_fast_period ||
      strategy_vol_span <= 1 ||
      strategy_forecast_scalar <= 0.0 ||
      strategy_forecast_cap <= 0.0 ||
      strategy_min_group_symbols < 1)
      return false;

   int group_start = -1;
   int group_count = 0;
   if(!Strategy_GroupForSymbol(_Symbol, group_start, group_count))
      return false;
   if(group_count < strategy_min_group_symbols)
      return false;

   const int return_count = strategy_slow_period + strategy_vol_span + 20;
   const int close_count = return_count + 1;
   double aggregate_returns[];
   int aggregate_counts[];
   ArrayResize(aggregate_returns, return_count);
   ArrayResize(aggregate_counts, return_count);
   for(int i = 0; i < return_count; ++i)
     {
      aggregate_returns[i] = 0.0;
      aggregate_counts[i] = 0;
     }

   const double alpha_vol = 2.0 / ((double)strategy_vol_span + 1.0);
   for(int s = 0; s < group_count; ++s)
     {
      const string symbol = g_strategy_symbols[group_start + s];
      double closes[];
      if(!Strategy_CopyCloses(symbol, close_count, closes))
         continue;

      double variance = 0.0;
      for(int t = 1; t < close_count; ++t)
        {
         const double prev_close = closes[t - 1];
         const double curr_close = closes[t];
         if(prev_close <= 0.0 || curr_close <= 0.0)
            continue;

         const double r = (curr_close / prev_close) - 1.0;
         variance = alpha_vol * r * r + (1.0 - alpha_vol) * variance;
         const double vol = MathSqrt(variance);
         if(vol <= 0.0 || !MathIsValidNumber(vol))
            continue;

         aggregate_returns[t - 1] += r / vol;
         aggregate_counts[t - 1]++;
        }
     }

   double aggregate_price[];
   ArrayResize(aggregate_price, return_count);
   double level = 0.0;
   for(int t = 0; t < return_count; ++t)
     {
      if(aggregate_counts[t] < strategy_min_group_symbols)
         return false;
      level += aggregate_returns[t] / (double)aggregate_counts[t];
      aggregate_price[t] = level;
     }

   double ema_fast = aggregate_price[0];
   double ema_slow = aggregate_price[0];
   double group_var = 0.0;
   const double alpha_fast = 2.0 / ((double)strategy_fast_period + 1.0);
   const double alpha_slow = 2.0 / ((double)strategy_slow_period + 1.0);

   for(int t = 1; t < return_count; ++t)
     {
      const double value = aggregate_price[t];
      const double diff = aggregate_price[t] - aggregate_price[t - 1];
      ema_fast = alpha_fast * value + (1.0 - alpha_fast) * ema_fast;
      ema_slow = alpha_slow * value + (1.0 - alpha_slow) * ema_slow;
      group_var = alpha_vol * diff * diff + (1.0 - alpha_vol) * group_var;
     }

   const double group_vol = MathSqrt(group_var);
   if(group_vol <= 0.0 || !MathIsValidNumber(group_vol))
      return false;

   forecast = strategy_forecast_scalar * (ema_fast - ema_slow) / group_vol;
   if(forecast > strategy_forecast_cap)
      forecast = strategy_forecast_cap;
   if(forecast < -strategy_forecast_cap)
      forecast = -strategy_forecast_cap;

   return MathIsValidNumber(forecast);
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_exit_pending = false;
   g_group_forecast = 0.0;
   g_median_spread_points = Strategy_MedianSpreadPoints();

   if(!Strategy_DataAllows())
      return false;

   if(!Strategy_ComputeGroupForecast(g_group_forecast))
      return false;

   ENUM_POSITION_TYPE ptype;
   if(Strategy_CurrentPosition(ptype))
     {
      if(ptype == POSITION_TYPE_BUY && g_group_forecast < 0.0)
         g_exit_pending = true;
      if(ptype == POSITION_TYPE_SELL && g_group_forecast > 0.0)
         g_exit_pending = true;
     }

   g_state_ready = true;
   return true;
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_DataAllows())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && g_median_spread_points > 0.0)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > 2.0 * g_median_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if(!Strategy_RefreshState())
      return false;

   ENUM_POSITION_TYPE ptype;
   if(Strategy_CurrentPosition(ptype))
      return false;

   QM_OrderType side = QM_BUY;
   if(g_group_forecast > strategy_entry_forecast)
      side = QM_BUY;
   else if(g_group_forecast < -strategy_entry_forecast)
      side = QM_SELL;
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "QM5_1069_ASSETTREND_LONG" : "QM5_1069_ASSETTREND_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card baseline uses the entry-time ATR emergency stop only.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_exit_pending)
      return false;

   ENUM_POSITION_TYPE ptype;
   if(!Strategy_CurrentPosition(ptype))
     {
      g_exit_pending = false;
      return false;
     }

   return true;
  }

// News Filter Hook (callable for P8 News Impact phase).
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

   QM_SymbolGuardInit(g_strategy_symbols);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, Strategy_WarmupBars());

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1069\",\"strategy\":\"carver-assettrend\"}");
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
