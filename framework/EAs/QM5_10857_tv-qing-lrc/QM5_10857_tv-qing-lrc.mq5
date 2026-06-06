#property strict
#property version   "5.0"
#property description "QM5_10857 TradingView Qing LRC Support EMA Mean Reversion (tv-qing-lrc)"
// Strategy Card: QM5_10857 tv-qing-lrc, G0 APPROVED 2026-05-22.
// Source: TradingView `Qing LRC + S/R + EMA (Trend Cross Logic)`, author Z8830.

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10857 — Qing Linear-Regression-Channel + EMA trend-filtered mean reversion
// -----------------------------------------------------------------------------
// Mechanic (card section Mechanik, long-only P2 baseline):
//   - Linear Regression Channel (LRC) over `lrc_length` closed bars, bands at
//     +/- `lrc_dev` * residual std-dev.
//   - Bullish bias when the LRC upper channel sits above EMA(`ema_period`).
//   - Enter LONG when the last closed bar's low touches/pierces the lower band.
//   - Target = LRC upper channel. Early exit when the lower channel crosses
//     below EMA (trend weakness). Time exit after `time_exit_bars` bars.
//   - Stop = lower of recent pivot support and entry - `atr_sl_mult` * ATR.
//   - Filters: skip if channel width < `width_atr_min` * ATR, skip if EMA slope
//     negative three consecutive bars, spread guard, no same-bar re-entry after
//     a weakness exit.
//
// Perf: the LRC regression + pivot scan are bespoke structural math with no QM_*
// reader. They run ONCE per closed bar inside Strategy_EntrySignal (the caller
// gates entry behind QM_IsNewBar()), are cached to file scope, and are read
// O(1) by the per-tick exit path. Raw iClose/iLow calls carry an explicit
// `// perf-allowed` tag per the Framework Corset. NOTE: the exit path must NOT
// call QM_IsNewBar() — that would consume the new-bar event for the _Symbol|
// _Period key and starve the entry gate in OnTick (guaranteed zero trades).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10857;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 — Two-axis news filter per Vault Q09 (temporal + compliance). A trade is
// allowed only if BOTH axes allow.
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
input int    lrc_length        = 100;   // LRC regression lookback (card: 50/100/150)
input double lrc_dev           = 2.0;    // channel std-dev multiplier (card: 1.5/2.0/2.5)
input int    ema_period        = 20;     // trend-filter EMA period
input int    atr_len           = 14;     // ATR period for stop / width
input double atr_sl_mult       = 1.5;    // stop = entry - atr_sl_mult*ATR (card: 1.0/1.5/2.0)
input int    pivot_lookback    = 5;      // recent pivot-support window (card: 3/5/10)
input int    time_exit_bars    = 20;     // time exit after N bars (card: 12/20/30)
input double width_atr_min     = 0.75;   // skip if channel width < this * ATR
input double spread_stop_frac  = 0.15;   // skip if spread > this fraction of stop distance

// -----------------------------------------------------------------------------
// File-scope cached channel state — refreshed once per closed bar inside
// Strategy_EntrySignal (caller is gated by QM_IsNewBar) and read O(1) per tick.
// -----------------------------------------------------------------------------
bool     g_state_ready       = false;
double   g_lrc_up            = 0.0;   // upper band at last closed bar (shift 1)
double   g_lrc_lo            = 0.0;   // lower band at last closed bar (shift 1)
double   g_lrc_lo_prev       = 0.0;   // lower band at shift 2 (cross detection)
double   g_ema_now           = 0.0;   // EMA(ema_period) shift 1
double   g_ema_prev          = 0.0;   // EMA(ema_period) shift 2
double   g_atr_now           = 0.0;   // ATR(atr_period) shift 1
double   g_pivot_support     = 0.0;   // recent swing-low support level
double   g_channel_width     = 0.0;   // upper - lower band
bool     g_ema_slope_neg3          = false; // EMA fell three consecutive bars
bool     g_skip_next_entry_eval    = false; // weakness exit fired; suppress next entry evaluation

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Refresh the cached LRC / EMA / ATR / pivot state from the last closed bars.
// Bespoke linear-regression math: no QM_* reader exists, so iClose/iLow are
// tagged perf-allowed and the whole function runs once per closed bar.
void ComputeChannelState()
  {
   g_state_ready = false;

   const int n = lrc_length;
   if(n < 10)
      return;

   // --- Least-squares linear regression of close over the last n closed bars.
   //     k = 0 maps to the oldest bar in the window (shift n), k = n-1 to the
   //     most recent closed bar (shift 1).
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const double price = iClose(_Symbol, _Period, n - k); // perf-allowed: bespoke LRC fit, gated once per closed bar
      const double x = (double)k;
      sx  += x;
      sy  += price;
      sxx += x * x;
      sxy += x * price;
     }
   const double denom = (double)n * sxx - sx * sx;
   if(MathAbs(denom) < 1e-12)
      return;
   const double slope     = ((double)n * sxy - sx * sy) / denom;
   const double intercept = (sy - slope * sx) / (double)n;

   double sse = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const double price = iClose(_Symbol, _Period, n - k); // perf-allowed: bespoke LRC residual, gated once per closed bar
      const double fit   = intercept + slope * (double)k;
      const double resid = price - fit;
      sse += resid * resid;
     }
   const double sd = MathSqrt(sse / (double)n);

   const double reg_end  = intercept + slope * (double)(n - 1); // regression value at shift 1
   const double reg_prev = intercept + slope * (double)(n - 2); // regression value at shift 2
   g_lrc_up        = reg_end  + lrc_dev * sd;
   g_lrc_lo        = reg_end  - lrc_dev * sd;
   g_lrc_lo_prev   = reg_prev - lrc_dev * sd;
   g_channel_width = g_lrc_up - g_lrc_lo;

   // --- Trend-filter EMA (pooled reader) + three-bar slope check.
   g_ema_now  = QM_EMA(_Symbol, _Period, ema_period, 1);
   g_ema_prev = QM_EMA(_Symbol, _Period, ema_period, 2);
   const double ema3 = QM_EMA(_Symbol, _Period, ema_period, 3);
   const double ema4 = QM_EMA(_Symbol, _Period, ema_period, 4);
   g_ema_slope_neg3 = (g_ema_now < g_ema_prev && g_ema_prev < ema3 && ema3 < ema4);

   // --- ATR (pooled reader) for stop distance and width filter.
   g_atr_now = QM_ATR(_Symbol, _Period, atr_len, 1);

   // --- Recent pivot support = lowest low over the pivot_lookback closed bars.
   double swing_low = DBL_MAX;
   const int pv = (pivot_lookback > 0) ? pivot_lookback : 1;
   for(int i = 1; i <= pv; ++i)
     {
      const double lo = iLow(_Symbol, _Period, i); // perf-allowed: bespoke pivot-support scan, gated once per closed bar
      if(lo > 0.0 && lo < swing_low)
         swing_low = lo;
     }
   g_pivot_support = (swing_low < DBL_MAX) ? swing_low : 0.0;

   if(g_atr_now > 0.0 && g_lrc_up > 0.0 && g_lrc_lo > 0.0)
      g_state_ready = true;
  }

// True if this EA already holds a position on this symbol/magic.
bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// Open time of our position (for the time-exit). Returns false if none.
bool GetOurPositionTime(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news). Time/news are enforced by the framework
// (Friday-close guard + 2-axis news filter). The spread guard needs the stop
// distance, so it is applied inside Strategy_EntrySignal. Cheap O(1) here.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry. Caller guarantees QM_IsNewBar() == true, so this is the single
// per-closed-bar refresh point for the cached channel state.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ComputeChannelState();
   if(!g_state_ready)
      return false;

   // One position per symbol/magic (single mean-reversion sleeve).
   if(HasOurPosition())
      return false;

   // Card: disable immediate re-entry after a trend-weakness exit without using
   // a per-EA timestamp gate. Entry is evaluated once per closed bar, so this
   // suppresses the next eligible entry evaluation after the exit.
   if(g_skip_next_entry_eval)
     {
      g_skip_next_entry_eval = false;
      return false;
     }

   // Filter: channel must be wide enough to be a real value zone.
   if(g_channel_width < width_atr_min * g_atr_now)
      return false;
   // Filter: skip if EMA slope negative for three consecutive bars.
   if(g_ema_slope_neg3)
      return false;
   // Trend bias: long only while the LRC upper channel sits above EMA.
   if(!(g_lrc_up > g_ema_now))
      return false;

   // Entry trigger: last closed bar's low touched/pierced the lower LRC band.
   const double low1 = iLow(_Symbol, _Period, 1); // perf-allowed: lower-band touch test, gated per closed bar
   if(low1 <= 0.0 || low1 > g_lrc_lo)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Stop = lower of recent pivot support and entry - atr_sl_mult * ATR.
   double sl = ask - atr_sl_mult * g_atr_now;
   if(g_pivot_support > 0.0 && g_pivot_support < sl)
      sl = g_pivot_support;
   if(sl <= 0.0 || sl >= ask)
      return false;

   // Target = LRC upper channel; must give room above the entry.
   const double tp = g_lrc_up;
   if(tp <= ask)
      return false;

   // V5 spread guard: skip if spread > spread_stop_frac of the stop distance.
   const double stop_dist = ask - sl;
   if(stop_dist <= 0.0 || (ask - bid) > spread_stop_frac * stop_dist)
      return false;

   req.type               = QM_BUY;
   req.price              = 0.0;   // market entry
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = "tv_qing_lrc_long";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management. Card defines no break-even / trailing / partial logic — the
// position runs to the LRC-upper TP, the structural stop, or an exit signal.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close. Discretionary exits separate from SL/TP: time exit after N bars,
// and the LRC-lower-crosses-below-EMA trend-weakness exit. Reads cached state
// only (O(1) per tick); must NOT call QM_IsNewBar() (would starve entry gate).
bool Strategy_ExitSignal()
  {
   datetime open_time;
   if(!GetOurPositionTime(open_time))
      return false;

   // Time exit: close after time_exit_bars closed bars without TP/SL.
   if(open_time > 0)
     {
      const int bars_held = iBarShift(_Symbol, _Period, open_time, false);
      if(bars_held >= time_exit_bars)
         return true;
     }

   // Trend-weakness exit: LRC lower channel crosses below EMA (cached state).
   if(g_state_ready && g_lrc_lo_prev >= g_ema_prev && g_lrc_lo < g_ema_now)
     {
      g_skip_next_entry_eval = true;
      return true;
     }

   return false;
  }

// News Filter Hook (callable for the P8 News Impact phase). Defer to the central
// 2-axis news filter (return false = no extra suppression beyond the framework).
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10857_tv_qing_lrc\"}");
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

   // Per-tick: trade management (no-op for this strategy).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (time stop + trend-weakness). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. This is the ONLY QM_IsNewBar()
   // consumer for the _Symbol|_Period key on the per-tick path.
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
