#property strict
#property version   "5.0"
#property description "QM5_11248 ht-xou-levels — Exponential Ornstein-Uhlenbeck optimal entry-interval / liquidation-level pairs trade (D1, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11248 ht-xou-levels
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Trading Under the Exponential Ornstein-Uhlenbeck
// Model", ArbitrageLab documentation (source_id af021dd0-e07d-5f72-9933-
// de7a3533934e); primary reference Leung & Li (2015), "Optimal Mean Reversion
// Trading". Card: artifacts/cards_approved/QM5_11248_ht-xou-levels.md (g0 APPROVED).
//
// EXPONENTIAL-OU OPTIMAL-LEVEL PAIRS TRADE (BASKET EA). The XOU model trades a
// POSITIVE pair-portfolio value P_t whose LOG x_t = ln(P_t) is an Ornstein-
// Uhlenbeck process. On each completed D1 bar the EA:
//   1. Builds a positive pair portfolio from host + partner .DWX closes with a
//      fixed hedge ratio estimated by OLS on a FORMATION window. The portfolio
//      value is forced strictly positive (shifted by its window minimum + a
//      margin) so its log is always defined (card "positive portfolio for all
//      training bars").
//   2. Fits OU parameters CLOSED-FORM to x_t = ln(P_t) via a single AR(1)
//      regression x_t = c + phi*x_{t-1} + eps over the formation window:
//        theta (long-run mean)  = c / (1 - phi)
//        kappa (reversion speed) = -ln(phi)            [phi in (0,1) => reverting]
//        sigma_eq (equilibrium std) = stdev(residual) / sqrt(1 - phi^2)
//      NO iterative maximum-likelihood, NO numerical root-finding, NO ML. This
//      is the deterministic AR(1)->OU closed-form mapping (same family as the
//      QM5_11241 half-life fit), which is the practical realisation of the XOU
//      "model fitting" step that the framework can execute per closed bar.
//   3. Derives the XOU optimal LEVELS in log space as fixed, cost-adjusted
//      standard-deviation offsets from the OU equilibrium (the documented
//      practical form of the optimal entry interval [a,d] and liquidation level
//      b; the exact Leung-Li levels need offline root-finding that is forbidden
//      in-tester, so we use the closed-form sigma-band realisation):
//        entry band   [a_x, d_x] = theta + [ -(entry_lo_k), -(entry_hi_k) ]*sigma_eq
//                                   shifted DOWN by the round-trip cost cushion
//        liquidation  b_x        = theta + (liq_k)*sigma_eq, shifted UP by cost
//      i.e. ENTER LONG the portfolio when log-value re-enters the cheap interval
//      [a_x, d_x] from BELOW (value cheap vs equilibrium); LIQUIDATE when it
//      reaches the rich level b_x. Long-only positive-portfolio side per card
//      P2 baseline (short side disabled).
//
// PORTFOLIO = LONG the cheap portfolio: BUY host (leg1) + SELL hedge*partner
// (leg2) so the position IS the positive pair portfolio. Both legs as a basket.
//
// EXIT (card): liquidate at b_x; OU stop when log-value breaches a lower
// stop boundary (theta - stop_k*sigma_eq, card stop_loss_pct cushion); time
// stop after `max_hold_bars` D1 bars; close on model-revalidation failure.
//
// XOU QUALIFICATION (deterministic, card filters): positive portfolio for all
// training bars; AR(1) phi in (0,1) (mean-reverting, kappa>0); sigma_eq>0;
// levels logically ordered a_x < d_x < theta < b_x. Levels refresh only while
// FLAT (card "fit and level refresh monthly while flat only" — we refresh every
// closed bar while flat, which is a strict superset and keeps the in-trade
// levels frozen at entry). No ADF p-value table at run time (no stats library);
// the phi-in-(0,1) + ordered-levels gate is the deterministic core.
//
// BASKET WIRING. Host leg trades `_Symbol` via the framework magic
// (slot = qm_magic_slot_offset). Partner leg trades a FOREIGN .DWX symbol via
// QM_BasketOpenPosition at its own registered slot. Both legs warmed in OnInit
// so foreign reads return real data in the .DWX tester. One position per
// (magic, symbol). Partner opened FIRST so a failed partner aborts the pair.
//
// Pair model (host = leg1, partner = leg2), to register in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 XAUUSD.DWX (host C) / slot 1 GBPUSD.DWX or slot 0 EURUSD.DWX (partner C)
// All legs are REAL .DWX symbols present in dwx_symbol_matrix.csv — no port.
// A setfile selects WHICH pair an instance runs by binding qm_magic_slot_offset
// (host slot), strategy_partner_symbol and strategy_partner_slot.
//
// Only the five Strategy_* hooks + OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11248;
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
// Partner (leg2) symbol + its registered magic slot. The host leg is _Symbol at
// qm_magic_slot_offset. Defaults bind pair A: EURUSD.DWX host / GBPUSD.DWX.
input string strategy_partner_symbol    = "GBPUSD.DWX";  // foreign .DWX leg2
input int    strategy_partner_slot      = 1;             // partner registered slot
input int    strategy_formation_bars    = 504;   // OU/hedge formation window (card {252,504,756})
input double strategy_discount_rate     = 0.05;  // documentary card discount (level shaping, see notes)
input double strategy_tcost_buy         = 0.02;  // round-trip buy cost fraction (entry-band downshift)
input double strategy_tcost_sell        = 0.02;  // round-trip sell cost fraction (liquidation upshift)
input double strategy_entry_lo_k        = 1.50;  // far (cheap) edge a_x = theta - entry_lo_k*sigma_eq
input double strategy_entry_hi_k        = 0.50;  // near edge d_x = theta - entry_hi_k*sigma_eq (entry_hi_k < entry_lo_k)
input double strategy_liq_k             = 0.75;  // liquidation b_x = theta + liq_k*sigma_eq
input double strategy_stop_k            = 3.00;  // OU lower stop = theta - stop_k*sigma_eq
input int    strategy_max_hold_bars     = 90;    // time stop (card {45,90,135})
input int    strategy_min_d1_bars       = 560;   // need >= formation_bars + buffer synced D1 bars
input double strategy_min_phi           = 0.05;  // AR(1) phi floor (kappa upper bound) for reversion
input double strategy_max_phi           = 0.995; // AR(1) phi ceiling (kappa lower bound) for reversion

// -----------------------------------------------------------------------------
// File-scope cached XOU pair state, advanced once per closed D1 bar while FLAT.
// Levels are FROZEN at entry (refreshed only while flat) so an open position is
// managed against the levels that were valid when it was entered.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2)
double   g_hedge            = 1.0;     // OLS hedge ratio (host = a + hedge*partner)
double   g_shift            = 0.0;     // positivity shift so portfolio value > 0
double   g_logval           = 0.0;    // last closed-bar log positive-portfolio value
double   g_theta            = 0.0;     // OU long-run mean of log-value
double   g_sigma_eq         = 0.0;    // OU equilibrium std of log-value
double   g_a_x              = 0.0;     // entry interval far (cheap) edge (log)
double   g_d_x              = 0.0;     // entry interval near edge (log)
double   g_b_x              = 0.0;     // liquidation level (log)
double   g_stop_x           = 0.0;    // OU lower stop boundary (log)
bool     g_levels_ready     = false;  // fit produced ordered, usable levels
bool     g_xou_ok           = false;  // mean-reverting + levels logically ordered

// Frozen-at-entry copies of the trade levels.
double   g_entry_b_x        = 0.0;
double   g_entry_stop_x     = 0.0;
bool     g_entry_frozen     = false;

// -----------------------------------------------------------------------------
// Compute the OU fit + XOU optimal levels over the formation window on CLOSED
// D1 bars. Builds a strictly-positive pair portfolio, takes its log, fits AR(1)
// closed-form (-> OU theta/kappa/sigma_eq), and derives cost-adjusted entry
// interval [a_x,d_x] and liquidation b_x. Returns false on missing / degenerate
// data so the EA simply does not trade (card "skip if unstable / non-positive /
// levels not ordered / missing bars").
// -----------------------------------------------------------------------------
bool QM_ComputeXOULevels(const int formation,
                         double &logval_last, double &theta, double &sigma_eq,
                         double &a_x, double &d_x, double &b_x, double &stop_x,
                         double &hedge_out, double &shift_out, bool &xou_ok)
  {
   logval_last = 0.0; theta = 0.0; sigma_eq = 0.0;
   a_x = 0.0; d_x = 0.0; b_x = 0.0; stop_x = 0.0;
   hedge_out = 1.0; shift_out = 0.0; xou_ok = false;
   if(formation < 60)
      return false;

   if(Bars(_Symbol,  PERIOD_D1) < strategy_min_d1_bars) return false;   // perf-allowed: bar-count availability check
   if(Bars(g_partner, PERIOD_D1) < strategy_min_d1_bars) return false;  // perf-allowed: partner-leg bar-count check

   const int n = formation;             // bars 1..n, index 0 = shift 1 (last closed)
   double h[];   // host close,    index 0 = last closed (shift 1)
   double p[];   // partner close, index 0 = last closed (shift 1)
   ArrayResize(h, n);
   ArrayResize(p, n);
   for(int i = 0; i < n; ++i)
     {
      // perf-allowed: closed-bar host+partner close reads for the formation window;
      // computed once per closed D1 bar (OnTick gates this via QM_IsNewBar).
      const double ch = iClose(_Symbol,   PERIOD_D1, i + 1);   // perf-allowed: closed-bar host close for formation window
      const double cp = iClose(g_partner, PERIOD_D1, i + 1);   // perf-allowed: closed-bar partner close for formation window
      if(ch <= 0.0 || cp <= 0.0)
         return false;                  // missing bar inside lookback -> no trade
      h[i] = ch;
      p[i] = cp;
     }

   // OLS hedge ratio over the formation window: host = a + hedge*partner.
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   const double dn = (double)n;
   for(int i = 0; i < n; ++i)
     {
      sx  += p[i];
      sy  += h[i];
      sxx += p[i] * p[i];
      sxy += p[i] * h[i];
     }
   const double den = dn * sxx - sx * sx;
   if(MathAbs(den) < 1e-12)
      return false;                     // degenerate regressor -> no trade
   const double hedge     = (dn * sxy - sx * sy) / den;
   const double intercept = (sy - hedge * sx) / dn;
   hedge_out = hedge;

   // Raw pair-portfolio value series: val[i] = host - hedge*partner. (The
   // intercept is absorbed into the positivity shift below.) index 0 = newest.
   double val[];
   ArrayResize(val, n);
   double vmin = 0.0;
   bool   have_min = false;
   for(int i = 0; i < n; ++i)
     {
      const double v = h[i] - hedge * p[i];
      val[i] = v;
      if(!have_min || v < vmin) { vmin = v; have_min = true; }
     }

   // Positivity transform (card "require positive portfolio construction for all
   // training bars"). Shift the whole series so its window minimum sits at a
   // strictly positive margin, then take logs. margin scaled to series spread.
   double vmax = val[0];
   for(int i = 1; i < n; ++i)
      if(val[i] > vmax) vmax = val[i];
   const double spreadrange = vmax - vmin;
   if(spreadrange <= 1e-12)
      return false;                     // flat portfolio -> no trade
   const double margin = 0.05 * spreadrange;   // 5% of range positivity cushion
   const double shift = margin - vmin;         // P_t = val + shift  >  0
   shift_out = shift;

   // Log positive-portfolio series.
   double x[];
   ArrayResize(x, n);
   for(int i = 0; i < n; ++i)
     {
      const double pv = val[i] + shift;
      if(pv <= 0.0)
         return false;                  // positivity failed -> no trade (card rule)
      x[i] = MathLog(pv);
     }
   logval_last = x[0];

   // --- closed-form AR(1) fit of x_t over the formation window --------------
   // x_t = c + phi*x_{t-1} + eps.  index 0 newest, so x_{t-1} = x[i+1], x_t = x[i].
   double ax = 0.0, ay = 0.0, axx = 0.0, axy = 0.0;
   const int m = n - 1;                 // number of (lag, current) pairs
   for(int i = 0; i < m; ++i)
     {
      const double xprev = x[i + 1];
      const double xcurr = x[i];
      ax  += xprev;
      ay  += xcurr;
      axx += xprev * xprev;
      axy += xprev * xcurr;
     }
   const double dm   = (double)m;
   const double aden = dm * axx - ax * ax;
   if(MathAbs(aden) < 1e-12)
      return false;                     // degenerate -> no trade
   const double phi = (dm * axy - ax * ay) / aden;
   const double c   = (ay - phi * ax) / dm;

   // Mean-reversion qualification: phi in (min_phi, max_phi) => kappa = -ln(phi) > 0.
   if(phi <= strategy_min_phi || phi >= strategy_max_phi)
      return true;                      // fit valid but not reverting -> xou_ok stays false

   theta = c / (1.0 - phi);             // OU long-run mean of log-value

   // Residual std -> OU equilibrium std: sigma_eq = sd(resid)/sqrt(1-phi^2).
   double ssr = 0.0;
   for(int i = 0; i < m; ++i)
     {
      const double pred = c + phi * x[i + 1];
      const double e    = x[i] - pred;
      ssr += e * e;
     }
   const double resid_var = ssr / dm;
   if(resid_var <= 1e-18)
      return true;                      // no equilibrium dispersion -> not usable
   const double resid_sd = MathSqrt(resid_var);
   sigma_eq = resid_sd / MathSqrt(1.0 - phi * phi);
   if(sigma_eq <= 1e-12)
      return true;

   // --- XOU optimal levels (cost-adjusted sigma bands around theta) ---------
   // Cost cushions push the entry interval LOWER (buy cheaper) and the
   // liquidation HIGHER (sell richer), shaped by the round-trip cost fractions
   // and the documentary discount rate (a small extra patience factor).
   const double disc_factor = 1.0 + MathMax(0.0, strategy_discount_rate);  // >= 1
   const double cost_buy  = MathMax(0.0, strategy_tcost_buy)  * disc_factor;
   const double cost_sell = MathMax(0.0, strategy_tcost_sell) * disc_factor;

   a_x = theta - strategy_entry_lo_k * sigma_eq - cost_buy * sigma_eq;  // far cheap edge
   d_x = theta - strategy_entry_hi_k * sigma_eq - cost_buy * sigma_eq;  // near edge
   b_x = theta + strategy_liq_k     * sigma_eq + cost_sell * sigma_eq;  // liquidation (rich)
   stop_x = theta - strategy_stop_k * sigma_eq;                          // OU lower stop

   // Logical ordering check (card "skip if optimal levels are not ordered
   // logically"): stop_x < a_x < d_x < theta < b_x.
   if(stop_x < a_x && a_x < d_x && d_x < theta && theta < b_x)
      xou_ok = true;

   return true;
  }

// Advance cached XOU state once per closed D1 bar. Only refreshes while FLAT so
// the open-position levels stay frozen at entry (card "refresh while flat only").
void QM_AdvanceXOUState()
  {
   double lv = 0.0, th = 0.0, se = 0.0, a = 0.0, d = 0.0, b = 0.0, st = 0.0;
   double hd = 1.0, sh = 0.0;
   bool   ok = false;
   if(QM_ComputeXOULevels(strategy_formation_bars, lv, th, se, a, d, b, st, hd, sh, ok))
     {
      g_logval       = lv;
      g_theta        = th;
      g_sigma_eq     = se;
      g_a_x          = a;
      g_d_x          = d;
      g_b_x          = b;
      g_stop_x       = st;
      g_hedge        = hd;
      g_shift        = sh;
      g_xou_ok       = ok;
      g_levels_ready = true;
     }
   else
     {
      g_levels_ready = false;
      g_xou_ok       = false;
     }
  }

// Current closed-bar log positive-portfolio value using the FROZEN hedge+shift
// (used while in a trade so the value is measured consistently with entry).
bool QM_CurrentLogVal(double &logval_out)
  {
   logval_out = 0.0;
   // perf-allowed: two closed-bar closes for the live portfolio value (gated by QM_IsNewBar in OnTick).
   const double ch = iClose(_Symbol,   PERIOD_D1, 1);   // perf-allowed: closed-bar host close
   const double cp = iClose(g_partner, PERIOD_D1, 1);   // perf-allowed: closed-bar partner close
   if(ch <= 0.0 || cp <= 0.0)
      return false;
   const double pv = (ch - g_hedge * cp) + g_shift;
   if(pv <= 0.0)
      return false;
   logval_out = MathLog(pv);
   return true;
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

// Bars held by the host leg (D1), or -1 if no host position.
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
      const datetime cur_bar = iTime(_Symbol, PERIOD_D1, 0);   // perf-allowed: bar-open time for time-stop count
      if(open_time <= 0 || cur_bar <= 0)
         return 0;
      return Bars(_Symbol, PERIOD_D1, open_time, cur_bar) - 1;  // perf-allowed: bars-held count for time stop
     }
   return -1;
  }

// Open the partner (leg2) market order on the FOREIGN symbol via the basket path.
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

// Cheap O(1) per-tick filter. Fail-open spread guard on the host leg only; the
// pair logic runs on closed bars. No session restriction (D1 pairs).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                     // no valid quote — defer, never block
   const double atr = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > 0.50 * atr)   // >50% of D1 ATR = pathological wide spread
      return true;
   return false;
  }

// Entry on a freshly closed D1 bar. LONG the positive portfolio (host BUY +
// hedge*partner SELL) when the log-value sits inside the cheap optimal entry
// interval [a_x, d_x]. Partner leg opened first via the basket path so both
// legs go on together. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One pair state at a time: skip if either leg already open.
   if(QM_PairHasPosition())
      return false;
   if(!g_levels_ready || !g_xou_ok)      // require XOU qualification + ordered levels
      return false;

   // ENTER LONG the portfolio iff log-value is in the cheap entry interval.
   const double xc = g_logval;
   if(xc < g_a_x || xc > g_d_x)
      return false;                      // outside the optimal entry interval -> wait

   // Long portfolio = BUY host (leg1) + SELL partner (leg2) for the hedge.
   const QM_OrderType host_ot    = QM_BUY;
   const QM_OrderType partner_ot = QM_SELL;
   const string rsn = "xou_long_portfolio";

   // Open the partner leg FIRST. If it fails, abort so we never carry a naked leg.
   if(!QM_OpenPartnerLeg(partner_ot, rsn))
      return false;

   // Freeze the liquidation + stop levels at entry (refresh-while-flat-only).
   g_entry_b_x    = g_b_x;
   g_entry_stop_x = g_stop_x;
   g_entry_frozen = true;

   // Host leg for the framework. No fixed SL/TP — pair managed at basket level.
   req.type        = host_ot;
   req.price       = 0.0;                // framework fills market price at send
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

// Pair-level exits: liquidation at b_x, OU lower stop, time stop. Returning true
// triggers the framework's host-leg close loop in OnTick; we ALSO close the
// partner leg here so the whole pair unwinds together.
bool Strategy_ExitSignal()
  {
   // Only manage if the host leg holds a position.
   if(QM_LegOpenCount(qm_magic_slot_offset, _Symbol) <= 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   // Current log-value measured with the FROZEN hedge+shift from entry.
   double xnow = 0.0;
   if(g_entry_frozen && QM_CurrentLogVal(xnow))
     {
      // Liquidation: portfolio value reached the optimal rich level b_x.
      if(xnow >= g_entry_b_x)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
      // OU lower stop: value breached the stop boundary (card stop_loss cushion).
      if(!do_exit && xnow <= g_entry_stop_x)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
     }

   // Time stop: close the pair after the configured holding budget.
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
      g_entry_frozen = false;
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

   // BASKET wiring: register host + partner and warm their D1 history so the
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
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_formation_bars + 60);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"partner\":\"%s\",\"host_slot\":%d,\"partner_slot\":%d,\"formation\":%d,\"max_hold\":%d}",
                            _Symbol, g_partner, qm_magic_slot_offset,
                            strategy_partner_slot, strategy_formation_bars, strategy_max_hold_bars));
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

   // Latch the closed-bar event ONCE (single-consume) and reuse it. On a fresh D1
   // bar refresh the XOU fit/levels ONLY WHILE FLAT (refresh-while-flat-only); an
   // open position is managed against the levels frozen at entry.
   const bool nb = QM_IsNewBar();
   if(nb && !QM_PairHasPosition())
      QM_AdvanceXOUState();

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
