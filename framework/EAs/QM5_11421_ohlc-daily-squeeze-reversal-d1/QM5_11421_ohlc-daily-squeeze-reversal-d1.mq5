#property strict
#property version   "5.0"
#property description "QM5_11421 ohlc-daily-squeeze-reversal-d1 — OHLC squeeze reversal (D1, pending-stop)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11421 ohlc-daily-squeeze-reversal-d1
// -----------------------------------------------------------------------------
// Source: "Forex Scalping Strategies" (anonymous), Strategy C "Forex Market
//   Squeeze". Card: artifacts/cards_approved/QM5_11421_ohlc-daily-squeeze-
//   reversal-d1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads; day 2 = shift 1, day 1 = shift 2, day 0 = shift 3):
//   Squeeze STATE (the compression is a STATE, not the trigger):
//     SHORT: two consecutive UP-closes  Close[1] > Close[2] > Close[3]
//            AND day-2 range sits predominantly above day-1's close:
//            (High[1] - Close[2]) >= day2_range / 2.
//     LONG : mirror — two consecutive DOWN-closes Close[1] < Close[2] < Close[3]
//            AND (Close[2] - Low[1]) >= day2_range / 2.
//     day2_range = High[1] - Low[1]; require day2_range >= min_range (pips).
//   Trigger EVENT (the single event): price breaks the prior CLOSE-anchored
//     stop level on the NEXT bar. Gapless-safe — the stop level is anchored to
//     the prior CLOSE (Close[1]) and the prior RANGE, never to a real price gap.
//     SHORT: SELLSTOP at Close[1] - entry_range_mult * day2_range.
//     LONG : BUYSTOP  at Close[1] + entry_range_mult * day2_range.
//   Stop loss : SHORT High[1] + sl_range_mult * day2_range (mirror for LONG),
//               capped at sl_cap_pips.
//   Take profit: distance = day2_range projected from the pending entry price.
//   Pending lifecycle: one pending-or-position per magic. The pending order is
//     auto-expired (expiration_seconds) and is also explicitly cancelled if the
//     next closed bar CONTINUES the same-direction close run (squeeze persists →
//     no reversal yet), so a fresh squeeze can re-arm.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// .DWX invariants honoured:
//   - Spread guard fails OPEN (zero modeled spread is tradeable; only a
//     genuinely wide spread blocks), scaled in pips via the pip factor.
//   - No swap gate; no external/macro CSV feed; pure OHLC arithmetic.
//   - Prior-CLOSE-anchored levels (gapless CFD safe), not a real-gap rule.
//   - Thresholds in PIPS via QM_StopRulesPipsToPriceDistance (5-digit/JPY safe).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11421;
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
input double strategy_entry_range_mult  = 1.0;    // SELLSTOP/BUYSTOP offset = mult * day2_range below/above Close[1]
input double strategy_sl_range_mult     = 1.5;    // stop distance = mult * day2_range beyond day-2 high/low
input double strategy_tp_range_mult     = 1.0;    // take-profit distance = mult * day2_range from entry
input double strategy_min_range_pips    = 30.0;   // skip squeeze bars narrower than this (day2_range)
input double strategy_sl_cap_pips       = 80.0;   // hard cap on stop distance (card P2 cap)
input int    strategy_pending_ttl_bars  = 1;      // pending order lives this many D1 bars before auto-expiry
input double strategy_spread_cap_pips   = 25.0;   // skip only a genuinely WIDE spread (fail-open on .DWX zero spread)
input bool   strategy_enable_long       = true;   // mirror LONG squeeze (descending closes); SHORT always on

// -----------------------------------------------------------------------------
// Helpers (pure OHLC geometry — structural reads, // perf-allowed exceptions).
// All reads are at fixed closed-bar shifts; no per-tick lookback loops.
// -----------------------------------------------------------------------------

double SqueezePipFactor()
  {
   // Price distance of one pip on this symbol (5-digit/JPY safe).
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread blocks; zero/negative modeled spread passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double pip = SqueezePipFactor();
   if(pip <= 0.0)
      return false;

   const double cap_price = strategy_spread_cap_pips * pip;
   const double spread = ask - bid;
   if(spread > 0.0 && cap_price > 0.0 && spread > cap_price)
      return true; // genuinely wide spread — block

   return false;
  }

// Build the squeeze pending order. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One open position per magic.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Closed-bar OHLC: day2 = shift 1, day1 = shift 2, day0 = shift 3.
   const double high2  = iHigh(_Symbol, _Period, 1);   // perf-allowed: structural OHLC geometry
   const double low2   = iLow(_Symbol, _Period, 1);    // perf-allowed: structural OHLC geometry
   const double close2 = iClose(_Symbol, _Period, 1);  // perf-allowed: structural OHLC geometry
   const double close1 = iClose(_Symbol, _Period, 2);  // perf-allowed: structural OHLC geometry
   const double close0 = iClose(_Symbol, _Period, 3);  // perf-allowed: structural OHLC geometry
   if(high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0 || close1 <= 0.0 || close0 <= 0.0)
      return false;

   const bool asc_closes  = (close2 > close1 && close1 > close0);
   const bool desc_closes = (close2 < close1 && close1 < close0);

   // Pending-order lifecycle (new-bar gated — this hook only fires on a fresh
   // closed bar). One pending-or-position per magic. If a pending stop is armed
   // and the squeeze CONTINUES (same-direction close run extends → no reversal
   // yet), cancel it so a fresh squeeze can re-arm; otherwise leave it to fill
   // or auto-expire (req.expiration_seconds). Either way, do not stack a second.
   const int total_orders = OrdersTotal();
   for(int i = total_orders - 1; i >= 0; --i)
     {
      const ulong oticket = OrderGetTicket(i);
      if(oticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(otype == ORDER_TYPE_SELL_STOP && asc_closes)
         QM_TM_RemovePendingOrder(oticket, "squeeze_continues_cancel_sellstop");
      else if(otype == ORDER_TYPE_BUY_STOP && desc_closes)
         QM_TM_RemovePendingOrder(oticket, "squeeze_continues_cancel_buystop");
      else
         return false; // a still-valid pending order is armed — do not stack
     }

   const double day2_range = high2 - low2;
   if(day2_range <= 0.0)
      return false;

   const double pip = SqueezePipFactor();
   if(pip <= 0.0)
      return false;

   // Minimum day-2 range filter (avoid very narrow squeeze bars).
   if(day2_range < strategy_min_range_pips * pip)
      return false;

   // Stop-distance cap (in price) from the pips cap.
   const double sl_cap_price = strategy_sl_cap_pips * pip;

   // --- SHORT squeeze: two ascending closes + range predominantly above day-1 close ---
   if(asc_closes && (high2 - close1) >= (day2_range * 0.5))
     {
      const double entry = close2 - strategy_entry_range_mult * day2_range;
      double sl          = high2 + strategy_sl_range_mult * day2_range;
      // Apply the stop-distance cap (relative to the pending entry price).
      if(sl_cap_price > 0.0 && (sl - entry) > sl_cap_price)
         sl = entry + sl_cap_price;
      const double tp = entry - strategy_tp_range_mult * day2_range;

      if(entry <= 0.0 || tp <= 0.0 || sl <= entry)
         return false;
      // Pending stop must sit below current bid to be a valid SELLSTOP.
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0 || entry >= bid)
         return false;

      req.type               = QM_SELL_STOP;
      req.price              = entry;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "squeeze_short_sellstop";
      req.symbol_slot        = qm_magic_slot_offset;   // match the framework magic slot
      req.expiration_seconds = QM_PendingTTLSeconds();
      return true;
     }

   // --- LONG squeeze (mirror): two descending closes + range predominantly below day-1 close ---
   if(strategy_enable_long)
     {
      if(desc_closes && (close1 - low2) >= (day2_range * 0.5))
        {
         const double entry = close2 + strategy_entry_range_mult * day2_range;
         double sl          = low2 - strategy_sl_range_mult * day2_range;
         if(sl_cap_price > 0.0 && (entry - sl) > sl_cap_price)
            sl = entry - sl_cap_price;
         const double tp = entry + strategy_tp_range_mult * day2_range;

         if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || sl >= entry)
            return false;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || entry <= ask)
            return false;

         req.type               = QM_BUY_STOP;
         req.price              = entry;
         req.sl                 = sl;
         req.tp                 = tp;
         req.reason             = "squeeze_long_buystop";
         req.symbol_slot        = qm_magic_slot_offset;   // match the framework magic slot
         req.expiration_seconds = QM_PendingTTLSeconds();
         return true;
        }
     }

   return false;
  }

// No per-tick position management. Pending-order lifecycle (cancel-on-squeeze-
// continuation + one-per-magic) is handled new-bar-gated inside Strategy_Entry-
// Signal; un-triggered pendings auto-expire via req.expiration_seconds. The
// filled position rides its fixed SL/TP. Kept empty to avoid a per-EA new-bar
// gate (forbidden) on the per-tick path.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary position exit — SL/TP (and pending expiry) carry the trade.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// Pending order time-to-live, expressed in seconds for the framework expiration.
// strategy_pending_ttl_bars D1 bars; D1 bar = 86400 s.
int QM_PendingTTLSeconds()
  {
   const int bars = (strategy_pending_ttl_bars > 0) ? strategy_pending_ttl_bars : 1;
   return bars * 86400;
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                             QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                             "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
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
