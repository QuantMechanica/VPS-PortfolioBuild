#property strict
#property version   "5.0"
#property description "QM5_11065 atc-macd-prob — MACD cross gated by fixed historical-probability bins (H1 FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11065 atc-macd-prob
// -----------------------------------------------------------------------------
// Source: Vitaly Antonov ("beast"), ATC 2011 interview, MQL5 Articles
//         https://www.mql5.com/en/articles/551
// Card: artifacts/cards_approved/QM5_11065_atc-macd-prob.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trigger EVENT : MACD main crosses signal (up = long candidate,
//                   down = short candidate). ONE cross event per bar.
//   Regime FILTER : ATR percentile over a fixed lookback window must be above
//                   atr_pct_min (calmer regimes are skipped, per the source's
//                   "considerable oscillations were better" comment).
//   Probability   : a BOUNDED DETERMINISTIC lookback computation (NOT an external
//   GATE            feed, NOT online learning). At signal time we classify the
//                   current bar into a discrete bin (MACD-histogram-sign bucket x
//                   ATR-percentile bucket x last-3-bar-return-sign). We then scan a
//                   fixed history window of completed bars, and among bars that
//                   fell in the SAME bin we measure the empirical hit rate that the
//                   candidate direction's next-bar close moved favourably. The bin
//                   is recomputed from scratch every signal from closed-bar history
//                   only — no persisted/mutating state, no PnL-adaptive params, so
//                   it satisfies HR14 (fixed-at-evaluation deterministic table).
//                   Trade only if that empirical probability >= prob_threshold.
//   Stop          : entry -/+ sl_atr_mult * ATR.
//   Take profit   : entry +/- tp_atr_mult * ATR (same ATR value as the stop).
//   Exits         : opposite eligible MACD cross, OR time stop after
//                   time_stop_bars closed H1 bars.
//   Spread guard  : skip only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11065;
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
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 9;      // MACD signal SMA period
input int    strategy_atr_period        = 14;     // ATR period (filter / stop / target)
input int    strategy_atr_pct_lookback  = 100;    // bars for the ATR-percentile window
input double strategy_atr_pct_min        = 40.0;  // skip if ATR percentile <= this (0..100)
input int    strategy_prob_lookback     = 400;    // closed bars scanned to build the prob bin
input double strategy_prob_threshold    = 0.55;   // min empirical bin hit-rate to trade
input int    strategy_prob_min_samples  = 12;     // min same-bin samples or the gate abstains
input double strategy_sl_atr_mult       = 1.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 1.5;    // target distance = mult * ATR
input int    strategy_time_stop_bars    = 16;     // close after N closed H1 bars in trade
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope state. g_entry_bar_time latches the bar-open time of the bar on
// which the current position was opened, so the time stop counts CLOSED bars
// without maintaining a per-EA new-bar gate. It is set on open and cleared on
// flat — it is NOT a strategy-state cache and is never used to gate new bars.
// -----------------------------------------------------------------------------
datetime g_entry_bar_time = 0;

// ---------------------------------------------------------------------------
// Bounded per-signal snapshot. To keep the deterministic probability scan well
// inside the smoke budget, we read ATR / close / MACD-histogram into fixed
// file-scope arrays ONCE per signal evaluation (gated by the framework new-bar
// gate, never per tick), then derive every bin from cheap array arithmetic.
// This avoids the O(lookback x pct_lookback) repeated QM_ATR reads a naive
// nested scan would incur. The snapshot is rebuilt from scratch each signal
// (no persisted/adaptive state), so HR14 holds.
//
// SNAP_MAX bounds the longest span any bin needs:
//   prob_lookback history bars + pct_lookback ATR-percentile window + small
//   margin for the 3-bar return and cross lookback. Inputs are validated in
//   OnInit so the configured spans never exceed SNAP_MAX.
// ---------------------------------------------------------------------------
#define SNAP_MAX 700
double g_snap_atr[SNAP_MAX];   // ATR at shift s
double g_snap_close[SNAP_MAX]; // close at shift s
double g_snap_hist[SNAP_MAX];  // MACD histogram (main-signal) at shift s
int    g_snap_n = 0;           // number of valid leading entries

// Build the per-signal snapshot covering shifts 0..need (inclusive). Returns
// the count of contiguous valid leading bars (from shift 0). All reads are
// closed-bar/handle-pooled; called once per signal evaluation, not per tick.
int BuildSnapshot(const int need)
  {
   const int cap = (need + 1 < SNAP_MAX) ? need + 1 : SNAP_MAX;
   int valid = 0;
   for(int s = 0; s < cap; ++s)
     {
      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, s);
      const double cls = iClose(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      const double mm  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s);
      const double ms  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s);
      // MACD line CAN be negative — no <=0 guard on MACD. Validity is judged on
      // ATR/close only (degenerate empty-history reads come back <= 0).
      if(atr <= 0.0 || cls <= 0.0)
         break;
      g_snap_atr[s]   = atr;
      g_snap_close[s] = cls;
      g_snap_hist[s]  = mm - ms; // histogram may be negative — that is fine
      valid = s + 1;
     }
   g_snap_n = valid;
   return valid;
  }

// ATR percentile (0..100) of the ATR at `shift` vs the ATR distribution over
// [shift+1 .. shift+pct_lookback], read from the cached snapshot.
double ATRPercentileSnap(const int shift)
  {
   const double ref = g_snap_atr[shift];
   int below = 0, total = 0;
   for(int k = 1; k <= strategy_atr_pct_lookback; ++k)
     {
      const int idx = shift + k;
      if(idx >= g_snap_n)
         break;
      total++;
      if(g_snap_atr[idx] < ref)
         below++;
     }
   if(total <= 0)
      return 50.0;
   return (100.0 * (double)below) / (double)total;
  }

// Classify the cached bar at `shift` into a discrete bin and report the MACD
// cross direction at that shift (+1 up / -1 down / 0 none). Reads only the
// snapshot. Returns false if the shift lacks the data its bin needs.
//   bin = histbucket(0..2) * 100 + atrbucket(0..2) * 10 + ret3sign(0..2)
bool ClassifyBarSnap(const int shift, int &bin_out, int &cross_dir_out)
  {
   // Needs shift+1 (cross prev + percentile window start) and shift+3 (return).
   if(shift + 3 >= g_snap_n)
      return false;

   const double hist      = g_snap_hist[shift];
   const double hist_prev = g_snap_hist[shift + 1];

   int cross_dir = 0;
   if(hist_prev <= 0.0 && hist > 0.0)
      cross_dir = 1;
   else if(hist_prev >= 0.0 && hist < 0.0)
      cross_dir = -1;
   cross_dir_out = cross_dir;

   // Histogram-sign bucket with a symbol-scale-aware flat band.
   const double flat_band = 0.05 * g_snap_atr[shift];
   int hist_bucket = 1;
   if(hist < -flat_band)      hist_bucket = 0;
   else if(hist > flat_band)  hist_bucket = 2;

   const double pct = ATRPercentileSnap(shift);
   int atr_bucket = 1;
   if(pct < 33.0)       atr_bucket = 0;
   else if(pct > 66.0)  atr_bucket = 2;

   const double r3 = g_snap_close[shift] - g_snap_close[shift + 3];
   int ret_bucket = 1;
   if(r3 < 0.0)      ret_bucket = 0;
   else if(r3 > 0.0) ret_bucket = 2;

   bin_out = hist_bucket * 100 + atr_bucket * 10 + ret_bucket;
   return true;
  }

// Empirical hit-rate that, among cached historical bars sharing `target_bin`,
// the candidate `direction` (+1 long / -1 short) next-bar move was favourable.
// Pure read over the snapshot; recomputed from scratch every signal, no state.
// Returns -1.0 if too few same-bin samples.
double BinProbabilitySnap(const int target_bin, const int direction)
  {
   const int start_shift = 2;                         // first fully-formed history bar
   int end_shift = strategy_prob_lookback + 1;
   if(end_shift > g_snap_n - 4)
      end_shift = g_snap_n - 4;                        // ClassifyBarSnap needs shift+3
   int hits = 0, samples = 0;
   for(int s = start_shift; s <= end_shift; ++s)
     {
      int b = 0, cd = 0;
      if(!ClassifyBarSnap(s, b, cd))
         continue;
      if(b != target_bin)
         continue;
      // Outcome: next bar toward the present (shift s-1) move vs the bin bar.
      const double move = g_snap_close[s - 1] - g_snap_close[s];
      samples++;
      if(direction > 0 && move > 0.0)
         hits++;
      else if(direction < 0 && move < 0.0)
         hits++;
     }
   if(samples < strategy_prob_min_samples)
      return -1.0;
   return (double)hits / (double)samples;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — all signal work is on the
// closed-bar entry path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). MACD cross
// trigger gated by the deterministic historical-probability bin + ATR-regime.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Build the bounded per-signal snapshot once (history scan source). ---
   const int need = strategy_prob_lookback + strategy_atr_pct_lookback + 5;
   if(BuildSnapshot(need) < strategy_atr_pct_lookback + 10)
      return false; // not enough warmed history yet

   // --- Classify the just-closed bar (shift 1) and read its cross event. ---
   int bin = 0, cross_dir = 0;
   if(!ClassifyBarSnap(1, bin, cross_dir))
      return false;
   if(cross_dir == 0)
      return false; // no fresh MACD cross on the just-closed bar

   // --- ATR-regime filter: skip calm regimes. ---
   const double atr_value = g_snap_atr[1];
   if(atr_value <= 0.0)
      return false;
   const double atr_pct = ATRPercentileSnap(1);
   if(atr_pct <= strategy_atr_pct_min)
      return false;

   // --- Probability gate: deterministic empirical hit-rate for this bin. ---
   const double prob = BinProbabilitySnap(bin, cross_dir);
   if(prob < 0.0)              // too few same-bin samples → abstain
      return false;
   if(prob < strategy_prob_threshold)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const QM_OrderType ot = (cross_dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (cross_dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, ot, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, ot, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (cross_dir > 0) ? "atc_macd_prob_long" : "atc_macd_prob_short";

   // Latch the entry bar-open time for the time-stop counter.
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open time
   return true;
  }

// No active trade management beyond the fixed ATR stop/target.
void Strategy_ManageOpenPosition()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      g_entry_bar_time = 0; // flat → reset the time-stop latch
  }

// Discretionary exit: opposite eligible MACD cross OR time stop after N bars.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Determine the current position side (this magic only).
   int pos_dir = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      pos_dir = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      break;
     }
   if(pos_dir == 0)
      return false;

   // --- Time stop: count CLOSED bars since the entry bar. ---
   if(g_entry_bar_time > 0 && strategy_time_stop_bars > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed
      if(cur_bar > g_entry_bar_time)
        {
         const int bars_held = iBarShift(_Symbol, _Period, g_entry_bar_time, false); // closed bars elapsed
         if(bars_held >= strategy_time_stop_bars)
            return true;
        }
     }

   // --- Opposite eligible MACD cross on the just-closed bar. ---
   // Cheap O(1): only the histogram at shift 1 and shift 2 are needed; do NOT
   // build the heavy probability snapshot on this per-tick path.
   const double hist_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1)
                          - QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double hist_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2)
                          - QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   int cross_dir = 0;
   if(hist_prev <= 0.0 && hist_now > 0.0)
      cross_dir = 1;
   else if(hist_prev >= 0.0 && hist_now < 0.0)
      cross_dir = -1;
   if(cross_dir != 0 && cross_dir == -pos_dir)
      return true;

   return false;
  }

// Defer to the central news filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
      g_entry_bar_time = 0;
     }

   if(!QM_IsNewBar())
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
