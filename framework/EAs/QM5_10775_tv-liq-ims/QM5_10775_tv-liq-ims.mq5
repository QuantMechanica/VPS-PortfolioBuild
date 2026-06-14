#property strict
#property version   "5.0"
#property description "QM5_10775 TradingView Liquidity Internal Market Shift"

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
input int    qm_ea_id                   = 10775;
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
input int    strategy_liquidity_lookback = 5;
input int    strategy_internal_lookback  = 2;
input int    strategy_structure_scan_bars = 80;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_buffer    = 0.50;
input double strategy_rr_target          = 2.00;
input int    strategy_mode               = 0;     // 0=both, 1=bullish only, 2=bearish only
input int    strategy_session_start_hour = 7;
input int    strategy_session_end_hour   = 21;
input int    strategy_max_spread_points  = 500;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   bool in_session = false;
   if(strategy_session_start_hour == strategy_session_end_hour)
      in_session = true;
   else if(strategy_session_start_hour < strategy_session_end_hour)
      in_session = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
   else
      in_session = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
   if(!in_session)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_points = (ask - bid) / point;
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
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

   if(strategy_liquidity_lookback < 1 ||
      strategy_internal_lookback < 1 ||
      strategy_structure_scan_bars < 10 ||
      strategy_atr_period < 1 ||
      strategy_atr_stop_buffer <= 0.0 ||
      strategy_rr_target <= 0.0)
      return false;

   int max_lr = strategy_liquidity_lookback;
   if(strategy_internal_lookback > max_lr)
      max_lr = strategy_internal_lookback;

   const int bars_needed = strategy_structure_scan_bars + max_lr + 3;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 0, bars_needed, rates); // perf-allowed: bounded pivot/liquidity scan inside framework QM_IsNewBar-gated Strategy_EntrySignal.
   if(copied < bars_needed)
      return false;

   double liquidity_low = 0.0;
   double liquidity_high = 0.0;
   for(int s = strategy_liquidity_lookback + 1; s < copied - strategy_liquidity_lookback; ++s)
     {
      bool is_low = true;
      bool is_high = true;
      for(int j = 1; j <= strategy_liquidity_lookback; ++j)
        {
         if(rates[s].low >= rates[s - j].low || rates[s].low >= rates[s + j].low)
            is_low = false;
         if(rates[s].high <= rates[s - j].high || rates[s].high <= rates[s + j].high)
            is_high = false;
        }
      if(liquidity_low <= 0.0 && is_low)
         liquidity_low = rates[s].low;
      if(liquidity_high <= 0.0 && is_high)
         liquidity_high = rates[s].high;
      if(liquidity_low > 0.0 && liquidity_high > 0.0)
         break;
     }

   double internal_pivot_high = 0.0;
   double internal_pivot_low = 0.0;
   for(int s = strategy_internal_lookback + 1; s < copied - strategy_internal_lookback; ++s)
     {
      bool is_pivot_high = true;
      bool is_pivot_low = true;
      for(int j = 1; j <= strategy_internal_lookback; ++j)
        {
         if(rates[s].high <= rates[s - j].high || rates[s].high <= rates[s + j].high)
            is_pivot_high = false;
         if(rates[s].low >= rates[s - j].low || rates[s].low >= rates[s + j].low)
            is_pivot_low = false;
        }
      if(internal_pivot_high <= 0.0 && is_pivot_high)
         internal_pivot_high = rates[s].high;
      if(internal_pivot_low <= 0.0 && is_pivot_low)
         internal_pivot_low = rates[s].low;
      if(internal_pivot_high > 0.0 && internal_pivot_low > 0.0)
         break;
     }

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double close1 = rates[1].close;
   const bool bullish_allowed = (strategy_mode == 0 || strategy_mode == 1);
   const bool bearish_allowed = (strategy_mode == 0 || strategy_mode == 2);

   const bool touched_low = (liquidity_low > 0.0 && rates[1].low <= liquidity_low && rates[1].high >= liquidity_low);
   const bool bullish_shift = (internal_pivot_high > 0.0 && close1 > internal_pivot_high);
   if(bullish_allowed && touched_low && bullish_shift)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, liquidity_low - (atr * strategy_atr_stop_buffer));
      if(req.sl <= 0.0 || req.sl >= ask)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr_target);
      if(req.tp <= ask)
         return false;
      req.reason = "LIQ_LOW_BULLISH_IMS";
      return true;
     }

   const bool touched_high = (liquidity_high > 0.0 && rates[1].high >= liquidity_high && rates[1].low <= liquidity_high);
   const bool bearish_shift = (internal_pivot_low > 0.0 && close1 < internal_pivot_low);
   if(bearish_allowed && touched_high && bearish_shift)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, liquidity_high + (atr * strategy_atr_stop_buffer));
      if(req.sl <= 0.0 || req.sl <= bid)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr_target);
      if(req.tp <= 0.0 || req.tp >= bid)
         return false;
      req.reason = "LIQ_HIGH_BEARISH_IMS";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card P2 baseline has no trailing, partial close, or break-even rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card P2 disables optional opposite internal-shift exits; exits are SL/TP plus framework Friday close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return !QM_NewsAllowsTrade2(_Symbol, broker_time, qm_news_temporal, qm_news_compliance);
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
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
