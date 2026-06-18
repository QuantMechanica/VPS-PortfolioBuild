#property strict
#property version   "5.0"
#property description "QM5_11468 nekritin-peters-last-kiss-d1h4 — Naked Forex 'Last Kiss' box-breakout retouch (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11468 nekritin-peters-last-kiss-d1h4
// -----------------------------------------------------------------------------
// Source: Alex Nekritin & Walter Peters PhD, "Naked Forex" Ch5 (Wiley, 2012).
// Card: artifacts/cards_approved/QM5_11468_nekritin-peters-last-kiss-d1h4.md
//       (g0_status APPROVED).
//
// Mechanics ("The Last Kiss" — all reads on CLOSED D1 bars, shift >= 1):
//   1. CONSOLIDATION BOX (state): over a rolling window of the last
//      box_bars closed bars (excluding the most recent few used for the
//      breakout/retouch), the highest high (box_high) and lowest low
//      (box_low) define a range. The box is valid only if its width is
//      within [box_min_pips, box_max_pips]. This bounds the structure.
//   2. BREAKOUT (state, latched): the first bar AFTER the box window that
//      closes beyond a box edge — bullish if close > box_high, bearish if
//      close < box_low. We scan the retouch window for that escape bar.
//   3. RETOUCH + REJECTION (the single trigger EVENT): the most recent
//      CLOSED bar (shift 1) returns to "kiss" the broken edge from the
//      breakout side and rejects in the breakout direction:
//        LONG : low[1] <= box_high + zone_buffer  AND  close[1] > open[1]
//               AND close[1] > box_high   (closed back above = still broken out)
//        SHORT: high[1] >= box_low  - zone_buffer AND  close[1] < open[1]
//               AND close[1] < box_low
//      Only shift-1 can be the trigger, so the EVENT fires on exactly one
//      bar — this avoids the two-cross-same-bar zero-trade trap (box +
//      breakout are STATES observed over earlier bars; the kiss is the EVENT).
//   Stop  : midpoint of the box (box_high + box_low)/2, capped at sl_cap_pips.
//   Take  : next swing extreme beyond the box on the trade-direction side
//           (iHighest/iLowest); fallback = box_height * tp_box_mult from entry.
//   Exit  : closed bar prints back INSIDE the box (invalidation) OR
//           time-stop after time_stop_bars closed bars in the trade.
//
// .DWX invariants honoured: spread guard fails OPEN on zero modeled spread;
// no swap gate; QM_IsNewBar consumed exactly ONCE per tick (in the framework
// OnTick); all pip thresholds scaled via QM_StopRulesPipsToPriceDistance.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11468;
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
input int    strategy_box_bars          = 10;    // consolidation window length (closed bars)
input int    strategy_box_min_pips      = 30;    // min box width (card: >= 30 pips)
input int    strategy_box_max_pips      = 120;   // max box width (P3 sweep 50/80/120)
input int    strategy_zone_buffer_pips  = 10;    // retouch proximity to broken edge (5/10/15)
input int    strategy_retouch_window    = 10;    // bars after box to find breakout+retouch
input int    strategy_sl_cap_pips       = 120;   // skip if box-midpoint stop > this
input int    strategy_tp_swing_lookback = 30;    // swing lookback for the TP zone
input double strategy_tp_box_mult       = 1.5;   // fallback TP = box_height * mult from entry
input int    strategy_time_stop_bars    = 20;    // exit at market after N closed bars in trade
input double strategy_spread_cap_pips   = 25.0;  // genuine-spread cap (25 pips per card)

// -----------------------------------------------------------------------------
// File-scope state (advanced only on new closed bars / position open)
// -----------------------------------------------------------------------------
datetime g_entry_bar_time = 0;   // open-time of the bar on which we entered

// -----------------------------------------------------------------------------
// Helpers (all structural OHLC math — closed bars only, D1 cadence)
// -----------------------------------------------------------------------------

double LK_PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// Scan for the most recent valid Last-Kiss setup ending at the trigger bar
// (shift 1). Returns +1 (long), -1 (short), 0 (none). On a hit, fills
// out_box_high/out_box_low/out_entry_ref. The "entry_ref" is the rejection
// candle's extreme used for the stop-order/structure reference.
int LK_DetectSetup(double &out_box_high, double &out_box_low)
  {
   out_box_high = 0.0;
   out_box_low  = 0.0;

   const double zone   = LK_PipDistance(strategy_zone_buffer_pips);
   const double minw   = LK_PipDistance(strategy_box_min_pips);
   const double maxw   = LK_PipDistance(strategy_box_max_pips);
   if(minw <= 0.0 || maxw <= 0.0)
      return 0;

   // The trigger (retouch+rejection) bar is always shift 1.
   const double rej_open  = iOpen(_Symbol, _Period, 1);   // perf-allowed: structural OHLC, D1 closed bar
   const double rej_close = iClose(_Symbol, _Period, 1);  // perf-allowed
   const double rej_high  = iHigh(_Symbol, _Period, 1);   // perf-allowed
   const double rej_low   = iLow(_Symbol, _Period, 1);    // perf-allowed
   if(rej_open <= 0.0 || rej_close <= 0.0 || rej_high <= 0.0 || rej_low <= 0.0)
      return 0;

   // Search: place the box window strictly BEFORE the breakout/retouch zone.
   // breakout_shift ranges over [2 .. retouch_window+1]; the box is the
   // box_bars closed bars immediately older than the breakout bar.
   for(int brk = 2; brk <= strategy_retouch_window + 1; ++brk)
     {
      const int box_first = brk + 1;                       // newest box bar (older than breakout)
      const int box_last  = brk + strategy_box_bars;       // oldest box bar
      if(box_last >= Bars(_Symbol, _Period) - 1)
         break;                                            // not enough history

      // Build the box extremes over [box_first .. box_last].
      double bh = -1.0, bl = 1.0e18;
      for(int s = box_first; s <= box_last; ++s)
        {
         const double h = iHigh(_Symbol, _Period, s);      // perf-allowed: structural OHLC
         const double l = iLow(_Symbol, _Period, s);       // perf-allowed
         if(h <= 0.0 || l <= 0.0)
           { bh = -1.0; break; }
         if(h > bh) bh = h;
         if(l < bl) bl = l;
        }
      if(bh <= 0.0 || bl >= 1.0e18 || bh <= bl)
         continue;

      const double width = bh - bl;
      if(width < minw || width > maxw)
         continue;

      // Breakout bar = `brk`: must have CLOSED beyond a box edge.
      const double brk_close = iClose(_Symbol, _Period, brk); // perf-allowed
      if(brk_close <= 0.0)
         continue;

      // --- LONG: bullish breakout above the box, then a kiss-and-reject ---
      if(brk_close > bh)
        {
         const bool retouch  = (rej_low <= bh + zone);      // came back to the broken edge
         const bool rejectup = (rej_close > rej_open);      // bullish rejection candle
         const bool stillout = (rej_close > bh);            // closed back above broken edge
         if(retouch && rejectup && stillout)
           {
            out_box_high = bh;
            out_box_low  = bl;
            return +1;
           }
        }

      // --- SHORT: bearish breakout below the box, then a kiss-and-reject ---
      if(brk_close < bl)
        {
         const bool retouch  = (rej_high >= bl - zone);
         const bool rejectdn = (rej_close < rej_open);
         const bool stillout = (rej_close < bl);
         if(retouch && rejectdn && stillout)
           {
            out_box_high = bh;
            out_box_low  = bl;
            return -1;
           }
        }
     }

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing quote

   const double cap = LK_PipDistance((int)strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double box_high = 0.0, box_low = 0.0;
   const int dir = LK_DetectSetup(box_high, box_low);
   if(dir == 0)
      return false;

   const double box_mid    = (box_high + box_low) / 2.0;
   const double box_height = box_high - box_low;
   if(box_height <= 0.0)
      return false;

   if(dir > 0)
     {
      // LONG. Entry at market on the confirmed retouch-rejection close.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // Stop = box midpoint; must be below entry and within the cap.
      double sl = box_mid;
      if(sl >= entry)
         return false;
      const double sl_dist = entry - sl;
      if(sl_dist > LK_PipDistance(strategy_sl_cap_pips))
         return false;

      // TP = next swing high beyond the box on the upside; fallback = box*mult.
      double tp = 0.0;
      const int hi_shift = iHighest(_Symbol, _Period, MODE_HIGH,
                                    strategy_tp_swing_lookback,
                                    strategy_retouch_window + 1); // perf-allowed: structural
      if(hi_shift >= 0)
        {
         const double swing_hi = iHigh(_Symbol, _Period, hi_shift); // perf-allowed
         if(swing_hi > entry)
            tp = swing_hi;
        }
      if(tp <= entry)
         tp = entry + box_height * strategy_tp_box_mult;
      if(tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "last_kiss_long";
      g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: latch entry bar
      return true;
     }
   else
     {
      // SHORT.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = box_mid;
      if(sl <= entry)
         return false;
      const double sl_dist = sl - entry;
      if(sl_dist > LK_PipDistance(strategy_sl_cap_pips))
         return false;

      double tp = 0.0;
      const int lo_shift = iLowest(_Symbol, _Period, MODE_LOW,
                                   strategy_tp_swing_lookback,
                                   strategy_retouch_window + 1); // perf-allowed
      if(lo_shift >= 0)
        {
         const double swing_lo = iLow(_Symbol, _Period, lo_shift); // perf-allowed
         if(swing_lo > 0.0 && swing_lo < entry)
            tp = swing_lo;
        }
      if(tp <= 0.0 || tp >= entry)
         tp = entry - box_height * strategy_tp_box_mult;
      if(tp <= 0.0 || tp >= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "last_kiss_short";
      g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: latch entry bar
      return true;
     }
  }

// No active trade management beyond the fixed stop/target; exits are handled
// in Strategy_ExitSignal (box re-entry invalidation + time stop).
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: closed bar prints back INSIDE the box (invalidation) or
// the trade exceeded the time-stop. Re-derive the active box from the position
// direction by reusing the SL (box midpoint) is not reliable, so we use the
// simpler invalidation: a closed bar back inside the box region relative to the
// position. We approximate "inside the box" using the entry-direction SL line
// (box midpoint): a CLOSE crossing back past the midpoint is the invalidation.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Locate this EA's open position to read direction.
   bool   is_long = false;
   bool   found   = false;
   double pos_sl  = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      pos_sl  = PositionGetDouble(POSITION_SL);
      found   = true;
      break;
     }
   if(!found)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar invalidation read
   if(close1 <= 0.0)
      return false;

   // Box-midpoint invalidation: the SL was set to the box midpoint at entry.
   // A closed bar back past the midpoint (into the box) invalidates the kiss.
   if(pos_sl > 0.0)
     {
      if(is_long && close1 < pos_sl)
         return true;   // long: closed back below box midpoint
      if(!is_long && close1 > pos_sl)
         return true;   // short: closed back above box midpoint
     }

   // Time stop: count closed bars since entry.
   if(g_entry_bar_time > 0 && strategy_time_stop_bars > 0)
     {
      const datetime now_bar = iTime(_Symbol, _Period, 0); // perf-allowed: bar-open time
      if(now_bar > g_entry_bar_time)
        {
         const int bars_held = Bars(_Symbol, _Period,
                                    g_entry_bar_time, now_bar) - 1;
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
         g_entry_bar_time = 0;
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
