#property strict
#property version   "5.0"
#property description "QM5_11791 carter-h1-s6-ema51560-pullback-h1 — Triple EMA(5/15/60) Trend Pullback, EMA15 resume (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11791 carter-h1-s6-ema51560-pullback-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)"
//   (Scribd, ~2014), Strategy S6. source_id 529382f8.
// Card: artifacts/cards_approved/QM5_11791_carter-h1-s6-ema51560-pullback-h1.md
//   (g0_status APPROVED).
//
// Sibling of QM5_11671 (same Carter S6 family). This card differs in the RESUME
// trigger: the card's Implementation Notes specify the bounce confirmation as a
// close back above the EMA(15) (not above EMA(60) as in 11671):
//   Pullback detection (long): Low[1] <= ema60[1]*1.001 AND Close[1] > ema15[1].
//   "entry when price re-crosses above EMA15 from below after touching EMA60 zone"
//
// Mechanics (long + short, closed-bar reads at shift 1; H1):
//   Trend STATE (long) : EMA(5) > EMA(15) > EMA(60)  AND  EMA(15) rising
//                        AND EMA(60) rising (full stack + slope confirmation).
//   Trend STATE (short): mirror — EMA(5) < EMA(15) < EMA(60) AND EMA(15)
//                        falling AND EMA(60) falling.
//   Pullback-resume EVENT (long): within the last pb_lookback closed bars price
//                        wicked down INTO the EMA(60) zone (Low <= EMA60*(1+tol)),
//                        and the trigger bar then re-crosses UP through EMA(15)
//                        (close[2] <= EMA15[2]  AND  close[1] > EMA15[1]) — the
//                        pullback was bought and the trend resumed. Mirror short.
//
//   The stack + slope is the STATE; the EMA15 re-cross close is the single
//   trigger EVENT (one event per bar). The EMA60-zone touch is a prerequisite
//   STATE observed within the lookback, NOT a second coincident event. This
//   deliberately avoids the two-cross-same-bar zero-trade trap: there is exactly
//   ONE event condition (the EMA15 resume cross), never two coincident crosses.
//
//   Stop Loss  : fixed sl_pips (card: 30 pips), scale-correct via QM helper.
//   Take Profit: fixed tp_pips (card: 50 pips).
//   Defensive exit: EMA(5)/EMA(15) cross against the position (card: "Also exit
//                   on EMA(5)/(15) crossover against position").
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//                modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11791;
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
input int    strategy_ema_fast_period    = 5;      // fastest EMA (stack top / cross exit)
input int    strategy_ema_mid_period     = 15;     // middle EMA (pullback resume target)
input int    strategy_ema_slow_period    = 60;     // slowest EMA (pullback zone / slope filter)
input int    strategy_pullback_lookback  = 4;      // closed bars to look back for the EMA60-zone touch
input double strategy_ema60_zone_pct      = 0.1;   // EMA60 touch tolerance, in percent (card: *1.001)
input int    strategy_sl_pips            = 30;     // fixed stop loss (pips)
input int    strategy_tp_pips            = 50;     // fixed take profit (pips)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — trend/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference for the spread cap (scale-correct pips->price).
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long + short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA stack values at the trigger (closed) bar, shift 1 ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   // --- Slope confirmation: mid + slow EMA at shift 2 for the slope sign ---
   const double ema_mid_prev  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 2);
   const double ema_slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_mid_prev <= 0.0 || ema_slow_prev <= 0.0)
      return false;

   // --- Resume-cross prerequisite: EMA(15) at shift 2 (the bar BEFORE trigger) ---
   const double ema_mid_at2 = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 2);
   if(ema_mid_at2 <= 0.0)
      return false;

   // --- Trigger + prior bar closes (shift 1 / shift 2) for the resume cross ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double zone = strategy_ema60_zone_pct / 100.0; // e.g. 0.1% -> 0.001 (card *1.001)

   // ================= LONG =================
   const bool stack_long = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool slope_long = (ema_mid > ema_mid_prev && ema_slow > ema_slow_prev);
   if(stack_long && slope_long)
     {
      // Pullback-resume EVENT: a wick touched the EMA60 zone within the lookback
      // (Low[s] <= EMA60[s]*(1+zone)) AND the trigger bar re-crosses UP through
      // EMA15 (close[2] <= EMA15[2] AND close[1] > EMA15[1]). The EMA15 re-cross
      // is the SINGLE trigger event; the touch is the prerequisite state.
      const bool resume_cross_up = (close2 <= ema_mid_at2 && close1 > ema_mid);
      if(resume_cross_up)
        {
         bool touched = false;
         for(int s = 1; s <= strategy_pullback_lookback; ++s)
           {
            const double low_s   = iLow(_Symbol, _Period, s);   // perf-allowed: single closed-bar read
            const double ema60_s = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
            if(low_s <= 0.0 || ema60_s <= 0.0)
               continue;
            if(low_s <= ema60_s * (1.0 + zone))
              {
               touched = true;
               break;
              }
           }
         if(touched)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(entry <= 0.0)
               return false;
            const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
            const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
            if(sl <= 0.0 || tp <= 0.0)
               return false;
            req.type   = QM_BUY;
            req.price  = 0.0;   // framework fills market price at send
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "triple_ema_pullback_ema15_long";
            return true;
           }
        }
      return false;
     }

   // ================= SHORT =================
   const bool stack_short = (ema_fast < ema_mid && ema_mid < ema_slow);
   const bool slope_short = (ema_mid < ema_mid_prev && ema_slow < ema_slow_prev);
   if(stack_short && slope_short)
     {
      // Mirror: touch EMA60 zone from above (High[s] >= EMA60[s]*(1-zone)) AND
      // the trigger bar re-crosses DOWN through EMA15 (close[2] >= EMA15[2] AND
      // close[1] < EMA15[1]).
      const bool resume_cross_down = (close2 >= ema_mid_at2 && close1 < ema_mid);
      if(resume_cross_down)
        {
         bool touched = false;
         for(int s = 1; s <= strategy_pullback_lookback; ++s)
           {
            const double high_s  = iHigh(_Symbol, _Period, s);  // perf-allowed: single closed-bar read
            const double ema60_s = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
            if(high_s <= 0.0 || ema60_s <= 0.0)
               continue;
            if(high_s >= ema60_s * (1.0 - zone))
              {
               touched = true;
               break;
              }
           }
         if(touched)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(entry <= 0.0)
               return false;
            const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
            const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
            if(sl <= 0.0 || tp <= 0.0)
               return false;
            req.type   = QM_SELL;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "triple_ema_pullback_ema15_short";
            return true;
           }
        }
     }

   return false;
  }

// Fixed SL/TP carry the position; the defensive cross exit lives in
// Strategy_ExitSignal. No active SL/TP management.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: EMA(5)/EMA(15) cross AGAINST the open position (card: "Also
// exit on EMA(5)/(15) crossover against position"). One event at shift 1.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double mid_now   = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double mid_prev  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 2);
   if(fast_now <= 0.0 || mid_now <= 0.0 || fast_prev <= 0.0 || mid_prev <= 0.0)
      return false;

   // Determine the open position's direction for this magic.
   const int magic = QM_FrameworkMagic();
   bool have_long = false, have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  have_long  = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }

   // Long held -> exit on EMA5 crossing DOWN through EMA15.
   if(have_long)
     {
      const bool cross_down = (fast_prev >= mid_prev && fast_now < mid_now);
      if(cross_down)
         return true;
     }
   // Short held -> exit on EMA5 crossing UP through EMA15.
   if(have_short)
     {
      const bool cross_up = (fast_prev <= mid_prev && fast_now > mid_now);
      if(cross_up)
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
