#property strict
#property version   "5.0"
#property description "QM5_10526 MQL5 Flat Channel Breakout"
// rework v2 2026-06-16 — flat-width gate compared a 20-bar accumulated channel
// range against a single-bar ATR (scale mismatch) so "flat" was never satisfied
// (~0 trades). Scale the threshold by sqrt(lookback) so it gates a *compressed*
// multi-bar channel as the card intends, keeping strategy_flat_atr_ratio meaningful.

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
input int    qm_ea_id                   = 10526;
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
input int    strategy_channel_lookback  = 20;
input int    strategy_atr_period        = 14;
input double strategy_flat_atr_ratio    = 1.20;
input int    strategy_slope_bars        = 5;
input double strategy_max_slope_atr     = 0.25;
input double strategy_breakout_atr_indent = 0.10;
input double strategy_min_tp_r          = 1.25;
input double strategy_max_tp_r          = 2.00;
input int    strategy_time_stop_bars    = 12;
input double strategy_time_stop_min_r   = 0.50;

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

   if(strategy_channel_lookback <= 1 ||
      strategy_atr_period <= 0 ||
      strategy_flat_atr_ratio <= 0.0 ||
      strategy_slope_bars <= 0 ||
      strategy_max_slope_atr < 0.0 ||
      strategy_breakout_atr_indent < 0.0 ||
      strategy_min_tp_r <= 0.0 ||
      strategy_max_tp_r < strategy_min_tp_r)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double channel_high = -DBL_MAX;
   double channel_low = DBL_MAX;
   for(int shift = 2; shift <= strategy_channel_lookback + 1; ++shift)
     {
      const double h = iHigh(_Symbol, _Period, shift);
      const double l = iLow(_Symbol, _Period, shift);
      if(h <= 0.0 || l <= 0.0)
         return false;
      channel_high = MathMax(channel_high, h);
      channel_low = MathMin(channel_low, l);
     }

   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int shift = 2 + strategy_slope_bars; shift <= strategy_channel_lookback + 1 + strategy_slope_bars; ++shift)
     {
      const double h = iHigh(_Symbol, _Period, shift);
      const double l = iLow(_Symbol, _Period, shift);
      if(h <= 0.0 || l <= 0.0)
         return false;
      prior_high = MathMax(prior_high, h);
      prior_low = MathMin(prior_low, l);
     }

   const double channel_width = channel_high - channel_low;
   // FIX (rework v2): channel_width is the high-low range accumulated over
   // strategy_channel_lookback bars; ATR is a single-bar quantity. A flat/compressed
   // N-bar range scales ~sqrt(N)*ATR, so gate against sqrt(lookback)*ATR rather than
   // raw ATR. With lookback=20, ratio=1.20 this admits channels up to ~5.4*ATR wide —
   // i.e. genuinely compressed ranges — instead of the unreachable ~1.2*ATR.
   const double flat_width_max = strategy_flat_atr_ratio * MathSqrt((double)strategy_channel_lookback) * atr;
   if(channel_width <= 0.0 || channel_width > flat_width_max)
      return false;
   if(MathAbs(channel_high - prior_high) > strategy_max_slope_atr * atr ||
      MathAbs(channel_low - prior_low) > strategy_max_slope_atr * atr)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   if(close_1 <= 0.0)
      return false;

   const double breakout_indent = strategy_breakout_atr_indent * atr;
   if(close_1 > channel_high + breakout_indent)
     {
      req.type = QM_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl = QM_StopRulesNormalizePrice(_Symbol, channel_low);
      req.reason = "FLAT_CHAN_LONG";
     }
   else if(close_1 < channel_low - breakout_indent)
     {
      req.type = QM_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl = QM_StopRulesNormalizePrice(_Symbol, channel_high);
      req.reason = "FLAT_CHAN_SHORT";
     }
   else
      return false;

   if(req.price <= 0.0 || req.sl <= 0.0)
      return false;

   const double risk_distance = MathAbs(req.price - req.sl);
   if(risk_distance <= 0.0)
      return false;
   if((req.type == QM_BUY && req.sl >= req.price) ||
      (req.type == QM_SELL && req.sl <= req.price))
      return false;

   double tp_distance = MathMax(channel_width, strategy_min_tp_r * risk_distance);
   tp_distance = MathMin(tp_distance, strategy_max_tp_r * risk_distance);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, req.price, tp_distance);

   return (req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0 || strategy_time_stop_min_r <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   const int hold_seconds = strategy_time_stop_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(magic <= 0 || hold_seconds <= 0)
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

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at <= 0 || TimeCurrent() - opened_at < hold_seconds)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || sl <= 0.0)
         continue;

      const double risk_distance = MathAbs(open_price - sl);
      if(risk_distance <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && bid - open_price < strategy_time_stop_min_r * risk_distance)
            return true;
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && open_price - ask < strategy_time_stop_min_r * risk_distance)
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
