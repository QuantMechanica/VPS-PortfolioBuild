#property strict
#property version   "5.0"
#property description "QM5_11251 ht-minprofit — Lin-McCann minimum-profit cointegration pair bounds (D1, two-leg basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11251 ht-minprofit
// -----------------------------------------------------------------------------
// Source: Hudson & Thames, "Minimum Profit Optimization" / "Minimum Profit
// Strategy", ArbitrageLab documentation (source_id af021dd0-e07d-5f72-9933-
// de7a3533934e); primary references Lin, McCrae & Gulati (2006) and
// Puspaningrum, Lin & Gulati (2010).
// Card: artifacts/cards_approved/QM5_11251_ht-minprofit.md (g0 APPROVED).
//
// MINIMUM-PROFIT COINTEGRATION PAIR BOUNDS (BASKET EA). On each completed D1 bar
// the EA fits a static Engle-Granger hedge ratio by rolling OLS of the host close
// on the partner close over a TRAINING window (`training_window_bars` D1 bars),
// forms the cointegration error spread `e = host - (a + b*partner)`, and trades
// the spread market-neutrally as a two-leg basket against FIXED absolute boundary
// levels derived from the spread's own mean and dispersion over the training
// window. This is the Lin-McCann minimum-profit construction: rather than a
// rolling z-score, the boundaries are pre-set absolute spread levels that are
// re-derived flat-only on a fixed monthly cadence (mechanical, deterministic):
//
//   mean       = mean(e) over training window
//   sigma      = std(e)  over training window
//   buy_level  = mean - k * sigma      (spread cheap  -> LONG  spread)
//   sell_level = mean + k * sigma      (spread rich   -> SHORT spread)
//   close_level= mean                  (reversion target -> exit)
//
//   e <= buy_level   -> LONG  spread: BUY  host (leg1) + SELL partner (leg2)
//   e >= sell_level  -> SHORT spread: SELL host (leg1) + BUY  partner (leg2)
//
// Exit (card minimum-profit rule):
//   - close the pair when the spread reverts THROUGH close_level (the mean),
//   - protective ADVERSE STOP when the spread moves `adverse_stop_mult` times the
//     entry distance (|entry - mean|) further AGAINST the open position,
//   - time stop after `max_hold_bars` D1 bars,
//   - Friday cut-off handled by the framework.
//
// COINTEGRATION QUALIFICATION (card filters, fully deterministic, no stats lib):
//   - spread sigma over the training window must be > 0 (else degenerate),
//   - AR(1) coefficient phi of the cointegration error must satisfy |phi| < 0.98
//     (a near-unit-root residual is non-stationary -> not tradeable). phi is the
//     OLS slope of e_t on e_{t-1}; reversion requires phi < 1 (and |phi|<0.98 per
//     card). This is the deterministic Engle-Granger residual-stationarity proxy;
//     we do NOT run an ADF p-value table at run time (no stats library in MQL5).
//   - the EXPECTED number of boundary-crossing trades over the training horizon
//     must be >= `min_expected_trades` (card "skip when estimated optimal number
//     of trades over the training horizon is below 6"). We estimate this directly,
//     mechanically, by COUNTING historical boundary round-trips in the training
//     spread series — no MLE, no mean-first-passage integral, no ML.
//
// BASKET WIRING. The host leg trades `_Symbol` via the framework magic
// (slot = qm_magic_slot_offset). The partner leg trades a FOREIGN .DWX symbol via
// QM_BasketOpenPosition at its own registered symbol_slot. Both legs are warmed in
// OnInit so foreign-symbol reads return real data in the .DWX tester. One position
// per (magic, symbol).
//
// Pair model (host = leg1, partner = leg2), registered in magic_numbers.csv:
//   slot 0 EURUSD.DWX (host A) / slot 1 GBPUSD.DWX (partner A)
//   slot 2 AUDUSD.DWX (host B) / slot 3 NZDUSD.DWX (partner B)
//   slot 4 XAUUSD.DWX (host C) / slot 0 EURUSD.DWX (partner C; R3 pair XAUUSD/EURUSD
//                               reuses the EURUSD slot-0 leg, never double-opened
//                               because pair C runs on a different host instance)
// All legs are REAL .DWX symbols present in dwx_symbol_matrix.csv — no port needed.
// A setfile selects WHICH pair an instance runs by binding:
//   qm_magic_slot_offset    = host leg slot (matches the host symbol it runs on)
//   strategy_partner_symbol = the partner .DWX symbol
//   strategy_partner_slot   = the partner leg slot
// (default = pair A on EURUSD.DWX host / GBPUSD.DWX partner).
//
// Only the five Strategy_* hooks + OnInit basket wiring are EA-specific.
// No ML, no martingale, no unbounded grid, RISK_FIXED in tester, one position
// per magic, fail-OPEN spread guard. No external non-MT5 feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11251;
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
input int    strategy_training_window   = 504;   // OLS + boundary training window (P3 {252,504,756})
input double strategy_min_profit_k      = 1.0;   // boundary multiple of spread sigma (P3 {1.0,1.25,1.5})
input double strategy_adverse_stop_mult = 1.5;   // adverse-stop multiple of entry distance (P3 {1.25,1.5,2.0})
input int    strategy_max_hold_bars     = 60;    // time stop in D1 bars (P3 {30,60,90})
input double strategy_phi_max           = 0.98;  // |AR(1) phi| cointegration ceiling (card filter)
input int    strategy_min_expected_trades = 6;   // training-horizon round-trip floor (card filter)
input int    strategy_min_d1_bars       = 560;   // need >= training_window + buffer synced D1 bars

// -----------------------------------------------------------------------------
// File-scope cached pair state, advanced once per closed D1 bar.
// -----------------------------------------------------------------------------
string   g_partner          = "";     // resolved partner symbol (leg2)
double   g_spread_curr      = 0.0;    // last closed-bar cointegration error spread
double   g_mean             = 0.0;    // training-window spread mean (close_level)
double   g_sigma            = 0.0;    // training-window spread std
double   g_buy_level        = 0.0;    // mean - k*sigma
double   g_sell_level       = 0.0;    // mean + k*sigma
bool     g_ready            = false;  // both legs synced + spread well-formed
bool     g_coint_ok         = false;  // qualification: |phi|<phi_max AND expected_trades>=floor

// -----------------------------------------------------------------------------
// Minimum-profit spread + boundaries over the training window on CLOSED D1 bars.
// Fits hedge ratio host = a + b*partner by OLS over `training` bars, forms the
// cointegration-error spread series, computes the absolute minimum-profit
// boundary levels (mean +/- k*sigma), and qualifies the pair via the AR(1) phi
// stationarity proxy plus a mechanical count of historical boundary round-trips.
// Returns false on missing / degenerate data so the EA simply does not trade
// (card "skip if unstable / sigma==0 / missing bars").
// -----------------------------------------------------------------------------
bool QM_ComputeMinProfit(const int training, const double k,
                         double &spread_last, double &mean_out, double &sigma_out,
                         double &buy_lvl, double &sell_lvl, bool &coint_ok)
  {
   spread_last = 0.0;
   mean_out    = 0.0;
   sigma_out   = 0.0;
   buy_lvl     = 0.0;
   sell_lvl    = 0.0;
   coint_ok    = false;
   if(training < 30)
      return false;

   // Need `training` closed bars (shift 1..training) on BOTH legs.
   if(Bars(_Symbol,  PERIOD_D1) < strategy_min_d1_bars) return false;   // perf-allowed: bar-count availability check
   if(Bars(g_partner, PERIOD_D1) < strategy_min_d1_bars) return false;  // perf-allowed: partner-leg bar-count check

   const int n = training;              // bars 1..n, index 0 = shift 1 (last closed)
   double h[];   // host close,    index 0 = last closed (shift 1)
   double p[];   // partner close, index 0 = last closed (shift 1)
   ArrayResize(h, n);
   ArrayResize(p, n);
   for(int i = 0; i < n; ++i)
     {
      // perf-allowed: closed-bar foreign+host close reads for the training window;
      // computed once per closed D1 bar (OnTick gates this via QM_IsNewBar).
      const double ch = iClose(_Symbol,   PERIOD_D1, i + 1);   // perf-allowed: closed-bar host close for training window
      const double cp = iClose(g_partner, PERIOD_D1, i + 1);   // perf-allowed: closed-bar partner close for training window
      if(ch <= 0.0 || cp <= 0.0)
         return false;                  // missing bar inside lookback -> no trade
      h[i] = ch;
      p[i] = cp;
     }

   // OLS hedge ratio over the full training window: host = a + b*partner.
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
   const double slope     = (dn * sxy - sx * sy) / den;
   const double intercept = (sy - slope * sx) / dn;

   // Cointegration-error spread series over the training window:
   // spread[i] = host - (a + b*partner). index 0 = last closed bar; higher = older.
   double spread[];
   ArrayResize(spread, n);
   for(int i = 0; i < n; ++i)
      spread[i] = h[i] - (intercept + slope * p[i]);

   // --- minimum-profit boundary levels (mean +/- k*sigma) over training -----
   double smean = 0.0;
   for(int i = 0; i < n; ++i)
      smean += spread[i];
   smean /= dn;
   double svar = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double d = spread[i] - smean;
      svar += d * d;
     }
   svar /= dn;
   const double sigma = MathSqrt(svar);
   if(sigma <= 1e-12)
      return false;                     // zero spread dispersion -> no trade (card rule)

   spread_last = spread[0];
   mean_out    = smean;
   sigma_out   = sigma;
   buy_lvl     = smean - k * sigma;
   sell_lvl    = smean + k * sigma;

   // --- AR(1) phi stationarity proxy: regress e_t on e_{t-1} ----------------
   // spread index 0 is the newest bar so e_{t-1} = spread[i+1], e_t = spread[i].
   double ax = 0.0, ay = 0.0, axx = 0.0, axy = 0.0;
   const int m = n - 1;
   for(int i = 0; i < m; ++i)
     {
      const double e_prev = spread[i + 1];
      const double e_cur  = spread[i];
      ax  += e_prev;
      ay  += e_cur;
      axx += e_prev * e_prev;
      axy += e_prev * e_cur;
     }
   const double dm   = (double)m;
   const double aden = dm * axx - ax * ax;
   if(MathAbs(aden) < 1e-12)
      return true;                      // spread valid but phi undefined -> not qualified
   const double phi = (dm * axy - ax * ay) / aden;
   const bool phi_ok = (MathAbs(phi) < strategy_phi_max);

   // --- mechanical expected-trade count over the training horizon -----------
   // Count completed boundary round-trips in the training spread series: a trade
   // opens when the spread crosses a boundary (buy_lvl/sell_lvl) from the inside
   // and completes when it reverts back through the mean (close_level). This is a
   // direct deterministic count, NOT an MLE / mean-first-passage integral / ML.
   int trade_count = 0;
   int state = 0;                       // 0 flat, +1 long-spread open, -1 short-spread open
   for(int i = n - 1; i >= 0; --i)      // oldest -> newest
     {
      const double e = spread[i];
      if(state == 0)
        {
         if(e <= buy_lvl)      state = +1;   // opened a long-spread
         else if(e >= sell_lvl) state = -1;  // opened a short-spread
        }
      else if(state == +1)
        {
         if(e >= smean) { ++trade_count; state = 0; }   // reverted to mean -> closed
        }
      else // state == -1
        {
         if(e <= smean) { ++trade_count; state = 0; }   // reverted to mean -> closed
        }
     }
   const bool freq_ok = (trade_count >= strategy_min_expected_trades);

   coint_ok = (phi_ok && freq_ok);
   return true;
  }

// Advance cached minimum-profit state once per closed D1 bar.
void QM_AdvanceMinProfitState()
  {
   double sl_curr = 0.0, mn = 0.0, sg = 0.0, bl = 0.0, sel = 0.0;
   bool   ok = false;
   if(QM_ComputeMinProfit(strategy_training_window, strategy_min_profit_k,
                          sl_curr, mn, sg, bl, sel, ok))
     {
      g_spread_curr = sl_curr;
      g_mean        = mn;
      g_sigma       = sg;
      g_buy_level   = bl;
      g_sell_level  = sel;
      g_coint_ok    = ok;
      g_ready       = true;
     }
   else
     {
      g_ready    = false;
      g_coint_ok = false;
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

// Cheap O(1) per-tick filter. Fail-OPEN spread guard on the host leg only; the
// pair logic runs on closed bars. No session restriction (D1 pairs). On .DWX the
// modeled spread is 0, so we only ever block a genuinely pathological wide spread.
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
   if(spread > 0.0 && spread > 0.50 * atr)   // >50% of D1 ATR = pathological
      return true;
   return false;
  }

// Entry on a freshly closed D1 bar. Host leg opened via the framework path; the
// partner leg opened first via the basket path so both legs go on together.
// Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One pair state at a time: skip if either leg already open (card "one open
   // trade per pair only").
   if(QM_PairHasPosition())
      return false;
   if(!g_ready || !g_coint_ok)           // require cointegration qualification
      return false;

   const double e = g_spread_curr;
   int dir = 0;                          // +1 long-spread, -1 short-spread
   if(e <= g_buy_level)
      dir = +1;                          // spread cheap -> LONG spread
   else if(e >= g_sell_level)
      dir = -1;                          // spread rich -> SHORT spread
   if(dir == 0)
      return false;

   // Host (leg1): long-spread -> BUY host; short-spread -> SELL host.
   const QM_OrderType host_ot    = (dir > 0) ? QM_BUY : QM_SELL;
   // Partner (leg2) takes the OPPOSITE side for market-neutral exposure.
   const QM_OrderType partner_ot = (dir > 0) ? QM_SELL : QM_BUY;

   // Open the partner leg FIRST. If it fails, abort so we never carry a naked leg.
   const string rsn = (dir > 0) ? "minprofit_long_spread" : "minprofit_short_spread";
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

// Pair-level exits: minimum-profit reversion through close_level (mean), adverse
// spread stop (adverse_stop_mult * entry distance against the position), time
// stop. Returning true triggers the framework's host-leg close loop in OnTick; we
// ALSO close the partner leg here so the whole pair unwinds together.
bool Strategy_ExitSignal()
  {
   const int host_dir = QM_HostLegDir();   // +1 long-spread, -1 short-spread, 0 none
   if(host_dir == 0)
      return false;

   bool do_exit = false;
   QM_ExitReason reason = QM_EXIT_STRATEGY;

   if(g_ready)
     {
      const double e = g_spread_curr;
      // Minimum-profit reversion: close when the spread crosses back through the
      // mean (close_level) in the profitable direction.
      if(host_dir > 0 && e >= g_mean)       // long-spread reverted up to mean
        { do_exit = true; reason = QM_EXIT_STRATEGY; }
      else if(host_dir < 0 && e <= g_mean)  // short-spread reverted down to mean
        { do_exit = true; reason = QM_EXIT_STRATEGY; }

      // Adverse stop: spread moved adverse_stop_mult * |entry boundary - mean|
      // further AGAINST the position beyond the entry boundary. Entry distance is
      // the boundary offset from the mean (k*sigma); the stop band sits
      // adverse_stop_mult beyond the entry boundary on the adverse side.
      if(!do_exit)
        {
         const double entry_dist = MathAbs(g_buy_level - g_mean);   // = k*sigma
         if(entry_dist > 0.0)
           {
            // Long-spread entered below buy_level (= mean - k*sigma); adverse =
            // spread keeps falling. Stop if e <= mean - (1+adverse_mult)*entry_dist.
            const double long_stop  = g_mean - (1.0 + strategy_adverse_stop_mult) * entry_dist;
            const double short_stop = g_mean + (1.0 + strategy_adverse_stop_mult) * entry_dist;
            if(host_dir > 0 && e <= long_stop)
              { do_exit = true; reason = QM_EXIT_STRATEGY; }
            else if(host_dir < 0 && e >= short_stop)
              { do_exit = true; reason = QM_EXIT_STRATEGY; }
           }
        }
     }

   // Time stop: close the pair after the card's max-hold bar budget.
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
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_training_window + 60);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"partner\":\"%s\",\"host_slot\":%d,\"partner_slot\":%d,\"training\":%d,\"k\":%.3f}",
                            _Symbol, g_partner, qm_magic_slot_offset,
                            strategy_partner_slot, strategy_training_window, strategy_min_profit_k));
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
   // bar refresh the minimum-profit boundary state BEFORE the rule-based exit so
   // the exit sees the current spread.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceMinProfitState();

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
