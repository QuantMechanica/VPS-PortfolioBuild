#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
input int    qm_ea_id                   = 12433;
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
input int    strategy_tenkan_period          = 30;
input int    strategy_kijun_period           = 10;
input int    strategy_senkou_period          = 30;
input int    strategy_signal_shift           = 1;
input int    strategy_prior_state_bars       = 2;
input int    strategy_slope_lookback_bars    = 3;
input double strategy_open_level             = 0.001;
input int    strategy_stop_loss_pips         = 80;
input int    strategy_take_profit_pips       = 80;
input int    strategy_close_time_bars        = 30;
input int    strategy_max_spread_pips        = 4;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_tenkan_period <= 0 ||
      strategy_kijun_period <= 0 ||
      strategy_senkou_period <= 0 ||
      strategy_signal_shift < 1 ||
      strategy_prior_state_bars < 1 ||
      strategy_slope_lookback_bars < 1 ||
      strategy_open_level < 0.0 ||
      strategy_stop_loss_pips <= 0 ||
      strategy_take_profit_pips <= 0 ||
      strategy_close_time_bars <= 0 ||
      strategy_max_spread_pips <= 0)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   const double max_spread =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(max_spread <= 0.0)
      return true;

   // .DWX tester quotes may have ask == bid. Only a genuinely wide,
   // positive spread blocks entry.
   if(ask > bid && (ask - bid) > max_spread)
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

   const int signal_shift = strategy_signal_shift;
   const int prior_shift = signal_shift + strategy_prior_state_bars;
   const int slope_shift = signal_shift + strategy_slope_lookback_bars;

   const double tenkan_signal =
      QM_Ichimoku_TenkanSen(_Symbol, (ENUM_TIMEFRAMES)_Period,
                            strategy_tenkan_period, strategy_kijun_period,
                            strategy_senkou_period, signal_shift);
   const double kijun_signal =
      QM_Ichimoku_KijunSen(_Symbol, (ENUM_TIMEFRAMES)_Period,
                           strategy_tenkan_period, strategy_kijun_period,
                           strategy_senkou_period, signal_shift);
   const double tenkan_prior =
      QM_Ichimoku_TenkanSen(_Symbol, (ENUM_TIMEFRAMES)_Period,
                            strategy_tenkan_period, strategy_kijun_period,
                            strategy_senkou_period, prior_shift);
   const double kijun_prior =
      QM_Ichimoku_KijunSen(_Symbol, (ENUM_TIMEFRAMES)_Period,
                           strategy_tenkan_period, strategy_kijun_period,
                           strategy_senkou_period, prior_shift);
   const double tenkan_slope_reference =
      QM_Ichimoku_TenkanSen(_Symbol, (ENUM_TIMEFRAMES)_Period,
                            strategy_tenkan_period, strategy_kijun_period,
                            strategy_senkou_period, slope_shift);
   const double chikou_signal =
      QM_Ichimoku_ChikouSpan(_Symbol, (ENUM_TIMEFRAMES)_Period,
                             strategy_tenkan_period, strategy_kijun_period,
                             strategy_senkou_period, signal_shift);
   const double senkou_a_signal =
      QM_Ichimoku_SenkouSpanA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                              strategy_tenkan_period, strategy_kijun_period,
                              strategy_senkou_period, signal_shift);
   const double senkou_b_signal =
      QM_Ichimoku_SenkouSpanB(_Symbol, (ENUM_TIMEFRAMES)_Period,
                              strategy_tenkan_period, strategy_kijun_period,
                              strategy_senkou_period, signal_shift);

   if(tenkan_signal <= 0.0 ||
      kijun_signal <= 0.0 ||
      tenkan_prior <= 0.0 ||
      kijun_prior <= 0.0 ||
      tenkan_slope_reference <= 0.0 ||
      chikou_signal <= 0.0 ||
      senkou_a_signal <= 0.0 ||
      senkou_b_signal <= 0.0)
      return false;

   const bool long_signal =
      tenkan_signal > kijun_signal &&
      tenkan_prior < kijun_prior &&
      chikou_signal < tenkan_signal &&
      senkou_a_signal > senkou_b_signal &&
      (tenkan_signal - tenkan_slope_reference) >= strategy_open_level;
   const bool short_signal =
      tenkan_signal < kijun_signal &&
      tenkan_prior > kijun_prior &&
      chikou_signal > tenkan_signal &&
      senkou_a_signal < senkou_b_signal &&
      (tenkan_slope_reference - tenkan_signal) >= strategy_open_level;

   if(!long_signal && !short_signal)
      return false;

   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(long_signal)
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_price <= 0.0)
      return false;

   if(long_signal)
      req.type = QM_BUY;
   else
      req.type = QM_SELL;
   req.sl = QM_StopFixedPips(_Symbol, req.type, entry_price,
                             strategy_stop_loss_pips);
   const double take_rr =
      (double)strategy_take_profit_pips / (double)strategy_stop_loss_pips;
   req.tp = QM_TakeRR(_Symbol, req.type, entry_price, req.sl, take_rr);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = long_signal
                ? "ICHI_TK_CLOUD_LONG"
                : "ICHI_TK_CLOUD_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // The approved card specifies fixed SL/TP and no trailing, partial-close,
   // break-even, or scale-in rule.
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
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime entry_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      const int period_seconds =
         PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(entry_time > 0 &&
         period_seconds > 0 &&
         (TimeCurrent() - entry_time) >=
            (strategy_close_time_bars * period_seconds))
         return true;

      const int signal_shift = strategy_signal_shift;
      const int prior_shift =
         signal_shift + strategy_prior_state_bars;
      const double tenkan_signal =
         QM_Ichimoku_TenkanSen(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_tenkan_period,
                               strategy_kijun_period,
                               strategy_senkou_period,
                               signal_shift);
      const double kijun_signal =
         QM_Ichimoku_KijunSen(_Symbol, (ENUM_TIMEFRAMES)_Period,
                              strategy_tenkan_period,
                              strategy_kijun_period,
                              strategy_senkou_period,
                              signal_shift);
      const double tenkan_prior =
         QM_Ichimoku_TenkanSen(_Symbol, (ENUM_TIMEFRAMES)_Period,
                               strategy_tenkan_period,
                               strategy_kijun_period,
                               strategy_senkou_period,
                               prior_shift);
      const double kijun_prior =
         QM_Ichimoku_KijunSen(_Symbol, (ENUM_TIMEFRAMES)_Period,
                              strategy_tenkan_period,
                              strategy_kijun_period,
                              strategy_senkou_period,
                              prior_shift);
      if(tenkan_signal <= 0.0 ||
         kijun_signal <= 0.0 ||
         tenkan_prior <= 0.0 ||
         kijun_prior <= 0.0)
         return false;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY)
         return tenkan_signal < kijun_signal &&
                tenkan_prior > kijun_prior;
      if(position_type == POSITION_TYPE_SELL)
         return tenkan_signal > kijun_signal &&
                tenkan_prior < kijun_prior;
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
