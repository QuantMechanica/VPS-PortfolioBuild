#property strict
#property version   "5.0"
#property description "QM5_11259 cs-macd-cross — CryptoSignal MACD signal-line cross (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11259 cs-macd-cross
// -----------------------------------------------------------------------------
// Source: Abenezer Mamo / CryptoSignal contributors — Crypto-Signal MACD analyzer
//   and docs/config.md 15m crossover example (MACD over MACD-signal).
// Card: artifacts/cards_approved/QM5_11259_cs-macd-cross.md (g0_status APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads at shift 1):
//   Trigger EVENT : MACD line crosses MACD signal line.
//                     Long  = main crosses ABOVE signal (prev<=sig, now>sig).
//                     Short = main crosses BELOW signal (prev>=sig, now<sig).
//                   The cross is the SINGLE event. The MACD line itself may be
//                   negative — there is intentionally NO main<=0 / main>=0 guard.
//   Noise filter  : optional |MACD histogram| / ATR floor (P2-tunable; default
//                   OFF so the baseline generates trades). STATE check, not a
//                   second event.
//   Stop          : ATR(14) hard stop at sl_atr_mult (2.0) ATR. No fixed TP —
//                   the position exits on the opposite cross or the time stop.
//   Management    : move SL to break-even after +1R (favourable excursion).
//   Exit          : opposite MACD line/signal cross (reverse), OR time stop
//                   after time_stop_bars (48) M15 bars with no opposite cross.
//   Spread guard  : skip only a genuinely wide spread > spread_pct_of_stop of
//                   the stop distance (fail-OPEN on .DWX zero modeled spread).
//   Session       : optional London+NY liquid-hours gate in BROKER time
//                   (DST-aware via QM_BrokerToUTC). Default window 08:00-21:00
//                   broker; widen/narrow per symbol in the setfile.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11259;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 9;      // MACD signal EMA period
input int    strategy_atr_period        = 14;     // ATR period (stop / noise norm)
input double strategy_sl_atr_mult       = 2.0;    // hard stop = mult * ATR
input int    strategy_time_stop_bars    = 48;     // close after N bars w/o opp cross
input bool   strategy_breakeven_enabled = true;   // move SL to BE after +1R
input double strategy_hist_atr_floor    = 0.0;    // |hist|/ATR noise floor (0 = OFF)
input double strategy_spread_pct_of_stop = 20.0;  // skip if spread > this % of stop dist
input bool   strategy_session_enabled   = true;   // restrict to liquid hours
input int    strategy_session_start_brk = 8;      // broker-hour session open (incl.)
input int    strategy_session_end_brk   = 21;     // broker-hour session end (excl.)

// -----------------------------------------------------------------------------
// File-scope state: bar index of the open position's entry, for the time stop.
// Tracked by entry-bar timestamp so it is robust across ticks.
// -----------------------------------------------------------------------------
datetime g_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// Helpers (closed-bar reads at shift 1 / 2 — the cross is shift1-vs-shift2).
// -----------------------------------------------------------------------------

// +1 fresh bullish cross, -1 fresh bearish cross, 0 none. The cross is the
// SINGLE event; the MACD main value may be negative on a valid bullish cross.
int MacdCrossSignal()
  {
   const double main_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                          strategy_macd_slow, strategy_macd_signal, 1);
   const double sig_now   = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, 1);
   const double main_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                          strategy_macd_slow, strategy_macd_signal, 2);
   const double sig_prev  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, 2);

   const bool crossed_up   = (main_prev <= sig_prev && main_now > sig_now);
   const bool crossed_down = (main_prev >= sig_prev && main_now < sig_now);
   if(crossed_up)
      return 1;
   if(crossed_down)
      return -1;
   return 0;
  }

// Optional |histogram|/ATR noise floor STATE. Returns true if the cross bar
// passes the floor (or the floor is OFF). main-signal = MACD histogram.
bool PassesNoiseFloor()
  {
   if(strategy_hist_atr_floor <= 0.0)
      return true; // filter OFF
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return true; // no ATR yet — do not block on it
   const double main_now = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                        strategy_macd_slow, strategy_macd_signal, 1);
   const double sig_now  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                          strategy_macd_slow, strategy_macd_signal, 1);
   const double hist = MathAbs(main_now - sig_now);
   return ((hist / atr_value) >= strategy_hist_atr_floor);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard (fail-OPEN on .DWX zero spread) plus
// optional liquid-hours session window in BROKER time (DST-aware).
bool Strategy_NoTradeFilter()
  {
   // --- Session window (broker time, DST-aware via UTC reference) ---
   if(strategy_session_enabled)
     {
      const datetime utc_now    = QM_BrokerToUTC(TimeCurrent());
      const datetime broker_now = QM_UTCToBroker(utc_now); // normalised broker time
      MqlDateTime bt;
      TimeToStruct(broker_now, bt);
      const int h = bt.hour;
      bool in_session;
      if(strategy_session_start_brk <= strategy_session_end_brk)
         in_session = (h >= strategy_session_start_brk && h < strategy_session_end_brk);
      else // wrap past midnight
         in_session = (h >= strategy_session_start_brk || h < strategy_session_end_brk);
      if(!in_session)
         return true; // block: outside liquid hours
     }

   // --- Spread guard: fail-OPEN on zero/negative modeled spread (.DWX) ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to entry gate
   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // only a genuinely wide spread blocks
   return false;
  }

// Symmetric long/short MACD signal-line cross. Caller guarantees QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int dir = MacdCrossSignal();
   if(dir == 0)
      return false;
   if(!PassesNoiseFloor())
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(dir > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — exit on opposite cross / time stop
      req.reason = "macd_cross_long";
     }
   else
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "macd_cross_short";
     }

   // Latch entry-bar time for the time stop (bar 0 = the just-closed-bar's tick).
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open read
   return true;
  }

// Move SL to break-even after +1R of favourable excursion.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_breakeven_enabled)
      return;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double open_px  = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl   = PositionGetDouble(POSITION_SL);
      const long   pos_type = PositionGetInteger(POSITION_TYPE);
      const double risk     = MathAbs(open_px - cur_sl);
      if(risk <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         // +1R reached and SL still below entry -> lift to break-even.
         if(bid - open_px >= risk && cur_sl < open_px)
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_px), "breakeven_1R");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(open_px - ask >= risk && cur_sl > open_px)
            QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_px), "breakeven_1R");
        }
     }
  }

// Exit on opposite MACD cross (reverse) or time stop after N bars.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Determine current open-position direction.
   const int magic = QM_FrameworkMagic();
   long pos_type = -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type = PositionGetInteger(POSITION_TYPE);
      break;
     }
   if(pos_type < 0)
      return false;

   // Opposite-cross reversal exit. The cross is the single event.
   const int dir = MacdCrossSignal();
   if(pos_type == POSITION_TYPE_BUY  && dir < 0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && dir > 0)
      return true;

   // Time stop: N closed bars elapsed since entry with no opposite cross.
   if(strategy_time_stop_bars > 0 && g_entry_bar_time > 0)
     {
      const datetime bar_now = iTime(_Symbol, _Period, 0); // perf-allowed: single read
      const int secs_per_bar = PeriodSeconds(_Period);
      if(secs_per_bar > 0)
        {
         const int bars_held = (int)((bar_now - g_entry_bar_time) / secs_per_bar);
         if(bars_held >= strategy_time_stop_bars)
            return true;
        }
     }
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   g_entry_bar_time = 0;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
      g_entry_bar_time = 0;
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
