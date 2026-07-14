#property strict
#property version   "5.0"
#property description "QM5_1229 carver-statevol - Rob Carver state-of-vol percentile rule"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1229 carver-statevol
// -----------------------------------------------------------------------------
// Source: Rob Carver, "The State Of Vol" (qoppac.blogspot.com/2023/10).
// Standalone volatility-state factor. Trades the SIGN of a backward-looking
// volatility percentile rather than price momentum:
//   - low relative volatility  -> SHORT forecast
//   - high relative volatility -> LONG forecast
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_1229_carver-statevol.md
//
// Rework (2026-07-14): prior build was REJECT_REWORK'd twice by Codex review
// for (a) a file-scope g_statevol_last_bar_time timestamp gate duplicating
// QM_IsNewBar(), and (b) 0 trades on the EURUSD.DWX 2024 smoke. Root cause of
// (b): the old code required BOTH a >=500-sample volatility baseline AND a
// SEPARATE >=500-sample prior-history count for the percentile rank before a
// forecast could ever be produced -- an unintended ~1000+ bar compounding of
// the card's single "500 prior D1 bars" filter, which a one-year smoke window
// can never accumulate incrementally. This rework replaces the per-bar full
// CopyRates rebuild with a ONE-TIME history backfill (gated by g_lazy_init_done,
// a plain "have I run setup" flag -- not a bar-time gate) so warmup completes
// immediately from existing history, then advances incrementally one bar at a
// time via the pooled QM_ReadBar reader.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1229;
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
input int    strategy_vol_lookback       = 25;    // StdDev(daily % returns) window
input int    strategy_long_vol_baseline  = 2500;   // ten-year vol baseline (growing-window SMA cap)
input int    strategy_smooth             = 10;     // EMA period for raw_forecast smoothing
input double strategy_entry_threshold    = 5.0;    // |forecast| > threshold to enter
input int    strategy_atr_period         = 20;     // emergency-stop ATR period
input double strategy_atr_stop_mult      = 2.5;    // emergency-stop ATR multiple (P3: 2.0/2.5/3.0)
input int    strategy_min_warmup_bars    = 500;    // min D1 daily_vol samples before trading (card filter)

// -----------------------------------------------------------------------------
// Strategy state — cached across closed D1 bars. The framework calls
// Strategy_EntrySignal exactly once per closed bar (it runs AFTER the single
// QM_IsNewBar() consumption already wired into OnTick below), so all state
// advances from inside that hook rather than adding a second IsNewBar/bar-time
// consumer.
// -----------------------------------------------------------------------------

#define QM_1229_MAX_HIST   20000
#define QM_1229_SPREAD_WIN 20

double g_daily_vol_hist[QM_1229_MAX_HIST];
double g_norm_vol_hist[QM_1229_MAX_HIST];
int    g_hist_count      = 0;   // count of daily_vol observations recorded
int    g_norm_count      = 0;   // count of normalised_vol observations recorded

double g_forecast_ema      = 0.0;
bool   g_forecast_ema_init = false;
double g_forecast_current  = 0.0;

bool   g_lazy_init_done    = false; // one-time historical backfill latch (NOT a bar-time gate)

double g_spread_hist[QM_1229_SPREAD_WIN];
int    g_spread_hist_count = 0;   // total updates seen (may exceed window; ring index = %WIN)
double g_spread_cap_points = 0.0; // 0.0 = not enough history yet -> fail-open (never blocks)

// Records one daily_vol observation: updates the ten_year_vol growing-window
// baseline, the normalised_vol percentile rank, and the smoothed forecast EMA.
// Shared by the one-time backfill replay and the live per-bar path so both
// converge on identical state-update logic.
void ProcessDailyVolSample(const double daily_vol)
  {
   if(g_hist_count >= QM_1229_MAX_HIST)
      return;

   g_daily_vol_hist[g_hist_count] = daily_vol;

   // ten_year_vol = SMA(daily_vol, strategy_long_vol_baseline), using a
   // growing window while fewer than strategy_long_vol_baseline samples exist
   // (card: "prefer 2500 bars for P2"; converges to the literal SMA(2500)
   // once full history accumulates via backfill + live advance).
   const int window = MathMin(g_hist_count + 1, strategy_long_vol_baseline);
   double vsum = 0.0;
   for(int k = 0; k < window; ++k)
      vsum += g_daily_vol_hist[g_hist_count - k];
   const double ten_year_vol = vsum / window;

   g_hist_count++;

   if(ten_year_vol <= 0.0)
      return; // degenerate (zero historical vol) — skip forecast update this sample

   const double normalised_vol = daily_vol / ten_year_vol;

   if(g_norm_count >= QM_1229_MAX_HIST)
      return;

   // vol_quantile = percentile_rank(normalised_vol vs ALL prior normalised_vol
   // values) — single card-specified threshold, no secondary minimum-count
   // gate (that compounding was the old code's zero-trades root cause).
   int le_count = 0;
   for(int k = 0; k < g_norm_count; ++k)
      if(g_norm_vol_hist[k] <= normalised_vol)
         le_count++;
   g_norm_vol_hist[g_norm_count] = normalised_vol;
   g_norm_count++;
   const double vol_quantile = (double)(le_count + 1) / (double)g_norm_count;

   const double raw_forecast = (vol_quantile - 0.5) * 40.0;

   if(!g_forecast_ema_init)
     {
      g_forecast_ema      = raw_forecast;
      g_forecast_ema_init = true;
     }
   else
     {
      const double alpha = 2.0 / (strategy_smooth + 1.0);
      g_forecast_ema = alpha * raw_forecast + (1.0 - alpha) * g_forecast_ema;
     }

   double capped = g_forecast_ema;
   if(capped > 20.0)
      capped = 20.0;
   if(capped < -20.0)
      capped = -20.0;

   g_forecast_current = capped;
  }

// daily_vol = StdDev(daily % returns, lookback) ending at closes[end_idx].
// closes[] must be oldest-first; requires end_idx >= lookback.
double ComputeDailyVol(const double &closes[], const int end_idx, const int lookback)
  {
   double rets[];
   ArrayResize(rets, lookback);
   double sum = 0.0;
   for(int j = 0; j < lookback; ++j)
     {
      const int hi = end_idx - lookback + 1 + j;
      const int lo = hi - 1;
      if(closes[lo] <= 0.0 || closes[hi] <= 0.0)
         return 0.0;
      rets[j] = (closes[hi] - closes[lo]) / closes[lo];
      sum += rets[j];
     }
   const double mean = sum / lookback;
   double sq = 0.0;
   for(int j = 0; j < lookback; ++j)
     {
      const double d = rets[j] - mean;
      sq += d * d;
     }
   return MathSqrt(sq / (lookback - 1));
  }

// One-time historical backfill so entries become eligible from existing
// history instead of waiting strategy_min_warmup_bars real elapsed bars.
// Gated by g_lazy_init_done (a plain latch, not a bar-time/IsNewBar
// reimplementation) and called only from Strategy_EntrySignal, which the
// framework itself invokes at most once per closed bar. The bulk CopyRates
// call runs exactly once ever — the sanctioned "custom bar arrays" pattern
// (Performance Discipline: call CopyRates once, gated, cache into file-scope
// state) — not a per-tick or per-bar warmup rebuild.
void LazyBackfillHistory()
  {
   if(g_lazy_init_done)
      return;
   g_lazy_init_done = true;

   const int lookback = strategy_vol_lookback;
   if(lookback < 2)
      return;

   const int want_closes = strategy_long_vol_baseline + lookback + 1;

   MqlRates rates[];
   ArraySetAsSeries(rates, false); // oldest-first, deterministic indexing
   // shift=2 leaves "today" (shift=1) for the live AdvanceState_OnNewBar()
   // path that runs immediately after this in the same EntrySignal call, so
   // the most recent closed bar is never double-counted.
   const int copied = CopyRates(_Symbol, PERIOD_D1, 2, want_closes, rates); // perf-allowed: one-time backfill, gated by g_lazy_init_done above (runs exactly once ever, not per-tick/per-bar)
   if(copied < lookback + 1)
      return; // not enough history to backfill — live path builds up incrementally

   double closes[];
   ArrayResize(closes, copied);
   for(int i = 0; i < copied; ++i)
      closes[i] = rates[i].close;

   for(int i = lookback; i < copied; ++i)
     {
      const double daily_vol = ComputeDailyVol(closes, i, lookback);
      if(daily_vol > 0.0)
         ProcessDailyVolSample(daily_vol);
     }
  }

// Live per-bar advance: reads the last (lookback+1) closes via the pooled
// QM_ReadBar reader (no raw iClose calls) and records one new daily_vol
// sample. Runs the one-time backfill first (no-op after the first call).
void AdvanceState_OnNewBar()
  {
   LazyBackfillHistory();

   const int lookback = strategy_vol_lookback;
   if(lookback < 2)
      return;

   double closes[];
   ArrayResize(closes, lookback + 1);
   for(int i = 0; i <= lookback; ++i)
     {
      MqlRates bar;
      if(!QM_ReadBar(_Symbol, PERIOD_D1, i + 1, bar))
         return; // not enough history yet — retry next bar
      closes[lookback - i] = bar.close; // reindex to oldest-first
     }

   const double daily_vol = ComputeDailyVol(closes, lookback, lookback);
   if(daily_vol > 0.0)
      ProcessDailyVolSample(daily_vol);

   UpdateSpreadCap();
  }

// Maintains a rolling 20-observation spread history (one sample per closed D1
// bar) and caches 2*median as the entry spread cap. Per the .DWX backtest
// invariant, spread reads 0 in the tester, so this cap is 0 in backtest and
// the ">" comparison in Strategy_NoTradeFilter never fires there — it only
// bites with real broker spreads live. Fails OPEN (cap=0.0 => no block) until
// at least one observation exists.
void UpdateSpreadCap()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return;
   const double spread_pts = (ask - bid) / point;

   g_spread_hist[g_spread_hist_count % QM_1229_SPREAD_WIN] = spread_pts;
   g_spread_hist_count++;

   const int n = MathMin(g_spread_hist_count, QM_1229_SPREAD_WIN);
   double sorted[];
   ArrayResize(sorted, n);
   for(int i = 0; i < n; ++i)
      sorted[i] = g_spread_hist[i];
   ArraySort(sorted); // template single-array overload — ascending only
   const double median = (n % 2 == 1) ? sorted[n / 2]
                                       : (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0;
   g_spread_cap_points = 2.0 * median;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true; // no valid quote

   // Card filter: skip new entries when spread exceeds 2*MedianSpread(20D).
   // g_spread_cap_points stays 0.0 until UpdateSpreadCap has run at least
   // once, so this never fail-closes on the zero-spread .DWX tester default.
   if(g_spread_cap_points > 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point > 0.0)
        {
         const double spread_pts = (ask - bid) / point;
         if(spread_pts > g_spread_cap_points)
            return true;
        }
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   AdvanceState_OnNewBar();

   if(g_hist_count < strategy_min_warmup_bars)
      return false; // card filter: require >=500 prior D1 bars

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false; // one position per symbol/magic

   const double f = g_forecast_current;

   if(f > strategy_entry_threshold)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_stop_mult);
      req.tp                 = 0.0;
      req.reason              = "carver_statevol_long";
      req.symbol_slot         = 0;
      req.expiration_seconds  = 0;
      return true;
     }

   if(f < -strategy_entry_threshold)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = QM_StopATR(_Symbol, QM_SELL, entry_price, strategy_atr_period, strategy_atr_stop_mult);
      req.tp                 = 0.0;
      req.reason              = "carver_statevol_short";
      req.symbol_slot         = 0;
      req.expiration_seconds  = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card carries no trailing/break-even rule — emergency ATR stop only.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
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
      if(ptype == POSITION_TYPE_BUY && g_forecast_current <= 0.0)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_forecast_current >= 0.0)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
