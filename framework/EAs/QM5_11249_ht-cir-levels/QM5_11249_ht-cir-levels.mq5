#property strict
#property version   "5.0"
#property description "QM5_11249 ht-cir-levels — Cox-Ingersoll-Ross positive-spread optimal entry/liquidation levels (D1, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11249 ht-cir-levels
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Trading Under the Cox-Ingersoll-Ross Model",
// ArbitrageLab documentation (source_id af021dd0-e07d-5f72-9933-de7a3533934e);
// primary reference Leung, T.S.T. & Li, X. (2015), "Optimal Mean Reversion
// Trading". Card: artifacts/cards_approved/QM5_11249_ht-cir-levels.md (g0 APPROVED).
//
// CIR POSITIVE-SPREAD LEVEL TRADE (BASKET EA). On each completed D1 bar the EA
// builds a NON-NEGATIVE pair portfolio over a FORMATION window:
//
//     Y_t = S1_t - beta * S2_t + offset      (offset guards Y_t > 0)
//
// where S1 = host close (leg1), S2 = partner close (leg2). The hedge ratio beta
// is chosen from a bounded grid {beta_grid_min .. beta_grid_max} by MAXIMISING a
// CIR Gaussian-quasi log-likelihood proxy of the resulting positive spread (a
// fixed formation-stage parameter search, NOT a trading grid, NOT ML). The CIR
// parameters theta (mean-reversion speed), mu (long-run mean) and sigma
// (volatility) are then estimated CLOSED-FORM via weighted OLS on the discretised
// CIR (Euler scheme, variance-stabilised by dividing by sqrt(Y_{t-1})) — pure
// method-of-moments / OLS, NO iterative MLE, NO library, NO ML.
//
// The Leung-Li optimal entry/liquidation levels are realised deterministically as
// a band around the long-run mean using the CIR stationary standard deviation
// sigma_stat = sigma * sqrt(mu / (2*theta)):
//
//     d_chi (optimal ENTRY)       = mu - entry_k * sigma_stat   (spread cheap)
//     b_chi (optimal LIQUIDATION) = mu + exit_k  * sigma_stat   (spread reverted)
//
// This is a LONG-ONLY positive-spread trade (the card enters long when cheap and
// liquidates when reverted up; there is no short-spread leg):
//
//   Y_t <= d_chi  -> spread cheap  -> LONG  spread: BUY host (leg1) + SELL partner (leg2)
//   Y_t >= b_chi  -> reverted up   -> LIQUIDATE the pair
//
// Stops (card): hard stop when Y_t breaches the model stop band (mu - stop_k *
// sigma_stat) OR when the positivity guard fails (Y_t <= 0). Time stop after
// max_hold_bars D1 bars. Re-qualify monthly while flat (the closed-bar refit runs
// every bar but a NEW position only opens while flat, which is the card's
// "refit monthly while flat only" intent in deterministic form).
//
// CIR QUALIFICATION (card fit-quality filters, fully deterministic):
//   - Y_t > 0 across the WHOLE formation window after the offset (positivity),
//   - theta > 0 (mean-reverting) and mu > 0 (CIR positivity assumption),
//   - sigma > 0 and sigma_stat > 0,
//   - entry and liquidation levels separated by more than a transaction-cost
//     cushion (reject trades whose band is too tight vs estimated cost).
//
// BASKET WIRING. The host leg trades `_Symbol` via the framework magic
// (slot = qm_magic_slot_offset). The partner leg trades a FOREIGN .DWX symbol via
// QM_BasketOpenPosition at its own registered symbol_slot. Both legs are warmed in
// OnInit so foreign-symbol reads return real data in the .DWX tester. One position
// per (magic, symbol).
//
// Pair model (host = leg1, partner = leg2), to register in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 XAUUSD.DWX (host C, single positive series fallback)
// All legs are REAL .DWX symbols present in dwx_symbol_matrix.csv — no port
// needed. A setfile selects WHICH pair an instance runs by binding:
//   qm_magic_slot_offset    = host leg slot (matches the host symbol it runs on)
//   strategy_partner_symbol = the partner .DWX symbol
//   strategy_partner_slot   = the partner leg slot
// (default = pair A on EURUSD.DWX host / GBPUSD.DWX partner).
//
// Only the five Strategy_* hooks + OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11249;
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
// Set strategy_partner_symbol = "" (or equal to the host) to trade a SINGLE
// positive series (host only) per the card's "single positive series" branch.
input string strategy_partner_symbol    = "GBPUSD.DWX";  // foreign .DWX leg2 ("" = single series)
input int    strategy_partner_slot      = 1;             // partner registered slot
input int    strategy_formation_bars    = 504;   // CIR formation window (P3 {252,504,756})
input double strategy_beta_grid_min     = 0.50;  // min hedge-ratio in the bounded scan (P3 {0.25,0.50,0.75})
input double strategy_beta_grid_max     = 2.00;  // max hedge-ratio in the bounded scan (P3 {1.50,2.00,2.50})
input int    strategy_beta_grid_steps   = 16;    // grid resolution for the beta scan
input double strategy_entry_k           = 1.50;  // d_chi = mu - entry_k * sigma_stat (entry depth)
input double strategy_exit_k            = 0.25;  // b_chi = mu + exit_k  * sigma_stat (liquidation)
input double strategy_stop_k            = 3.00;  // model stop = mu - stop_k * sigma_stat
input int    strategy_max_hold_bars     = 120;   // time stop (D1 bars) (P3 {60,120,180})
input double strategy_cost_cushion_frac = 0.10;  // reject if (b_chi-d_chi) < cushion * sigma_stat
input int    strategy_min_d1_bars       = 560;   // need >= formation_bars + buffer synced D1 bars
input double strategy_min_sigma_stat    = 1e-9;  // floor on stationary std (degenerate guard)

// -----------------------------------------------------------------------------
// File-scope cached CIR state, advanced once per closed D1 bar.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2), "" => single series
bool     g_single_series    = false;  // true when trading host-only positive series
double   g_beta             = 0.0;    // selected hedge ratio (0 in single-series mode)
double   g_offset           = 0.0;    // positivity offset added to the spread
double   g_y_curr           = 0.0;    // last closed-bar positive spread Y_t
double   g_mu               = 0.0;    // CIR long-run mean
double   g_sigma_stat       = 0.0;    // CIR stationary std
double   g_d_chi            = 0.0;    // optimal entry level
double   g_b_chi            = 0.0;    // optimal liquidation level
double   g_stop_level       = 0.0;    // model stop band
bool     g_cir_ok           = false;  // CIR qualification passed
bool     g_y_ready          = false;  // formation window well-formed

// -----------------------------------------------------------------------------
// Build the positive spread series for a given beta over the formation window,
// returning the raw (pre-offset) spread array. index 0 = last closed bar.
// Returns false on missing / non-positive close data.
// -----------------------------------------------------------------------------
bool QM_BuildRawSpread(const int n, const double beta, double &spread[])
  {
   ArrayResize(spread, n);
   for(int i = 0; i < n; ++i)
     {
      // perf-allowed: closed-bar host/partner close reads for the formation window;
      // computed once per closed D1 bar (OnTick gates this via QM_IsNewBar).
      const double ch = iClose(_Symbol, PERIOD_D1, i + 1);   // perf-allowed: closed-bar host close for formation window
      if(ch <= 0.0)
         return false;
      if(g_single_series)
        {
         spread[i] = ch;
        }
      else
        {
         const double cp = iClose(g_partner, PERIOD_D1, i + 1);  // perf-allowed: closed-bar partner close for formation window
         if(cp <= 0.0)
            return false;
         spread[i] = ch - beta * cp;
        }
     }
   return true;
  }

// Closed-form CIR fit on a strictly-positive series Y (index 0 = newest).
// Discretised CIR (Euler):  dY = theta*(mu - Y_{t-1}) dt + sigma*sqrt(Y_{t-1}) dW.
// Variance-stabilise by dividing by sqrt(Y_{t-1}) and run OLS of
//   r_t = dY_t / sqrt(Y_{t-1})  on  x1 = 1/sqrt(Y_{t-1})  and  x2 = sqrt(Y_{t-1}).
// Then  b1 = theta*mu*dt ,  b2 = -theta*dt  => theta = -b2/dt , mu = -b1/b2 ,
// sigma^2 = Var(resid)/dt. dt = 1 (per-bar). Pure OLS, deterministic, no MLE.
// Returns the CIR quasi log-likelihood proxy (higher = better fit) via &ll, and
// fills theta/mu/sigma. Returns false on degenerate inputs.
// -----------------------------------------------------------------------------
bool QM_FitCIR(const double &y[], const int n,
               double &theta, double &mu, double &sigma, double &ll)
  {
   theta = 0.0; mu = 0.0; sigma = 0.0; ll = -1e18;
   if(n < 30)
      return false;

   // m = number of (Y_{t-1} -> dY_t) increment pairs. y[i] newest; the increment
   // dY_t = y[i] - y[i+1] uses Y_{t-1} = y[i+1].
   const int m = n - 1;
   // OLS design: r = b1*x1 + b2*x2 (no separate intercept; x1 carries the const).
   double s11 = 0.0, s12 = 0.0, s22 = 0.0, s1r = 0.0, s2r = 0.0;
   int used = 0;
   for(int i = 0; i < m; ++i)
     {
      const double yprev = y[i + 1];
      if(yprev <= 0.0)
         return false;                  // positivity broken inside window
      const double root = MathSqrt(yprev);
      const double dy   = y[i] - yprev;
      const double x1   = 1.0 / root;
      const double x2   = root;
      const double r    = dy / root;
      s11 += x1 * x1;
      s12 += x1 * x2;
      s22 += x2 * x2;
      s1r += x1 * r;
      s2r += x2 * r;
      ++used;
     }
   if(used < 20)
      return false;
   const double det = s11 * s22 - s12 * s12;
   if(MathAbs(det) < 1e-18)
      return false;
   const double b1 = ( s22 * s1r - s12 * s2r) / det;   // = theta*mu
   const double b2 = (-s12 * s1r + s11 * s2r) / det;   // = -theta
   if(b2 >= 0.0)
      return false;                     // not mean-reverting (theta <= 0)
   theta = -b2;
   mu    = b1 / theta;                  // mu = (theta*mu)/theta
   if(mu <= 0.0)
      return false;                     // CIR positivity assumption violated

   // Residual variance -> sigma^2 (dt = 1).
   double sse = 0.0;
   for(int i = 0; i < m; ++i)
     {
      const double yprev = y[i + 1];
      const double root  = MathSqrt(yprev);
      const double r     = (y[i] - yprev) / root;
      const double rhat  = b1 * (1.0 / root) + b2 * root;
      const double e     = r - rhat;
      sse += e * e;
     }
   const double var = sse / (double)used;
   if(var <= 0.0)
      return false;
   sigma = MathSqrt(var);

   // Gaussian quasi log-likelihood proxy of the standardised residuals
   // (used only to RANK beta candidates; deterministic, not ML training).
   ll = -0.5 * (double)used * (MathLog(2.0 * M_PI * var) + 1.0);
   return true;
  }

// Full CIR computation for the current closed bar: scan beta, pick best CIR fit,
// build the positive spread, derive levels + qualification. Fills the file-scope
// g_* state. Returns false (no trade) on any degenerate condition.
bool QM_ComputeCIR()
  {
   g_y_ready = false;
   g_cir_ok  = false;

   const int n = strategy_formation_bars;
   if(n < 30)
      return false;
   if(Bars(_Symbol, PERIOD_D1) < strategy_min_d1_bars) return false;  // perf-allowed: host bar-count availability check
   if(!g_single_series && Bars(g_partner, PERIOD_D1) < strategy_min_d1_bars) return false;  // perf-allowed: partner bar-count check

   // --- 1. select beta over the bounded grid by best CIR fit ---------------
   double best_ll    = -1e18;
   double best_beta  = 0.0;
   double best_off   = 0.0;
   double best_mu    = 0.0;
   double best_theta = 0.0;
   double best_sigma = 0.0;
   bool   found      = false;

   const int steps = (g_single_series) ? 1 : (strategy_beta_grid_steps < 1 ? 1 : strategy_beta_grid_steps);
   const double bmin = strategy_beta_grid_min;
   const double bmax = strategy_beta_grid_max;

   for(int s = 0; s < steps; ++s)
     {
      double beta = 0.0;
      if(!g_single_series)
        {
         if(steps == 1)
            beta = 0.5 * (bmin + bmax);
         else
            beta = bmin + (bmax - bmin) * (double)s / (double)(steps - 1);
        }

      double raw[];
      if(!QM_BuildRawSpread(n, beta, raw))
         continue;

      // Positivity offset: shift the spread so its minimum sits at a small
      // positive floor. CIR requires Y_t > 0 across the whole window.
      double mn = raw[0];
      for(int i = 1; i < n; ++i)
         if(raw[i] < mn) mn = raw[i];
      // Floor at 1% of the spread's own scale (range) to keep sqrt(Y) stable.
      double mx = raw[0];
      for(int i = 1; i < n; ++i)
         if(raw[i] > mx) mx = raw[i];
      const double rng = mx - mn;
      if(rng <= 0.0)
         continue;
      const double floor_eps = 0.01 * rng;
      const double offset = (mn <= floor_eps) ? (floor_eps - mn) : 0.0;

      double y[];
      ArrayResize(y, n);
      bool positive = true;
      for(int i = 0; i < n; ++i)
        {
         y[i] = raw[i] + offset;
         if(y[i] <= 0.0) { positive = false; break; }
        }
      if(!positive)
         continue;

      double th = 0.0, mu = 0.0, sg = 0.0, ll = -1e18;
      if(!QM_FitCIR(y, n, th, mu, sg, ll))
         continue;

      if(ll > best_ll)
        {
         best_ll    = ll;
         best_beta  = beta;
         best_off   = offset;
         best_mu    = mu;
         best_theta = th;
         best_sigma = sg;
         found      = true;
        }
     }

   if(!found)
      return false;

   // --- 2. rebuild the chosen spread's CURRENT value ------------------------
   const double s1 = iClose(_Symbol, PERIOD_D1, 1);   // perf-allowed: current host close (last closed bar)
   if(s1 <= 0.0)
      return false;
   double y_curr = 0.0;
   if(g_single_series)
      y_curr = s1 + best_off;
   else
     {
      const double s2 = iClose(g_partner, PERIOD_D1, 1);  // perf-allowed: current partner close (last closed bar)
      if(s2 <= 0.0)
         return false;
      y_curr = s1 - best_beta * s2 + best_off;
     }
   if(y_curr <= 0.0)
      return false;

   // --- 3. CIR stationary std + optimal levels ------------------------------
   // sigma_stat = sigma * sqrt(mu / (2*theta)) (CIR long-run std).
   if(best_theta <= 0.0 || best_mu <= 0.0 || best_sigma <= 0.0)
      return false;
   const double sigma_stat = best_sigma * MathSqrt(best_mu / (2.0 * best_theta));
   if(sigma_stat <= strategy_min_sigma_stat)
      return false;

   const double d_chi = best_mu - strategy_entry_k * sigma_stat;   // optimal entry (cheap)
   const double b_chi = best_mu + strategy_exit_k  * sigma_stat;   // liquidation (reverted)
   const double stop  = best_mu - strategy_stop_k  * sigma_stat;   // model stop band

   // --- 4. qualification: entry/exit band wide enough vs cost cushion -------
   bool ok = true;
   if((b_chi - d_chi) < strategy_cost_cushion_frac * sigma_stat)
      ok = false;                       // band too tight vs estimated cost
   if(d_chi <= 0.0)
      ok = false;                       // entry below positivity floor -> reject

   // --- 5. latch state ------------------------------------------------------
   g_beta       = best_beta;
   g_offset     = best_off;
   g_mu         = best_mu;
   g_sigma_stat = sigma_stat;
   g_d_chi      = d_chi;
   g_b_chi      = b_chi;
   g_stop_level = stop;
   g_y_curr     = y_curr;
   g_cir_ok     = ok;
   g_y_ready    = true;
   return true;
  }

// Advance cached CIR state once per closed D1 bar.
void QM_AdvanceCIRState()
  {
   if(!QM_ComputeCIR())
     {
      g_y_ready = false;
      g_cir_ok  = false;
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
   if(!g_single_series && QM_LegOpenCount(strategy_partner_slot, g_partner) > 0)
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
      const datetime cur_bar = iTime(_Symbol, PERIOD_D1, 0);  // perf-allowed: bar-open time for time-stop count
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

// Cheap O(1) per-tick filter. Fail-OPEN spread guard on the host leg only; the
// CIR logic runs on closed bars. No session restriction (D1 pairs).
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

// Entry on a freshly closed D1 bar. LONG positive spread when Y_t <= d_chi (cheap)
// and the CIR fit qualifies. Host leg opened via the framework path; the partner
// leg opened first via the basket path so both legs go on together.
// Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One pair state at a time: skip if either leg already open (refit-while-flat).
   if(QM_PairHasPosition())
      return false;
   if(!g_y_ready || !g_cir_ok)
      return false;

   // Enter ONLY when the positive spread is at/below the optimal entry level.
   if(g_y_curr > g_d_chi)
      return false;
   // Never enter below the model stop band (already broken-down).
   if(g_y_curr <= g_stop_level)
      return false;

   // LONG positive spread: BUY host (leg1) + SELL partner (leg2) for the basket.
   const string rsn = "cir_long_spread";
   if(!g_single_series)
     {
      if(!QM_OpenPartnerLeg(QM_SELL, rsn))
         return false;                  // never carry a naked leg
     }

   // Host leg for the framework. No fixed SL/TP — pair managed at level basis.
   req.type        = QM_BUY;
   req.price       = 0.0;               // framework fills market price at send
   req.sl          = 0.0;
   req.tp          = 0.0;
   req.reason      = rsn;
   req.symbol_slot = qm_magic_slot_offset;  // host leg slot
   return true;
  }

// No active per-position trade management; pair exits are rule-based on levels.
void Strategy_ManageOpenPosition()
  {
  }

// Pair-level exits: liquidation (Y_t >= b_chi), model stop (Y_t <= stop or <= 0),
// time stop. Returning true triggers the framework host-leg close loop in OnTick;
// we ALSO close the partner leg here so the whole pair unwinds together.
bool Strategy_ExitSignal()
  {
   if(QM_LegOpenCount(qm_magic_slot_offset, _Symbol) <= 0)
      return false;                     // no host position -> nothing to exit

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_y_ready)
     {
      // Liquidation: spread reverted to/above the optimal liquidation level.
      if(g_y_curr >= g_b_chi)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
      // Model stop: breached the lower stop band or positivity guard failed.
      if(!do_exit && (g_y_curr <= g_stop_level || g_y_curr <= 0.0))
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
     }

   // Time stop after the configured holding budget.
   if(!do_exit)
     {
      const int held = QM_HostLegBarsHeld();
      if(held >= 0 && held >= strategy_max_hold_bars)
        { do_exit = true; reason = QM_EXIT_TIME_STOP; }
     }

   if(do_exit && !g_single_series)
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
     }
   return do_exit;
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

   // Resolve the partner leg. Blank or equal to the host => single positive
   // series mode (host-only CIR levels, no basket leg).
   g_partner = strategy_partner_symbol;
   if(StringLen(g_partner) == 0 || g_partner == _Symbol)
     {
      g_partner       = _Symbol;
      g_single_series = true;
     }
   else
      g_single_series = false;

   // BASKET wiring: register host (+ partner) and warm D1 history so the
   // foreign-symbol close reads return real data in the .DWX tester.
   string universe[];
   if(g_single_series)
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
               StringFormat("{\"host\":\"%s\",\"partner\":\"%s\",\"single\":%s,\"host_slot\":%d,\"partner_slot\":%d,\"formation\":%d}",
                            _Symbol, g_partner, (g_single_series ? "true" : "false"),
                            qm_magic_slot_offset, strategy_partner_slot, strategy_formation_bars));
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
   // bar refresh the CIR state BEFORE the rule-based exit so the exit sees current Y.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceCIRState();

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
