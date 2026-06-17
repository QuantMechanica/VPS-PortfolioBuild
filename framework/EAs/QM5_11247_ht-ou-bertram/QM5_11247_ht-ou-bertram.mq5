#property strict
#property version   "5.0"
#property description "QM5_11247 ht-ou-bertram — Bertram (2010) optimal OU trading thresholds for a mean-reverting pair spread (H4, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11247 ht-ou-bertram
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "OU Model Optimal Trading Thresholds Bertram",
// ArbitrageLab docs (source_id af021dd0-e07d-5f72-9933-de7a3533934e); primary
// reference Bertram, W.K. (2010), "Analytic solutions for optimal statistical
// arbitrage trading", Physica A.
// Card: artifacts/cards_approved/QM5_11247_ht-ou-bertram.md (g0 APPROVED).
//
// BERTRAM OPTIMAL-OU-THRESHOLD RELATIVE-VALUE PAIRS TRADE (BASKET EA). On each
// completed H4 bar the EA builds a log-price pair spread over a fixed FORMATION
// window, fits the Ornstein-Uhlenbeck parameters CLOSED-FORM from an AR(1)
// regression of the spread, then solves the Bertram optimal entry/exit levels
// by maximising the (cost-aware) Sharpe ratio per unit time over a deterministic
// bounded scan of dimensionless levels. NO iterative MLE, NO ML, NO grid/martingale.
//
// OU FIT (closed-form, per card "AR(1) regression -> OU via -ln(slope)"):
//   spread series S_t = log(host) - hedge*log(partner) over the formation window.
//   AR(1):  S_t = c + phi * S_{t-1} + e_t   (OLS, deterministic).
//   theta   = -ln(phi)                       (OU mean-reversion speed per bar; phi in (0,1))
//   mu      = c / (1 - phi)                   (OU long-run mean)
//   sigma_e = std(residual e_t)
//   sigma_eq= sigma_e / sqrt(1 - phi*phi)     (equilibrium / stationary std of S)
// A reverting spread needs 0 < phi < 1 (=> theta > 0). Otherwise no trade.
//
// BERTRAM THRESHOLDS (deterministic bounded scan, dimensionless levels k):
//   For each candidate entry level k (in equilibrium-sigma units below the mean):
//     entry a   = mu - k * sigma_eq      (long-spread entry; spread cheap)
//     exit  m   = mu + k * sigma_eq      (symmetric liquidation around the mean)
//   The expected one-way move is 2*k*sigma_eq, expected cycle time ~ ln-based
//   first-passage time that grows with k, and per-cycle cost = transaction_cost.
//   Pick k* maximising the cost-adjusted Sharpe-per-unit-time proxy
//     S(k) = (2*k*sigma_eq - cost) * sqrt(theta) / (k * sigma_eq + eps)
//   subject to net expected return per cycle > 0 (card filter "minimum expected
//   return per unit time must be positive after transaction cost"). This is the
//   closed-form Bertram objective family (maximise Sharpe per unit time after
//   cost) evaluated on a finite, deterministic level grid — no optimiser loop
//   over the data, no PnL-adaptive parameters.
//
// TRADING (card "Trading Strategy"):
//   S_t <= a  -> spread cheap  -> LONG  spread: BUY  host (leg1) + SELL partner (leg2)
//   S_t >= m' -> spread rich   -> SHORT spread: SELL host (leg1) + BUY  partner (leg2)
//     where the SHORT side mirrors the level logic on -S (entry mu + k*sigma_eq,
//     exit mu - k*sigma_eq).
//   Exit long  when S_t >= m  (reverted through the mean to the liquidation band).
//   Exit short when S_t <= mirrored exit.
//   Protective stop: |S_t - mu| >= stop_sigma_mult * sigma_eq.
//   Time stop: held >= min(expected first-passage proxy, max_hold_bars) H4 bars.
//
// FILTERS (card): refit thresholds only while FLAT (fixed cadence, not PnL-driven);
// skip if phi not in (0,1) (non-reverting / non-positive theta), sigma_eq==0, the
// entry band sits inside the transaction cost, or net expected return <= 0.
//
// BASKET WIRING. Host leg trades `_Symbol` via the framework magic
// (slot = qm_magic_slot_offset). Partner leg trades a FOREIGN .DWX symbol via
// QM_BasketOpenPosition at its own registered symbol_slot. Both legs are warmed
// in OnInit so foreign-symbol reads return real data in the .DWX tester. One
// position per (magic, symbol). All legs close together.
//
// Pair model (host = leg1, partner = leg2), to register in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 XAUUSD.DWX (host C) / slot 5 EURUSD.DWX (partner C, cross test)
// All legs are REAL .DWX symbols in dwx_symbol_matrix.csv — no port needed.
// XAUUSD/EURUSD cross (pair C) is a card-stated PORTING test, not source-stated.
// A setfile selects which pair an instance runs by binding:
//   qm_magic_slot_offset    = host leg slot (matches the host symbol it runs on)
//   strategy_partner_symbol = the partner .DWX symbol
//   strategy_partner_slot   = the partner leg slot
// (default = pair A on EURUSD.DWX host / GBPUSD.DWX partner).
//
// Only the five Strategy_* hooks + OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11247;
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
input int    strategy_formation_bars    = 252;   // OU formation window in H4 bars (P3 {126,252,504})
input double strategy_transaction_cost  = 0.001; // round-trip cost in spread (log) units (P3 {0.0005,0.001,0.002})
input double strategy_stop_sigma_mult   = 3.0;   // protective stop at |S-mu| >= mult*sigma_eq (P3 {2.5,3.0,3.5})
input int    strategy_max_hold_bars     = 60;    // hard time-stop cap in H4 bars (P3 {40,60,90})
input double strategy_min_level         = 0.5;   // smallest dimensionless entry level k to scan (sigma_eq units)
input double strategy_max_level         = 2.5;   // largest dimensionless entry level k to scan
input double strategy_level_step        = 0.25;  // scan step for the Bertram level grid
input int    strategy_min_h4_bars       = 320;   // need >= formation_bars + buffer synced H4 bars

// -----------------------------------------------------------------------------
// File-scope cached pair / OU state, advanced once per closed H4 bar.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2)
bool     g_ou_ready         = false;  // OU fit well-formed + reverting + cost-feasible
double   g_spread_curr      = 0.0;    // last closed-bar log-price spread S_t
double   g_mu               = 0.0;    // OU long-run mean
double   g_sigma_eq         = 0.0;    // OU equilibrium std
double   g_theta            = 0.0;    // OU mean-reversion speed (per bar)
double   g_entry_a          = 0.0;    // long-spread entry level  (mu - k*sigma_eq)
double   g_exit_m           = 0.0;    // long-spread exit level   (mu + k*sigma_eq)
double   g_entry_short      = 0.0;    // short-spread entry level (mu + k*sigma_eq)
double   g_exit_short       = 0.0;    // short-spread exit level  (mu - k*sigma_eq)
int      g_time_stop_bars   = 0;      // first-passage time-stop budget (H4 bars), latched per fit

// -----------------------------------------------------------------------------
// Closed-form OU fit + Bertram optimal-threshold solve over CLOSED H4 bars.
// Builds the log-price spread over `formation` bars (hedge ratio = OLS slope of
// log(host) on log(partner)), fits OU via AR(1) (theta = -ln(phi)), then scans a
// deterministic dimensionless level grid for the cost-aware Sharpe-per-time peak.
// Returns false on missing / degenerate / non-reverting / cost-infeasible data so
// the EA simply does not trade (card "skip if non-positive mu / unstable / inside
// transaction cost").
// -----------------------------------------------------------------------------
bool QM_ComputeBertramOU(const int formation)
  {
   g_ou_ready       = false;
   g_spread_curr    = 0.0;
   g_mu             = 0.0;
   g_sigma_eq       = 0.0;
   g_theta          = 0.0;
   g_entry_a        = 0.0;
   g_exit_m         = 0.0;
   g_entry_short    = 0.0;
   g_exit_short     = 0.0;
   g_time_stop_bars = 0;

   if(formation < 40)
      return false;

   // Need `formation` closed bars (shift 1..formation) on BOTH legs.
   if(Bars(_Symbol,  PERIOD_H4) < strategy_min_h4_bars) return false;   // perf-allowed: bar-count availability check
   if(Bars(g_partner, PERIOD_H4) < strategy_min_h4_bars) return false;  // perf-allowed: partner-leg bar-count check

   const int n = formation;             // bars 1..n, index 0 = shift 1 (last closed)
   double lh[];   // log host close,    index 0 = last closed (shift 1)
   double lp[];   // log partner close, index 0 = last closed (shift 1)
   ArrayResize(lh, n);
   ArrayResize(lp, n);
   for(int i = 0; i < n; ++i)
     {
      // perf-allowed: closed-bar foreign+host close reads for the formation window;
      // computed once per closed H4 bar (OnTick gates this via QM_IsNewBar).
      const double ch = iClose(_Symbol,   PERIOD_H4, i + 1);   // perf-allowed: closed-bar host close for formation window
      const double cp = iClose(g_partner, PERIOD_H4, i + 1);   // perf-allowed: closed-bar partner close for formation window
      if(ch <= 0.0 || cp <= 0.0)
         return false;                  // missing bar inside lookback -> no trade
      lh[i] = MathLog(ch);
      lp[i] = MathLog(cp);
     }

   // Hedge ratio = OLS slope of log(host) on log(partner) over the formation window.
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   const double dn = (double)n;
   for(int i = 0; i < n; ++i)
     {
      sx  += lp[i];
      sy  += lh[i];
      sxx += lp[i] * lp[i];
      sxy += lp[i] * lh[i];
     }
   const double den = dn * sxx - sx * sx;
   if(MathAbs(den) < 1e-12)
      return false;                     // degenerate regressor -> no trade
   const double hedge     = (dn * sxy - sx * sy) / den;
   const double intercept = (sy - hedge * sx) / dn;

   // Spread series: S[i] = log(host) - (intercept + hedge*log(partner)).
   // index 0 = last closed bar; higher index = older.
   double sp[];
   ArrayResize(sp, n);
   for(int i = 0; i < n; ++i)
      sp[i] = lh[i] - (intercept + hedge * lp[i]);

   // --- closed-form OU via AR(1): S_t = c + phi*S_{t-1} + e ------------------
   // index 0 is newest, so S_{t-1} = sp[i+1], S_t = sp[i].  Regress sp[i] on sp[i+1].
   double bx = 0.0, by = 0.0, bxx = 0.0, bxy = 0.0;
   const int m = n - 1;                 // number of (prev, curr) pairs
   for(int i = 0; i < m; ++i)
     {
      const double prev = sp[i + 1];
      const double curr = sp[i];
      bx  += prev;
      by  += curr;
      bxx += prev * prev;
      bxy += prev * curr;
     }
   const double dm   = (double)m;
   const double bden = dm * bxx - bx * bx;
   if(MathAbs(bden) < 1e-12)
      return false;
   const double phi = (dm * bxy - bx * by) / bden;      // AR(1) slope
   const double c   = (by - phi * bx) / dm;             // AR(1) intercept

   // Reverting spread requires 0 < phi < 1  =>  theta = -ln(phi) > 0.
   if(phi <= 0.0 || phi >= 1.0)
      return false;
   const double theta = -MathLog(phi);
   if(theta <= 0.0)
      return false;
   const double mu = c / (1.0 - phi);                   // OU long-run mean

   // Residual std of the AR(1) fit -> OU equilibrium std.
   double sse = 0.0;
   for(int i = 0; i < m; ++i)
     {
      const double pred = c + phi * sp[i + 1];
      const double e    = sp[i] - pred;
      sse += e * e;
     }
   const double sigma_e = MathSqrt(sse / dm);
   const double denom_eq = 1.0 - phi * phi;
   if(denom_eq <= 1e-12 || sigma_e <= 0.0)
      return false;
   const double sigma_eq = sigma_e / MathSqrt(denom_eq);
   if(sigma_eq <= 1e-12)
      return false;                     // degenerate spread std -> no trade (card rule)

   // --- Bertram optimal level: deterministic bounded Sharpe-per-time scan ----
   // Maximise S(k) = (gross_move - cost) * sqrt(theta) / (band + eps) over a
   // finite k grid; require net expected return per cycle > 0 (after cost).
   double best_k     = 0.0;
   double best_score = -1.0e18;
   bool   found      = false;
   const double cost = (strategy_transaction_cost > 0.0) ? strategy_transaction_cost : 0.0;
   for(double k = strategy_min_level; k <= strategy_max_level + 1e-9; k += strategy_level_step)
     {
      if(k <= 0.0)
         continue;
      const double band       = k * sigma_eq;           // distance mean->entry (= mean->exit)
      const double gross_move = 2.0 * band;             // entry->exit traversal in spread units
      const double net        = gross_move - cost;      // net expected per-cycle return after cost
      if(net <= 0.0)
         continue;                                      // card: skip if inside transaction cost
      // Sharpe-per-unit-time proxy: faster reversion (sqrt(theta)) and bigger net
      // edge favoured; wider band lengthens cycle time -> penalised in denominator.
      const double score = net * MathSqrt(theta) / (band + 1e-12);
      if(score > best_score)
        {
         best_score = score;
         best_k     = k;
         found      = true;
        }
     }
   if(!found)
      return false;                     // no cost-feasible level -> no trade

   const double band = best_k * sigma_eq;
   g_theta       = theta;
   g_mu          = mu;
   g_sigma_eq    = sigma_eq;
   g_entry_a     = mu - band;           // long-spread entry  (spread cheap)
   g_exit_m      = mu + band;           // long-spread exit   (reverted through mean)
   g_entry_short = mu + band;           // short-spread entry (spread rich)
   g_exit_short  = mu - band;           // short-spread exit
   g_spread_curr = sp[0];               // last closed-bar spread

   // Time-stop budget: OU mean first-passage scales ~ 1/theta; use ~3 mean-reversion
   // times (3/theta bars) capped at max_hold_bars. Deterministic, no PnL adaptation.
   int ts = (int)MathRound(3.0 / theta);
   if(ts < 1) ts = 1;
   if(ts > strategy_max_hold_bars) ts = strategy_max_hold_bars;
   g_time_stop_bars = ts;

   g_ou_ready = true;
   return true;
  }

// Advance cached OU/Bertram state once per closed H4 bar. Card filter: refit
// thresholds only while FLAT. While a pair is open we keep the latched levels and
// only refresh the current spread so exits use the live spread but stable bands.
void QM_AdvanceBertramState()
  {
   if(QM_PairHasPositionFwd())
     {
      // Flat-only refit: keep latched mu/sigma/levels; refresh current spread only.
      double s = 0.0;
      if(QM_CurrentSpreadOnly(strategy_formation_bars, s))
         g_spread_curr = s;
      return;
     }
   QM_ComputeBertramOU(strategy_formation_bars);
  }

// Lightweight current-spread read using the latched hedge fit is not retained, so
// recompute the hedge over the formation window and return only the newest spread.
// Used while a position is open (flat-only refit rule) so exits track the live
// spread without re-solving the Bertram thresholds.
bool QM_CurrentSpreadOnly(const int formation, double &out_spread)
  {
   out_spread = 0.0;
   if(formation < 40)
      return false;
   if(Bars(_Symbol,  PERIOD_H4) < strategy_min_h4_bars) return false;  // perf-allowed: bar-count check
   if(Bars(g_partner, PERIOD_H4) < strategy_min_h4_bars) return false; // perf-allowed: partner bar-count check

   const int n = formation;
   double lh[]; double lp[];
   ArrayResize(lh, n);
   ArrayResize(lp, n);
   for(int i = 0; i < n; ++i)
     {
      const double ch = iClose(_Symbol,   PERIOD_H4, i + 1);  // perf-allowed: closed-bar host close
      const double cp = iClose(g_partner, PERIOD_H4, i + 1);  // perf-allowed: closed-bar partner close
      if(ch <= 0.0 || cp <= 0.0)
         return false;
      lh[i] = MathLog(ch);
      lp[i] = MathLog(cp);
     }
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   const double dn = (double)n;
   for(int i = 0; i < n; ++i)
     {
      sx  += lp[i]; sy  += lh[i];
      sxx += lp[i]*lp[i]; sxy += lp[i]*lh[i];
     }
   const double den = dn*sxx - sx*sx;
   if(MathAbs(den) < 1e-12)
      return false;
   const double hedge     = (dn*sxy - sx*sy) / den;
   const double intercept = (sy - hedge*sx) / dn;
   out_spread = lh[0] - (intercept + hedge*lp[0]);
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
bool QM_PairHasPositionFwd()
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
// pair logic runs on closed bars. No session restriction (H4 pairs).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                     // no valid quote — defer, never block
   const double atr = QM_ATR(_Symbol, PERIOD_H4, 14, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > 0.50 * atr)   // >50% of H4 ATR = pathological (fail-open on 0 spread)
      return true;
   return false;
  }

// Entry on a freshly closed H4 bar. Host leg opened via the framework path; the
// partner leg opened first via the basket path so both legs go on together.
// Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One pair state at a time: skip if either leg already open.
   if(QM_PairHasPositionFwd())
      return false;
   if(!g_ou_ready)                       // require a valid, cost-feasible OU fit
      return false;

   const double s = g_spread_curr;
   int dir = 0;                          // +1 long-spread, -1 short-spread
   if(s <= g_entry_a)
      dir = +1;                          // spread cheap  -> LONG  spread
   else if(s >= g_entry_short)
      dir = -1;                          // spread rich   -> SHORT spread
   if(dir == 0)
      return false;

   // Host (leg1): long-spread -> BUY host; short-spread -> SELL host.
   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY : QM_SELL;
   // Partner (leg2) takes the OPPOSITE side for market-neutral exposure.
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open the partner leg FIRST. If it fails, abort so we never carry a naked leg.
   const string rsn = (dir > 0) ? "bertram_long_spread" : "bertram_short_spread";
   if(!QM_OpenPartnerLeg(partner_ot, rsn))
      return false;

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

// Pair-level exits: Bertram liquidation band, protective sigma stop, time stop.
// Returning true triggers the framework's host-leg close loop in OnTick; we ALSO
// close the partner leg here so the whole pair unwinds together.
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long-spread, -1 short-spread, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_ou_ready || g_sigma_eq > 0.0)
     {
      const double s = g_spread_curr;
      // Bertram liquidation band: long exits at/above m, short exits at/below mirror.
      if(host_dir > 0 && s >= g_exit_m)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
      else if(host_dir < 0 && s <= g_exit_short)
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
      // Protective stop: spread diverged too far from the OU mean.
      if(!do_exit && g_sigma_eq > 0.0)
        {
         const double dev = MathAbs(s - g_mu);
         if(dev >= strategy_stop_sigma_mult * g_sigma_eq)
           { do_exit = true; reason = QM_EXIT_STRATEGY; }
        }
     }

   // Time stop: close the pair after the OU-derived bar budget.
   if(!do_exit)
     {
      const int budget = (g_time_stop_bars > 0) ? g_time_stop_bars : strategy_max_hold_bars;
      const int held = QM_HostLegBarsHeld();
      if(held >= 0 && held >= budget)
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
   QM_BasketWarmupHistory(universe, PERIOD_H4, strategy_formation_bars + 80);

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

   // Latch the closed-bar event ONCE (single-consume) and reuse it. On a fresh H4
   // bar refresh the OU/Bertram state BEFORE the rule-based exit so the exit sees
   // the current spread.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceBertramState();

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
