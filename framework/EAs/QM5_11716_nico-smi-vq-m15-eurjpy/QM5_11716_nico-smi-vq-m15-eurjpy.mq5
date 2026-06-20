#property strict
#property version   "5.0"
#property description "QM5_11716 Nico SMI VQ M15 EURJPY"

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
input int    qm_ea_id                   = 11716;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    smi_hl_period              = 14;
input int    smi_smooth1                = 10;
input int    smi_smooth2                = 14;
input double smi_extreme                = 40.0;
input int    stoch_k_period             = 10;
input int    stoch_d_period             = 1;
input int    stoch_slowing              = 7;
input int    ema_fast_period            = 5;
input int    ema_slow_period            = 6;
input int    vq_length                  = 5;
input int    vq_smoothing               = 3;
input double vq_filter_threshold        = 0.0;
input int    atr_period                 = 14;
input double sl_atr_mult                = 2.0;
input int    take_profit_pips           = 35;
input int    session_start_gmt_hour     = 7;
input int    max_spread_pips            = 8;

double PriceRangeAverage(MqlRates &rates[], const int shift, const int lookback)
  {
   if(lookback <= 0)
      return 0.0;
   double total = 0.0;
   int samples = 0;
   const int count = ArraySize(rates);
   for(int i = shift; i < shift + lookback && i < count; ++i)
     {
      const double range = rates[i].high - rates[i].low;
      if(range > 0.0)
        {
         total += range;
         samples++;
        }
     }
   if(samples <= 0)
      return 0.0;
   return total / samples;
  }

bool ReadSmiValues(MqlRates &rates[], double &smi_now, double &smi_prev)
  {
   smi_now = 0.0;
   smi_prev = 0.0;
   const int count = ArraySize(rates);
   if(smi_hl_period < 2 || smi_smooth1 < 1 || smi_smooth2 < 1 || count < smi_hl_period + 4)
      return false;

   const int first_shift = count - smi_hl_period - 1;
   if(first_shift < 2)
      return false;

   const double a1 = 2.0 / (smi_smooth1 + 1.0);
   const double a2 = 2.0 / (smi_smooth2 + 1.0);
   double ema1_num = 0.0;
   double ema2_num = 0.0;
   double ema1_den = 0.0;
   double ema2_den = 0.0;
   bool seeded = false;
   bool have_now = false;
   bool have_prev = false;

   for(int shift = first_shift; shift >= 1; --shift)
     {
      double highest = -DBL_MAX;
      double lowest = DBL_MAX;
      for(int j = shift; j < shift + smi_hl_period; ++j)
        {
         if(rates[j].high > highest)
            highest = rates[j].high;
         if(rates[j].low < lowest)
            lowest = rates[j].low;
        }
      if(highest <= lowest)
         continue;

      const double midpoint = 0.5 * (highest + lowest);
      const double rel = rates[shift].close - midpoint;
      const double range = highest - lowest;

      if(!seeded)
        {
         ema1_num = rel;
         ema2_num = rel;
         ema1_den = range;
         ema2_den = range;
         seeded = true;
        }
      else
        {
         ema1_num = ema1_num + a1 * (rel - ema1_num);
         ema1_den = ema1_den + a1 * (range - ema1_den);
         ema2_num = ema2_num + a2 * (ema1_num - ema2_num);
         ema2_den = ema2_den + a2 * (ema1_den - ema2_den);
        }

      double smi = 0.0;
      const double half_den = 0.5 * ema2_den;
      if(half_den > 0.0)
         smi = 100.0 * ema2_num / half_den;

      if(shift == 2)
        {
         smi_prev = smi;
         have_prev = true;
        }
      if(shift == 1)
        {
         smi_now = smi;
         have_now = true;
        }
     }

   return (seeded && have_now && have_prev);
  }

bool ReadHeikenAshiNow(MqlRates &rates[], double &ha_open, double &ha_close)
  {
   ha_open = 0.0;
   ha_close = 0.0;
   const int count = ArraySize(rates);
   if(count < 4)
      return false;

   double prev_ha_open = 0.0;
   double prev_ha_close = 0.0;
   bool seeded = false;
   for(int shift = count - 1; shift >= 1; --shift)
     {
      const double current_close = 0.25 * (rates[shift].open + rates[shift].high + rates[shift].low + rates[shift].close);
      double current_open = 0.0;
      if(!seeded)
        {
         current_open = 0.5 * (rates[shift].open + rates[shift].close);
         seeded = true;
        }
      else
         current_open = 0.5 * (prev_ha_open + prev_ha_close);

      prev_ha_open = current_open;
      prev_ha_close = current_close;

      if(shift == 1)
        {
         ha_open = current_open;
         ha_close = current_close;
         return true;
        }
     }

   return false;
  }

bool ReadVqValues(MqlRates &rates[], double &vq_now, double &vq_prev)
  {
   vq_now = 0.0;
   vq_prev = 0.0;
   const int count = ArraySize(rates);
   if(vq_length < 1 || vq_smoothing < 1 || count < vq_length + 5)
      return false;

   const int first_shift = count - vq_length - 2;
   if(first_shift < 2)
      return false;

   const double alpha = 2.0 / (vq_smoothing + 1.0);
   double smooth = 0.0;
   bool seeded = false;
   bool have_now = false;
   bool have_prev = false;

   for(int shift = first_shift; shift >= 1; --shift)
     {
      const double avg_range = PriceRangeAverage(rates, shift, vq_length);
      if(avg_range <= 0.0)
         continue;
      const double raw = (rates[shift].close - rates[shift + 1].close) / avg_range;
      if(!seeded)
        {
         smooth = raw;
         seeded = true;
        }
      else
         smooth = smooth + alpha * (raw - smooth);

      if(shift == 2)
        {
         vq_prev = smooth;
         have_prev = true;
        }
      if(shift == 1)
        {
         vq_now = smooth;
         have_now = true;
        }
     }

   return (seeded && have_now && have_prev);
  }

bool StochLongCrossWithin3()
  {
   for(int shift = 1; shift <= 3; ++shift)
     {
      const double k_now = QM_Stoch_K(_Symbol, _Period, stoch_k_period, stoch_d_period, stoch_slowing, shift);
      const double k_prev = QM_Stoch_K(_Symbol, _Period, stoch_k_period, stoch_d_period, stoch_slowing, shift + 1);
      if(k_prev < 20.0 && k_now > 20.0)
         return true;
     }
   return false;
  }

bool StochShortCrossWithin3()
  {
   for(int shift = 1; shift <= 3; ++shift)
     {
      const double k_now = QM_Stoch_K(_Symbol, _Period, stoch_k_period, stoch_d_period, stoch_slowing, shift);
      const double k_prev = QM_Stoch_K(_Symbol, _Period, stoch_k_period, stoch_d_period, stoch_slowing, shift + 1);
      if(k_prev > 80.0 && k_now < 80.0)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime utc;
   TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc);
   if(utc.hour < session_start_gmt_hour)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, max_spread_pips);
      if(max_spread > 0.0 && (ask - bid) > max_spread)
         return true;
     }

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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   int bars_needed = smi_hl_period + smi_smooth1 * 4 + smi_smooth2 * 4 + vq_length + 10;
   if(bars_needed < 80)
      bars_needed = 80;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: Strategy_EntrySignal is called only after the framework
   // QM_IsNewBar gate; SMI/VQ/Heiken-Ashi require one bounded custom OHLC read.
   const int copied = CopyRates(_Symbol, _Period, 0, bars_needed, rates);
   if(copied < bars_needed / 2)
      return false;

   double smi_now = 0.0;
   double smi_prev = 0.0;
   if(!ReadSmiValues(rates, smi_now, smi_prev))
      return false;

   double ha_open = 0.0;
   double ha_close = 0.0;
   if(!ReadHeikenAshiNow(rates, ha_open, ha_close))
      return false;

   double vq_now = 0.0;
   double vq_prev = 0.0;
   if(!ReadVqValues(rates, vq_now, vq_prev))
      return false;

   const double ema_fast_now = QM_EMA(_Symbol, _Period, ema_fast_period, 1);
   const double ema_slow_now = QM_EMA(_Symbol, _Period, ema_slow_period, 1);
   const double ema_fast_prev = QM_EMA(_Symbol, _Period, ema_fast_period, 2);
   const double ema_slow_prev = QM_EMA(_Symbol, _Period, ema_slow_period, 2);
   const double atr_value = QM_ATR(_Symbol, _Period, atr_period, 1);
   if(ema_fast_now <= 0.0 || ema_slow_now <= 0.0 || ema_fast_prev <= 0.0 || ema_slow_prev <= 0.0 || atr_value <= 0.0)
      return false;

   const bool ema_cross_up = (ema_fast_prev <= ema_slow_prev && ema_fast_now > ema_slow_now);
   const bool ema_cross_down = (ema_fast_prev >= ema_slow_prev && ema_fast_now < ema_slow_now);
   const bool ha_white = (ha_close > ha_open);
   const bool ha_red = (ha_close < ha_open);
   const bool vq_up = (vq_now > vq_prev && MathAbs(vq_now) >= vq_filter_threshold);
   const bool vq_down = (vq_now < vq_prev && MathAbs(vq_now) >= vq_filter_threshold);

   const bool smi_long = ((smi_prev < -smi_extreme && smi_now > smi_prev) ||
                          (smi_prev <= 0.0 && smi_now > smi_prev && smi_now > -20.0));
   if(smi_long && ema_cross_up && ha_white && vq_up && StochLongCrossWithin3())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, sl_atr_mult);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, take_profit_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "smi_vq_ha_stoch_long";
      return true;
     }

   const bool smi_short = (smi_prev > smi_extreme && smi_now < smi_prev);
   if(smi_short && ema_cross_down && ha_red && vq_down && StochShortCrossWithin3())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, sl_atr_mult);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, take_profit_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "smi_vq_ha_stoch_short";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, break-even, partial close, or scale-in rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Factory implementation uses the card's fixed 35-pip TP plus 2xATR SL.
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
