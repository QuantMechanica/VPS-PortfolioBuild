#property strict
#property version   "5.0"
#property description "QM5_11056 pst-normmom — pysystemtrade volatility-normalised momentum (EWMAC, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11056 pst-normmom
// -----------------------------------------------------------------------------
// Source: Rob Carver / pysystemtrade rob_system normalised-momentum rules
//   (normmom2/4/8/16/32/64 + get_cumulative_daily_vol_normalised_returns).
// Card: artifacts/cards_approved/QM5_11056_pst-normmom.md (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift >= 1):
//   1. Build a cumulative VOLATILITY-NORMALISED RETURN series ("norm price"):
//        r_t       = close_t / close_{t-1} - 1
//        vol_t     = rolling stddev of returns over `vol_lookback`
//        norm_ret  = r_t / vol_t
//        norm_px_t = cumulative_sum(norm_ret)        (like a price, equal vol)
//   2. For each Lfast in {2,4,8,16,32,64}, Lslow = 4*Lfast:
//        raw   = (EMA(norm_px,Lfast) - EMA(norm_px,Lslow)) / robust_vol(diff(norm_px),35)
//        fc    = clamp(raw * forecast_scalar[Lfast], -cap, +cap)
//   3. combined_forecast = mean of the 6 capped components.
//   4. Long  when combined >= +entry_threshold ; exit long  when <= +exit_buffer.
//      Short when combined <= -entry_threshold ; exit short when >= -exit_buffer.
//      Flip only after a later close crosses the opposite entry threshold.
//   5. Emergency stop = stop_atr_mult * ATR(stop_atr_period). Primary exit is the
//      signal-reversal close above; the stop only bounds MT5 worst-case risk.
//
// .DWX invariants honoured: D1-native (no MN1), no swap gate, fail-OPEN spread,
// returns use the prior CLOSE (gapless CFDs), no external-macro CSV. The norm-
// price series is rebuilt once per closed D1 bar (QM_IsNewBar gate) — cheap at
// ~252 bars/year — and cached in file scope; OnTick reads only cached state.
//
// Only the 5 Strategy_* hooks + AdvanceState_OnNewBar + Strategy inputs are
// EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11056;
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
// Volatility-normalised return construction.
input int    strategy_vol_lookback      = 35;    // rolling stddev window for daily-return vol
input int    strategy_warmup_bars       = 320;   // min closed D1 bars before any signal
// Robust-vol of diff(norm_price) used to scale each raw EWMAC.
input int    strategy_diff_vol_lookback = 35;    // robust-vol window of diff(norm_price)
// Combined-forecast thresholds.
input double strategy_entry_threshold   = 5.0;   // |forecast| >= this to enter
input double strategy_exit_buffer       = 1.0;   // close long when fc <= +this (short: >= -this)
input double strategy_forecast_cap      = 20.0;  // per-component cap [-cap,+cap]
// Emergency stop (signal reversal is the primary exit).
input int    strategy_stop_atr_period   = 20;    // ATR period for the emergency stop
input double strategy_stop_atr_mult     = 3.0;   // emergency stop distance = mult * ATR
// Spread guard: skip new entries on a genuinely wide spread (fail-OPEN on .DWX).
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// EWMAC horizons + their pysystemtrade forecast scalars (fixed, non-ML table).
// Lfast = {2,4,8,16,32,64}, Lslow = 4*Lfast.
const int    NORMMOM_HORIZONS = 6;

// -----------------------------------------------------------------------------
// File-scope cached state — advanced ONCE per closed D1 bar.
// -----------------------------------------------------------------------------
double g_combined_forecast = 0.0;   // latest combined forecast at last closed bar
bool   g_forecast_valid    = false; // false until enough history is built

int FastLen(const int h)
  {
   switch(h)
     {
      case 0: return 2;
      case 1: return 4;
      case 2: return 8;
      case 3: return 16;
      case 4: return 32;
      default: return 64;
     }
  }

double ForecastScalar(const int h)
  {
   switch(h)
     {
      case 0: return 12.388306;
      case 1: return 8.614430;
      case 2: return 5.979139;
      case 3: return 4.116537;
      case 4: return 2.758873;
      default: return 1.870680;
     }
  }

// Standard EMA of a forward-ordered series (series[0] oldest .. series[n-1] newest).
// Returns the EMA value at the newest sample.
double EmaOfSeries(const double &series[], const int n, const int period)
  {
   if(n <= 0 || period <= 0)
      return 0.0;
   const double alpha = 2.0 / (period + 1.0);
   double ema = series[0];
   for(int i = 1; i < n; ++i)
      ema = alpha * series[i] + (1.0 - alpha) * ema;
   return ema;
  }

// Rebuild the cumulative vol-normalised return series and the combined forecast.
// Called ONCE per new closed D1 bar (do not add a second timestamp gate).
void AdvanceState_OnNewBar()
  {
   g_forecast_valid = false;

   const int longest_slow = 4 * FastLen(NORMMOM_HORIZONS - 1); // 4*64 = 256
   // Need closes back far enough to: form returns, the vol window, AND the
   // longest EMA span across the norm-price series.
   const int need_bars = strategy_warmup_bars + longest_slow + strategy_vol_lookback + 8;

   // Use closed bars only: shift 1 is the last completed bar. Index k below
   // maps oldest..newest. We build returns r_t = close_t/close_{t-1} - 1.
   // perf-allowed: single CopyClose inside the QM_IsNewBar gate (D1, once/bar).
   double closes[];
   const int copied = CopyClose(_Symbol, _Period, 1, need_bars, closes); // perf-allowed
   if(copied < strategy_warmup_bars + longest_slow + strategy_vol_lookback + 4)
      return; // not enough history yet
   // CopyClose returns oldest..newest in closes[0..copied-1] (as-series false default).
   ArraySetAsSeries(closes, false);

   const int nc = copied;
   // Daily returns: ret[i] corresponds to closes[i] vs closes[i-1], i=1..nc-1.
   double rets[];
   ArrayResize(rets, nc);
   rets[0] = 0.0;
   for(int i = 1; i < nc; ++i)
     {
      const double prev = closes[i - 1];
      rets[i] = (prev > 0.0) ? (closes[i] / prev - 1.0) : 0.0;
     }

   // Rolling stddev of returns over vol_lookback -> per-bar vol; normalised
   // return = ret/vol. Build the cumulative norm-price series.
   const int vl = strategy_vol_lookback;
   double normpx[];
   ArrayResize(normpx, nc);
   double cum = 0.0;
   int    np_count = 0;
   double normpx_seq[]; // compact, only valid samples (oldest..newest)
   ArrayResize(normpx_seq, nc);
   for(int i = 1; i < nc; ++i)
     {
      if(i < vl)
        { normpx[i] = cum; continue; }   // pre-warmup: hold flat
      // stddev of rets over [i-vl+1 .. i]
      double mean = 0.0;
      for(int j = i - vl + 1; j <= i; ++j)
         mean += rets[j];
      mean /= vl;
      double var = 0.0;
      for(int j = i - vl + 1; j <= i; ++j)
        {
         const double d = rets[j] - mean;
         var += d * d;
        }
      var /= vl;
      const double vol = MathSqrt(var);
      const double norm_ret = (vol > 0.0) ? (rets[i] / vol) : 0.0;
      cum += norm_ret;
      normpx[i] = cum;
      normpx_seq[np_count++] = cum;
     }

   if(np_count < longest_slow + strategy_diff_vol_lookback + 4)
      return; // not enough normalised samples to form the slowest EMA + diff vol

   // Robust vol of diff(norm_price) over diff_vol_lookback (stddev of the last
   // dvl first-differences of the compact norm-price sequence).
   const int dvl = strategy_diff_vol_lookback;
   double diffs[];
   ArrayResize(diffs, np_count);
   for(int i = 1; i < np_count; ++i)
      diffs[i] = normpx_seq[i] - normpx_seq[i - 1];
   // stddev over the last dvl diffs (indices np_count-dvl .. np_count-1).
   double dmean = 0.0;
   for(int i = np_count - dvl; i < np_count; ++i)
      dmean += diffs[i];
   dmean /= dvl;
   double dvar = 0.0;
   for(int i = np_count - dvl; i < np_count; ++i)
     {
      const double d = diffs[i] - dmean;
      dvar += d * d;
     }
   dvar /= dvl;
   const double diff_vol = MathSqrt(dvar);
   if(diff_vol <= 0.0)
      return;

   // For each horizon: EMA(norm_px,Lfast) - EMA(norm_px,Lslow) on the tail span,
   // scaled by diff_vol, * forecast scalar, capped. Average the six.
   double sum_fc = 0.0;
   for(int h = 0; h < NORMMOM_HORIZONS; ++h)
     {
      const int lf = FastLen(h);
      const int ls = 4 * lf;
      // EMA over the most recent `ls + ls` samples is enough to stabilise the
      // slow EMA; clamp the span to the available data.
      int span = 4 * ls;
      if(span > np_count) span = np_count;
      const int start = np_count - span;
      double tail[];
      ArrayResize(tail, span);
      for(int k = 0; k < span; ++k)
         tail[k] = normpx_seq[start + k];

      const double ema_fast = EmaOfSeries(tail, span, lf);
      const double ema_slow = EmaOfSeries(tail, span, ls);
      const double raw = (ema_fast - ema_slow) / diff_vol;
      double fc = raw * ForecastScalar(h);
      if(fc >  strategy_forecast_cap) fc =  strategy_forecast_cap;
      if(fc < -strategy_forecast_cap) fc = -strategy_forecast_cap;
      sum_fc += fc;
     }

   g_combined_forecast = sum_fc / NORMMOM_HORIZONS;
   g_forecast_valid    = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is cached per bar.
// Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_stop_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry, do not block

   const double stop_distance = strategy_stop_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry: long when combined forecast >= +threshold, short when <= -threshold.
// Caller guarantees QM_IsNewBar() == true (closed-bar gate). Reads cached state.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_forecast_valid)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_stop_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(g_combined_forecast >= strategy_entry_threshold)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_stop_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — signal reversal is the primary exit
      req.reason = "normmom_long";
      return true;
     }

   if(g_combined_forecast <= -strategy_entry_threshold)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_stop_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "normmom_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed emergency ATR stop. The signal-reversal
// close lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal-reversal exit (primary close path):
//   close long  when combined forecast <= +exit_buffer
//   close short when combined forecast >= -exit_buffer
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_forecast_valid)
      return false;

   // Determine current net direction for this magic.
   bool have_long = false;
   bool have_short = false;
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
      if(ptype == POSITION_TYPE_BUY)  have_long  = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }

   if(have_long && g_combined_forecast <= strategy_exit_buffer)
      return true;
   if(have_short && g_combined_forecast >= -strategy_exit_buffer)
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!QM_IsNewBar())
      return;

   // FIRST work on the new closed bar: rebuild the normalised-momentum forecast.
   AdvanceState_OnNewBar();

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
