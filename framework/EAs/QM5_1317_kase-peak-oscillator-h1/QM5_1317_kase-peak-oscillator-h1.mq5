#property strict
#property version   "5.0"
#property description "QM5_1317 kase-peak-oscillator-h1 — Kase Peak Oscillator confirmed peak/trough entry (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1317 kase-peak-oscillator-h1
// -----------------------------------------------------------------------------
// Source: Cynthia A. Kase, "Trading with the Odds: Using the Power of
//   Probability to Profit in the Futures Market" (McGraw-Hill 1996,
//   ISBN 0-7863-0911-1) — Kase Peak Oscillator (KPO). FF Trading-Systems Kase
//   cluster (source_id 6e967762-b26d-59a3-b076-35c17f2e7c36).
// Card: artifacts/cards_approved/QM5_1317_kase-peak-oscillator-h1.md (g0 APPROVED).
//
// KPO — vol-normalized statistical-momentum oscillator (computed in-EA; no
// built-in indicator handle exists for it):
//
//   KaseDev_n(s) = (close[s] - close[s+n]) / (ATR(n, s) * sqrt(n))
//                  n-bar displacement normalized by the n-bar ATR scaled by
//                  sqrt(n) (Kase's 1996 random-walk volatility normalization).
//   KaseRaw(s)   = KaseDev_8(s) + KaseDev_21(s) + KaseDev_55(s)
//   KPO(s)       = EMA(KaseRaw, kpo_smooth)(s)        // smoothed peak oscillator
//   KPO_signal(s)= EMA(KPO,     sig_smooth)(s)        // signal line
//
// KPO oscillates around zero; magnitude = vol-normalized momentum strength.
// The EMAs of the derived KaseRaw / KPO series are reconstructed by a bounded
// recursive EMA seeded over a fixed warmup window on the CLOSED-BAR path only
// (Strategy_EntrySignal/ExitSignal run under the QM_IsNewBar gate). No raw
// indicator handles, no CopyBuffer; ATR is read via the pooled QM_ATR reader.
//
//   Entry (BUY) on the H1 close (confirmed trough was the prior bar [1]):
//     1. Confirmed KPO trough at bar [1]:  KPO[1] < KPO[2] AND KPO[1] < KPO[0]
//        (KPO[1] is a local trough — lower than both neighbours).            STATE
//     2. Trough in the extreme bearish zone:  KPO[1] < -extreme_z.           STATE
//     3. Signal-line cross UP = the single trigger EVENT:
//          KPO[0] > KPO_signal[0]  AND  KPO[1] <= KPO_signal[1].             EVENT
//     4. Macro bias agreement:  close[1] > EMA(close, macro).               STATE
//   SELL mirrors: confirmed peak (KPO[1] > both neighbours), KPO[1] > +extreme_z,
//        signal-cross DOWN, close[1] < EMA(macro).
//
//   Only the signal-line cross is an EVENT; the confirmed peak/trough, the
//   extreme-zone magnitude, and the macro-bias are STATES — so there is no
//   two-fresh-cross-same-bar zero-trade trap.
//
//   Exit (closed-bar, any of):
//     - Opposite confirmed peak/trough in the extreme zone (BUY closes on a
//       confirmed peak with KPO[1] > +extreme_z; SELL mirror).
//     - KPO zero-cross against the position (Kase's momentum-vanishing exit):
//       BUY closes when KPO crosses below zero; SELL mirror above zero.
//   Stop : recent-N-bar extreme -/+ sl_atr_buf * ATR (structural stop).
//   Take : tp_atr_mult * ATR from entry, expressed via QM_TakeRR off the stop.
//
//   Session     : trade only inside [session_start_h, session_end_h) broker
//                 time (06:00-21:00). O(1) per-tick gate.
//   Spread guard: only a genuinely wide spread blocks (fail-OPEN on .DWX zero
//                 modeled spread, ask == bid).
//   Re-arm      : one position per magic + the KPO zero-cross exit means the
//                 same-side extreme cannot re-stack while a position is open;
//                 after the zero-cross exit a fresh confirmed-extreme + signal
//                 cross is required to re-enter.
//
//   One position per magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no
//   external feed, $0-swap-independent (pure price/vol-normalized momentum rule).
//   All KPO math is fixed closed-form over bounded closed-bar windows —
//   transparent non-ML computation (HR14 compliant).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1317;
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
input int    strategy_kase_n_short       = 8;      // short KaseDev window (P3 sweep 6-11)
input int    strategy_kase_n_med         = 21;     // medium KaseDev window (P3 sweep 15-28)
input int    strategy_kase_n_long        = 55;     // long KaseDev window (P3 sweep 38-72)
input int    strategy_kpo_smooth         = 9;      // EMA smoothing of KaseRaw -> KPO (P3 7-12)
input int    strategy_sig_smooth         = 5;      // EMA of KPO -> signal line (P3 3-7)
input double strategy_extreme_z          = 1.0;    // |KPO| extreme-zone threshold (P3 0.7-1.5)
input int    strategy_macro_ema_period   = 200;    // macro-bias EMA gate (P3 150-250)
input int    strategy_atr_period         = 14;     // ATR period for stop/target
input double strategy_tp_atr_mult        = 2.5;    // take profit = mult * ATR from entry (P3 1.5-4.0)
input double strategy_sl_atr_buf         = 1.0;    // stop buffer = mult * ATR beyond extreme (P3 0.5-1.5)
input int    strategy_struct_lookback    = 4;      // recent-bar extreme window for the stop (4-bar)
input int    strategy_session_start_h    = 6;      // broker-hour session open (inclusive)
input int    strategy_session_end_h      = 21;     // broker-hour session close (exclusive)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers — Kase Peak Oscillator computed in-EA.
// -----------------------------------------------------------------------------

// KaseDev for one window n at a closed-bar shift: vol-normalized n-bar
// displacement. (close[shift] - close[shift+n]) / (ATR(n, shift) * sqrt(n)).
// Fail-closed (ok=false) on any warmup / invalid read.
double KaseDevAt(const int n, const int shift, bool &ok)
  {
   ok = false;
   if(n < 1)
      return 0.0;
   const double c0 = iClose(_Symbol, _Period, shift);     // perf-allowed: single closed-bar read
   const double cn = iClose(_Symbol, _Period, shift + n); // perf-allowed: single closed-bar read
   if(c0 <= 0.0 || cn <= 0.0)
      return 0.0;
   const double atr_n = QM_ATR(_Symbol, _Period, n, shift);
   if(atr_n <= 0.0)
      return 0.0;
   const double denom = atr_n * MathSqrt((double)n);
   if(denom <= 0.0)
      return 0.0;
   ok = true;
   return (c0 - cn) / denom;
  }

// KaseRaw at a closed-bar shift: sum of the three KaseDev windows.
double KaseRawAt(const int shift, bool &ok)
  {
   ok = false;
   bool s_ok=false, m_ok=false, l_ok=false;
   const double ks = KaseDevAt(strategy_kase_n_short, shift, s_ok);
   const double km = KaseDevAt(strategy_kase_n_med,   shift, m_ok);
   const double kl = KaseDevAt(strategy_kase_n_long,  shift, l_ok);
   if(!(s_ok && m_ok && l_ok))
      return 0.0;
   ok = true;
   return ks + km + kl;
  }

// EMA of KaseRaw -> KPO at a closed-bar shift. Recursive EMA reconstructed over
// a bounded warmup window (warmup * kpo_smooth bars deep), seeded by the oldest
// KaseRaw read and rolled forward to `shift`. Closed-bar path only.
double KPOAt(const int shift, bool &ok)
  {
   ok = false;
   const int p = strategy_kpo_smooth;
   if(p < 1)
      return 0.0;
   const double alpha = 2.0 / (double)(p + 1);
   // Warmup depth: enough bars for the EMA to converge (5*period is ample).
   const int warmup = 5 * p;
   const int oldest = shift + warmup;
   bool seed_ok = false;
   double ema = KaseRawAt(oldest, seed_ok);
   if(!seed_ok)
      return 0.0;
   for(int s = oldest - 1; s >= shift; --s)
     {
      bool r_ok = false;
      const double raw = KaseRawAt(s, r_ok);
      if(!r_ok)
         return 0.0;
      ema = alpha * raw + (1.0 - alpha) * ema;
     }
   ok = true;
   return ema;
  }

// EMA of KPO -> signal line at a closed-bar shift. Same bounded recursive seed,
// one level deeper (each KPO read itself spans a warmup window). Closed-bar only.
double KPOSignalAt(const int shift, bool &ok)
  {
   ok = false;
   const int p = strategy_sig_smooth;
   if(p < 1)
      return 0.0;
   const double alpha = 2.0 / (double)(p + 1);
   const int warmup = 5 * p;
   const int oldest = shift + warmup;
   bool seed_ok = false;
   double ema = KPOAt(oldest, seed_ok);
   if(!seed_ok)
      return 0.0;
   for(int s = oldest - 1; s >= shift; --s)
     {
      bool k_ok = false;
      const double k = KPOAt(s, k_ok);
      if(!k_ok)
         return 0.0;
      ema = alpha * k + (1.0 - alpha) * ema;
     }
   ok = true;
   return ema;
  }

// Broker-time session gate: true if `broker_now` is inside the [start, end) hour
// window. Wrap-safe. O(1).
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

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + spread guard. The KPO computation
// is on the closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero
// modeled spread (ask == bid).
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

   const double stop_distance = strategy_tp_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// KPO confirmed-trough/peak + signal-cross entry. Caller guarantees
// QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- KPO + signal at shifts 0, 1, 2 (closed-bar path) ---
   bool k0_ok=false, k1_ok=false, k2_ok=false, s0_ok=false, s1_ok=false;
   const double kpo0 = KPOAt(0, k0_ok);
   const double kpo1 = KPOAt(1, k1_ok);
   const double kpo2 = KPOAt(2, k2_ok);
   const double sig0 = KPOSignalAt(0, s0_ok);
   const double sig1 = KPOSignalAt(1, s1_ok);
   if(!(k0_ok && k1_ok && k2_ok && s0_ok && s1_ok))
      return false; // warmup / unavailable -> no trade

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double macro  = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(close1 <= 0.0 || macro <= 0.0)
      return false;

   // --- Confirmed local extreme at bar [1] (lower/higher than both neighbours) ---
   const bool confirmed_trough = (kpo1 < kpo2 && kpo1 < kpo0);  // STATE
   const bool confirmed_peak   = (kpo1 > kpo2 && kpo1 > kpo0);  // STATE

   // --- Extreme-zone magnitude (only act on extended extremes) ---
   const bool trough_extreme = (kpo1 < -strategy_extreme_z);    // STATE
   const bool peak_extreme   = (kpo1 >  strategy_extreme_z);    // STATE

   // --- Signal-line cross = the single trigger EVENT ---
   const bool cross_up   = (kpo0 > sig0 && kpo1 <= sig1);       // EVENT
   const bool cross_down = (kpo0 < sig0 && kpo1 >= sig1);       // EVENT

   // --- Macro bias agreement ---
   const bool macro_long  = (close1 > macro);                   // STATE
   const bool macro_short = (close1 < macro);                   // STATE

   QM_OrderType dir;
   double entry;

   if(confirmed_trough && trough_extreme && cross_up && macro_long)
     {
      dir   = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else if(confirmed_peak && peak_extreme && cross_down && macro_short)
     {
      dir   = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   else
      return false;

   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Stop: recent-N-bar extreme +/- buffer*ATR (structural stop) ---
   const int lb = (strategy_struct_lookback > 0 ? strategy_struct_lookback : 4);
   double hh = -DBL_MAX, ll = DBL_MAX;
   for(int s = 1; s <= lb; ++s)
     {
      const double hi = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar structure window
      const double lo = iLow(_Symbol, _Period, s);  // perf-allowed
      if(hi <= 0.0 || lo <= 0.0)
         return false;
      if(hi > hh) hh = hi;
      if(lo < ll) ll = lo;
     }

   double sl;
   if(dir == QM_BUY)
      sl = ll - strategy_sl_atr_buf * atr_value;
   else
      sl = hh + strategy_sl_atr_buf * atr_value;
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // --- Take profit: tp_atr_mult * ATR from entry, expressed via RR off the
   //     structural stop so the framework's price normalization applies. ---
   const double sl_dist = MathAbs(entry - sl);
   if(sl_dist <= 0.0)
      return false;
   const double rr = (strategy_tp_atr_mult * atr_value) / sl_dist;
   if(rr <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "kpo_confirmed_extreme_signal_cross";
   return true;
  }

// Primary exits are the broker-side structural stop and ATR target; no active
// management (trailing/BE) per the card.
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar exits: opposite confirmed extreme-zone peak/trough OR KPO zero-cross
// against the position. Caller closes the magic's positions when this returns true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this magic's open position to read its direction.
   bool have_pos = false;
   long pos_type = -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type = PositionGetInteger(POSITION_TYPE);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   bool k0_ok=false, k1_ok=false, k2_ok=false;
   const double kpo0 = KPOAt(0, k0_ok);
   const double kpo1 = KPOAt(1, k1_ok);
   const double kpo2 = KPOAt(2, k2_ok);
   if(!(k0_ok && k1_ok && k2_ok))
      return false;

   // --- Opposite confirmed extreme-zone peak/trough ---
   const bool confirmed_peak   = (kpo1 > kpo2 && kpo1 > kpo0 && kpo1 >  strategy_extreme_z);
   const bool confirmed_trough = (kpo1 < kpo2 && kpo1 < kpo0 && kpo1 < -strategy_extreme_z);
   if(pos_type == POSITION_TYPE_BUY  && confirmed_peak)
      return true;
   if(pos_type == POSITION_TYPE_SELL && confirmed_trough)
      return true;

   // --- KPO zero-cross against the position (momentum-vanishing exit) ---
   // BUY closes when KPO crosses below zero; SELL when it crosses above.
   if(pos_type == POSITION_TYPE_BUY  && kpo1 >= 0.0 && kpo0 < 0.0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && kpo1 <= 0.0 && kpo0 > 0.0)
      return true;

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
