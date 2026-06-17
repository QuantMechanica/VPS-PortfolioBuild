#property strict
#property version   "5.0"
#property description "QM5_11250 ht-ou-optstop — Ornstein-Uhlenbeck optimal-stopping pairs trade (D1, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11250 ht-ou-optstop
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Trading Under the Ornstein-Uhlenbeck Model",
// ArbitrageLab documentation (source_id af021dd0-e07d-5f72-9933-de7a3533934e);
// primary reference Tim Leung & Xin Li, "Optimal Mean Reversion Trading:
// Mathematical Analysis and Practical Applications".
// Card: artifacts/cards_approved/QM5_11250_ht-ou-optstop.md (g0 APPROVED).
//
// OU OPTIMAL-STOPPING RELATIVE-VALUE PAIRS TRADE (BASKET EA). On each completed D1
// bar the EA fits a static hedge ratio by rolling OLS of the host close on the
// partner close over a FORMATION/training window (`training_window_bars` D1 bars),
// forms the spread X(t) = host - (a + beta*partner), then fits an OU process to the
// spread CLOSED-FORM via an AR(1) regression (no iterative MLE, no ML, no library):
//
//   AR(1):  X_t = c + phi*X_{t-1} + eps_t       (dt = 1 D1 bar)
//   OU map: theta   = c / (1 - phi)             (long-run mean / equilibrium)
//           kappa   = -ln(phi)                  (mean-reversion speed, phi in (0,1))
//           sigma_e = sqrt( var(eps) / (1 - phi^2) )   (OU equilibrium std-dev)
//
// half_life = ln(2) / kappa.  The pair qualifies only when phi in (0,1) (genuine
// mean reversion), sigma_e > 0, and half_life lies inside [min_half_life,
// max_half_life].  This is the deterministic core of the Leung-Li OU calibration.
//
// OPTIMAL LEVELS (closed-form, in OU equilibrium-std units around theta). The exact
// Leung-Li free-boundary problem solves a transcendental ODE pair for d*/b*/L; we
// use the closed-form discount-rate-adjusted band that the framework can evaluate
// deterministically each bar (no root-finder, no iteration):
//
//   entry level   d* = theta - z_entry * sigma_e     (buy spread when cheap)
//   liquidation   b* = theta + z_exit  * sigma_e     (sell when reverted past mean)
//   optimal stop  L  = theta - z_stop  * sigma_e     (hard OU stop below entry band)
//
// where the discount rate `r` tightens the liquidation target the costlier waiting
// is: z_exit_eff = max(0, z_exit_base - r * kappa_scale). Higher discount rate r =>
// liquidate sooner (smaller z_exit), exactly the Leung-Li "value of waiting" effect,
// expressed closed-form. We trade ONLY the long-spread direction the OU optimal-
// stopping problem is posed for (enter cheap at d*, liquidate at b*); the spread is
// symmetric so the same band is mirrored for the short-spread side (enter rich at
// theta + z_entry*sigma_e, liquidate at theta - z_exit*sigma_e, stop above).
//
// EDGE-FLOOR FILTER (card): skip if the cost-adjusted target width (b* - d*) is below
// `min_target_atr` * ATR(portfolio). The portfolio ATR proxy is the OU equilibrium
// std sigma_e (the natural spread-unit volatility). Beta-stability filter: skip if
// the freshly fitted beta moved more than `beta_max_change` (fraction) vs the prior
// flat refit. Refits happen ONLY while flat (no parameter update while in a trade).
//
// EXITS: liquidate at b* (reversion target), hard OU stop at L, time stop after
// `max_hold_bars` D1 bars, Friday-close by framework. All legs close together.
//
// BASKET WIRING. Host leg trades `_Symbol` via the framework magic (slot =
// qm_magic_slot_offset). Partner leg trades a FOREIGN .DWX symbol via
// QM_BasketOpenPosition at its own registered symbol_slot. Both legs warmed in
// OnInit so foreign-symbol reads return real data in the .DWX tester. One position
// per (magic, symbol).
//
// Pair model (host = leg1, partner = leg2), registered in magic_numbers.csv:
//   slot 0 EURUSD.DWX  slot 1 GBPUSD.DWX  slot 2 AUDUSD.DWX
//   slot 3 NZDUSD.DWX  slot 4 XAUUSD.DWX
// The card's R3 names three cointegrated DWX pairs over these five legs:
//   pair A = EURUSD.DWX (host slot 0) / GBPUSD.DWX (partner slot 1)
//   pair B = AUDUSD.DWX (host slot 2) / NZDUSD.DWX (partner slot 3)
//   pair C = XAUUSD.DWX (host slot 4) / EURUSD.DWX (partner slot 0)
// A setfile binds host slot + partner symbol + partner slot to pick the pair; pair C
// reuses EURUSD.DWX (slot 0) as its partner leg, so pair A and pair C cannot both hold
// an EURUSD position at once (same magic+symbol) — a documented setfile-time constraint.
// All five legs are REAL .DWX symbols present in dwx_symbol_matrix.csv — no port needed.
// A setfile selects WHICH pair an instance runs by binding:
//   qm_magic_slot_offset   = host leg slot (matches the host symbol it runs on)
//   strategy_partner_symbol= the partner .DWX symbol
//   strategy_partner_slot  = the partner leg slot
// (default = pair A on EURUSD.DWX host / GBPUSD.DWX partner).
//
// Only the five Strategy_* hooks + OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11250;
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
input string strategy_partner_symbol      = "GBPUSD.DWX";  // foreign .DWX leg2
input int    strategy_partner_slot        = 1;             // partner registered slot
input int    strategy_training_window_bars= 504;   // OU training window (card P3 {252,504,756})
input double strategy_discount_rate       = 0.05;  // OU discount rate r (card P3 {0.02,0.05,0.10})
input double strategy_entry_z             = 1.5;   // entry band: d*=theta - z_entry*sigma_e
input double strategy_exit_z              = 0.25;  // base liquidation offset b*=theta + z_exit*sigma_e
input double strategy_stop_z              = 2.5;   // OU optimal stop: L=theta - z_stop*sigma_e (card P3 {2.0,2.5,3.0})
input double strategy_min_target_atr      = 1.5;   // skip if (b*-d*) < this * sigma_e (cost floor)
input double strategy_beta_max_change     = 0.25;  // skip if |beta-prev_beta|/|prev_beta| > this
input int    strategy_min_half_life       = 3;     // min OU half-life (D1 bars) (card 3..60)
input int    strategy_max_half_life       = 60;    // max OU half-life (D1 bars)
input int    strategy_max_hold_bars       = 80;    // time stop (D1 bars) (card P3 {40,80,120})
input int    strategy_min_d1_bars         = 560;   // need >= training_window + buffer synced D1 bars

// -----------------------------------------------------------------------------
// File-scope cached OU pair state, advanced once per closed D1 bar while FLAT.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2)
double   g_spread_curr      = 0.0;    // last closed-bar spread value X(t)
double   g_ou_theta         = 0.0;    // OU long-run mean
double   g_ou_sigma_e       = 0.0;    // OU equilibrium std-dev
double   g_ou_kappa         = 0.0;    // OU mean-reversion speed
double   g_level_entry_long = 0.0;    // d* (buy spread when X <= d*)
double   g_level_entry_short= 0.0;    // mirror (sell spread when X >= this)
double   g_level_exit_long  = 0.0;    // b* long-spread liquidation
double   g_level_exit_short = 0.0;    // mirror short-spread liquidation
double   g_level_stop_long  = 0.0;    // L long-spread hard OU stop
double   g_level_stop_short = 0.0;    // mirror short-spread hard OU stop
double   g_beta_prev        = 0.0;    // last accepted hedge ratio (beta-stability)
double   g_intercept_prev   = 0.0;    // last accepted OLS intercept (spread frame anchor)
bool     g_beta_seeded      = false;  // have we accepted at least one beta?
bool     g_ou_ready         = false;  // levels well-formed + qualification passed

// -----------------------------------------------------------------------------
// OU calibration over the training window on CLOSED D1 bars. Fits hedge ratio
// host = a + beta*partner by OLS, forms the spread, fits AR(1)->OU CLOSED-FORM
// (no iteration), derives theta / sigma_e / kappa / half_life and the optimal
// entry/liquidation/stop levels. Returns false on missing / degenerate data so
// the EA simply does not trade (card "skip if unstable / std==0 / missing bars").
// -----------------------------------------------------------------------------
bool QM_ComputeOULevels(const int train)
  {
   g_ou_ready = false;
   if(train < 60)
      return false;

   // Need `train` closed bars (shift 1..train) on BOTH legs.
   if(Bars(_Symbol,  PERIOD_D1) < strategy_min_d1_bars) return false;  // perf-allowed: bar-count availability check
   if(Bars(g_partner, PERIOD_D1) < strategy_min_d1_bars) return false; // perf-allowed: partner-leg bar-count check

   const int n = train;                  // bars 1..n, index 0 = shift 1 (last closed)
   double h[];   // host close,    index 0 = last closed (shift 1)
   double p[];   // partner close, index 0 = last closed (shift 1)
   ArrayResize(h, n);
   ArrayResize(p, n);
   for(int i = 0; i < n; ++i)
     {
      // perf-allowed: closed-bar host+partner close reads for the training window;
      // computed once per closed D1 bar (OnTick gates this via QM_IsNewBar) and only
      // while flat (no refit during an open trade).
      const double ch = iClose(_Symbol,   PERIOD_D1, i + 1);   // perf-allowed: closed-bar host close, training window
      const double cp = iClose(g_partner, PERIOD_D1, i + 1);   // perf-allowed: closed-bar partner close, training window
      if(ch <= 0.0 || cp <= 0.0)
         return false;                    // missing bar inside lookback -> no trade
      h[i] = ch;
      p[i] = cp;
     }

   // OLS hedge ratio over the full training window: host = a + beta*partner.
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
      return false;                       // degenerate regressor -> no trade
   const double beta      = (dn * sxy - sx * sy) / den;
   const double intercept = (sy - beta * sx) / dn;

   // Beta-stability gate (card): reject this refit if beta moved too much vs prior.
   if(g_beta_seeded && MathAbs(g_beta_prev) > 1e-12)
     {
      const double rel = MathAbs(beta - g_beta_prev) / MathAbs(g_beta_prev);
      if(rel > strategy_beta_max_change)
         return false;                    // unstable beta -> skip (no trade this bar)
     }

   // Spread series over the training window: spread[i] = host - (a + beta*partner).
   // index 0 = last closed bar; higher index = older.
   double spread[];
   ArrayResize(spread, n);
   for(int i = 0; i < n; ++i)
      spread[i] = h[i] - (intercept + beta * p[i]);

   // --- AR(1) fit: X_t = c + phi*X_{t-1} + eps_t.  Regress current spread on its
   // one-bar lag. spread index 0 is the newest bar => for pair (X_t, X_{t-1}) we use
   // X_t = spread[i], X_{t-1} = spread[i+1], i in 0..n-2.
   double lx = 0.0, ly = 0.0, lxx = 0.0, lxy = 0.0;
   const int m = n - 1;                   // number of (lag, current) pairs
   for(int i = 0; i < m; ++i)
     {
      const double x_prev = spread[i + 1];   // X_{t-1}
      const double x_curr = spread[i];       // X_t
      lx  += x_prev;
      ly  += x_curr;
      lxx += x_prev * x_prev;
      lxy += x_prev * x_curr;
     }
   const double dm   = (double)m;
   const double lden = dm * lxx - lx * lx;
   if(MathAbs(lden) < 1e-12)
      return false;                       // degenerate lag regressor -> no trade
   const double phi = (dm * lxy - lx * ly) / lden;   // AR(1) coefficient
   const double c   = (ly - phi * lx) / dm;          // AR(1) intercept

   // Genuine mean reversion requires 0 < phi < 1 (stationary, reverting).
   if(phi <= 0.0 || phi >= 1.0)
      return true;                        // computed but not qualified -> no trade

   // OU map (dt = 1 D1 bar).
   const double theta = c / (1.0 - phi);
   const double kappa = -MathLog(phi);    // > 0 since 0<phi<1
   if(kappa <= 0.0)
      return true;

   // Residual variance of the AR(1) fit -> OU equilibrium std-dev.
   double rss = 0.0;
   for(int i = 0; i < m; ++i)
     {
      const double pred = c + phi * spread[i + 1];
      const double e    = spread[i] - pred;
      rss += e * e;
     }
   const double resid_var = rss / dm;            // var(eps)
   const double eq_var    = resid_var / (1.0 - phi * phi);   // OU stationary variance
   if(eq_var <= 1e-18)
      return true;                        // degenerate (zero spread vol) -> no trade
   const double sigma_e = MathSqrt(eq_var);

   // Half-life gate (card 3..60 D1 bars).
   const double half_life = MathLog(2.0) / kappa;
   if(half_life < (double)strategy_min_half_life ||
      half_life > (double)strategy_max_half_life)
      return true;                        // out of band -> no trade

   // --- Closed-form optimal levels in OU equilibrium-std units around theta -----
   // Discount-rate effect: a higher discount rate r tightens the liquidation target
   // (value of waiting falls), expressed closed-form via kappa. z_exit shrinks but is
   // floored at 0 so b* never crosses below theta.
   const double r = (strategy_discount_rate > 0.0) ? strategy_discount_rate : 0.0;
   double z_exit_eff = strategy_exit_z - (r / kappa);
   if(z_exit_eff < 0.0)
      z_exit_eff = 0.0;

   const double d_long   = theta - strategy_entry_z * sigma_e;  // buy spread when cheap
   const double b_long   = theta + z_exit_eff       * sigma_e;  // liquidate past mean
   const double l_long   = theta - strategy_stop_z  * sigma_e;  // hard OU stop below

   // Mirror for the symmetric short-spread side.
   const double d_short  = theta + strategy_entry_z * sigma_e;  // sell spread when rich
   const double b_short  = theta - z_exit_eff       * sigma_e;  // liquidate past mean
   const double l_short  = theta + strategy_stop_z  * sigma_e;  // hard OU stop above

   // Cost / edge floor (card): skip if the target width is below the floor in
   // sigma_e (portfolio-ATR proxy) units. (b*-d*) = (z_entry + z_exit_eff)*sigma_e.
   const double target_width = (b_long - d_long);
   if(target_width < strategy_min_target_atr * sigma_e)
      return true;                        // edge too thin -> no trade

   // Accept this calibration: latch the levels + beta for the stability gate.
   g_spread_curr       = spread[0];
   g_ou_theta          = theta;
   g_ou_sigma_e        = sigma_e;
   g_ou_kappa          = kappa;
   g_level_entry_long  = d_long;
   g_level_exit_long   = b_long;
   g_level_stop_long   = l_long;
   g_level_entry_short = d_short;
   g_level_exit_short  = b_short;
   g_level_stop_short  = l_short;
   g_beta_prev         = beta;
   g_intercept_prev    = intercept;
   g_beta_seeded       = true;
   g_ou_ready          = true;
   return true;
  }

// Advance cached OU state once per closed D1 bar. While flat we recalibrate (refit);
// while in a trade we ONLY refresh the current spread value against the LATCHED
// levels (no parameter update while a position is open — card flat-only refit rule).
void QM_AdvanceOUState(const bool flat)
  {
   if(flat)
     {
      if(!QM_ComputeOULevels(strategy_training_window_bars))
         g_ou_ready = false;
      return;
     }
   // In-trade (card flat-only refit rule): do NOT recalibrate. Keep the latched OU
   // frame (beta, intercept, theta, sigma_e, levels) fixed and refresh ONLY the newest
   // spread value in that SAME frame, using the identical definition as calibration:
   //   spread = host - (intercept + beta*partner).
   // This keeps g_spread_curr directly comparable to the latched liquidation/stop
   // levels, so exits fire on the OU optimal-stopping bands the trade was opened under.
   if(!g_beta_seeded)
      return;                              // no latched frame yet -> keep last value
   const double ch = iClose(_Symbol,   PERIOD_D1, 1);   // perf-allowed: newest closed host close
   const double cp = iClose(g_partner, PERIOD_D1, 1);   // perf-allowed: newest closed partner close
   if(ch <= 0.0 || cp <= 0.0)
      return;                              // keep last good spread value
   g_spread_curr = ch - (g_intercept_prev + g_beta_prev * cp);
  }

// Count open positions for an arbitrary (slot,symbol) leg of THIS ea_id.
int QM_LegOpenCount(const int slot, const string sym)
  {
   const int magic = QM_Magic(qm_ea_id, slot);
   if(magic <= 0)
      return 0;
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      ++cnt;
     }
   return cnt;
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
      const datetime cur_bar   = iTime(_Symbol, PERIOD_D1, 0);   // perf-allowed: bar-open time for time-stop count
      if(open_time <= 0 || cur_bar <= 0)
         return 0;
      return Bars(_Symbol, PERIOD_D1, open_time, cur_bar) - 1;    // perf-allowed: bars-held count for time stop
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

// Cheap O(1) per-tick filter. Fail-OPEN spread guard on the host leg only; the OU
// pair logic runs on closed bars. No session restriction (D1 pairs).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                       // no valid quote — defer, never block
   const double atr = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > 0.50 * atr)   // >50% of D1 ATR = pathological wide spread
      return true;
   return false;
  }

// Entry on a freshly closed D1 bar. Host leg via the framework path; the partner leg
// opened first via the basket path so both legs go on together. Caller guarantees
// QM_IsNewBar()==true. OU optimal-stopping: enter LONG-spread when X(t) <= d*, enter
// SHORT-spread when X(t) >= mirror entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_PairHasPosition())
      return false;
   if(!g_ou_ready)                          // require OU qualification + well-formed levels
      return false;

   const double x = g_spread_curr;
   int dir = 0;                             // +1 long-spread, -1 short-spread
   if(x <= g_level_entry_long)
      dir = +1;                             // spread cheap -> LONG spread (buy host)
   else if(x >= g_level_entry_short)
      dir = -1;                             // spread rich  -> SHORT spread (sell host)
   if(dir == 0)
      return false;

   // Host (leg1): long-spread -> BUY host; short-spread -> SELL host.
   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY : QM_SELL;
   // Partner (leg2) takes the OPPOSITE side for market-neutral exposure.
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open the partner leg FIRST. If it fails, abort so we never carry a naked leg.
   const string rsn = (dir > 0) ? "ou_long_spread" : "ou_short_spread";
   if(!QM_OpenPartnerLeg(partner_ot, rsn))
      return false;

   // Host leg for the framework. No fixed SL/TP — pair managed at basket level via
   // the OU optimal-stopping liquidation / stop levels in Strategy_ExitSignal.
   req.type        = host_ot;
   req.price       = 0.0;                   // framework fills market price at send
   req.sl          = 0.0;
   req.tp          = 0.0;
   req.reason      = rsn;
   req.symbol_slot = qm_magic_slot_offset;  // host leg slot
   return true;
  }

// No active per-position trade management; pair exits are rule-based (OU levels).
void Strategy_ManageOpenPosition()
  {
  }

// Pair-level OU optimal-stopping exits: liquidation at b*, hard OU stop at L, time
// stop after max_hold_bars. Returning true triggers the framework's host-leg close
// loop in OnTick; we ALSO close the partner leg here so the pair unwinds together.
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();    // +1 long-spread, -1 short-spread, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_ou_ready || g_ou_sigma_e > 0.0)     // levels available (latched while in-trade)
     {
      const double x = g_spread_curr;
      if(host_dir > 0)                       // LONG spread: liquidate at/above b*, stop at/below L
        {
         if(x >= g_level_exit_long)
           { do_exit = true; reason = QM_EXIT_STRATEGY; }
         else if(x <= g_level_stop_long)
           { do_exit = true; reason = QM_EXIT_STRATEGY; }
        }
      else                                   // SHORT spread: liquidate at/below b*, stop at/above L
        {
         if(x <= g_level_exit_short)
           { do_exit = true; reason = QM_EXIT_STRATEGY; }
         else if(x >= g_level_stop_short)
           { do_exit = true; reason = QM_EXIT_STRATEGY; }
        }
     }

   // Time stop: close the pair after the max-hold bar budget.
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

   // Resolve the partner leg. If blank or equal to the host, the pair is degenerate
   // and the EA simply never trades (still a valid, safe init).
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
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_training_window_bars + 60);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"partner\":\"%s\",\"host_slot\":%d,\"partner_slot\":%d,\"train\":%d,\"r\":%.4f}",
                            _Symbol, g_partner, qm_magic_slot_offset,
                            strategy_partner_slot, strategy_training_window_bars, strategy_discount_rate));
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

   // Latch the closed-bar event ONCE (single-consume) and reuse it. On a fresh D1 bar
   // advance the OU state BEFORE the rule-based exit so the exit sees the current
   // spread. Refit only while flat; refresh-only while a pair position is open.
   const bool nb = QM_IsNewBar();
   if(nb)
     {
      const bool flat = !QM_PairHasPosition();
      QM_AdvanceOUState(flat);
     }

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
