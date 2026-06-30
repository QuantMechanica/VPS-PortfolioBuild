#property strict
#property version   "5.0"
#property description "QM5_1492 Connors VIX Spike Reversal ATR-Stretch Port (H4)"

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
input int    qm_ea_id                   = 1492;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input ENUM_TIMEFRAMES strategy_signal_tf            = PERIOD_H4;
input int             strategy_atr_period          = 14;
input int             strategy_atr_baseline_bars   = 50;
input double          strategy_spike_threshold      = 1.5;
input double          strategy_confirm_threshold    = 1.3;
input int             strategy_long_sma_period      = 200;
input int             strategy_long_sma_slope_bars  = 10;
input int             strategy_pullback_sma_period  = 5;
input int             strategy_daily_sma_period     = 50;
input int             strategy_daily_sma_slope_bars = 5;
input int             strategy_cooldown_bars        = 12;
input double          strategy_atr_sl_mult          = 2.0;
input int             strategy_time_stop_bars       = 16;
input int             strategy_tp2_sma_period       = 10;
input double          strategy_tp1_fraction         = 0.60;
input double          strategy_tp_done_volume_ratio = 0.50;
input double          strategy_spread_atr_fraction  = 0.15;
input int             strategy_warmup_bars          = 250;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): no card-specific session gate;
   // framework owns news/Friday handling, card adds a spread guard.
   if(strategy_signal_tf != PERIOD_H4 ||
      strategy_atr_period <= 0 ||
      strategy_spread_atr_fraction <= 0.0)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   if(ask > bid)
     {
      const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
      if(atr <= 0.0)
         return true;
      if((ask - bid) > atr * strategy_spread_atr_fraction)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: Connors VIX-stretch port, long only.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_signal_tf != PERIOD_H4 ||
      strategy_atr_period <= 0 ||
      strategy_atr_baseline_bars <= 0 ||
      strategy_atr_baseline_bars > 80 ||
      strategy_cooldown_bars < 0 ||
      strategy_cooldown_bars > 24 ||
      strategy_spike_threshold <= 0.0 ||
      strategy_confirm_threshold <= 0.0 ||
      strategy_long_sma_period <= 0 ||
      strategy_long_sma_slope_bars <= 0 ||
      strategy_pullback_sma_period <= 0 ||
      strategy_daily_sma_period <= 0 ||
      strategy_daily_sma_slope_bars <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_warmup_bars < strategy_long_sma_period)
      return false;

   if(QM_SMA(_Symbol, strategy_signal_tf, 1, strategy_warmup_bars, PRICE_CLOSE) <= 0.0)
      return false;

   const int max_atr_shift = strategy_cooldown_bars + strategy_atr_baseline_bars + 3;
   if(max_atr_shift >= 128)
      return false;

   double atr_cache[128];
   double atr_prefix[128];
   atr_cache[0] = 0.0;
   atr_prefix[0] = 0.0;
   for(int shift = 1; shift <= max_atr_shift; ++shift)
     {
      atr_cache[shift] = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, shift);
      if(atr_cache[shift] <= 0.0)
         return false;
      atr_prefix[shift] = atr_prefix[shift - 1] + atr_cache[shift];
     }

   const double atr_long = (atr_prefix[strategy_atr_baseline_bars] - atr_prefix[0]) / (double)strategy_atr_baseline_bars;
   if(atr_long <= 0.0)
      return false;

   const double stretch = atr_cache[1] / atr_long;
   if(stretch <= strategy_spike_threshold)
      return false;

   double confirm_stretch_1 = 0.0;
   double confirm_stretch_2 = 0.0;
   const double confirm_base_1 = (atr_prefix[strategy_atr_baseline_bars + 1] - atr_prefix[1]) / (double)strategy_atr_baseline_bars;
   const double confirm_base_2 = (atr_prefix[strategy_atr_baseline_bars + 2] - atr_prefix[2]) / (double)strategy_atr_baseline_bars;
   if(confirm_base_1 > 0.0)
      confirm_stretch_1 = atr_cache[2] / confirm_base_1;
   if(confirm_base_2 > 0.0)
      confirm_stretch_2 = atr_cache[3] / confirm_base_2;
   if(confirm_stretch_1 <= strategy_confirm_threshold &&
      confirm_stretch_2 <= strategy_confirm_threshold)
      return false;

   const double close_h4 = QM_SMA(_Symbol, strategy_signal_tf, 1, 1, PRICE_CLOSE);
   const double sma200 = QM_SMA(_Symbol, strategy_signal_tf, strategy_long_sma_period, 1, PRICE_CLOSE);
   const double sma200_prior = QM_SMA(_Symbol, strategy_signal_tf, strategy_long_sma_period, 1 + strategy_long_sma_slope_bars, PRICE_CLOSE);
   if(close_h4 <= 0.0 || sma200 <= 0.0 || sma200_prior <= 0.0 ||
      close_h4 <= sma200 || sma200 <= sma200_prior)
      return false;

   const double close_pull_0 = close_h4;
   const double close_pull_1 = QM_SMA(_Symbol, strategy_signal_tf, 1, 2, PRICE_CLOSE);
   const double sma5_0 = QM_SMA(_Symbol, strategy_signal_tf, strategy_pullback_sma_period, 1, PRICE_CLOSE);
   const double sma5_1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_pullback_sma_period, 2, PRICE_CLOSE);
   if(close_pull_0 <= 0.0 || close_pull_1 <= 0.0 || sma5_0 <= 0.0 || sma5_1 <= 0.0 ||
      close_pull_0 >= sma5_0 || close_pull_1 >= sma5_1)
      return false;

   const double close_d1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double sma50_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_daily_sma_period, 1, PRICE_CLOSE);
   const double sma50_d1_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_daily_sma_period, 1 + strategy_daily_sma_slope_bars, PRICE_CLOSE);
   if(close_d1 <= 0.0 || sma50_d1 <= 0.0 || sma50_d1_prior <= 0.0 ||
      close_d1 <= sma50_d1 || sma50_d1 <= sma50_d1_prior)
      return false;

   for(int signal_shift = 2; signal_shift <= strategy_cooldown_bars + 1; ++signal_shift)
     {
      const double past_base = (atr_prefix[signal_shift + strategy_atr_baseline_bars - 1] - atr_prefix[signal_shift - 1]) / (double)strategy_atr_baseline_bars;
      if(past_base <= 0.0)
         return false;

      const double past_stretch = atr_cache[signal_shift] / past_base;
      if(past_stretch <= strategy_spike_threshold)
         continue;

      const double past_confirm_base_1 = (atr_prefix[signal_shift + strategy_atr_baseline_bars] - atr_prefix[signal_shift]) / (double)strategy_atr_baseline_bars;
      const double past_confirm_base_2 = (atr_prefix[signal_shift + strategy_atr_baseline_bars + 1] - atr_prefix[signal_shift + 1]) / (double)strategy_atr_baseline_bars;
      double past_confirm_1 = 0.0;
      double past_confirm_2 = 0.0;
      if(past_confirm_base_1 > 0.0)
         past_confirm_1 = atr_cache[signal_shift + 1] / past_confirm_base_1;
      if(past_confirm_base_2 > 0.0)
         past_confirm_2 = atr_cache[signal_shift + 2] / past_confirm_base_2;
      if(past_confirm_1 <= strategy_confirm_threshold &&
         past_confirm_2 <= strategy_confirm_threshold)
         continue;

      const double past_close = QM_SMA(_Symbol, strategy_signal_tf, 1, signal_shift, PRICE_CLOSE);
      const double past_sma200 = QM_SMA(_Symbol, strategy_signal_tf, strategy_long_sma_period, signal_shift, PRICE_CLOSE);
      const double past_sma200_prior = QM_SMA(_Symbol, strategy_signal_tf, strategy_long_sma_period, signal_shift + strategy_long_sma_slope_bars, PRICE_CLOSE);
      if(past_close <= 0.0 || past_sma200 <= 0.0 || past_sma200_prior <= 0.0 ||
         past_close <= past_sma200 || past_sma200 <= past_sma200_prior)
         continue;

      const double past_close_pull_1 = QM_SMA(_Symbol, strategy_signal_tf, 1, signal_shift + 1, PRICE_CLOSE);
      const double past_sma5 = QM_SMA(_Symbol, strategy_signal_tf, strategy_pullback_sma_period, signal_shift, PRICE_CLOSE);
      const double past_sma5_prior = QM_SMA(_Symbol, strategy_signal_tf, strategy_pullback_sma_period, signal_shift + 1, PRICE_CLOSE);
      if(past_close >= past_sma5 ||
         past_close_pull_1 <= 0.0 ||
         past_sma5 <= 0.0 ||
         past_sma5_prior <= 0.0 ||
         past_close_pull_1 >= past_sma5_prior)
         continue;

      const int daily_shift = 1 + ((signal_shift - 1) / 6);
      const double past_close_d1 = QM_SMA(_Symbol, PERIOD_D1, 1, daily_shift, PRICE_CLOSE);
      const double past_sma50_d1 = QM_SMA(_Symbol, PERIOD_D1, strategy_daily_sma_period, daily_shift, PRICE_CLOSE);
      const double past_sma50_d1_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_daily_sma_period, daily_shift + strategy_daily_sma_slope_bars, PRICE_CLOSE);
      if(past_close_d1 > 0.0 &&
         past_sma50_d1 > 0.0 &&
         past_sma50_d1_prior > 0.0 &&
         past_close_d1 > past_sma50_d1 &&
         past_sma50_d1 > past_sma50_d1_prior)
         return false;
     }

   const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry_price, atr_cache[1], strategy_atr_sl_mult);
   if(req.sl <= 0.0 || req.sl >= entry_price)
      return false;

   req.reason = "CONNORS_VIX_ATR_STRETCH_LONG";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: TP1 closes 60% once H4 closes back above SMA(5).
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 ||
      strategy_signal_tf != PERIOD_H4 ||
      strategy_pullback_sma_period <= 0 ||
      strategy_tp1_fraction <= 0.0 ||
      strategy_tp1_fraction >= 1.0 ||
      strategy_tp_done_volume_ratio <= 0.0 ||
      strategy_tp_done_volume_ratio >= 1.0)
      return;

   const double close_h4 = QM_SMA(_Symbol, strategy_signal_tf, 1, 1, PRICE_CLOSE);
   const double sma5 = QM_SMA(_Symbol, strategy_signal_tf, strategy_pullback_sma_period, 1, PRICE_CLOSE);
   if(close_h4 <= 0.0 || sma5 <= 0.0 || close_h4 <= sma5)
      return;

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

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(volume <= 0.0 || open_price <= 0.0 || stop_price <= 0.0 || point <= 0.0)
         continue;

      const double sl_points = MathAbs(open_price - stop_price) / point;
      const double initial_lots = QM_LotsForRisk(_Symbol, sl_points);
      if(initial_lots <= 0.0 || volume <= initial_lots * strategy_tp_done_volume_ratio)
         continue;

      QM_TM_PartialClose(ticket, volume * strategy_tp1_fraction, QM_EXIT_PARTIAL);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: TP2 closes the remainder above SMA(10); time-stop closes
   // full size if TP1 has not fired within 16 H4 bars.
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 ||
      strategy_signal_tf != PERIOD_H4 ||
      strategy_tp2_sma_period <= 0 ||
      strategy_time_stop_bars <= 0)
      return false;

   const double close_h4 = QM_SMA(_Symbol, strategy_signal_tf, 1, 1, PRICE_CLOSE);
   const double sma10 = QM_SMA(_Symbol, strategy_signal_tf, strategy_tp2_sma_period, 1, PRICE_CLOSE);

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

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      bool tp1_done = false;
      if(volume > 0.0 && open_price > 0.0 && stop_price > 0.0 && point > 0.0)
        {
         const double sl_points = MathAbs(open_price - stop_price) / point;
         const double initial_lots = QM_LotsForRisk(_Symbol, sl_points);
         if(initial_lots > 0.0 && volume <= initial_lots * strategy_tp_done_volume_ratio)
            tp1_done = true;
        }

      if(tp1_done && close_h4 > 0.0 && sma10 > 0.0 && close_h4 > sma10)
         return true;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const int bar_seconds = PeriodSeconds(strategy_signal_tf);
      if(!tp1_done &&
         opened_at > 0 &&
         bar_seconds > 0 &&
         (TimeCurrent() - opened_at) >= (strategy_time_stop_bars * bar_seconds))
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: defer to the central 60-minute pre/post high-impact gate.
   return false;
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
