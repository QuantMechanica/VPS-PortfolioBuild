#property strict
#property version   "5.0"
#property description "QM5_11818 carter-m5-s6-mtf-ema142150-bb20-m5h1 — MTF triple-EMA stack + BB(20,20) pullback (M5 entry / H1 bias)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11818 carter-m5-s6-mtf-ema142150-bb20-m5h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         Strategy #6, 2014 (367145560-...). R1 FAIL (self-published retail PDF);
//         G0 APPROVED on revised R1 (single source_id + citation).
// Card: artifacts/cards_approved/
//         QM5_11818_carter-m5-s6-mtf-ema142150-bb20-m5h1.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5 base TF, H1 explicit-TF bias):
//
//   Multi-timeframe triple-EMA(14/21/50) alignment must agree on BOTH M5 and H1
//   before entry. BB(20, dev=20) is the very-wide containment band: an entry is
//   only valid while price is in-range (near the BB middle / not overextended at
//   the outer bands).
//
//   H1 trend STATE (bias filter — read via explicit PERIOD_H1):
//     LONG : ema14_h1 > ema21_h1 > ema50_h1   (H1 bullish stack)
//     SHORT: ema14_h1 < ema21_h1 < ema50_h1   (H1 bearish stack)
//   H1 is a STATE only — it does not generate the trigger.
//
//   M5 trend STATE:
//     LONG : ema14_m5 > ema21_m5 > ema50_m5
//     SHORT: ema14_m5 < ema21_m5 < ema50_m5
//
//   BB range STATE (card rule 4 — "within / touching the BB(20,20) midline zone,
//   not overextended"): on the last closed M5 bar the close must sit INSIDE the
//   BB(20,20) envelope (between lower and upper band), i.e. price has not blown
//   out past the wide bands. This keeps entries to in-range pullbacks.
//
//   M5 entry EVENT (the single discrete trigger — avoids the two-cross-same-bar
//   zero-trade trap): a FRESH M5 pullback-touch of the EMA14/EMA21 cluster on the
//   last closed bar (touch present at shift 1, ABSENT at shift 2). All EMA-stack
//   and BB conditions are STATEs; only this pullback-touch is the EVENT, so the
//   signal fires once per pullback rather than every bar the trend persists.
//
//   Stop : 2 * ATR(14) on M5  (card factory default).
//   Take : 4 * ATR(14) on M5  (card factory default; 2R relative to the stop).
//   Exit : initial Stop Loss or Take Profit only — the card specifies NO
//          discretionary close rule, so Strategy_ExitSignal is a no-op.
//   Spread guard: block only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Symbol: EURUSD.DWX (card target; present in dwx_symbol_matrix.csv).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11818;
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
input int    strategy_ema_fast_period    = 14;     // stack fast EMA (M5 & H1)
input int    strategy_ema_mid_period     = 21;     // stack mid  EMA (M5 & H1)
input int    strategy_ema_slow_period    = 50;     // stack slow EMA (M5 & H1)
input int    strategy_bb_period          = 20;     // Bollinger period (M5)
input double strategy_bb_deviation       = 20.0;   // Bollinger deviation (card BB(20,20); P3 sweep 2/10/20)
input bool   strategy_use_h1_filter      = true;   // require the H1 trend stack bias (P3: on/off)
input bool   strategy_use_bb_filter      = true;   // require the M5 close inside the BB envelope (P3: on/off)
input bool   strategy_touch_ema21_too    = true;   // pullback touch on EMA14 OR EMA21 (false = EMA14 only)
input int    strategy_atr_period         = 14;     // ATR period (M5)
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR(M5)  (card 2xATR)
input double strategy_tp_atr_mult        = 4.0;    // take distance = mult * ATR(M5)  (card 4xATR)
input int    strategy_sl_fixed_pips      = 20;     // spread-cap reference stop (pips)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar EMA stack / BB containment / pullback evaluated at a shift)
// -----------------------------------------------------------------------------

// dir: +1 require bullish stack, -1 require bearish stack. True if the triple-EMA
// stack on (sym,tf) is ordered in the requested direction at `shift`.
bool StackAligned(const string sym, const ENUM_TIMEFRAMES tf, const int dir, const int shift)
  {
   const double ef = QM_EMA(sym, tf, strategy_ema_fast_period, shift);
   const double em = QM_EMA(sym, tf, strategy_ema_mid_period,  shift);
   const double es = QM_EMA(sym, tf, strategy_ema_slow_period, shift);
   if(ef <= 0.0 || em <= 0.0 || es <= 0.0)
      return false;

   if(dir > 0)
      return (ef > em && em > es);
   return (ef < em && em < es);
  }

// True if the (sym,tf) close at `shift` sits INSIDE the BB(period,deviation)
// envelope — card rule 4: "within / touching the BB midline zone, not
// overextended". If the BB filter is off, always pass.
bool CloseInsideBB(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   if(!strategy_use_bb_filter)
      return true;
   const double upper = QM_BB_Upper(sym, tf, strategy_bb_period, strategy_bb_deviation, shift);
   const double lower = QM_BB_Lower(sym, tf, strategy_bb_period, strategy_bb_deviation, shift);
   if(upper <= 0.0 || lower <= 0.0)
      return false;
   const double c = iClose(sym, tf, shift); // perf-allowed: single closed-bar read
   if(c <= 0.0)
      return false;
   return (c >= lower && c <= upper);
  }

// True if the (sym,tf) bar at `shift` pulled back to touch the fast/mid EMA in
// the trend direction AND closed directionally (card "pullback to the EMA
// cluster" + confirming candle close).
// dir>0: bar low dipped to/under the EMA and close>open (long pullback).
// dir<0: bar high rose to/above the EMA and close<open (short pullback).
bool PullbackTouchClose(const string sym, const ENUM_TIMEFRAMES tf, const int dir, const int shift)
  {
   const double ef = QM_EMA(sym, tf, strategy_ema_fast_period, shift);
   const double em = QM_EMA(sym, tf, strategy_ema_mid_period,  shift);
   if(ef <= 0.0 || em <= 0.0)
      return false;

   const double o = iOpen(sym, tf, shift);  // perf-allowed: single closed-bar read
   const double c = iClose(sym, tf, shift);  // perf-allowed: single closed-bar read
   if(o <= 0.0 || c <= 0.0)
      return false;

   if(dir > 0)
     {
      if(!(c > o))
         return false; // bullish close required
      const double lo = iLow(sym, tf, shift); // perf-allowed: single closed-bar read
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
      if(!(c < o))
         return false; // bearish close required
      const double hi = iHigh(sym, tf, shift); // perf-allowed: single closed-bar read
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

   // Stop-distance reference for the spread cap: the fixed-pips fallback stop
   // distance scales the cap per symbol without needing an open position.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_fixed_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// MTF triple-EMA + BB(20,20) pullback entry. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Evaluate LONG then SHORT. dir = +1 long, -1 short.
   for(int k = 0; k < 2; ++k)
     {
      const int dir = (k == 0) ? 1 : -1;

      // --- H1 trend STATE (bias; explicit PERIOD_H1) ---
      if(strategy_use_h1_filter)
        {
         if(!StackAligned(_Symbol, PERIOD_H1, dir, 1))
            continue;
        }

      // --- M5 trend STATE ---
      if(!StackAligned(_Symbol, _Period, dir, 1))
         continue;

      // --- M5 BB range STATE: last closed M5 close inside the BB envelope
      // (in-range / not overextended). ---
      if(!CloseInsideBB(_Symbol, _Period, 1))
         continue;

      // --- M5 entry EVENT: a FRESH pullback-touch of the EMA cluster + a
      // directional close on the last closed M5 bar. Present at shift 1, absent
      // at shift 2 → fires once per pullback, not every bar the trend persists.
      // This is the SINGLE trigger; everything above is STATE (no two-cross trap).
      if(!PullbackTouchClose(_Symbol, _Period, dir, 1))
         continue;
      if(PullbackTouchClose(_Symbol, _Period, dir, 2))
         continue; // not fresh — the prior M5 bar already touched

      // --- Build the entry. Framework sizes lots (no lots field). ---
      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value <= 0.0)
         continue;

      const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         continue;

      const QM_OrderType ot = (dir > 0) ? QM_BUY : QM_SELL;

      // Stop: 2 * ATR(M5) (card). Take: 4 * ATR(M5) (card).
      const double sl = QM_StopATRFromValue(_Symbol, ot, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         continue;
      const double tp = QM_TakeATRFromValue(_Symbol, ot, entry, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         continue;

      req.type   = ot;
      req.price  = 0.0; // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = (dir > 0) ? "carter_mtf_ema_bb_long" : "carter_mtf_ema_bb_short";
      return true;
     }

   return false;
  }

// No active trade management — stop/target are set at entry (card: SL/TP only).
void Strategy_ManageOpenPosition()
  {
  }

// Card: "Exit via initial Stop Loss or Take Profit; no discretionary close rule."
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
