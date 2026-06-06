#property strict
#property version   "5.0"
#property description "QM5_10904 Carter Williams R SMMA Channel"

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
input int    qm_ea_id                   = 10904;
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
input int    strategy_smma_period       = 55;
input int    strategy_wpr_period        = 55;
input double strategy_wpr_long_level    = -25.0;
input double strategy_wpr_short_level   = -75.0;
input int    strategy_stoch_k           = 5;
input int    strategy_stoch_d           = 5;
input int    strategy_stoch_slowing     = 5;
input int    strategy_swing_lookback    = 10;
input int    strategy_stop_buffer_pips  = 2;
input double strategy_take_profit_rr    = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card authorizes only the default V5 spread/session/news filters.
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

   if(strategy_smma_period <= 1 || strategy_wpr_period <= 1 ||
      strategy_stoch_k <= 1 || strategy_stoch_d <= 1 || strategy_stoch_slowing <= 1 ||
      strategy_swing_lookback <= 0 || strategy_take_profit_rr <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close1 = iClose(_Symbol, tf, 1); // perf-allowed: closed-bar source close for card cross/Williams R.
   const double close2 = iClose(_Symbol, tf, 2); // perf-allowed: prior closed-bar source close for card cross/Williams R.
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double smma_high1 = QM_SMMA(_Symbol, tf, strategy_smma_period, 1, PRICE_HIGH);
   const double smma_high2 = QM_SMMA(_Symbol, tf, strategy_smma_period, 2, PRICE_HIGH);
   const double smma_low1 = QM_SMMA(_Symbol, tf, strategy_smma_period, 1, PRICE_LOW);
   const double smma_low2 = QM_SMMA(_Symbol, tf, strategy_smma_period, 2, PRICE_LOW);
   if(smma_high1 <= 0.0 || smma_high2 <= 0.0 || smma_low1 <= 0.0 || smma_low2 <= 0.0)
      return false;

   double highest1 = -DBL_MAX;
   double lowest1 = DBL_MAX;
   double highest2 = -DBL_MAX;
   double lowest2 = DBL_MAX;
   for(int i = 1; i <= strategy_wpr_period; ++i)
     {
      const double high1 = iHigh(_Symbol, tf, i);     // perf-allowed: bounded Williams R window on closed-bar path.
      const double low1 = iLow(_Symbol, tf, i);       // perf-allowed: bounded Williams R window on closed-bar path.
      const double high2 = iHigh(_Symbol, tf, i + 1); // perf-allowed: prior bounded Williams R window on closed-bar path.
      const double low2 = iLow(_Symbol, tf, i + 1);   // perf-allowed: prior bounded Williams R window on closed-bar path.
      if(high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
         return false;
      if(high1 > highest1)
         highest1 = high1;
      if(low1 < lowest1)
         lowest1 = low1;
      if(high2 > highest2)
         highest2 = high2;
      if(low2 < lowest2)
         lowest2 = low2;
     }

   if(highest1 <= lowest1 || highest2 <= lowest2)
      return false;

   const double wpr1 = -100.0 * (highest1 - close1) / (highest1 - lowest1);
   const double wpr2 = -100.0 * (highest2 - close2) / (highest2 - lowest2);
   const double stoch_k = QM_Stoch_K(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);

   const bool long_signal = (close2 <= smma_high2 && close1 > smma_high1 &&
                             wpr2 <= strategy_wpr_long_level && wpr1 > strategy_wpr_long_level &&
                             stoch_k > stoch_d);
   const bool short_signal = (close2 >= smma_low2 && close1 < smma_low1 &&
                              wpr2 >= strategy_wpr_short_level && wpr1 < strategy_wpr_short_level &&
                              stoch_k < stoch_d);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry_price = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   double sl = QM_StopStructure(_Symbol, side, entry_price, strategy_swing_lookback);
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_buffer_pips);
   if(sl <= 0.0 || buffer < 0.0)
      return false;
   sl = long_signal ? (sl - buffer) : (sl + buffer);
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry_price, sl, strategy_take_profit_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = entry_price;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "CARTER_WPR_SMMA_LONG" : "CARTER_WPR_SMMA_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_smma_period <= 1)
      return false;

   const int magic = QM_FrameworkMagic();
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close1 = iClose(_Symbol, tf, 1); // perf-allowed: closed-bar channel-close exit check.
   if(close1 <= 0.0)
      return false;

   const double smma_high = QM_SMMA(_Symbol, tf, strategy_smma_period, 1, PRICE_HIGH);
   const double smma_low = QM_SMMA(_Symbol, tf, strategy_smma_period, 1, PRICE_LOW);
   if(smma_high <= 0.0 || smma_low <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && close1 < smma_high)
         return true;
      if(pos_type == POSITION_TYPE_SELL && close1 > smma_low)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to framework news handling.
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
