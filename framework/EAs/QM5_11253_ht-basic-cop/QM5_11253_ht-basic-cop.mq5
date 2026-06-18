#property strict
#property version   "5.0"
#property description "QM5_11253 ht-basic-cop — Basic-Copula conditional-probability pairs trade (D1, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11253 ht-basic-cop
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Basic Copula Trading Strategy", ArbitrageLab docs
// (source_id af021dd0-e07d-5f72-9933-de7a3533934e); references Liew & Wu (2013),
// Stander, Marais & Botha (2013). Card:
// artifacts/cards_approved/QM5_11253_ht-basic-cop.md (g0 APPROVED).
//
// BASIC COPULA CONDITIONAL-PROBABILITY PAIRS TRADE (BASKET EA). Distinct from the
// QM5_11242 cumulative-flag (mispricing-index) variant: this build uses the
// INSTANTANEOUS conditional probabilities directly as threshold triggers, the
// "basic" copula scheme from the ArbitrageLab Basic Copula notebook.
//
// On each completed D1 bar the EA fits a CLOSED-FORM Gaussian copula over the
// last `FormationBars` D1 log-returns of the host leg (leg1 X) and partner leg
// (leg2 Y), then computes the two conditional probabilities for the MOST RECENT
// return:
//
//   u_X = empirical CDF rank of R_X (formation window) ; u_Y likewise.
//   rho = sin(pi/2 * tau)  with tau = Kendall's tau over the formation window
//         (deterministic CLOSED-FORM method-of-moments — no MLE, no AIC search).
//   P1 = P(U_X <= u_X | U_Y = u_Y) = Phi( (Phi^-1(u_X) - rho*Phi^-1(u_Y)) / sqrt(1-rho^2) )
//   P2 = P(U_Y <= u_Y | U_X = u_X) = Phi( (Phi^-1(u_Y) - rho*Phi^-1(u_X)) / sqrt(1-rho^2) )
//
// Entry (one pair position at a time):
//   P1 <= b_lo AND P2 >= b_up  -> X under-priced / Y over-priced relative to copula
//        -> LONG X (BUY host) + SHORT Y (SELL partner)   [dir = +1]
//   P1 >= b_up AND P2 <= b_lo  -> X over-priced / Y under-priced
//        -> SHORT X (SELL host) + LONG Y (BUY partner)   [dir = -1]
//
// Exit (source "or" exit logic — exit overrides open):
//   - Mean-cross: EITHER conditional probability crosses 0.5 since the position
//     opened (detected via prior-bar vs current-bar sign change around 0.5).
//   - Saturation stop: EITHER probability sits at a boundary (<= b_lo or >= b_up)
//     for `SaturationBars` consecutive closed bars without mean reversion.
//   - Time stop: held >= MaxHoldBars D1 bars.
//
// BASKET WIRING. Host leg trades `_Symbol` through the framework magic
// (slot = qm_magic_slot_offset). Partner leg trades a FOREIGN .DWX symbol via
// QM_BasketOpenPosition with its own registered symbol_slot. Both legs warmed in
// OnInit so foreign-symbol reads return real data in the .DWX tester. One
// position per (magic, symbol).
//
// Pair model (host = leg1 X, partner = leg2 Y), registered in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 XAUUSD.DWX (host C) / slot 0 EURUSD.DWX (partner C, XAU/EUR pair)
// A setfile selects WHICH pair this instance runs (qm_magic_slot_offset = host
// slot, strategy_partner_symbol / strategy_partner_slot = partner leg). Defaults
// bind pair A: EURUSD.DWX host (X) / GBPUSD.DWX partner (Y).
//
// CLOSED-FORM / NO-ML NOTE. The card's baseline names "one fixed copula family".
// This build realises the closed-form Gaussian-copula member: rho is estimated
// by the deterministic Kendall-tau relation rho = sin(pi*tau/2) (method-of-
// moments), and both conditional probabilities are the closed-form Gaussian
// copula h-function with an inline Abramowitz-Stegun NormCDF and Acklam NormInv.
// No iterative optimiser, no MLE, no ML, no PnL-adaptive params.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11253;
input int    qm_magic_slot_offset       = 0;     // HOST (X) leg slot
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
// Partner (leg2 Y) symbol + its registered magic slot. Defaults bind pair A:
// EURUSD.DWX host (X, slot 0) / GBPUSD.DWX partner (Y, slot 1).
input string strategy_partner_symbol    = "GBPUSD.DWX";  // foreign .DWX leg2 (Y)
input int    strategy_partner_slot      = 1;             // partner registered slot
input int    strategy_formation_bars    = 504;   // formation window of D1 returns (P3 {252,504,756})
input double strategy_b_lo              = 0.05;  // lower conditional-prob trigger (P3 {0.03,0.05,0.10})
input double strategy_b_up              = 0.95;  // upper conditional-prob trigger (P3 {0.90,0.95,0.97})
input double strategy_exit_prob         = 0.50;  // mean-cross exit level (P3 {0.45,0.50,0.55})
input int    strategy_max_hold_bars     = 60;    // time stop in D1 bars (P3 {30,60,90})
input int    strategy_saturation_bars   = 5;     // consecutive boundary bars -> stop
input int    strategy_min_d1_bars       = 560;   // need >= FormationBars+buffer synced D1 bars
input double strategy_leg_risk_split    = 0.5;   // share of RISK_FIXED per leg (0.5 each)

// -----------------------------------------------------------------------------
// File-scope cached pair state, advanced once per closed D1 bar.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2 Y)
double   g_p1               = 0.5;    // last closed-bar P(U_X<=u_X | U_Y=u_Y)
double   g_p2               = 0.5;    // last closed-bar P(U_Y<=u_Y | U_X=u_X)
double   g_p1_prev          = 0.5;    // prior closed-bar P1 (for 0.5-cross detect)
double   g_p2_prev          = 0.5;    // prior closed-bar P2 (for 0.5-cross detect)
bool     g_prob_ready       = false;  // last closed bar produced a clean prob step
int      g_sat_bars         = 0;      // consecutive bars with a probability at boundary

// =============================================================================
// CLOSED-FORM standard-normal CDF and inverse CDF (deterministic, bounded).
// =============================================================================

// Standard normal CDF via the Abramowitz & Stegun 7.1.26 erf approximation.
// |error| < 1.5e-7. Pure arithmetic, no iteration.
double QM_NormCDF(const double x)
  {
   const double t = 1.0 / (1.0 + 0.2316419 * MathAbs(x));
   const double d = 0.3989422804014327 * MathExp(-0.5 * x * x); // 1/sqrt(2pi)*exp
   double p = d * t * (0.319381530
                       + t * (-0.356563782
                              + t * (1.781477937
                                     + t * (-1.821255978
                                            + t * 1.330274429))));
   if(x >= 0.0)
      return 1.0 - p;
   return p;
  }

// Inverse standard normal CDF (quantile) via Acklam's rational approximation.
// Bounded, deterministic; relative error < 1.15e-9 over (0,1).
double QM_NormInv(const double p_in)
  {
   // Clamp away from the open-interval endpoints so we never feed +-inf.
   double p = p_in;
   if(p < 1e-12)
      p = 1e-12;
   if(p > 1.0 - 1e-12)
      p = 1.0 - 1e-12;

   const double a1 = -3.969683028665376e+01;
   const double a2 =  2.209460984245205e+02;
   const double a3 = -2.759285104469687e+02;
   const double a4 =  1.383577518672690e+02;
   const double a5 = -3.066479806614716e+01;
   const double a6 =  2.506628277459239e+00;
   const double b1 = -5.447609879822406e+01;
   const double b2 =  1.615858368580409e+02;
   const double b3 = -1.556989798598866e+02;
   const double b4 =  6.680131188771972e+01;
   const double b5 = -1.328068155288572e+01;
   const double c1 = -7.784894002430293e-03;
   const double c2 = -3.223964580411365e-01;
   const double c3 = -2.400758277161838e+00;
   const double c4 = -2.549732539343734e+00;
   const double c5 =  4.374664141464968e+00;
   const double c6 =  2.938163982698783e+00;
   const double d1 =  7.784695709041462e-03;
   const double d2 =  3.224671290700398e-01;
   const double d3 =  2.445134137142996e+00;
   const double d4 =  3.754408661907416e+00;

   const double plow  = 0.02425;
   const double phigh = 1.0 - plow;
   double q, r, x;

   if(p < plow)
     {
      q = MathSqrt(-2.0 * MathLog(p));
      x = (((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) /
          ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0);
     }
   else if(p <= phigh)
     {
      q = p - 0.5;
      r = q * q;
      x = (((((a1 * r + a2) * r + a3) * r + a4) * r + a5) * r + a6) * q /
          (((((b1 * r + b2) * r + b3) * r + b4) * r + b5) * r + 1.0);
     }
   else
     {
      q = MathSqrt(-2.0 * MathLog(1.0 - p));
      x = -(((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) /
           ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0);
     }
   return x;
  }

// =============================================================================
// Basic-copula conditional-probability step over the last `formation` CLOSED D1
// returns of both legs. Computes the two conditional probabilities for the MOST
// RECENT return and feeds them to the caller. Returns false on missing /
// degenerate data (so the EA simply does not step — card "skip insufficient /
// failed fit" rule). Runs once per closed D1 bar (OnTick gates via QM_IsNewBar).
// =============================================================================
bool QM_ComputeCondProb(const int formation, double &p1, double &p2)
  {
   p1 = 0.5;
   p2 = 0.5;
   if(formation < 30)
      return false;

   // Need formation+1 closes => formation returns, on BOTH legs.
   const int n_close = formation + 1;            // shifts 1..formation+1
   if(Bars(_Symbol, PERIOD_D1)   < strategy_min_d1_bars) return false;   // perf-allowed: bar-count availability check
   if(Bars(g_partner, PERIOD_D1) < strategy_min_d1_bars) return false;   // perf-allowed: partner-leg bar-count check

   double cx[];   // host closes, index 0 = shift 1 (last closed)
   double cy[];   // partner closes
   ArrayResize(cx, n_close);
   ArrayResize(cy, n_close);
   for(int i = 0; i < n_close; ++i)
     {
      // perf-allowed: closed-bar host+partner closes for the copula formation
      // window; computed once per closed D1 bar (OnTick gates via QM_IsNewBar).
      const double hx = iClose(_Symbol,   PERIOD_D1, i + 1);   // perf-allowed: closed-bar host close for formation window
      const double hy = iClose(g_partner, PERIOD_D1, i + 1);   // perf-allowed: closed-bar partner close for formation window
      if(hx <= 0.0 || hy <= 0.0)
         return false;                  // missing bar inside lookback -> skip
      cx[i] = hx;
      cy[i] = hy;
     }

   // Log returns over the formation window. rx[k] = log(close_k / close_{k+1}).
   // rx[0] = MOST RECENT return (last closed bar). m = formation samples.
   const int m = formation;
   double rx[];
   double ry[];
   ArrayResize(rx, m);
   ArrayResize(ry, m);
   for(int k = 0; k < m; ++k)
     {
      rx[k] = MathLog(cx[k] / cx[k + 1]);
      ry[k] = MathLog(cy[k] / cy[k + 1]);
     }

   // Empirical CDF (pseudo-observations) via rank/(m+1). Rank of each return =
   // count of window returns strictly less than it. O(m^2) but bounded by
   // formation (<=756) and gated to once per closed D1 bar.
   double ux[];   // empirical CDF of rx
   double uy[];
   ArrayResize(ux, m);
   ArrayResize(uy, m);
   for(int a = 0; a < m; ++a)
     {
      int rank_x = 1;   // ranks are 1..m; +1 baseline so u in (0,1)
      int rank_y = 1;
      for(int b = 0; b < m; ++b)
        {
         if(rx[b] < rx[a]) ++rank_x;
         if(ry[b] < ry[a]) ++rank_y;
        }
      ux[a] = (double)rank_x / (double)(m + 1);
      uy[a] = (double)rank_y / (double)(m + 1);
     }

   // Kendall's tau between the two return series (closed-form, O(m^2)). Counts
   // concordant minus discordant pairs over all i<j.
   long concordant = 0;
   long discordant = 0;
   for(int i = 0; i < m - 1; ++i)
     {
      for(int j = i + 1; j < m; ++j)
        {
         const double dx = rx[i] - rx[j];
         const double dy = ry[i] - ry[j];
         const double prod = dx * dy;
         if(prod > 0.0)      ++concordant;
         else if(prod < 0.0) ++discordant;
         // ties contribute zero
        }
     }
   const double npairs = 0.5 * (double)m * (double)(m - 1);
   if(npairs <= 0.0)
      return false;
   double tau = ((double)(concordant - discordant)) / npairs;
   if(tau > 0.999)  tau = 0.999;
   if(tau < -0.999) tau = -0.999;

   // Gaussian-copula correlation by the closed-form Kendall relation.
   double rho = MathSin(M_PI_2 * tau);
   if(rho > 0.999)  rho = 0.999;
   if(rho < -0.999) rho = -0.999;
   const double one_minus_r2 = 1.0 - rho * rho;
   if(one_minus_r2 <= 1e-12)
      return false;                     // degenerate copula -> skip step
   const double denom = MathSqrt(one_minus_r2);

   // Conditional probabilities for the MOST RECENT return (index 0), via the
   // closed-form Gaussian copula h-function.
   const double zx = QM_NormInv(ux[0]);
   const double zy = QM_NormInv(uy[0]);
   p1 = QM_NormCDF((zx - rho * zy) / denom);  // P(U_X<=u_X | U_Y=u_Y)
   p2 = QM_NormCDF((zy - rho * zx) / denom);  // P(U_Y<=u_Y | U_X=u_X)
   return true;
  }

// Advance cached conditional probabilities once per closed D1 bar. Tracks the
// prior-bar values for the 0.5-cross exit and the consecutive-saturation count.
void QM_AdvanceProbState()
  {
   double np1 = 0.5, np2 = 0.5;
   if(QM_ComputeCondProb(strategy_formation_bars, np1, np2))
     {
      g_p1_prev = g_p1;
      g_p2_prev = g_p2;
      g_p1 = np1;
      g_p2 = np2;
      g_prob_ready = true;

      // Saturation tracking: EITHER probability pinned at a boundary band.
      const bool at_boundary = (g_p1 <= strategy_b_lo || g_p1 >= strategy_b_up ||
                                g_p2 <= strategy_b_lo || g_p2 >= strategy_b_up);
      if(at_boundary)
         g_sat_bars += 1;
      else
         g_sat_bars = 0;
     }
   else
     {
      g_prob_ready = false;
     }
  }

// Reset cached cross / saturation state (on every pair exit, card rule).
void QM_ResetProbState()
  {
   g_p1_prev   = g_p1;
   g_p2_prev   = g_p2;
   g_sat_bars  = 0;
  }

// True if a probability series crossed the exit level (0.5) between the prior
// and current closed bar — used for the source "or" mean-cross exit.
bool QM_ProbCrossed(const double prev, const double cur, const double level)
  {
   return ((prev < level && cur >= level) || (prev > level && cur <= level));
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

// Direction of the open HOST (X) leg: +1 host long, -1 host short, 0 none.
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

// Bars held by the host (X) leg (D1), or -1 if no host position.
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

// Open the partner (leg2 Y) market order on the FOREIGN symbol via basket path.
bool QM_OpenPartnerLeg(const QM_OrderType ot, const string reason)
  {
   QM_BasketOrderRequest br;
   br.symbol             = g_partner;
   br.type               = ot;
   br.price              = 0.0;     // basket path fills market price at send
   br.sl                 = 0.0;     // pair-level (prob) exits manage the position
   br.tp                 = 0.0;
   br.lots               = 0.0;     // 0 -> basket sizes via QM_LotsForRisk
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
// copula logic runs on closed bars. No session restriction (D1 pairs).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                     // no valid quote — defer, never block
   // Block only a genuinely wide modeled spread (zero modeled spread passes).
   const double atr = QM_ATR(_Symbol, PERIOD_D1, 14, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > 0.50 * atr)   // >50% of D1 ATR = pathological
      return true;
   return false;
  }

// Entry on a freshly closed D1 bar. The host (X) leg is opened here through the
// framework path; the partner (Y) leg is opened immediately via the basket path
// so both legs go on together. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One pair position at a time: skip if either leg already open.
   if(QM_PairHasPosition())
      return false;
   if(!g_prob_ready)
      return false;

   const double p1 = g_p1;
   const double p2 = g_p2;
   int dir = 0;                         // +1 long-X/short-Y, -1 short-X/long-Y
   if(p1 <= strategy_b_lo && p2 >= strategy_b_up)
      dir = +1;                         // X cheap / Y rich -> LONG X, SHORT Y
   else if(p1 >= strategy_b_up && p2 <= strategy_b_lo)
      dir = -1;                         // X rich / Y cheap -> SHORT X, LONG Y
   if(dir == 0)
      return false;

   // Host (X) direction; partner (Y) takes the opposite side.
   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY  : QM_SELL;
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open the partner leg FIRST through the basket path. If it fails (e.g. data
   // gap), abort the pair so we never carry a naked single leg.
   const string rsn = (dir > 0) ? "basic_copula_long_x" : "basic_copula_short_x";
   if(!QM_OpenPartnerLeg(partner_ot, rsn))
      return false;

   // Reset the saturation counter on open so the saturation stop measures bars
   // held in the boundary band, not bars accumulated before entry.
   g_sat_bars = 0;

   // Build the host leg for the framework to send. No fixed SL/TP — the pair is
   // managed by the mean-cross / saturation / time-stop exits at the basket level.
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

// Pair-level exits (source "or" logic, exit overrides open):
//   - mean-cross: EITHER conditional probability crosses the exit level (0.5),
//   - saturation stop: EITHER probability pinned at a boundary for N bars,
//   - time stop: held >= MaxHoldBars D1 bars.
// Returning true triggers the framework's host-leg close loop in OnTick; we ALSO
// close the partner leg here so the whole pair unwinds together, then reset the
// cross / saturation state.
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long-X, -1 short-X, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_prob_ready)
     {
      // Mean-cross exit: either conditional probability crossed 0.5 since the
      // prior closed bar.
      if(QM_ProbCrossed(g_p1_prev, g_p1, strategy_exit_prob) ||
         QM_ProbCrossed(g_p2_prev, g_p2, strategy_exit_prob))
        { do_exit = true; reason = QM_EXIT_STRATEGY; }

      // Saturation stop: a probability stuck at the boundary band without mean
      // reversion for the configured number of consecutive bars.
      if(!do_exit && g_sat_bars >= strategy_saturation_bars)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
     }

   // Time stop: close the pair after N D1 bars held.
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
      QM_ResetProbState();              // reset cross / saturation state on exit
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
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_formation_bars + 80);

   QM_ResetProbState();
   g_p1 = 0.5;
   g_p2 = 0.5;
   g_p1_prev = 0.5;
   g_p2_prev = 0.5;
   g_prob_ready = false;
   g_sat_bars = 0;

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"partner\":\"%s\",\"host_slot\":%d,\"partner_slot\":%d,\"formation\":%d}",
                            _Symbol, g_partner, qm_magic_slot_offset,
                            strategy_partner_slot, strategy_formation_bars));
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
   // D1 bar, advance the conditional-probability state BEFORE the rule-based
   // exit so the exit sees the current probabilities.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceProbState();

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
