#property strict
#property version   "5.0"
#property description "QM5_11105 wrb-hg-breach — Wide-Range-Bar Hidden-Gap breach (H4, gapless-CFD safe)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11105 wrb-hg-breach
// -----------------------------------------------------------------------------
// Source: EarnForex "WRB-Hidden-Gap" indicator
//   (https://github.com/EarnForex/WRB-Hidden-Gap), card
//   artifacts/cards_approved/QM5_11105_wrb-hg-breach.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift >= 1, both directions):
//   WRB (Wide Range Bar): the bar at shift `wrb_anchor_shift` has a high-low
//     range strictly WIDER than each of the prior `wrb_lookback` bars. This is
//     the source `WRB_LookBackBarCount=3` comparison, expressed range-based so
//     it is robust on gapless .DWX CFDs.
//   Hidden-Gap (HG) rectangle: the unfilled zone the WRB leaves behind. A
//     bullish WRB (close>open) leaves a bullish rectangle whose breach level is
//     the WRB HIGH; a bearish WRB (close<open) leaves a bearish rectangle whose
//     breach level is the WRB LOW. (NOTE in the build brief: breach uses prior
//     CLOSED bars, NOT a real price gap — .DWX index/FX CFDs are gapless so
//     open[0]==close[1]; a real-gap rule could never fire.)
//   Long entry  : an active bullish HG/WRB rectangle is breached from below —
//     the most recent CLOSED bar closes above the WRB high (source
//     AlertBreachesFromBelow). One position per symbol/magic, first breach only.
//   Short entry : an active bearish HG/WRB rectangle is breached from above —
//     the most recent CLOSED bar closes below the WRB low (AlertBreachesFromAbove).
//   Stop loss   : opposite side of the breached HG rectangle (the WRB's far
//     extreme) plus 0.5*ATR(14) buffer, capped so the stop distance never
//     exceeds 2.5*ATR(14) (card P2 baseline).
//   Exit        : opposite-rectangle breach (a fresh WRB/HG breach in the other
//     direction) OR after `exit_max_bars` (12) closed H4 bars — whichever first.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11105;
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
input int    strategy_wrb_lookback      = 3;     // source WRB_LookBackBarCount: prior bars the WRB must exceed
input int    strategy_wrb_search_bars   = 10;    // how far back to search for the most recent active WRB anchor
input int    strategy_atr_period        = 14;    // ATR period for the SL buffer / cap
input double strategy_sl_buffer_atr     = 0.5;   // SL = opposite rectangle side +/- this*ATR
input double strategy_sl_cap_atr        = 2.5;   // hard cap on stop distance, in ATR multiples
input int    strategy_exit_max_bars     = 12;    // time-stop: close after this many closed bars
input double strategy_spread_pct_of_stop = 15.0; // skip only a genuinely wide spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope state (advanced only on the closed-bar entry path).
// -----------------------------------------------------------------------------
datetime g_entry_bar_time = 0;   // iTime of the bar on which the current position was opened

// -----------------------------------------------------------------------------
// WRB / Hidden-Gap detection helpers
// -----------------------------------------------------------------------------

// Is the bar at `anchor` a Wide Range Bar vs the prior `lookback` bars?
// Range-based (high-low) so it is gapless-CFD robust.
bool WRB_IsWideRangeBar(const int anchor, const int lookback)
  {
   const double hi = iHigh(_Symbol, _Period, anchor);   // perf-allowed: closed-bar structural read
   const double lo = iLow(_Symbol, _Period, anchor);    // perf-allowed
   if(hi <= 0.0 || lo <= 0.0)
      return false;
   const double range = hi - lo;
   if(range <= 0.0)
      return false;
   for(int k = 1; k <= lookback; ++k)
     {
      const double phi = iHigh(_Symbol, _Period, anchor + k); // perf-allowed
      const double plo = iLow(_Symbol, _Period, anchor + k);  // perf-allowed
      if(phi <= 0.0 || plo <= 0.0)
         return false;
      if(!(range > (phi - plo)))
         return false; // must be strictly wider than every prior bar
     }
   return true;
  }

// Find the most recent WRB anchor in [first_anchor .. search_bars+first_anchor].
// Returns the anchor shift via `out_anchor`, the direction via `out_dir`
// (+1 bullish, -1 bearish), and the breach level via `out_breach` (WRB high for
// bullish, WRB low for bearish). Returns false if none found.
bool WRB_FindRecent(const int first_anchor,
                    const int search_bars,
                    const int lookback,
                    int    &out_anchor,
                    int    &out_dir,
                    double &out_breach,
                    double &out_far_side)
  {
   for(int a = first_anchor; a < first_anchor + search_bars; ++a)
     {
      if(!WRB_IsWideRangeBar(a, lookback))
         continue;
      const double o = iOpen(_Symbol, _Period, a);  // perf-allowed
      const double c = iClose(_Symbol, _Period, a);  // perf-allowed
      const double hi = iHigh(_Symbol, _Period, a);  // perf-allowed
      const double lo = iLow(_Symbol, _Period, a);   // perf-allowed
      if(o <= 0.0 || c <= 0.0 || hi <= 0.0 || lo <= 0.0)
         continue;
      if(c > o)
        {
         out_dir      = 1;     // bullish WRB → bullish HG rectangle
         out_breach   = hi;    // breached from below when price closes above the WRB high
         out_far_side = lo;    // opposite (far) side of the rectangle
        }
      else if(c < o)
        {
         out_dir      = -1;    // bearish WRB → bearish HG rectangle
         out_breach   = lo;    // breached from above when price closes below the WRB low
         out_far_side = hi;
        }
      else
         continue;             // doji WRB has no directional HG rectangle
      out_anchor = a;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_cap_atr * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Most recent CLOSED bar = shift 1. The WRB anchor must precede that bar so
   // its rectangle can be breached by the shift-1 close → search anchors >= 2.
   int    anchor   = 0;
   int    dir      = 0;
   double breach   = 0.0;
   double far_side = 0.0;
   if(!WRB_FindRecent(2, strategy_wrb_search_bars, strategy_wrb_lookback,
                      anchor, dir, breach, far_side))
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: breach reference
   if(close1 <= 0.0)
      return false;

   // First-breach gate: the bar BEFORE the breach bar (shift 2) must NOT already
   // have breached the rectangle — so we only trade the FIRST breach.
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
   if(close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   QM_OrderType side;
   if(dir > 0)
     {
      // Bullish HG rectangle breached from below: shift-1 closes above WRB high,
      // shift-2 had not yet (first breach).
      if(!(close1 > breach && close2 <= breach))
         return false;
      side = QM_BUY;
     }
   else
     {
      // Bearish HG rectangle breached from above: shift-1 closes below WRB low,
      // shift-2 had not yet (first breach).
      if(!(close1 < breach && close2 >= breach))
         return false;
      side = QM_SELL;
     }

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Stop = opposite (far) side of the breached rectangle, plus a 0.5*ATR
   // buffer, then capped so |entry - sl| <= sl_cap_atr * ATR.
   const double buffer = strategy_sl_buffer_atr * atr_value;
   double sl;
   if(side == QM_BUY)
      sl = far_side - buffer;     // below the rectangle low
   else
      sl = far_side + buffer;     // above the rectangle high
   if(sl <= 0.0)
      return false;

   // Cap the stop distance at sl_cap_atr * ATR.
   const double cap_distance = strategy_sl_cap_atr * atr_value;
   if(side == QM_BUY)
     {
      const double min_sl = entry - cap_distance;
      if(sl < min_sl)
         sl = min_sl;
      if(!(sl < entry))           // stop must sit below entry for a long
         return false;
     }
   else
     {
      const double max_sl = entry + cap_distance;
      if(sl > max_sl)
         sl = max_sl;
      if(!(sl > entry))           // stop must sit above entry for a short
         return false;
     }

   sl = QM_TM_NormalizePrice(_Symbol, sl);

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — exit via opposite rectangle or time stop
   req.reason = (side == QM_BUY) ? "wrb_hg_breach_long" : "wrb_hg_breach_short";

   // Latch the entry bar time for the time-stop; the open is sent immediately
   // after this returns true on this same closed bar.
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: current bar open time
   return true;
  }

// No active SL/TP management — fixed structural stop, no trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: opposite-rectangle breach OR time stop (exit_max_bars closed bars).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open position's direction for this magic.
   bool   have_pos = false;
   bool   is_long  = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   // --- Time stop: close after exit_max_bars closed bars since entry. ---
   if(g_entry_bar_time > 0)
     {
      const datetime now_bar = iTime(_Symbol, _Period, 0); // perf-allowed
      const long secs_per_bar = (long)PeriodSeconds(_Period);
      if(secs_per_bar > 0)
        {
         const long elapsed_bars = (long)(now_bar - g_entry_bar_time) / secs_per_bar;
         if(elapsed_bars >= (long)strategy_exit_max_bars)
            return true;
        }
     }

   // --- Opposite-rectangle breach: a fresh WRB/HG breach in the other
   //     direction on the most recent closed bar. ---
   int    anchor   = 0;
   int    dir      = 0;
   double breach   = 0.0;
   double far_side = 0.0;
   if(WRB_FindRecent(2, strategy_wrb_search_bars, strategy_wrb_lookback,
                     anchor, dir, breach, far_side))
     {
      const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
      const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
      if(close1 > 0.0 && close2 > 0.0)
        {
         if(is_long && dir < 0 && close1 < breach && close2 >= breach)
            return true; // long open, fresh bearish breach → exit
         if(!is_long && dir > 0 && close1 > breach && close2 <= breach)
            return true; // short open, fresh bullish breach → exit
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
