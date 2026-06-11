#property strict
#property version   "5.0"
#property description "QM5_9705 ForexFactory Simple 1 EMA M15"

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
input int    qm_ea_id                   = 9705;
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
input int    strategy_ema_period        = 9;
input int    strategy_atr_period        = 14;
input int    strategy_setup_expiry_bars = 4;
input double strategy_pullaway_pips     = 5.0;
input double strategy_sl_buffer_pips    = 1.0;
input double strategy_min_sl_pips       = 10.0;
input double strategy_gap_atr_mult      = 0.35;
input int    strategy_slope_bars        = 5;
input double strategy_slope_atr_mult    = 0.10;
input double strategy_rr_target         = 2.0;
input int    strategy_max_hold_bars     = 20;
input int    strategy_session_start_h   = 7;
input int    strategy_session_end_h     = 20;
input double strategy_max_spread_pips   = 3.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
   if(point <= 0.0 || pip <= 0.0)
      return true;

   if(strategy_max_spread_pips > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0 || (ask - bid) > strategy_max_spread_pips * pip)
         return true;
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_h));
   const int end_h = MathMax(0, MathMin(23, strategy_session_end_h));
   if(start_h == end_h)
      return false;
   if(start_h < end_h)
      return (dt.hour < start_h || dt.hour >= end_h);
   return (dt.hour < start_h && dt.hour >= end_h);
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

   if(strategy_ema_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_setup_expiry_bars <= 0 ||
      strategy_slope_bars <= 0 ||
      strategy_rr_target <= 0.0)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int bars_needed = MathMax(strategy_setup_expiry_bars + 2, strategy_slope_bars + 2);
   if(CopyRates(_Symbol, PERIOD_M15, 0, bars_needed, bars) != bars_needed) // perf-allowed: bounded closed-bar candle confirmation inside framework new-bar gate.
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || pip <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double ema_candidate = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_period, 1);
   const double ema_slope_ref = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_period, 1 + strategy_slope_bars);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(ema_candidate <= 0.0 || ema_slope_ref <= 0.0 || atr <= 0.0)
      return false;

   if(MathAbs(ema_candidate - ema_slope_ref) < strategy_slope_atr_mult * atr)
      return false;

   if(MathAbs(bars[0].open - bars[1].close) > strategy_gap_atr_mult * atr)
      return false;

   bool long_setup = false;
   bool short_setup = false;
   for(int shift = 2; shift <= strategy_setup_expiry_bars + 1; ++shift)
     {
      const double ema_setup = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_period, shift);
      if(ema_setup <= 0.0)
         continue;
      if(bars[shift].close > ema_setup)
         long_setup = true;
      if(bars[shift].close < ema_setup)
         short_setup = true;
     }

   const double pullaway = strategy_pullaway_pips * pip;
   const double sl_buffer = strategy_sl_buffer_pips * pip;
   const double spread = MathMax(0.0, ask - bid);

   if(long_setup &&
      bars[1].low >= ema_candidate + pullaway &&
      bars[1].close > bars[2].high)
     {
      const double entry = ask;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, bars[1].low - sl_buffer - spread);
      if(sl <= 0.0 || (entry - sl) / pip < strategy_min_sl_pips)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_rr_target);
      if(tp <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "FF_SIMPLE1EMA_LONG";
      return true;
     }

   if(short_setup &&
      bars[1].high <= ema_candidate - pullaway &&
      bars[1].close < bars[2].low)
     {
      const double entry = bid;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, bars[1].high + sl_buffer + spread);
      if(sl <= 0.0 || (sl - entry) / pip < strategy_min_sl_pips)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_rr_target);
      if(tp <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = entry;
      req.sl = sl;
      req.tp = tp;
      req.reason = "FF_SIMPLE1EMA_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   if(CopyRates(_Symbol, PERIOD_M15, 1, 1, bar) != 1) // perf-allowed: O(1) closed-bar EMA recross exit check.
      return false;

   const double ema = QM_EMA(_Symbol, PERIOD_M15, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_M15);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(hold_seconds > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened > 0 && TimeCurrent() - opened >= hold_seconds)
            return true;
        }

      const ENUM_POSITION_TYPE side = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(side == POSITION_TYPE_BUY && bar[0].close < ema)
         return true;
      if(side == POSITION_TYPE_SELL && bar[0].close > ema)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // Defer to the central framework news filter for the P8 callable hook.
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
