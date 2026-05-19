#property strict
#property version   "5.0"
#property description "QM5_1054 BigDog TMS TDI HMA H4"

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
input int    qm_ea_id                   = 1054;
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
input int    strategy_tdi_rsi_period     = 13;
input int    strategy_tdi_signal_period  = 2;
input double strategy_tdi_midline        = 50.0;
input int    strategy_hma_period         = 20;
input int    strategy_asctrend_period    = 10;
input double strategy_asctrend_atr_mult  = 0.50;
input int    strategy_swing_lookback     = 10;
input int    strategy_sl_buffer_points   = 30;
input double strategy_rr                 = 2.0;
input int    strategy_spread_cap_points  = 25;

double WmaClose(const int period, const int shift)
  {
   if(period <= 0 || shift < 0)
      return 0.0;

   double weighted_sum = 0.0;
   double weight_total = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double close_price = iClose(_Symbol, _Period, shift + i);
      if(close_price <= 0.0)
         return 0.0;

      const double weight = period - i;
      weighted_sum += close_price * weight;
      weight_total += weight;
     }

   if(weight_total <= 0.0)
      return 0.0;
   return weighted_sum / weight_total;
  }

double HmaValue(const int period, const int shift)
  {
   if(period < 2 || shift < 0)
      return 0.0;

   const int half_period = MathMax(1, period / 2);
   const int sqrt_period = MathMax(1, (int)MathSqrt((double)period));
   double weighted_sum = 0.0;
   double weight_total = 0.0;

   for(int i = 0; i < sqrt_period; ++i)
     {
      const double fast_wma = WmaClose(half_period, shift + i);
      const double slow_wma = WmaClose(period, shift + i);
      if(fast_wma <= 0.0 || slow_wma <= 0.0)
         return 0.0;

      const double raw_hma = (2.0 * fast_wma) - slow_wma;
      const double weight = sqrt_period - i;
      weighted_sum += raw_hma * weight;
      weight_total += weight;
     }

   if(weight_total <= 0.0)
      return 0.0;
   return weighted_sum / weight_total;
  }

double TdiGreen(const int shift)
  {
   return QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_tdi_rsi_period, shift, PRICE_CLOSE);
  }

double TdiRed(const int shift)
  {
   if(strategy_tdi_signal_period <= 0 || shift < 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < strategy_tdi_signal_period; ++i)
     {
      const double value = TdiGreen(shift + i);
      if(value <= 0.0)
         return 0.0;
      sum += value;
     }
   return sum / strategy_tdi_signal_period;
  }

int ASCTrendColor(const int shift)
  {
   const double close_now = iClose(_Symbol, _Period, shift);
   const double close_prev = iClose(_Symbol, _Period, shift + 1);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_asctrend_period, shift);
   if(close_now <= 0.0 || close_prev <= 0.0 || atr <= 0.0 || strategy_asctrend_atr_mult <= 0.0)
      return 0;

   const double band_offset = atr * strategy_asctrend_atr_mult;
   if(close_now > close_prev + band_offset)
      return 1;
   if(close_now < close_prev - band_offset)
      return -1;
   return 0;
  }

bool TdiCrossUp()
  {
   const double green_1 = TdiGreen(1);
   const double red_1 = TdiRed(1);
   const double green_2 = TdiGreen(2);
   const double red_2 = TdiRed(2);
   if(green_1 <= 0.0 || red_1 <= 0.0 || green_2 <= 0.0 || red_2 <= 0.0)
      return false;
   return (green_2 <= red_2 && green_1 > red_1 &&
           green_1 > strategy_tdi_midline && red_1 > strategy_tdi_midline);
  }

bool TdiCrossDown()
  {
   const double green_1 = TdiGreen(1);
   const double red_1 = TdiRed(1);
   const double green_2 = TdiGreen(2);
   const double red_2 = TdiRed(2);
   if(green_1 <= 0.0 || red_1 <= 0.0 || green_2 <= 0.0 || red_2 <= 0.0)
      return false;
   return (green_2 >= red_2 && green_1 < red_1 &&
           green_1 < strategy_tdi_midline && red_1 < strategy_tdi_midline);
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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

double SwingStopWithBuffer(const QM_OrderType side)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double base_stop = QM_StopStructure(_Symbol, side, QM_EntryMarketPrice(side), strategy_swing_lookback);
   if(point <= 0.0 || base_stop <= 0.0)
      return 0.0;

   const double buffer = strategy_sl_buffer_points * point;
   const double stop = QM_OrderTypeIsBuy(side) ? (base_stop - buffer) : (base_stop + buffer);
   return QM_StopRulesNormalizePrice(_Symbol, stop);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread > strategy_spread_cap_points)
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_H4 || HasOpenPosition())
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double hma_1 = HmaValue(strategy_hma_period, 1);
   if(close_1 <= 0.0 || hma_1 <= 0.0)
      return false;

   const int asctrend = ASCTrendColor(1);
   if(TdiCrossUp() && close_1 > hma_1 && asctrend > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = SwingStopWithBuffer(req.type);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "TMS_TDI_HMA_ASCTREND_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(TdiCrossDown() && close_1 < hma_1 && asctrend < 0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = SwingStopWithBuffer(req.type);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "TMS_TDI_HMA_ASCTREND_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   static datetime last_exit_eval_bar = 0;
   const datetime current_bar = iTime(_Symbol, _Period, 0);
   if(current_bar <= 0 || current_bar == last_exit_eval_bar)
      return false;
   last_exit_eval_bar = current_bar;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int asctrend = ASCTrendColor(1);
      if(ptype == POSITION_TYPE_BUY && (TdiCrossDown() || asctrend < 0))
         return true;
      if(ptype == POSITION_TYPE_SELL && (TdiCrossUp() || asctrend > 0))
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
