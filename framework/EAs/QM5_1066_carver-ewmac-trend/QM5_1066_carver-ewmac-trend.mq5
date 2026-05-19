#property strict
#property version   "5.0"
#property description "QM5_1066 Carver EWMAC Vol-Normalised Trend"

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
input int    qm_ea_id                   = 1066;
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
input int    strategy_fast_ema          = 16;
input int    strategy_slow_ema          = 64;
input int    strategy_vol_span          = 25;
input double strategy_forecast_scalar   = 3.75;
input double strategy_forecast_cap      = 20.0;
input double strategy_entry_forecast    = 2.0;
input double strategy_exit_long         = 0.0;
input double strategy_exit_short        = 0.0;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 2.5;
input int    strategy_spread_days       = 20;
input double strategy_spread_mult       = 2.0;
input int    strategy_index_start_hour  = 8;
input int    strategy_index_end_hour    = 21;
input int    strategy_nonindex_hour     = 1;

const int STRATEGY_UNIVERSE_SIZE = 8;
string    g_universe_symbols[8] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX",
   "GDAXI.DWX", "NDX.DWX", "WS30.DWX", "XAUUSD.DWX"
  };

datetime  g_forecast_bar_time = 0;
double    g_cached_forecast = 0.0;
bool      g_forecast_ready = false;
datetime  g_last_entry_bar_time = 0;
datetime  g_last_exit_bar_time = 0;

bool Strategy_IsRegisteredSymbol()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return true;
   return false;
  }

bool Strategy_IsIndexSymbol()
  {
   return (_Symbol == "GDAXI.DWX" || _Symbol == "NDX.DWX" || _Symbol == "WS30.DWX");
  }

bool Strategy_TradingHourAllowsEntry()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(Strategy_IsIndexSymbol())
     {
      if(strategy_index_start_hour == strategy_index_end_hour)
         return true;
      if(strategy_index_start_hour < strategy_index_end_hour)
         return (dt.hour >= strategy_index_start_hour && dt.hour < strategy_index_end_hour);
      return (dt.hour >= strategy_index_start_hour || dt.hour < strategy_index_end_hour);
     }

   return (dt.hour >= strategy_nonindex_hour);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

int Strategy_OpenPositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return 1;
      if(type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

double Strategy_MedianDailySpreadPoints()
  {
   const int n = MathMin(strategy_spread_days, 64);
   if(n <= 0)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
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

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

double Strategy_EwmacForecast()
  {
   const int slow = MathMax(strategy_slow_ema, strategy_fast_ema + 1);
   const int warmup = MathMax(slow * 4, strategy_vol_span * 8);
   const int need = MathMin(MathMax(warmup, 128), 1200);

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, need, closes); // perf-allowed: gated by QM_IsNewBar(PERIOD_D1) in Strategy_RefreshForecast().
   if(copied < MathMax(slow + 2, strategy_vol_span + 2))
      return 0.0;

   const double alpha_fast = 2.0 / ((double)strategy_fast_ema + 1.0);
   const double alpha_slow = 2.0 / ((double)slow + 1.0);
   const double alpha_vol = 2.0 / ((double)strategy_vol_span + 1.0);

   double ema_fast = closes[copied - 1];
   double ema_slow = closes[copied - 1];
   double ewma_mean = 0.0;
   double ewma_var = 0.0;
   bool vol_seeded = false;

   for(int i = copied - 2; i >= 0; --i)
     {
      const double close_value = closes[i];
      ema_fast = alpha_fast * close_value + (1.0 - alpha_fast) * ema_fast;
      ema_slow = alpha_slow * close_value + (1.0 - alpha_slow) * ema_slow;

      const double diff = closes[i] - closes[i + 1];
      if(!vol_seeded)
        {
         ewma_mean = diff;
         ewma_var = 0.0;
         vol_seeded = true;
        }
      else
        {
         const double old_mean = ewma_mean;
         ewma_mean = alpha_vol * diff + (1.0 - alpha_vol) * ewma_mean;
         const double dev = diff - old_mean;
         ewma_var = alpha_vol * dev * dev + (1.0 - alpha_vol) * ewma_var;
        }
     }

   const double daily_vol = MathSqrt(MathMax(ewma_var, 0.0));
   if(daily_vol <= 0.0 || strategy_forecast_scalar <= 0.0)
      return 0.0;

   double forecast = strategy_forecast_scalar * (ema_fast - ema_slow) / daily_vol;
   const double cap_value = MathAbs(strategy_forecast_cap);
   if(cap_value > 0.0)
      forecast = MathMax(-cap_value, MathMin(cap_value, forecast));
   return forecast;
  }

void Strategy_RefreshForecast()
  {
   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar <= 0)
      return;
   if(g_forecast_bar_time == d1_bar)
      return;
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   g_cached_forecast = Strategy_EwmacForecast();
   g_forecast_bar_time = d1_bar;
   g_forecast_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   Strategy_RefreshForecast();
   if(!Strategy_IsRegisteredSymbol())
      return true;
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
   req.reason = "QM5_1066_EWMAC";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_forecast_ready || g_forecast_bar_time <= 0)
      return false;
   if(g_last_entry_bar_time == g_forecast_bar_time)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_TradingHourAllowsEntry())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   int direction = 0;
   if(g_cached_forecast > strategy_entry_forecast)
      direction = 1;
   else if(g_cached_forecast < -strategy_entry_forecast)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1066_EWMAC_LONG" : "QM5_1066_EWMAC_SHORT";
   g_last_entry_bar_time = g_forecast_bar_time;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial close; hard ATR SL only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!g_forecast_ready || g_forecast_bar_time <= 0)
      return false;
   if(g_last_exit_bar_time == g_forecast_bar_time)
      return false;

   const int direction = Strategy_OpenPositionDirection();
   if(direction == 0)
      return false;

   bool exit_now = false;
   if(direction > 0 && g_cached_forecast < strategy_exit_long)
      exit_now = true;
   if(direction < 0 && g_cached_forecast > strategy_exit_short)
      exit_now = true;

   if(exit_now)
      g_last_exit_bar_time = g_forecast_bar_time;
   return exit_now;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      SymbolSelect(g_universe_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1066\",\"ea\":\"carver-ewmac-trend\"}");
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
