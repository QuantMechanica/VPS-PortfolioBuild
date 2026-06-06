#property strict
#property version   "5.0"
#property description "QM5_10965 FTMO Morning Star Support Reversal"

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
input int    qm_ea_id                   = 10965;
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
input int    strategy_sma_fast_period         = 50;
input int    strategy_sma_slow_period         = 100;
input int    strategy_swing_lookback_bars     = 40;
input int    strategy_support_lookback_bars   = 60;
input int    strategy_entry_window_bars       = 3;
input int    strategy_max_hold_bars           = 20;
input int    strategy_slope_positive_max_bars = 10;
input int    strategy_round_step_points       = 1000;
input double strategy_candle1_body_atr_mult   = 0.80;
input double strategy_candle2_body_ratio      = 0.35;
input double strategy_support_atr_mult        = 0.35;
input double strategy_round_tolerance_pct     = 0.15;
input double strategy_sl_atr_buffer_mult      = 0.25;
input double strategy_min_stop_atr_mult       = 0.50;
input double strategy_max_stop_atr_mult       = 2.50;
input double strategy_primary_rr              = 2.00;
input double strategy_alt_tp_min_rr           = 1.50;
input double strategy_alt_tp_max_rr           = 3.00;

double CandleBody(const MqlRates &bar)
  {
   return MathAbs(bar.close - bar.open);
  }

double CandleLow3(const MqlRates &a, const MqlRates &b, const MqlRates &c)
  {
   return MathMin(a.low, MathMin(b.low, c.low));
  }

bool LoadStrategyBars(MqlRates &rates[])
  {
   const int support_bars_needed = strategy_support_lookback_bars + strategy_entry_window_bars + 8;
   const int sma_bars_needed = strategy_sma_slow_period + strategy_entry_window_bars + 12;
   const int bars_needed = (support_bars_needed > sma_bars_needed) ? support_bars_needed : sma_bars_needed;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 0, bars_needed, rates); // perf-allowed: bounded H4 structural pattern read under framework QM_IsNewBar gate.
   return (copied >= bars_needed);
  }

bool IsSwingLow(const MqlRates &rates[], const int shift)
  {
   return (rates[shift].low < rates[shift - 1].low &&
           rates[shift].low <= rates[shift - 2].low &&
           rates[shift].low < rates[shift + 1].low &&
           rates[shift].low <= rates[shift + 2].low);
  }

bool IsSwingHigh(const MqlRates &rates[], const int shift)
  {
   return (rates[shift].high > rates[shift - 1].high &&
           rates[shift].high >= rates[shift - 2].high &&
           rates[shift].high > rates[shift + 1].high &&
           rates[shift].high >= rates[shift + 2].high);
  }

int CountLowerSwingProgression(const MqlRates &rates[],
                               const int start_shift,
                               const int lookback_bars,
                               const bool highs)
  {
   int count = 0;
   bool have_newer = false;
   double newer_value = 0.0;
   const int last_shift = start_shift + lookback_bars;
   for(int shift = start_shift + 2; shift <= last_shift - 2; ++shift)
     {
      const bool is_swing = highs ? IsSwingHigh(rates, shift) : IsSwingLow(rates, shift);
      if(!is_swing)
         continue;

      const double value = highs ? rates[shift].high : rates[shift].low;
      if(have_newer && newer_value < value)
         ++count;

      newer_value = value;
      have_newer = true;
     }
   return count;
  }

double LowestPriorSwingLow(const MqlRates &rates[], const int start_shift, const int lookback_bars)
  {
   double lowest = DBL_MAX;
   const int last_shift = start_shift + lookback_bars;
   for(int shift = start_shift + 2; shift <= last_shift - 2; ++shift)
     {
      if(IsSwingLow(rates, shift))
         lowest = MathMin(lowest, rates[shift].low);
     }

   if(lowest < DBL_MAX)
      return lowest;

   for(int shift = start_shift; shift <= last_shift; ++shift)
      lowest = MathMin(lowest, rates[shift].low);
   return lowest;
  }

double NearestPriorSwingHighAbove(const MqlRates &rates[],
                                  const int start_shift,
                                  const int lookback_bars,
                                  const double entry)
  {
   double nearest = DBL_MAX;
   const int last_shift = start_shift + lookback_bars;
   for(int shift = start_shift + 2; shift <= last_shift - 2; ++shift)
     {
      if(!IsSwingHigh(rates, shift))
         continue;
      if(rates[shift].high > entry && rates[shift].high < nearest)
         nearest = rates[shift].high;
     }
   return (nearest < DBL_MAX) ? nearest : 0.0;
  }

bool PatternNearRoundNumber(const double pattern_low)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || strategy_round_step_points <= 0 || pattern_low <= 0.0)
      return false;

   const double step = point * strategy_round_step_points;
   if(step <= 0.0)
      return false;

   const double nearest = MathRound(pattern_low / step) * step;
   const double tolerance = pattern_low * (strategy_round_tolerance_pct / 100.0);
   return (MathAbs(pattern_low - nearest) <= tolerance);
  }

bool SmaSlopeAlreadyPositiveTooLong(const int start_shift)
  {
   int positive_count = 0;
   for(int shift = start_shift; shift < start_shift + strategy_slope_positive_max_bars + 1; ++shift)
     {
      const double sma_now = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_fast_period, shift);
      const double sma_prev = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_fast_period, shift + 1);
      if(sma_now <= 0.0 || sma_prev <= 0.0 || sma_now <= sma_prev)
         break;
      ++positive_count;
     }
   return (positive_count > strategy_slope_positive_max_bars);
  }

bool IsMorningStarSetup(const MqlRates &rates[], const int bars_after_c3, double &pattern_low, double &candle3_high)
  {
   const int c1 = bars_after_c3 + 3;
   const int c2 = bars_after_c3 + 2;
   const int c3 = bars_after_c3 + 1;
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, c3);
   if(atr <= 0.0)
      return false;

   const double sma_fast = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_fast_period, c3);
   const double sma_slow = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_slow_period, c3);
   if(sma_fast <= 0.0 || sma_slow <= 0.0 || sma_fast >= sma_slow)
      return false;

   if(CountLowerSwingProgression(rates, c3, strategy_swing_lookback_bars, false) < 2)
      return false;
   if(CountLowerSwingProgression(rates, c3, strategy_swing_lookback_bars, true) < 2)
      return false;

   if(SmaSlopeAlreadyPositiveTooLong(c3))
      return false;

   const double c1_body = CandleBody(rates[c1]);
   const double c2_body = CandleBody(rates[c2]);
   if(rates[c1].close >= rates[c1].open)
      return false;
   if(c1_body < strategy_candle1_body_atr_mult * atr)
      return false;
   if(c2_body > strategy_candle2_body_ratio * c1_body)
      return false;
   if(rates[c2].low > rates[c1].low || rates[c2].low > rates[c3].low)
      return false;
   if(rates[c3].close <= rates[c3].open)
      return false;

   const double c1_midpoint = (rates[c1].open + rates[c1].close) * 0.5;
   if(rates[c3].close <= c1_midpoint)
      return false;

   pattern_low = CandleLow3(rates[c1], rates[c2], rates[c3]);
   candle3_high = rates[c3].high;

   const double support_low = LowestPriorSwingLow(rates, c3 + 1, strategy_support_lookback_bars);
   const bool near_swing_support = (support_low > 0.0 && MathAbs(pattern_low - support_low) <= strategy_support_atr_mult * atr);
   return (near_swing_support || PatternNearRoundNumber(pattern_low));
  }

double PriceDistanceToPips(const string symbol, const double distance)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0 || distance <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return distance / (point * pip_factor);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
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

   MqlRates rates[];
   if(!LoadStrategyBars(rates))
      return false;

   for(int bars_after_c3 = 1; bars_after_c3 <= strategy_entry_window_bars; ++bars_after_c3)
     {
      double pattern_low = 0.0;
      double candle3_high = 0.0;
      if(!IsMorningStarSetup(rates, bars_after_c3, pattern_low, candle3_high))
         continue;

      if(rates[1].high <= candle3_high || rates[1].close <= candle3_high)
         continue;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
      if(ask <= 0.0 || point <= 0.0 || atr <= 0.0)
         return false;

      const double sl_raw = pattern_low - strategy_sl_atr_buffer_mult * atr;
      const double stop_distance = ask - sl_raw;
      if(stop_distance <= 0.0)
         return false;
      if(stop_distance < strategy_min_stop_atr_mult * atr || stop_distance > strategy_max_stop_atr_mult * atr)
         return false;

      double tp_raw = ask + strategy_primary_rr * stop_distance;
      const double swing_tp = NearestPriorSwingHighAbove(rates, bars_after_c3 + 2, strategy_support_lookback_bars, ask);
      if(swing_tp > 0.0)
        {
         const double swing_rr = (swing_tp - ask) / stop_distance;
         if(swing_rr >= strategy_alt_tp_min_rr && swing_rr <= strategy_alt_tp_max_rr)
            tp_raw = swing_tp;
        }

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl_raw, _Digits);
      req.tp = NormalizeDouble(tp_raw, _Digits);
      req.reason = "ftmo_morning_star_h4_breakout";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
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
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double initial_risk = open_price - current_sl;
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(initial_risk <= 0.0 || bid < open_price + initial_risk)
         continue;

      const int trigger_pips = (int)MathMax(1.0, MathRound(PriceDistanceToPips(_Symbol, initial_risk)));
      QM_TM_MoveToBreakEven(ticket, trigger_pips, 0);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int hold_seconds = PeriodSeconds(PERIOD_H4) * strategy_max_hold_bars;
   if(hold_seconds <= 0)
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
      if(opened > 0 && now - opened >= hold_seconds)
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
