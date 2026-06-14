#property strict
#property version   "5.0"
#property description "QM5_10885 Risk.net carry-to-vol FX monthly rebalance"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10885;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_vol_lookback          = 63;
input int    strategy_median_lookback       = 252;
input int    strategy_basket_size           = 5;
input double strategy_vol_shock_mult        = 2.5;
input int    strategy_atr_period            = 20;
input double strategy_atr_stop_mult         = 2.25;
input double strategy_high_vol_risk_factor  = 0.5;
input int    strategy_rebalance_window_days = 7;

#define QM5_10885_SYMBOLS 7

string g_qm5_10885_symbols[QM5_10885_SYMBOLS] =
  {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "AUDUSD.DWX",
   "USDCAD.DWX",
   "USDCHF.DWX",
   "NZDUSD.DWX"
  };

double g_qm5_10885_score[QM5_10885_SYMBOLS];
int    g_qm5_10885_direction[QM5_10885_SYMBOLS];
bool   g_qm5_10885_selected[QM5_10885_SYMBOLS];
bool   g_qm5_10885_vol_above_median[QM5_10885_SYMBOLS];
bool   g_qm5_10885_vol_shock[QM5_10885_SYMBOLS];
int    g_qm5_10885_cached_day_key = 0;
bool   g_qm5_10885_state_ready = false;
int    g_qm5_10885_last_rebalance_month = 0;

int QM5_10885_SymbolIndex(const string symbol)
  {
   for(int i = 0; i < QM5_10885_SYMBOLS; ++i)
      if(g_qm5_10885_symbols[i] == symbol)
         return i;
   return -1;
  }

int QM5_10885_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int QM5_10885_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool QM5_10885_IsRebalanceWindow(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day >= 1 && dt.day <= strategy_rebalance_window_days);
  }

bool QM5_10885_LoadClosedCloses(const string symbol, const int count, double &closes[])
  {
   if(count <= 1)
      return false;
   ArrayResize(closes, count);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_D1, 1, count, closes); // perf-allowed: bounded D1 carry/volatility window, cached once per broker day.
   return (copied == count);
  }

double QM5_10885_WindowLogVol(const double &closes[], const int start, const int lookback)
  {
   if(lookback < 2 || start < 0 || start + lookback >= ArraySize(closes))
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int i = start; i < start + lookback; ++i)
     {
      const double c0 = closes[i];
      const double c1 = closes[i + 1];
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      sum += MathLog(c0 / c1);
      samples++;
     }
   if(samples < 2)
      return 0.0;

   const double mean = sum / samples;
   double var_sum = 0.0;
   for(int i = start; i < start + lookback; ++i)
     {
      const double r = MathLog(closes[i] / closes[i + 1]);
      const double d = r - mean;
      var_sum += d * d;
     }

   const double variance = var_sum / (samples - 1);
   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance) * MathSqrt(252.0);
  }

double QM5_10885_Median(double &values[], const int n)
  {
   if(n <= 0)
      return 0.0;
   ArrayResize(values, n);
   ArraySort(values);
   const int mid = n / 2;
   if((n % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

bool QM5_10885_VolStats(const string symbol,
                        double &current_vol,
                        double &median_vol)
  {
   current_vol = 0.0;
   median_vol = 0.0;

   const int vol_lookback = MathMax(2, strategy_vol_lookback);
   const int median_lookback = MathMax(1, strategy_median_lookback);
   const int close_count = vol_lookback + median_lookback + 1;
   double closes[];
   if(!QM5_10885_LoadClosedCloses(symbol, close_count, closes))
      return false;

   current_vol = QM5_10885_WindowLogVol(closes, 0, vol_lookback);
   if(current_vol <= 0.0)
      return false;

   double vols[];
   ArrayResize(vols, median_lookback);
   int n = 0;
   for(int start = 0; start < median_lookback; ++start)
     {
      const double v = QM5_10885_WindowLogVol(closes, start, vol_lookback);
      if(v > 0.0)
        {
         vols[n] = v;
         n++;
        }
     }
   if(n <= 0)
      return false;

   median_vol = QM5_10885_Median(vols, n);
   return (median_vol > 0.0);
  }

double QM5_10885_AnnualCarryAfterSpread(const string symbol, const int direction)
  {
   const double swap_value = (direction > 0)
                             ? SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG)
                             : SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(swap_value <= 0.0 || spread_points < 0)
      return 0.0;

   const double annualized_swap_points = swap_value * 252.0;
   const double after_spread = annualized_swap_points - (double)spread_points;
   return (after_spread > 0.0) ? after_spread : 0.0;
  }

void QM5_10885_ResetState()
  {
   for(int i = 0; i < QM5_10885_SYMBOLS; ++i)
     {
      g_qm5_10885_score[i] = 0.0;
      g_qm5_10885_direction[i] = 0;
      g_qm5_10885_selected[i] = false;
      g_qm5_10885_vol_above_median[i] = false;
      g_qm5_10885_vol_shock[i] = false;
     }
  }

bool QM5_10885_RefreshState()
  {
   const datetime now = TimeCurrent();
   const int day_key = QM5_10885_DayKey(now);
   if(g_qm5_10885_state_ready && g_qm5_10885_cached_day_key == day_key)
      return true;

   QM5_10885_ResetState();
   for(int i = 0; i < QM5_10885_SYMBOLS; ++i)
     {
      const string symbol = g_qm5_10885_symbols[i];
      double vol = 0.0;
      double median_vol = 0.0;
      if(!QM5_10885_VolStats(symbol, vol, median_vol))
         continue;

      const double long_carry = QM5_10885_AnnualCarryAfterSpread(symbol, +1);
      const double short_carry = QM5_10885_AnnualCarryAfterSpread(symbol, -1);
      int direction = 0;
      double carry = 0.0;
      if(long_carry > short_carry && long_carry > 0.0)
        {
         direction = +1;
         carry = long_carry;
        }
      else if(short_carry > 0.0)
        {
         direction = -1;
         carry = short_carry;
        }

      if(direction == 0 || carry <= 0.0 || vol <= 0.0)
         continue;

      g_qm5_10885_direction[i] = direction;
      g_qm5_10885_score[i] = carry / vol;
      g_qm5_10885_vol_above_median[i] = (vol > median_vol);
      g_qm5_10885_vol_shock[i] = (vol > strategy_vol_shock_mult * median_vol);
     }

   const int max_selected = MathMin(MathMax(1, strategy_basket_size), QM5_10885_SYMBOLS);
   for(int rank = 0; rank < max_selected; ++rank)
     {
      int best = -1;
      double best_score = 0.0;
      for(int i = 0; i < QM5_10885_SYMBOLS; ++i)
        {
         if(g_qm5_10885_selected[i])
            continue;
         if(g_qm5_10885_score[i] > best_score)
           {
            best_score = g_qm5_10885_score[i];
            best = i;
           }
        }
      if(best < 0 || best_score <= 0.0)
         break;
      g_qm5_10885_selected[best] = true;
     }

   g_qm5_10885_cached_day_key = day_key;
   g_qm5_10885_state_ready = true;
   return true;
  }

bool QM5_10885_CurrentPositionDirection(int &direction)
  {
   direction = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (type == POSITION_TYPE_BUY) ? +1 : -1;
      return true;
     }
   return false;
  }

void QM5_10885_ApplyRiskCap(const bool high_vol)
  {
   double factor = high_vol ? strategy_high_vol_risk_factor : 1.0;
   if(factor <= 0.0 || factor > 1.0)
      factor = 1.0;
   const double effective_weight = PORTFOLIO_WEIGHT * factor;
   const QM_RiskMode mode = (RISK_FIXED > 0.0) ? QM_RISK_MODE_FIXED : QM_RISK_MODE_PERCENT;
   QM_RiskSizerConfigure(mode, RISK_PERCENT, RISK_FIXED, effective_weight);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   return (QM5_10885_SymbolIndex(_Symbol) < 0);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!QM5_10885_RefreshState())
      return false;

   const datetime now = TimeCurrent();
   const int month_key = QM5_10885_MonthKey(now);
   if(g_qm5_10885_last_rebalance_month == month_key || !QM5_10885_IsRebalanceWindow(now))
      return false;

   const int idx = QM5_10885_SymbolIndex(_Symbol);
   if(idx < 0)
      return false;

   int open_direction = 0;
   if(QM5_10885_CurrentPositionDirection(open_direction))
     {
      if(g_qm5_10885_selected[idx] && open_direction == g_qm5_10885_direction[idx])
         g_qm5_10885_last_rebalance_month = month_key;
      return false;
     }

   g_qm5_10885_last_rebalance_month = month_key;
   if(!g_qm5_10885_selected[idx] || g_qm5_10885_direction[idx] == 0 || g_qm5_10885_vol_shock[idx])
      return false;

   req.type = (g_qm5_10885_direction[idx] > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   const double entry = (req.type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = (req.type == QM_BUY) ? "carry_vol_monthly_buy" : "carry_vol_monthly_sell";
   QM5_10885_ApplyRiskCap(g_qm5_10885_vol_above_median[idx]);
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even adjustment.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int idx = QM5_10885_SymbolIndex(_Symbol);
   if(idx < 0 || !QM5_10885_RefreshState())
      return false;

   int open_direction = 0;
   if(!QM5_10885_CurrentPositionDirection(open_direction))
      return false;

   if(g_qm5_10885_vol_shock[idx])
      return true;

   const datetime now = TimeCurrent();
   const int month_key = QM5_10885_MonthKey(now);
   if(g_qm5_10885_last_rebalance_month == month_key || !QM5_10885_IsRebalanceWindow(now))
      return false;

   if(!g_qm5_10885_selected[idx])
      return true;
   if(open_direction != g_qm5_10885_direction[idx])
      return true;
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
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
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
