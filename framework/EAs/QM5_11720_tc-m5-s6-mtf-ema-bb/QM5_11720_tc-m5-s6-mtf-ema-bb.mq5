#property strict
#property version   "5.0"
#property description "QM5_11720 tc-m5-s6-mtf-ema-bb — MTF EMA-stack + BB containment (M5 entry / H1 bias)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11720 tc-m5-s6-mtf-ema-bb
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         Strategy #6, self-published 2014 (367145560). R1 FAIL (self-published).
// Card: artifacts/cards_approved/QM5_11720_tc-m5-s6-mtf-ema-bb.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5 base TF, H1 explicit-TF bias):
//   MTF confluence: both M5 and H1 must show the EMA stack (14>21>50) AND
//   EMA(50) inside Bollinger(20,dev). Entry fires on a fresh M5 pullback-touch
//   of EMA14/EMA21 with a confirming close, while the H1 side confirms a fresh
//   pullback-touch + directional close as well.
//
//   H1 trend STATE (bias filter):
//     LONG : ema14_h1 > ema21_h1 > ema50_h1  AND  ema50_h1 inside BB(20,dev)_h1
//     SHORT: ema14_h1 < ema21_h1 < ema50_h1  AND  ema50_h1 inside BB(20,dev)_h1
//   H1 confirmation (card): the last closed H1 bar touched EMA14/EMA21 in the
//     trend direction (low<=fastEMA for long / high>=fastEMA for short) AND
//     closed directionally (close>open long / close<open short). Required fresh
//     (present at H1 shift 1, absent at H1 shift 2) so the bias-trigger does not
//     re-fire every H1 bar the trend persists.
//   M5 trend STATE:
//     LONG : ema14_m5 > ema21_m5 > ema50_m5  AND  ema50_m5 inside BB(20,dev)_m5
//     SHORT: mirror.
//   M5 entry EVENT (the single discrete trigger):
//     A FRESH M5 pullback-touch of EMA14/EMA21 on the last closed bar (touch at
//     shift 1, NOT at shift 2) with a confirming directional close. This is the
//     one event; the H1/M5 stacks + BB containment are STATEs. Demanding only a
//     single fresh M5 event avoids the two-cross-same-bar zero-trade trap.
//
//   Stop : card = recent M5 swing low (structure) OR 20 pips. We use the
//          structural swing extreme over sl_structure_lookback M5 bars, and fall
//          back to a fixed sl_fixed_pips stop if structure is unavailable or
//          would be on the wrong side of entry.
//   Take : card factory = 2 * ATR(atr_period, M5).
//   Exit : card = EMA stack breaks (14>21>50 ordering lost for long / inverse
//          for short) on EITHER M5 or H1 AND EMA50 has left the BB envelope on
//          EITHER M5 or H1.
//   Spread guard: block only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Symbol: EURUSD.DWX (card target; present in dwx_symbol_matrix.csv).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11720;
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
input int    strategy_bb_period          = 20;     // Bollinger period (M5 & H1)
input double strategy_bb_deviation       = 20.0;   // Bollinger deviation (card BB(20,20); P3 sweep 2/10/20)
input bool   strategy_use_h1_filter      = true;   // require the H1 trend stack (P3: on/off)
input bool   strategy_use_h1_confirm     = true;   // require the H1 fresh touch + directional close (card)
input bool   strategy_use_bb_filter      = true;   // require EMA50 inside the BB envelope (P3: on/off)
input bool   strategy_touch_ema21_too    = true;   // pullback touch on EMA14 OR EMA21 (false = EMA14 only)
input int    strategy_atr_period         = 14;     // ATR period (target)
input double strategy_tp_atr_mult        = 2.0;    // take-profit distance = mult * ATR(M5) (card 2xATR)
input int    strategy_sl_structure_lookback = 10;  // M5 swing lookback for the structural stop (card swing low)
input int    strategy_sl_fixed_pips      = 20;     // fallback fixed stop in pips (card "or 20 pips")
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar EMA stack + BB containment / pullback evaluated at a shift)
// -----------------------------------------------------------------------------

// dir: +1 require bullish stack, -1 require bearish stack. True if the triple-EMA
// stack on (sym,tf) is ordered in the requested direction at `shift`. If the BB
// filter is on, the slow EMA must also sit inside the BB envelope at `shift`.
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

// True if the EMA50 on (sym,tf) has LEFT the BB envelope at `shift` (used by the
// exit: "EMA50 leaves BB"). If the BB filter is off, treat as "not left".
bool EMA50OutsideBB(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   if(!strategy_use_bb_filter)
      return false;
   const double es    = QM_EMA(sym, tf, strategy_ema_slow_period, shift);
   const double upper = QM_BB_Upper(sym, tf, strategy_bb_period, strategy_bb_deviation, shift);
   const double lower = QM_BB_Lower(sym, tf, strategy_bb_period, strategy_bb_deviation, shift);
   if(es <= 0.0 || upper <= 0.0 || lower <= 0.0)
      return false; // can't confirm — do not force an exit on missing data
   return (es < lower || es > upper);
  }

// True if the EMA stack ordering on (sym,tf) is BROKEN for `dir` at `shift`
// (no longer 14>21>50 for long / 14<21<50 for short).
bool StackBroken(const string sym, const ENUM_TIMEFRAMES tf, const int dir, const int shift)
  {
   const double ef = QM_EMA(sym, tf, strategy_ema_fast_period, shift);
   const double em = QM_EMA(sym, tf, strategy_ema_mid_period,  shift);
   const double es = QM_EMA(sym, tf, strategy_ema_slow_period, shift);
   if(ef <= 0.0 || em <= 0.0 || es <= 0.0)
      return false; // can't confirm — do not force an exit on missing data
   if(dir > 0)
      return !(ef > em && em > es);
   return !(ef < em && em < es);
  }

// True if the (sym,tf) bar at `shift` pulled back to touch the fast/mid EMA in
// the trend direction AND closed directionally (card "confirming candle close").
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

// MTF EMA-stack + BB containment entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

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

      // --- H1 confirmation (card): fresh H1 pullback-touch + directional close.
      // Fresh = touch present at H1 shift 1 but absent at H1 shift 2. ---
      if(strategy_use_h1_confirm)
        {
         if(!PullbackTouchClose(_Symbol, PERIOD_H1, dir, 1))
            continue;
         if(PullbackTouchClose(_Symbol, PERIOD_H1, dir, 2))
            continue; // not fresh — the prior H1 bar already touched
        }

      // --- M5 trend STATE filter ---
      if(!StackAligned(_Symbol, _Period, dir, 1))
         continue;

      // --- M5 entry EVENT: a FRESH pullback-touch + directional close on the
      // last closed M5 bar. Present at shift 1, absent at shift 2 → fires once
      // per pullback, not every bar the trend persists. ---
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

      // Stop: structural M5 swing extreme; fall back to fixed pips if structure
      // is unavailable or lands on the wrong side of entry (card: swing OR 20 pips).
      double sl = QM_StopStructure(_Symbol, ot, entry, strategy_sl_structure_lookback);
      const bool sl_ok = (sl > 0.0) &&
                         ((dir > 0 && sl < entry) || (dir < 0 && sl > entry));
      if(!sl_ok)
         sl = QM_StopFixedPips(_Symbol, ot, entry, strategy_sl_fixed_pips);
      if(sl <= 0.0)
         continue;

      // Take: 2 * ATR(M5) (card factory target).
      const double tp = QM_TakeATRFromValue(_Symbol, ot, entry, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         continue;

      req.type   = ot;
      req.price  = 0.0; // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = (dir > 0) ? "mtf_ema_bb_long" : "mtf_ema_bb_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the structural/fixed stop + ATR target.
// The discretionary stack-break exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Card exit: EMA stack breaks on EITHER M5 or H1 AND EMA50 has left the BB
// envelope on EITHER M5 or H1, in the open position's direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open position's direction for this magic.
   int dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      dir = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      break;
     }
   if(dir == 0)
      return false;

   const bool stack_broken = StackBroken(_Symbol, _Period, dir, 1) ||
                             StackBroken(_Symbol, PERIOD_H1, dir, 1);
   const bool bb_left      = EMA50OutsideBB(_Symbol, _Period, 1) ||
                             EMA50OutsideBB(_Symbol, PERIOD_H1, 1);

   return (stack_broken && bb_left);
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
