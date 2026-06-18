#property strict
#property version   "5.0"
#property description "QM5_12392 comm-asym-ie — commodity return-asymmetry IE cross-section (D1, basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12392 comm-asym-ie
// -----------------------------------------------------------------------------
// Source: Papers With Backtest / Quantpedia "Return Asymmetry Effect in
// Commodity Futures", source_id b7832a20. Card:
// artifacts/cards_approved/QM5_12392_comm-asym-ie.md (g0_status APPROVED).
//
// BASKET EA — monthly commodity cross-section by an Information-Event (IE)
// asymmetry count. Each calendar month, on the first tradable D1 bar, compute
// per commodity an IE count over the latest 260 daily returns:
//
//   returns[k]  = close[1+k] / close[2+k] - 1     (k = 0..lookback-1, closed bars)
//   mean, stdev = sample stats of those `lookback` returns
//   IE          = count(r > mean + 2*stdev) - count(r < mean - 2*stdev)
//
// Then rank symbols ASCENDING by IE and:
//   long the LOWEST-IE commodity, short the HIGHEST-IE commodity.
// The lowest-IE asset (fewest positive tail events relative to negative) is the
// long; the highest-IE asset is the short. (Source buys bottom-7 / sells top-7
// from a 22-name universe; the DWX port narrows to a 1-long / 1-short pair over
// the four available commodity CFDs.)
//
// DWX commodity universe (matrix-verified, available=true):
//   XAUUSD.DWX (gold), XAGUSD.DWX (silver), XTIUSD.DWX (WTI oil), XNGUSD.DWX (nat gas)
//
// The EA runs one instance per host symbol. The host opens a LONG only when it
// is itself the selected lowest-IE commodity, a SHORT only when it is the
// selected highest-IE commodity. One position per magic on the host. Monthly
// reselection is the primary exit; a protective 3.0*ATR(20,D1) stop bounds the
// MT5 worst case.
//
// MN1 is untestable in the .DWX tester (0 bars), so the monthly cadence is a
// D1-native "first tradable D1 bar of a new calendar month" gate (broker-time
// month rollover of the newly-closed D1 bar), NOT a PERIOD_MN1 series.
//
// IE needs the full return distribution (mean / stdev / tail counts), which no
// QM_* reader exposes, so closes are pulled via a single CopyClose per symbol
// INSIDE the monthly new-bar gate (once per month per symbol — well within the
// smoke budget). No per-tick history reads.
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12392;
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
input int    strategy_ie_lookback        = 260;   // daily returns in the IE window (P3 {126,189,260})
input double strategy_ie_sigma_mult      = 2.0;   // tail threshold = mean +/- mult*stdev
input int    strategy_min_candidates     = 4;     // require >= this many valid commodities (card: 4)
input int    strategy_atr_period         = 20;    // protective-stop ATR period (D1)
input double strategy_stop_atr_mult      = 3.0;   // protective stop = mult*ATR (P3 {2.0,3.0,4.0})
input double strategy_spread_pct_of_stop = 20.0;  // skip if host spread > this % of stop distance

// -----------------------------------------------------------------------------
// Fixed commodity basket (matrix-verified, available=true). The EA reads every
// candidate's D1 closes to compute IE, ranks ascending, then longs the lowest
// and shorts the highest. The host trades only when it is one of those two.
// -----------------------------------------------------------------------------
#define QM_MAX_CAND 8

string g_cand[QM_MAX_CAND];
int    g_ncand    = 0;
int    g_host_idx = -1;          // index of _Symbol in g_cand, or -1

// Cached selection state, advanced once per monthly rebalance D1 bar.
double g_ie[QM_MAX_CAND];        // IE count per candidate
bool   g_valid[QM_MAX_CAND];     // per-candidate valid-data flag
int    g_long_idx  = -1;         // index of the selected long (lowest IE), or -1
int    g_short_idx = -1;         // index of the selected short (highest IE), or -1
int    g_active_count = 0;       // candidates with valid IE this eval
bool   g_ready    = false;       // true when this eval produced a usable selection
int    g_last_eval_month = -1;   // broker-time month of the last evaluation (rollover guard)

void QM_BuildCandidates()
  {
   string u[] =
     {
      "XAUUSD.DWX","XAGUSD.DWX","XTIUSD.DWX","XNGUSD.DWX"
     };
   g_ncand = ArraySize(u);
   if(g_ncand > QM_MAX_CAND) g_ncand = QM_MAX_CAND;
   for(int i = 0; i < g_ncand; ++i)
      g_cand[i] = u[i];
  }

// Fill `out` with the candidate basket plus the host (dedup keeps warmup clean).
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

// Compute the IE asymmetry count for one symbol over the last `lookback` daily
// returns (built from closed D1 bars, shift 1.. = no look-ahead). Returns true
// and sets `ie_out` when the symbol has enough warm history; false otherwise.
// Single CopyClose per call — runs only on the monthly rebalance bar.
bool QM_ComputeIE(const string sym, const int lookback, double &ie_out)
  {
   ie_out = 0.0;
   const int need_closes = lookback + 2;          // returns[k]=close[1+k]/close[2+k]
   if(Bars(sym, PERIOD_D1) < need_closes + 2)
      return false;

   double closes[];
   // Pull closed bars only: start at shift 1, count need_closes. CopyClose with
   // (start_pos=1) skips the still-forming bar 0.
   const int copied = CopyClose(sym, PERIOD_D1, 1, need_closes, closes);
   if(copied < need_closes)
      return false;
   // CopyClose fills index 0 = oldest of the copied window. We addressed it by
   // shift via start_pos, so closes[copied-1] is the most recent closed bar.
   // Build returns newest-first: r[k] = closes[last-k]/closes[last-1-k] - 1.
   const int last = copied - 1;
   double rets[];
   ArrayResize(rets, lookback);
   for(int k = 0; k < lookback; ++k)
     {
      const double c_new = closes[last - k];
      const double c_old = closes[last - 1 - k];
      if(c_old <= 0.0)
         return false;
      rets[k] = c_new / c_old - 1.0;
     }

   // Sample mean and (population) standard deviation of the returns.
   double sum = 0.0;
   for(int k = 0; k < lookback; ++k)
      sum += rets[k];
   const double mean = sum / lookback;

   double var_sum = 0.0;
   for(int k = 0; k < lookback; ++k)
     {
      const double d = rets[k] - mean;
      var_sum += d * d;
     }
   const double stdev = MathSqrt(var_sum / lookback);
   if(stdev <= 0.0)
      return false;

   const double hi = mean + strategy_ie_sigma_mult * stdev;
   const double lo = mean - strategy_ie_sigma_mult * stdev;
   int up = 0, dn = 0;
   for(int k = 0; k < lookback; ++k)
     {
      if(rets[k] > hi) ++up;
      else if(rets[k] < lo) ++dn;
     }
   ie_out = (double)(up - dn);
   return true;
  }

// -----------------------------------------------------------------------------
// Advance the cross-sectional selection ONCE per monthly rebalance D1 bar.
// Ranks valid candidates by IE: lowest IE -> long, highest IE -> short.
// -----------------------------------------------------------------------------
void QM_AdvanceSelection()
  {
   g_ready = false;
   g_long_idx = -1;
   g_short_idx = -1;
   g_active_count = 0;

   for(int i = 0; i < g_ncand; ++i)
     {
      g_ie[i] = 0.0;
      g_valid[i] = false;
      double ie = 0.0;
      if(!QM_ComputeIE(g_cand[i], strategy_ie_lookback, ie))
         continue;
      g_ie[i] = ie;
      g_valid[i] = true;
      ++g_active_count;
     }

   if(g_active_count < strategy_min_candidates)
      return;                                       // too thin for a valid rank

   // Lowest IE = long leg, highest IE = short leg. First valid member seeds both.
   int lo_idx = -1, hi_idx = -1;
   double lo_ie = 0.0, hi_ie = 0.0;
   for(int i = 0; i < g_ncand; ++i)
     {
      if(!g_valid[i]) continue;
      if(lo_idx < 0 || g_ie[i] < lo_ie) { lo_idx = i; lo_ie = g_ie[i]; }
      if(hi_idx < 0 || g_ie[i] > hi_ie) { hi_idx = i; hi_ie = g_ie[i]; }
     }

   // Degenerate: all IE equal -> lo_idx == hi_idx. Skip (no asymmetric spread).
   if(lo_idx < 0 || hi_idx < 0 || lo_idx == hi_idx)
      return;

   g_long_idx  = lo_idx;
   g_short_idx = hi_idx;
   g_ready = true;
  }

// Is the newly-closed D1 bar the FIRST tradable bar of a new calendar month
// (broker time)? Latched so a month evaluates exactly once.
bool QM_IsMonthlyRebalanceBar()
  {
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(dt.mon == g_last_eval_month)
      return false;
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
      return false;                                 // no valid quote — defer, don't block

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_stop_atr_mult * atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;                                  // genuinely wide spread — block
   return false;                                    // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true. Selection advanced in OnTick
// before this call (g_long_idx / g_short_idx / g_ready). Host longs when it is
// the lowest-IE pick, shorts when it is the highest-IE pick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_ready || g_host_idx < 0)
      return false;

   QM_OrderType ot;
   string reason;
   if(g_host_idx == g_long_idx)
     {
      ot = QM_BUY;
      reason = "ie_long_lowest";
     }
   else if(g_host_idx == g_short_idx)
     {
      ot = QM_SELL;
      reason = "ie_short_highest";
     }
   else
      return false;                                 // host is neither leg this month

   const double entry = (ot == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;        // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;        // no TP — monthly reselection is the primary exit
   req.reason = reason;
   return true;
  }

// No active management beyond the static protective ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Monthly rebalance exit: close the host position when it is no longer the leg
// (long->lowest, short->highest) that the current selection assigns it, or when
// the selection became unusable.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(g_host_idx < 0)
      return false;

   // Determine the side of the open host position (one per magic).
   bool have_pos = false;
   bool is_long = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      have_pos = true;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      break;
     }
   if(!have_pos)
      return false;

   // Selection unusable this month -> liquidate (card: close all if < min valid).
   if(!g_ready)
      return true;

   // Hold only while the host still maps to its current side.
   if(is_long  && g_host_idx == g_long_idx)
      return false;
   if(!is_long && g_host_idx == g_short_idx)
      return false;

   return true;                                     // no longer the selected leg -> close
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

   // Build the fixed commodity basket and locate the host within it.
   QM_BuildCandidates();
   g_host_idx = -1;
   for(int i = 0; i < g_ncand; ++i)
      if(g_cand[i] == _Symbol) { g_host_idx = i; break; }

   // BASKET wiring: register the host + every candidate and warm their D1
   // history so foreign-symbol reads return real tester data.
   string warmlist[];
   QM_BuildWarmupList(warmlist);
   QM_SymbolGuardInit(warmlist);
   const int warm = strategy_ie_lookback + strategy_atr_period + 32;
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
   // also the first bar of a new calendar month, refresh the cross-sectional IE
   // selection BEFORE the rule-based exit so the signal-exit sees the current pick.
   const bool nb = QM_IsNewBar();
   if(nb && QM_IsMonthlyRebalanceBar())
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
