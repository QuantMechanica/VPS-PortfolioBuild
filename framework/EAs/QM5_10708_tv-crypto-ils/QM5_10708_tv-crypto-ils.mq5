#property strict
#property version   "5.0"
#property description "QM5_10708 TradingView Crypto Institutional Liquidity Sweep"

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
input int    qm_ea_id                   = 10708;
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
input int    strategy_ema_period             = 200;
input int    strategy_ema_buffer_points      = 0;
input int    strategy_pivot_length           = 5;
input int    strategy_pivot_lookback_bars    = 80;
input int    strategy_linreg_period          = 20;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;
input double strategy_rr_target              = 2.0;
input double strategy_max_stop_atr_mult      = 3.5;
input double strategy_max_spread_stop_frac   = 0.15;
input double strategy_reversal_close_frac    = 0.40;
input int    strategy_time_stop_bars         = 48;

double LinearRegressionSlope(const MqlRates &rates[], const int period)
  {
   if(period < 2 || ArraySize(rates) < period)
      return 0.0;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;
   double sum_x2 = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double x = (double)i;
      const double y = rates[period - 1 - i].close;
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_x2 += x * x;
     }

   const double n = (double)period;
   const double denom = n * sum_x2 - sum_x * sum_x;
   if(MathAbs(denom) <= DBL_EPSILON)
      return 0.0;
   return (n * sum_xy - sum_x * sum_y) / denom;
  }

bool FindRecentPivot(const MqlRates &rates[], const int pivot_len, const bool want_high, double &level)
  {
   level = 0.0;
   const int total = ArraySize(rates);
   if(pivot_len < 1 || total < (pivot_len * 2 + 3))
      return false;

   const int first_candidate = pivot_len + 1;
   const int last_candidate = MathMin(total - pivot_len - 1, strategy_pivot_lookback_bars);
   for(int s = first_candidate; s <= last_candidate; ++s)
     {
      const double candidate = want_high ? rates[s].high : rates[s].low;
      if(candidate <= 0.0)
         continue;

      bool is_pivot = true;
      for(int k = 1; k <= pivot_len; ++k)
        {
         if(want_high)
           {
            if(rates[s - k].high >= candidate || rates[s + k].high > candidate)
              {
               is_pivot = false;
               break;
              }
           }
         else
           {
            if(rates[s - k].low <= candidate || rates[s + k].low < candidate)
              {
               is_pivot = false;
               break;
              }
           }
        }

      if(is_pivot)
        {
         level = candidate;
         return true;
        }
     }
   return false;
  }

bool BullishReversalCandle(const MqlRates &bar)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0 || bar.close <= bar.open)
      return false;
   return (bar.close >= bar.high - range * strategy_reversal_close_frac);
  }

bool BearishReversalCandle(const MqlRates &bar)
  {
   const double range = bar.high - bar.low;
   if(range <= 0.0 || bar.close >= bar.open)
      return false;
   return (bar.close <= bar.low + range * strategy_reversal_close_frac);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No card-specific time filter. Spread is evaluated with the ATR stop inside EntrySignal.
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

   if(strategy_ema_period < 2 ||
      strategy_pivot_length < 1 ||
      strategy_pivot_lookback_bars < (strategy_pivot_length * 2 + 3) ||
      strategy_linreg_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_rr_target <= 0.0 ||
      strategy_max_stop_atr_mult <= 0.0 ||
      strategy_max_spread_stop_frac <= 0.0 ||
      strategy_reversal_close_frac <= 0.0 ||
      strategy_reversal_close_frac >= 1.0)
      return false;

   const int bars_needed = MathMax(strategy_pivot_lookback_bars + strategy_pivot_length + 2,
                                   MathMax(strategy_linreg_period, strategy_ema_period) + 2);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, bars_needed, rates); // perf-allowed: one bounded structural OHLC read inside closed-bar EntrySignal.
   if(copied < bars_needed)
      return false;

   const MqlRates signal_bar = rates[0];
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || signal_bar.close <= 0.0)
      return false;

   const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(ema <= 0.0 || atr <= 0.0)
      return false;

   const double ema_buffer = point * (double)MathMax(0, strategy_ema_buffer_points);
   const bool long_bias = (signal_bar.close > ema + ema_buffer);
   const bool short_bias = (signal_bar.close < ema - ema_buffer);
   if(!long_bias && !short_bias)
      return false;

   const double slope = LinearRegressionSlope(rates, strategy_linreg_period);
   const bool slope_long = (slope > 0.0);
   const bool slope_short = (slope < 0.0);

   double pivot_low = 0.0;
   double pivot_high = 0.0;
   const bool have_pivot_low = FindRecentPivot(rates, strategy_pivot_length, false, pivot_low);
   const bool have_pivot_high = FindRecentPivot(rates, strategy_pivot_length, true, pivot_high);

   const double stop_distance = atr * strategy_atr_sl_mult;
   if(stop_distance <= 0.0 || stop_distance > atr * strategy_max_stop_atr_mult)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   if((ask - bid) > stop_distance * strategy_max_spread_stop_frac)
      return false;

   if(long_bias && slope_long && have_pivot_low &&
      signal_bar.low < pivot_low &&
      signal_bar.close > pivot_low &&
      BullishReversalCandle(signal_bar))
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, atr, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr_target);
      req.reason = "TV_CRYPTO_ILS_LONG_SWEEP_RECLAIM";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(short_bias && slope_short && have_pivot_high &&
      signal_bar.high > pivot_high &&
      signal_bar.close < pivot_high &&
      BearishReversalCandle(signal_bar))
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, atr, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr_target);
      req.reason = "TV_CRYPTO_ILS_SHORT_SWEEP_RECLAIM";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no break-even, trailing, partial, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds_per_bar <= 0)
      return false;

   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= strategy_time_stop_bars * seconds_per_bar)
         return true;
     }
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
