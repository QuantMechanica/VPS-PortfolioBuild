#property strict
#property version   "5.0"
#property description "QM5_11246 ht-kalman-bb — Kalman dynamic-hedge-ratio forecast-error band pairs trade (H4, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11246 ht-kalman-bb
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Kalman Filter", ArbitrageLab documentation
// (source_id af021dd0-e07d-5f72-9933-de7a3533934e); primary reference Ernest P.
// Chan (2013), "Algorithmic Trading". Card:
// artifacts/cards_approved/QM5_11246_ht-kalman-bb.md (g0 APPROVED).
//
// RELATIVE-VALUE PAIRS TRADE (BASKET EA) driven by a DETERMINISTIC Kalman filter.
// On each completed H4 bar the EA runs the standard linear Kalman recursion FORWARD
// over the last `Period` closed bars to estimate a DYNAMIC hedge ratio between the
// host (y) and partner (x) legs, with FIXED process/observation covariances (no
// learning, no PnL adaptation — HR14 compliant). The recursion is the textbook
// predict/update of Chan (2013):
//
//   State  b = [intercept, hedge_ratio]   (2-vector)
//   Cov    P (2x2), seeded large/diagonal (diffuse prior)
//   Obs    y(t) = host close,  regressor x(t) = [1, partner close]
//
//   PREDICT:  b unchanged;  P += transition_covariance * I        (random-walk state)
//   FORECAST: e(t) = y(t) - x(t).b           (forecast error / innovation)
//             Q(t) = x(t) P x(t)' + observation_covariance   (forecast variance)
//   UPDATE:   K = P x(t)' / Q(t)             (Kalman gain)
//             b += K e(t);   P -= K (x(t) P)
//
// The traded spread is the forecast error e(t) (= y - hedge_ratio*x - intercept),
// banded by its own standard error sqrt(Q(t)):
//
//   e(t) < -entry_std * sqrt(Q)  -> spread CHEAP -> LONG  spread: BUY host + SELL partner
//   e(t) > +entry_std * sqrt(Q)  -> spread RICH  -> SHORT spread: SELL host + BUY partner
//
// Exit (mean-reversion to the band): close LONG  when e(t) >= -exit_std*sqrt(Q),
// close SHORT when e(t) <= +exit_std*sqrt(Q). Protective stop when |e(t)| exceeds
// stop_std*sqrt(Q). Time stop after `max_hold_bars` H4 bars. All legs close together.
//
// JUMP GUARD: skip a fresh entry if the estimated hedge ratio changed by more than
// `max_hr_jump` (fraction) between the last two closed bars — a regime break, not a
// tradeable band excursion.
//
// BASKET WIRING (identical pattern to QM5_11145_vbt-pair-z). The host leg trades
// `_Symbol` through the framework magic (slot = qm_magic_slot_offset). The partner
// leg trades a FOREIGN .DWX symbol via QM_BasketOpenPosition with its own registered
// symbol_slot. Both legs are warmed in OnInit so foreign-symbol reads return real
// data in the .DWX tester. One position per (magic, symbol).
//
// Pair model (host = leg1 = y, partner = leg2 = x), registered in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 XAUUSD.DWX (host C) / slot 5 XAGUSD.DWX (partner C)
// All six are present in dwx_symbol_matrix.csv (forex + metals). The card's
// XAUUSD/XAGUSD pair is contingent on XAGUSD availability per its R3 note — XAGUSD.DWX
// IS in the matrix, so the metals pair is registered.
//
// A setfile selects WHICH pair this instance runs by binding:
//   qm_magic_slot_offset    = host leg slot (matches the host symbol it runs on)
//   strategy_partner_symbol = the partner .DWX symbol
//   strategy_partner_slot   = the partner leg slot
// (default = pair A on EURUSD.DWX host).
//
// Only the five Strategy_* hooks + OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11246;
input int    qm_magic_slot_offset       = 0;     // HOST leg slot (= host symbol slot)
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
// Partner (leg2 = x) symbol + its registered magic slot. Host leg = _Symbol at
// qm_magic_slot_offset. Defaults bind pair A: EURUSD.DWX host / GBPUSD.DWX partner.
input string strategy_partner_symbol       = "GBPUSD.DWX";  // foreign .DWX leg2 (x)
input int    strategy_partner_slot         = 1;             // partner registered slot
input int    strategy_period               = 252;     // Kalman run-forward window (closed H4 bars; card correlation screen = 252)
input double strategy_obs_covariance       = 0.001;   // observation_covariance (card baseline; P3 {0.0005,0.001,0.002})
input double strategy_trans_covariance     = 0.0001;  // transition_covariance (card baseline; P3 {0.00005,0.0001,0.0002})
input double strategy_entry_std_score      = 3.0;     // |e| band to ENTER (card baseline; P3 {2.0,2.5,3.0})
input double strategy_exit_std_score       = 0.5;     // band to EXIT toward mean (card baseline; P3 {0.0,0.5,1.0})
input double strategy_stop_std_score       = 5.0;     // protective stop |e| band (card baseline)
input int    strategy_max_hold_bars        = 80;      // H4 time stop (card baseline; P3 {40,80,120})
input double strategy_max_hr_jump          = 0.25;    // skip entry if |hr jump| > 25% between adjacent bars
input int    strategy_min_h4_bars          = 320;     // need >= Period+buffer synced H4 bars
input double strategy_leg_risk_split       = 0.5;     // share of RISK_FIXED per leg (info only; sizing per leg)

// -----------------------------------------------------------------------------
// File-scope cached Kalman/forecast state, advanced once per closed H4 bar.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2 = x)
double   g_e_curr           = 0.0;    // last closed-bar forecast error e(t)
double   g_se_curr          = 0.0;    // last closed-bar forecast standard error sqrt(Q(t))
double   g_hr_curr          = 0.0;    // last closed-bar hedge ratio estimate
double   g_hr_prev          = 0.0;    // prior closed-bar hedge ratio (jump guard)
bool     g_ready            = false;  // both legs had clean synced data this bar

// -----------------------------------------------------------------------------
// Deterministic Kalman recursion over the last `period` CLOSED H4 bars.
//
// Runs the standard 2-state linear Kalman filter FORWARD from oldest to newest
// bar in the window. State b = [intercept, hedge_ratio]; observation y = host
// close; regressor x = [1, partner close]. Process/observation covariances are
// FIXED inputs (no learning). Returns the LAST bar's forecast error e, its
// standard error sqrt(Q), the current hedge ratio, and the prior-bar hedge ratio
// (for the jump guard). Returns false on missing/degenerate data so the EA simply
// does not trade — matching the card's "skip if data missing" rule.
// -----------------------------------------------------------------------------
bool QM_ComputeKalman(const int period,
                      double &e_out, double &se_out,
                      double &hr_out, double &hr_prev_out)
  {
   e_out = 0.0; se_out = 0.0; hr_out = 0.0; hr_prev_out = 0.0;
   if(period < 10)
      return false;
   if(strategy_obs_covariance <= 0.0 || strategy_trans_covariance <= 0.0)
      return false;

   if(Bars(_Symbol, PERIOD_H4)   < strategy_min_h4_bars) return false;   // perf-allowed: host bar-count availability check
   if(Bars(g_partner, PERIOD_H4) < strategy_min_h4_bars) return false;   // perf-allowed: partner-leg bar-count check

   // Window of `period` closed bars: oldest = shift period, newest = shift 1.
   double yv[];   // host close (y)
   double xv[];   // partner close (x)
   ArrayResize(yv, period);
   ArrayResize(xv, period);
   for(int i = 0; i < period; ++i)
     {
      // Oldest first: window index 0 = shift `period`, ... index period-1 = shift 1.
      const int shift = period - i;
      // perf-allowed: closed-bar host+partner close reads for the Kalman window;
      // computed once per closed H4 bar (OnTick gates this via QM_IsNewBar).
      const double cy = iClose(_Symbol,  PERIOD_H4, shift);   // perf-allowed: closed-bar host close for Kalman window
      const double cx = iClose(g_partner, PERIOD_H4, shift);   // perf-allowed: closed-bar partner close for Kalman window
      if(cy <= 0.0 || cx <= 0.0)
         return false;                  // missing bar inside lookback -> no trade
      yv[i] = cy;
      xv[i] = cx;
     }

   // State b = [b0 intercept, b1 hedge_ratio]; covariance P (2x2 symmetric).
   // Diffuse prior: large diagonal P, zero state. Process noise Vw = trans_cov*I
   // added each step; observation noise Ve = obs_cov.
   double b0 = 0.0, b1 = 0.0;
   double p00 = 1.0, p01 = 0.0, p10 = 0.0, p11 = 1.0;   // P seed (diffuse)
   const double ve = strategy_obs_covariance;
   const double vw = strategy_trans_covariance;

   double e_last = 0.0, q_last = 0.0;
   double hr_last = 0.0, hr_prev = 0.0;

   for(int t = 0; t < period; ++t)
     {
      // PREDICT: state random-walk (unchanged mean); add process noise to P diag.
      p00 += vw;
      p11 += vw;
      // (off-diagonals unchanged by diagonal process noise)

      // Regressor x = [1, xv[t]]; observation y = yv[t].
      const double x0 = 1.0;
      const double x1 = xv[t];
      const double y  = yv[t];

      // Forecast: yhat = x . b ; innovation e = y - yhat.
      const double yhat = b0 * x0 + b1 * x1;
      const double e    = y - yhat;

      // P x'  =>  px = P * [x0; x1]  (2-vector)
      const double px0 = p00 * x0 + p01 * x1;
      const double px1 = p10 * x0 + p11 * x1;

      // Forecast variance Q = x P x' + Ve.
      const double q = x0 * px0 + x1 * px1 + ve;
      if(q <= 1e-18)
         return false;                  // degenerate forecast variance -> no trade

      // Kalman gain K = P x' / Q  (2-vector).
      const double k0 = px0 / q;
      const double k1 = px1 / q;

      // UPDATE state: b += K e.
      hr_prev = b1;                      // hedge ratio BEFORE this update (prior bar)
      b0 += k0 * e;
      b1 += k1 * e;

      // UPDATE covariance: P -= K (x P).  x P = (P x')' = [px0, px1] (P symmetric).
      // K (xP) is the outer product [k0;k1] * [px0, px1].
      p00 -= k0 * px0;
      p01 -= k0 * px1;
      p10 -= k1 * px0;
      p11 -= k1 * px1;

      e_last  = e;
      q_last  = q;
      hr_last = b1;
     }

   if(q_last <= 0.0)
      return false;

   e_out       = e_last;
   se_out      = MathSqrt(q_last);
   hr_out      = hr_last;
   hr_prev_out = hr_prev;               // hedge ratio one update before the last
   return true;
  }

// Advance cached Kalman/forecast state once per closed H4 bar.
void QM_AdvanceKalmanState()
  {
   double e = 0.0, se = 0.0, hr = 0.0, hrp = 0.0;
   if(QM_ComputeKalman(strategy_period, e, se, hr, hrp))
     {
      g_e_curr  = e;
      g_se_curr = se;
      g_hr_curr = hr;
      g_hr_prev = hrp;
      g_ready   = true;
     }
   else
     {
      g_ready = false;
     }
  }

// Count open positions for an arbitrary (slot,symbol) leg of THIS ea_id.
int QM_LegOpenCount(const int slot, const string sym)
  {
   const int magic = QM_Magic(qm_ea_id, slot);
   if(magic <= 0)
      return 0;
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      ++c;
     }
   return c;
  }

// True if EITHER leg of the pair currently holds a position.
bool QM_PairHasPosition()
  {
   if(QM_LegOpenCount(qm_magic_slot_offset, _Symbol) > 0)
      return true;
   if(QM_LegOpenCount(strategy_partner_slot, g_partner) > 0)
      return true;
   return false;
  }

// Direction of the open HOST leg: +1 host long (long-spread), -1 host short
// (short-spread), 0 none.
int QM_HostLegDir()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
     }
   return 0;
  }

// Bars held by the host leg (H4), or -1 if no host position.
int QM_HostLegBarsHeld()
  {
   const int magic = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   if(magic <= 0)
      return -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      // perf-allowed: single bar-open time read for the time-stop bar count.
      const datetime cur_bar = iTime(_Symbol, PERIOD_H4, 0);   // perf-allowed: bar-open time for time-stop count
      if(open_time <= 0 || cur_bar <= 0)
         return 0;
      return Bars(_Symbol, PERIOD_H4, open_time, cur_bar) - 1;  // perf-allowed: bars-held count for time stop
     }
   return -1;
  }

// Close every leg of the pair (host + partner) under this ea_id.
void QM_ClosePair(const QM_ExitReason reason)
  {
   const int host_magic    = QM_Magic(qm_ea_id, qm_magic_slot_offset);
   const int partner_magic = QM_Magic(qm_ea_id, strategy_partner_slot);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      const long m = PositionGetInteger(POSITION_MAGIC);
      if(m == host_magic || m == partner_magic)
         QM_TM_ClosePosition(ticket, reason);
     }
  }

// Open the partner (leg2 = x) market order on the FOREIGN symbol via the basket path.
bool QM_OpenPartnerLeg(const QM_OrderType ot, const string reason)
  {
   QM_BasketOrderRequest br;
   br.symbol             = g_partner;
   br.type               = ot;
   br.price              = 0.0;     // basket path fills market price at send
   br.sl                 = 0.0;     // pair-level exits manage the position
   br.tp                 = 0.0;
   br.lots               = 0.0;     // 0 -> basket sizes via QM_LotsForRisk(partner, sl_pts)
   br.reason             = reason;
   br.symbol_slot        = strategy_partner_slot;
   br.expiration_seconds = 0;

   ulong tk = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, br, tk);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter. Fail-OPEN spread guard on the host leg only; the
// Kalman logic runs on closed bars. No session restriction (H4 pairs).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                     // no valid quote — defer, never block
   // Block only a genuinely wide modeled spread (zero modeled .DWX spread passes).
   const double atr = QM_ATR(_Symbol, PERIOD_H4, 14, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > 0.50 * atr)   // >50% of H4 ATR = pathological
      return true;
   return false;
  }

// Entry on a freshly closed H4 bar. The host leg is opened here through the
// framework path; the partner leg is opened immediately via the basket path so
// both legs go on together. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One pair state at a time: skip if either leg already open.
   if(QM_PairHasPosition())
      return false;
   if(!g_ready)
      return false;
   if(g_se_curr <= 0.0)
      return false;

   // Hedge-ratio jump guard: skip if the hedge ratio shifted too much between the
   // last two closed bars (regime break, not a tradeable band excursion).
   if(MathAbs(g_hr_prev) > 1e-9)
     {
      const double jump = MathAbs(g_hr_curr - g_hr_prev) / MathAbs(g_hr_prev);
      if(jump > strategy_max_hr_jump)
         return false;
     }

   const double band = strategy_entry_std_score * g_se_curr;
   int dir = 0;                         // +1 long-spread, -1 short-spread
   if(g_e_curr < -band)
      dir = +1;                         // e below -entry band -> spread cheap -> LONG spread
   else if(g_e_curr > band)
      dir = -1;                         // e above +entry band -> spread rich -> SHORT spread
   if(dir == 0)
      return false;

   // Host (leg1) direction: long-spread -> BUY host; short-spread -> SELL host.
   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY : QM_SELL;
   // Partner (leg2) takes the OPPOSITE side for market-neutral exposure.
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open the partner leg FIRST through the basket path. If it fails (e.g. data
   // gap), abort the pair so we never carry a naked single leg.
   const string rsn = (dir > 0) ? "kalman_long_spread" : "kalman_short_spread";
   if(!QM_OpenPartnerLeg(partner_ot, rsn))
      return false;

   // Build the host leg for the framework to send. No fixed SL/TP — the pair is
   // managed by the forecast-error / stop / time-stop exits at the basket level.
   req.type        = host_ot;
   req.price       = 0.0;               // framework fills market price at send
   req.sl          = 0.0;
   req.tp          = 0.0;
   req.reason      = rsn;
   req.symbol_slot = qm_magic_slot_offset;  // host leg slot
   return true;
  }

// No active per-position trade management; pair exits are rule-based.
void Strategy_ManageOpenPosition()
  {
  }

// Pair-level exits: forecast-error mean-reversion (exit band), |e| protective
// stop, time stop. Returning true triggers the framework's host-leg close loop in
// OnTick; we ALSO close the partner leg here so the whole pair unwinds together.
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long-spread, -1 short-spread, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_ready && g_se_curr > 0.0)
     {
      const double e         = g_e_curr;
      const double exit_band = strategy_exit_std_score * g_se_curr;
      const double stop_band = strategy_stop_std_score * g_se_curr;

      // Mean-reversion exit toward the band:
      //   LONG  spread (host long): entered at e < -entry; close when e >= -exit_band.
      //   SHORT spread (host short): entered at e > +entry; close when e <= +exit_band.
      if(host_dir > 0 && e >= -exit_band) { do_exit = true; reason = QM_EXIT_STRATEGY; }
      if(host_dir < 0 && e <=  exit_band) { do_exit = true; reason = QM_EXIT_STRATEGY; }

      // Protective stop: |e| expanded beyond the stop band.
      if(!do_exit && MathAbs(e) > stop_band)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
     }

   // Time stop: close the pair after N H4 bars held.
   if(!do_exit)
     {
      const int held = QM_HostLegBarsHeld();
      if(held >= 0 && held >= strategy_max_hold_bars)
        { do_exit = true; reason = QM_EXIT_TIME_STOP; }
     }

   if(do_exit)
     {
      // Close the PARTNER leg here; the OnTick close loop closes the host leg.
      const int partner_magic = QM_Magic(qm_ea_id, strategy_partner_slot);
      if(partner_magic > 0)
        {
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))
               continue;
            if(PositionGetInteger(POSITION_MAGIC) != partner_magic)
               continue;
            QM_TM_ClosePosition(ticket, reason);
           }
        }
      return true;
     }
   return false;
  }

// Defer to the central two-axis news filter.
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

   // Resolve the partner leg. If blank or equal to the host, the pair is
   // degenerate and the EA simply never trades (still a valid, safe init).
   g_partner = strategy_partner_symbol;
   if(StringLen(g_partner) == 0)
      g_partner = _Symbol;

   // BASKET wiring: register host + partner and warm their H4 history so the
   // foreign-symbol close reads return real data in the .DWX tester.
   string universe[];
   if(g_partner == _Symbol)
     {
      ArrayResize(universe, 1);
      universe[0] = _Symbol;
     }
   else
     {
      ArrayResize(universe, 2);
      universe[0] = _Symbol;
      universe[1] = g_partner;
     }
   QM_SymbolGuardInit(universe);
   QM_BasketWarmupHistory(universe, PERIOD_H4, strategy_period + 80);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"partner\":\"%s\",\"host_slot\":%d,\"partner_slot\":%d,\"period\":%d}",
                            _Symbol, g_partner, qm_magic_slot_offset,
                            strategy_partner_slot, strategy_period));
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

   // Latch the closed-bar event ONCE (single-consume) and reuse it. On a fresh
   // H4 bar, refresh the Kalman state BEFORE the rule-based exit so the exit sees
   // the current forecast error.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceKalmanState();

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

   if(!nb)
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
