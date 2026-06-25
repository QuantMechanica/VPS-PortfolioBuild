#property strict
#property version   "5.0"
#property description "QM5_2080 Pring Special-K Major-Cycle H4"

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
input int    qm_ea_id                   = 2080;
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
input ENUM_TIMEFRAMES strategy_tf                = PERIOD_H4;
input int    strategy_major_window               = 100;
input int    strategy_separation_bars            = 60;
input int    strategy_atr_period                 = 20;
input double strategy_initial_stop_atr_mult      = 1.0;
input double strategy_trail_atr_mult             = 3.0;
input double strategy_trail_trigger_atr_mult     = 2.0;
input int    strategy_time_stop_bars             = 200;
input double strategy_spread_atr_mult            = 0.30;
input double strategy_min_sk_range               = 50.0;
input bool   strategy_d1_regime_filter_enabled   = false;
input int    strategy_d1_sma_period              = 100;

MqlRates g_rates[]; // perf-allowed: Special-K closed-bar ROC/min window, refreshed only from the framework QM_IsNewBar-gated entry hook.
double   g_sk_window[];
bool     g_cache_ready = false;
bool     g_trough_signal = false;
bool     g_peak_signal = false;
bool     g_zero_cross_up = false;
bool     g_zero_cross_down = false;
int      g_bars_since_major_extreme = 100000;

int Strategy_RocPeriod(const int idx)
  {
   switch(idx)
     {
      case 0:  return 10;
      case 1:  return 15;
      case 2:  return 20;
      case 3:  return 30;
      case 4:  return 40;
      case 5:  return 65;
      case 6:  return 75;
      case 7:  return 100;
      case 8:  return 195;
      case 9:  return 265;
      case 10: return 390;
      case 11: return 530;
     }
   return 0;
  }

int Strategy_SmaPeriod(const int idx)
  {
   switch(idx)
     {
      case 0:
      case 1:
      case 2:  return 10;
      case 3:  return 15;
      case 4:  return 50;
      case 5:  return 65;
      case 6:  return 75;
      case 7:  return 100;
      case 8:
      case 9:  return 130;
      case 10:
      case 11: return 195;
     }
   return 0;
  }

int Strategy_ComponentWeight(const int idx)
  {
   const int tier_pos = idx % 4;
   return tier_pos + 1;
  }

int Strategy_Sign(const double value)
  {
   if(value > 0.0)
      return 1;
   if(value < 0.0)
      return -1;
   return 0;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &pos_type, datetime &open_time)
  {
   pos_type = POSITION_TYPE_BUY;
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

double Strategy_RocAt(const int base_idx, const int roc_period)
  {
   const int prev_idx = base_idx + roc_period;
   if(base_idx < 0 || prev_idx >= ArraySize(g_rates))
      return 0.0;
   const double c_now = g_rates[base_idx].close;
   const double c_prev = g_rates[prev_idx].close;
   if(c_now <= 0.0 || c_prev <= 0.0)
      return 0.0;
   return (c_now / c_prev - 1.0) * 100.0;
  }

double Strategy_SmoothedRoc(const int base_idx, const int roc_period, const int sma_period)
  {
   if(roc_period <= 0 || sma_period <= 0)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < sma_period; ++i)
      sum += Strategy_RocAt(base_idx + i, roc_period);
   return sum / (double)sma_period;
  }

double Strategy_SpecialK(const int base_idx, double &sk_short_value, double &sk_long_value)
  {
   sk_short_value = 0.0;
   sk_long_value = 0.0;
   double sk_total = 0.0;

   for(int i = 0; i < 12; ++i)
     {
      const double term = (double)Strategy_ComponentWeight(i) *
                          Strategy_SmoothedRoc(base_idx, Strategy_RocPeriod(i), Strategy_SmaPeriod(i));
      sk_total += term;
      if(i <= 3)
         sk_short_value += term;
      if(i >= 8)
         sk_long_value += term;
     }
   return sk_total;
  }

bool Strategy_RefreshSpecialKCache()
  {
   g_cache_ready = false;
   g_trough_signal = false;
   g_peak_signal = false;
   g_zero_cross_up = false;
   g_zero_cross_down = false;

   if((ENUM_TIMEFRAMES)_Period != strategy_tf)
      return false;
   if(strategy_major_window < 10 || strategy_separation_bars < 1 ||
      strategy_atr_period < 1 || strategy_time_stop_bars < 1)
      return false;

   const int max_roc = 530;
   const int max_sma = 195;
   const int bars_needed = strategy_major_window + max_roc + max_sma;
   ArraySetAsSeries(g_rates, true);
   if(CopyRates(_Symbol, strategy_tf, 1, bars_needed, g_rates) < bars_needed) // perf-allowed: bounded Special-K ROC/SMA window, called once per H4 closed bar.
      return false;

   ArrayResize(g_sk_window, strategy_major_window);
   double sk_short_now = 0.0;
   double sk_long_now = 0.0;
   for(int i = 0; i < strategy_major_window; ++i)
     {
      double sk_short_tmp = 0.0;
      double sk_long_tmp = 0.0;
      g_sk_window[i] = Strategy_SpecialK(i, sk_short_tmp, sk_long_tmp);
      if(i == 0)
        {
         sk_short_now = sk_short_tmp;
         sk_long_now = sk_long_tmp;
        }
     }

   double sk_short_prev = 0.0;
   double sk_long_prev = 0.0;
   const double sk_now = g_sk_window[0];
   const double sk_prev = Strategy_SpecialK(1, sk_short_prev, sk_long_prev);

   double sk_min = DBL_MAX;
   double sk_max = -DBL_MAX;
   double price_min = DBL_MAX;
   double price_max = -DBL_MAX;
   for(int i = 0; i < strategy_major_window; ++i)
     {
      sk_min = MathMin(sk_min, g_sk_window[i]);
      sk_max = MathMax(sk_max, g_sk_window[i]);
      price_min = MathMin(price_min, g_rates[i].low);
      price_max = MathMax(price_max, g_rates[i].high);
     }

   const bool magnitude_ok = ((sk_max - sk_min) >= strategy_min_sk_range);
   const bool components_aligned = (Strategy_Sign(sk_short_now) == Strategy_Sign(sk_long_now));
   const bool separation_ok = (g_bars_since_major_extreme >= strategy_separation_bars);
   const bool bullish_bar = (g_rates[0].close > g_rates[0].open);
   const bool bearish_bar = (g_rates[0].close < g_rates[0].open);
   const double tol = MathMax(MathAbs(sk_now) * 0.0000001, 0.0000001);

   bool regime_long_ok = true;
   bool regime_short_ok = true;
   if(strategy_d1_regime_filter_enabled)
     {
      const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1, PRICE_CLOSE);
      if(d1_sma <= 0.0)
         return false;
      regime_long_ok = (g_rates[0].close > d1_sma);
      regime_short_ok = (g_rates[0].close < d1_sma);
     }

   g_zero_cross_up = (sk_prev < 0.0 && sk_now >= 0.0);
   g_zero_cross_down = (sk_prev > 0.0 && sk_now <= 0.0);

   g_trough_signal = magnitude_ok &&
                     components_aligned &&
                     separation_ok &&
                     (sk_now <= sk_min + tol) &&
                     (g_rates[0].low <= price_min) &&
                     ((sk_now - sk_prev) > 0.0) &&
                     bullish_bar &&
                     regime_long_ok;

   g_peak_signal = magnitude_ok &&
                   components_aligned &&
                   separation_ok &&
                   (sk_now >= sk_max - tol) &&
                   (g_rates[0].high >= price_max) &&
                   ((sk_now - sk_prev) < 0.0) &&
                   bearish_bar &&
                   regime_short_ok;

   if(g_trough_signal || g_peak_signal)
      g_bars_since_major_extreme = 0;
   else if(g_bars_since_major_extreme < 100000)
      g_bars_since_major_extreme++;

   g_cache_ready = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != strategy_tf)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask < bid)
      return true;
   if(ask == bid)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_spread_atr_mult <= 0.0)
      return false;
   return ((ask - bid) > strategy_spread_atr_mult * atr);
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

   if(!Strategy_RefreshSpecialKCache())
      return false;

   ENUM_POSITION_TYPE pos_type;
   datetime open_time;
   if(Strategy_SelectOurPosition(pos_type, open_time))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_trough_signal)
     {
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_rates[0].low - strategy_initial_stop_atr_mult * atr);
      req.tp = 0.0;
      req.reason = "SPECIAL_K_MAJOR_TROUGH_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(g_peak_signal)
     {
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, g_rates[0].high + strategy_initial_stop_atr_mult * atr);
      req.tp = 0.0;
      req.reason = "SPECIAL_K_MAJOR_PEAK_SHORT";
      return (req.sl > 0.0 && req.sl > bid);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(ptype == POSITION_TYPE_BUY && bid > 0.0 &&
         (bid - open_price) >= strategy_trail_trigger_atr_mult * atr)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
      if(ptype == POSITION_TYPE_SELL && ask > 0.0 &&
         (open_price - ask) >= strategy_trail_trigger_atr_mult * atr)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE pos_type;
   datetime open_time;
   if(!Strategy_SelectOurPosition(pos_type, open_time))
      return false;

   const int seconds = PeriodSeconds(strategy_tf);
   if(seconds > 0 && open_time > 0 && strategy_time_stop_bars > 0)
     {
      if(TimeCurrent() >= open_time + (long)strategy_time_stop_bars * seconds)
         return true;
     }

   if(!g_cache_ready)
      return false;

   if(pos_type == POSITION_TYPE_BUY && (g_peak_signal || g_zero_cross_down))
      return true;
   if(pos_type == POSITION_TYPE_SELL && (g_trough_signal || g_zero_cross_up))
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
