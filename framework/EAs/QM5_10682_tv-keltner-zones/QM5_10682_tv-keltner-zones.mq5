#property strict
#property version   "5.0"
#property description "QM5_10682 TradingView Keltner Zone Mean Reversion"

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
input int    qm_ea_id                   = 10682;
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
input int    strategy_keltner_period       = 20;
input double strategy_keltner_atr_mult     = 1.5;
input double strategy_inner_band_atr_mult  = 0.75;
input int    strategy_smi_period           = 14;
input double strategy_smi_threshold        = 40.0;
input int    strategy_rvol_period          = 20;
input double strategy_rvol_min             = 1.10;
input int    strategy_zone_lookback        = 24;
input double strategy_zone_impulse_atr_min = 0.80;
input double strategy_zone_base_atr_max    = 0.55;
input double strategy_stop_pct             = 0.008;
input double strategy_stop_atr_min         = 1.0;
input double strategy_stop_atr_cap         = 2.5;

double Strategy_Price(const ENUM_APPLIED_PRICE price, const int shift)
  {
   return QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, shift, price);
  }

double Strategy_Close(const int shift) { return Strategy_Price(PRICE_CLOSE, shift); }
double Strategy_Open(const int shift)  { return Strategy_Price(PRICE_OPEN, shift);  }
double Strategy_High(const int shift)  { return Strategy_Price(PRICE_HIGH, shift);  }
double Strategy_Low(const int shift)   { return Strategy_Price(PRICE_LOW, shift);   }

double Strategy_KeltnerMid(const int shift)
  {
   return QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, shift, PRICE_TYPICAL);
  }

double Strategy_ATR(const int shift)
  {
   return QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, shift);
  }

double Strategy_SMIProxy(const int shift)
  {
   if(strategy_smi_period < 2)
      return 0.0;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = shift; i < shift + strategy_smi_period; ++i)
     {
      const double h = Strategy_High(i);
      const double l = Strategy_Low(i);
      if(h <= 0.0 || l <= 0.0)
         return 0.0;
      if(h > highest)
         highest = h;
      if(l < lowest)
         lowest = l;
     }

   const double close = Strategy_Close(shift);
   const double half_range = (highest - lowest) * 0.5;
   if(close <= 0.0 || half_range <= 0.0)
      return 0.0;

   const double midpoint = (highest + lowest) * 0.5;
   return 100.0 * (close - midpoint) / half_range;
  }

double Strategy_RVOL(const int shift)
  {
   if(strategy_rvol_period < 2)
      return 0.0;

   const long last_vol = iVolume(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bounded RVOL proxy; framework has no tick-volume reader.
   if(last_vol <= 0)
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int i = shift + 1; i <= shift + strategy_rvol_period; ++i)
     {
      const long v = iVolume(_Symbol, (ENUM_TIMEFRAMES)_Period, i); // perf-allowed: bounded RVOL proxy; called only after framework new-bar gate.
      if(v <= 0)
         continue;
      sum += (double)v;
      samples++;
     }

   if(samples <= 0 || sum <= 0.0)
      return 0.0;
   return (double)last_vol / (sum / (double)samples);
  }

bool Strategy_BullImpulse(const int shift, const double atr)
  {
   const double o = Strategy_Open(shift);
   const double c = Strategy_Close(shift);
   const double h = Strategy_High(shift);
   const double l = Strategy_Low(shift);
   return (o > 0.0 && c > o && h > l && (h - l) >= atr * strategy_zone_impulse_atr_min);
  }

bool Strategy_BearImpulse(const int shift, const double atr)
  {
   const double o = Strategy_Open(shift);
   const double c = Strategy_Close(shift);
   const double h = Strategy_High(shift);
   const double l = Strategy_Low(shift);
   return (o > 0.0 && c < o && h > l && (h - l) >= atr * strategy_zone_impulse_atr_min);
  }

bool Strategy_BaseCandle(const int shift, const double atr, double &zone_low, double &zone_high)
  {
   zone_low = Strategy_Low(shift);
   zone_high = Strategy_High(shift);
   return (zone_low > 0.0 && zone_high > zone_low && (zone_high - zone_low) <= atr * strategy_zone_base_atr_max);
  }

bool Strategy_DemandZoneTouch()
  {
   const double close = Strategy_Close(1);
   const double low = Strategy_Low(1);
   if(close <= 0.0 || low <= 0.0)
      return false;

   const int limit = (strategy_zone_lookback > 3) ? strategy_zone_lookback : 3;
   for(int s = 1; s <= limit; ++s)
     {
      const double atr = Strategy_ATR(s + 1);
      if(atr <= 0.0)
         continue;

      double zone_low = 0.0;
      double zone_high = 0.0;
      if(!Strategy_BullImpulse(s + 2, atr))
         continue;
      if(!Strategy_BaseCandle(s + 1, atr, zone_low, zone_high))
         continue;
      if(!Strategy_BullImpulse(s, atr))
         continue;

      if(low <= zone_high && close >= zone_low)
         return true;
     }
   return false;
  }

bool Strategy_SupplyZoneTouch()
  {
   const double close = Strategy_Close(1);
   const double high = Strategy_High(1);
   if(close <= 0.0 || high <= 0.0)
      return false;

   const int limit = (strategy_zone_lookback > 3) ? strategy_zone_lookback : 3;
   for(int s = 1; s <= limit; ++s)
     {
      const double atr = Strategy_ATR(s + 1);
      if(atr <= 0.0)
         continue;

      double zone_low = 0.0;
      double zone_high = 0.0;
      if(!Strategy_BearImpulse(s + 2, atr))
         continue;
      if(!Strategy_BaseCandle(s + 1, atr, zone_low, zone_high))
         continue;
      if(!Strategy_BearImpulse(s, atr))
         continue;

      if(high >= zone_low && close <= zone_high)
         return true;
     }
   return false;
  }

double Strategy_StopDistance(const double entry, const double atr)
  {
   if(entry <= 0.0 || atr <= 0.0)
      return 0.0;
   const double min_dist = atr * strategy_stop_atr_min;
   const double percent_dist = entry * strategy_stop_pct;
   const double cap_dist = atr * strategy_stop_atr_cap;
   return MathMin(MathMax(min_dist, percent_dist), cap_dist);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
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

   if(strategy_keltner_period < 2 ||
      strategy_keltner_atr_mult <= 0.0 ||
      strategy_inner_band_atr_mult <= 0.0 ||
      strategy_rvol_min <= 0.0)
      return false;

   const double close = Strategy_Close(1);
   const double mid = Strategy_KeltnerMid(1);
   const double atr = Strategy_ATR(1);
   if(close <= 0.0 || mid <= 0.0 || atr <= 0.0)
      return false;

   const double upper = mid + atr * strategy_keltner_atr_mult;
   const double lower = mid - atr * strategy_keltner_atr_mult;
   const double inner_upper = mid + atr * strategy_inner_band_atr_mult;
   const double inner_lower = mid - atr * strategy_inner_band_atr_mult;
   const double smi = Strategy_SMIProxy(1);
   const double smi_prev = Strategy_SMIProxy(2);
   const double rvol = Strategy_RVOL(1);
   if(rvol < strategy_rvol_min)
      return false;

   if(close <= lower &&
      smi <= -strategy_smi_threshold &&
      smi > smi_prev &&
      Strategy_DemandZoneTouch())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double stop_dist = Strategy_StopDistance(entry, atr);
      if(entry <= 0.0 || stop_dist <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(entry - stop_dist, _Digits);
      req.tp = NormalizeDouble(MathMax(mid, inner_upper), _Digits);
      req.reason = "KELTNER_ZONE_LONG";
      return (req.sl > 0.0 && req.tp > entry);
     }

   if(close >= upper &&
      smi >= strategy_smi_threshold &&
      smi < smi_prev &&
      Strategy_SupplyZoneTouch())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double stop_dist = Strategy_StopDistance(entry, atr);
      if(entry <= 0.0 || stop_dist <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(entry + stop_dist, _Digits);
      req.tp = NormalizeDouble(MathMin(mid, inner_lower), _Digits);
      req.reason = "KELTNER_ZONE_SHORT";
      return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // P2 card disables partial close, runner logic, break-even, and trailing.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Full exit occurs at the broker TP/SL levels and framework Friday close.
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
