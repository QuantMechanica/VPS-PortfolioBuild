#property strict
#property version   "5.0"
#property description "QM5_1324 carter-ttm-squeeze-pro-h1 — Carter TTM Squeeze-Pro 4-regime, tightness-gated (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1324 carter-ttm-squeeze-pro-h1
// -----------------------------------------------------------------------------
// Source: John Carter, "Mastering the Trade" 2nd ed (McGraw-Hill, 2012,
//   ISBN 978-0071775144) — TTM Squeeze-Pro (4-regime nested-Keltner variant).
//   FF Trading-Systems cluster (6e967762); community Pro ports by mladen /
//   jaguar / igorad. Card: artifacts/cards_approved/QM5_1324_carter-ttm-squeeze-pro-h1.md
//   (g0_status APPROVED).
//
// DISTINCT FROM the 2-regime sibling QM5_1291 (single 1.5xATR Keltner, binary
// in/out of squeeze): QM5_1324 nests THREE Keltner channels (1.0 / 1.5 / 2.0 x
// ATR) and classifies the compression into FOUR regimes by the tightest band the
// Bollinger Band still fits inside:
//
//   tight      : BB inside KC1 (EMA +/- 1.0*ATR)          -> highest conviction
//   medium     : not tight, BB inside KC2 (EMA +/- 1.5*ATR) -> baseline (= 1291)
//   wide       : not medium, BB inside KC3 (EMA +/- 2.0*ATR) -> marginal squeeze
//   no_squeeze : BB has expanded outside KC3                -> released / no compression
//
// Realization (framework-native, closed-bar reads at shift 1 = latest closed):
//
//   Regime at shift   : RegimeAt(shift) -> 0=tight 1=medium 2=wide 3=no_squeeze.
//                       BB = QM_BB_Upper/Lower(bb_period, bb_dev); KC midline =
//                       EMA(kc_period); width = mult * ATR(kc_atr_period).
//
//   Release EVENT     : the ONE trigger per bar. prior closed bar (shift 2) was
//                       in a STABLE squeeze regime (tight/medium/wide held >=
//                       squeeze_min_bars consecutive bars ENDING at shift 2), and
//                       the latest closed bar (shift 1) is no_squeeze. A direct
//                       no_squeeze -> no_squeeze transition is NOT a release.
//                       Single on->off transition => no two-cross-same-bar trap.
//
//   Tightness GATE    : the regime that was active at shift 2 selects the entry
//                       risk weight (tight 1.0 / medium 0.66 / wide 0.33) AND the
//                       take-profit ATR multiple (tight gets more room). The
//                       weight scales RISK_FIXED (tester) / RISK_PERCENT (live)
//                       via the framework risk sizer for THIS entry only. The
//                       three weights are FIXED design constants set at compile
//                       time, never learned from running PnL (HR14 compliant);
//                       total per-trade risk stays bounded (weight <= 1.0), no
//                       martingale, no averaging-in.
//
//   Direction STATE   : TTM momentum proxy = closed-form OLS slope of
//                       (close - midline) over mom_period closed bars, midline =
//                       avg(Donchian mid, SMA close) (Carter TTM baseline).
//                         BUY  : mom[1] > 0 AND mom[1] > mom[2]  (positive & rising)
//                         SELL : mom[1] < 0 AND mom[1] < mom[2]  (negative & falling)
//
//   Macro STATE       : EMA(macro_ema_period) bias — long only if close[1] > EMA,
//                       short only if close[1] < EMA.
//
//   Stop              : QM_StopATR(atr_period, sl_atr_mult) from entry, all
//                       regimes (default 1.0 x ATR(14)). Hard SL, no widening, no BE.
//   Take profit       : QM_TakeATR(atr_period, tp_mult) where tp_mult is
//                       regime-scaled: tight -> tp_atr_mult_tight (2.5), medium /
//                       wide -> tp_atr_mult_medwide (2.0). (~1:2.5 / ~1:2.0 RR.)
//
//   Exits (closed-bar):
//     - Momentum-flip : TTM momentum crosses zero AGAINST the open direction -> close.
//     - Macro-flip    : H1 close crosses to the wrong side of EMA(macro) -> close.
//     - Time-stop     : position older than time_stop_bars H1 bars -> close.
//     (Broker-side ATR stop + regime-scaled ATR target are the primary exits.)
//
//   Session           : trade only inside [session_start_h, session_end_h) broker
//                       time. Spread guard fails OPEN on .DWX zero modeled spread.
//
//   One position per magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no
//   external feed. The OLS slope and the regime latch are fixed closed-form
//   computations over bounded windows — transparent non-ML logic (HR14).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1324;
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
input int    strategy_bb_period          = 20;     // Bollinger period
input double strategy_bb_dev             = 2.0;    // Bollinger deviation (MANDATORY arg)
input int    strategy_kc_period          = 20;     // Keltner EMA midline period
input int    strategy_kc_atr_period      = 10;     // ATR period for Keltner width
input double strategy_kc_mult_tight      = 1.0;    // KC1 = EMA +/- 1.0*ATR  (tight regime)
input double strategy_kc_mult_medium     = 1.5;    // KC2 = EMA +/- 1.5*ATR  (medium regime, = 1291)
input double strategy_kc_mult_wide       = 2.0;    // KC3 = EMA +/- 2.0*ATR  (wide regime)
input int    strategy_squeeze_min_bars   = 6;      // squeeze regime must hold >= N bars before release (P3 4..12)
input int    strategy_mom_period         = 20;     // TTM momentum OLS window
input int    strategy_macro_ema_period   = 200;    // macro-bias EMA gate
input int    strategy_atr_period         = 14;     // ATR period for stop/target
input double strategy_sl_atr_mult        = 1.0;    // stop distance = mult * ATR  (all regimes, P3 0.7..1.5)
input double strategy_tp_atr_mult_tight  = 2.5;    // TP mult for a TIGHT-release entry (P3 2.0..3.5)
input double strategy_tp_atr_mult_medwide= 2.0;    // TP mult for MEDIUM / WIDE-release entry (P3 1.5..3.0)
input double strategy_risk_weight_tight  = 1.00;   // tightness-gate risk weight: tight release
input double strategy_risk_weight_medium = 0.66;   // tightness-gate risk weight: medium release (= 1291 baseline)
input double strategy_risk_weight_wide   = 0.33;   // tightness-gate risk weight: wide release
input int    strategy_time_stop_bars     = 24;     // close after N H1 bars without TP/SL (P3 16..48)
input int    strategy_session_start_h    = 6;      // broker-hour session open (inclusive)
input int    strategy_session_end_h      = 21;     // broker-hour session close (exclusive)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// Regime codes.
#define QM1324_TIGHT       0
#define QM1324_MEDIUM      1
#define QM1324_WIDE        2
#define QM1324_NO_SQUEEZE  3

// Base risk config captured at init so the per-entry tightness weight scales the
// configured RISK_FIXED / RISK_PERCENT without ratcheting (re-applied every entry
// off these stored bases, never off the previously-scaled live value).
double g_qm1324_base_portfolio_weight = 1.0;

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// 4-regime classification at a closed-bar shift: the TIGHTEST nested Keltner the
// Bollinger Band still sits strictly inside. Returns QM1324_TIGHT/MEDIUM/WIDE/
// NO_SQUEEZE. Fails to NO_SQUEEZE on any unavailable buffer read (warmup) so the
// gate is safe (a warmup bar never counts as a stable squeeze).
int RegimeAt(const int shift)
  {
   const double bb_up = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, shift);
   const double bb_lo = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, shift);
   if(bb_up <= 0.0 || bb_lo <= 0.0)
      return QM1324_NO_SQUEEZE;

   const double mid = QM_EMA(_Symbol, _Period, strategy_kc_period, shift);
   const double atr = QM_ATR(_Symbol, _Period, strategy_kc_atr_period, shift);
   if(mid <= 0.0 || atr <= 0.0)
      return QM1324_NO_SQUEEZE;

   // tight: BB inside KC1 (EMA +/- 1.0*ATR)
   if(bb_up < mid + strategy_kc_mult_tight  * atr && bb_lo > mid - strategy_kc_mult_tight  * atr)
      return QM1324_TIGHT;
   // medium: BB inside KC2 (EMA +/- 1.5*ATR)
   if(bb_up < mid + strategy_kc_mult_medium * atr && bb_lo > mid - strategy_kc_mult_medium * atr)
      return QM1324_MEDIUM;
   // wide: BB inside KC3 (EMA +/- 2.0*ATR)
   if(bb_up < mid + strategy_kc_mult_wide   * atr && bb_lo > mid - strategy_kc_mult_wide   * atr)
      return QM1324_WIDE;

   return QM1324_NO_SQUEEZE;
  }

// True if `regime` is one of the three compression regimes (a squeeze is "on").
bool IsSqueezeRegime(const int regime)
  {
   return (regime == QM1324_TIGHT || regime == QM1324_MEDIUM || regime == QM1324_WIDE);
  }

// TTM momentum oscillator at the given closed-bar shift: closed-form OLS slope of
// (close - midline) over strategy_mom_period closed bars, midline = average of the
// Donchian mid ((HH+LL)/2) and SMA(close) of the window (Carter TTM baseline).
// Returns the slope; sign gives direction, magnitude its strength. `ok` is set
// false on any warmup/unavailable read. Bounded loop on the closed-bar path only.
double MomentumSlopeAt(const int trigger_shift, bool &ok)
  {
   ok = false;
   const int n = strategy_mom_period;
   if(n < 3)
      return 0.0;

   double hh = -DBL_MAX;
   double ll =  DBL_MAX;
   double close_sum = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const int s = trigger_shift + k;
      const double hi = iHigh(_Symbol, _Period, s);   // perf-allowed: bounded closed-bar regression window
      const double lo = iLow(_Symbol, _Period, s);    // perf-allowed
      const double cl = iClose(_Symbol, _Period, s);  // perf-allowed
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0)
         return 0.0;                                   // warmup -> fail closed
      if(hi > hh) hh = hi;
      if(lo < ll) ll = lo;
      close_sum += cl;
     }

   const double donchian_mid = 0.5 * (hh + ll);
   const double sma_close     = close_sum / (double)n;
   const double midline       = 0.5 * (donchian_mid + sma_close);

   // OLS slope of y=(close-midline) vs x=bar index, indexed so the most-recent
   // bar (trigger_shift) is the largest x => positive slope == momentum building.
   double sum_x = 0.0, sum_y = 0.0, sum_xx = 0.0, sum_xy = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const int s = trigger_shift + k;
      const double cl = iClose(_Symbol, _Period, s); // perf-allowed: bounded closed-bar regression window
      if(cl <= 0.0)
         return 0.0;
      const double x = (double)(n - 1 - k);
      const double y = cl - midline;
      sum_x  += x;
      sum_y  += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double denom = (double)n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) < 1e-12)
      return 0.0;

   const double slope = ((double)n * sum_xy - sum_x * sum_y) / denom;
   ok = true;
   return slope;
  }

// Broker-time session gate: true if inside [start, end) hour window. Wrap-safe. O(1).
bool InSession(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int h = dt.hour;
   if(strategy_session_start_h == strategy_session_end_h)
      return true; // degenerate full-day
   if(strategy_session_start_h < strategy_session_end_h)
      return (h >= strategy_session_start_h && h < strategy_session_end_h);
   return (h >= strategy_session_start_h || h < strategy_session_end_h); // overnight wrap
  }

// Map a release regime to its take-profit ATR multiple.
double TpMultForRegime(const int regime)
  {
   if(regime == QM1324_TIGHT)
      return strategy_tp_atr_mult_tight;
   return strategy_tp_atr_mult_medwide; // medium / wide
  }

// Map a release regime to its tightness-gate risk weight (fixed design constants).
double RiskWeightForRegime(const int regime)
  {
   if(regime == QM1324_TIGHT)
      return strategy_risk_weight_tight;
   if(regime == QM1324_MEDIUM)
      return strategy_risk_weight_medium;
   return strategy_risk_weight_wide; // wide
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + spread guard. Fail-OPEN on .DWX zero
// modeled spread (ask == bid). Regime / signal work is closed-bar only.
bool Strategy_NoTradeFilter()
  {
   if(!InSession(TimeCurrent()))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Squeeze-Pro release + tightness-gate + momentum-direction entry. Caller
// guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Release EVENT: stable squeeze at shift 2, no_squeeze at shift 1 ---
   const int regime_prev = RegimeAt(2);  // regime that just released
   const int regime_now  = RegimeAt(1);
   if(!IsSqueezeRegime(regime_prev) || regime_now != QM1324_NO_SQUEEZE)
      return false; // not a fresh squeeze release this bar

   // --- Stability LATCH: the SAME squeeze regime (or tighter) held for at least
   //     squeeze_min_bars consecutive bars ENDING at shift 2. shift 2 counts as
   //     bar #1; require a squeeze regime across shifts 2 .. (squeeze_min_bars+1).
   //     "or tighter" because tightness can only increase as compression builds;
   //     a regime that loosened (or released) mid-window breaks the latch. ---
   if(strategy_squeeze_min_bars > 1)
     {
      const int last_shift = strategy_squeeze_min_bars + 1; // shift 2 already counts as bar #1
      for(int s = 3; s <= last_shift; ++s)
        {
         const int r = RegimeAt(s);
         if(!IsSqueezeRegime(r) || r < regime_prev)
            return false; // squeeze did not persist long enough / loosened then re-tightened
        }
     }

   // --- Direction STATE: TTM momentum positive&rising (BUY) / negative&falling (SELL) ---
   bool mom1_ok = false, mom2_ok = false;
   const double mom1 = MomentumSlopeAt(1, mom1_ok);
   const double mom2 = MomentumSlopeAt(2, mom2_ok);
   if(!mom1_ok || !mom2_ok)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double macro  = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(close1 <= 0.0 || macro <= 0.0)
      return false;

   QM_OrderType dir;
   double entry;
   if(mom1 > 0.0 && mom1 > mom2)
     {
      // BUY: positive & rising momentum + bullish macro bias
      if(!(close1 > macro))
         return false;
      dir   = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else if(mom1 < 0.0 && mom1 < mom2)
     {
      // SELL: negative & falling momentum + bearish macro bias
      if(!(close1 < macro))
         return false;
      dir   = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   else
      return false; // no directional conviction (flat / wrong-way momentum)

   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, dir, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeATR(_Symbol, dir, entry, strategy_atr_period, TpMultForRegime(regime_prev));
   if(tp <= 0.0)
      return false;

   // --- Tightness GATE: scale this entry's risk by the released regime's fixed
   //     weight. Re-apply off the captured base weight (never off the live value)
   //     so weights do not compound across entries. ---
   const double regime_weight = RiskWeightForRegime(regime_prev);
   const double applied_weight = g_qm1324_base_portfolio_weight * regime_weight;
   QM_RiskSizerConfigure(g_qm_risk_mode,
                         g_qm_risk_percent,
                         g_qm_risk_fixed,
                         applied_weight,
                         g_qm_risk_per_trade_cap_money);

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (regime_prev == QM1324_TIGHT)  ? "ttm_squeeze_pro_release_tight"  :
                (regime_prev == QM1324_MEDIUM) ? "ttm_squeeze_pro_release_medium" :
                                                 "ttm_squeeze_pro_release_wide";
   return true;
  }

// Primary exits are the broker-side ATR stop and regime-scaled ATR target; no
// active management (trailing/BE) per the card.
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar exits: momentum-flip against the open direction, EMA-200 macro-bias
// flip, or time-stop (position too old). Caller closes the magic's positions when
// this returns true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this magic's open position to read its direction + open time.
   bool   have_pos    = false;
   long   pos_type    = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos  = true;
      break;
     }
   if(!have_pos)
      return false;

   // --- Time-stop: position older than time_stop_bars H1 bars ---
   if(strategy_time_stop_bars > 0)
     {
      const int bar_seconds = PeriodSeconds(_Period);
      if(bar_seconds > 0)
        {
         const long held_bars = (long)((TimeCurrent() - open_time) / bar_seconds);
         if(held_bars >= (long)strategy_time_stop_bars)
            return true;
        }
     }

   // --- Momentum-flip exit: TTM momentum sign turns against the position ---
   bool mom_ok = false;
   const double mom = MomentumSlopeAt(1, mom_ok);
   if(mom_ok)
     {
      if(pos_type == POSITION_TYPE_BUY  && mom < 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && mom > 0.0)
         return true;
     }

   // --- Macro-bias flip exit: H1 close crosses to the wrong side of EMA(macro) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double macro  = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(close1 > 0.0 && macro > 0.0)
     {
      if(pos_type == POSITION_TYPE_BUY  && close1 < macro)
         return true;
      if(pos_type == POSITION_TYPE_SELL && close1 > macro)
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

   // Capture the configured base portfolio weight so the per-entry tightness
   // gate scales off it (never off a previously-scaled live value).
   g_qm1324_base_portfolio_weight = g_qm_risk_portfolio_weight;

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
