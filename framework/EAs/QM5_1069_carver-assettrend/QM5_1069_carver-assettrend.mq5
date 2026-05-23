#property strict
#property version   "5.0"
#property description "QM5_1069 Carver Asset-Class Aggregate Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1069;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_fast_period        = 32;
input int    strategy_slow_period        = 128;
input int    strategy_vol_span           = 25;
input double strategy_forecast_scalar    = 1.0;
input double strategy_entry_forecast     = 2.0;
input double strategy_forecast_cap       = 20.0;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_min_group_symbols  = 3;

double   g_last_forecast       = 0.0;
bool     g_last_forecast_valid = false;
datetime g_last_forecast_d1    = 0;

int Strategy_SymbolSlot(const string symbol)
  {
   if(symbol == "EURUSD.DWX") return 0;
   if(symbol == "GBPUSD.DWX") return 1;
   if(symbol == "AUDUSD.DWX") return 2;
   if(symbol == "NZDUSD.DWX") return 3;
   if(symbol == "USDJPY.DWX") return 4;
   if(symbol == "USDCAD.DWX") return 5;
   if(symbol == "GDAXI.DWX")  return 6;
   if(symbol == "NDX.DWX")    return 7;
   if(symbol == "WS30.DWX")   return 8;
   return -1;
  }

bool Strategy_IsFxMajor(const string symbol)
  {
   return (symbol == "EURUSD.DWX" ||
           symbol == "GBPUSD.DWX" ||
           symbol == "AUDUSD.DWX" ||
           symbol == "NZDUSD.DWX" ||
           symbol == "USDJPY.DWX" ||
           symbol == "USDCAD.DWX");
  }

bool Strategy_IsIndex(const string symbol)
  {
   return (symbol == "GDAXI.DWX" ||
           symbol == "NDX.DWX" ||
           symbol == "WS30.DWX");
  }

int Strategy_LoadGroupSymbols(string &symbols[])
  {
   ArrayResize(symbols, 0);
   if(Strategy_IsFxMajor(_Symbol))
     {
      ArrayResize(symbols, 6);
      symbols[0] = "EURUSD.DWX";
      symbols[1] = "GBPUSD.DWX";
      symbols[2] = "AUDUSD.DWX";
      symbols[3] = "NZDUSD.DWX";
      symbols[4] = "USDJPY.DWX";
      symbols[5] = "USDCAD.DWX";
      return 6;
     }

   if(Strategy_IsIndex(_Symbol))
     {
      ArrayResize(symbols, 3);
      symbols[0] = "GDAXI.DWX";
      symbols[1] = "NDX.DWX";
      symbols[2] = "WS30.DWX";
      return 3;
     }

   return 0;
  }

bool Strategy_HasOurPosition(ENUM_POSITION_TYPE &ptype)
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

bool Strategy_ComputeGroupForecast(double &forecast)
  {
   forecast = 0.0;
   if(strategy_fast_period <= 1 ||
      strategy_slow_period <= strategy_fast_period ||
      strategy_vol_span <= 1 ||
      strategy_forecast_scalar <= 0.0 ||
      strategy_forecast_cap <= 0.0)
      return false;

   string symbols[];
   const int group_count = Strategy_LoadGroupSymbols(symbols);
   if(group_count < strategy_min_group_symbols)
      return false;

   const int samples = strategy_slow_period + strategy_vol_span + 5;
   if(samples < strategy_slow_period + 2)
      return false;

   double aggregate_price[];
   ArrayResize(aggregate_price, samples);
   double aggregate_level = 0.0;

   double symbol_var[];
   ArrayResize(symbol_var, group_count);
   for(int s = 0; s < group_count; ++s)
      symbol_var[s] = 0.0;

   const double alpha_vol = 2.0 / (strategy_vol_span + 1.0);
   for(int t = 0; t < samples; ++t)
     {
      const int shift = samples - t;
      double norm_sum = 0.0;
      int available = 0;

      for(int s = 0; s < group_count; ++s)
        {
         const double c_now = iClose(symbols[s], PERIOD_D1, shift);
         const double c_prev = iClose(symbols[s], PERIOD_D1, shift + 1);
         if(c_now <= 0.0 || c_prev <= 0.0)
            continue;

         const double r = (c_now / c_prev) - 1.0;
         symbol_var[s] = (alpha_vol * r * r) + ((1.0 - alpha_vol) * symbol_var[s]);
         const double vol = MathSqrt(symbol_var[s]);
         if(vol <= 0.0)
            continue;

         norm_sum += (r / vol);
         available++;
        }

      if(available < strategy_min_group_symbols)
        {
         aggregate_price[t] = aggregate_level;
         continue;
        }

      aggregate_level += (norm_sum / available);
      aggregate_price[t] = aggregate_level;
     }

   double ema_fast = aggregate_price[0];
   double ema_slow = aggregate_price[0];
   double group_var = 0.0;
   const double alpha_fast = 2.0 / (strategy_fast_period + 1.0);
   const double alpha_slow = 2.0 / (strategy_slow_period + 1.0);

   for(int t = 1; t < samples; ++t)
     {
      const double value = aggregate_price[t];
      const double diff = aggregate_price[t] - aggregate_price[t - 1];
      ema_fast = (alpha_fast * value) + ((1.0 - alpha_fast) * ema_fast);
      ema_slow = (alpha_slow * value) + ((1.0 - alpha_slow) * ema_slow);
      group_var = (alpha_vol * diff * diff) + ((1.0 - alpha_vol) * group_var);
     }

   const double group_vol = MathSqrt(group_var);
   if(group_vol <= 0.0)
      return false;

   forecast = strategy_forecast_scalar * (ema_fast - ema_slow) / group_vol;
   if(forecast > strategy_forecast_cap)
      forecast = strategy_forecast_cap;
   if(forecast < -strategy_forecast_cap)
      forecast = -strategy_forecast_cap;
   return true;
  }

bool Strategy_RefreshForecastCache()
  {
   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar <= 0)
      return false;

   if(g_last_forecast_valid && g_last_forecast_d1 == d1_bar)
      return true;

   double forecast = 0.0;
   g_last_forecast_valid = Strategy_ComputeGroupForecast(forecast);
   g_last_forecast = forecast;
   g_last_forecast_d1 = d1_bar;
   return g_last_forecast_valid;
  }

double Strategy_MedianD1Spread()
  {
   double values[20];
   int count = 0;
   for(int i = 1; i <= 20; ++i)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, i);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
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
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_SymbolSlot(_Symbol) < 0)
      return true;

   static datetime cached_d1 = 0;
   static double median_spread = 0.0;
   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar > 0 && d1_bar != cached_d1)
     {
      median_spread = Strategy_MedianD1Spread();
      cached_d1 = d1_bar;
     }

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point > 0.0 && ask > 0.0 && bid > 0.0 && median_spread > 0.0)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > 2.0 * median_spread)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int expected_slot = Strategy_SymbolSlot(_Symbol);
   if(expected_slot < 0 || qm_magic_slot_offset != expected_slot)
      return false;

   ENUM_POSITION_TYPE ptype;
   if(Strategy_HasOurPosition(ptype))
      return false;

   if(!Strategy_RefreshForecastCache())
      return false;

   if(g_last_forecast <= strategy_entry_forecast &&
      g_last_forecast >= -strategy_entry_forecast)
      return false;

   const QM_OrderType side = (g_last_forecast > strategy_entry_forecast) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "CARVER_ASSETTREND_LONG" : "CARVER_ASSETTREND_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed emergency ATR stop only; no trailing, BE, or partial exits.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_HasOurPosition(ptype))
      return false;

   if(!Strategy_RefreshForecastCache())
      return false;

   if(ptype == POSITION_TYPE_BUY && g_last_forecast < 0.0)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_last_forecast > 0.0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
