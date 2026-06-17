#property strict
#property version   "5.0"
#property description "QM5_11058 pst-skewfactor — pysystemtrade cross-sectional negative-skew factor (D1 basket)"

#include <QM/QM_Common.mqh>
#include <QM/QM_Indicators.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11058 pst-skewfactor
// -----------------------------------------------------------------------------
// Source: Rob Carver / pst-group pysystemtrade skew factor rules
//   systems/provided/rules/factors.py  factor_trading_rule
//   rob_system/config.yaml  skewabs365 / skewabs180 / skewrv365 / skewrv180
//   rob_system/rawdata.py   skew / neg_skew / get_demeanded_factor_value
// (source_id 352af9de-f372-5cf2-9a86-681a26224597)
// Card: artifacts/cards_approved/QM5_11058_pst-skewfactor.md (g0_status APPROVED).
//
// BASKET / cross-sectional FACTOR EA. The basket spans 7 DWX assets:
//   FX        : EURUSD, GBPUSD, USDJPY, AUDUSD
//   indices   : NDX, WS30
//   commodity : XAUUSD
// Each EA instance runs on one registered host symbol but reads the WHOLE basket
// on D1 to build the cross-sectional skew factor and trade the host's signed
// forecast. No external feed: skew is a pure statistic of each symbol's own D1
// return distribution over a bounded closed-bar lookback.
//
// Mechanics (advanced once per closed D1 bar; all closed-bar reads at shift>=1):
//   neg_skew(sym, L) = -sample_skew( D1 %returns over the last L closed bars ).
//   Four components, each capped to [-20,+20]:
//     skewabs365: L=365, demean against the CROSS-SECTIONAL (all-asset) mean of
//                 neg_skew, normalise by the cross-sectional robust vol (stdev of
//                 neg_skew across assets), EWMA span 90, scalar 2.351484.
//     skewabs180: L=180, same demean, EWMA span 45, scalar 4.590247.
//     skewrv365 : L=365, demean against the host ASSET-CLASS mean of neg_skew,
//                 same cross-sectional robust vol, EWMA span 90, scalar 3.002222.
//     skewrv180 : L=180, asset-class demean, EWMA span 45, scalar 5.244753.
//   combined_forecast = equal-weight average of the four capped components.
//   Entry  : long  when combined >= +entry_threshold (default +5).
//            short when combined <= -entry_threshold.
//   Exit   : close long  when combined <= +exit_buffer (default +1).
//            close short when combined >= -exit_buffer.
//   Flip   : a new opposite entry only fires after a later D1 close crosses the
//            opposite entry threshold (one position per magic enforces this).
//   Stop   : emergency 3.0 * ATR(20, D1) from entry (bounds MT5 worst case;
//            primary exit is signal reversal).
//   Filters: >=3 active assets in the host's asset class for the rv components;
//            >=420 D1 bars warmup per asset; skip new entries when spread
//            exceeds 2 * median spread proxy (fail-open on .DWX zero spread).
//
// Only the five Strategy_* hooks + the OnInit basket wiring are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11058;
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
input int    strategy_skew_long_lookback  = 365;  // L for skewabs365 / skewrv365 (D1 bars)
input int    strategy_skew_short_lookback = 180;  // L for skewabs180 / skewrv180 (D1 bars)
input int    strategy_ewma_span_long      = 90;   // EWMA span for the 365D components
input int    strategy_ewma_span_short     = 45;   // EWMA span for the 180D components
input double strategy_scalar_abs365       = 2.351484; // pst forecast scalar
input double strategy_scalar_abs180       = 4.590247;
input double strategy_scalar_rv365        = 3.002222;
input double strategy_scalar_rv180        = 5.244753;
input double strategy_forecast_cap        = 20.0;  // per-component cap [-cap,+cap] (P3 sweep)
input double strategy_entry_threshold     = 5.0;   // |combined| >= this to enter (P3 sweep {3,5,8})
input double strategy_exit_buffer         = 1.0;   // close when combined decays inside this band (P3 {0,1,2})
input int    strategy_atr_period          = 20;    // ATR period for the emergency stop
input double strategy_atr_sl_mult         = 3.0;   // SL = mult * ATR(20,D1) (P3 sweep {2.5,3.0,3.5})
input int    strategy_min_d1_bars         = 420;   // warmup: 365D skew + smoothing
input int    strategy_min_class_assets    = 3;     // min active assets in class for rv components
input double strategy_spread_atr_cap_pct  = 200.0; // skip entry if spread > this % of ATR(D1) (proxy for 2*median)

// -----------------------------------------------------------------------------
// Static basket model (7 assets, with asset-class tags).
// -----------------------------------------------------------------------------
#define QM_NASSET   7
#define QM_NCOMP    4

// Asset-class codes.
#define QM_CLASS_FX     0
#define QM_CLASS_INDEX  1
#define QM_CLASS_COMMOD 2

string g_asset[QM_NASSET];        // basket .DWX symbols
int    g_asset_class[QM_NASSET];  // asset-class code per symbol

// Per-asset neg_skew for each lookback, recomputed once per closed D1 bar.
double g_negskew_long[QM_NASSET];   // neg_skew over the long  lookback (365D)
double g_negskew_short[QM_NASSET];  // neg_skew over the short lookback (180D)
bool   g_asset_ready[QM_NASSET];    // enough D1 history for this asset

// Persisted EWMA state per component (advanced one step per closed D1 bar).
double g_ewma[QM_NCOMP];           // current smoothed component value (pre-scalar/cap)
bool   g_ewma_seeded[QM_NCOMP];

// Current capped components + combined forecast for the HOST symbol.
double g_component[QM_NCOMP];
double g_combined_forecast = 0.0;
bool   g_forecast_ready    = false;

// Host index inside the basket (-1 if host is not a basket asset → inert).
int    g_host_idx = -1;

// -----------------------------------------------------------------------------
int QM_AssetIndex(const string sym)
  {
   for(int i = 0; i < QM_NASSET; ++i)
      if(g_asset[i] == sym)
         return i;
   return -1;
  }

void QM_BuildBasketModel()
  {
   g_asset[0] = "EURUSD.DWX"; g_asset_class[0] = QM_CLASS_FX;
   g_asset[1] = "GBPUSD.DWX"; g_asset_class[1] = QM_CLASS_FX;
   g_asset[2] = "USDJPY.DWX"; g_asset_class[2] = QM_CLASS_FX;
   g_asset[3] = "AUDUSD.DWX"; g_asset_class[3] = QM_CLASS_FX;
   g_asset[4] = "NDX.DWX";    g_asset_class[4] = QM_CLASS_INDEX;
   g_asset[5] = "WS30.DWX";   g_asset_class[5] = QM_CLASS_INDEX;
   g_asset[6] = "XAUUSD.DWX"; g_asset_class[6] = QM_CLASS_COMMOD;
  }

// -----------------------------------------------------------------------------
// Sample skew of the last `lookback` D1 percentage returns of `sym`, computed
// from CLOSED bars only (close reads at shift 1 .. lookback+1). Returns true on
// success and writes the (positive) sample skew into `out_skew`.
// perf-allowed: bounded foreign-symbol closed-bar reads, run once per closed D1
// bar (a D1 EA gets one new bar per day → well within the smoke budget).
// -----------------------------------------------------------------------------
bool QM_RollingSkew(const string sym, const int lookback, double &out_skew)
  {
   out_skew = 0.0;
   if(lookback < 8)
      return false;
   if(Bars(sym, PERIOD_D1) < (lookback + 2))
      return false;

   // Returns r[k] = (close[shift=1+k] - close[shift=2+k]) / close[shift=2+k].
   // We need `lookback` returns → close reads from shift 1 to shift lookback+1.
   double sum = 0.0;
   int    n   = 0;
   double rets[];
   ArrayResize(rets, lookback);
   for(int k = 0; k < lookback; ++k)
     {
      const double c0 = iClose(sym, PERIOD_D1, 1 + k);
      const double c1 = iClose(sym, PERIOD_D1, 2 + k);
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;          // missing data → asset not ready this bar
      const double r = (c0 - c1) / c1;
      rets[n] = r;
      sum += r;
      ++n;
     }
   if(n < 8)
      return false;

   const double mean = sum / (double)n;
   double m2 = 0.0, m3 = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const double d = rets[k] - mean;
      m2 += d * d;
      m3 += d * d * d;
     }
   m2 /= (double)n;
   m3 /= (double)n;
   if(m2 <= 0.0)
      return false;
   const double sd = MathSqrt(m2);
   out_skew = m3 / (sd * sd * sd);   // population sample skewness
   return true;
  }

// -----------------------------------------------------------------------------
// Advance the whole factor model ONCE per closed D1 bar.
//  1. neg_skew per asset for both lookbacks.
//  2. cross-sectional mean + robust vol (stdev across assets) per lookback.
//  3. asset-class mean per (class, lookback).
//  4. demeaned/normalised raw factor for the HOST, per component.
//  5. EWMA-smooth each component, apply scalar, cap.
//  6. combined_forecast = equal-weight mean of the four capped components.
// -----------------------------------------------------------------------------
void QM_AdvanceFactor()
  {
   g_forecast_ready = false;

   if(g_host_idx < 0)
      return;

   const int Llong  = strategy_skew_long_lookback;
   const int Lshort = strategy_skew_short_lookback;

   // 1. neg_skew per asset for each lookback.
   for(int a = 0; a < QM_NASSET; ++a)
     {
      g_asset_ready[a] = false;
      g_negskew_long[a]  = 0.0;
      g_negskew_short[a] = 0.0;
      if(Bars(g_asset[a], PERIOD_D1) < strategy_min_d1_bars)
         continue;
      double sk_l = 0.0, sk_s = 0.0;
      const bool ok_l = QM_RollingSkew(g_asset[a], Llong,  sk_l);
      const bool ok_s = QM_RollingSkew(g_asset[a], Lshort, sk_s);
      if(!ok_l || !ok_s)
         continue;
      g_negskew_long[a]  = -sk_l;   // neg_skew = -rolling_skew
      g_negskew_short[a] = -sk_s;
      g_asset_ready[a]   = true;
     }

   if(!g_asset_ready[g_host_idx])
      return;

   // 2. cross-sectional (all-asset) mean + robust vol per lookback.
   double sum_l = 0.0, sum_s = 0.0;
   int    cnt = 0;
   for(int a = 0; a < QM_NASSET; ++a)
     {
      if(!g_asset_ready[a])
         continue;
      sum_l += g_negskew_long[a];
      sum_s += g_negskew_short[a];
      ++cnt;
     }
   if(cnt < 2)
      return;
   const double mean_all_l = sum_l / (double)cnt;
   const double mean_all_s = sum_s / (double)cnt;

   double var_l = 0.0, var_s = 0.0;
   for(int a = 0; a < QM_NASSET; ++a)
     {
      if(!g_asset_ready[a])
         continue;
      const double dl = g_negskew_long[a]  - mean_all_l;
      const double ds = g_negskew_short[a] - mean_all_s;
      var_l += dl * dl;
      var_s += ds * ds;
     }
   var_l /= (double)cnt;
   var_s /= (double)cnt;
   const double vol_l = MathSqrt(var_l);
   const double vol_s = MathSqrt(var_s);
   if(vol_l <= 0.0 || vol_s <= 0.0)
      return;

   // 3. asset-class mean per (host class, lookback). Require >= min_class_assets.
   const int host_class = g_asset_class[g_host_idx];
   double cls_sum_l = 0.0, cls_sum_s = 0.0;
   int    cls_cnt = 0;
   for(int a = 0; a < QM_NASSET; ++a)
     {
      if(!g_asset_ready[a])
         continue;
      if(g_asset_class[a] != host_class)
         continue;
      cls_sum_l += g_negskew_long[a];
      cls_sum_s += g_negskew_short[a];
      ++cls_cnt;
     }
   const bool class_ok = (cls_cnt >= strategy_min_class_assets);
   double cls_mean_l = 0.0, cls_mean_s = 0.0;
   if(class_ok)
     {
      cls_mean_l = cls_sum_l / (double)cls_cnt;
      cls_mean_s = cls_sum_s / (double)cls_cnt;
     }

   // 4. raw demeaned/normalised factor for the HOST, per component.
   //    abs* : demean against the all-asset mean. rv* : against the class mean.
   const double host_nl = g_negskew_long[g_host_idx];
   const double host_ns = g_negskew_short[g_host_idx];

   double raw[QM_NCOMP];
   bool   comp_ok[QM_NCOMP];
   raw[0] = (host_nl - mean_all_l) / vol_l;  comp_ok[0] = true;            // skewabs365
   raw[1] = (host_ns - mean_all_s) / vol_s;  comp_ok[1] = true;            // skewabs180
   if(class_ok)
     {
      raw[2] = (host_nl - cls_mean_l) / vol_l; comp_ok[2] = true;          // skewrv365
      raw[3] = (host_ns - cls_mean_s) / vol_s; comp_ok[3] = true;          // skewrv180
     }
   else
     {
      raw[2] = 0.0; comp_ok[2] = false;
      raw[3] = 0.0; comp_ok[3] = false;
     }

   // 5. EWMA-smooth each available raw component, then scalar + cap.
   const double alpha_long  = 2.0 / ((double)strategy_ewma_span_long  + 1.0);
   const double alpha_short = 2.0 / ((double)strategy_ewma_span_short + 1.0);
   const double alpha[QM_NCOMP] = { alpha_long, alpha_short, alpha_long, alpha_short };
   const double scalar[QM_NCOMP] =
     { strategy_scalar_abs365, strategy_scalar_abs180,
       strategy_scalar_rv365,  strategy_scalar_rv180 };

   double combined_sum = 0.0;
   int    combined_cnt = 0;
   for(int c = 0; c < QM_NCOMP; ++c)
     {
      g_component[c] = 0.0;
      if(!comp_ok[c])
        {
         g_ewma_seeded[c] = false;     // class went stale → reseed when it returns
         continue;
        }
      if(!g_ewma_seeded[c])
        {
         g_ewma[c]        = raw[c];
         g_ewma_seeded[c] = true;
        }
      else
        {
         g_ewma[c] = alpha[c] * raw[c] + (1.0 - alpha[c]) * g_ewma[c];
        }
      double comp = g_ewma[c] * scalar[c];
      if(comp >  strategy_forecast_cap) comp =  strategy_forecast_cap;
      if(comp < -strategy_forecast_cap) comp = -strategy_forecast_cap;
      g_component[c] = comp;
      combined_sum += comp;
      ++combined_cnt;
     }

   if(combined_cnt <= 0)
      return;

   // 6. equal-weight average of the AVAILABLE capped components.
   g_combined_forecast = combined_sum / (double)combined_cnt;
   g_forecast_ready    = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick filter: spread guard only (fail-open on .DWX zero spread).
// No session window — this is a daily factor; entries fire on the D1 close.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                     // no valid quote — defer, don't block
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_atr_cap_pct / 100.0) * atr)
      return true;                      // genuinely wide spread — block
   return false;                        // zero/normal modeled spread — pass
  }

// D1 entry. Caller guarantees QM_IsNewBar()==true (one call per closed D1 bar).
// The factor is advanced in OnTick (on the same new-bar event) BEFORE this call.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;                     // one position per magic; flip needs flat first

   if(g_host_idx < 0)
      return false;
   if(!g_forecast_ready)
      return false;

   int dir = 0;
   if(g_combined_forecast >=  strategy_entry_threshold) dir = +1;
   else if(g_combined_forecast <= -strategy_entry_threshold) dir = -1;
   if(dir == 0)
      return false;

   const QM_OrderType ot = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, ot, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type   = ot;
   req.price  = 0.0;                    // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;                    // no fixed TP; primary exit is signal reversal
   req.reason = (dir > 0) ? "skewfactor_long" : "skewfactor_short";
   return true;
  }

// No active trade management beyond the static emergency ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Signal-reversal exit: close long when the forecast decays to <= +exit_buffer,
// close short when it recovers to >= -exit_buffer. Uses the forecast cached by
// QM_AdvanceFactor on this closed D1 bar.
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

   if(pos_dir > 0 && g_combined_forecast <=  strategy_exit_buffer) return true;
   if(pos_dir < 0 && g_combined_forecast >= -strategy_exit_buffer) return true;
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

   // Build the static basket model and resolve the host's index.
   QM_BuildBasketModel();
   g_host_idx = QM_AssetIndex(_Symbol);

   for(int c = 0; c < QM_NCOMP; ++c)
     {
      g_ewma[c]        = 0.0;
      g_ewma_seeded[c] = false;
      g_component[c]   = 0.0;
     }

   // BASKET wiring: register the full basket and warm D1 history so every
   // foreign-symbol read returns real data in the tester.
   string universe[];
   ArrayResize(universe, QM_NASSET);
   for(int i = 0; i < QM_NASSET; ++i)
      universe[i] = g_asset[i];
   QM_SymbolGuardInit(universe);
   // Warm enough D1 history to cover the 365D lookback + warmup margin.
   QM_BasketWarmupHistory(universe, PERIOD_D1, strategy_min_d1_bars + 60);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"host\":\"%s\",\"host_idx\":%d,\"assets\":%d}",
                            _Symbol, g_host_idx, QM_NASSET));
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
   // D1 bar refresh the cross-sectional skew factor BEFORE evaluating the exit
   // so the signal-reversal exit sees the current forecast.
   const bool nb = QM_IsNewBar();
   if(nb)
      QM_AdvanceFactor();

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
