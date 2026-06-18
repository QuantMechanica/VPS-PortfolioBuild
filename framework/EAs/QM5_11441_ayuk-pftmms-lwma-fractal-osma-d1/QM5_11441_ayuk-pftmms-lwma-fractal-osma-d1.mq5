#property strict
#property version   "5.0"
#property description "QM5_11441 ayuk-pftmms-lwma-fractal-osma-d1 — LWMA(8/10)+OsMA+Fractal SL, LIMIT pullback (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11441 ayuk-pftmms-lwma-fractal-osma-d1
// -----------------------------------------------------------------------------
// Source: Caroline Ayuk, "PFTMMS — Profit from the Market Master System"
//         (online/self-published, source_id 16844b14-0fe5-53d2-876e-336ee9b67e0d).
// Card: artifacts/cards_approved/QM5_11441_ayuk-pftmms-lwma-fractal-osma-d1.md
//       (g0_status APPROVED).
//
// D1 end-of-day trend-pullback strategy. All reads are on CLOSED bars (shift>=1)
// so the signal is non-repainting. Per the build directive the OsMA zero-cross
// OR a fractal break is the single EVENT; the LWMA trend alignment is a STATE.
//
// Sibling QM5_11367 (caroline-ayuk) is the same indicator family. KEY DIFFERENCE
// of this PFTMMS variant (card §Entry 4):
//   - When price is FAR from LWMA8, entry is a PENDING LIMIT at LWMA8 (wait for a
//     PULLBACK to the fast MA), NOT a breakout STOP. The limit is valid for ONE
//     D1 bar only and is cancelled if unfilled.
//   - OsMA STATE is strictly positive (>0) for long / negative (<0) for short.
//
// Mechanics (LONG; SHORT mirrors):
//   STATE  (trend) : LWMA(8, Close)[1]  > LWMA(10, Open, MA-shift 1)[1]  (fast>slow)
//                    AND OsMA(12,26,9)[1] > 0                            (positive)
//                    AND Low[1] > LWMA(10, Open)[1]                      (no break below slow MA)
//   EVENT  (one of):
//     (a) OsMA zero-cross-up : OsMA[2] <= 0 AND OsMA[1] > 0, OR
//     (b) fractal break-up   : Close[1] > last confirmed UP fractal price
//   Entry  : if (Close[1] - LWMA8) within entry_market_pips -> BUY at market next bar
//            else -> BUY LIMIT at LWMA8 (pullback to fast MA), valid 1 bar.
//   Stop   : Low of the last confirmed DOWN fractal before the setup bar,
//            capped to sl_max_pips (P2 cap, D1 swing trades need wide stops).
//   Take   : entry + tp_rr * (entry - sl).      (card R:R 1.5:1)
//   Manage : breakeven (+be_buffer_pips) once price moves be_trigger_frac * SL
//            in favour (card: BE once 0.5R in profit).
//   Exit   : opposite setup STATE fires -> close immediately.
//   Spread : skip only a genuinely wide spread (fail-OPEN on .DWX zero spread).
//
// OsMA = MACD main - MACD signal (the MACD histogram, can be negative). MT5's
// native OsMA equals exactly that with (12,26,9), so we derive it from the
// pooled QM_MACD_* readers rather than allocating a separate handle.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11441;
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
input int    strategy_lwma_fast_period   = 8;      // fast LWMA on Close
input int    strategy_lwma_slow_period   = 10;     // slow LWMA on Open (MA-shift 1)
input int    strategy_macd_fast          = 12;     // OsMA fast EMA (MACD fast)
input int    strategy_macd_slow          = 26;     // OsMA slow EMA (MACD slow)
input int    strategy_macd_signal        = 9;      // OsMA signal EMA (MACD signal)
input int    strategy_entry_market_pips  = 60;     // within this of LWMA8 -> market, else LIMIT at LWMA8
input int    strategy_sl_max_pips        = 150;    // P2 cap on fractal-based stop distance (card: 150 pips)
input int    strategy_fractal_scan_bars  = 60;     // how far back to scan for the last fractal
input double strategy_tp_rr              = 1.5;    // TP = tp_rr * SL distance (card 1.5:1)
input double strategy_be_trigger_frac    = 0.5;    // move to BE once price moves this * SL in favour (card 0.5R)
input int    strategy_be_buffer_pips     = 0;      // BE offset (BE + this many pips); card = pure breakeven
input double strategy_spread_pct_of_stop = 25.0;   // skip if spread > this % of stop budget (card spread cap 25 pips ~ % of 150)
input int    strategy_pending_expiry_sec = 86400;  // pending LIMIT lifetime (1 D1 bar)

// -----------------------------------------------------------------------------
// Internal helpers (closed-bar deterministic reads only)
// -----------------------------------------------------------------------------

// OsMA histogram at a closed-bar shift = MACD main - MACD signal.
double Strategy_OsMA(const int shift)
  {
   const double main_v = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                       strategy_macd_slow, strategy_macd_signal, shift, PRICE_CLOSE);
   const double sig_v  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                        strategy_macd_slow, strategy_macd_signal, shift, PRICE_CLOSE);
   return main_v - sig_v;
  }

// Fast LWMA(period, Close) at a closed-bar shift.
double Strategy_LwmaFast(const int shift)
  {
   return QM_LWMA(_Symbol, _Period, strategy_lwma_fast_period, shift, PRICE_CLOSE);
  }

// Slow LWMA(period, Open) with a 1-bar MA-shift. The card specifies LWMA(10,
// Open, shift=1): the MA value is itself shifted forward one bar. We emulate that
// by reading the LWMA one bar OLDER than the requested closed bar (shift+1).
double Strategy_LwmaSlow(const int shift)
  {
   return QM_LWMA(_Symbol, _Period, strategy_lwma_slow_period, shift + 1, PRICE_OPEN);
  }

// Last confirmed DOWN (lower) fractal price strictly before `from_shift`.
// iFractals confirms a pivot only after 2 bars to its right, so the newest
// confirmable fractal sits at shift 2 at the earliest. We scan from
// max(from_shift, 3) outward — this is bounded and non-repainting.
double Strategy_LastLowerFractal(const int from_shift)
  {
   int s = (from_shift > 3) ? from_shift : 3;
   const int last = s + strategy_fractal_scan_bars;
   for(; s <= last; ++s)
     {
      const double f = QM_FractalLower(_Symbol, _Period, s);
      if(f > 0.0)
         return f;
     }
   return 0.0;
  }

// Last confirmed UP (upper) fractal price strictly before `from_shift`.
double Strategy_LastUpperFractal(const int from_shift)
  {
   int s = (from_shift > 3) ? from_shift : 3;
   const int last = s + strategy_fractal_scan_bars;
   for(; s <= last; ++s)
     {
      const double f = QM_FractalUpper(_Symbol, _Period, s);
      if(f > 0.0)
         return f;
     }
   return 0.0;
  }

// LONG state: fast>slow + price above slow MA + OsMA strictly positive (card).
bool Strategy_LongState()
  {
   const double lwma8  = Strategy_LwmaFast(1);
   const double lwma10 = Strategy_LwmaSlow(1);
   if(lwma8 <= 0.0 || lwma10 <= 0.0)
      return false;
   const double low1 = iLow(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(low1 <= 0.0)
      return false;
   if(!(lwma8 > lwma10))      // fast MA above slow MA
      return false;
   if(!(low1 > lwma10))       // candle low above slow MA (no break below filter)
      return false;
   if(!(Strategy_OsMA(1) > 0.0))  // OsMA strictly positive
      return false;
   return true;
  }

// SHORT state (mirror).
bool Strategy_ShortState()
  {
   const double lwma8  = Strategy_LwmaFast(1);
   const double lwma10 = Strategy_LwmaSlow(1);
   if(lwma8 <= 0.0 || lwma10 <= 0.0)
      return false;
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(high1 <= 0.0)
      return false;
   if(!(lwma8 < lwma10))      // fast MA below slow MA
      return false;
   if(!(high1 < lwma10))      // candle high below slow MA
      return false;
   if(!(Strategy_OsMA(1) < 0.0))  // OsMA strictly negative
      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing quote

   // Cap the spread relative to the configured stop budget so it scales per symbol.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes (fail-OPEN).
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// D1 end-of-day entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// PFTMMS variant: pending order is a LIMIT (pullback to LWMA8), not a STOP.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double osma1 = Strategy_OsMA(1);
   const double osma2 = Strategy_OsMA(2);

   const double market_band = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_market_pips);
   if(market_band <= 0.0)
      return false;

   // ---------------------- LONG ----------------------
   if(Strategy_LongState())
     {
      const double lwma8 = Strategy_LwmaFast(1);
      // EVENT: OsMA zero-cross-up OR price breaks above the last UP fractal.
      const bool osma_cross_up = (osma2 <= 0.0 && osma1 > 0.0);
      const double up_frac = Strategy_LastUpperFractal(2);
      const bool frac_break_up = (up_frac > 0.0 && close1 > up_frac);
      if(osma_cross_up || frac_break_up)
        {
         // Stop = last DOWN fractal low before the setup bar, capped to sl_max_pips.
         const double down_frac = Strategy_LastLowerFractal(2);
         if(down_frac <= 0.0)
            return false;

         // Within market_band of LWMA8 -> market; else LIMIT (pullback) at LWMA8.
         const bool is_market = (MathAbs(close1 - lwma8) <= market_band);
         const double entry = is_market
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)              // market
                              : QM_StopRulesNormalizePrice(_Symbol, lwma8);        // BUY LIMIT @ LWMA8
         if(entry <= 0.0)
            return false;

         double sl = down_frac;
         if(!(sl < entry))
            return false; // fractal not below entry — invalid stop geometry
         const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
         if(entry - sl > max_dist)
            sl = entry - max_dist; // cap stop distance
         sl = QM_StopRulesNormalizePrice(_Symbol, sl);

         const double sl_dist = entry - sl;
         if(sl_dist <= 0.0)
            return false;
         const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_rr * sl_dist);

         req.type   = is_market ? QM_BUY : QM_BUY_LIMIT;
         req.price  = is_market ? 0.0 : entry; // 0 => framework fills market price
         req.sl     = sl;
         req.tp     = tp;
         req.reason = is_market ? "ayuk_pftmms_long_market" : "ayuk_pftmms_long_buylimit";
         req.expiration_seconds = is_market ? 0 : strategy_pending_expiry_sec;
         return true;
        }
     }

   // ---------------------- SHORT ----------------------
   if(Strategy_ShortState())
     {
      const double lwma8 = Strategy_LwmaFast(1);
      const bool osma_cross_dn = (osma2 >= 0.0 && osma1 < 0.0);
      const double dn_frac = Strategy_LastLowerFractal(2);
      const bool frac_break_dn = (dn_frac > 0.0 && close1 < dn_frac);
      if(osma_cross_dn || frac_break_dn)
        {
         const double up_frac = Strategy_LastUpperFractal(2);
         if(up_frac <= 0.0)
            return false;

         const bool is_market = (MathAbs(close1 - lwma8) <= market_band);
         const double entry = is_market
                              ? SymbolInfoDouble(_Symbol, SYMBOL_BID)              // market
                              : QM_StopRulesNormalizePrice(_Symbol, lwma8);        // SELL LIMIT @ LWMA8
         if(entry <= 0.0)
            return false;

         double sl = up_frac;
         if(!(sl > entry))
            return false;
         const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
         if(sl - entry > max_dist)
            sl = entry + max_dist;
         sl = QM_StopRulesNormalizePrice(_Symbol, sl);

         const double sl_dist = sl - entry;
         if(sl_dist <= 0.0)
            return false;
         const double tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_tp_rr * sl_dist);

         req.type   = is_market ? QM_SELL : QM_SELL_LIMIT;
         req.price  = is_market ? 0.0 : entry;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = is_market ? "ayuk_pftmms_short_market" : "ayuk_pftmms_short_selllimit";
         req.expiration_seconds = is_market ? 0 : strategy_pending_expiry_sec;
         return true;
        }
     }

   return false;
  }

// Trade management: move SL to breakeven (+buffer) once price moves
// be_trigger_frac * SL in favour (card: BE once 0.5R in profit).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl     = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || cur_sl <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double mkt = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(mkt <= 0.0)
         continue;

      // Original SL distance: |open - current SL|. Favourable move measured from open.
      const double sl_dist = MathAbs(open_price - cur_sl);
      if(sl_dist <= 0.0)
         continue;

      const double moved = is_buy ? (mkt - open_price) : (open_price - mkt);
      if(moved <= 0.0)
         continue;

      // Breakeven (+ buffer) once price moves be_trigger_frac * SL in favour.
      if(moved >= strategy_be_trigger_frac * sl_dist)
        {
         const double be_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_be_buffer_pips);
         const double target = is_buy ? (open_price + be_buffer) : (open_price - be_buffer);
         const double ntarget = QM_TM_NormalizePrice(_Symbol, target);
         const bool improves = is_buy ? (ntarget > cur_sl) : (ntarget < cur_sl);
         if(ntarget > 0.0 && improves)
            QM_TM_MoveSL(ticket, ntarget, "ayuk_pftmms_breakeven");
        }
     }
  }

// Opposite-signal exit: close the open position if the opposite setup STATE fires.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && Strategy_ShortState())
         return true;
      if(ptype == POSITION_TYPE_SELL && Strategy_LongState())
         return true;
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
