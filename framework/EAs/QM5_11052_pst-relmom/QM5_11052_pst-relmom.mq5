#property strict
#property version   "5.0"
#property description "QM5_11052 pst-relmom — pysystemtrade cross-sectional relative momentum (D1 basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11052 pst-relmom
// -----------------------------------------------------------------------------
// Source: Rob Carver / pst-group pysystemtrade relative-momentum rule
//   systems/provided/rules/rel_mom.py + rob_system/config.yaml
//   (rules relmomentum10/20/40/80). source_id 352af9de-f372-5cf2-9a86-681a26224597.
// Card: artifacts/cards_approved/QM5_11052_pst-relmom.md (g0_status APPROVED).
//
// BASKET EA. Cross-sectional (relative) momentum: each host symbol is compared to
// its OWN asset class. The EA runs one instance per host symbol and reads the
// foreign asset-class peers on D1 to build the class benchmark. One position per
// magic on the host; foreign reads are bound at call site to the peer symbol.
//
// Mechanics (closed-bar D1 reads, evaluated once per completed D1 bar):
//   For the host and EVERY peer in the host's asset class, build a
//   volatility-normalised cumulative log-return path over a shared window:
//     ret_t          = log(close[t]) - log(close[t-1])     (per D1 bar)
//     vol            = stdev of the last `vol_lookback` daily returns
//     norm_ret_t     = ret_t / vol                          (vol target = 1)
//     cum_norm[k]    = running sum of norm_ret over the window (index 0 = oldest)
//   Asset-class benchmark = equal-weight mean of the peers' cum_norm paths.
//   outperformance[k]    = host_cum_norm[k] - class_cum_norm[k]
//   For each horizon H in {10,20,40,80}:
//     avg_outperf = (outperformance[last] - outperformance[last-H]) / H
//     smoothed    = EMA(avg_outperf series, span = max(H/4, 2))   (over window)
//     forecast_H  = clamp(smoothed * forecast_scalar[H], -20, +20)
//   combined_forecast = equal-weight mean of the four forecast_H.
//   Entry  : long  when combined >= +entry_threshold ; short when <= -entry_threshold.
//   Exit   : close long when combined <= +exit_buffer ; close short when >= -exit_buffer.
//   Flip   : only after a later D1 close crosses the opposite entry threshold
//            (handled by closing first, then re-entering on a subsequent bar).
//   Stop   : emergency stop = stop_atr_mult * ATR(D1, atr_period) from entry.
//            Primary exit is the signal reversal; the stop only bounds worst case.
//   Warmup : require >= min_d1_bars D1 bars (longest horizon + smoothing).
//   Class  : require >= min_class_members peers with data for a meaningful benchmark.
//   Spread : skip new entries when host spread > spread_pct_of_atr% of ATR(D1).
//            Fail-open on .DWX zero modeled spread.
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11052;
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
input double strategy_entry_threshold   = 5.0;    // |combined forecast| to ENTER (P3 sweep {3,5,8})
input double strategy_exit_buffer       = 1.0;    // |combined forecast| to EXIT  (P3 sweep {0,1,2})
input int    strategy_vol_lookback      = 25;     // D1 bars for return stdev (vol normalisation)
input int    strategy_atr_period        = 20;     // ATR(D1) period for the emergency stop
input double strategy_stop_atr_mult     = 3.0;    // emergency stop = mult * ATR (P3 sweep {2.5,3.0,3.5})
input int    strategy_min_class_members = 3;      // min peers with data for a class benchmark
input int    strategy_min_d1_bars       = 120;    // warmup: longest horizon + smoothing

// -----------------------------------------------------------------------------
// Asset-class model. Each host belongs to exactly one class; the class benchmark
// is the equal-weight mean of the peers' normalised cumulative-return paths. All
// symbols use the ".DWX" suffix and match framework/registry/dwx_symbol_matrix.csv.
// Classes are drawn from the matrix so each has >= min_class_members members.
// -----------------------------------------------------------------------------
#define QM_NCLASS    3
#define QM_MAX_CLASS 24       // max members across any single class
#define QM_NHORIZON  4
#define QM_WINDOW    100      // shared cumulative-return window length (>= longest horizon)

// Forecast scalars from rob_system/config.yaml relmomentum10/20/40/80.
const double QM_FC_SCALAR[QM_NHORIZON] = {61.2403, 86.5075, 117.7794, 159.8780};
const int    QM_HORIZON[QM_NHORIZON]   = {10, 20, 40, 80};

string g_class_member[QM_NCLASS][QM_MAX_CLASS];
int    g_class_count[QM_NCLASS];

int    g_host_class = -1;     // class index of _Symbol, or -1 if host not modelled

// Cached signal state, advanced once per closed D1 bar.
double g_combined_forecast = 0.0;
bool   g_forecast_ready    = false;

// Reusable scratch buffers (file-scope to avoid per-call allocation).
double g_host_cum[QM_WINDOW];
double g_class_cum[QM_WINDOW];
double g_peer_cum[QM_WINDOW];

void QM_BuildClassModel()
  {
   for(int c = 0; c < QM_NCLASS; ++c)
      g_class_count[c] = 0;

   // Class 0 — FOREX majors (card targets EUR/GBP/USD/JPY/AUD pairs).
   string fx[] =
     {
      "EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX","AUDUSD.DWX",
      "NZDUSD.DWX","USDCHF.DWX","USDCAD.DWX"
     };
   for(int i = 0; i < ArraySize(fx); ++i) { g_class_member[0][i] = fx[i]; }
   g_class_count[0] = ArraySize(fx);

   // Class 1 — equity INDICES (NDX/WS30 from the card + DWX index peers).
   string idx[] =
     {
      "NDX.DWX","WS30.DWX","SP500.DWX","GDAXI.DWX","UK100.DWX"
     };
   for(int i = 0; i < ArraySize(idx); ++i) { g_class_member[1][i] = idx[i]; }
   g_class_count[1] = ArraySize(idx);

   // Class 2 — COMMODITIES / metals (XAUUSD from the card + DWX commodity peers).
   string cmd[] =
     {
      "XAUUSD.DWX","XAGUSD.DWX","XTIUSD.DWX","XNGUSD.DWX"
     };
   for(int i = 0; i < ArraySize(cmd); ++i) { g_class_member[2][i] = cmd[i]; }
   g_class_count[2] = ArraySize(cmd);
  }

int QM_ClassOf(const string sym)
  {
   for(int c = 0; c < QM_NCLASS; ++c)
      for(int i = 0; i < g_class_count[c]; ++i)
         if(g_class_member[c][i] == sym)
            return c;
   return -1;
  }

// Fill `universe` with the host + every member of the host's asset class.
void QM_BuildUniverse(string &universe[])
  {
   int n = 0;
   ArrayResize(universe, 1 + QM_MAX_CLASS);
   universe[n++] = _Symbol;
   if(g_host_class >= 0)
     {
      for(int i = 0; i < g_class_count[g_host_class]; ++i)
        {
         const string s = g_class_member[g_host_class][i];
         bool dup = false;
         for(int j = 0; j < n; ++j)
            if(universe[j] == s) { dup = true; break; }
         if(!dup)
            universe[n++] = s;
        }
     }
   ArrayResize(universe, n);
  }

// Build a volatility-normalised cumulative-return path for `sym` into `out`
// (length QM_WINDOW, index 0 = oldest). Returns true on success. Uses closed
// D1 bars only (shift 1 = last completed bar). All foreign reads are bound to
// `sym` at the call site.
bool QM_BuildCumNormPath(const string sym, double &out[])
  {
   if(Bars(sym, PERIOD_D1) < strategy_min_d1_bars)
      return false;

   const int L = strategy_vol_lookback;
   // Need WINDOW returns + L history for the trailing vol of the oldest return.
   const int need = QM_WINDOW + L + 2;
   // perf-allowed: one closed-bar copy of D1 closes per peer, once per new D1 bar.
   double closes[];
   ArraySetAsSeries(closes, true);
   const int got = CopyClose(sym, PERIOD_D1, 1, need, closes);
   if(got < need)
      return false;

   // closes[] is series-indexed: closes[0] = last closed bar, increasing = older.
   // Daily log return at series index k: r[k] = log(closes[k]) - log(closes[k+1]).
   // Cumulative path index 0 = oldest -> map to series index (QM_WINDOW-1).
   double cum = 0.0;
   for(int w = 0; w < QM_WINDOW; ++w)
     {
      // Newest contribution last: iterate oldest->newest.
      const int k = (QM_WINDOW - 1) - w;   // series index of this window step's return
      const double c_now  = closes[k];
      const double c_prev = closes[k + 1];
      if(c_now <= 0.0 || c_prev <= 0.0)
         return false;
      const double ret = MathLog(c_now) - MathLog(c_prev);

      // Trailing stdev of the L returns ending at this bar (series k .. k+L).
      double mean = 0.0;
      for(int m = 0; m < L; ++m)
        {
         const double a = closes[k + m];
         const double b = closes[k + m + 1];
         if(a <= 0.0 || b <= 0.0)
            return false;
         mean += (MathLog(a) - MathLog(b));
        }
      mean /= (double)L;
      double var = 0.0;
      for(int m = 0; m < L; ++m)
        {
         const double a = closes[k + m];
         const double b = closes[k + m + 1];
         const double rr = (MathLog(a) - MathLog(b)) - mean;
         var += rr * rr;
        }
      var /= (double)L;
      const double vol = MathSqrt(var);
      const double norm_ret = (vol > 0.0) ? (ret / vol) : 0.0;

      cum += norm_ret;
      out[w] = cum;
     }
   return true;
  }

// EMA of a window-indexed series with the given span; returns the LAST value.
double QM_EMA_LastOf(const double &series[], const int span)
  {
   const double alpha = 2.0 / (double)(span + 1);
   double ema = series[0];
   for(int w = 1; w < QM_WINDOW; ++w)
      ema = alpha * series[w] + (1.0 - alpha) * ema;
   return ema;
  }

// Advance the cached combined forecast for the host vs its asset class.
// Called once per closed D1 bar (cheap relative to per-tick; bounded loops).
void QM_AdvanceForecast()
  {
   g_forecast_ready    = false;
   g_combined_forecast = 0.0;

   if(g_host_class < 0)
      return;

   if(!QM_BuildCumNormPath(_Symbol, g_host_cum))
      return;

   // Class benchmark = equal-weight mean of peers' cum-norm paths (exclude host).
   for(int w = 0; w < QM_WINDOW; ++w)
      g_class_cum[w] = 0.0;
   int members = 0;
   for(int i = 0; i < g_class_count[g_host_class]; ++i)
     {
      const string peer = g_class_member[g_host_class][i];
      if(peer == _Symbol)
         continue;
      if(!QM_BuildCumNormPath(peer, g_peer_cum))
         continue;                       // missing peer data -> skip (card rule)
      for(int w = 0; w < QM_WINDOW; ++w)
         g_class_cum[w] += g_peer_cum[w];
      ++members;
     }
   if(members < strategy_min_class_members)
      return;                            // not enough peers for a benchmark
   for(int w = 0; w < QM_WINDOW; ++w)
      g_class_cum[w] /= (double)members;

   // Outperformance path = host - class (reuse g_peer_cum as scratch).
   for(int w = 0; w < QM_WINDOW; ++w)
      g_peer_cum[w] = g_host_cum[w] - g_class_cum[w];

   // Per-horizon forecast, then equal-weight combine.
   double combined = 0.0;
   int    used     = 0;
   for(int hh = 0; hh < QM_NHORIZON; ++hh)
     {
      const int H = QM_HORIZON[hh];
      if(QM_WINDOW <= H)
         continue;
      const double avg_outperf =
         (g_peer_cum[QM_WINDOW - 1] - g_peer_cum[QM_WINDOW - 1 - H]) / (double)H;

      // Smooth the avg-outperformance series with EMA(span = max(H/4, 2)).
      // The avg-outperf is itself a single scalar per bar; the source smooths the
      // per-bar avg series. We approximate the source EMA by smoothing the
      // outperformance differences across the window at this horizon.
      const int span = (int)MathMax((double)(H / 4), 2.0);
      // Build the per-bar avg-outperf series over the window for this horizon.
      double avg_series[QM_WINDOW];
      for(int w = 0; w < QM_WINDOW; ++w)
        {
         const int back = w - H;
         if(back < 0)
            avg_series[w] = 0.0;
         else
            avg_series[w] = (g_peer_cum[w] - g_peer_cum[back]) / (double)H;
        }
      const double smoothed = QM_EMA_LastOf(avg_series, span);

      double fc = smoothed * QM_FC_SCALAR[hh];
      if(fc > 20.0)  fc = 20.0;
      if(fc < -20.0) fc = -20.0;
      combined += fc;
      ++used;
     }
   if(used <= 0)
      return;

   g_combined_forecast = combined / (double)used;
   g_forecast_ready    = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter: spread guard only (fail-open on .DWX zero spread).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                      // no valid quote — defer, don't block
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/normal modeled spread passes.
   if(spread > 0.0 && spread > 0.20 * atr)
      return true;
   return false;
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true (one call per closed D1 bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_forecast_ready)
      return false;

   int dir = 0;
   if(g_combined_forecast >= strategy_entry_threshold)
      dir = +1;
   else if(g_combined_forecast <= -strategy_entry_threshold)
      dir = -1;
   if(dir == 0)
      return false;

   const QM_OrderType ot = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;        // no fixed TP — exit is the signal reversal
   req.reason = (dir > 0) ? "relmom_long" : "relmom_short";
   return true;
  }

// No active trade management beyond the emergency ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Signal-reversal exit: close long when combined <= +exit_buffer, close short
// when combined >= -exit_buffer. Uses the forecast cached on this D1 bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_forecast_ready)
      return false;

   int pos_dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      pos_dir = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      break;
     }
   if(pos_dir == 0)
      return false;

   if(pos_dir > 0 && g_combined_forecast <= strategy_exit_buffer)
      return true;
   if(pos_dir < 0 && g_combined_forecast >= -strategy_exit_buffer)
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

   // Build the asset-class model and resolve the host's class.
   QM_BuildClassModel();
   g_host_class = QM_ClassOf(_Symbol);

   // BASKET wiring: register the host + class peers and warm their D1 history so
   // foreign-symbol reads return real data in the tester.
   string universe[];
   QM_BuildUniverse(universe);
   QM_SymbolGuardInit(universe);
   QM_BasketWarmupHistory(universe, PERIOD_D1, QM_WINDOW + strategy_vol_lookback + strategy_min_d1_bars + 10);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host_class\":%d,\"universe\":%d}",
                            g_host_class, ArraySize(universe)));
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
   // D1 bar, refresh the cross-sectional forecast BEFORE the rule-based exit so
   // the signal-reversal exit sees the current forecast.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceForecast();

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
