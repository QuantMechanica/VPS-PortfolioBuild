#property strict
#property version   "5.0"
#property description "QM5_11147 clenow-vam-rot — Clenow volatility-adjusted-momentum cross-sectional rotation (D1, basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11147 clenow-vam-rot
// -----------------------------------------------------------------------------
// Source: Andreas F. Clenow, "Stocks on the Move" (2015, ISBN 9781511466141),
// source_id 2b7435de. Card: artifacts/cards_approved/QM5_11147_clenow-vam-rot.md
// (g0_status APPROVED).
//
// BASKET EA — cross-sectional volatility-adjusted momentum ROTATION. A fixed
// universe of liquid DWX CFDs is ranked cross-sectionally every week; the EA
// runs one instance per host symbol and only opens / holds the host when the
// host is itself a top-ranked member. One position per magic on the host.
//
// Universe (10 DWX symbols, all matrix-verified):
//   SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX,
//   XAUUSD.DWX, XTIUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX
//   (card GER40 -> GDAXI, FTSE100 -> UK100; nearest matrix ports.)
//
// Mechanics (all on CLOSED D1 bars, advanced once per new D1 bar; the weekly
// Wednesday cadence is enforced by the broker-time weekday of the new bar):
//   Market regime : SP500.DWX close < SMA(200) -> bearish; no NEW longs.
//                   Two consecutive bearish weekly evals -> force-exit holds.
//   Eligibility   : per symbol require close > SMA(elig_sma); reject if ANY
//                   |1-day close-to-close return| over the last `rank_lookback`
//                   D1 bars exceeds outlier_pct; require >= min_warmup_bars.
//   Momentum score: fit OLS of ln(close) over `rank_lookback` D1 bars.
//                   annualised slope = (e^slope - 1) * 252 ; score = ann*R^2.
//   Rank          : eligible symbols by score desc. Top-N (default 6) tradable.
//                   Buffer: a held symbol may stay until it leaves top N+buffer.
//   Entry (host)  : host eligible AND host in top-N AND host score > 0 AND
//                   regime not bearish AND no open position for this magic.
//   Exit (host)   : host ineligible, OR host out of top (N+buffer), OR host
//                   score <= 0, OR regime bearish for 2 consecutive weekly evals.
//   Stop          : catastrophic 3.0 * ATR(20, D1) from entry (bounds gap risk;
//                   the rank/rebalance close is the primary exit).
//   Filters       : require >= min_universe_active eligible-data symbols (the
//                   cross-sectional premise is too thin below 4); skip a
//                   genuinely wide host spread (fail-open on .DWX zero spread).
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11147;
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
input int    strategy_rank_lookback     = 90;    // OLS / outlier window (P3 sweep {60,90,120})
input int    strategy_elig_sma          = 100;   // eligibility SMA period (P3 sweep {80,100,120})
input int    strategy_market_sma        = 200;   // SP500 regime SMA period (P3 sweep {150,200,250})
input double strategy_outlier_pct       = 15.0;  // reject if any 1d |ret| > this % (P3 {10,15,20})
input int    strategy_top_n             = 6;     // basket size (P3 sweep {3,4,6})
input int    strategy_rank_buffer       = 2;     // hold buffer beyond top-N (P3 sweep {0,2,4})
input int    strategy_atr_period        = 20;    // catastrophic-stop ATR period (D1)
input double strategy_stop_atr_mult     = 3.0;   // emergency stop = mult * ATR (P3 {2.5,3.0,3.5})
input int    strategy_min_warmup_bars   = 120;   // min D1 warmup bars per symbol
input int    strategy_min_universe_active = 4;   // min eligible-data symbols for a valid rank
input int    strategy_rebalance_weekday = 3;     // 0=Sun..6=Sat; 3 = Wednesday (broker time)
input double strategy_spread_pct_of_stop = 20.0; // skip if host spread > this % of stop distance

// -----------------------------------------------------------------------------
// Fixed cross-sectional universe (matrix-verified). The EA reads every member's
// D1 closes to rank them; the host trades only when it is top-ranked.
// -----------------------------------------------------------------------------
#define QM_MAX_UNIV 16

string g_univ[QM_MAX_UNIV];
int    g_nuniv = 0;
int    g_host_idx = -1;          // index of _Symbol in g_univ, or -1

// Cached rank state, advanced once per closed D1 bar (on rebalance weekday).
double g_score[QM_MAX_UNIV];     // momentum score per universe member
bool   g_eligible[QM_MAX_UNIV];  // per-member eligibility flag
int    g_rank[QM_MAX_UNIV];      // rank (0 = best) among eligible members; -1 if not ranked
int    g_active_count = 0;       // members with valid rank data this eval
bool   g_regime_bearish = false; // SP500 below SMA(market_sma)
int    g_bearish_streak = 0;     // consecutive bearish weekly evals
bool   g_ready = false;          // true when this eval produced a usable rank

void QM_BuildUniverse()
  {
   string u[] =
     {
      "SP500.DWX","NDX.DWX","WS30.DWX","GDAXI.DWX","UK100.DWX",
      "XAUUSD.DWX","XTIUSD.DWX","EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX"
     };
   g_nuniv = ArraySize(u);
   if(g_nuniv > QM_MAX_UNIV) g_nuniv = QM_MAX_UNIV;
   for(int i = 0; i < g_nuniv; ++i)
      g_univ[i] = u[i];
  }

// Fill `out` with the universe plus the host (host is normally already a member;
// dedup keeps the warmup list clean).
void QM_BuildWarmupList(string &out[])
  {
   ArrayResize(out, g_nuniv + 1);
   int n = 0;
   out[n++] = _Symbol;
   for(int i = 0; i < g_nuniv; ++i)
     {
      bool dup = false;
      for(int j = 0; j < n; ++j)
         if(out[j] == g_univ[i]) { dup = true; break; }
      if(!dup) out[n++] = g_univ[i];
     }
   ArrayResize(out, n);
  }

// -----------------------------------------------------------------------------
// Per-symbol momentum + eligibility on the LAST closed D1 bars (shift 1..L).
// Fills `score` and `eligible`. Returns true if the symbol had valid data
// (enough history + positive closes) regardless of eligibility.
// -----------------------------------------------------------------------------
bool QM_ScoreSymbol(const string sym, double &score, bool &eligible)
  {
   score = 0.0;
   eligible = false;

   const int L = strategy_rank_lookback;
   if(Bars(sym, PERIOD_D1) < strategy_min_warmup_bars)
      return false;
   if(strategy_min_warmup_bars < L + 2)
      return false;                       // misconfig guard

   // Read L closes ending at the last closed bar (shift 1..L), oldest first.
   // perf-allowed: closed-bar foreign-symbol daily close reads (basket leg);
   // gated to once-per-new-D1-bar via QM_IsNewBar in OnTick.
   double c[];
   ArrayResize(c, L);
   for(int i = 0; i < L; ++i)
     {
      const int shift = L - i;            // i=0 -> shift L (oldest), i=L-1 -> shift 1 (newest)
      const double v = iClose(sym, PERIOD_D1, shift);
      if(v <= 0.0)
         return false;                    // missing data -> symbol has no valid rank
      c[i] = v;
     }

   // Outlier filter: reject if any 1-day |close-to-close return| over the window
   // exceeds outlier_pct. Computed on the same L closes.
   bool outlier = false;
   for(int i = 1; i < L; ++i)
     {
      const double r = (c[i] - c[i - 1]) / c[i - 1] * 100.0;
      if(MathAbs(r) > strategy_outlier_pct) { outlier = true; break; }
     }

   // OLS of ln(close) on x = 0..L-1. slope, then R^2.
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0, syy = 0.0;
   for(int i = 0; i < L; ++i)
     {
      const double x = (double)i;
      const double y = MathLog(c[i]);
      sx += x; sy += y; sxx += x * x; sxy += x * y; syy += y * y;
     }
   const double n = (double)L;
   const double denom = n * sxx - sx * sx;
   if(denom == 0.0)
      return true;                        // degenerate x (cannot happen for L>1) — valid but score 0
   const double slope = (n * sxy - sx * sy) / denom;

   // R^2 = (cov^2) / (var_x * var_y).
   const double cov   = n * sxy - sx * sy;
   const double var_x = n * sxx - sx * sx;
   const double var_y = n * syy - sy * sy;
   double r2 = 0.0;
   if(var_x > 0.0 && var_y > 0.0)
      r2 = (cov * cov) / (var_x * var_y);
   if(r2 < 0.0) r2 = 0.0;
   if(r2 > 1.0) r2 = 1.0;

   // Annualise the per-day log-slope to a compounded % move, scale by R^2.
   const double annualised = (MathExp(slope) - 1.0) * 252.0;
   score = annualised * r2;

   // Eligibility: close above eligibility SMA AND not an outlier.
   const double sma = QM_SMA(sym, PERIOD_D1, strategy_elig_sma, 1);
   const double last_close = c[L - 1];
   eligible = (!outlier && sma > 0.0 && last_close > sma);
   return true;
  }

// -----------------------------------------------------------------------------
// Advance the cross-sectional rank ONCE per closed D1 rebalance bar.
// -----------------------------------------------------------------------------
void QM_AdvanceRank()
  {
   g_ready = false;
   g_active_count = 0;

   // 1) Market regime from SP500.DWX vs its SMA(market_sma).
   bool prev_bearish = g_regime_bearish;
   g_regime_bearish = false;
   const double spx_close = iClose("SP500.DWX", PERIOD_D1, 1);  // perf-allowed: regime read
   const double spx_sma   = QM_SMA("SP500.DWX", PERIOD_D1, strategy_market_sma, 1);
   if(spx_close > 0.0 && spx_sma > 0.0)
      g_regime_bearish = (spx_close < spx_sma);
   // Track consecutive bearish weekly evals (this function is called once per eval).
   if(g_regime_bearish) g_bearish_streak = (prev_bearish ? g_bearish_streak + 1 : 1);
   else                 g_bearish_streak = 0;

   // 2) Score + eligibility for every universe member.
   for(int i = 0; i < g_nuniv; ++i)
     {
      g_score[i] = 0.0;
      g_eligible[i] = false;
      g_rank[i] = -1;
      double sc = 0.0; bool el = false;
      if(QM_ScoreSymbol(g_univ[i], sc, el))
        {
         g_score[i] = sc;
         g_eligible[i] = el;
         ++g_active_count;
        }
     }

   if(g_active_count < strategy_min_universe_active)
      return;                             // too thin for a cross-sectional rank

   // 3) Rank ELIGIBLE members by score descending (selection over <=16 items).
   // Build an index list of eligible members, sort by score desc, assign ranks.
   int idx[QM_MAX_UNIV];
   int ne = 0;
   for(int i = 0; i < g_nuniv; ++i)
      if(g_eligible[i]) idx[ne++] = i;

   for(int a = 0; a < ne; ++a)
      for(int b = a + 1; b < ne; ++b)
         if(g_score[idx[b]] > g_score[idx[a]])
           { const int t = idx[a]; idx[a] = idx[b]; idx[b] = t; }

   for(int a = 0; a < ne; ++a)
      g_rank[idx[a]] = a;                 // 0 = best eligible

   g_ready = true;
  }

// Is "now" a rebalance evaluation bar? True only on the configured broker-time
// weekday of the newly-closed D1 bar.
bool QM_IsRebalanceBar()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   return (dt.day_of_week == strategy_rebalance_weekday);
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
      return false;                       // no valid quote — defer, don't block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                        // genuinely wide spread — block
   return false;                          // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true. Rank is advanced in OnTick
// before this call (g_rank / g_score / g_regime_bearish / g_ready).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready || g_host_idx < 0)
      return false;

   // No new longs in a bearish regime.
   if(g_regime_bearish)
      return false;

   // Host must be eligible, top-N, and have a positive score.
   if(!g_eligible[g_host_idx])
      return false;
   const int hr = g_rank[g_host_idx];
   if(hr < 0 || hr >= strategy_top_n)
      return false;
   if(g_score[g_host_idx] <= 0.0)
      return false;

   // Long-only rotation.
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
   req.tp     = 0.0;        // no TP — rank/rebalance exit is primary
   req.reason = "clenow_vam_rotation_long";
   return true;
  }

// No active management beyond the static catastrophic ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Rank/rebalance exit: close the host long when it loses eligibility, leaves the
// top (N+buffer) ranks, its score turns non-positive, or the regime has been
// bearish for two consecutive weekly evals.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_ready || g_host_idx < 0)
      return false;

   // Only act on long positions on this host (long-only EA, one per magic).
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

   // Regime: two consecutive bearish weekly evals -> exit.
   if(g_regime_bearish && g_bearish_streak >= 2)
      return true;

   // Eligibility / score / rank-buffer exits.
   if(!g_eligible[g_host_idx])
      return true;
   if(g_score[g_host_idx] <= 0.0)
      return true;
   const int hr = g_rank[g_host_idx];
   if(hr < 0 || hr >= (strategy_top_n + strategy_rank_buffer))
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

   // Build the fixed cross-sectional universe and locate the host within it.
   QM_BuildUniverse();
   g_host_idx = -1;
   for(int i = 0; i < g_nuniv; ++i)
      if(g_univ[i] == _Symbol) { g_host_idx = i; break; }

   // BASKET wiring: register the host + every universe member and warm their D1
   // history so foreign-symbol reads return real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int warm = strategy_rank_lookback + strategy_market_sma + 16;
   QM_BasketWarmupHistory(warmlist, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"universe\":%d,\"host\":\"%s\",\"host_idx\":%d}",
                            g_nuniv, _Symbol, g_host_idx));
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
   // also the weekly rebalance weekday, refresh the cross-sectional rank BEFORE
   // the rule-based exit so the signal-exit sees the current ranking.
   const bool nb = QM_IsNewBar();
   if(nb && QM_IsRebalanceBar())
      QM_AdvanceRank();

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
