#property strict
#property version   "5.0"
#property description "QM5_11403 carter-tf3-ema50-100-macd-partial-exit — H4 EMA50/100 zone + MACD cross, 2R partial + EMA50 trail"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11403 carter-tf3-ema50-100-macd-partial-exit
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Trend Following Systems" (2014), Strategy #3.
// Card: artifacts/cards_approved/QM5_11403_carter-tf3-ema50-100-macd-partial-exit.md
//       (g0_status APPROVED). Source ID 29c77a02-59bd-52f7-bcb3-b3108d5f1e79.
//
// Mechanics (closed-bar reads at shift 1; H4):
//   Zone STATE (EMA50/EMA100 stack + broken-past-EMA50 by >= zone_break_pips):
//     LONG  : close@1 > EMA50@1  AND  close@1 > EMA100@1  AND  EMA50@1 > EMA100@1
//             AND  close@1 >= EMA50@1 + zone_break_pips   (out of the squeeze zone)
//     SHORT : close@1 < EMA50@1  AND  close@1 < EMA100@1  AND  EMA50@1 < EMA100@1
//             AND  close@1 <= EMA50@1 - zone_break_pips
//   Trigger EVENT (the SINGLE event; MACD can be negative — NO sign-as-validity):
//     MACD(12,26,9) main crosses signal within the last macd_window closed bars.
//     LONG  : main crossed ABOVE signal on some bar s in [1 .. macd_window].
//     SHORT : main crossed BELOW signal on some bar s in [1 .. macd_window].
//   The EMA zone is a STATE; the MACD cross is the one EVENT observed within a
//   small lookback window (avoids the two-cross-same-bar zero-trade trap).
//   Stop         : 5-bar structure (lowest low / highest high of last sl_lookback
//                  closed bars), capped at sl_cap_pips.
//   Take profit  : none fixed — TP1 is a 2R partial; the rest trails to EMA50.
//   Management   : at +partial_rr * R, close partial_close_pct of the position and
//                  move SL to breakeven on the remainder (latched once per fill).
//   Exit         : after the partial, close the remainder when price breaks back
//                  through EMA50 by exit_break_pips (closed-bar event).
//   Spread guard : block ONLY a genuinely wide spread (> spread_cap_pips). Fail
//                  OPEN on .DWX zero modeled spread.
//
// MACD-validity note: QM_MACD_Main / QM_MACD_Signal legitimately run negative;
// readiness is gated on the strictly-positive EMA / structure reads (same closed
// H4 bars), never on the MACD sign.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11403;
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
input int    strategy_ema_fast_period   = 50;     // fast EMA (zone + trail anchor)
input int    strategy_ema_slow_period   = 100;    // slow EMA (zone)
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 9;      // MACD signal period
input int    strategy_macd_window       = 5;      // MACD cross must occur within last N bars
input double strategy_zone_break_pips    = 10.0;  // min break past EMA50 (out of squeeze)
input int    strategy_sl_lookback       = 5;      // structure SL lookback (bars)
input double strategy_sl_cap_pips        = 80.0;  // max SL distance (pips)
input double strategy_partial_rr         = 2.0;   // take partial at this R-multiple
input double strategy_partial_close_pct  = 50.0;  // % of position closed at TP1
input double strategy_exit_break_pips    = 10.0;  // close remainder if price breaks EMA50 by this
input double strategy_spread_cap_pips    = 20.0;  // skip only if spread > this (pips)

// File-scope: latch whether we've already taken the partial for the current
// position (set per fill; cleared when flat). NOT a new-bar gate.
ulong  g_partial_done_ticket = 0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// pip-distance in price terms for the active symbol (scale-correct, 5-digit/JPY).
double PipsToPrice(const double pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(pips));
  }

// MACD main crossed ABOVE signal within [1 .. window] closed bars (one EVENT).
bool MacdCrossedUpRecently(const int window)
  {
   for(int s = 1; s <= window; ++s)
     {
      const double main_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, s);
      const double sig_now   = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, s);
      const double main_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, s + 1);
      const double sig_prev  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, s + 1);
      // Fresh upward cross between consecutive closed bars. MACD can be negative.
      if(main_prev <= sig_prev && main_now > sig_now)
         return true;
     }
   return false;
  }

// MACD main crossed BELOW signal within [1 .. window] closed bars (one EVENT).
bool MacdCrossedDownRecently(const int window)
  {
   for(int s = 1; s <= window; ++s)
     {
      const double main_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, s);
      const double sig_now   = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, s);
      const double main_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, s + 1);
      const double sig_prev  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                            strategy_macd_slow, strategy_macd_signal, s + 1);
      if(main_prev >= sig_prev && main_now < sig_now)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// a 0 / negative modeled spread is never a reason to block.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap    = PipsToPrice(strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Readiness via strictly-positive reads (NOT via the MACD sign) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double break_dist = PipsToPrice(strategy_zone_break_pips);
   if(break_dist <= 0.0)
      return false;

   // --- Zone STATE (long): above both EMAs, EMA stack up, broken past EMA50 ---
   const bool zone_long  = (close1 > ema_fast) && (close1 > ema_slow) &&
                           (ema_fast > ema_slow) &&
                           (close1 >= ema_fast + break_dist);
   const bool zone_short = (close1 < ema_fast) && (close1 < ema_slow) &&
                           (ema_fast < ema_slow) &&
                           (close1 <= ema_fast - break_dist);

   QM_OrderType side;
   if(zone_long && MacdCrossedUpRecently(strategy_macd_window))
      side = QM_BUY;
   else if(zone_short && MacdCrossedDownRecently(strategy_macd_window))
      side = QM_SELL;
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: 5-bar structure, capped at sl_cap_pips ---
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_lookback);
   if(sl <= 0.0)
      return false;

   // Enforce the pip cap on the structure stop distance.
   const double cap_dist = PipsToPrice(strategy_sl_cap_pips);
   if(cap_dist > 0.0)
     {
      const double sl_dist = MathAbs(entry - sl);
      if(sl_dist > cap_dist)
         sl = (side == QM_BUY) ? QM_TM_NormalizePrice(_Symbol, entry - cap_dist)
                               : QM_TM_NormalizePrice(_Symbol, entry + cap_dist);
     }
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — 2R partial + EMA50 trail exit
   req.reason = (side == QM_BUY) ? "carter_tf3_long" : "carter_tf3_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Take a partial at +partial_rr * R, move SL to breakeven on the remainder.
// Latched once per fill; cleared in this same hook when flat.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_partial_done_ticket = 0; // flat — reset the partial latch
      return;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(g_partial_done_ticket == ticket)
         continue; // partial already taken for this fill

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_price   = PositionGetDouble(POSITION_SL);
      const double volume     = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0 || sl_price <= 0.0)
         continue;

      // 1R in price terms = |entry - initial SL| (SL untouched before the partial).
      const double r_dist = MathAbs(open_price - sl_price);
      if(r_dist <= 0.0)
         continue;

      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;
      const double moved = is_buy ? (market - open_price) : (open_price - market);

      // --- Partial at +partial_rr * R (once per fill) ---
      if(moved >= strategy_partial_rr * r_dist)
        {
         const double part_lots = QM_TM_NormalizeVolume(_Symbol,
                                    volume * strategy_partial_close_pct / 100.0);
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         // Only partial if both legs remain tradeable.
         if(part_lots >= min_lot && (volume - part_lots) >= min_lot)
            QM_TM_PartialClose(ticket, part_lots, QM_EXIT_PARTIAL);

         // Break-even on the remainder (only if it improves the stop).
         const double be_sl = QM_TM_NormalizePrice(_Symbol, open_price);
         const bool be_improves = is_buy ? (be_sl > sl_price) : (be_sl < sl_price);
         if(be_sl > 0.0 && be_improves)
            QM_TM_MoveSL(ticket, be_sl, "breakeven_after_partial");

         g_partial_done_ticket = ticket; // latch regardless of partial success
        }
     }
  }

// After the partial, close the remainder when price breaks back through EMA50
// by exit_break_pips (closed-bar event). Pre-partial, the structure SL governs.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   // Only trail-exit the remainder once the partial has been taken.
   if(g_partial_done_ticket == 0)
      return false;

   // Determine current side from the open position.
   bool is_buy = false;
   bool found  = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found  = true;
      break;
     }
   if(!found)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema_fast <= 0.0 || close1 <= 0.0)
      return false;

   const double break_dist = PipsToPrice(strategy_exit_break_pips);
   if(break_dist <= 0.0)
      return false;

   // LONG: close back below EMA50 by exit_break_pips. SHORT mirror.
   if(is_buy)
      return (close1 <= ema_fast - break_dist);
   return (close1 >= ema_fast + break_dist);
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

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
