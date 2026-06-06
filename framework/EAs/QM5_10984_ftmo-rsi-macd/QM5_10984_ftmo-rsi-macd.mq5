#property strict
#property version   "5.0"
#property description "QM5_10984 FTMO RSI MACD synchronized reversal"

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
input int    qm_ea_id                   = 10984;
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
input ENUM_TIMEFRAMES strategy_timeframe             = PERIOD_H1;
input int             strategy_rsi_period            = 14;
input double          strategy_rsi_oversold          = 30.0;
input double          strategy_rsi_overbought        = 70.0;
input int             strategy_rsi_signal_lookback   = 3;
input int             strategy_rsi_sequence_max_bars = 3;
input int             strategy_macd_fast             = 12;
input int             strategy_macd_slow             = 26;
input int             strategy_macd_signal           = 9;
input int             strategy_macd_confirm_bars     = 2;
input int             strategy_atr_period            = 14;
input int             strategy_atr_percentile_bars   = 250;
input double          strategy_min_atr_percentile    = 0.20;
input double          strategy_stop_atr_buffer_mult  = 0.25;
input double          strategy_min_stop_atr_mult     = 0.80;
input double          strategy_max_stop_atr_mult     = 2.50;
input double          strategy_take_profit_r         = 2.0;
input int             strategy_time_exit_bars        = 36;
input int             strategy_spread_median_bars    = 20;
input double          strategy_spread_median_mult    = 1.50;

bool Strategy_SelectOurPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &ptype,
                                double &open_price,
                                datetime &open_time,
                                double &sl,
                                double &tp)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;
   sl = 0.0;
   tp = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      return true;
     }

   return false;
  }

bool Strategy_LoadClosedRates(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, count, rates); // perf-allowed: bounded closed-bar OHLC/spread read inside framework new-bar entry hook.
   return (copied >= count);
  }

double Strategy_AtrPercentileThreshold()
  {
   const int count_target = MathMax(1, strategy_atr_percentile_bars);
   double values[];
   ArrayResize(values, count_target);
   int count = 0;

   for(int shift = 2; shift < count_target + 2; ++shift)
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(atr > 0.0)
        {
         values[count] = atr;
         count++;
        }
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);
   int idx = (int)MathFloor((count - 1) * strategy_min_atr_percentile);
   idx = MathMax(0, MathMin(count - 1, idx));
   return values[idx];
  }

double Strategy_MedianClosedSpread(const MqlRates &rates[], const int count)
  {
   const int total = ArraySize(rates);
   const int usable = MathMin(MathMax(0, count), total);
   if(usable <= 0)
      return 0.0;

   int values[];
   ArrayResize(values, usable);
   int n = 0;
   for(int i = 0; i < usable; ++i)
     {
      if(rates[i].spread > 0)
        {
         values[n] = rates[i].spread;
         n++;
        }
     }

   if(n <= 0)
      return 0.0;

   ArrayResize(values, n);
   ArraySort(values);
   if((n % 2) == 1)
      return (double)values[n / 2];
   return 0.5 * (double)(values[n / 2 - 1] + values[n / 2]);
  }

bool Strategy_BullishMacdCrossAt(const int shift)
  {
   const double main_now = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double sig_now = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double main_prev = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   const double sig_prev = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   return (main_prev <= sig_prev && main_now > sig_now);
  }

bool Strategy_BearishMacdCrossAt(const int shift)
  {
   const double main_now = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double sig_now = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   const double main_prev = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   const double sig_prev = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + 1);
   return (main_prev >= sig_prev && main_now < sig_now);
  }

bool Strategy_RsiCrossAboveAt(const int shift)
  {
   const double rsi_now = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, shift);
   const double rsi_prev = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, shift + 1);
   return (rsi_prev <= strategy_rsi_oversold && rsi_now > strategy_rsi_oversold);
  }

bool Strategy_RsiCrossBelowAt(const int shift)
  {
   const double rsi_now = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, shift);
   const double rsi_prev = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, shift + 1);
   return (rsi_prev >= strategy_rsi_overbought && rsi_now < strategy_rsi_overbought);
  }

bool Strategy_FindLongRsiCross(int &rsi_cross_shift)
  {
   rsi_cross_shift = -1;
   const int max_shift = MathMax(1, strategy_rsi_signal_lookback);
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      if((shift - 1) > strategy_macd_confirm_bars)
         continue;
      if(Strategy_RsiCrossAboveAt(shift))
        {
         rsi_cross_shift = shift;
         return true;
        }
     }
   return false;
  }

bool Strategy_FindShortRsiCross(int &rsi_cross_shift)
  {
   rsi_cross_shift = -1;
   const int max_shift = MathMax(1, strategy_rsi_signal_lookback);
   for(int shift = 1; shift <= max_shift; ++shift)
     {
      if((shift - 1) > strategy_macd_confirm_bars)
         continue;
      if(Strategy_RsiCrossBelowAt(shift))
        {
         rsi_cross_shift = shift;
         return true;
        }
     }
   return false;
  }

bool Strategy_RsiSequenceLow(const MqlRates &rates[], const int rsi_cross_shift, double &sequence_low)
  {
   sequence_low = DBL_MAX;
   bool found = false;
   const int max_bars = MathMax(1, strategy_rsi_sequence_max_bars);

   for(int offset = 1; offset <= max_bars; ++offset)
     {
      const int shift = rsi_cross_shift + offset;
      const int idx = shift - 1;
      if(idx < 0 || idx >= ArraySize(rates))
         break;
      const double rsi = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, shift);
      if(rsi < strategy_rsi_oversold)
        {
         sequence_low = MathMin(sequence_low, rates[idx].low);
         found = true;
        }
      else if(found)
         break;
     }

   return (found && sequence_low < DBL_MAX && sequence_low > 0.0);
  }

bool Strategy_RsiSequenceHigh(const MqlRates &rates[], const int rsi_cross_shift, double &sequence_high)
  {
   sequence_high = -DBL_MAX;
   bool found = false;
   const int max_bars = MathMax(1, strategy_rsi_sequence_max_bars);

   for(int offset = 1; offset <= max_bars; ++offset)
     {
      const int shift = rsi_cross_shift + offset;
      const int idx = shift - 1;
      if(idx < 0 || idx >= ArraySize(rates))
         break;
      const double rsi = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, shift);
      if(rsi > strategy_rsi_overbought)
        {
         sequence_high = MathMax(sequence_high, rates[idx].high);
         found = true;
        }
      else if(found)
         break;
     }

   return (found && sequence_high > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
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

   if(strategy_timeframe != PERIOD_H1 ||
      strategy_rsi_period <= 1 ||
      strategy_rsi_signal_lookback < 1 ||
      strategy_rsi_sequence_max_bars < 1 ||
      strategy_macd_fast <= 0 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 ||
      strategy_macd_confirm_bars < 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_percentile_bars < 10 ||
      strategy_min_atr_percentile < 0.0 ||
      strategy_min_atr_percentile > 1.0 ||
      strategy_stop_atr_buffer_mult < 0.0 ||
      strategy_min_stop_atr_mult <= 0.0 ||
      strategy_max_stop_atr_mult <= strategy_min_stop_atr_mult ||
      strategy_take_profit_r <= 0.0 ||
      strategy_spread_median_bars < 1 ||
      strategy_spread_median_mult <= 0.0)
      return false;

   ulong existing_ticket;
   ENUM_POSITION_TYPE existing_type;
   double existing_open;
   datetime existing_time;
   double existing_sl;
   double existing_tp;
   if(Strategy_SelectOurPosition(existing_ticket, existing_type, existing_open, existing_time, existing_sl, existing_tp))
      return false;

   const int rates_needed = MathMax(strategy_spread_median_bars,
                                    strategy_rsi_signal_lookback + strategy_rsi_sequence_max_bars + 2);
   MqlRates rates[];
   if(!Strategy_LoadClosedRates(rates, rates_needed))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double atr_threshold = Strategy_AtrPercentileThreshold();
   if(atr <= 0.0 || atr_threshold <= 0.0 || atr < atr_threshold)
      return false;

   const double median_spread = Strategy_MedianClosedSpread(rates, strategy_spread_median_bars);
   const int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread > 0.0 && current_spread > strategy_spread_median_mult * median_spread)
      return false;

   const double close_1 = rates[0].close;
   const double midpoint_1 = 0.5 * (rates[0].high + rates[0].low);
   if(close_1 <= 0.0 || rates[0].high <= 0.0 || rates[0].low <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   int rsi_cross_shift = -1;
   if(close_1 > midpoint_1 &&
      Strategy_BullishMacdCrossAt(1) &&
      Strategy_FindLongRsiCross(rsi_cross_shift))
     {
      double sequence_low = 0.0;
      if(!Strategy_RsiSequenceLow(rates, rsi_cross_shift, sequence_low))
         return false;

      const double entry = ask;
      const double raw_sl = sequence_low - strategy_stop_atr_buffer_mult * atr;
      double risk = entry - raw_sl;
      if(risk <= 0.0)
         return false;
      if(risk > strategy_max_stop_atr_mult * atr)
         return false;
      risk = MathMax(risk, strategy_min_stop_atr_mult * atr);

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry - risk);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_take_profit_r * risk);
      req.reason = "FTMO_RSI_MACD_LONG";
      return (req.sl > 0.0 && req.sl < entry && req.tp > entry);
     }

   if(close_1 < midpoint_1 &&
      Strategy_BearishMacdCrossAt(1) &&
      Strategy_FindShortRsiCross(rsi_cross_shift))
     {
      double sequence_high = 0.0;
      if(!Strategy_RsiSequenceHigh(rates, rsi_cross_shift, sequence_high))
         return false;

      const double entry = bid;
      const double raw_sl = sequence_high + strategy_stop_atr_buffer_mult * atr;
      double risk = raw_sl - entry;
      if(risk <= 0.0)
         return false;
      if(risk > strategy_max_stop_atr_mult * atr)
         return false;
      risk = MathMax(risk, strategy_min_stop_atr_mult * atr);

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry + risk);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_take_profit_r * risk);
      req.reason = "FTMO_RSI_MACD_SHORT";
      return (req.sl > entry && req.tp > 0.0 && req.tp < entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   double open_price;
   datetime open_time;
   double sl;
   double tp;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_price, open_time, sl, tp))
      return false;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   if(is_buy && Strategy_BearishMacdCrossAt(1))
      return true;
   if(!is_buy && Strategy_BullishMacdCrossAt(1))
      return true;

   if(strategy_time_exit_bars > 0 && open_time > 0)
     {
      const int bars_held = iBarShift(_Symbol, strategy_timeframe, open_time, false);
      if(bars_held >= strategy_time_exit_bars)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework high-impact news handling.
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
