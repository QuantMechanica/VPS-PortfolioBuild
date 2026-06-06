#property strict
#property version   "5.0"
#property description "QM5_10862 TradingView MTF Trend Breakout"

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
input int    qm_ea_id                   = 10862;
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
input ENUM_TIMEFRAMES strategy_signal_timeframe = PERIOD_CURRENT;
input int    strategy_ema_period        = 240;
input int    strategy_consecutive_closes = 3;
input double strategy_breakout_offset_pct = 0.10;
input double strategy_trailing_stop_pct = 2.50;
input int    strategy_atr_period        = 14;
input double strategy_atr_fallback_mult = 2.50;
input double strategy_atr_wide_threshold = 3.00;
input int    strategy_pending_bars      = 3;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): framework owns time/news; block bad quotes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask <= 0.0 || bid <= 0.0 || ask <= bid);
  }

// Trade Entry: D1 EMA trend context + consecutive-close stop breakout.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;

   const ENUM_TIMEFRAMES signal_tf = (strategy_signal_timeframe == PERIOD_CURRENT)
                                     ? (ENUM_TIMEFRAMES)_Period
                                     : strategy_signal_timeframe;
   const int pending_bars = MathMax(1, strategy_pending_bars);
   const int period_seconds = PeriodSeconds(signal_tf);
   req.expiration_seconds = ((period_seconds > 0) ? period_seconds : PeriodSeconds((ENUM_TIMEFRAMES)_Period)) * pending_bars;

   const int magic = QM_FrameworkMagic();
   const double signal_close = iClose(_Symbol, signal_tf, 1); // perf-allowed: closed-bar breakout candle close.
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, MathMax(1, strategy_ema_period), 1, PRICE_CLOSE);
   if(signal_close <= 0.0 || d1_ema <= 0.0)
      return false;

   const bool long_context = (signal_close > d1_ema);
   const bool short_context = (signal_close < d1_ema);

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP && !long_context)
         QM_TM_RemovePendingOrder(ticket, "trend_context_flip");
      else if(order_type == ORDER_TYPE_SELL_STOP && !short_context)
         QM_TM_RemovePendingOrder(ticket, "trend_context_flip");
      else
         return false;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int closes_needed = MathMax(1, strategy_consecutive_closes);
   bool higher_closes = true;
   bool lower_closes = true;
   for(int shift = 1; shift <= closes_needed; ++shift)
     {
      const double close_curr = iClose(_Symbol, signal_tf, shift);     // perf-allowed: bounded closed-bar momentum sequence.
      const double close_prev = iClose(_Symbol, signal_tf, shift + 1); // perf-allowed: bounded closed-bar momentum sequence.
      if(close_curr <= 0.0 || close_prev <= 0.0)
         return false;
      if(close_curr <= close_prev)
         higher_closes = false;
      if(close_curr >= close_prev)
         lower_closes = false;
     }

   const double signal_high = iHigh(_Symbol, signal_tf, 1); // perf-allowed: signal candle breakout stop level.
   const double signal_low = iLow(_Symbol, signal_tf, 1);   // perf-allowed: signal candle breakout stop level.
   const double atr = QM_ATR(_Symbol, signal_tf, MathMax(1, strategy_atr_period), 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(signal_high <= 0.0 || signal_low <= 0.0 || atr <= 0.0 || point <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   const double offset = MathMax(0.0, strategy_breakout_offset_pct) / 100.0;
   const double trail_pct = MathMax(0.0, strategy_trailing_stop_pct) / 100.0;
   const double atr_mult = MathMax(0.1, strategy_atr_fallback_mult);
   const double atr_wide = MathMax(0.1, strategy_atr_wide_threshold);
   if(offset <= 0.0 || trail_pct <= 0.0)
      return false;

   if(long_context && higher_closes)
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, signal_high * (1.0 + offset));
      const double pct_dist = entry * trail_pct;
      const double stop_dist = (pct_dist > atr_wide * atr) ? atr_mult * atr : pct_dist;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = QM_TM_NormalizePrice(_Symbol, entry - stop_dist);
      req.tp = 0.0;
      req.reason = "TV_MTF_TREND_BO_LONG";
      return (req.price > ask && req.sl > 0.0 && req.sl < req.price);
     }

   if(short_context && lower_closes)
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, signal_low * (1.0 - offset));
      const double pct_dist = entry * trail_pct;
      const double stop_dist = (pct_dist > atr_wide * atr) ? atr_mult * atr : pct_dist;
      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = QM_TM_NormalizePrice(_Symbol, entry + stop_dist);
      req.tp = 0.0;
      req.reason = "TV_MTF_TREND_BO_SHORT";
      return (req.price < bid && req.sl > req.price);
     }

   return false;
  }

// Trade Management: dynamic 2.5% trailing stop with ATR fallback hard stop.
void Strategy_ManageOpenPosition()
  {
   const ENUM_TIMEFRAMES signal_tf = (strategy_signal_timeframe == PERIOD_CURRENT)
                                     ? (ENUM_TIMEFRAMES)_Period
                                     : strategy_signal_timeframe;
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, signal_tf, MathMax(1, strategy_atr_period), 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return;

   const double trail_pct = MathMax(0.0, strategy_trailing_stop_pct) / 100.0;
   const double atr_mult = MathMax(0.1, strategy_atr_fallback_mult);
   const double atr_wide = MathMax(0.1, strategy_atr_wide_threshold);
   if(trail_pct <= 0.0)
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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const bool is_buy = (position_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double pct_dist = market * trail_pct;
      const double stop_dist = (pct_dist > atr_wide * atr) ? atr_mult * atr : pct_dist;
      const double raw_sl = is_buy ? (market - stop_dist) : (market + stop_dist);
      const double target_sl = QM_TM_NormalizePrice(_Symbol, raw_sl);
      if(target_sl <= 0.0)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (is_buy ? (target_sl > current_sl + point * 0.5)
                                    : (target_sl < current_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "dynamic_percent_trail");
     }
  }

// Trade Close: exits are handled by the managed trailing stop plus framework close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no card-specific override beyond the central news filter.
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
