#property strict
#property version   "5.0"
#property description "QM5_1330 DeMark TD Pressure H4 (buying/selling pressure oscillator)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1330 — DeMark TD-Pressure (H4)
// -----------------------------------------------------------------------------
// TD-Pressure is a buying-vs-selling-pressure oscillator bounded ~[0,100]:
//   bar_pressure_i = (close_i - open_i) / (high_i - low_i)        in [-1,+1]
//   num_t   = Sum_{i in N} ((bar_pressure_i + 1)/2) * volume_i
//   den_t   = Sum_{i in N} volume_i
//   TDP_t   = 100 * num_t / den_t                                (else 0)
// volume_i = tick_volume (PROXY for real volume on .DWX CFD/FX — flagged in
// SPEC + notes). N default 5 per DeMark canonical.
//
// Entry trigger (ONE event): TD-Pressure crosses BACK out of an extreme zone.
//   BUY  : TDP[2]<25 AND TDP[1]<25 (>=2-bar flush) AND TDP[2_cross]<25 AND
//          TDP crosses up through 25 (prev<25, curr>=25), close>EMA200.
//   SELL : mirror (>75, close<EMA200).
// Remaining conditions are STATES (macro bias, duration, no open position).
//
// .DWX invariants honoured: fail-OPEN spread guard; no swap gate; broker-time
// session window; prior CLOSE referenced (not gap/range); single QM_IsNewBar
// consume per OnTick (entry-gated); all indicator math in-EA (no ML);
// RISK_FIXED default; one position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1330;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_pressure_n         = 5;       // N-bar TD-Pressure lookback (DeMark canonical)
input double strategy_oversold           = 25.0;    // oversold zone threshold
input double strategy_overbought         = 75.0;    // overbought zone threshold
input int    strategy_flush_bars         = 2;       // min consecutive bars in extreme before cross-back
input int    strategy_ema_period         = 200;     // macro-bias EMA (H4)
input int    strategy_atr_period         = 14;      // ATR period for SL/TP sizing
input double strategy_sl_atr_mult        = 1.8;     // hard SL = 1.8 * ATR
input double strategy_tp_atr_mult        = 3.0;     // TP = 3.0 * ATR
input int    strategy_time_stop_bars     = 24;      // ~4 trading days time stop
input int    strategy_session_start_hr   = 6;       // broker-time session window (entries)
input int    strategy_session_end_hr     = 22;
input double strategy_spread_atr_mult    = 0.40;    // fail-OPEN spread guard cap (* ATR)

// File-scope cycle-suppression state (one entry per pressure cycle, per symbol).
// After a BUY entry: suppress new BUYs until TDP runs to overbought then back
// below it (full cycle to opposite extreme + return to neutral). SELL mirror.
bool g_buy_suppressed  = false;
bool g_sell_suppressed = false;

// -----------------------------------------------------------------------------
// TD-Pressure oscillator at a given closed-bar shift.
// Returns true on success and writes the [0,100] value; false if any bar in the
// N-window has zero range or zero tick-volume (dead-market hole corrupts the
// denominator — skip the signal per card "tick-volume sanity").
// Direct iX reads are perf-allowed bespoke structural math (gated by new-bar).
// -----------------------------------------------------------------------------
bool TDPressureAt(const int shift, double &value)
  {
   value = 0.0;
   const int n = (strategy_pressure_n > 0) ? strategy_pressure_n : 5;

   double num = 0.0;
   double den = 0.0;
   for(int i = shift; i < shift + n; ++i)
     {
      const double open  = iOpen(_Symbol, PERIOD_H4, i);
      const double high  = iHigh(_Symbol, PERIOD_H4, i);
      const double low   = iLow(_Symbol, PERIOD_H4, i);
      const double close = iClose(_Symbol, PERIOD_H4, i);
      const double vol   = (double)iVolume(_Symbol, PERIOD_H4, i);

      if(open <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0)
         return false;
      if(high <= low)            // zero range — undefined bar pressure
         return false;
      if(vol <= 0.0)             // tick-volume sanity: dead-market hole
         return false;

      const double bar_pressure = (close - open) / (high - low);     // [-1,+1]
      const double shifted      = (bar_pressure + 1.0) / 2.0;        // [0,1]
      num += shifted * vol;
      den += vol;
     }

   if(den <= 0.0)
      return false;

   value = 100.0 * num / den;
   return true;
  }

bool GetOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type, double &open_price, datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int BarsSincePositionOpen(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;
   const int shift = iBarShift(_Symbol, PERIOD_H4, open_time, false);
   return (shift < 0) ? 0 : shift;
  }

// Advance the per-symbol cycle-suppression latches once per closed bar.
// A suppressed BUY clears only after TDP has reached overbought and dropped
// back below it (full cycle); SELL mirror.
void AdvanceCycleSuppression()
  {
   double tdp = 0.0;
   if(!TDPressureAt(1, tdp))
      return;

   if(g_buy_suppressed && tdp <= strategy_overbought)
     {
      // require it to have re-touched the opposite extreme first
      double tdp_prev = 0.0;
      if(TDPressureAt(2, tdp_prev) && tdp_prev > strategy_overbought)
         g_buy_suppressed = false;
     }
   if(g_sell_suppressed && tdp >= strategy_oversold)
     {
      double tdp_prev = 0.0;
      if(TDPressureAt(2, tdp_prev) && tdp_prev < strategy_oversold)
         g_sell_suppressed = false;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block entries outside the broker-time session window. Cheap O(1).
bool Strategy_NoTradeFilter()
  {
   // Never block management of an already-open position.
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < strategy_session_start_hr || dt.hour >= strategy_session_end_hr)
      return true;

   // fail-OPEN spread guard: only block a genuinely wide spread.
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr > 0.0 && ask > 0.0 && bid > 0.0 && ask > bid &&
      (ask - bid) > atr * strategy_spread_atr_mult)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Advance cycle-suppression latches once per new closed bar (entry gate).
   AdvanceCycleSuppression();

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   // TD-Pressure at the just-closed bar (t = shift 1) and the prior two bars.
   double tdp1 = 0.0; // crossing bar (t)
   double tdp2 = 0.0; // t-1
   double tdp3 = 0.0; // t-2
   if(!TDPressureAt(1, tdp1) || !TDPressureAt(2, tdp2) || !TDPressureAt(3, tdp3))
      return false;

   const double ema = QM_EMA(_Symbol, PERIOD_H4, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double close1 = iClose(_Symbol, PERIOD_H4, 1);
   if(ema <= 0.0 || atr <= 0.0 || close1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const int flush = (strategy_flush_bars > 0) ? strategy_flush_bars : 2;

   // BUY: cross BACK UP out of oversold, after >=flush bars below oversold,
   // macro bias up, not cycle-suppressed.
   bool buy_flush = (tdp2 < strategy_oversold);
   if(flush >= 2)
      buy_flush = buy_flush && (tdp3 < strategy_oversold);
   const bool buy_cross = (tdp2 < strategy_oversold) && (tdp1 >= strategy_oversold);
   if(!g_buy_suppressed && buy_cross && buy_flush && close1 > ema)
     {
      const double entry = ask;
      double sl = entry - strategy_sl_atr_mult * atr;
      double tp = entry + strategy_tp_atr_mult * atr;
      if(sl <= 0.0 || (entry - sl) < point)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TD_PRESSURE_BUY";
      g_buy_suppressed = true;   // one entry per pressure cycle
      return true;
     }

   // SELL: mirror.
   bool sell_flush = (tdp2 > strategy_overbought);
   if(flush >= 2)
      sell_flush = sell_flush && (tdp3 > strategy_overbought);
   const bool sell_cross = (tdp2 > strategy_overbought) && (tdp1 <= strategy_overbought);
   if(!g_sell_suppressed && sell_cross && sell_flush && close1 < ema)
     {
      const double entry = bid;
      double sl = entry + strategy_sl_atr_mult * atr;
      double tp = entry - strategy_tp_atr_mult * atr;
      if(tp <= 0.0 || (sl - entry) < point)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TD_PRESSURE_SELL";
      g_sell_suppressed = true;  // one entry per pressure cycle
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // SL/TP are fixed at entry (hard SL 1.8*ATR, TP 3*ATR); no trailing per card.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   // Time stop: ~4 trading days (24 H4 bars) without TP/SL/opposite-extreme.
   const int bars_since = BarsSincePositionOpen(open_time);
   if(strategy_time_stop_bars > 0 && bars_since >= strategy_time_stop_bars)
      return true;

   // Opposite-extreme exit (primary): mean-reversion target reached.
   double tdp = 0.0;
   if(!TDPressureAt(1, tdp))
      return false;

   if(position_type == POSITION_TYPE_BUY && tdp > strategy_overbought)
      return true;
   if(position_type == POSITION_TYPE_SELL && tdp < strategy_oversold)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1330\",\"strategy\":\"td_pressure_h4\"}");
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
