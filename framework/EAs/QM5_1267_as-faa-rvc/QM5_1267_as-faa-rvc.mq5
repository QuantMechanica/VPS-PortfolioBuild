#property strict
#property version   "5.0"
#property description "QM5_1267 as-faa-rvc — AllocateSmartly Flexible Asset Allocation (Relative/Volatility/Correlation, D1, basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1267 as-faa-rvc
// -----------------------------------------------------------------------------
// Source: AllocateSmartly "Flexible Asset Allocation" (Keller & van Putten,
// "Generalized Momentum and Flexible Asset Allocation (FAA): An Heuristic
// Approach", SSRN 2193735). source_id 2df06de7. Card:
// artifacts/cards_approved/QM5_1267_as-faa-rvc.md (g0_status APPROVED).
//
// BASKET EA — cross-sectional FAA rotation on Relative momentum, Volatility,
// and Correlation. Each monthly rebalance the EA ranks the whole universe by a
// fixed-weight composite of three cross-sectional ranks and holds the best-N.
// The EA runs one instance per host symbol; the host opens / holds a long only
// when it is itself one of the surviving best-N sleeves. One position per magic
// on the host.
//
// FAA composite rank (Keller-van Putten, fixed weights — NOT learned, no ML):
//   Relative momentum (R) : lookback-period return; HIGHER ranks better.
//   Volatility        (V) : realized vol of daily returns; LOWER ranks better.
//   Correlation       (C) : average pairwise correlation of the asset's daily
//                           returns to every other universe member; LOWER ranks
//                           better (diversification reward).
//   score = wR*rank_R + wV*rank_V + wC*rank_C   (default 1.0 / 0.5 / 0.5)
//   rank_R is ascending in momentum-DESC order (best momentum -> rank 1).
//   rank_V / rank_C are ascending in their natural order (lowest -> rank 1).
//   Lowest composite score = best. Select the best-N (default 3).
//   Absolute-momentum filter: any selected asset with non-positive momentum is
//   dropped (replaced by cash; in this CFD port the sleeve simply goes flat).
//
// DWX PORT (ETFs are NOT tradeable on Darwinex; ported to liquid CFD proxies —
// documented in basket_manifest.json):
//   SP500.DWX  (S&P 500, backtest-only read member)  <- US large-cap ETF (SPY/VTI)
//   NDX.DWX    (Nasdaq 100)                           <- tech / growth ETF (QQQ)
//   WS30.DWX   (Dow 30)                               <- US large-cap value (DIA)
//   GDAXI.DWX  (DAX 40)                               <- EAFE / European equity (VEA/EFA)
//   XAUUSD.DWX (gold)                                 <- gold / real-asset ETF (GLD)
//   XTIUSD.DWX (WTI crude)                            <- commodity ETF (DBC)
//   EURUSD.DWX (EUR/USD)                              <- non-USD / FX diversifier
// Bond sleeves (the source paper's safe asset) have no DWX CFD; per the card's
// declared "CFD-port variant", bond sleeves are omitted and cash is represented
// by a sleeve going flat under the absolute-momentum filter.
//
// MONTHLY logic is D1-native (HR/DWX rule 10: the .DWX tester yields 0 bars on
// MN1). Rebalance fires on the first new D1 bar of a new broker-time month;
// lookbacks use a ~21-trading-day-per-month proxy.
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1267;
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
input int    strategy_lookback_months    = 4;     // FAA lookback (months); D1 proxy below
input int    strategy_days_per_month      = 21;    // trading-day-per-month proxy (D1-native)
input int    strategy_best_n              = 3;     // hold the best-N sleeves (card: bestN=3)
input double strategy_w_momentum          = 1.0;   // composite weight on relative-momentum rank
input double strategy_w_volatility        = 0.5;   // composite weight on volatility rank
input double strategy_w_correlation       = 0.5;   // composite weight on correlation rank
input int    strategy_min_candidates      = 4;     // min candidates with valid data for a valid rank
input int    strategy_atr_period          = 14;    // protective-stop ATR period (D1)
input double strategy_stop_atr_mult       = 3.0;   // protective stop = mult * ATR (P3 {2.0,2.5,3.0})
input int    strategy_min_warmup_bars     = 40;    // extra D1 warmup margin per candidate
input double strategy_spread_pct_of_stop  = 20.0;  // skip if host spread > this % of stop distance

// -----------------------------------------------------------------------------
// Fixed universe (matrix-verified DWX proxies for the FAA ETF universe).
// -----------------------------------------------------------------------------
#define QM_MAX_CAND   8
#define QM_MAX_RETBAR 256          // upper bound on cached return-series length

string g_cand[QM_MAX_CAND];
int    g_ncand    = 0;
int    g_host_idx = -1;            // index of _Symbol in g_cand, or -1

// Cached selection state, advanced once per closed D1 rebalance bar (month turn).
double g_momentum[QM_MAX_CAND];    // lookback return percent per candidate
double g_vol[QM_MAX_CAND];         // realized volatility of daily returns
double g_corr[QM_MAX_CAND];        // average pairwise correlation to the universe
bool   g_valid[QM_MAX_CAND];       // per-candidate valid-data flag
bool   g_selected_host = false;    // true if host survived into the best-N this month
int    g_active_count  = 0;        // candidates with valid data this eval
bool   g_ready         = false;    // true when this eval produced a usable selection

// Broker-time month of the last completed rebalance (-1 = none yet).
int    g_last_reb_month = -1;
int    g_last_reb_year  = -1;

void QM_BuildCandidates()
  {
   string u[] =
     {
      "SP500.DWX","NDX.DWX","WS30.DWX","GDAXI.DWX","XAUUSD.DWX","XTIUSD.DWX","EURUSD.DWX"
     };
   g_ncand = ArraySize(u);
   if(g_ncand > QM_MAX_CAND) g_ncand = QM_MAX_CAND;
   for(int i = 0; i < g_ncand; ++i)
      g_cand[i] = u[i];
  }

// Fill `out` with the host + every candidate (dedup keeps the warmup list clean).
void QM_BuildWarmupList(string &out[])
  {
   ArrayResize(out, g_ncand + 1);
   int n = 0;
   out[n++] = _Symbol;
   for(int i = 0; i < g_ncand; ++i)
     {
      bool dup = false;
      for(int j = 0; j < n; ++j)
         if(out[j] == g_cand[i]) { dup = true; break; }
      if(!dup) out[n++] = g_cand[i];
     }
   ArrayResize(out, n);
  }

int QM_LookbackDays()
  {
   int d = strategy_lookback_months * strategy_days_per_month;
   if(d < 5) d = 5;
   if(d > QM_MAX_RETBAR - 2) d = QM_MAX_RETBAR - 2;
   return d;
  }

// Load the daily LOG-return series for `sym` over the last `nret` closed bars
// (shift 1..nret). Returns true with `ret[]` filled (length nret) on success.
// perf-allowed: this runs ONCE per candidate per monthly rebalance (~12x/yr),
// gated by the broker-time month change in OnTick — not on the per-tick path.
bool QM_LoadReturns(const string sym, const int nret, double &ret[])
  {
   const int need = nret + 2;                       // need nret+1 closes -> nret returns
   if(Bars(sym, PERIOD_D1) < need + strategy_min_warmup_bars)
      return false;

   double cl[];
   ArrayResize(cl, nret + 1);
   for(int k = 0; k <= nret; ++k)
     {
      // perf-allowed: bounded copy of closed-bar closes for the return series.
      const double c = iClose(sym, PERIOD_D1, 1 + k);
      if(c <= 0.0)
         return false;
      cl[k] = c;
     }

   ArrayResize(ret, nret);
   for(int k = 0; k < nret; ++k)
     {
      // cl[k] is more recent than cl[k+1]; log return of the more recent bar.
      ret[k] = MathLog(cl[k] / cl[k + 1]);
     }
   return true;
  }

double QM_Mean(const double &a[], const int n)
  {
   if(n <= 0) return 0.0;
   double s = 0.0;
   for(int i = 0; i < n; ++i) s += a[i];
   return s / n;
  }

// Pearson correlation of two equal-length series. 0.0 on degenerate variance.
double QM_PairCorr(const double &a[], const double &b[], const int n)
  {
   if(n <= 1) return 0.0;
   const double ma = QM_Mean(a, n);
   const double mb = QM_Mean(b, n);
   double cov = 0.0, va = 0.0, vb = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double da = a[i] - ma;
      const double db = b[i] - mb;
      cov += da * db;
      va  += da * da;
      vb  += db * db;
     }
   if(va <= 0.0 || vb <= 0.0) return 0.0;
   return cov / MathSqrt(va * vb);
  }

// -----------------------------------------------------------------------------
// Advance the cross-sectional FAA selection ONCE per closed monthly-rebalance
// bar. Computes Relative-momentum, Volatility and Correlation states, composite
// ranks, best-N selection, and whether the host survives.
// -----------------------------------------------------------------------------
void QM_AdvanceSelection()
  {
   g_ready = false;
   g_selected_host = false;
   g_active_count = 0;

   const int nret = QM_LookbackDays();

   // Per-candidate return series (cached for correlation pass).
   double rets[QM_MAX_CAND][QM_MAX_RETBAR];
   int    rlen[QM_MAX_CAND];

   for(int i = 0; i < g_ncand; ++i)
     {
      g_momentum[i] = 0.0;
      g_vol[i] = 0.0;
      g_corr[i] = 0.0;
      g_valid[i] = false;
      rlen[i] = 0;

      double r[];
      if(!QM_LoadReturns(g_cand[i], nret, r))
         continue;

      // Relative momentum: cumulative log return over the lookback (== sum of
      // daily log returns). Sign-faithful to a price-ratio momentum.
      double cum = 0.0;
      double sumsq = 0.0;
      const double mr = QM_Mean(r, nret);
      for(int k = 0; k < nret; ++k)
        {
         cum += r[k];
         const double d = r[k] - mr;
         sumsq += d * d;
         rets[i][k] = r[k];
        }
      rlen[i] = nret;

      g_momentum[i] = cum;                               // higher = better
      g_vol[i] = MathSqrt(sumsq / nret);                 // realized vol; lower = better
      g_valid[i] = true;
      ++g_active_count;
     }

   if(g_active_count < strategy_min_candidates)
      return;                                            // too thin for a valid rank

   // Average pairwise correlation of each valid asset's returns to every other
   // valid asset (lower average correlation = better diversification).
   for(int i = 0; i < g_ncand; ++i)
     {
      if(!g_valid[i]) continue;
      double csum = 0.0;
      int cn = 0;
      double ai[]; ArrayResize(ai, rlen[i]);
      for(int k = 0; k < rlen[i]; ++k) ai[k] = rets[i][k];
      for(int j = 0; j < g_ncand; ++j)
        {
         if(j == i || !g_valid[j]) continue;
         const int n = MathMin(rlen[i], rlen[j]);
         if(n <= 1) continue;
         double bj[]; ArrayResize(bj, n);
         for(int k = 0; k < n; ++k) bj[k] = rets[j][k];
         csum += QM_PairCorr(ai, bj, n);
         ++cn;
        }
      g_corr[i] = (cn > 0) ? (csum / cn) : 0.0;
     }

   // Cross-sectional ranks. rank 1 = best.
   //  - momentum rank: DESC (highest momentum -> rank 1)
   //  - volatility rank: ASC (lowest vol -> rank 1)
   //  - correlation rank: ASC (lowest avg corr -> rank 1)
   double score[QM_MAX_CAND];
   for(int i = 0; i < g_ncand; ++i) score[i] = 0.0;

   for(int i = 0; i < g_ncand; ++i)
     {
      if(!g_valid[i]) continue;
      int rmom = 1, rvol = 1, rcor = 1;
      for(int j = 0; j < g_ncand; ++j)
        {
         if(j == i || !g_valid[j]) continue;
         if(g_momentum[j] > g_momentum[i]) ++rmom;       // better momentum ahead of us
         if(g_vol[j]      < g_vol[i])      ++rvol;        // lower vol ahead of us
         if(g_corr[j]     < g_corr[i])     ++rcor;        // lower corr ahead of us
        }
      score[i] = strategy_w_momentum    * rmom
               + strategy_w_volatility  * rvol
               + strategy_w_correlation * rcor;          // lower composite = better
     }

   // Select the best-N by lowest composite score among valid members, then
   // apply the absolute-momentum filter (drop non-positive momentum sleeves).
   const int want = MathMax(1, strategy_best_n);
   bool taken[QM_MAX_CAND];
   for(int i = 0; i < g_ncand; ++i) taken[i] = false;

   for(int slot = 0; slot < want; ++slot)
     {
      int best = -1;
      double best_score = 0.0;
      for(int i = 0; i < g_ncand; ++i)
        {
         if(!g_valid[i] || taken[i]) continue;
         if(best < 0 || score[i] < best_score)
           { best = i; best_score = score[i]; }
        }
      if(best < 0) break;
      taken[best] = true;
      // Absolute-momentum filter: only a positive-momentum sleeve is actually
      // held (otherwise that slot rotates to cash = sleeve stays flat).
      if(best == g_host_idx && g_momentum[best] > 0.0)
         g_selected_host = true;
     }

   g_ready = true;
  }

// Is the newly-closed D1 bar the first bar of a NEW broker-time month?
bool QM_IsRebalanceBar()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.mon == g_last_reb_month && dt.year == g_last_reb_year)
      return false;                                      // already rebalanced this month
   g_last_reb_month = dt.mon;
   g_last_reb_year  = dt.year;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick spread guard. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                                      // no valid quote — defer, don't block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                                       // genuinely wide spread — block
   return false;                                         // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true. Selection is advanced in
// OnTick before this call (g_selected_host / g_ready).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready || g_host_idx < 0)
      return false;

   // Host must be one of this month's surviving best-N sleeves.
   if(!g_selected_host)
      return false;

   // Long-only FAA allocation into a selected sleeve.
   const QM_OrderType ot = QM_BUY;
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;        // no TP — monthly reselection is the primary exit
   req.reason = "faa_rvc_allocate_long";
   return true;
  }

// No active management beyond the static protective ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Rebalance exit: close the host long when the monthly reselection drops the
// host out of the surviving best-N (or the selection became unusable).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_ready || g_host_idx < 0)
      return false;

   // Only act on a long position on this host (long-only EA, one per magic).
   bool have_long = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         have_long = true;
      break;
     }
   if(!have_long)
      return false;

   // Exit when the host is no longer a selected (positive-momentum) sleeve.
   if(!g_selected_host)
      return true;

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

   // Build the fixed universe and locate the host within it.
   QM_BuildCandidates();
   g_host_idx = -1;
   for(int i = 0; i < g_ncand; ++i)
      if(g_cand[i] == _Symbol) { g_host_idx = i; break; }

   g_last_reb_month = -1;
   g_last_reb_year  = -1;

   // BASKET wiring: register the host + every candidate and warm their D1
   // history so foreign-symbol reads return real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int warm = QM_LookbackDays() + strategy_min_warmup_bars + 16;
   QM_BasketWarmupHistory(warmlist, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"candidates\":%d,\"host\":\"%s\",\"host_idx\":%d,\"lookback_days\":%d}",
                            g_ncand, _Symbol, g_host_idx, QM_LookbackDays()));
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

   // Latch the closed-bar event ONCE (single-consume). On the first new D1 bar
   // of a new broker-time month, refresh the cross-sectional FAA selection
   // BEFORE the rule-based exit so the signal-exit sees the current pick.
   const bool nb = QM_IsNewBar();
   if(nb && QM_IsRebalanceBar())
      QM_AdvanceSelection();

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
