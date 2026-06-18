#property strict
#property version   "5.0"
#property description "QM5_11865 ema5-15-60-pullback-h1 — Triple EMA(5/15/60) Pullback-to-EMA60 (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11865 ema5-15-60-pullback-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//   2014. source_id 3c77a80c. Card:
//   artifacts/cards_approved/QM5_11865_ema5-15-60-pullback-h1.md
//   (g0_status APPROVED). Sibling of QM5_11671 (same strategy family); this
//   build follows THIS card's parameters (sl 30 / tp 50 pips) and its explicit
//   stack-break invalidation note.
//
// Mechanics (long + short, closed-bar reads at shift 1; H1):
//   Trend STATE (long) : EMA(5) > EMA(15) > EMA(60)  AND  EMA(15) rising
//                        AND EMA(60) rising  (full stack + slope confirmation).
//   Trend STATE (short): mirror — EMA(5) < EMA(15) < EMA(60) AND EMA(15)
//                        falling AND EMA(60) falling.
//   Pullback-resume EVENT (long): within the last pb_lookback closed bars the
//                        price wicked down to TOUCH the EMA(60) (Low <= EMA60),
//                        and the trigger bar then CLOSES back above the EMA(60)
//                        — i.e. the pullback to the slowest EMA was bought and
//                        the trend resumed. Mirror for short (High >= EMA60,
//                        close back below).
//
//   The stack + slope is the STATE; the touch-then-resume is the single trigger
//   EVENT (one event per bar). The touch may be on the trigger bar itself or on
//   a bar within the small lookback window — both are admissible because the
//   distinguishing trigger is the RESUME close, evaluated once on the trigger
//   bar. This deliberately avoids the two-cross-same-bar zero-trade trap: there
//   is exactly ONE event condition (the resume close), never two coincident
//   crossover events.
//
//   Card invalidation note ("If EMA stack breaks during the pullback — EMA5
//   crosses EMA15 — the setup is invalidated; skip the trade"): the full
//   EMA5>EMA15>EMA60 stack is re-evaluated on the trigger (closed) bar, so a
//   broken stack at the resume bar fails the stack_long/stack_short gate and no
//   trade is taken. The setup only fires when the stack is intact at resume.
//
//   Stop Loss  : fixed sl_pips (card: 30 pips), scale-correct via QM helper.
//   Take Profit: fixed tp_pips (card: 50 pips; R:R ~1.67).
//   Exit       : via the fixed SL / TP only (card: no re-entry, no discretionary
//                exit).
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//                modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11865;
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
input int    strategy_ema_fast_period   = 5;      // fastest EMA (stack top)
input int    strategy_ema_mid_period    = 15;     // middle EMA
input int    strategy_ema_slow_period   = 60;     // slowest EMA (pullback target / slope filter)
input int    strategy_pullback_lookback = 4;      // closed bars to look back for the EMA60 touch
input int    strategy_sl_pips           = 30;     // fixed stop loss (pips) — card
input int    strategy_tp_pips           = 50;     // fixed take profit (pips) — card
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

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

   // --- Trigger bar close (shift 1) for the resume-close test ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // ================= LONG =================
   // Stack re-evaluated on the resume bar; a broken stack (EMA5 not above
   // EMA15) at resume invalidates the setup per the card's note.
   const bool stack_long = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool slope_long = (ema_mid > ema_mid_prev && ema_slow > ema_slow_prev);
   if(stack_long && slope_long)
     {
      // Pullback-resume EVENT: a wick touched EMA60 within the lookback window
      // (Low[s] <= EMA60[s]) AND the trigger bar closes back ABOVE EMA60.
      // The resume close is the single trigger; the touch is the prerequisite.
      if(close1 > ema_slow)
        {
         bool touched = false;
         for(int s = 1; s <= strategy_pullback_lookback; ++s)
           {
            const double low_s   = iLow(_Symbol, _Period, s);   // perf-allowed: single closed-bar read
            const double ema60_s = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
            if(low_s <= 0.0 || ema60_s <= 0.0)
               continue;
            if(low_s <= ema60_s)
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
            req.reason = "ema5_15_60_pullback_long";
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
      if(close1 < ema_slow)
        {
         bool touched = false;
         for(int s = 1; s <= strategy_pullback_lookback; ++s)
           {
            const double high_s  = iHigh(_Symbol, _Period, s);  // perf-allowed: single closed-bar read
            const double ema60_s = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
            if(high_s <= 0.0 || ema60_s <= 0.0)
               continue;
            if(high_s >= ema60_s)
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
            req.reason = "ema5_15_60_pullback_short";
            return true;
           }
        }
     }

   return false;
  }

// Fixed SL/TP only; no active management. (Card: exit via 30-pip SL / 50-pip TP.)
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — the fixed SL/TP carry the position. (Card: no re-entry.)
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
