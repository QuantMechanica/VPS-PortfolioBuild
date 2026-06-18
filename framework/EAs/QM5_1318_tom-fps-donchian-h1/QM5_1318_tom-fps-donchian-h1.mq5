#property strict
#property version   "5.0"
#property description "QM5_1318 tom-fps-donchian-h1 — Tom Yeoman FPS Donchian-channel breakout + RSI confirmation (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1318 tom-fps-donchian-h1
// -----------------------------------------------------------------------------
// Source: Tom Yeoman "Forex Profit System" master-thread (ForexFactory thread/12503),
//   Donchian-channel breakout + RSI(14) confirmation variant.
// Card: artifacts/cards_approved/QM5_1318_tom-fps-donchian-h1.md (g0_status APPROVED).
//
// NOTE ON "TOM": the slug token "tom" here is the FF author *Tom* Yeoman, NOT
// turn-of-month. There is no date/seasonality STATE in this card — the single
// trigger EVENT is the Donchian breakout; RSI / EMA200 / channel-width are STATES.
//
// Mechanics (H1, closed-bar reads; shift 1 = last closed bar). The Donchian
// channel is fixed at signal time by using the PRIOR-bar window so the just-
// closed bar's break cannot trigger itself:
//   DC_upper = highest(high) over the 20 bars BEFORE the signal bar  (shift 2..21)
//   DC_lower = lowest(low)  over the same window
//   close_sig = iClose(shift 1)  (the just-closed bar's close)
//
//   Entry — BUY (all on the just-closed bar):
//     EVENT  breakout   : close_sig > DC_upper           (close clears prior 20-bar high)
//     STATE  momentum   : RSI(14)[1] > rsi_buy_thresh    (default 55)
//     STATE  macro bias : close_sig > EMA(200)[1]
//     STATE  width gate : (DC_upper - DC_lower) > width_atr_mult * ATR(14)[1]
//     STATE  re-arm     : price stayed INSIDE the channel for the last
//                         rearm_bars closed bars before the signal bar
//                         (stateless lookback — prevents stacked breakout entries)
//   Entry — SELL: mirror (close_sig < DC_lower, RSI < rsi_sell_thresh,
//                 close < EMA200, same width gate, same re-arm).
//
//   Stop  : BUY  = entry - sl_atr_mult * ATR(14)        (default 1.5)
//           SELL = entry + sl_atr_mult * ATR(14)
//   TP    : tp_atr_mult * ATR(14) from entry            (default 2.5, pure RR cap)
//
//   Exit (Strategy_ExitSignal), in addition to the protective SL/TP:
//     - Donchian opposite-band cross (BUY: close_sig < DC_lower; SELL mirror)
//     - Time-stop: position held >= time_stop_bars H1 bars -> market close
//
//   Session : trade only 06:00–21:00 broker-time (Strategy_NoTradeFilter).
//   Spread  : skip only a genuinely wide spread (fail-OPEN on .DWX zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1318;
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
input int    strategy_donchian_period   = 20;    // Donchian high/low lookback (P3-sweep 15-30)
input int    strategy_rsi_period        = 14;    // RSI period (P3-sweep 9-21)
input double strategy_rsi_buy_thresh    = 55.0;  // BUY: RSI must exceed this (P3-sweep 50-60)
input double strategy_rsi_sell_thresh   = 45.0;  // SELL: RSI must be below this (mirror)
input int    strategy_ema_macro_period  = 200;   // macro-bias EMA (P3-sweep 150-250)
input int    strategy_atr_period        = 14;    // ATR period (SL/TP + width gate)
input double strategy_width_atr_mult    = 1.0;   // channel width must exceed this * ATR
input double strategy_sl_atr_mult       = 1.5;   // SL distance = mult * ATR (P3-sweep 1.0-2.5)
input double strategy_tp_atr_mult       = 2.5;   // TP distance = mult * ATR (P3-sweep 1.5-4.0)
input int    strategy_time_stop_bars    = 40;    // close after N H1 bars without TP/SL
input int    strategy_rearm_bars        = 5;     // price must sit inside channel this many bars before a new signal
input int    strategy_sess_start_hour   = 6;     // session start, broker time (inclusive)
input int    strategy_sess_end_hour     = 21;    // session end, broker time (exclusive)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar, stateless) — perf-allowed single-bar OHLC reads.
// -----------------------------------------------------------------------------

// Highest high over `period` bars starting at `start_shift` (inclusive, going back).
double DonchianHigh(const int period, const int start_shift)
  {
   double hi = -DBL_MAX;
   for(int i = start_shift; i < start_shift + period; ++i)
     {
      const double h = iHigh(_Symbol, _Period, i); // perf-allowed
      if(h > hi) hi = h;
     }
   return hi;
  }

// Lowest low over `period` bars starting at `start_shift` (inclusive, going back).
double DonchianLow(const int period, const int start_shift)
  {
   double lo = DBL_MAX;
   for(int i = start_shift; i < start_shift + period; ++i)
     {
      const double l = iLow(_Symbol, _Period, i); // perf-allowed
      if(l < lo && l > 0.0) lo = l;
     }
   return lo;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time) + wide-spread guard.
// Returns TRUE to BLOCK. Fail-OPEN on .DWX zero/negative modeled spread.
bool Strategy_NoTradeFilter()
  {
   // --- Session window in broker time (06:00–21:00 broker). ---
   const datetime broker_now = TimeCurrent();
   MqlDateTime bt;
   TimeToStruct(broker_now, bt);
   if(strategy_sess_start_hour <= strategy_sess_end_hour)
     {
      if(bt.hour < strategy_sess_start_hour || bt.hour >= strategy_sess_end_hour)
         return true; // outside session
     }
   else
     {
      if(bt.hour < strategy_sess_start_hour && bt.hour >= strategy_sess_end_hour)
         return true;
     }

   // --- Wide-spread guard relative to ATR-scaled stop distance. ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer, do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Donchian channel over the window ENDING the bar BEFORE the signal bar. ---
   // Signal bar = the just-closed bar (shift 1). The channel must be "fixed" at
   // signal time, so it is computed over shift 2..(period+1) — i.e. it does NOT
   // include the breakout bar itself.
   const double dc_upper = DonchianHigh(strategy_donchian_period, 2);
   const double dc_lower = DonchianLow(strategy_donchian_period, 2);
   if(dc_upper <= 0.0 || dc_lower <= 0.0 || dc_upper <= dc_lower)
      return false;

   // --- Signal-bar close (just-closed bar). ---
   const double close_sig = iClose(_Symbol, _Period, 1); // perf-allowed
   if(close_sig <= 0.0)
      return false;

   // --- States. ---
   const double rsi   = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double ema   = QM_EMA(_Symbol, _Period, strategy_ema_macro_period, 1);
   const double atr_v = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(rsi <= 0.0 || ema <= 0.0 || atr_v <= 0.0)
      return false;

   // Channel-width gate: kill entries in a coil narrower than 1 ATR.
   const double width = dc_upper - dc_lower;
   if(width <= strategy_width_atr_mult * atr_v)
      return false;

   // Re-arm: require price to have sat INSIDE the channel for the rearm_bars
   // closed bars immediately preceding the signal bar (shift 2..rearm_bars+1).
   // This is a stateless closed-bar lookback (no timestamp gate). It prevents a
   // sustained breakout from stacking multiple entries — the bars before the
   // break must have been range-bound inside [dc_lower, dc_upper].
   bool was_inside = true;
   for(int i = 2; i <= strategy_rearm_bars + 1; ++i)
     {
      const double c = iClose(_Symbol, _Period, i); // perf-allowed
      if(c <= 0.0)
        {
         was_inside = false;
         break;
        }
      if(c > dc_upper || c < dc_lower)
        {
         was_inside = false;
         break;
        }
     }
   if(!was_inside)
      return false;

   // ---------------------------- BUY ----------------------------
   const bool brk_up    = (close_sig > dc_upper);
   const bool mom_buy   = (rsi > strategy_rsi_buy_thresh);
   const bool macro_buy = (close_sig > ema);
   if(brk_up && mom_buy && macro_buy)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_v, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_v, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "fps_donchian_long";
      return true;
     }

   // ---------------------------- SELL ---------------------------
   const bool brk_dn     = (close_sig < dc_lower);
   const bool mom_sell   = (rsi < strategy_rsi_sell_thresh);
   const bool macro_sell = (close_sig < ema);
   if(brk_dn && mom_sell && macro_sell)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_v, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_v, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "fps_donchian_short";
      return true;
     }

   return false;
  }

// Fixed ATR SL + ATR TP handle the protective side; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits (whichever fires first), evaluated on the closed bar:
//   - Donchian opposite-band cross (BUY: close back below the lower band;
//     SELL: close back above the upper band) — the breakout fully reversed.
//   - Time-stop: position open for >= time_stop_bars H1 bars.
// Direction + open time taken from the live open position for this EA's magic.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine open direction + open time.
   bool     is_long  = false;
   bool     is_short = false;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(!is_long && !is_short)
      return false;

   // --- Time-stop: bars held since entry. ---
   const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed (current bar open)
   if(open_time > 0 && bar_open > open_time)
     {
      const int secs_per_bar = PeriodSeconds(_Period);
      if(secs_per_bar > 0)
        {
         const int bars_held = (int)((bar_open - open_time) / secs_per_bar);
         if(bars_held >= strategy_time_stop_bars)
            return true;
        }
     }

   // --- Donchian opposite-band cross. ---
   // Channel fixed over the window before the just-closed bar (shift 2..period+1).
   const double dc_upper = DonchianHigh(strategy_donchian_period, 2);
   const double dc_lower = DonchianLow(strategy_donchian_period, 2);
   if(dc_upper <= 0.0 || dc_lower <= 0.0 || dc_upper <= dc_lower)
      return false;

   const double close_sig = iClose(_Symbol, _Period, 1); // perf-allowed
   if(close_sig <= 0.0)
      return false;

   if(is_long)
      return (close_sig < dc_lower); // breakout fully reversed below opposite band
   // is_short
   return (close_sig > dc_upper);
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
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
