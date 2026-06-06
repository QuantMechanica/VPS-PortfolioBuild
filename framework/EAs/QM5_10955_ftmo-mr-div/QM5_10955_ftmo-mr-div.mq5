#property strict
#property version   "5.0"
#property description "QM5_10955 FTMO Mean-Reversion Divergence"

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
input int    qm_ea_id                   = 10955;
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
input int    strategy_bb_period             = 20;
input double strategy_bb_deviation          = 2.0;
input int    strategy_rsi_period            = 14;
input double strategy_rsi_oversold          = 35.0;
input double strategy_rsi_overbought        = 65.0;
input int    strategy_macd_fast             = 12;
input int    strategy_macd_slow             = 26;
input int    strategy_macd_signal           = 9;
input int    strategy_atr_period            = 14;
input int    strategy_atr_median_bars       = 100;
input int    strategy_divergence_lookback   = 20;
input int    strategy_swing_side_bars       = 2;
input double strategy_sl_atr_buffer_mult    = 0.15;
input int    strategy_trend_ema_period      = 200;
input double strategy_trend_atr_skip_mult   = 1.5;
input int    strategy_time_exit_bars        = 36;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
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

   if(strategy_bb_period <= 1 || strategy_bb_deviation <= 0.0 ||
      strategy_rsi_period <= 1 || strategy_macd_fast <= 0 ||
      strategy_macd_slow <= strategy_macd_fast || strategy_macd_signal <= 0 ||
      strategy_atr_period <= 0 || strategy_atr_median_bars < 3 ||
      strategy_divergence_lookback < 8 || strategy_swing_side_bars < 1 ||
      strategy_sl_atr_buffer_mult <= 0.0 || strategy_trend_ema_period <= 1 ||
      strategy_trend_atr_skip_mult <= 0.0)
      return false;

   int rates_count = strategy_divergence_lookback + strategy_swing_side_bars + 4;
   if(rates_count < 30)
      rates_count = 30;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, rates_count, rates); // perf-allowed: bounded swing/divergence read inside framework new-bar entry hook.
   if(copied < rates_count)
      return false;

   const double close_current = rates[0].close;
   const double close_setup = rates[1].close;
   if(close_current <= 0.0 || close_setup <= 0.0)
      return false;

   const double atr_current = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double ema_trend = QM_EMA(_Symbol, PERIOD_H1, strategy_trend_ema_period, 1);
   if(atr_current <= 0.0 || ema_trend <= 0.0)
      return false;

   double atr_values[];
   ArrayResize(atr_values, strategy_atr_median_bars);
   for(int i = 0; i < strategy_atr_median_bars; ++i)
     {
      atr_values[i] = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, i + 2);
      if(atr_values[i] <= 0.0)
         return false;
     }
   ArraySort(atr_values);
   double atr_median = atr_values[strategy_atr_median_bars / 2];
   if((strategy_atr_median_bars % 2) == 0)
      atr_median = 0.5 * (atr_values[strategy_atr_median_bars / 2 - 1] +
                          atr_values[strategy_atr_median_bars / 2]);
   if(atr_current <= atr_median)
      return false;

   const double upper_current = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower_current = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double middle_current = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper_setup = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 2);
   const double lower_setup = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 2);
   const double rsi_setup = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 2);
   if(upper_current <= 0.0 || lower_current <= 0.0 || middle_current <= 0.0 ||
      upper_setup <= 0.0 || lower_setup <= 0.0 || rsi_setup <= 0.0)
      return false;

   int max_scan = strategy_divergence_lookback - 1 - strategy_swing_side_bars;
   const int copied_scan = copied - 1 - strategy_swing_side_bars;
   if(copied_scan < max_scan)
      max_scan = copied_scan;
   if(max_scan <= strategy_swing_side_bars)
      return false;

   int latest_low_index = -1;
   int previous_low_index = -1;
   double latest_low = 0.0;
   double previous_low = 0.0;
   int latest_high_index = -1;
   int previous_high_index = -1;
   double latest_high = 0.0;
   double previous_high = 0.0;

   for(int i = strategy_swing_side_bars; i <= max_scan; ++i)
     {
      bool is_swing_low = true;
      bool is_swing_high = true;
      for(int side = 1; side <= strategy_swing_side_bars; ++side)
        {
         if(rates[i].low >= rates[i - side].low || rates[i].low >= rates[i + side].low)
            is_swing_low = false;
         if(rates[i].high <= rates[i - side].high || rates[i].high <= rates[i + side].high)
            is_swing_high = false;
        }

      if(is_swing_low)
        {
         if(latest_low_index < 0)
           {
            latest_low_index = i;
            latest_low = rates[i].low;
           }
         else if(previous_low_index < 0)
           {
            previous_low_index = i;
            previous_low = rates[i].low;
           }
        }

      if(is_swing_high)
        {
         if(latest_high_index < 0)
           {
            latest_high_index = i;
            latest_high = rates[i].high;
           }
         else if(previous_high_index < 0)
           {
            previous_high_index = i;
            previous_high = rates[i].high;
           }
        }
     }

   bool bullish_divergence = false;
   if(latest_low_index >= 0 && previous_low_index >= 0 &&
      latest_low > 0.0 && previous_low > 0.0 && latest_low < previous_low)
     {
      const int latest_shift = latest_low_index + 1;
      const int previous_shift = previous_low_index + 1;
      const double latest_hist = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, latest_shift) -
                                 QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, latest_shift);
      const double previous_hist = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, previous_shift) -
                                   QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, previous_shift);
      bullish_divergence = (latest_hist > previous_hist);
     }

   bool bearish_divergence = false;
   if(latest_high_index >= 0 && previous_high_index >= 0 &&
      latest_high > 0.0 && previous_high > 0.0 && latest_high > previous_high)
     {
      const int latest_shift = latest_high_index + 1;
      const int previous_shift = previous_high_index + 1;
      const double latest_hist = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, latest_shift) -
                                 QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, latest_shift);
      const double previous_hist = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, previous_shift) -
                                   QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, previous_shift);
      bearish_divergence = (latest_hist < previous_hist);
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool skip_long_countertrend = (close_current < ema_trend - strategy_trend_atr_skip_mult * atr_current);
   const bool skip_short_countertrend = (close_current > ema_trend + strategy_trend_atr_skip_mult * atr_current);
   const double buffer = strategy_sl_atr_buffer_mult * atr_current;

   if(!skip_long_countertrend &&
      close_setup < lower_setup &&
      rsi_setup < strategy_rsi_oversold &&
      bullish_divergence &&
      close_current > lower_current)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = latest_low - buffer;
      req.tp = middle_current;
      req.reason = "FTMO_MR_DIV_LONG";
      return (req.sl > 0.0 && req.sl < ask && req.tp > ask);
     }

   if(!skip_short_countertrend &&
      close_setup > upper_setup &&
      rsi_setup > strategy_rsi_overbought &&
      bearish_divergence &&
      close_current < upper_current)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = latest_high + buffer;
      req.tp = middle_current;
      req.reason = "FTMO_MR_DIV_SHORT";
      return (req.sl > bid && req.tp > 0.0 && req.tp < bid);
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
   if(strategy_time_exit_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   const int period_seconds = PeriodSeconds(PERIOD_H1);
   if(period_seconds <= 0)
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && now - open_time >= (long)strategy_time_exit_bars * period_seconds)
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
