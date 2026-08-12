#property strict
#property version   "5.0"
#property description "QM5_11888 Lien Perfect Order SMA Stack"

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
input int    qm_ea_id                   = 11888;
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
input int    strategy_sma_10                  = 10;
input int    strategy_sma_20                  = 20;
input int    strategy_sma_50                  = 50;
input int    strategy_sma_100                 = 100;
input int    strategy_sma_200                 = 200;
input int    strategy_fresh_lookback_bars     = 60;
input int    strategy_sl_sma50_buffer_pips    = 25;

int    g_perfect_order_state       = 0;
bool   g_perfect_order_fresh       = false;
double g_cached_sma20              = 0.0;
double g_cached_sma50              = 0.0;
bool   g_perfect_order_state_ready = false;

bool Strategy_SMAFromPrefix(const double &prefix[],
                            const int offset,
                            const int period,
                            double &value)
  {
   value = 0.0;
   if(offset < 0 || period <= 0 || offset + period >= ArraySize(prefix))
      return false;

   value = (prefix[offset + period] - prefix[offset]) / (double)period;
   return (value > 0.0);
  }

int Strategy_PerfectOrderStateFromPrefix(const double &prefix[],
                                         const int offset,
                                         double &sma20,
                                         double &sma50)
  {
   double sma10 = 0.0;
   double sma100 = 0.0;
   double sma200 = 0.0;
   sma20 = 0.0;
   sma50 = 0.0;

   if(!Strategy_SMAFromPrefix(prefix, offset, strategy_sma_10, sma10) ||
      !Strategy_SMAFromPrefix(prefix, offset, strategy_sma_20, sma20) ||
      !Strategy_SMAFromPrefix(prefix, offset, strategy_sma_50, sma50) ||
      !Strategy_SMAFromPrefix(prefix, offset, strategy_sma_100, sma100) ||
      !Strategy_SMAFromPrefix(prefix, offset, strategy_sma_200, sma200))
      return 0;

   if(sma10 > sma20 && sma20 > sma50 && sma50 > sma100 && sma100 > sma200)
      return 1;
   if(sma10 < sma20 && sma20 < sma50 && sma50 < sma100 && sma100 < sma200)
      return -1;
   return 0;
  }

bool Strategy_AdvanceStateOnNewBar()
  {
   g_perfect_order_state = 0;
   g_perfect_order_fresh = false;
   g_cached_sma20 = 0.0;
   g_cached_sma50 = 0.0;
   g_perfect_order_state_ready = false;

   if(strategy_sma_10 <= 0 || strategy_sma_20 <= 0 || strategy_sma_50 <= 0 ||
      strategy_sma_100 <= 0 || strategy_sma_200 <= 0 ||
      strategy_fresh_lookback_bars < 1)
      return false;

   int max_period = strategy_sma_10;
   max_period = MathMax(max_period, strategy_sma_20);
   max_period = MathMax(max_period, strategy_sma_50);
   max_period = MathMax(max_period, strategy_sma_100);
   max_period = MathMax(max_period, strategy_sma_200);
   const int close_count = max_period + strategy_fresh_lookback_bars;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, close_count, closes); // perf-allowed: one bounded cache fill per completed D1 bar.
   if(copied < close_count)
      return false;

   double prefix[];
   if(ArrayResize(prefix, close_count + 1) != close_count + 1)
      return false;
   prefix[0] = 0.0;
   for(int i = 0; i < close_count; ++i)
     {
      if(closes[i] <= 0.0)
         return false;
      prefix[i + 1] = prefix[i] + closes[i];
     }

   g_perfect_order_state = Strategy_PerfectOrderStateFromPrefix(prefix,
                                                                0,
                                                                g_cached_sma20,
                                                                g_cached_sma50);
   g_perfect_order_fresh = (g_perfect_order_state != 0);
   for(int offset = 1; offset <= strategy_fresh_lookback_bars && g_perfect_order_fresh; ++offset)
     {
      double prior_sma20 = 0.0;
      double prior_sma50 = 0.0;
      if(Strategy_PerfectOrderStateFromPrefix(prefix, offset, prior_sma20, prior_sma50) ==
         g_perfect_order_state)
         g_perfect_order_fresh = false;
     }

   g_perfect_order_state_ready = true;
   return true;
  }

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

   if(!g_perfect_order_state_ready)
      return false;

   const int direction = g_perfect_order_state;
   if(direction == 0 || !g_perfect_order_fresh)
      return false;

   const double sma50 = g_cached_sma50;
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_sma50_buffer_pips);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(sma50 <= 0.0 || buffer <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return false;

   if(direction > 0)
     {
      const double sl = QM_StopRulesNormalizePrice(_Symbol, sma50 - buffer);
      if(sl <= 0.0 || sl >= ask)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.reason = "PERFECT_ORDER_UP_FRESH";
      return true;
     }

   const double sl = QM_StopRulesNormalizePrice(_Symbol, sma50 + buffer);
   if(sl <= 0.0 || sl <= bid)
      return false;
   req.type = QM_SELL;
   req.sl = sl;
   req.reason = "PERFECT_ORDER_DOWN_FRESH";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!g_perfect_order_state_ready)
      return;

   const double sma20 = g_cached_sma20;
   if(sma20 <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double trail_sl = QM_StopRulesNormalizePrice(_Symbol, sma20);

      if(ptype == POSITION_TYPE_BUY)
        {
         if(trail_sl > 0.0 && trail_sl < bid && (current_sl <= 0.0 || trail_sl > current_sl))
            QM_TM_MoveSL(ticket, trail_sl, "SMA20_TRAIL_LONG");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(trail_sl > 0.0 && trail_sl > ask && (current_sl <= 0.0 || trail_sl < current_sl))
            QM_TM_MoveSL(ticket, trail_sl, "SMA20_TRAIL_SHORT");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!g_perfect_order_state_ready)
      return false;

   const int state = g_perfect_order_state;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && state != 1)
         return true;
      if(ptype == POSITION_TYPE_SELL && state != -1)
         return true;
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
   // Q08 evidence lifecycle: no guard may skip floating-P&L sampling.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   // QM_IsNewBar is single-consume. Latch it once and derive the full SMA
   // stack/freshness window once per completed D1 bar. Entry, exit, and the
   // SMA20 trail then reuse the same closed-bar state on every tick.
   const bool qm_new_bar = QM_IsNewBar();
   if(qm_new_bar)
      Strategy_AdvanceStateOnNewBar();

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
   bool exit_fired_this_tick = false;
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
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            exit_fired_this_tick = true;
        }
     }

   // News blackouts gate new entries only; broker-side protection, trailing,
   // and source exits above remain active during blackout windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!qm_new_bar || exit_fired_this_tick)
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
