#property strict
#property version   "5.0"
#property description "QM5_10961 FTMO CHOP Keltner TSI Momentum"

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
input int    qm_ea_id                   = 10961;
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
input int    strategy_chop_period              = 14;
input double strategy_chop_trend_threshold     = 38.1;
input double strategy_chop_consolidation_level = 61.8;
input int    strategy_chop_lookback_bars       = 10;
input int    strategy_keltner_ema_period       = 20;
input int    strategy_keltner_atr_period       = 20;
input double strategy_keltner_atr_mult         = 2.0;
input int    strategy_tsi_fast_period          = 25;
input int    strategy_tsi_slow_period          = 13;
input int    strategy_tsi_signal_period        = 13;
input int    strategy_tsi_zero_cross_bars      = 3;
input double strategy_sl_atr_mult              = 1.5;
input double strategy_tp_r_multiple            = 2.0;
input int    strategy_max_hold_bars            = 48;
input int    strategy_atr_percentile_lookback  = 8760;
input double strategy_atr_percentile_min       = 30.0;
input double strategy_max_spread_stop_fraction = 0.10;

bool     g_state_ready          = false;
bool     g_state_entry_long     = false;
bool     g_state_entry_short    = false;
bool     g_state_exit_long      = false;
bool     g_state_exit_short     = false;
datetime g_state_bar_time       = 0;
double   g_state_close          = 0.0;
double   g_state_kc_middle      = 0.0;
double   g_state_atr            = 0.0;

bool Strategy_HasOurPosition()
  {
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

double Strategy_EMA(const double value, const double previous, const int period)
  {
   const double alpha = 2.0 / ((double)period + 1.0);
   return alpha * value + (1.0 - alpha) * previous;
  }

double Strategy_TrueRange(const MqlRates &rates[], const int shift)
  {
   if(shift < 0 || shift + 1 >= ArraySize(rates))
      return 0.0;

   const double high_low = rates[shift].high - rates[shift].low;
   const double high_close = MathAbs(rates[shift].high - rates[shift + 1].close);
   const double low_close = MathAbs(rates[shift].low - rates[shift + 1].close);
   return MathMax(high_low, MathMax(high_close, low_close));
  }

double Strategy_Chop(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 1 || shift < 0 || shift + period >= ArraySize(rates))
      return 0.0;

   double tr_sum = 0.0;
   double highest = -DBL_MAX;
   double lowest = DBL_MAX;

   for(int i = shift; i < shift + period; ++i)
     {
      tr_sum += Strategy_TrueRange(rates, i);
      highest = MathMax(highest, rates[i].high);
      lowest = MathMin(lowest, rates[i].low);
     }

   const double range = highest - lowest;
   if(tr_sum <= 0.0 || range <= 0.0)
      return 0.0;

   return 100.0 * MathLog(tr_sum / range) / MathLog((double)period);
  }

double Strategy_TSIValue(const MqlRates &rates[], const int shift)
  {
   const int warmup = MathMax(150, (strategy_tsi_fast_period + strategy_tsi_slow_period) * 4);
   int oldest = shift + warmup;
   if(oldest + 1 >= ArraySize(rates))
      oldest = ArraySize(rates) - 2;
   if(oldest <= shift)
      return 0.0;

   double mom = rates[oldest].close - rates[oldest + 1].close;
   double ema_mom_1 = mom;
   double ema_abs_1 = MathAbs(mom);
   double ema_mom_2 = ema_mom_1;
   double ema_abs_2 = ema_abs_1;

   for(int i = oldest - 1; i >= shift; --i)
     {
      mom = rates[i].close - rates[i + 1].close;
      ema_mom_1 = Strategy_EMA(mom, ema_mom_1, strategy_tsi_fast_period);
      ema_abs_1 = Strategy_EMA(MathAbs(mom), ema_abs_1, strategy_tsi_fast_period);
      ema_mom_2 = Strategy_EMA(ema_mom_1, ema_mom_2, strategy_tsi_slow_period);
      ema_abs_2 = Strategy_EMA(ema_abs_1, ema_abs_2, strategy_tsi_slow_period);
     }

   if(ema_abs_2 <= 0.0)
      return 0.0;
   return 100.0 * ema_mom_2 / ema_abs_2;
  }

bool Strategy_TSIAndSignal(const MqlRates &rates[], const int shift, double &tsi, double &signal)
  {
   tsi = 0.0;
   signal = 0.0;
   if(strategy_tsi_signal_period <= 0 || shift + strategy_tsi_signal_period + 2 >= ArraySize(rates))
      return false;

   const int signal_warmup = MathMax(40, strategy_tsi_signal_period * 4);
   int oldest = shift + signal_warmup;
   if(oldest >= ArraySize(rates) - 2)
      oldest = ArraySize(rates) - 3;
   if(oldest <= shift)
      return false;

   signal = Strategy_TSIValue(rates, oldest);
   for(int i = oldest - 1; i >= shift; --i)
     {
      const double tsi_i = Strategy_TSIValue(rates, i);
      signal = Strategy_EMA(tsi_i, signal, strategy_tsi_signal_period);
      if(i == shift)
         tsi = tsi_i;
     }

   return true;
  }

bool Strategy_TSIZeroCross(const MqlRates &rates[], const bool want_long)
  {
   const int max_shift = MathMax(1, strategy_tsi_zero_cross_bars);
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const double now = Strategy_TSIValue(rates, shift);
      const double prev = Strategy_TSIValue(rates, shift + 1);
      if(want_long && now > 0.0 && prev <= 0.0)
         return true;
      if(!want_long && now < 0.0 && prev >= 0.0)
         return true;
     }

   return false;
  }

bool Strategy_ATRPercentileAllows(const MqlRates &rates[], const double current_atr)
  {
   if(strategy_atr_percentile_lookback <= 0 || strategy_atr_percentile_min <= 0.0)
      return true;
   if(current_atr <= 0.0)
      return false;

   const int max_shift = MathMin(strategy_atr_percentile_lookback,
                                 ArraySize(rates) - strategy_keltner_atr_period - 2);
   if(max_shift < MathMax(100, strategy_keltner_atr_period * 3))
      return false;

   double values[];
   ArrayResize(values, max_shift);
   int count = 0;

   for(int shift = 1; shift <= max_shift; ++shift)
     {
      double sum = 0.0;
      int samples = 0;
      for(int j = shift; j < shift + strategy_keltner_atr_period; ++j)
        {
         const double tr = Strategy_TrueRange(rates, j);
         if(tr <= 0.0)
            continue;
         sum += tr;
         ++samples;
        }

      if(samples == strategy_keltner_atr_period && sum > 0.0)
        {
         values[count] = sum / (double)samples;
         ++count;
        }
     }

   if(count < 100)
      return false;

   ArrayResize(values, count);
   ArraySort(values);
   int idx = (int)MathFloor((strategy_atr_percentile_min / 100.0) * (double)(count - 1));
   idx = MathMax(0, MathMin(count - 1, idx));
   return (current_atr >= values[idx]);
  }

void Strategy_UpdateClosedBarState()
  {
   g_state_ready = false;
   g_state_entry_long = false;
   g_state_entry_short = false;
   g_state_exit_long = false;
   g_state_exit_short = false;

   const int required = MathMax(strategy_atr_percentile_lookback + strategy_keltner_atr_period + 5,
                                MathMax(240, strategy_chop_period + strategy_chop_lookback_bars + 20));
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, required, rates); // perf-allowed: called only from Strategy_EntrySignal after framework QM_IsNewBar gate.
   if(copied < MathMin(required, 240))
      return;

   g_state_bar_time = rates[1].time;
   g_state_close = rates[1].close;
   g_state_atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_keltner_atr_period, 1);
   g_state_kc_middle = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_keltner_ema_period, 1, PRICE_CLOSE);
   const double kc_upper = g_state_kc_middle + strategy_keltner_atr_mult * g_state_atr;
   const double kc_lower = g_state_kc_middle - strategy_keltner_atr_mult * g_state_atr;
   const double kc_middle_prev = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_keltner_ema_period, 2, PRICE_CLOSE);
   const double atr_prev = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_keltner_atr_period, 2);
   const double kc_upper_prev = kc_middle_prev + strategy_keltner_atr_mult * atr_prev;
   const double kc_lower_prev = kc_middle_prev - strategy_keltner_atr_mult * atr_prev;

   if(g_state_atr <= 0.0 || g_state_kc_middle <= 0.0)
      return;
   if(!Strategy_ATRPercentileAllows(rates, g_state_atr))
      return;

   const double chop_now = Strategy_Chop(rates, 1, strategy_chop_period);
   bool had_consolidation = false;
   for(int shift = 2; shift <= strategy_chop_lookback_bars + 1; ++shift)
     {
      if(Strategy_Chop(rates, shift, strategy_chop_period) > strategy_chop_consolidation_level)
        {
         had_consolidation = true;
         break;
        }
     }

   const bool market_valid = (chop_now > 0.0 && chop_now < strategy_chop_trend_threshold) ||
                             (had_consolidation && chop_now > 0.0 && chop_now < strategy_chop_consolidation_level);
   if(!market_valid)
      return;

   const bool breaks_upper = (rates[1].close > kc_upper && rates[2].close <= kc_upper_prev);
   const bool breaks_lower = (rates[1].close < kc_lower && rates[2].close >= kc_lower_prev);
   g_state_entry_long = breaks_upper && Strategy_TSIZeroCross(rates, true);
   g_state_entry_short = breaks_lower && Strategy_TSIZeroCross(rates, false);

   double tsi_1 = 0.0;
   double sig_1 = 0.0;
   double tsi_2 = 0.0;
   double sig_2 = 0.0;
   if(Strategy_TSIAndSignal(rates, 1, tsi_1, sig_1) &&
      Strategy_TSIAndSignal(rates, 2, tsi_2, sig_2))
     {
      g_state_exit_long = (tsi_1 < sig_1 && tsi_2 >= sig_2);
      g_state_exit_short = (tsi_1 > sig_1 && tsi_2 <= sig_2);
     }

   g_state_ready = true;
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

   Strategy_UpdateClosedBarState();
   if(!g_state_ready || Strategy_HasOurPosition())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   double entry = ask;
   if(g_state_entry_long)
     {
      side = QM_BUY;
      entry = ask;
     }
   else if(g_state_entry_short)
     {
      side = QM_SELL;
      entry = bid;
     }
   else
      return false;

   const double middle_distance = QM_OrderTypeIsBuy(side)
                                  ? MathMax(0.0, entry - g_state_kc_middle)
                                  : MathMax(0.0, g_state_kc_middle - entry);
   const double atr_distance = strategy_sl_atr_mult * g_state_atr;
   const double stop_distance = MathMax(middle_distance, atr_distance);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_max_spread_stop_fraction * stop_distance)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, stop_distance);
   req.tp = QM_TakeRR(_Symbol, side, entry, req.sl, strategy_tp_r_multiple);
   req.reason = QM_OrderTypeIsBuy(side) ? "CHOP_KC_TSI_LONG" : "CHOP_KC_TSI_SHORT";
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_GetOurPosition(ptype, open_time))
      return false;

   if(strategy_max_hold_bars > 0)
     {
      const int seconds_per_bar = PeriodSeconds(PERIOD_H1);
      if(seconds_per_bar > 0 && TimeCurrent() - open_time >= strategy_max_hold_bars * seconds_per_bar)
         return true;
     }

   if(g_state_ready && g_state_bar_time > open_time)
     {
      if(ptype == POSITION_TYPE_BUY && g_state_exit_long)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_state_exit_short)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Defer to the framework two-axis news filter.
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
