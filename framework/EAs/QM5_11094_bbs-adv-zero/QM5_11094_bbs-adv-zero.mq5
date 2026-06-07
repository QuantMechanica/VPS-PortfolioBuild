#property strict
#property version   "5.0"
#property description "QM5_11094 EarnForex Bollinger Squeeze Advanced Zero Cross"

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
input int    qm_ea_id                   = 11094;
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
// EarnForex Bollinger Squeeze Advanced defaults from source indicator.
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H1;
input int             strategy_bb_period       = 20;
input double          strategy_bb_deviation    = 2.0;
input int             strategy_keltner_period  = 20;
input double          strategy_keltner_factor  = 1.5;
input int             strategy_demarker_period = 13;
input int             strategy_atr_period      = 14;
input double          strategy_atr_sl_mult     = 2.0;
input int             strategy_max_hold_bars   = 24;

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

double Strategy_DeMarkerRaw(const int shift)
  {
   const int period = MathMax(1, strategy_demarker_period);
   double up_sum = 0.0;
   double down_sum = 0.0;

   for(int k = 0; k < period; ++k)
     {
      const int bar = shift + k;
      const double high_now = iHigh(_Symbol, strategy_signal_tf, bar);      // perf-allowed: bounded DeMarker formula; no QM_DeMarker reader exists.
      const double high_prev = iHigh(_Symbol, strategy_signal_tf, bar + 1); // perf-allowed: bounded DeMarker formula; no QM_DeMarker reader exists.
      const double low_now = iLow(_Symbol, strategy_signal_tf, bar);        // perf-allowed: bounded DeMarker formula; no QM_DeMarker reader exists.
      const double low_prev = iLow(_Symbol, strategy_signal_tf, bar + 1);   // perf-allowed: bounded DeMarker formula; no QM_DeMarker reader exists.

      if(high_now <= 0.0 || high_prev <= 0.0 || low_now <= 0.0 || low_prev <= 0.0)
         return 0.5;

      const double up = high_now - high_prev;
      if(up > 0.0)
         up_sum += up;

      const double down = low_prev - low_now;
      if(down > 0.0)
         down_sum += down;
     }

   const double denom = up_sum + down_sum;
   if(denom <= 0.0)
      return 0.5;
   return up_sum / denom;
  }

double Strategy_DemarkerHistogram(const int shift)
  {
   return Strategy_DeMarkerRaw(shift) - 0.5;
  }

double Strategy_BbsRatio(const int shift)
  {
   const double std = QM_StdDev(_Symbol, strategy_signal_tf, strategy_bb_period, shift, PRICE_CLOSE, MODE_SMA);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_keltner_period, shift);
   const double denom = atr * strategy_keltner_factor;
   if(std <= 0.0 || denom <= 0.0)
      return 0.0;
   return strategy_bb_deviation * std / denom;
  }

bool Strategy_Trending(const int shift)
  {
   return Strategy_BbsRatio(shift) >= 1.0;
  }

int Strategy_CurrentPositionDir(ulong &out_ticket, datetime &open_time)
  {
   out_ticket = 0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      out_ticket = ticket;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }

   return 0;
  }

bool Strategy_BuildEntry(const QM_OrderType side, const string reason, QM_EntryRequest &req)
  {
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — card has no bespoke session or regime filter. Framework
// handles time, spread, news, kill-switch, and Friday close.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry — evaluated once per completed bar by the framework. The source
// signal is DeMarker(13)-0.5 crossing zero while BB/Keltner trending state is on.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const bool trend1 = Strategy_Trending(1);
   const double d1 = Strategy_DemarkerHistogram(1);
   const double d2 = Strategy_DemarkerHistogram(2);

   const bool cross_up = (d2 <= 0.0 && d1 > 0.0);
   const bool cross_down = (d2 >= 0.0 && d1 < 0.0);

   ulong ticket = 0;
   datetime open_time = 0;
   int dir = Strategy_CurrentPositionDir(ticket, open_time);

   if(dir > 0 && (!trend1 || cross_down))
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      dir = 0;
     }
   else if(dir < 0 && (!trend1 || cross_up))
     {
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      dir = 0;
     }

   if(!trend1)
      return false;

   if(cross_up && dir <= 0)
      return Strategy_BuildEntry(QM_BUY, "bbs_adv_demarker_zero_cross_long", req);

   if(cross_down && dir >= 0)
      return Strategy_BuildEntry(QM_SELL, "bbs_adv_demarker_zero_cross_short", req);

   return false;
  }

// Trade Management — card specifies a fixed catastrophic ATR stop only.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — zero-cross and trend-state exits are processed on the next
// completed bar in Strategy_EntrySignal; this hook enforces the 24-bar time stop.
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime open_time = 0;
   if(Strategy_CurrentPositionDir(ticket, open_time) == 0 || open_time <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_signal_tf);
   if(seconds_per_bar <= 0)
      return false;

   return (TimeCurrent() - open_time) >= (strategy_max_hold_bars * seconds_per_bar);
  }

// News Filter Hook — defer to the central P8-capable news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
