#property strict
#property version   "5.0"
#property description "QM5_11242 ht-copula-mpi — Gaussian-copula Mispricing-Index cumulative-flag pairs trade (D1, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11242 ht-copula-mpi
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Copula Strategy Using Mispricing Index" notebook
// (source_id af021dd0-e07d-5f72-9933-de7a3533934e); primary reference Xie, Liew,
// Wu & Zou, "Pairs trading with copulas", 2016. Card:
// artifacts/cards_approved/QM5_11242_ht-copula-mpi.md (g0 APPROVED).
//
// COPULA MISPRICING-INDEX PAIRS TRADE (BASKET EA). On each completed D1 bar the
// EA fits a CLOSED-FORM Gaussian copula over the last `FormationBars` D1 returns
// of the host leg (leg1) and the partner leg (leg2), then computes the two
// conditional "mispricing index" probabilities and accumulates them into two
// cumulative flags:
//
//   u_X = empirical CDF rank of R_X (formation window) ; u_Y likewise.
//   rho = sin(pi/2 * tau)  with tau = Kendall's tau over the formation window
//         (deterministic CLOSED-FORM method-of-moments — no MLE, no AIC search).
//   MI_X_given_Y = P(U_X <= u_X | U_Y = u_Y)
//               = Phi( ( Phi^{-1}(u_X) - rho*Phi^{-1}(u_Y) ) / sqrt(1-rho^2) )
//   MI_Y_given_X = P(U_Y <= u_Y | U_X = u_X)  (symmetric in X<->Y).
//   FlagX += (MI_X_given_Y - 0.5) ; FlagY += (MI_Y_given_X - 0.5).
//
// Entry (one pair position at a time):
//   FlagX <= -OpenFlag AND FlagY >= +OpenFlag  -> X cheap / Y rich
//        -> LONG X (BUY host) + SHORT Y (SELL partner)   [dir = +1]
//   FlagX >= +OpenFlag AND FlagY <= -OpenFlag  -> X rich / Y cheap
//        -> SHORT X (SELL host) + LONG Y (BUY partner)   [dir = -1]
//
// Exit:
//   - Revert: both |FlagX| <= ExitFlag AND |FlagY| <= ExitFlag.
//   - Stop:   |FlagX| >= StopFlag OR |FlagY| >= StopFlag.
//   - Time:   held >= MaxHoldBars D1 bars.
//   On ANY exit the real flag series are RESET to zero (card rule).
//
// BASKET WIRING. Host leg trades `_Symbol` through the framework magic
// (slot = qm_magic_slot_offset). Partner leg trades a FOREIGN .DWX symbol via
// QM_BasketOpenPosition with its own registered symbol_slot. Both legs warmed
// in OnInit so foreign-symbol reads return real data in the .DWX tester. One
// position per (magic, symbol).
//
// Pair model (host = leg1 X, partner = leg2 Y), registered in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 NDX.DWX    (host C) / slot 5 WS30.DWX   (partner C)
// A setfile selects WHICH pair this instance runs (qm_magic_slot_offset =
// host slot, strategy_partner_symbol / strategy_partner_slot = partner leg).
//
// CLOSED-FORM / NO-ML NOTE. The card's baseline names an AIC family selection
// (Gaussian/Student/Frank/Clayton/Gumbel). A full multi-family AIC fit needs an
// iterative MLE optimiser, which V5 HR14 forbids. This build realises the
// closed-form Gaussian-copula member of that set: rho is estimated by the
// deterministic Kendall-tau relation rho = sin(pi*tau/2) (method-of-moments),
// and the conditional MPI is the closed-form Gaussian h-function. No iterative
// optimiser, no ML, no PnL-adaptive params. (Flagged in build open_questions.)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11242;
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
// EURUSD.DWX host (X) / GBPUSD.DWX partner (Y).
input string strategy_partner_symbol    = "GBPUSD.DWX";  // foreign .DWX leg2 (Y)
input int    strategy_partner_slot      = 1;             // partner registered slot
input int    strategy_formation_bars    = 252;   // formation window of D1 returns (P3 {126,252,504})
input double strategy_open_flag         = 0.6;   // cumulative-flag open threshold (P3 {0.4,0.6,0.8,1.0})
input double strategy_exit_flag         = 0.1;   // revert-to-flat threshold (P3 {0.0,0.1,0.2})
input double strategy_stop_flag         = 1.5;   // flag-overextension stop (P3 {1.2,1.5,2.0})
input int    strategy_max_hold_bars     = 45;    // time stop in D1 bars (P3 {20,45,60})
input int    strategy_min_d1_bars       = 320;   // need >= FormationBars+buffer synced D1 bars
input double strategy_leg_risk_split    = 0.5;   // share of RISK_FIXED per leg (0.5 each)

// -----------------------------------------------------------------------------
// File-scope cached pair state, advanced once per closed D1 bar.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2 Y)
double   g_flag_x           = 0.0;    // cumulative mispricing flag, host (X)
double   g_flag_y           = 0.0;    // cumulative mispricing flag, partner (Y)
bool     g_mpi_ready        = false;  // last closed bar produced a clean MPI step

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
// Copula MPI step over the last `formation` CLOSED D1 returns of both legs.
// Computes the two conditional mispricing indices for the MOST RECENT return
// and feeds them to the caller. Returns false on missing / degenerate data
// (so the EA simply does not step its flags — card "skip insufficient/failed
// fit" rule). Runs once per closed D1 bar (OnTick gates via QM_IsNewBar).
// =============================================================================
bool QM_ComputeMPI(const int formation, double &mi_x_given_y, double &mi_y_given_x)
  {
   mi_x_given_y = 0.5;
   mi_y_given_x = 0.5;
   if(formation < 30)
      return false;

   // Need formation+1 closes => formation returns, on BOTH legs.
   const int n_close = formation + 1;            // shifts 1..formation+1
   if(Bars(_Symbol, PERIOD_D1)  < strategy_min_d1_bars) return false;   // perf-allowed: bar-count availability check
   if(Bars(g_partner, PERIOD_D1) < strategy_min_d1_bars) return false;  // perf-allowed: partner-leg bar-count check

   double cx[];   // host closes, index 0 = shift 1 (last closed)
   double cy[];   // partner closes
   ArrayResize(cx, n_close);
   ArrayResize(cy, n_close);
   for(int i = 0; i < n_close; ++i)
     {
      // perf-allowed: closed-bar host+partner closes for the copula formation
      // window; computed once per closed D1 bar (OnTick gates via QM_IsNewBar).
      const double hx = iClose(_Symbol,  PERIOD_D1, i + 1);   // perf-allowed: closed-bar host close for formation window
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
   // formation (<=504) and gated to once per closed D1 bar.
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

   // Conditional mispricing indices for the MOST RECENT return (index 0), via
   // the closed-form Gaussian copula h-function.
   const double zx = QM_NormInv(ux[0]);
   const double zy = QM_NormInv(uy[0]);
   mi_x_given_y = QM_NormCDF((zx - rho * zy) / denom);  // P(U_X<=u_X | U_Y=u_Y)
   mi_y_given_x = QM_NormCDF((zy - rho * zx) / denom);  // P(U_Y<=u_Y | U_X=u_X)
   return true;
  }

// Advance cached cumulative flags once per closed D1 bar.
void QM_AdvanceMPIState()
  {
   double mxy = 0.5, myx = 0.5;
   if(QM_ComputeMPI(strategy_formation_bars, mxy, myx))
     {
      g_flag_x += (mxy - 0.5);
      g_flag_y += (myx - 0.5);
      g_mpi_ready = true;
     }
   else
     {
      g_mpi_ready = false;
     }
  }

// Reset the cumulative real-flag series to zero (on every pair exit, card rule).
void QM_ResetFlags()
  {
   g_flag_x = 0.0;
   g_flag_y = 0.0;
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
      const long mg = PositionGetInteger(POSITION_MAGIC);
      if(mg == host_magic || mg == partner_magic)
         QM_TM_ClosePosition(ticket, reason);
     }
  }

// Open the partner (leg2 Y) market order on the FOREIGN symbol via basket path.
bool QM_OpenPartnerLeg(const QM_OrderType ot, const string reason)
  {
   QM_BasketOrderRequest br;
   br.symbol             = g_partner;
   br.type               = ot;
   br.price              = 0.0;     // basket path fills market price at send
   br.sl                 = 0.0;     // pair-level (flag) exits manage the position
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
   if(!g_mpi_ready)
      return false;

   const double fx = g_flag_x;
   const double fy = g_flag_y;
   int dir = 0;                         // +1 long-X/short-Y, -1 short-X/long-Y
   if(fx <= -strategy_open_flag && fy >= strategy_open_flag)
      dir = +1;                         // X cheap / Y rich -> LONG X, SHORT Y
   else if(fx >= strategy_open_flag && fy <= -strategy_open_flag)
      dir = -1;                         // X rich / Y cheap -> SHORT X, LONG Y
   if(dir == 0)
      return false;

   // Host (X) direction; partner (Y) takes the opposite side.
   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY  : QM_SELL;
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open the partner leg FIRST through the basket path. If it fails (e.g. data
   // gap), abort the pair so we never carry a naked single leg.
   const string rsn = (dir > 0) ? "copula_mpi_long_x" : "copula_mpi_short_x";
   if(!QM_OpenPartnerLeg(partner_ot, rsn))
      return false;

   // Build the host leg for the framework to send. No fixed SL/TP — the pair is
   // managed by the flag revert / stop / time-stop exits at the basket level.
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

// Pair-level exits: cumulative-flag revert, flag-overextension stop, time stop.
// Returning true triggers the framework's host-leg close loop in OnTick; we
// ALSO close the partner leg here so the whole pair unwinds together, then
// RESET the cumulative flags (card rule).
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long-X, -1 short-X, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_mpi_ready)
     {
      const double afx = MathAbs(g_flag_x);
      const double afy = MathAbs(g_flag_y);
      // Revert to flat: both flags back inside the exit band.
      if(afx <= strategy_exit_flag && afy <= strategy_exit_flag)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
      // Stop: either flag overextends beyond the stop band.
      if(!do_exit && (afx >= strategy_stop_flag || afy >= strategy_stop_flag))
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
      QM_ResetFlags();                  // reset real flag series on every exit
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

   QM_ResetFlags();

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
   // D1 bar, advance the copula MPI cumulative flags BEFORE the rule-based exit
   // so the exit sees the current flags.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceMPIState();

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
