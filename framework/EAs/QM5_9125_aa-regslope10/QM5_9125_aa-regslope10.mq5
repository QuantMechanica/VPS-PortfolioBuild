#property strict
#property version   "5.0"
#property description "QM5_9125 Alpha Architect Regression Slope 10 Trend"

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
input int    qm_ea_id                    = 9125;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_regression_period  = 10;
input int    strategy_min_d1_bars        = 30;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_spread_lookback    = 20;
input double strategy_spread_median_mult = 2.5;

#define STRATEGY_SYMBOL_COUNT 9
string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "SP500.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX",
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX"
  };

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return idx;
  }

bool Strategy_HasOpenPosition()
  {
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool Strategy_HasMinimumBars()
  {
   if(strategy_regression_period < 2 || strategy_regression_period > 64)
      return false;
   if(strategy_atr_period < 1)
      return false;
   if(strategy_min_d1_bars < strategy_regression_period + 1)
      return false;
   return (Bars(_Symbol, PERIOD_D1) >= strategy_min_d1_bars);
  }

double Strategy_RegSlope(const int first_closed_shift)
  {
   if(!Strategy_HasMinimumBars() || first_closed_shift < 1)
      return 0.0;

   const int n = strategy_regression_period;
   const double t_mean = -0.5 * (double)(n - 1);
   double closes[64];
   double c_sum = 0.0;

   for(int k = 0; k < n; ++k)
     {
      const int shift = first_closed_shift + (n - 1 - k);
      const double close_price = iClose(_Symbol, PERIOD_D1, shift);
      if(close_price <= 0.0)
         return 0.0;
      closes[k] = close_price;
      c_sum += close_price;
     }

   const double c_mean = c_sum / (double)n;
   double numerator = 0.0;
   double denominator = 0.0;

   for(int k = 0; k < n; ++k)
     {
      const double t = (double)k - (double)(n - 1);
      const double t_dev = t - t_mean;
      numerator += t_dev * (closes[k] - c_mean);
      denominator += t_dev * t_dev;
     }

   if(denominator <= 0.0)
      return 0.0;
   return numerator / denominator;
  }

bool Strategy_SpreadBlocksEntry()
  {
   if(strategy_spread_lookback <= 0 || strategy_spread_median_mult <= 0.0)
      return false;

   const int last_spread = (int)iSpread(_Symbol, PERIOD_D1, 1);
   if(last_spread <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, strategy_spread_lookback);
   int samples = 0;

   for(int i = 1; i <= strategy_spread_lookback; ++i)
     {
      const int spread = (int)iSpread(_Symbol, PERIOD_D1, i);
      if(spread <= 0)
         continue;
      spreads[samples] = (double)spread;
      samples++;
     }

   if(samples < 3)
      return false;

   ArrayResize(spreads, samples);
   ArraySort(spreads);

   double median = spreads[samples / 2];
   if((samples % 2) == 0)
      median = 0.5 * (spreads[samples / 2 - 1] + spreads[samples / 2]);

   return (median > 0.0 && last_spread > strategy_spread_median_mult * median);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return true;
   return (qm_magic_slot_offset != idx);
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   if(Strategy_CurrentSymbolIndex() < 0)
      return false;
   if(!Strategy_HasMinimumBars())
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(Strategy_SpreadBlocksEntry())
      return false;

   const double slope_now = Strategy_RegSlope(1);
   const double slope_prev = Strategy_RegSlope(2);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(slope_now > 0.0 && slope_prev <= 0.0)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATR(_Symbol, QM_BUY, req.price, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "QM5_9125_REGSLOPE10_CROSS_UP";
      return (req.sl > 0.0 && req.sl < req.price);
     }

   if(slope_now < 0.0 && slope_prev >= 0.0)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATR(_Symbol, QM_SELL, req.price, strategy_atr_period, strategy_atr_sl_mult);
      req.reason = "QM5_9125_REGSLOPE10_CROSS_DOWN";
      return (req.sl > 0.0 && req.sl > req.price);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasMinimumBars())
      return false;

   const double slope_now = Strategy_RegSlope(1);
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && slope_now <= 0.0)
         return true;
      if(type == POSITION_TYPE_SELL && slope_now >= 0.0)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   // Per-closed-D1-bar: this card evaluates both exits and entries only on
   // the final completed D1 bar.
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   // Discretionary exit (opposite zero-cross). Separate from SL/TP.
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
