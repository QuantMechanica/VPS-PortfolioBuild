#property strict
#property version   "5.0"
#property description "QM5_2014 NNFX V2 Range Filter Mean Reversion"

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
input int    qm_ea_id                   = 2014;
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
input int    strategy_adx_period         = 14;
input double strategy_adx_range_max      = 18.0;
input double strategy_adx_exit_min       = 23.0;
input int    strategy_range_ema_period   = 100;
input int    strategy_atr_period         = 14;
input double strategy_range_atr_mult     = 1.0;
input double strategy_exit_atr_mult      = 1.6;
input int    strategy_d1_momentum_bars   = 20;
input double strategy_d1_momentum_atr_mult = 1.5;
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 2.0;
input int    strategy_bbwidth_median_bars = 80;
input int    strategy_rsi_period         = 14;
input double strategy_rsi_long_max       = 32.0;
input double strategy_rsi_short_min      = 68.0;
input double strategy_stop_atr_mult      = 1.4;
input int    strategy_cooldown_h1_bars   = 4;
input int    strategy_time_exit_h1_bars  = 36;
input int    strategy_max_spread_points  = 0;

datetime g_recent_entry_time = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
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

   if(strategy_cooldown_h1_bars > 0 && g_recent_entry_time > 0)
     {
      const datetime h1_bar = iTime(_Symbol, PERIOD_H1, 1);
      const int since_entry = iBarShift(_Symbol, PERIOD_H1, g_recent_entry_time, false);
      if(h1_bar > 0 && since_entry >= 0 && since_entry < strategy_cooldown_h1_bars)
         return false;
     }

   const double h4_adx = QM_ADX(_Symbol, PERIOD_H4, strategy_adx_period, 1);
   const double h4_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double h4_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_range_ema_period, 1);
   const double h4_close = iClose(_Symbol, PERIOD_H4, 1);
   if(h4_adx <= 0.0 || h4_atr <= 0.0 || h4_ema <= 0.0 || h4_close <= 0.0)
      return false;
   if(h4_adx >= strategy_adx_range_max)
      return false;
   if(MathAbs(h4_close - h4_ema) > strategy_range_atr_mult * h4_atr)
      return false;

   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double d1_close_now = iClose(_Symbol, PERIOD_D1, 1);
   const double d1_close_then = iClose(_Symbol, PERIOD_D1, 1 + strategy_d1_momentum_bars);
   if(d1_atr <= 0.0 || d1_close_now <= 0.0 || d1_close_then <= 0.0)
      return false;
   if(MathAbs(d1_close_now - d1_close_then) >= strategy_d1_momentum_atr_mult * d1_atr)
      return false;

   double widths[];
   ArrayResize(widths, strategy_bbwidth_median_bars);
   for(int i = 0; i < strategy_bbwidth_median_bars; ++i)
     {
      const int shift = i + 2;
      const double upper_i = QM_BB_Upper(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, shift);
      const double lower_i = QM_BB_Lower(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, shift);
      if(upper_i <= 0.0 || lower_i <= 0.0 || upper_i <= lower_i)
         return false;
      widths[i] = upper_i - lower_i;
     }
   ArraySort(widths);
   const int mid = strategy_bbwidth_median_bars / 2;
   const double median_width = ((strategy_bbwidth_median_bars % 2) == 0) ? ((widths[mid - 1] + widths[mid]) * 0.5) : widths[mid];
   const double h4_upper = QM_BB_Upper(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 1);
   const double h4_lower = QM_BB_Lower(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 1);
   if(h4_upper <= 0.0 || h4_lower <= 0.0 || h4_upper <= h4_lower)
      return false;
   if((h4_upper - h4_lower) >= median_width)
      return false;

   const double h1_upper_1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double h1_lower_1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double h1_upper_2 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 2);
   const double h1_lower_2 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 2);
   const double h1_close_1 = iClose(_Symbol, PERIOD_H1, 1);
   const double h1_close_2 = iClose(_Symbol, PERIOD_H1, 2);
   const double h1_low_2 = iLow(_Symbol, PERIOD_H1, 2);
   const double h1_high_2 = iHigh(_Symbol, PERIOD_H1, 2);
   const double h1_rsi_2 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 2);
   const double h1_atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(h1_upper_1 <= 0.0 || h1_lower_1 <= 0.0 || h1_upper_2 <= 0.0 || h1_lower_2 <= 0.0 ||
      h1_close_1 <= 0.0 || h1_close_2 <= 0.0 || h1_low_2 <= 0.0 || h1_high_2 <= 0.0 ||
      h1_rsi_2 <= 0.0 || h1_atr <= 0.0 || point <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(h1_close_2 < h1_lower_2 && h1_rsi_2 < strategy_rsi_long_max && h1_close_1 > h1_lower_1)
     {
      const double sl = h1_low_2 - strategy_stop_atr_mult * h1_atr;
      const double sl_points = MathAbs(ask - sl) / point;
      if(sl <= 0.0 || sl_points <= 0.0 || QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.reason = "NNFX_RANGE_MR_LONG";
      g_recent_entry_time = iTime(_Symbol, PERIOD_H1, 1);
      return true;
     }

   if(h1_close_2 > h1_upper_2 && h1_rsi_2 > strategy_rsi_short_min && h1_close_1 < h1_upper_1)
     {
      const double sl = h1_high_2 + strategy_stop_atr_mult * h1_atr;
      const double sl_points = MathAbs(sl - bid) / point;
      if(sl <= 0.0 || sl_points <= 0.0 || QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.reason = "NNFX_RANGE_MR_SHORT";
      g_recent_entry_time = iTime(_Symbol, PERIOD_H1, 1);
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, averaging, martingale, or grid logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double middle = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(middle <= 0.0 || bid <= 0.0 || ask <= 0.0)
         return false;

      if(pos_type == POSITION_TYPE_BUY && bid >= middle)
         return true;
      if(pos_type == POSITION_TYPE_SELL && ask <= middle)
         return true;

      const double h4_adx = QM_ADX(_Symbol, PERIOD_H4, strategy_adx_period, 1);
      const double h4_atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
      const double h4_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_range_ema_period, 1);
      const double h4_close = iClose(_Symbol, PERIOD_H4, 1);
      if(h4_adx > strategy_adx_exit_min)
         return true;
      if(h4_atr > 0.0 && h4_ema > 0.0 && h4_close > 0.0 &&
         MathAbs(h4_close - h4_ema) > strategy_exit_atr_mult * h4_atr)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, PERIOD_H1, open_time, false);
      if(open_shift >= strategy_time_exit_h1_bars)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode))
      return true;
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
