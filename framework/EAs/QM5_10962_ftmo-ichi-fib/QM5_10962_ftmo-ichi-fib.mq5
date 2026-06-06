#property strict
#property version   "5.0"
#property description "QM5_10962 FTMO Ichimoku Fibonacci pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// -----------------------------------------------------------------------------
// Strategy Card: QM5_10962_ftmo-ichi-fib, G0 APPROVED 2026-05-22.
// The framework boilerplate stays intact; only strategy inputs, helpers, and the
// five Strategy_* hooks below are card-specific.
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
input int    qm_ea_id                   = 10962;
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
input int    strategy_atr_period              = 14;
input int    strategy_ichimoku_tenkan         = 9;
input int    strategy_ichimoku_kijun          = 26;
input int    strategy_ichimoku_senkou_b       = 52;
input int    strategy_d1_swing_bars           = 20;
input int    strategy_d1_search_bars          = 100;
input int    strategy_retrace_swing_h1_bars   = 20;
input double strategy_min_impulse_atr_mult    = 2.0;
input double strategy_min_cloud_atr_mult      = 0.5;
input double strategy_fib_retrace_min         = 0.382;
input double strategy_fib_retrace_max         = 0.618;
input int    strategy_rsi_period              = 14;
input double strategy_rsi_long_min            = 30.0;
input double strategy_rsi_long_max            = 50.0;
input double strategy_rsi_short_min           = 50.0;
input double strategy_rsi_short_max           = 70.0;
input int    strategy_rsi_cross_lookback_bars = 3;
input double strategy_sl_atr_buffer_mult      = 0.25;
input double strategy_min_stop_atr_h1_mult    = 0.5;
input double strategy_max_stop_atr_d1_mult    = 2.5;
input double strategy_take_profit_r           = 2.0;
input double strategy_extension_level         = 1.618;
input double strategy_extension_max_r         = 3.5;
input int    strategy_time_exit_h1_bars       = 72;

struct Strategy_Impulse
  {
   bool   valid;
   double low;
   double high;
   int    low_index;
   int    high_index;
  };

bool Strategy_CopyRates(const ENUM_TIMEFRAMES tf, const int start_shift, const int count, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, start_shift, count, rates); // perf-allowed: bounded closed-bar structural read; caller is framework QM_IsNewBar-gated.
   return (copied >= count);
  }

double Strategy_HighestHigh(const MqlRates &rates[], const int start, const int count)
  {
   double value = 0.0;
   const int total = ArraySize(rates);
   for(int i = start; i < start + count && i < total; ++i)
     {
      if(rates[i].high <= 0.0)
         continue;
      if(value <= 0.0 || rates[i].high > value)
         value = rates[i].high;
     }
   return value;
  }

double Strategy_LowestLow(const MqlRates &rates[], const int start, const int count)
  {
   double value = 0.0;
   const int total = ArraySize(rates);
   for(int i = start; i < start + count && i < total; ++i)
     {
      if(rates[i].low <= 0.0)
         continue;
      if(value <= 0.0 || rates[i].low < value)
         value = rates[i].low;
     }
   return value;
  }

bool Strategy_CloudBounds(const MqlRates &rates[],
                          const int shift,
                          double &upper,
                          double &lower)
  {
   upper = 0.0;
   lower = 0.0;
   const int total = ArraySize(rates);
   const int tenkan = MathMax(1, strategy_ichimoku_tenkan);
   const int kijun = MathMax(1, strategy_ichimoku_kijun);
   const int senkou_b = MathMax(1, strategy_ichimoku_senkou_b);
   if(shift < 0 || shift + senkou_b > total)
      return false;

   const double tenkan_high = Strategy_HighestHigh(rates, shift, tenkan);
   const double tenkan_low = Strategy_LowestLow(rates, shift, tenkan);
   const double kijun_high = Strategy_HighestHigh(rates, shift, kijun);
   const double kijun_low = Strategy_LowestLow(rates, shift, kijun);
   const double span_b_high = Strategy_HighestHigh(rates, shift, senkou_b);
   const double span_b_low = Strategy_LowestLow(rates, shift, senkou_b);
   if(tenkan_high <= 0.0 || tenkan_low <= 0.0 ||
      kijun_high <= 0.0 || kijun_low <= 0.0 ||
      span_b_high <= 0.0 || span_b_low <= 0.0)
      return false;

   const double tenkan_mid = (tenkan_high + tenkan_low) * 0.5;
   const double kijun_mid = (kijun_high + kijun_low) * 0.5;
   const double span_a = (tenkan_mid + kijun_mid) * 0.5;
   const double span_b = (span_b_high + span_b_low) * 0.5;
   upper = MathMax(span_a, span_b);
   lower = MathMin(span_a, span_b);
   return (upper > lower && lower > 0.0);
  }

bool Strategy_IsSwingHigh(const MqlRates &rates[], const int idx, const int radius)
  {
   const int total = ArraySize(rates);
   if(idx - radius < 0 || idx + radius >= total || rates[idx].high <= 0.0)
      return false;
   for(int i = idx - radius; i <= idx + radius; ++i)
     {
      if(i == idx)
         continue;
      if(rates[i].high > rates[idx].high)
         return false;
     }
   return true;
  }

bool Strategy_IsSwingLow(const MqlRates &rates[], const int idx, const int radius)
  {
   const int total = ArraySize(rates);
   if(idx - radius < 0 || idx + radius >= total || rates[idx].low <= 0.0)
      return false;
   for(int i = idx - radius; i <= idx + radius; ++i)
     {
      if(i == idx)
         continue;
      if(rates[i].low < rates[idx].low)
         return false;
     }
   return true;
  }

bool Strategy_FindLongImpulse(const MqlRates &d1_rates[], Strategy_Impulse &impulse)
  {
   impulse.valid = false;
   impulse.low = 0.0;
   impulse.high = 0.0;
   impulse.low_index = -1;
   impulse.high_index = -1;

   const int total = ArraySize(d1_rates);
   const int radius = MathMax(1, strategy_d1_swing_bars);
   const int max_idx = MathMin(total - radius - 1, MathMax(radius, strategy_d1_search_bars));
   for(int high_idx = radius; high_idx <= max_idx; ++high_idx)
     {
      if(!Strategy_IsSwingHigh(d1_rates, high_idx, radius))
         continue;
      for(int low_idx = high_idx + 1; low_idx <= max_idx; ++low_idx)
        {
         if(!Strategy_IsSwingLow(d1_rates, low_idx, radius))
            continue;
         impulse.valid = (d1_rates[high_idx].high > d1_rates[low_idx].low);
         impulse.low = d1_rates[low_idx].low;
         impulse.high = d1_rates[high_idx].high;
         impulse.low_index = low_idx;
         impulse.high_index = high_idx;
         return impulse.valid;
        }
     }
   return false;
  }

bool Strategy_FindShortImpulse(const MqlRates &d1_rates[], Strategy_Impulse &impulse)
  {
   impulse.valid = false;
   impulse.low = 0.0;
   impulse.high = 0.0;
   impulse.low_index = -1;
   impulse.high_index = -1;

   const int total = ArraySize(d1_rates);
   const int radius = MathMax(1, strategy_d1_swing_bars);
   const int max_idx = MathMin(total - radius - 1, MathMax(radius, strategy_d1_search_bars));
   for(int low_idx = radius; low_idx <= max_idx; ++low_idx)
     {
      if(!Strategy_IsSwingLow(d1_rates, low_idx, radius))
         continue;
      for(int high_idx = low_idx + 1; high_idx <= max_idx; ++high_idx)
        {
         if(!Strategy_IsSwingHigh(d1_rates, high_idx, radius))
            continue;
         impulse.valid = (d1_rates[high_idx].high > d1_rates[low_idx].low);
         impulse.low = d1_rates[low_idx].low;
         impulse.high = d1_rates[high_idx].high;
         impulse.low_index = low_idx;
         impulse.high_index = high_idx;
         return impulse.valid;
        }
     }
   return false;
  }

bool Strategy_PriceInZone(const double price, const double zone_low, const double zone_high)
  {
   if(price <= 0.0 || zone_low <= 0.0 || zone_high <= 0.0)
      return false;
   return (price >= MathMin(zone_low, zone_high) && price <= MathMax(zone_low, zone_high));
  }

bool Strategy_RsiCrossedUpWithin(const double level, const int bars)
  {
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double now = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift);
      const double prev = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift + 1);
      if(now > level && prev <= level && prev > 0.0)
         return true;
     }
   return false;
  }

bool Strategy_RsiCrossedDownWithin(const double level, const int bars)
  {
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double now = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift);
      const double prev = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, shift + 1);
      if(now < level && now > 0.0 && prev >= level)
         return true;
     }
   return false;
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
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
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;
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

   if(strategy_atr_period <= 0 ||
      strategy_ichimoku_tenkan <= 0 ||
      strategy_ichimoku_kijun <= 0 ||
      strategy_ichimoku_senkou_b <= 0 ||
      strategy_d1_swing_bars <= 0 ||
      strategy_d1_search_bars <= strategy_d1_swing_bars ||
      strategy_retrace_swing_h1_bars <= 0 ||
      strategy_min_impulse_atr_mult <= 0.0 ||
      strategy_min_cloud_atr_mult <= 0.0 ||
      strategy_fib_retrace_min <= 0.0 ||
      strategy_fib_retrace_max <= strategy_fib_retrace_min ||
      strategy_rsi_period <= 0 ||
      strategy_rsi_cross_lookback_bars <= 0 ||
      strategy_sl_atr_buffer_mult < 0.0 ||
      strategy_min_stop_atr_h1_mult <= 0.0 ||
      strategy_max_stop_atr_d1_mult <= 0.0 ||
      strategy_take_profit_r <= 0.0 ||
      strategy_extension_level <= 1.0 ||
      strategy_extension_max_r <= strategy_take_profit_r)
      return false;

   const int d1_need = MathMax(strategy_d1_search_bars + strategy_d1_swing_bars + 2,
                               strategy_ichimoku_senkou_b + 2);
   const int h1_need = MathMax(strategy_retrace_swing_h1_bars + 2,
                               strategy_ichimoku_senkou_b + 2);

   MqlRates d1[];
   MqlRates h1[];
   if(!Strategy_CopyRates(PERIOD_D1, 1, d1_need, d1))
      return false;
   if(!Strategy_CopyRates(PERIOD_H1, 1, h1_need, h1))
      return false;

   double d1_cloud_upper = 0.0;
   double d1_cloud_lower = 0.0;
   double h1_cloud_upper = 0.0;
   double h1_cloud_lower = 0.0;
   if(!Strategy_CloudBounds(d1, 0, d1_cloud_upper, d1_cloud_lower))
      return false;
   if(!Strategy_CloudBounds(h1, 0, h1_cloud_upper, h1_cloud_lower))
      return false;

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_d1 <= 0.0 || atr_h1 <= 0.0)
      return false;

   if((d1_cloud_upper - d1_cloud_lower) < strategy_min_cloud_atr_mult * atr_d1)
      return false;

   const double h1_close = h1[0].close;
   const double d1_close = d1[0].close;
   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   if(h1_close <= 0.0 || d1_close <= 0.0 || rsi <= 0.0)
      return false;

   Strategy_Impulse long_impulse;
   Strategy_Impulse short_impulse;
   const bool have_long_impulse = Strategy_FindLongImpulse(d1, long_impulse);
   const bool have_short_impulse = Strategy_FindShortImpulse(d1, short_impulse);

   bool long_signal = false;
   bool short_signal = false;
   double long_sl = 0.0;
   double short_sl = 0.0;
   double long_tp = 0.0;
   double short_tp = 0.0;

   if(have_long_impulse)
     {
      const double impulse_range = long_impulse.high - long_impulse.low;
      const double zone_low = long_impulse.high - impulse_range * strategy_fib_retrace_max;
      const double zone_high = long_impulse.high - impulse_range * strategy_fib_retrace_min;
      const bool rsi_ok = (rsi >= strategy_rsi_long_min && rsi <= strategy_rsi_long_max) ||
                          Strategy_RsiCrossedUpWithin(strategy_rsi_long_min, strategy_rsi_cross_lookback_bars);

      if(impulse_range >= strategy_min_impulse_atr_mult * atr_d1 &&
         d1_close > d1_cloud_upper &&
         h1_close > h1_cloud_upper &&
         Strategy_PriceInZone(h1_close, zone_low, zone_high) &&
         rsi_ok)
        {
         const double entry = QM_EntryMarketPrice(QM_BUY);
         const double retrace_low = Strategy_LowestLow(h1, 0, strategy_retrace_swing_h1_bars);
         const double raw_sl = MathMin(retrace_low, h1_cloud_lower) - strategy_sl_atr_buffer_mult * atr_h1;
         const double stop_distance = entry - raw_sl;
         if(entry > 0.0 &&
            raw_sl > 0.0 &&
            stop_distance >= strategy_min_stop_atr_h1_mult * atr_h1 &&
            stop_distance <= strategy_max_stop_atr_d1_mult * atr_d1)
           {
            long_sl = NormalizeDouble(raw_sl, _Digits);
            long_tp = QM_TakeRR(_Symbol, QM_BUY, entry, long_sl, strategy_take_profit_r);
            const double extension_tp = long_impulse.low + impulse_range * strategy_extension_level;
            const double extension_r = (extension_tp - entry) / stop_distance;
            if(extension_tp > entry && extension_r > strategy_take_profit_r && extension_r <= strategy_extension_max_r)
               long_tp = NormalizeDouble(extension_tp, _Digits);
            long_signal = (long_sl > 0.0 && long_tp > 0.0);
           }
        }
     }

   if(have_short_impulse)
     {
      const double impulse_range = short_impulse.high - short_impulse.low;
      const double zone_low = short_impulse.low + impulse_range * strategy_fib_retrace_min;
      const double zone_high = short_impulse.low + impulse_range * strategy_fib_retrace_max;
      const bool rsi_ok = (rsi >= strategy_rsi_short_min && rsi <= strategy_rsi_short_max) ||
                          Strategy_RsiCrossedDownWithin(strategy_rsi_short_max, strategy_rsi_cross_lookback_bars);

      if(impulse_range >= strategy_min_impulse_atr_mult * atr_d1 &&
         d1_close < d1_cloud_lower &&
         h1_close < h1_cloud_lower &&
         Strategy_PriceInZone(h1_close, zone_low, zone_high) &&
         rsi_ok)
        {
         const double entry = QM_EntryMarketPrice(QM_SELL);
         const double retrace_high = Strategy_HighestHigh(h1, 0, strategy_retrace_swing_h1_bars);
         const double raw_sl = MathMax(retrace_high, h1_cloud_upper) + strategy_sl_atr_buffer_mult * atr_h1;
         const double stop_distance = raw_sl - entry;
         if(entry > 0.0 &&
            raw_sl > 0.0 &&
            stop_distance >= strategy_min_stop_atr_h1_mult * atr_h1 &&
            stop_distance <= strategy_max_stop_atr_d1_mult * atr_d1)
           {
            short_sl = NormalizeDouble(raw_sl, _Digits);
            short_tp = QM_TakeRR(_Symbol, QM_SELL, entry, short_sl, strategy_take_profit_r);
            const double extension_tp = short_impulse.high - impulse_range * strategy_extension_level;
            const double extension_r = (entry - extension_tp) / stop_distance;
            if(extension_tp > 0.0 && extension_tp < entry && extension_r > strategy_take_profit_r && extension_r <= strategy_extension_max_r)
               short_tp = NormalizeDouble(extension_tp, _Digits);
            short_signal = (short_sl > 0.0 && short_tp > 0.0);
           }
        }
     }

   if(long_signal == short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = long_signal ? long_sl : short_sl;
   req.tp = long_signal ? long_tp : short_tp;
   req.reason = long_signal ? "FTMO_ICHI_FIB_LONG" : "FTMO_ICHI_FIB_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_GetOurPosition(ptype, open_time))
      return false;

   if(strategy_time_exit_h1_bars > 0 && open_time > 0)
     {
      const int hold_seconds = PeriodSeconds(PERIOD_H1) * strategy_time_exit_h1_bars;
      if(hold_seconds > 0 && (TimeCurrent() - open_time) >= hold_seconds)
         return true;
     }

   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   if(ptype == POSITION_TYPE_BUY && rsi >= strategy_rsi_short_max)
      return true;
   if(ptype == POSITION_TYPE_SELL && rsi > 0.0 && rsi <= strategy_rsi_long_min)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10962_ftmo-ichi-fib\"}");
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
