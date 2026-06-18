#property strict
#property version   "5.0"
#property description "QM5_1315 alma-ichimoku-h1 — ALMA-replaced Ichimoku cloud entry (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1315 alma-ichimoku-h1
// -----------------------------------------------------------------------------
// Source: ForexFactory Trading-Systems Ichimoku cluster (source_id
//   6e967762-b26d-59a3-b076-35c17f2e7c36). ALMA = Arnaud Legoux & Dimitris
//   Tsoukalas 2009 (Gaussian-weighted MA). Ichimoku = Goichi Hosoda 1968.
// Card: artifacts/cards_approved/QM5_1315_alma-ichimoku-h1.md (g0_status APPROVED).
//
// Idea: replace the classic Ichimoku Tenkan/Kijun midpoint construction with
//   ALMA-of-close (a closed-form Gaussian-weighted FIR filter; sigma=6,
//   offset=0.85 = Legoux defaults). The Ichimoku cloud (price vs cloud) is the
//   trend STATE; the Tenkan'/Kijun' cross is the single trigger EVENT.
//
// ALMA(price, window, sigma, offset) over the LAST `window` closed bars ending
//   at `base_shift` (oldest -> newest as i = window-1 .. 0):
//     m         = offset * (window - 1)
//     s         = window / sigma
//     w[i]      = exp( -((i - m)^2) / (2 * s^2) )
//     ALMA      = sum_i( w[i] * close[base_shift + (window-1 - i)] ) / sum_i( w[i] )
//   i indexes oldest(0)->newest(window-1); close[base_shift] is the NEWEST bar in
//   the window, close[base_shift+window-1] the OLDEST. Computed once per closed
//   bar from bounded closed-bar closes (perf-allowed single iClose reads).
//
// Mechanics (closed-bar reads; H1):
//   Tenkan' = ALMA(close, tenkan_period)           (slope-aware fast ALMA)
//   Kijun'  = ALMA(close, kijun_period)             (slow ALMA = recent-trend mean)
//   SenkouA = (Tenkan' + Kijun') / 2, computed `kijun` bars ago (forward-projected)
//   SenkouB = classic (highest(high,senkou)+lowest(low,senkou))/2, kijun bars ago
//             — read via QM_Ichimoku_SenkouSpanB at shift (1+kijun); the long-period
//             cloud floor stays classic for stability (per card).
//   Cloud STATE  : close[1] vs current Kumo (max/min of SenkouA/SenkouB) + bull/bear.
//   Trigger EVENT: Tenkan'/Kijun' cross THIS bar OR within prior `cross_window`
//                  bars — Tenkan'[w] <= Kijun'[w] AND Tenkan'[1] > Kijun'[1] (long).
//                  The cross is the single EVENT; the cloud relation is a STATE,
//                  so the two-cross-same-bar zero-trade trap is avoided.
//   Chikou clear : close[1] > high[1+kijun] (long) — lookback not stuck in prior
//                  congestion (classic Ichimoku Chikou confirmation).
//   Macro bias   : close[1] vs EMA(close, macro_ema) on H1.
//   Stop         : Kijun'[1] -/+ sl_atr_buffer*ATR, capped at sl_atr_cap*ATR.
//   Take         : tp_atr_mult * ATR from entry.
//   Exits        : Tenkan'/Kijun' cross against position OR price re-enters Kumo.
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX 0 spread).
//   Session      : 06:00-21:00 broker-time.
//
// Symbols: NDX.DWX / WS30.DWX / GDAXI.DWX / UK100.DWX (card R3 index basket; all
//   present in dwx_symbol_matrix.csv). SP500.DWX is backtest-only and not added.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1315;
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
input int    strategy_tenkan_period     = 9;     // ALMA Tenkan' window (P3-sweep 7-12)
input int    strategy_kijun_period      = 26;    // ALMA Kijun' window + cloud displacement (P3-sweep 22-34)
input int    strategy_senkou_period     = 52;    // classic Senkou Span B period
input double strategy_alma_sigma        = 6.0;   // ALMA Gaussian sigma (Legoux default, fixed)
input double strategy_alma_offset       = 0.85;  // ALMA Gaussian offset (Legoux default, fixed)
input int    strategy_cross_window      = 3;     // Tenkan'/Kijun' cross allowed within prior N bars
input int    strategy_macro_ema         = 200;   // H1 macro-bias EMA (P3-sweep 150-250)
input int    strategy_atr_period        = 14;    // ATR period (stop buffer / cap / target)
input double strategy_sl_atr_buffer     = 0.5;   // stop buffer beyond Kijun' = mult * ATR
input double strategy_sl_atr_cap        = 3.0;   // max stop distance = mult * ATR (P3-sweep 2.0-4.0)
input double strategy_tp_atr_mult       = 2.5;   // take-profit distance = mult * ATR (P3-sweep 1.5-4.0)
input int    strategy_session_start_hr  = 6;     // session open (broker hour, inclusive)
input int    strategy_session_end_hr    = 21;    // session close (broker hour, exclusive)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// ALMA of close over the last `window` closed bars, ending at `base_shift`.
// base_shift = the NEWEST bar in the window (e.g. 1 = last closed bar).
// Returns 0.0 if inputs are degenerate or any close read is invalid.
// -----------------------------------------------------------------------------
double ALMA_Close(const int window, const int base_shift)
  {
   if(window < 2)
      return 0.0;

   const double m = strategy_alma_offset * (double)(window - 1);
   const double s = (double)window / strategy_alma_sigma;
   if(s <= 0.0)
      return 0.0;
   const double two_s2 = 2.0 * s * s;

   double wsum   = 0.0;
   double sum    = 0.0;
   for(int i = 0; i < window; ++i)        // i: 0 = oldest ... window-1 = newest
     {
      const double diff = (double)i - m;
      const double w    = MathExp(-(diff * diff) / two_s2);
      // newest bar (i = window-1) -> close[base_shift]; oldest -> close[base_shift+window-1]
      const int    shift = base_shift + (window - 1 - i);
      const double px    = iClose(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar read
      if(px <= 0.0)
         return 0.0;
      wsum += w;
      sum  += w * px;
     }
   if(wsum <= 0.0)
      return 0.0;
   return sum / wsum;
  }

// SenkouA aligned to a closed bar = (ALMA Tenkan' + ALMA Kijun')/2 computed
// `kijun` bars BEFORE that bar (forward projection by kijun bars). For the bar at
// shift `bar_shift`, the cloud value under it was computed at base_shift = bar_shift + kijun.
double SenkouA_AtBar(const int bar_shift)
  {
   const int src = bar_shift + strategy_kijun_period;
   const double t = ALMA_Close(strategy_tenkan_period, src);
   const double k = ALMA_Close(strategy_kijun_period,  src);
   if(t <= 0.0 || k <= 0.0)
      return 0.0;
   return 0.5 * (t + k);
  }

// Classic Senkou Span B aligned to a closed bar. The QM buffer stores Span B
// displaced +kijun forward, so the value under the bar at shift `bar_shift` is
// read at buffer shift (bar_shift + kijun) — same idiom as QM5_11574.
double SenkouB_AtBar(const int bar_shift)
  {
   const int sshift = bar_shift + strategy_kijun_period;
   return QM_Ichimoku_SenkouSpanB(_Symbol, _Period,
                                  strategy_tenkan_period,
                                  strategy_kijun_period,
                                  strategy_senkou_period,
                                  sshift);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time) + spread guard.
// Fail-open on .DWX zero modeled spread; never block on zero spread.
bool Strategy_NoTradeFilter()
  {
   // --- Session window in BROKER time (06:00-21:00) ---
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);   // TimeCurrent() = broker time in the tester
   if(strategy_session_start_hr <= strategy_session_end_hr)
     {
      if(dt.hour < strategy_session_start_hr || dt.hour >= strategy_session_end_hr)
         return true;
     }
   else
     {
      // wrap-around window (not used by defaults, but kept safe)
      if(dt.hour < strategy_session_start_hr && dt.hour >= strategy_session_end_hr)
         return true;
     }

   // --- Spread guard relative to the ATR-derived stop distance ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_atr_cap * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // only a genuinely wide spread blocks

   return false;
  }

// ALMA-Ichimoku entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar close for cloud STATE + Chikou + macro bias ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Cloud STATE aligned to the last closed bar (shift 1) ---
   const double senkou_a = SenkouA_AtBar(1);
   const double senkou_b = SenkouB_AtBar(1);
   if(senkou_a <= 0.0 || senkou_b <= 0.0)
      return false;

   const double kumo_top = MathMax(senkou_a, senkou_b);
   const double kumo_bot = MathMin(senkou_a, senkou_b);
   const bool   bull_kumo = (senkou_a > senkou_b);
   const bool   bear_kumo = (senkou_a < senkou_b);

   const bool price_above_kumo = (close1 > kumo_top);
   const bool price_below_kumo = (close1 < kumo_bot);

   // --- ALMA Tenkan'/Kijun' at the last closed bar (shift 1) for the trigger ---
   const double tenkan1 = ALMA_Close(strategy_tenkan_period, 1);
   const double kijun1  = ALMA_Close(strategy_kijun_period,  1);
   if(tenkan1 <= 0.0 || kijun1 <= 0.0)
      return false;

   // --- Trigger EVENT: a Tenkan'/Kijun' cross at shift 1 OR within the prior
   //     cross_window bars. Long needs Tenkan' below-or-equal Kijun' at some
   //     shift w in [2 .. cross_window+1] AND Tenkan' > Kijun' at shift 1. ---
   const bool tk_long_now  = (tenkan1 > kijun1);
   const bool tk_short_now = (tenkan1 < kijun1);

   bool cross_up   = false;
   bool cross_down = false;
   if(tk_long_now || tk_short_now)
     {
      const int last_w = strategy_cross_window + 1; // inspect shifts 2 .. cross_window+1
      for(int w = 2; w <= last_w; ++w)
        {
         const double t_w = ALMA_Close(strategy_tenkan_period, w);
         const double k_w = ALMA_Close(strategy_kijun_period,  w);
         if(t_w <= 0.0 || k_w <= 0.0)
            continue;
         if(tk_long_now && t_w <= k_w)
           {
            cross_up = true;
            break;
           }
         if(tk_short_now && t_w >= k_w)
           {
            cross_down = true;
            break;
           }
        }
     }
   if(!cross_up && !cross_down)
      return false;

   // --- Macro bias: close vs H1 EMA(macro_ema) ---
   const double macro_ema = QM_EMA(_Symbol, _Period, strategy_macro_ema, 1);
   if(macro_ema <= 0.0)
      return false;

   // --- Chikou clear: close[1] vs high/low kijun bars ago ---
   const int    chikou_shift = 1 + strategy_kijun_period;
   const double high_back = iHigh(_Symbol, _Period, chikou_shift); // perf-allowed: single read
   const double low_back  = iLow(_Symbol, _Period, chikou_shift);  // perf-allowed: single read
   if(high_back <= 0.0 || low_back <= 0.0)
      return false;

   QM_OrderType side;
   string reason;
   // LONG: above bull cloud + fresh up-cross + Chikou clears prior high + above macro EMA.
   if(price_above_kumo && bull_kumo && cross_up &&
      close1 > high_back && close1 > macro_ema)
     {
      side   = QM_BUY;
      reason = "alma_ichi_long";
     }
   // SHORT: mirror.
   else if(price_below_kumo && bear_kumo && cross_down &&
           close1 < low_back && close1 < macro_ema)
     {
      side   = QM_SELL;
      reason = "alma_ichi_short";
     }
   else
      return false;

   // --- Entry price (market) ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: Kijun'[1] buffered by sl_atr_buffer*ATR, capped at sl_atr_cap*ATR ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double buffer_dist = strategy_sl_atr_buffer * atr_value;
   const double cap_dist    = strategy_sl_atr_cap * atr_value;
   if(cap_dist <= 0.0)
      return false;

   double sl;
   if(side == QM_BUY)
     {
      sl = kijun1 - buffer_dist;
      // Cap maximum SL distance below entry.
      if(entry - sl > cap_dist)
         sl = entry - cap_dist;
     }
   else
     {
      sl = kijun1 + buffer_dist;
      if(sl - entry > cap_dist)
         sl = entry + cap_dist;
     }
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // Reject a degenerate / wrong-side stop.
   const double stop_dist = MathAbs(entry - sl);
   if(stop_dist <= 0.0)
      return false;
   if(side == QM_BUY  && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   // --- Take profit = tp_atr_mult * ATR from entry ---
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// No active trade management beyond the fixed ATR-capped stop / ATR target.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: Tenkan'/Kijun' cross AGAINST the position, OR price
// re-enters the Kumo against the position. Evaluated on the closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine current position direction for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   // --- Tenkan'/Kijun' relation at the last closed bar ---
   const double tenkan1 = ALMA_Close(strategy_tenkan_period, 1);
   const double kijun1  = ALMA_Close(strategy_kijun_period,  1);
   if(tenkan1 <= 0.0 || kijun1 <= 0.0)
      return false;

   // --- Price vs Kumo at the last closed bar ---
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double senkou_a = SenkouA_AtBar(1);
   const double senkou_b = SenkouB_AtBar(1);
   if(close1 <= 0.0 || senkou_a <= 0.0 || senkou_b <= 0.0)
      return false;
   const double kumo_top = MathMax(senkou_a, senkou_b);
   const double kumo_bot = MathMin(senkou_a, senkou_b);

   if(is_long)
     {
      // BUY closes on Tenkan' < Kijun' OR close re-enters below the Kumo.
      if(tenkan1 < kijun1)
         return true;
      if(close1 < kumo_bot)
         return true;
     }
   else // is_short
     {
      // SELL closes on Tenkan' > Kijun' OR close re-enters above the Kumo.
      if(tenkan1 > kijun1)
         return true;
      if(close1 > kumo_top)
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
