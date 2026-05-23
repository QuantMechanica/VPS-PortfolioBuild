#property strict
#property version   "5.0"
#property description "QM5_10017 ForexFactory Stoch EMA50 H4"

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
input int    qm_ea_id                   = 10017;
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
input int    strategy_stoch_k_period    = 5;
input int    strategy_stoch_d_period    = 3;
input int    strategy_stoch_slowing     = 3;
input int    strategy_ema_period        = 50;
input int    strategy_atr_period        = 14;
input double strategy_slope_atr_mult    = 0.10;
input double strategy_stoch_lower       = 20.0;
input double strategy_stoch_upper       = 80.0;
input int    strategy_stop_lookback     = 5;
input double strategy_stop_buffer_pips  = 10.0;
input double strategy_max_stop_atr_mult = 3.0;
input double strategy_take_profit_rr    = 3.0;
input double strategy_trail_rr          = 1.0;
input int    strategy_time_stop_bars    = 18;

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
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_H4)
      return false;
   if(strategy_stop_lookback < 1 || strategy_take_profit_rr <= 0.0 || strategy_trail_rr <= 0.0)
      return false;

   const double k1 = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_H4, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_H4, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double ema1 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 1);
   const double ema4 = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 4);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(k1 < 0.0 || d1 < 0.0 || k2 < 0.0 || d2 < 0.0 || ema1 <= 0.0 || ema4 <= 0.0 || atr <= 0.0)
      return false;

   const bool slope_up = (ema1 - ema4) >= strategy_slope_atr_mult * atr;
   const bool slope_down = (ema4 - ema1) >= strategy_slope_atr_mult * atr;
   const bool long_cross = (k2 <= d2 && k1 > d1 && (k1 <= strategy_stoch_lower || d1 <= strategy_stoch_lower));
   const bool short_cross = (k2 >= d2 && k1 < d1 && (k1 >= strategy_stoch_upper || d1 >= strategy_stoch_upper));
   if(!(long_cross && slope_up) && !(short_cross && slope_down))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = ((digits == 3 || digits == 5) ? 10.0 : 1.0) * point;
   const double buffer = strategy_stop_buffer_pips * pip;
   const double entry = (long_cross ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(point <= 0.0 || pip <= 0.0 || entry <= 0.0 || buffer < 0.0)
      return false;

   double structure = long_cross ? DBL_MAX : -DBL_MAX;
   for(int i = 1; i <= strategy_stop_lookback; ++i)
     {
      if(long_cross)
         structure = MathMin(structure, iLow(_Symbol, PERIOD_H4, i));
      else
         structure = MathMax(structure, iHigh(_Symbol, PERIOD_H4, i));
     }
   if((long_cross && structure == DBL_MAX) || (short_cross && structure == -DBL_MAX) || structure <= 0.0)
      return false;

   const double sl = long_cross ? structure - buffer : structure + buffer;
   const double risk = MathAbs(entry - sl);
   const long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double min_stop = (double)stops_level * point;
   if(risk <= 0.0 || risk > strategy_max_stop_atr_mult * atr || (min_stop > 0.0 && risk < min_stop))
      return false;

   req.type = long_cross ? QM_BUY : QM_SELL;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(long_cross ? entry + strategy_take_profit_rr * risk : entry - strategy_take_profit_rr * risk, _Digits);
   req.reason = long_cross ? "FF_STOCH_EMA50_H4_LONG" : "FF_STOCH_EMA50_H4_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || sl <= 0.0 || tp <= 0.0 || strategy_take_profit_rr <= 0.0)
         continue;

      const double initial_r = MathAbs(tp - open_price) / strategy_take_profit_rr;
      if(initial_r <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid - open_price < strategy_trail_rr * initial_r)
            continue;
         const double new_sl = NormalizeDouble(bid - initial_r, _Digits);
         if(new_sl > sl && new_sl < bid)
            QM_TM_MoveSL(ticket, new_sl, "FF_STOCH_EMA50_TRAIL_1R");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(open_price - ask < strategy_trail_rr * initial_r)
            continue;
         const double new_sl = NormalizeDouble(ask + initial_r, _Digits);
         if((sl <= 0.0 || new_sl < sl) && new_sl > ask)
            QM_TM_MoveSL(ticket, new_sl, "FF_STOCH_EMA50_TRAIL_1R");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_buy = false;
   bool have_sell = false;
   bool time_stop = false;

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
      have_buy = have_buy || (ptype == POSITION_TYPE_BUY);
      have_sell = have_sell || (ptype == POSITION_TYPE_SELL);

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_time_stop_bars > 0 && open_time > 0 &&
         TimeCurrent() - open_time >= strategy_time_stop_bars * PeriodSeconds(PERIOD_H4))
         time_stop = true;
     }

   if(!have_buy && !have_sell)
      return false;
   if(time_stop)
      return true;

   const double k1 = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, PERIOD_H4, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, PERIOD_H4, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double d2 = QM_Stoch_D(_Symbol, PERIOD_H4, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(k1 < 0.0 || d1 < 0.0 || k2 < 0.0 || d2 < 0.0)
      return false;

   const bool cross_down = (k2 >= d2 && k1 < d1);
   const bool cross_up = (k2 <= d2 && k1 > d1);
   if(have_buy && cross_down)
      return true;
   if(have_sell && cross_up)
      return true;
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
