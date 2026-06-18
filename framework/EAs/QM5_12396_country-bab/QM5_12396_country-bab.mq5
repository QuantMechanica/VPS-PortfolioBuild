#property strict
#property version   "5.0"
#property description "QM5_12396 country-bab — Country-index Betting-Against-Beta cross-sectional long/short basket (D1)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12396 country-bab
// -----------------------------------------------------------------------------
// Source: Papers With Backtest / Quantpedia "Betting Against Beta Factor in
// Country Equity Indexes", source_id b7832a20. Card:
// artifacts/cards_approved/QM5_12396_country-bab.md (g0_status APPROVED).
//
// BASKET EA — cross-sectional Betting-Against-Beta (BAB) over country equity
// indices. Each index's beta is estimated as the closed-form OLS slope of its
// daily returns against the EQUAL-WEIGHT universe-average ("market") return
// over a rolling N-bar window:
//     beta_i = cov(r_i, r_mkt) / var(r_mkt)
// The universe is then ranked by beta. The strategy goes LONG the low-beta
// top-N indices and SHORT the high-beta bottom-N indices (long low-beta /
// short high-beta = classic BAB). Beta ranking = STATE, recomputed once per
// closed D1 rebalance bar (monthly cadence approximated by the day-of-month
// boundary on D1, since MN1 is untestable on .DWX — codex_build_ea rule 10).
//
// COUNTRY UNIVERSE — LIMITED TO AVAILABLE DWX EQUITY INDICES. The source uses
// broad country ETFs; the DWX matrix has only a small index set, so the
// "country" proxies are:
//     SP500.DWX  (US, backtest-only)   NDX.DWX (US tech)   WS30.DWX (US)
//     GDAXI.DWX  (Germany / DAX 40)    UK100.DWX (UK / FTSE 100)
// The card also listed JPN225.DWX, but it is NOT in
// framework/registry/dwx_symbol_matrix.csv (no Nikkei CFD) — dropped. The US
// indices (SP500/NDX/WS30) are highly correlated, so the realised country
// universe is effectively {US-cluster, Germany, UK}: a genuine limitation of
// the DWX index breadth, flagged in basket_manifest.json and SPEC.md.
//
// The EA runs ONE instance per host. The host opens / holds:
//   * LONG  if the host is in the low-beta top-N (long leg), or
//   * SHORT if the host is in the high-beta bottom-N (short leg).
// One position per magic on the host; rebalance reselection is the primary
// exit, with a protective ATR stop as the MT5 worst-case bound.
//
// Mechanics (all on CLOSED D1 bars; selection advanced once per new D1 bar on
// the rebalance-boundary day):
//   Returns   : per candidate, simple daily returns r_t = close[t]/close[t+1]-1
//               over the lookback window, from CLOSED bars (shift >= 1).
//   Market    : equal-weight average return across all valid candidates per bar.
//   Beta      : closed-form OLS slope cov(r_i,r_mkt)/var(r_mkt). No ML.
//   Rank      : sort valid candidates by beta ascending. Low-beta head = LONG
//               set (size N); high-beta tail = SHORT set (size N).
//   Entry(host): host in LONG set -> buy; host in SHORT set -> sell; else flat.
//   Exit(host) : host leaves its assigned set on the next rebalance (or the
//               selection becomes unusable / too few candidates).
//   Stop       : protective stop_atr_mult * ATR(atr_period, D1) from entry.
//   Filters    : require >= min_candidates valid candidates; >= warmup D1 bars;
//                skip new entries only on a genuinely wide host spread.
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12396;
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
input int    strategy_beta_lookback      = 252;   // beta-estimation window in D1 bars (P3 {126,189,252})
input int    strategy_side_size          = 1;     // # of symbols on each (long low-beta / short high-beta) side (P3 tercile / two)
input int    strategy_min_candidates     = 4;     // min candidates with valid beta for a valid ranking (card: close all if < 4)
input int    strategy_atr_period         = 20;    // protective-stop ATR period (D1; card: ATR(20))
input double strategy_stop_atr_mult      = 3.0;   // protective stop = mult * ATR (card baseline 3.0; P3 {3R,5R,none})
input int    strategy_min_warmup_bars    = 252;   // min D1 warmup bars per candidate (card: 252)
input int    strategy_rebalance_dom      = 1;     // rebalance on the first new D1 bar whose day-of-month >= this (monthly proxy)

// -----------------------------------------------------------------------------
// Fixed candidate basket (matrix-verified country-index proxies). Limited to
// the available DWX equity indices — see header note.
// -----------------------------------------------------------------------------
#define QM_MAX_CAND 8

string g_cand[QM_MAX_CAND];
int    g_ncand    = 0;
int    g_host_idx = -1;          // index of _Symbol in g_cand, or -1

// Cached ranking state, advanced once per closed D1 rebalance bar.
double g_beta[QM_MAX_CAND];      // estimated beta per candidate
bool   g_valid[QM_MAX_CAND];     // per-candidate valid-data flag
int    g_target_side[QM_MAX_CAND]; // +1 = long set, -1 = short set, 0 = flat
int    g_active_count = 0;       // candidates with valid beta this eval
bool   g_ready    = false;       // true when this eval produced a usable ranking
int    g_last_eval_month = -1;   // broker-time month of the last rebalance eval

void QM_BuildCandidates()
  {
   // Country-index proxies — ONLY symbols present in dwx_symbol_matrix.csv.
   // JPN225.DWX from the card is absent from the matrix and is intentionally
   // omitted (no Nikkei CFD). US cluster is correlated (genuine breadth limit).
   string u[] =
     {
      "SP500.DWX","NDX.DWX","WS30.DWX","GDAXI.DWX","UK100.DWX"
     };
   g_ncand = ArraySize(u);
   if(g_ncand > QM_MAX_CAND) g_ncand = QM_MAX_CAND;
   for(int i = 0; i < g_ncand; ++i)
      g_cand[i] = u[i];
  }

// Fill `out` with the candidate basket plus the host (dedup keeps it clean).
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

// -----------------------------------------------------------------------------
// Advance the cross-sectional BAB ranking ONCE per closed D1 rebalance bar.
// Computes each candidate's beta vs the equal-weight universe-average return
// via closed-form OLS, ranks ascending, assigns the low-beta head to the LONG
// set and the high-beta tail to the SHORT set.
// -----------------------------------------------------------------------------
void QM_AdvanceRanking()
  {
   g_ready = false;
   g_active_count = 0;
   for(int i = 0; i < g_ncand; ++i)
     {
      g_beta[i] = 0.0;
      g_valid[i] = false;
      g_target_side[i] = 0;
     }

   const int look = strategy_beta_lookback;
   if(look < 2)
      return;

   // Build per-candidate closed-bar return series r[k] = close[1+k]/close[2+k]-1
   // for k = 0..look-1. close-shift starts at 1 (last CLOSED bar). A candidate
   // is valid only if it has enough warmed history for the full window.
   // perf-allowed: bounded one-shot fill inside the per-bar rebalance gate
   // (not the per-tick path); iClose on foreign symbols warmed via
   // QM_BasketWarmupHistory. Cost = O(ncand * lookback) once per rebalance bar.
   double ret[QM_MAX_CAND][512];
   bool   cand_ok[QM_MAX_CAND];
   const int maxlook = (look < 512 ? look : 512);

   for(int i = 0; i < g_ncand; ++i)
     {
      cand_ok[i] = false;
      const string sym = g_cand[i];
      const int need = MathMax(strategy_min_warmup_bars, look + 2);
      if(Bars(sym, PERIOD_D1) < need)
         continue;
      bool ok = true;
      for(int k = 0; k < maxlook; ++k)
        {
         const double c0 = iClose(sym, PERIOD_D1, 1 + k);   // perf-allowed
         const double c1 = iClose(sym, PERIOD_D1, 2 + k);   // perf-allowed
         if(c0 <= 0.0 || c1 <= 0.0)
           { ok = false; break; }
         ret[i][k] = (c0 / c1) - 1.0;
        }
      cand_ok[i] = ok;
     }

   // Equal-weight market return per bar = mean of valid candidates' returns.
   // Recompute per-bar membership from cand_ok so a thin symbol doesn't poison
   // the market series.
   double mkt[512];
   for(int k = 0; k < maxlook; ++k)
     {
      double sum = 0.0;
      int cnt = 0;
      for(int i = 0; i < g_ncand; ++i)
        {
         if(!cand_ok[i]) continue;
         sum += ret[i][k];
         ++cnt;
        }
      mkt[k] = (cnt > 0 ? sum / cnt : 0.0);
     }

   // Market mean + variance over the window.
   double mkt_mean = 0.0;
   for(int k = 0; k < maxlook; ++k)
      mkt_mean += mkt[k];
   mkt_mean /= maxlook;

   double mkt_var = 0.0;
   for(int k = 0; k < maxlook; ++k)
     {
      const double d = mkt[k] - mkt_mean;
      mkt_var += d * d;
     }
   mkt_var /= maxlook;
   if(mkt_var <= 0.0)
      return;                                    // degenerate market — skip eval

   // Closed-form OLS beta per valid candidate: cov(r_i, r_mkt) / var(r_mkt).
   for(int i = 0; i < g_ncand; ++i)
     {
      if(!cand_ok[i])
         continue;
      double i_mean = 0.0;
      for(int k = 0; k < maxlook; ++k)
         i_mean += ret[i][k];
      i_mean /= maxlook;

      double cov = 0.0;
      for(int k = 0; k < maxlook; ++k)
         cov += (ret[i][k] - i_mean) * (mkt[k] - mkt_mean);
      cov /= maxlook;

      g_beta[i] = cov / mkt_var;
      g_valid[i] = true;
      ++g_active_count;
     }

   if(g_active_count < strategy_min_candidates)
      return;                                    // too thin for a valid ranking

   // Rank valid candidates by beta ascending (selection sort on a small set).
   int order[QM_MAX_CAND];
   int m = 0;
   for(int i = 0; i < g_ncand; ++i)
      if(g_valid[i]) order[m++] = i;
   for(int a = 0; a < m - 1; ++a)
      for(int b = a + 1; b < m; ++b)
         if(g_beta[order[b]] < g_beta[order[a]])
           { int t = order[a]; order[a] = order[b]; order[b] = t; }

   // Side size: at most half the valid set so long/short sets don't overlap.
   int n_side = strategy_side_size;
   if(n_side < 1) n_side = 1;
   if(n_side > m / 2) n_side = m / 2;
   if(n_side < 1)
      return;                                    // not enough to form two sides

   // Low-beta head -> LONG (+1); high-beta tail -> SHORT (-1).
   for(int s = 0; s < n_side; ++s)
     {
      g_target_side[order[s]]           = +1;    // lowest beta -> long
      g_target_side[order[m - 1 - s]]   = -1;    // highest beta -> short
     }

   g_ready = true;
  }

// Is "now" a rebalance evaluation bar? Monthly proxy on D1: the first new D1
// bar of a fresh broker-time month whose day-of-month has reached the boundary.
bool QM_IsRebalanceBar()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.mon == g_last_eval_month)
      return false;                              // already rebalanced this month
   if(dt.day < strategy_rebalance_dom)
      return false;                              // not yet at the month boundary
   g_last_eval_month = dt.mon;
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
      return false;                              // no valid quote — defer, don't block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > 0.20 * stop_distance)
      return true;                               // genuinely wide spread — block
   return false;                                 // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true. Ranking is advanced in
// OnTick before this call (g_target_side / g_ready).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready || g_host_idx < 0)
      return false;

   const int side = g_target_side[g_host_idx];
   if(side == 0)
      return false;                              // host not in either set this month

   const QM_OrderType ot = (side > 0 ? QM_BUY : QM_SELL);
   const double entry = (ot == QM_BUY
                         ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;        // no TP — monthly reselection is the primary exit
   req.reason = (side > 0 ? "bab_long_lowbeta" : "bab_short_highbeta");
   return true;
  }

// No active management beyond the static protective ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Rebalance exit: close the host position when the host is no longer on its
// assigned side after the monthly reselection (or the ranking became unusable).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(g_host_idx < 0)
      return false;

   // Determine the open side on this host (one position per magic).
   int open_side = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? +1 : -1);
      break;
     }
   if(open_side == 0)
      return false;

   // If the ranking is unusable, close (card: close all if < 4 eligible).
   if(!g_ready)
      return true;

   // Exit when the host's assigned side changed (flat or flipped).
   if(g_target_side[g_host_idx] != open_side)
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

   // Build the fixed candidate basket and locate the host within it.
   QM_BuildCandidates();
   g_host_idx = -1;
   for(int i = 0; i < g_ncand; ++i)
      if(g_cand[i] == _Symbol) { g_host_idx = i; break; }

   // BASKET wiring: register the host + every candidate and warm their D1
   // history so foreign-symbol reads return real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int warm = strategy_beta_lookback + strategy_min_warmup_bars + 16;
   QM_BasketWarmupHistory(warmlist, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"candidates\":%d,\"host\":\"%s\",\"host_idx\":%d}",
                            g_ncand, _Symbol, g_host_idx));
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

   // Latch the closed-bar event ONCE (single-consume). On a fresh D1 bar that is
   // also the monthly rebalance boundary, refresh the cross-sectional BAB
   // ranking BEFORE the rule-based exit so the signal-exit sees the new sides.
   const bool nb = QM_IsNewBar();
   if(nb && QM_IsRebalanceBar())
      QM_AdvanceRanking();

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
