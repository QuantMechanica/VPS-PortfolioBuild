#property strict
#property version   "5.0"
#property description "QM5_1064 Unger Inside-Day Breakout with Trend Bias"

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
input int    qm_ea_id                   = 1064;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_SKIP_DAY;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_sma_period          = 200;
input int    strategy_atr_period          = 20;
input double strategy_atr_stop_mult       = 2.0;
input double strategy_min_range_atr_mult  = 0.3;
input int    strategy_hold_days           = 3;
input int    strategy_breakout_offset_pts = 1;
input int    strategy_order_tif_seconds   = 86400;
input int    strategy_spread_median_days  = 20;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_order_tif_seconds;

   if(strategy_sma_period < 1 ||
      strategy_atr_period < 1 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_min_range_atr_mult <= 0.0 ||
      strategy_breakout_offset_pts < 0 ||
      strategy_spread_median_days < 1)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return false;
     }

   MqlRates spread_rates[];
   const int spread_copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, spread_rates); // perf-allowed: Strategy_EntrySignal is called only after QM_IsNewBar().
   if(spread_copied == strategy_spread_median_days)
     {
      int spreads[];
      ArrayResize(spreads, spread_copied);
      int positive_count = 0;
      for(int i = 0; i < spread_copied; ++i)
        {
         if(spread_rates[i].spread > 0)
           {
            spreads[positive_count] = spread_rates[i].spread;
            positive_count++;
           }
        }
      if(positive_count > 0)
        {
         ArrayResize(spreads, positive_count);
         ArraySort(spreads);
         const double median_spread = (positive_count % 2 == 1)
                                      ? (double)spreads[positive_count / 2]
                                      : ((double)spreads[(positive_count / 2) - 1] + (double)spreads[positive_count / 2]) / 2.0;
         const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if(median_spread > 0.0 && current_spread > 2.0 * median_spread)
            return false;
        }
     }

   const double high_1 = iHigh(_Symbol, PERIOD_D1, 1);
   const double low_1 = iLow(_Symbol, PERIOD_D1, 1);
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1);
   const double high_2 = iHigh(_Symbol, PERIOD_D1, 2);
   const double low_2 = iLow(_Symbol, PERIOD_D1, 2);
   if(high_1 <= 0.0 || low_1 <= 0.0 || close_1 <= 0.0 || high_2 <= 0.0 || low_2 <= 0.0)
      return false;

   if(!(high_1 < high_2 && low_1 > low_2))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   if(atr <= 0.0 || sma <= 0.0)
      return false;

   const double inside_range = high_1 - low_1;
   if(inside_range <= 0.0 || inside_range < strategy_min_range_atr_mult * atr)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double offset = (double)strategy_breakout_offset_pts * point;

   if(close_1 > sma)
     {
      const double entry = high_1 + offset;
      const double structure_sl = low_1 - offset;
      const double atr_cap_sl = entry - strategy_atr_stop_mult * atr;
      const double sl = MathMax(structure_sl, atr_cap_sl);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "ID_BIAS_LONG_BUY_STOP";
      return true;
     }

   if(close_1 < sma)
     {
      const double entry = low_1 - offset;
      const double structure_sl = high_1 + offset;
      const double atr_cap_sl = entry + strategy_atr_stop_mult * atr;
      const double sl = MathMin(structure_sl, atr_cap_sl);
      if(entry <= 0.0 || sl <= entry)
         return false;

      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "ID_BIAS_SHORT_SELL_STOP";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Baseline card has no trailing, break-even, partial close, or profit target.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_hold_days < 1)
      return false;

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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_bar_shift = iBarShift(_Symbol, PERIOD_D1, open_time, false);
      if(open_bar_shift >= strategy_hold_days)
         return true;
     }

   return false;
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
