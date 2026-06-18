#property strict
#property version   "5.0"
#property description "QM5_11494 carter-t-mtf-triple-ema-bb-align-m5h1 — MTF Triple-EMA + BB alignment (M5 entry / H1 bias)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11494 carter-t-mtf-triple-ema-bb-align-m5h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         System #6, self-published 2014.
// Card: artifacts/cards_approved/QM5_11494_carter-t-mtf-triple-ema-bb-align-m5h1.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5 base TF, H1 explicit-TF bias):
//   H1 trend STATE (filter):
//     LONG : ema14_h1 > ema21_h1 > ema50_h1  AND  ema50_h1 inside BB(20,dev)_h1
//     SHORT: ema14_h1 < ema21_h1 < ema50_h1  AND  ema50_h1 inside BB(20,dev)_h1
//   M5 trend STATE (filter):
//     LONG : ema14_m5 > ema21_m5 > ema50_m5  AND  ema50_m5 inside BB(20,dev)_m5
//     SHORT: ema14_m5 < ema21_m5 < ema50_m5  AND  ema50_m5 inside BB(20,dev)_m5
//   M5 entry EVENT (the single discrete trigger):
//     LONG : the last closed M5 bar (shift 1) PULLED BACK to touch EMA14 or
//            EMA21 (low <= the faster EMA) AND closed bullish (close > open),
//            while the bar BEFORE it (shift 2) did NOT yet touch — making the
//            pullback-touch a fresh single event, not a persistent state that
//            re-fires every bar. SHORT mirrors with the high touching from above.
//   Stop : entry -/+ sl_atr_mult * ATR(M5).   Take: rr_mult R-multiple of stop.
//   Spread guard: block only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// The H1 stack is a STATE filter; the M5 pullback-touch+close is the EVENT. Only
// ONE fresh M5 event is required per entry — this avoids the two-cross-same-bar
// zero-trade trap (we do not demand two independent crossovers to coincide).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11494;
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
input int    strategy_ema_fast_period   = 14;    // triple-stack fast EMA (M5 & H1)
input int    strategy_ema_mid_period    = 21;    // triple-stack mid EMA  (M5 & H1)
input int    strategy_ema_slow_period   = 50;    // triple-stack slow EMA (M5 & H1)
input int    strategy_bb_period         = 20;    // Bollinger period (M5 & H1)
input double strategy_bb_deviation      = 20.0;  // Bollinger deviation (card: BB(20,20); P3 sweep 2/10/20)
input bool   strategy_use_h1_filter     = true;  // require the H1 trend stack (P3: on/off)
input bool   strategy_use_bb_filter     = true;  // require EMA50 inside the BB envelope (P3: on/off)
input bool   strategy_touch_ema21_too   = true;  // pullback touch on EMA14 OR EMA21 (false = EMA14 only)
input int    strategy_atr_period        = 14;    // ATR period (stop / target)
input double strategy_sl_atr_mult       = 1.5;   // stop distance = mult * ATR (card)
input double strategy_tp_rr_mult        = 1.3333;// take-profit R-multiple (~2.0*ATR vs 1.5*ATR stop = card)
input bool   strategy_no_friday_entry   = true;  // card: no Friday entries
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar EMA stack + BB containment evaluated at a given shift)
// -----------------------------------------------------------------------------

// dir: +1 require bullish stack, -1 require bearish stack. Returns true if the
// triple-EMA stack on (sym,tf) is ordered in the requested direction at `shift`,
// and (if BB filter on) the slow EMA sits inside the BB envelope at `shift`.
bool StackAligned(const string sym, const ENUM_TIMEFRAMES tf, const int dir, const int shift)
  {
   const double ef = QM_EMA(sym, tf, strategy_ema_fast_period, shift);
   const double em = QM_EMA(sym, tf, strategy_ema_mid_period,  shift);
   const double es = QM_EMA(sym, tf, strategy_ema_slow_period, shift);
   if(ef <= 0.0 || em <= 0.0 || es <= 0.0)
      return false;

   if(dir > 0)
     {
      if(!(ef > em && em > es))
         return false;
     }
   else
     {
      if(!(ef < em && em < es))
         return false;
     }

   if(strategy_use_bb_filter)
     {
      const double upper = QM_BB_Upper(sym, tf, strategy_bb_period, strategy_bb_deviation, shift);
      const double lower = QM_BB_Lower(sym, tf, strategy_bb_period, strategy_bb_deviation, shift);
      if(upper <= 0.0 || lower <= 0.0)
         return false;
      if(!(es >= lower && es <= upper))
         return false;
     }

   return true;
  }

// True if the M5 bar at `shift` pulled back to touch the fast/mid EMA in the
// trend direction. dir>0: bar low dipped to/under the EMA (a long pullback).
// dir<0: bar high rose to/above the EMA (a short pullback).
bool PulledBackToEMA(const int dir, const int shift)
  {
   const double ef = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift);
   const double em = QM_EMA(_Symbol, _Period, strategy_ema_mid_period,  shift);
   if(ef <= 0.0 || em <= 0.0)
      return false;

   if(dir > 0)
     {
      const double lo = iLow(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
      if(lo <= 0.0)
         return false;
      if(lo <= ef)
         return true;
      if(strategy_touch_ema21_too && lo <= em)
         return true;
      return false;
     }
   else
     {
      const double hi = iHigh(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
      if(hi <= 0.0)
         return false;
      if(hi >= ef)
         return true;
      if(strategy_touch_ema21_too && hi >= em)
         return true;
      return false;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// MTF triple-EMA + BB alignment entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Card: no Friday entries.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // Evaluate LONG then SHORT. dir = +1 long, -1 short.
   for(int k = 0; k < 2; ++k)
     {
      const int dir = (k == 0) ? 1 : -1;

      // --- H1 trend STATE filter (bias) ---
      if(strategy_use_h1_filter)
        {
         if(!StackAligned(_Symbol, PERIOD_H1, dir, 1))
            continue;
        }

      // --- M5 trend STATE filter ---
      if(!StackAligned(_Symbol, _Period, dir, 1))
         continue;

      // --- M5 entry EVENT: a FRESH pullback-touch on the last closed bar.
      // The touch must be present at shift 1 but ABSENT at shift 2, so the
      // event fires once at the pullback, not every bar the trend persists. ---
      if(!PulledBackToEMA(dir, 1))
         continue;
      if(PulledBackToEMA(dir, 2))
         continue; // not fresh — the prior bar already touched

      // --- Bar must close in the trend direction (card: bullish for long). ---
      const double o1 = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
      const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(o1 <= 0.0 || c1 <= 0.0)
         continue;
      if(dir > 0 && !(c1 > o1))
         continue;
      if(dir < 0 && !(c1 < o1))
         continue;

      // --- Build the entry. Framework sizes lots (no lots field). ---
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value <= 0.0)
         continue;

      const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         continue;

      const QM_OrderType ot = (dir > 0) ? QM_BUY : QM_SELL;
      const double sl = QM_StopATRFromValue(_Symbol, ot, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         continue;
      const double tp = QM_TakeRR(_Symbol, ot, entry, sl, strategy_tp_rr_mult);
      if(tp <= 0.0)
         continue;

      req.type   = ot;
      req.price  = 0.0; // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = (dir > 0) ? "mtf_triple_ema_bb_long" : "mtf_triple_ema_bb_short";
      return true;
     }

   return false;
  }

// Fixed ATR stop/target only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the ATR stop/target.
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
