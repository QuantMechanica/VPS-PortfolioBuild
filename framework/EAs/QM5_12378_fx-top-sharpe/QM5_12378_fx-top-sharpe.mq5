#property strict
#property version   "5.0"
#property description "QM5_12378 fx-top-sharpe — cross-sectional FX rolling-Sharpe rotation (D1, basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12378 fx-top-sharpe
// -----------------------------------------------------------------------------
// Source: Neely & Weller, "Lessons from the Evolution of Foreign Exchange
// Trading Strategies" (Papers With Backtest), source_id b7832a20. Card:
// artifacts/cards_approved/QM5_12378_fx-top-sharpe.md (g0_status APPROVED).
//
// BASKET EA — cross-sectional FX rotation by TRAILING SHARPE. The source ranks
// rule/currency pairs by trailing Sharpe over a multi-year lookback and holds
// the highest-ranked live signals, re-ranking and rebalancing every 20 business
// days. The faithful, framework-bounded realization here:
//
//   Universe   : the 7 DWX FX majors named in the card's target_symbols
//                (EURUSD GBPUSD USDJPY USDCHF USDCAD AUDUSD NZDUSD).
//   Rank metric: per symbol, the TRAILING SHARPE of D1 log-ish simple returns
//                r[t] = close[t]/close[t-1] - 1 over `strategy_sharpe_lookback`
//                closed D1 bars: Sharpe = mean(r) / stdev(r). This is computed
//                in-EA from .DWX closes (no QM_Sharpe helper exists; the return
//                series is bespoke structural math the pooled readers can't do).
//   Direction  : the card's rule library reduces to a long-trend gate for a
//                long-only one-position-per-magic EA — the host's own MA rule
//                (Close > SMA(strategy_trend_period)) must be non-flat LONG.
//   Select     : rank all valid symbols by Sharpe; the top-N (strategy_top_n)
//                form the active book for the next rebalance window.
//   Entry(host): host is in the top-N by Sharpe AND its trend rule is LONG AND
//                no open position for this magic.
//   Exit(host) : at rebalance the host drops out of the top-N, OR its trend rule
//                flips non-long (rule flips before rebalance per the card).
//   Stop       : protective strategy_stop_atr_mult * ATR(strategy_atr_period,D1)
//                from entry (card: 3.0 * ATR(20)). The 20-business-day reselection
//                is the primary close; the ATR stop bounds MT5 worst-case.
//   Rebalance  : every `strategy_rebalance_days` closed D1 bars (card: 20 business
//                days). Counted on the new-bar boundary; selection is STATE.
//   Filters    : require >= strategy_min_candidates valid symbols; >= warmup bars
//                + lookback per symbol; >= strategy_min_signal_days non-flat trend
//                days in the lookback before a symbol can be ranked (card filter);
//                skip new host entries only on a genuinely wide host spread.
//
// All cross-sectional math runs on CLOSED D1 bars, advanced once per new D1 bar
// and only on the rebalance boundary. .DWX closes for every universe symbol are
// warmed via QM_SymbolGuardInit + QM_BasketWarmupHistory so foreign reads return
// real tester data. Long-only; the source forms long/short books but the EA's
// one-position-per-magic long realization holds the long leg of the top-Sharpe
// uptrending majors. No ML, no external feed, no PnL-adaptive parameters.
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12378;
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
input int    strategy_sharpe_lookback    = 252;   // D1 bars for trailing Sharpe (card: 3y; P3 sweep {252,504,756})
input int    strategy_top_n              = 5;     // hold top-N by Sharpe (card N=5; P3 {3,5,8})
input int    strategy_trend_period       = 50;    // long-trend MA gate: Close>SMA(period) (card MA rule)
input int    strategy_atr_period         = 20;    // protective-stop ATR period (D1; card ATR(20))
input double strategy_stop_atr_mult      = 3.0;   // protective stop = mult*ATR (card 3.0; P3 {2.0,3.0,4.0})
input int    strategy_rebalance_days     = 20;    // rebalance every N closed D1 bars (card: 20 business days)
input int    strategy_min_candidates     = 3;     // min valid symbols for a usable ranking
input int    strategy_min_signal_days    = 60;    // min non-flat trend days in lookback to rank (card filter)
input int    strategy_min_warmup_bars    = 800;   // min D1 warmup bars per symbol (card: 800)
input double strategy_spread_pct_of_stop = 20.0;  // skip if host spread > this % of stop distance

// -----------------------------------------------------------------------------
// Fixed FX-major universe (matrix-verified). The EA reads every member's D1
// closes to rank trailing Sharpe; the host trades only when it is top-N and
// its own trend rule is long.
// -----------------------------------------------------------------------------
#define QM_MAX_CAND 16

string g_cand[QM_MAX_CAND];
int    g_ncand    = 0;
int    g_host_idx = -1;                 // index of _Symbol in g_cand, or -1

// Cached selection state, advanced once per closed D1 rebalance bar.
double g_sharpe[QM_MAX_CAND];           // trailing Sharpe per symbol
bool   g_valid[QM_MAX_CAND];            // per-symbol valid-data flag
bool   g_intopn[QM_MAX_CAND];           // per-symbol top-N membership this window
bool   g_long[QM_MAX_CAND];             // per-symbol trend rule = long (Close>SMA)
int    g_active_count = 0;              // symbols with valid Sharpe this eval
bool   g_ready    = false;              // true when this eval produced a usable book
int    g_bars_since_rebal = 0;          // closed-bar counter toward rebalance cadence
bool   g_have_book = false;             // a book has been selected at least once

void QM_BuildCandidates()
  {
   string u[] =
     {
      "EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX","USDCHF.DWX",
      "USDCAD.DWX","AUDUSD.DWX","NZDUSD.DWX"
     };
   g_ncand = ArraySize(u);
   if(g_ncand > QM_MAX_CAND) g_ncand = QM_MAX_CAND;
   for(int i = 0; i < g_ncand; ++i)
      g_cand[i] = u[i];
  }

// Fill `out` with the universe plus the host (dedup keeps the warmup list clean).
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
// Trailing Sharpe of D1 simple returns for one symbol over `lookback` bars.
// Bespoke structural math (no pooled reader covers a foreign return series), so
// a single CopyClose is taken here. This runs ONLY on the rebalance bar (gated
// in OnTick by QM_IsNewBar + the cadence counter), well inside the smoke budget.
// `out_sharpe` = mean(r)/stdev(r); `out_signal_days` = count of non-flat trend
// days (close vs its own SMA window) used for the card's min-signal-days filter.
// Returns false when the symbol lacks enough warm bars.
// -----------------------------------------------------------------------------
bool QM_SymbolSharpe(const string sym, const int lookback, const int trend_period,
                     double &out_sharpe, int &out_signal_days)
  {
   out_sharpe = 0.0;
   out_signal_days = 0;

   // Need lookback returns -> lookback+1 closes; plus trend_period for the SMA
   // signal-day count; plus the card warmup floor. Read from shift 1 (closed).
   const int n_close = lookback + 1;
   const int need = MathMax(strategy_min_warmup_bars, n_close + trend_period + 2);
   if(Bars(sym, PERIOD_D1) < need)
      return false;

   double close[];
   ArraySetAsSeries(close, true);
   // Closes [0]=shift1 (last closed) .. need-1. CopyClose start=1 skips forming bar.
   const int want = n_close + trend_period + 1;
   const int got = CopyClose(sym, PERIOD_D1, 1, want, close); // perf-allowed: rebalance-bar only, cached
   if(got < n_close + 1)
      return false;

   // Returns over the most recent `lookback` closed bars: r[i]=close[i]/close[i+1]-1.
   double sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double c0 = close[i];
      const double c1 = close[i + 1];
      if(c1 <= 0.0)
         return false;
      sum += (c0 / c1 - 1.0);
     }
   const double mean = sum / (double)lookback;

   double var_sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double r = close[i] / close[i + 1] - 1.0;
      const double d = r - mean;
      var_sum += d * d;
     }
   const double variance = var_sum / (double)lookback;
   if(variance <= 0.0)
      return false;
   const double sd = MathSqrt(variance);
   if(sd <= 0.0)
      return false;

   out_sharpe = mean / sd;

   // Count non-flat trend-signal days in the lookback: a day is "signal" when its
   // close differs from the trailing SMA(trend_period) at that day (long or short
   // rule is active). Uses the cached closes only; no extra reads.
   int sig = 0;
   const int sig_span = MathMin(lookback, got - trend_period - 1);
   for(int i = 0; i < sig_span; ++i)
     {
      double ssum = 0.0;
      for(int k = 1; k <= trend_period; ++k)
         ssum += close[i + k];
      const double sma = ssum / (double)trend_period;
      if(MathAbs(close[i] - sma) > 0.0)
         ++sig;
     }
   out_signal_days = sig;
   return true;
  }

// -----------------------------------------------------------------------------
// Advance the cross-sectional Sharpe ranking ONCE per closed D1 rebalance bar.
// Builds g_sharpe / g_valid / g_long / g_intopn and the top-N book.
// -----------------------------------------------------------------------------
void QM_AdvanceSelection()
  {
   g_ready = false;
   g_active_count = 0;

   for(int i = 0; i < g_ncand; ++i)
     {
      g_sharpe[i] = 0.0;
      g_valid[i]  = false;
      g_intopn[i] = false;
      g_long[i]   = false;

      const string sym = g_cand[i];
      double sharpe = 0.0;
      int    sig_days = 0;
      if(!QM_SymbolSharpe(sym, strategy_sharpe_lookback, strategy_trend_period, sharpe, sig_days))
         continue;
      // Card filter: require enough non-flat signal days before a symbol can rank.
      if(sig_days < strategy_min_signal_days)
         continue;

      // Long-trend rule gate (Close > SMA(trend_period)) on the last closed bar.
      const double sma = QM_SMA(sym, PERIOD_D1, strategy_trend_period, 1);
      const double c1  = iClose(sym, PERIOD_D1, 1);          // perf-allowed: rebalance-bar only
      if(sma <= 0.0 || c1 <= 0.0)
         continue;

      g_sharpe[i] = sharpe;
      g_long[i]   = (c1 > sma);
      g_valid[i]  = true;
      ++g_active_count;
     }

   if(g_active_count < strategy_min_candidates)
     {
      // Too thin: clear the book so held positions exit at this rebalance.
      g_have_book = true;
      return;
     }

   // Select the top-N valid symbols by Sharpe (descending). Simple selection
   // over <=16 members — bounded, runs once per rebalance bar.
   const int top_n = MathMin(strategy_top_n, g_active_count);
   for(int rank = 0; rank < top_n; ++rank)
     {
      int best = -1;
      double best_sh = 0.0;
      for(int i = 0; i < g_ncand; ++i)
        {
         if(!g_valid[i] || g_intopn[i]) continue;
         if(best < 0 || g_sharpe[i] > best_sh)
           { best = i; best_sh = g_sharpe[i]; }
        }
      if(best < 0) break;
      g_intopn[best] = true;
     }

   g_have_book = true;
   g_ready = true;
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
      return false;                             // no valid quote — defer, don't block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                              // genuinely wide spread — block
   return false;                                // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true. Selection is advanced in
// OnTick before this call (g_intopn / g_long / g_ready).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready || g_host_idx < 0)
      return false;

   // Host must be in the top-N book AND its own trend rule must be long.
   if(!g_intopn[g_host_idx] || !g_long[g_host_idx])
      return false;

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
   req.tp     = 0.0;        // no TP — 20-day reselection / rule-flip is the primary exit
   req.reason = "fx_top_sharpe_long";
   return true;
  }

// No active management beyond the static protective ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Exit the host long when, at a rebalance, the host has dropped out of the top-N
// book OR its trend rule has flipped non-long (rule flip before rebalance).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_have_book || g_host_idx < 0)
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

   // Exit when the host is no longer top-N, or its trend rule is no longer long.
   if(!g_intopn[g_host_idx] || !g_long[g_host_idx])
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

   // Build the fixed FX-major universe and locate the host within it.
   QM_BuildCandidates();
   g_host_idx = -1;
   for(int i = 0; i < g_ncand; ++i)
      if(g_cand[i] == _Symbol) { g_host_idx = i; break; }

   g_bars_since_rebal = 0;
   g_have_book = false;
   g_ready = false;

   // BASKET wiring: register the host + every universe symbol and warm their D1
   // history so foreign-symbol reads (CopyClose / QM_SMA) return real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int warm = strategy_sharpe_lookback + strategy_trend_period
                    + strategy_min_warmup_bars + 16;
   QM_BasketWarmupHistory(warmlist, PERIOD_D1, warm);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"universe\":%d,\"host\":\"%s\",\"host_idx\":%d,\"top_n\":%d}",
                            g_ncand, _Symbol, g_host_idx, strategy_top_n));
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

   // Latch the closed-bar event ONCE (single-consume). Advance the rebalance
   // counter on each new D1 bar; refresh the cross-sectional Sharpe book only on
   // the 20-business-day boundary (and on the first new bar to seed the book),
   // BEFORE the rule-based exit so the signal-exit sees the current selection.
   const bool nb = QM_IsNewBar();
   if(nb)
     {
      ++g_bars_since_rebal;
      if(!g_have_book || g_bars_since_rebal >= strategy_rebalance_days)
        {
         QM_AdvanceSelection();
         g_bars_since_rebal = 0;
        }
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
