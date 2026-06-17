#property strict
#property version   "5.0"
#property description "QM5_11059 pst-momentum — pysystemtrade raw-price EWMAC combined forecast (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11059 pst-momentum
// -----------------------------------------------------------------------------
// Source: Rob Carver / pst-group, pysystemtrade rob_system raw-price momentum.
//   rob_system/config.yaml rules momentum4/8/16/32/64; rules/ewmac.py "ewmac".
// Card: artifacts/cards_approved/QM5_11059_pst-momentum.md (g0_status APPROVED).
//
// Mechanics (long+short, closed-bar reads at shift 1, D1 native):
//   Daily price-unit volatility (mixed vol, source params):
//     - exponential daily-return vol, span = vol_days (35), min_periods 10
//     - blended: (1 - slow_prop) * fast_vol + slow_prop * mean(fast_vol, 20y)
//   Five EWMAC components on raw daily close:
//     momentum4 : (EMA(4)  - EMA(16))  / vol , scalar 8.539941
//     momentum8 : (EMA(8)  - EMA(32))  / vol , scalar 5.949404
//     momentum16: (EMA(16) - EMA(64))  / vol , scalar 4.104172
//     momentum32: (EMA(32) - EMA(128)) / vol , scalar 2.786994
//     momentum64: (EMA(64) - EMA(256)) / vol , scalar 1.909395
//   Each scaled component capped to [-fc_cap, +fc_cap] (20).
//   Combined forecast = equal-weight average of the five capped components.
//   Entry  : combined >= +entry_threshold  -> long
//            combined <= -entry_threshold  -> short
//   Exit   : long  closed when combined <= +exit_buffer
//            short closed when combined >= -exit_buffer
//   Stop   : emergency stop = stop_atr_mult * ATR(atr_period) from entry.
//   Spread : fail-open guard; skip only a genuinely wide spread (zero modeled
//            spread on .DWX always passes).
//   One open position per symbol/magic; reversal happens after exit then a
//   later closed bar re-crosses the opposite entry threshold.
//
// The mixed-vol + EWMAC composite is bespoke per-EA math the framework readers
// cannot express directly. It runs ONLY on the closed-bar path (EntrySignal /
// ExitSignal, both gated by the framework new-bar gate) so the O(N) close scan
// happens once per D1 bar, not per tick. EMA reads use the pooled QM_EMA reader.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11059;
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
// EWMAC component fast spans (slow span = 4 * fast, per source momentumN config).
input int    strategy_ema_fast_1        = 4;        // momentum4  fast span
input int    strategy_ema_fast_2        = 8;        // momentum8  fast span
input int    strategy_ema_fast_3        = 16;       // momentum16 fast span
input int    strategy_ema_fast_4        = 32;       // momentum32 fast span
input int    strategy_ema_fast_5        = 64;       // momentum64 fast span
// Fixed forecast scalars from rob_system config (NOT optimised, non-ML constants).
input double strategy_scalar_1          = 8.539941; // momentum4  scalar
input double strategy_scalar_2          = 5.949404; // momentum8  scalar
input double strategy_scalar_3          = 4.104172; // momentum16 scalar
input double strategy_scalar_4          = 2.786994; // momentum32 scalar
input double strategy_scalar_5          = 1.909395; // momentum64 scalar
input double strategy_fc_cap            = 20.0;     // per-component forecast cap [-cap,+cap]
input double strategy_entry_threshold   = 5.0;      // |combined| >= -> enter (sweep 3/5/8)
input double strategy_exit_buffer       = 1.0;      // exit when combined decays to this side (sweep 0/1/2)
// Mixed daily-return volatility (source: days 35, min 10, slow 20y, prop 0.35).
input int    strategy_vol_days          = 35;       // exponential vol span (daily returns)
input int    strategy_vol_min_periods   = 10;       // minimum returns required for vol estimate
input int    strategy_vol_slow_years    = 20;       // slow-vol averaging window, years
input double strategy_vol_slow_prop     = 0.35;     // proportion of slow vol in the blend
// Emergency stop only (signal decay is the primary close).
input int    strategy_atr_period        = 20;       // ATR period for the emergency stop
input double strategy_stop_atr_mult     = 3.0;      // stop distance = mult * ATR (sweep 2.5/3.0/3.5)
input double strategy_spread_pct_of_stop = 25.0;    // skip if spread > this % of stop distance (fail-open)

// Warmup: slowest EMA span (4*64=256) + vol window. Min 320 D1 bars per card.
#define QM5_11059_MIN_BARS  330

// Closed-bar cache of the combined forecast. The forecast only changes on a
// new completed D1 bar, so the O(N) close scan + EMA reads run ONCE per bar.
// Both the per-tick exit path and the closed-bar entry path read through
// QM5_11059_GetForecast(), which recomputes only when the last-closed-bar
// open-time has advanced — keeping the per-tick path O(1) on unchanged bars.
double   g_combined_forecast = 0.0;
bool     g_forecast_valid    = false;
datetime g_forecast_bar_time = 0;

// -----------------------------------------------------------------------------
// Internal helpers (closed-bar path only — never called from the per-tick path)
// -----------------------------------------------------------------------------

// Daily price-unit volatility, mixed-vol blend per the source config.
// fast = exponentially-weighted std of daily price differences over vol_days,
// slow = simple mean of that fast series over vol_slow_years of D1 bars,
// blended = (1 - slow_prop) * fast + slow_prop * slow. Returns price units.
// Returns <= 0.0 when there is not enough history (caller then skips the bar).
double QM5_11059_MixedVol()
  {
   const int slow_bars  = strategy_vol_slow_years * 256; // ~256 trading days/yr
   const int diff_count = MathMax(strategy_vol_days, slow_bars) + 2;

   // Pull closed-bar closes: shift 1 is the most recent completed bar.
   double closes[];
   ArraySetAsSeries(closes, true);
   const int got = CopyClose(_Symbol, _Period, 1, diff_count + 1, closes);
   if(got < strategy_vol_min_periods + 2)
      return 0.0;

   const int n_diffs = got - 1; // number of daily price differences available

   // Exponentially-weighted volatility of daily price differences (span model:
   // alpha = 2/(span+1)). closes[0] = most recent completed bar.
   const double alpha = 2.0 / (double)(strategy_vol_days + 1);
   double ew_var = 0.0;
   bool   seeded = false;
   int    used   = 0;
   // Walk oldest -> newest so the EW recursion weights recent diffs most.
   for(int k = n_diffs - 1; k >= 0; --k)
     {
      const double diff = closes[k] - closes[k + 1]; // newer minus older (series=true)
      const double sq   = diff * diff;
      if(!seeded)
        {
         ew_var = sq;
         seeded = true;
        }
      else
         ew_var = alpha * sq + (1.0 - alpha) * ew_var;
      used++;
     }
   if(used < strategy_vol_min_periods || ew_var <= 0.0)
      return 0.0;
   const double fast_vol = MathSqrt(ew_var);

   // Slow vol = simple average of squared daily diffs over the slow window,
   // expressed as a std. Falls back to the available window when history short.
   double slow_sumsq = 0.0;
   int    slow_used  = 0;
   const int slow_lim = MathMin(n_diffs, slow_bars);
   for(int k = 0; k < slow_lim; ++k)
     {
      const double diff = closes[k] - closes[k + 1];
      slow_sumsq += diff * diff;
      slow_used++;
     }
   double slow_vol = fast_vol;
   if(slow_used >= strategy_vol_min_periods && slow_sumsq > 0.0)
      slow_vol = MathSqrt(slow_sumsq / (double)slow_used);

   double prop = strategy_vol_slow_prop;
   if(prop < 0.0) prop = 0.0;
   if(prop > 1.0) prop = 1.0;
   const double mixed = (1.0 - prop) * fast_vol + prop * slow_vol;
   return (mixed > 0.0 ? mixed : 0.0);
  }

// One EWMAC component: (EMA(fast) - EMA(4*fast)) / vol, scaled and capped.
// Returns the capped scaled forecast. ok=false if any EMA read is invalid.
double QM5_11059_Component(const int fast_span, const double scalar,
                           const double vol, bool &ok)
  {
   ok = false;
   const int slow_span = fast_span * 4;
   const double ema_fast = QM_EMA(_Symbol, _Period, fast_span, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, slow_span, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || vol <= 0.0)
      return 0.0;
   double fc = ((ema_fast - ema_slow) / vol) * scalar;
   if(fc >  strategy_fc_cap) fc =  strategy_fc_cap;
   if(fc < -strategy_fc_cap) fc = -strategy_fc_cap;
   ok = true;
   return fc;
  }

// Equal-weight combined forecast across the five components. ok=false if any
// component or the volatility estimate is not yet available.
double QM5_11059_CombinedForecast(bool &ok)
  {
   ok = false;
   if(Bars(_Symbol, _Period) < QM5_11059_MIN_BARS)
      return 0.0;

   const double vol = QM5_11059_MixedVol();
   if(vol <= 0.0)
      return 0.0;

   const int    fasts[5]   = {strategy_ema_fast_1, strategy_ema_fast_2,
                              strategy_ema_fast_3, strategy_ema_fast_4,
                              strategy_ema_fast_5};
   const double scalars[5] = {strategy_scalar_1, strategy_scalar_2,
                              strategy_scalar_3, strategy_scalar_4,
                              strategy_scalar_5};

   double sum = 0.0;
   for(int i = 0; i < 5; ++i)
     {
      bool comp_ok = false;
      const double fc = QM5_11059_Component(fasts[i], scalars[i], vol, comp_ok);
      if(!comp_ok)
         return 0.0;
      sum += fc;
     }
   ok = true;
   return sum / 5.0;
  }

// Cached accessor: recompute the combined forecast only when the last completed
// bar has advanced. Called from both the per-tick exit path and the closed-bar
// entry path; on an unchanged bar this is an O(1) timestamp compare + cache hit.
double QM5_11059_GetForecast(bool &ok)
  {
   // perf-allowed: iTime here is a CACHE-INVALIDATION key for the expensive
   // composite forecast, NOT a new-bar entry gate. Entry cadence is owned by
   // the framework QM_IsNewBar() gate in OnTick; this only avoids recomputing
   // the O(N) close scan on every per-tick exit-hook call within the same bar.
   const datetime last_closed = iTime(_Symbol, _Period, 1);
   if(last_closed != g_forecast_bar_time || !g_forecast_valid)
     {
      bool calc_ok = false;
      const double fc = QM5_11059_CombinedForecast(calc_ok);
      g_combined_forecast = fc;
      g_forecast_valid    = calc_ok;
      g_forecast_bar_time = last_closed;
     }
   ok = g_forecast_valid;
   return g_combined_forecast;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Fail-open spread guard only; .DWX zero modeled
// spread always passes. Stop-distance reference scales the cap per symbol.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_stop_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long/short entry on the combined EWMAC forecast threshold. Caller guarantees
// QM_IsNewBar() == true (closed-bar path).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (no pyramiding / grid).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   bool ok = false;
   const double combined = QM5_11059_GetForecast(ok);
   if(!ok)
      return false;

   QM_OrderType side;
   if(combined >= strategy_entry_threshold)
      side = QM_BUY;
   else if(combined <= -strategy_entry_threshold)
      side = QM_SELL;
   else
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target — exit on forecast decay (below) or stop
   req.reason = (side == QM_BUY) ? "ewmac_combined_long" : "ewmac_combined_short";
   return true;
  }

// No active trade management beyond the fixed emergency ATR stop. The forecast-
// decay exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Forecast-decay exit: close long when combined <= +exit_buffer, close short
// when combined >= -exit_buffer. Evaluated on the closed-bar path.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   bool ok = false;
   const double combined = QM5_11059_GetForecast(ok);
   if(!ok)
      return false; // cannot evaluate — let the emergency stop protect the trade

   // Determine current net direction for this magic from the open position.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long pt = PositionGetInteger(POSITION_TYPE);
      if(pt == POSITION_TYPE_BUY)  is_long  = true;
      if(pt == POSITION_TYPE_SELL) is_short = true;
     }

   if(is_long  && combined <= strategy_exit_buffer)
      return true;
   if(is_short && combined >= -strategy_exit_buffer)
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
