#property strict
#property version   "5.0"
#property description "QM5_11214 ClucMay Bollinger volume reversal"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 11214;
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
input int    strategy_bb_period           = 20;
input double strategy_bb_deviation        = 2.0;
input double strategy_bb_lower_mult       = 0.985;
input int    strategy_ema_period          = 50;
input int    strategy_volume_mean_bars    = 30;
input double strategy_volume_mean_mult    = 20.0;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_max_stop_pct        = 0.05;
input double strategy_roi_target          = 0.01;
input double strategy_max_spread_stop_frac = 0.06;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: the framework owns the news and Friday-close gates.
   // The card is explicitly M5; parameter and quote guards fail closed while
   // allowing the zero modeled spread used by Darwinex custom symbols.
   if(_Period != PERIOD_M5)
      return true;
   if(strategy_bb_period < 2 || strategy_bb_deviation <= 0.0 ||
      strategy_bb_lower_mult <= 0.0 || strategy_ema_period < 2 ||
      strategy_volume_mean_bars < 1 || strategy_volume_mean_bars > 1000 ||
      strategy_volume_mean_mult <= 0.0 || strategy_atr_period < 2 ||
      strategy_atr_sl_mult <= 0.0 || strategy_max_stop_pct <= 0.0 ||
      strategy_max_stop_pct >= 1.0 || strategy_roi_target <= 0.0 ||
      strategy_max_spread_stop_frac < 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
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
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M5)
      return false;

   // Trade Entry: read the signal bar plus the preceding volume baseline once
   // per framework-gated closed bar. Array bounds are proven against the
   // runtime destination size before every indexed access.
   const int bars_needed = strategy_volume_mean_bars + 1;
   if(bars_needed <= 1 || bars_needed > 1001)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, bars_needed, rates); // perf-allowed: bounded tick-volume port inside the framework QM_IsNewBar-gated entry hook.
   const int rate_count = ArraySize(rates);
   if(copied != bars_needed || rate_count != bars_needed || rate_count <= 0)
      return false;
   if(rates[0].close <= 0.0 || rates[0].tick_volume <= 0)
      return false;

   double prior_volume_sum = 0.0;
   for(int i = 1; i < ArraySize(rates); ++i)
     {
      if(rates[i].tick_volume <= 0)
         return false;
      prior_volume_sum += (double)rates[i].tick_volume;
     }
   const double prior_volume_mean = prior_volume_sum / (double)strategy_volume_mean_bars;
   if(prior_volume_mean <= 0.0 ||
      (double)rates[0].tick_volume >= prior_volume_mean * strategy_volume_mean_mult)
      return false;

   const double close_1 = rates[0].close;
   const double ema_1 = QM_EMA(_Symbol, PERIOD_M5, strategy_ema_period, 1, PRICE_CLOSE);
   const double lower_1 = QM_BB_Lower(_Symbol, PERIOD_M5, strategy_bb_period,
                                       strategy_bb_deviation, 1, PRICE_TYPICAL);
   if(ema_1 <= 0.0 || lower_1 <= 0.0 ||
      ema_1 == EMPTY_VALUE || lower_1 == EMPTY_VALUE)
      return false;
   if(close_1 >= ema_1 || close_1 >= strategy_bb_lower_mult * lower_1)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || bid <= 0.0)
      return false;

   const double atr_stop = QM_StopATR(_Symbol, QM_BUY, entry,
                                      strategy_atr_period, strategy_atr_sl_mult);
   const double source_stop = QM_StopRulesNormalizePrice(
      _Symbol, entry * (1.0 - strategy_max_stop_pct));
   if(atr_stop <= 0.0 || atr_stop >= entry || source_stop <= 0.0)
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol, MathMax(atr_stop, source_stop));
   const double stop_distance = entry - sl;
   if(sl <= 0.0 || stop_distance <= 0.0)
      return false;

   // A zero tester spread is valid. Block only a genuinely positive spread
   // wider than the card's six-percent share of planned stop distance.
   if(entry > bid && strategy_max_spread_stop_frac > 0.0 &&
      (entry - bid) > strategy_max_spread_stop_frac * stop_distance)
      return false;

   const double tp = QM_StopRulesNormalizePrice(
      _Symbol, entry * (1.0 + strategy_roi_target));
   if(tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "FT_CLUCMAY_BB_VOLUME_LONG";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: no trailing, partial close, break-even, or pyramiding
   // is authorized. The initial SL/TP and framework guard rails remain active.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: the source closes a long after a closed bar recovers above
   // the Bollinger middle band. The 1% ROI target remains server-side in req.tp.
   const int magic = QM_FrameworkMagic();
   bool has_long = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         has_long = true;
      break;
     }
   if(!has_long)
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: fixed closed-bar source exit, evaluated only while this magic owns a position.
   const double middle_1 = QM_BB_Middle(_Symbol, PERIOD_M5, strategy_bb_period,
                                         strategy_bb_deviation, 1, PRICE_TYPICAL);
   if(close_1 <= 0.0 || middle_1 <= 0.0 || middle_1 == EMPTY_VALUE)
      return false;
   return (close_1 > middle_1);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override; the central two-axis high-
   // impact pause remains callable for P8 and gates entries only.
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
