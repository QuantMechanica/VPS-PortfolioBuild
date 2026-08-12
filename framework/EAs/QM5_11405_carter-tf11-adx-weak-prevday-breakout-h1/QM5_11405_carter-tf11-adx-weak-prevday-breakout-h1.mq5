#property strict
#property version   "5.0"
#property description "QM5_11405 Carter TF11 ADX-weak previous-day breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy Card: QM5_11405 Carter TF#11, OWNER-approved at G0.
// The five Strategy_* hooks below are the only strategy-specific code.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11405;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection in ordinary backtests.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_adx_period          = 14;
input double strategy_adx_weak_threshold  = 35.0;
input int    strategy_breakout_buffer_pips = 15;
input int    strategy_sl_pips             = 30;
input int    strategy_tp_pips             = 60;
input int    strategy_be_trigger_pips     = 30;
input int    strategy_spread_cap_pips     = 20;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter: block invalid quotes or a genuinely wide spread. Darwinex
// .DWX tester quotes may have ask == bid, so zero modeled spread remains valid.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                              strategy_spread_cap_pips);
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Trade Entry: the caller has consumed the single framework H1 new-bar event.
// The card's [0] signal is therefore evaluated on the last completed H1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Only one untriggered stop order may remain active for this EA/symbol.
   const int order_count = OrdersTotal();
   for(int i = 0; i < order_count; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      return false;
     }

   const double adx = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   if(adx <= 0.0 || adx >= strategy_adx_weak_threshold)
      return false;

   // perf-allowed: card-authorized structural D1/H1 extremes, read only after
   // the framework closed-bar gate and never scanned in a warmup loop.
   const double previous_day_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double previous_day_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed
   const double signal_bar_high   = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed
   const double signal_bar_low    = iLow(_Symbol, PERIOD_H1, 1);  // perf-allowed
   if(previous_day_high <= 0.0 || previous_day_low <= 0.0 ||
      previous_day_high <= previous_day_low ||
      signal_bar_high <= 0.0 || signal_bar_low <= 0.0)
      return false;

   const double breakout_buffer =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_buffer_pips);
   const double take_distance =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   if(breakout_buffer <= 0.0 || take_distance <= 0.0)
      return false;

   const bool long_setup =
      (signal_bar_low < previous_day_low - breakout_buffer);
   const bool short_setup =
      (signal_bar_high > previous_day_high + breakout_buffer);

   // A single hook returns one request. An exceptional bar spanning both
   // thresholds is directionally ambiguous, so it does not arm either side.
   if(long_setup == short_setup)
      return false;

   const datetime broker_now = TimeCurrent();
   MqlDateTime broker_parts;
   TimeToStruct(broker_now, broker_parts);
   int expiration_seconds = 86400 -
      (broker_parts.hour * 3600 + broker_parts.min * 60 + broker_parts.sec);
   if(expiration_seconds < 60)
      expiration_seconds = 60;

   if(long_setup)
     {
      const double entry = QM_StopRulesNormalizePrice(
         _Symbol, previous_day_high + breakout_buffer);
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY_STOP, entry,
                                          strategy_sl_pips);
      const double tp = QM_StopRulesNormalizePrice(_Symbol,
                                                    entry + take_distance);
      if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
         return false;

      req.type               = QM_BUY_STOP;
      req.price              = entry;
      req.sl                 = sl;
      req.tp                 = tp;
      req.reason             = "carter_tf11_false_breakdown_long";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = expiration_seconds;
      return true;
     }

   const double entry = QM_StopRulesNormalizePrice(
      _Symbol, previous_day_low - breakout_buffer);
   const double sl = QM_StopFixedPips(_Symbol, QM_SELL_STOP, entry,
                                       strategy_sl_pips);
   const double tp = QM_StopRulesNormalizePrice(_Symbol,
                                                 entry - take_distance);
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   req.type               = QM_SELL_STOP;
   req.price              = entry;
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = "carter_tf11_false_breakout_short";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   return true;
  }

// Trade Management: move the server-side stop to exact break-even after the
// card's +30-pip trigger. Fixed SL and TP remain active at all times.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, 0);
     }
  }

// Trade Close: the card specifies fixed SL/TP plus break-even, with no
// additional signal or time exit for a filled position.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: no strategy-specific override; the framework's callable
// P8/Q09 news gate remains authoritative for new entries.
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
