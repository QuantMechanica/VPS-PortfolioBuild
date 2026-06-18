#property strict
#property version   "5.0"
#property description "QM5_11411 wilder-parabolic-sar-reversal-d1 — Wilder Parabolic SAR stop-and-reverse (always-in-market, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11411 wilder-parabolic-sar-reversal-d1
// -----------------------------------------------------------------------------
// Source: J. Welles Wilder Jr., "New Concepts in Technical Trading Systems"
//   (1978), Section II: Parabolic Time/Price System.
// Card: artifacts/cards_approved/QM5_11411_wilder-parabolic-sar-reversal-d1.md
//   (g0_status APPROVED).
//
// Mechanics (always-in-market stop-and-reverse, closed-bar reads):
//   The Parabolic SAR (iSAR / QM_SAR, AF step 0.02, max 0.20) is the single
//   signal. When the SAR crosses to the other side of price, the trend has
//   flipped: close the current position and reverse into the opposite side.
//   The PSAR FLIP is the single EVENT; everything else is STATE.
//
//   Long regime  : SAR below price.       Short regime : SAR above price.
//   Bullish flip : SAR[2] > close[2]  AND  SAR[1] < close[1]   (closed bars)
//   Bearish flip : SAR[2] < close[2]  AND  SAR[1] > close[1]
//
//   Entry        : on a flip, enter in the new flip direction (one EVENT/bar).
//                  Initial bootstrap: if flat and no fresh flip yet, enter in
//                  the side the SAR currently implies so the system is always
//                  in-market (Wilder's defining property).
//   Stop loss    : initial SL = current SAR price; the SAR itself trails the
//                  stop each closed bar (Strategy_ManageOpenPosition re-anchors
//                  SL to the live SAR). No fixed take-profit — the reverse IS
//                  the exit.
//   Exit         : close the open position when a flip AGAINST it fires; the
//                  reverse entry is then opened by Strategy_EntrySignal.
//   Direction    : optional Wilder DI(14) filter (+DI vs -DI). When enabled,
//                  only flips agreeing with the dominant DI are traded.
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// One position per magic. RISK_FIXED in tester, RISK_PERCENT live.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11411;
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
input double strategy_sar_step           = 0.02;   // PSAR acceleration factor start/increment
input double strategy_sar_max            = 0.20;   // PSAR acceleration factor maximum
input bool   strategy_use_di_filter      = false;  // optional Wilder DI(14) direction filter
input int    strategy_di_period          = 14;     // ADX/DI period for the optional filter
input double strategy_max_sl_pips        = 100.0;  // initial-stop cap (D1 bars; card P2 cap)
input bool   strategy_bootstrap_inmarket = true;   // seed first position from current SAR side
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal helpers — SAR-vs-price regime + flip detection (closed-bar reads).
// -----------------------------------------------------------------------------

// +1 = SAR below price (long regime), -1 = SAR above price (short regime),
// 0 = indeterminate (no data). Reads the closed bar at `shift`.
int Sar_Regime(const int shift)
  {
   const double sar   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, shift);
   const double close = iClose(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
   if(sar <= 0.0 || close <= 0.0)
      return 0;
   if(sar < close)
      return +1;
   if(sar > close)
      return -1;
   return 0;
  }

// Detect a flip on the just-closed bar. Returns +1 for a bullish flip
// (short->long), -1 for a bearish flip (long->short), 0 for no flip.
int Sar_Flip()
  {
   const int prev = Sar_Regime(2);
   const int now  = Sar_Regime(1);
   if(prev == 0 || now == 0)
      return 0;
   if(prev < 0 && now > 0)
      return +1; // bullish flip
   if(prev > 0 && now < 0)
      return -1; // bearish flip
   return 0;
  }

// Optional Wilder DI(14) directional filter. Returns true if a trade in
// `dir` (+1 long / -1 short) is permitted. Disabled -> always permitted.
bool Di_Allows(const int dir)
  {
   if(!strategy_use_di_filter)
      return true;
   const double plus  = QM_ADX_PlusDI(_Symbol, _Period, strategy_di_period, 1);
   const double minus = QM_ADX_MinusDI(_Symbol, _Period, strategy_di_period, 1);
   if(plus <= 0.0 && minus <= 0.0)
      return true; // no DI data yet — do not block
   if(dir > 0)
      return (plus > minus);
   if(dir < 0)
      return (minus > plus);
   return false;
  }

// Direction (+1/-1) of the currently open position for this EA's magic,
// or 0 if flat.
int Open_Direction()
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
      const long ptype = PositionGetInteger(POSITION_TYPE);
      return (ptype == POSITION_TYPE_BUY) ? +1 : -1;
     }
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop-distance reference: distance from ask to the current SAR.
   const double sar = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar <= 0.0)
      return false; // no SAR yet — defer to the entry gate, do not block here

   double stop_distance = MathAbs(ask - sar);
   if(stop_distance <= 0.0)
     {
      // Fall back to the pip cap so the spread test still scales.
      stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_max_sl_pips);
      if(stop_distance <= 0.0)
         return false;
     }

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Always-in-market entry. Caller guarantees QM_IsNewBar() == true.
// Fires on a fresh SAR flip in the new direction; bootstraps an initial
// position from the current SAR side when flat (Wilder is never out-of-market).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic. If a position is open, the reverse
   // exit (Strategy_ExitSignal) must close it first before we re-enter.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   int dir = Sar_Flip(); // +1 bullish flip, -1 bearish flip, 0 none

   // Bootstrap: when flat and no fresh flip, take the side the SAR currently
   // implies so the system is always in-market (the defining Wilder property).
   if(dir == 0 && strategy_bootstrap_inmarket)
      dir = Sar_Regime(1);

   if(dir == 0)
      return false;

   if(!Di_Allows(dir))
      return false;

   const double sar = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar <= 0.0)
      return false;

   const QM_OrderType otype = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Initial stop = SAR price, capped at strategy_max_sl_pips from entry.
   double sl = QM_TM_NormalizePrice(_Symbol, sar);
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_max_sl_pips);
   if(cap_dist > 0.0)
     {
      if(dir > 0)
        {
         const double floor_sl = entry - cap_dist; // deepest allowed long stop
         if(sl < floor_sl)
            sl = floor_sl;
         if(sl >= entry)                            // SAR not yet below entry
            sl = entry - cap_dist;
        }
      else
        {
         const double ceil_sl = entry + cap_dist;   // deepest allowed short stop
         if(sl > ceil_sl)
            sl = ceil_sl;
         if(sl <= entry)                            // SAR not yet above entry
            sl = entry + cap_dist;
        }
     }
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target — the reverse IS the exit
   req.reason = (dir > 0) ? "sar_flip_long" : "sar_flip_short";
   return true;
  }

// Trail the stop with the SAR each closed bar: re-anchor SL to the live SAR
// in the favorable direction only (the SAR is monotone within a trend leg).
void Strategy_ManageOpenPosition()
  {
   if(!QM_IsNewBarLatched())
      return; // only re-anchor once per closed bar, not per tick

   const int magic = QM_FrameworkMagic();
   const double sar = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype   = PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);
      const double new_sl = QM_TM_NormalizePrice(_Symbol, sar);
      if(new_sl <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         // Long: SAR is below price and rises; only move the stop UP.
         if(new_sl > cur_sl && new_sl < PositionGetDouble(POSITION_PRICE_CURRENT))
            QM_TM_MoveSL(ticket, new_sl, "sar_trail_long");
        }
      else
        {
         // Short: SAR is above price and falls; only move the stop DOWN.
         if((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > PositionGetDouble(POSITION_PRICE_CURRENT))
            QM_TM_MoveSL(ticket, new_sl, "sar_trail_short");
        }
     }
  }

// Reverse exit: close the open position when a SAR flip fires AGAINST it.
// The opposite-direction entry is then opened by Strategy_EntrySignal on the
// same closed bar (always-in-market reverse).
bool Strategy_ExitSignal()
  {
   const int open_dir = Open_Direction();
   if(open_dir == 0)
      return false;

   const int flip = Sar_Flip();
   if(flip == 0)
      return false;

   // Close only when the flip opposes the current position.
   return (flip == -open_dir);
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
