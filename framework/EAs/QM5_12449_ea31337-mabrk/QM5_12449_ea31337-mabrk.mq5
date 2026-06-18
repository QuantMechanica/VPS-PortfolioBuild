#property strict
#property version   "5.0"
#property description "QM5_12449 EA31337 Moving Average Candle Breakout"

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
input int    qm_ea_id                   = 12449;
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
input double strategy_signal_open_level = 1.0;
input int    strategy_signal_open_method = 0;
input int    strategy_tenkan_period     = 30;
input int    strategy_kijun_period      = 10;
input int    strategy_senkou_span_b_period = 30;
input int    strategy_stop_loss_pips    = 80;
input int    strategy_take_profit_pips  = 80;
input int    strategy_close_after_bars  = 30;
input int    strategy_max_spread_pips   = 4;
input bool   strategy_opposite_exit_enabled = true;

int g_last_closed_bar_signal = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_pips <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(spread_cap <= 0.0)
      return false;

   if(ask > bid && (ask - bid) > spread_cap)
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

   g_last_closed_bar_signal = 0;

   if(strategy_signal_open_level <= 0.0 ||
      strategy_tenkan_period < 2 ||
      strategy_kijun_period < 2 ||
      strategy_senkou_span_b_period < 2 ||
      strategy_stop_loss_pips <= 0 ||
      strategy_take_profit_pips <= 0)
      return false;

   MqlRates chart_rates[];
   ArraySetAsSeries(chart_rates, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 2, chart_rates) != 2) // perf-allowed
      return false;

   MqlRates daily_rates[];
   ArraySetAsSeries(daily_rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 2, daily_rates) != 2) // perf-allowed
      return false;

   const double range_candles = (chart_rates[0].high - chart_rates[0].low) +
                                (chart_rates[1].high - chart_rates[1].low);
   const double range_d1 = (daily_rates[0].high - daily_rates[0].low) +
                           (daily_rates[1].high - daily_rates[1].low);
   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(range_candles <= 0.0 || range_d1 <= 0.0 || seconds_per_bar <= 0)
      return false;

   const double tf_fraction_of_day = (double)seconds_per_bar / 86400.0;
   if(tf_fraction_of_day <= 0.0)
      return false;

   const double normalized_range = range_candles / (range_d1 * tf_fraction_of_day);
   if(normalized_range <= strategy_signal_open_level)
      return false;

   const double ma1 = QM_Ichimoku_TenkanSen(_Symbol,
                                            (ENUM_TIMEFRAMES)_Period,
                                            strategy_tenkan_period,
                                            strategy_kijun_period,
                                            strategy_senkou_span_b_period,
                                            1);
   const double ma2 = QM_Ichimoku_TenkanSen(_Symbol,
                                            (ENUM_TIMEFRAMES)_Period,
                                            strategy_tenkan_period,
                                            strategy_kijun_period,
                                            strategy_senkou_span_b_period,
                                            2);
   const double ma3 = QM_Ichimoku_TenkanSen(_Symbol,
                                            (ENUM_TIMEFRAMES)_Period,
                                            strategy_tenkan_period,
                                            strategy_kijun_period,
                                            strategy_senkou_span_b_period,
                                            3);
   const double ma4 = QM_Ichimoku_TenkanSen(_Symbol,
                                            (ENUM_TIMEFRAMES)_Period,
                                            strategy_tenkan_period,
                                            strategy_kijun_period,
                                            strategy_senkou_span_b_period,
                                            4);
   if(ma1 <= 0.0 || ma2 <= 0.0 || ma3 <= 0.0 || ma4 <= 0.0)
      return false;

   const bool ma_inside_candles =
      (chart_rates[0].low < ma1 && chart_rates[0].high > ma1) ||
      (chart_rates[1].low < ma2 && chart_rates[1].high > ma2);
   if(!ma_inside_candles)
      return false;

   bool long_ok = (chart_rates[0].close > chart_rates[0].open) ||
                  (chart_rates[1].close > chart_rates[1].open);
   bool short_ok = (chart_rates[0].close < chart_rates[0].open) ||
                   (chart_rates[1].close < chart_rates[1].open);

   if(strategy_signal_open_method != 0)
     {
      if((strategy_signal_open_method & 1) != 0)
        {
         long_ok = long_ok && (ma1 > ma2);
         short_ok = short_ok && (ma1 < ma2);
        }
      if((strategy_signal_open_method & 2) != 0)
        {
         long_ok = long_ok && (ma1 > ma4);
         short_ok = short_ok && (ma1 < ma4);
        }
      if((strategy_signal_open_method & 4) != 0)
        {
         long_ok = long_ok && (ma1 >= ma2 && ma1 >= ma3 && ma1 >= ma4);
         short_ok = short_ok && (ma1 <= ma2 && ma1 <= ma3 && ma1 <= ma4);
        }
     }

   if(long_ok && short_ok)
     {
      if(chart_rates[0].close > chart_rates[0].open)
         short_ok = false;
      else if(chart_rates[0].close < chart_rates[0].open)
         long_ok = false;
      else
         return false;
     }

   if(long_ok)
      g_last_closed_bar_signal = 1;
   else if(short_ok)
      g_last_closed_bar_signal = -1;
   else
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_last_closed_bar_signal > 0)
     {
      req.type = QM_BUY;
      req.sl = QM_StopFixedPips(_Symbol, req.type, ask, strategy_stop_loss_pips);
      req.tp = QM_TakeFixedPips(_Symbol, req.type, ask, strategy_take_profit_pips);
      req.reason = "EA31337_MABRK_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   req.type = QM_SELL;
   req.sl = QM_StopFixedPips(_Symbol, req.type, bid, strategy_stop_loss_pips);
   req.tp = QM_TakeFixedPips(_Symbol, req.type, bid, strategy_take_profit_pips);
   req.reason = "EA31337_MABRK_SHORT";
   return (req.sl > 0.0 && req.tp > 0.0);
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
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(strategy_close_after_bars > 0)
        {
         const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
         const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
         if(opened_at > 0 && seconds_per_bar > 0 &&
            TimeCurrent() - opened_at >= strategy_close_after_bars * seconds_per_bar)
            return true;
        }

      if(strategy_opposite_exit_enabled && g_last_closed_bar_signal != 0)
        {
         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pos_type == POSITION_TYPE_BUY && g_last_closed_bar_signal < 0)
            return true;
         if(pos_type == POSITION_TYPE_SELL && g_last_closed_bar_signal > 0)
            return true;
        }
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
