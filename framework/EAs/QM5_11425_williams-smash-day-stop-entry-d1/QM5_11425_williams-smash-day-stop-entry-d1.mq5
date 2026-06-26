#property strict
#property version   "5.0"
#property description "QM5_11425 williams-smash-day-stop-entry-d1 — Larry Williams Smash Day reversal stop entry (FX, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11425 williams-smash-day-stop-entry-d1
// -----------------------------------------------------------------------------
// Source: Larry Williams, "Inner Circle Workshop Trading Method".
// Card: artifacts/cards_approved/QM5_11425_williams-smash-day-stop-entry-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, deterministic OHLC candle geometry, closed-bar reads only):
//   The "Smash Day" is a SINGLE completed-bar EVENT measured on the prior closed
//   bar (shift 1) relative to the bar before it (shift 2). Two mirror cases:
//
//   Buy smash (bearish body inside a bullish range-expansion bar):
//     High[1] > High[2] AND Low[1] > Low[2] AND Close[1] > Close[2]
//     AND (Open[1] - Close[1]) >= body_ratio * (High[1] - Low[1])   (bearish body)
//     -> arm a BUY STOP at High[1] + 1 pip for the next D1 bar.
//        SL = Low[1] - 1 pip ; TP = entry + tp_rr * risk.
//
//   Sell smash (bullish body inside a bearish range-expansion bar):
//     Low[1] < Low[2] AND High[1] < High[2] AND Close[1] < Close[2]
//     AND (Close[1] - Open[1]) >= body_ratio * (High[1] - Low[1])   (bullish body)
//     -> arm a SELL STOP at Low[1] - 1 pip for the next D1 bar.
//        SL = High[1] + 1 pip ; TP = entry - tp_rr * risk.
//
//   All four geometry comparisons reference values WITHIN the two prior CLOSED
//   bars (prior high/low/close/open) — no cross-bar gap dependency, so the rule
//   is gapless-safe on .DWX CFDs (open[0]==close[1] does not affect it).
//
//   Entry timing : place the stop order at the open of the next D1 bar; it is a
//                  DAY-ONLY order — expires after one D1 window if unfilled
//                  ("cancel if not filled by end of bar[0]").
//   Re-evaluation: each new closed D1 bar cancels any stale pending order owned
//                  by this magic before re-detecting the pattern, so a fresh
//                  smash always replaces the previous unfilled level.
//   Stop loss    : the opposite extreme of bar[1] +/- 1 pip, but capped at
//                  sl_cap_pips (card P2 cap = 80 pips) measured from entry.
//   Take profit  : tp_rr (2.0) multiple of the entry->SL risk distance.
//   Min bar range: skip degenerate small smash bars (range[1] >= min_range_pips).
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// One position per magic; one pending order at a time. Only the 5 Strategy_*
// hooks + Strategy inputs are EA-specific — the rest is framework wiring.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11425;
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
input double strategy_body_ratio        = 0.33;   // min body size as fraction of bar range (Smash threshold)
input int    strategy_entry_buffer_pips = 1;      // stop-entry offset beyond prior H/L, in pips
input int    strategy_sl_cap_pips       = 80;     // max stop distance from entry (card P2 cap), in pips
input double strategy_tp_rr             = 2.0;    // take profit = this multiple of entry->SL risk
input int    strategy_min_range_pips    = 15;     // skip degenerate small smash bars (bar[1] range)
input int    strategy_spread_cap_pips   = 25;     // skip only if modeled spread exceeds this pip cap

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Remove any live pending order owned by this EA's magic on this symbol.
void CancelOwnPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      QM_TM_RemovePendingOrder(ticket, "smash_day_reeval_cancel");
     }
  }

// True if this EA's magic already has a live pending order on this symbol.
bool HasOwnPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; pattern detection is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Smash-day detection + pending stop-order placement. Caller guarantees
// QM_IsNewBar()==true, so this fires once per closed D1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Each new closed bar: cancel any stale pending level from the prior bar
   // ("cancel if not filled by end of the day"). A fresh smash replaces it.
   CancelOwnPendingOrders();

   // One position per symbol/magic — if filled, leave it to its SL/TP.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Defensive: never stack pending orders (cancel above should have cleared it).
   if(HasOwnPendingOrder())
      return false;

   // --- Prior two completed D1 bars (shift 1 = signal bar, shift 2 = ref) ---
   const double high1  = iHigh(_Symbol, _Period, 1);   // perf-allowed: closed-bar OHLC
   const double low1   = iLow(_Symbol, _Period, 1);    // perf-allowed: closed-bar OHLC
   const double open1  = iOpen(_Symbol, _Period, 1);   // perf-allowed: closed-bar OHLC
   const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: closed-bar OHLC
   const double high2  = iHigh(_Symbol, _Period, 2);   // perf-allowed: closed-bar OHLC
   const double low2   = iLow(_Symbol, _Period, 2);    // perf-allowed: closed-bar OHLC
   const double close2 = iClose(_Symbol, _Period, 2);  // perf-allowed: closed-bar OHLC
   if(high1 <= 0.0 || low1 <= 0.0 || open1 <= 0.0 || close1 <= 0.0 ||
      high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0)
      return false;

   const double range1 = high1 - low1;
   if(range1 <= 0.0)
      return false;

   // Min-range filter: skip degenerate small smash bars.
   const double min_range = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_range_pips);
   if(min_range > 0.0 && range1 < min_range)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_buffer_pips);
   if(buffer <= 0.0)
      return false;

   const double body_thresh = strategy_body_ratio * range1;

   QM_OrderType otype;
   double pending_price = 0.0;
   double sl            = 0.0;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   // --- Buy smash: bullish range-expansion bar with a bearish body ---
   const bool buy_expansion = (high1 > high2 && low1 > low2 && close1 > close2);
   const bool buy_body      = ((open1 - close1) >= body_thresh);
   // --- Sell smash: bearish range-expansion bar with a bullish body ---
   const bool sell_expansion = (low1 < low2 && high1 < high2 && close1 < close2);
   const bool sell_body      = ((close1 - open1) >= body_thresh);

   if(buy_expansion && buy_body)
     {
      otype = QM_BUY_STOP;
      pending_price = high1 + buffer;
      // Stop entry must sit strictly above current ask to be a valid buy stop.
      if(pending_price <= ask)
         return false;
      sl = low1 - buffer;            // pattern stop: below the smash-bar low
      // Cap the stop distance from entry at sl_cap_pips.
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
      if(cap > 0.0 && (pending_price - sl) > cap)
         sl = pending_price - cap;
      if(sl >= pending_price)
         return false;
     }
   else if(sell_expansion && sell_body)
     {
      otype = QM_SELL_STOP;
      pending_price = low1 - buffer;
      // Stop entry must sit strictly below current bid to be a valid sell stop.
      if(pending_price >= bid)
         return false;
      sl = high1 + buffer;           // pattern stop: above the smash-bar high
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
      if(cap > 0.0 && (sl - pending_price) > cap)
         sl = pending_price + cap;
      if(sl <= pending_price)
         return false;
     }
   else
     {
      return false; // no smash pattern on the prior closed bar
     }

   pending_price = QM_TM_NormalizePrice(_Symbol, pending_price);
   sl            = QM_TM_NormalizePrice(_Symbol, sl);
   if(pending_price <= 0.0 || sl <= 0.0)
      return false;

   // TP = tp_rr multiple of the entry->SL risk distance, from the pending price.
   const double tp = QM_TakeRR(_Symbol, otype, pending_price, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type               = otype;
   req.price              = pending_price; // pending stop-entry level
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = (otype == QM_BUY_STOP) ? "smash_day_buystop" : "smash_day_sellstop";
   req.symbol_slot        = qm_magic_slot_offset;
   // Day-only order: expires after one D1 window if unfilled.
   req.expiration_seconds = 86400;
   return true;
  }

// No active trade management beyond the fixed pattern SL and 2R TP (card uses a
// fixed-target exit; the 3-bar trailing stop is an explicit P3 alternative).
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP. A fresh opposite smash is handled by the
// per-bar pending-cancel + one-position guard, not by flipping an open trade.
bool Strategy_ExitSignal()
  {
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
