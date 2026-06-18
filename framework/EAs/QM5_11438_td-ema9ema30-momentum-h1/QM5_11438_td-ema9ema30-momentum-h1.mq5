#property strict
#property version   "5.0"
#property description "QM5_11438 td-ema9ema30-momentum-h1 — EMA(9/30) cross + Momentum(10) + 3-bar swing break (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11438 td-ema9ema30-momentum-h1
// -----------------------------------------------------------------------------
// Source: DayTradeForex.com "9 Profitable Trading Systems" (System #6).
//   Card: artifacts/cards_approved/QM5_11438_td-ema9ema30-momentum-h1.md
//   (g0_status APPROVED, source_id fb2ae527-c7ef-5765-a09d-9eb8157e55a0).
//
// Mechanics (all reads on CLOSED bars, shift >= 1):
//   TRIGGER EVENT (one event/bar): EMA(9) crosses EMA(30).
//       LONG  : EMA9 was <= EMA30 at shift 2 AND > EMA30 at shift 1.
//       SHORT : EMA9 was >= EMA30 at shift 2 AND < EMA30 at shift 1.
//   STATE 1 (momentum): Momentum(10) at shift 1.  > 100 confirms LONG,
//                       < 100 confirms SHORT (100 = zero-change baseline).
//   STATE 2 (TD trend-line break approximation, per card): the last closed bar
//       breaks a recent 3-bar swing —
//       LONG : High[1] > High[2] AND High[1] > High[3]  (break above resistance)
//       SHORT: Low[1]  < Low[2]  AND Low[1]  < Low[3]    (break below support)
//       This is the card's explicit deterministic, bounded, closed-bar
//       approximation of a TD trend-line break (Mechanik / Implementation Notes).
//
//   Avoiding the two-cross-same-bar zero-trade trap: the EMA cross is the SOLE
//   event. Momentum and the swing break are STATES sampled on the same closed
//   bar; they are not required to cross/occur freshly on the trigger bar.
//
//   The card specifies a BUYSTOP at High[1]+1pip valid for bar[0] only. The V5
//   single-position framework enters at MARKET on the new-bar gate; because the
//   trigger bar already closed ABOVE the 3-bar swing high (state 2), market
//   entry on the next bar's open is the deterministic, gapless-.DWX-safe
//   realisation of "trade the break" (open[0]==close[1] on .DWX CFDs). Flagged
//   in open_questions.
//
//   Stop          : fixed `strategy_sl_pips` pips from entry (card: 40 pips,
//                   P2 cap 50).
//   Take profit   : ATR(strategy_atr_period) x `strategy_tp_atr_mult` from entry
//                   (card: ATR(14) x 2.0 primary target).
//   Exit          : EMA9 crosses back below EMA30 (long) / above (short) —
//                   trend-reversal exit (card Exit section).
//   Spread guard  : fail-OPEN on .DWX zero modeled spread; block only a
//                   genuinely wide spread > strategy_max_spread_pips.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11438;
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
input int    strategy_ema_fast_period   = 9;      // fast EMA (cross signal)
input int    strategy_ema_slow_period   = 30;     // slow EMA (cross signal)
input int    strategy_mom_period        = 10;     // Momentum period; baseline 100
input double strategy_mom_baseline      = 100.0;  // momentum neutral level
input int    strategy_swing_lookback    = 3;      // N-bar swing for the TD break (High[1]>High[2..N])
input int    strategy_sl_pips           = 40;     // fixed initial stop (card: 40 pips, cap 50)
input int    strategy_atr_period        = 14;     // ATR period for the take-profit target
input double strategy_tp_atr_mult       = 2.0;    // take-profit = ATR x mult (card: ATR(14) x 2.0)
input int    strategy_max_spread_pips    = 20;    // skip only genuinely wide spread (card cap)

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// TRUE if the last closed bar (shift 1) broke above the prior swing: its high
// strictly exceeds every high in shifts 2..lookback. Bounded closed-bar scan.
bool SwingBreakUp(const int lookback)
  {
   const double h1 = iHigh(_Symbol, _Period, 1); // perf-allowed: bounded swing scan, new-bar gated
   if(h1 <= 0.0)
      return false;
   for(int s = 2; s <= lookback; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s);
      if(h <= 0.0)
         return false;
      if(!(h1 > h))
         return false;
     }
   return true;
  }

// TRUE if the last closed bar broke below the prior swing: its low strictly
// undercuts every low in shifts 2..lookback.
bool SwingBreakDown(const int lookback)
  {
   const double l1 = iLow(_Symbol, _Period, 1); // perf-allowed: bounded swing scan, new-bar gated
   if(l1 <= 0.0)
      return false;
   for(int s = 2; s <= lookback; ++s)
     {
      const double l = iLow(_Symbol, _Period, s);
      if(l <= 0.0)
         return false;
      if(!(l1 < l))
         return false;
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap    = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). The EMA
// cross is the sole EVENT; momentum + the 3-bar swing break are STATES.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA(9/30) values on the two most recent closed bars ---
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool cross_up   = (fast_prev <= slow_prev && fast_now > slow_now);
   const bool cross_down = (fast_prev >= slow_prev && fast_now < slow_now);
   if(!cross_up && !cross_down)
      return false;

   // --- Momentum STATE on the closed bar ---
   const double mom = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   if(mom <= 0.0)
      return false;

   // --- ATR for the take-profit target (same value used at entry) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(cross_up)
     {
      // momentum confirms bullish (close > close 10 bars ago)
      if(!(mom > strategy_mom_baseline))
         return false;
      // TD break approximation: last closed bar breaks the 3-bar swing high
      if(!SwingBreakUp(strategy_swing_lookback))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "td_ema930_mom_long";
      return true;
     }

   // cross_down -> SHORT
   if(!(mom < strategy_mom_baseline))
      return false;
   if(!SwingBreakDown(strategy_swing_lookback))
      return false;

   const double sentry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sentry <= 0.0)
      return false;
   const double ssl = QM_StopFixedPips(_Symbol, QM_SELL, sentry, strategy_sl_pips);
   if(ssl <= 0.0)
      return false;
   const double stp = QM_TakeATRFromValue(_Symbol, QM_SELL, sentry, atr_value, strategy_tp_atr_mult);
   if(stp <= 0.0)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = ssl;
   req.tp     = stp;
   req.reason = "td_ema930_mom_short";
   return true;
  }

// No active trade management beyond the fixed stop / ATR target. The
// trend-reversal exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Trend-reversal exit (card): close when EMA9 crosses back below EMA30 for a
// long, or back above EMA30 for a short. One event sampled at shift 1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool cross_back_down = (fast_prev >= slow_prev && fast_now < slow_now);
   const bool cross_back_up   = (fast_prev <= slow_prev && fast_now > slow_now);

   // Determine our open direction; exit only on the opposing EMA re-cross.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cross_back_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross_back_up)
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
