#property strict
#property version   "5.0"
#property description "QM5_1554 Bressert Double-Cycle Composite (H4)"

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
input int    qm_ea_id                   = 1554;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_trading_cycle_bars      = 24;
input int    strategy_intermediate_cycle_bars = 96;
input int    strategy_trading_tolerance_bars  = 2;
input int    strategy_intermediate_tolerance_bars = 4;
input int    strategy_dss_period              = 13;
input int    strategy_dss_slow                = 8;
input int    strategy_dss_smoothing           = 5;
input double strategy_dss_oversold            = 20.0;
input double strategy_dss_overbought          = 80.0;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 2.0;
input double strategy_spread_atr_mult         = 0.4;
input int    strategy_regime_sma_period       = 200;

datetime g_last_h4_signal_bar = 0;
datetime g_last_traded_long_anchor = 0;
datetime g_last_traded_short_anchor = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;
   if((ask - bid) > strategy_spread_atr_mult * atr)
      return true;
   return false;
  }

bool HasOpenPositionForMagic()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool FindLastSwingLow(const int period, const int search_bars, int &swing_shift, datetime &swing_time)
  {
   swing_shift = -1;
   swing_time = 0;
   if(period < 4 || search_bars <= period)
      return false;

   const int half = period / 2;
   const int bars = Bars(_Symbol, PERIOD_H4);
   if(bars <= search_bars + half + 2)
      return false;

   for(int shift = half + 1; shift <= search_bars; ++shift)
     {
      const double candidate = iLow(_Symbol, PERIOD_H4, shift);
      if(candidate <= 0.0)
         continue;

      bool is_swing = true;
      for(int j = shift - half; j <= shift + half; ++j)
        {
         if(j < 1)
            continue;
         const double v = iLow(_Symbol, PERIOD_H4, j);
         if(v <= 0.0 || v < candidate)
           {
            is_swing = false;
            break;
           }
        }

      if(is_swing)
        {
         swing_shift = shift;
         swing_time = iTime(_Symbol, PERIOD_H4, shift);
         return (swing_time > 0);
        }
     }
   return false;
  }

bool FindLastSwingHigh(const int period, const int search_bars, int &swing_shift, datetime &swing_time)
  {
   swing_shift = -1;
   swing_time = 0;
   if(period < 4 || search_bars <= period)
      return false;

   const int half = period / 2;
   const int bars = Bars(_Symbol, PERIOD_H4);
   if(bars <= search_bars + half + 2)
      return false;

   for(int shift = half + 1; shift <= search_bars; ++shift)
     {
      const double candidate = iHigh(_Symbol, PERIOD_H4, shift);
      if(candidate <= 0.0)
         continue;

      bool is_swing = true;
      for(int j = shift - half; j <= shift + half; ++j)
        {
         if(j < 1)
            continue;
         const double v = iHigh(_Symbol, PERIOD_H4, j);
         if(v <= 0.0 || v > candidate)
           {
            is_swing = false;
            break;
           }
        }

      if(is_swing)
        {
         swing_shift = shift;
         swing_time = iTime(_Symbol, PERIOD_H4, shift);
         return (swing_time > 0);
        }
     }
   return false;
  }

bool WithinProjectionWindow(const int anchor_shift, const int projected_bars, const int tolerance_bars)
  {
   return (MathAbs(anchor_shift - projected_bars) <= tolerance_bars);
  }

double CurrentDss(const int shift)
  {
   return QM_Stoch_K(_Symbol,
                     PERIOD_H4,
                     strategy_dss_period,
                     strategy_dss_slow,
                     strategy_dss_smoothing,
                     shift);
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

   const datetime h4_bar = iTime(_Symbol, PERIOD_H4, 0);
   if(h4_bar <= 0 || h4_bar == g_last_h4_signal_bar)
      return false;
   g_last_h4_signal_bar = h4_bar;

   if(HasOpenPositionForMagic())
      return false;

   const int p1 = strategy_trading_cycle_bars;
   const int p2 = strategy_intermediate_cycle_bars;
   if(p1 < 4 || p2 <= p1)
      return false;

   const int search = p2 + (p2 / 2) + strategy_intermediate_tolerance_bars + 8;
   int low_shift_1 = -1, low_shift_2 = -1, high_shift_1 = -1, high_shift_2 = -1;
   datetime low_time_1 = 0, low_time_2 = 0, high_time_1 = 0, high_time_2 = 0;
   if(!FindLastSwingLow(p1, search, low_shift_1, low_time_1))
      return false;
   if(!FindLastSwingLow(p2, search, low_shift_2, low_time_2))
      return false;
   if(!FindLastSwingHigh(p1, search, high_shift_1, high_time_1))
      return false;
   if(!FindLastSwingHigh(p2, search, high_shift_2, high_time_2))
      return false;

   const double dss_1 = CurrentDss(1);
   const double dss_2 = CurrentDss(2);
   if(dss_1 <= 0.0 && dss_2 <= 0.0)
      return false;

   const double d1_close = iClose(_Symbol, PERIOD_D1, 1);
   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1);
   if(d1_close <= 0.0 || d1_sma <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   const bool long_cycle =
      WithinProjectionWindow(low_shift_1, p1, strategy_trading_tolerance_bars) &&
      WithinProjectionWindow(low_shift_2, p2, strategy_intermediate_tolerance_bars);
   const bool long_confirm =
      dss_1 < strategy_dss_oversold && dss_1 > dss_2 && d1_close > d1_sma;

   if(long_cycle && long_confirm && low_time_2 != g_last_traded_long_anchor)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = NormalizeDouble(ask - strategy_atr_sl_mult * atr, _Digits);
      req.reason = "bressert_double_cycle_bottom";
      g_last_traded_long_anchor = low_time_2;
      return true;
     }

   const bool short_cycle =
      WithinProjectionWindow(high_shift_1, p1, strategy_trading_tolerance_bars) &&
      WithinProjectionWindow(high_shift_2, p2, strategy_intermediate_tolerance_bars);
   const bool short_confirm =
      dss_1 > strategy_dss_overbought && dss_1 < dss_2 && d1_close < d1_sma;

   if(short_cycle && short_confirm && high_time_2 != g_last_traded_short_anchor)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = NormalizeDouble(bid + strategy_atr_sl_mult * atr, _Digits);
      req.reason = "bressert_double_cycle_top";
      g_last_traded_short_anchor = high_time_2;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const int pt1_bars = strategy_trading_cycle_bars / 2;
   if(pt1_bars <= 0)
      return;

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
      const int bars_since_entry = iBarShift(_Symbol, PERIOD_H4, open_time, false);
      if(bars_since_entry < pt1_bars)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool be_done = (ptype == POSITION_TYPE_BUY) ? (current_sl >= open_price) :
                                                        (current_sl <= open_price && current_sl > 0.0);
      if(be_done)
         continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double close_lots = volume * 0.75;
      if(close_lots > 0.0)
         QM_TM_PartialClose(ticket, close_lots, QM_EXIT_STRATEGY);
      if(PositionSelectByTicket(ticket))
         QM_TM_MoveSL(ticket, open_price, "bressert_pt1_move_to_breakeven");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_entry = iBarShift(_Symbol, PERIOD_H4, open_time, false);
      if(bars_since_entry >= strategy_trading_cycle_bars)
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
