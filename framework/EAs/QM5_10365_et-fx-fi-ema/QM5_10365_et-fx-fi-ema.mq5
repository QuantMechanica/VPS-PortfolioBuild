#property strict
#property version   "5.0"
#property description "QM5_10365 Elite Trader FX EMA RSI Force Index"

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
input int    qm_ea_id                   = 10365;
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
input int    strategy_fast_ema_period        = 5;
input int    strategy_slow_ema_period        = 12;
input int    strategy_rsi_period             = 14;
input double strategy_rsi_midline            = 50.0;
input int    strategy_force_index_period     = 14;
input int    strategy_stop_pips              = 100;
input int    strategy_target_pips            = 250;
input int    strategy_breakeven_trigger_pips = 80;
input int    strategy_breakeven_buffer_pips  = 0;
input int    strategy_trail_trigger_pips     = 190;
input int    strategy_trail_step_pips        = 100;
input int    strategy_spread_median_bars     = 48;
input double strategy_spread_median_mult     = 2.5;

double g_strategy_spread_median_points = 0.0;

bool Strategy_HasOpenPosition();
double Strategy_RawForceIndex(const int shift);
double Strategy_ForceIndexEma(const int period, const int shift);
void Strategy_UpdateSpreadMedian();
bool Strategy_SpreadBlocked();

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news).
   // News is handled by the framework before this hook; the card has no time gate.
   if(g_strategy_spread_median_points > 0.0 && !Strategy_HasOpenPosition())
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > (long)MathRound(g_strategy_spread_median_points * strategy_spread_median_mult))
         return true;
     }
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_fast_ema_period <= 0 ||
      strategy_slow_ema_period <= strategy_fast_ema_period ||
      strategy_rsi_period <= 0 ||
      strategy_force_index_period <= 0 ||
      strategy_stop_pips <= 0 ||
      strategy_target_pips <= 0)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   Strategy_UpdateSpreadMedian();
   if(Strategy_SpreadBlocked())
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_H1;
   const double fast_1 = QM_EMA(_Symbol, tf, strategy_fast_ema_period, 1);
   const double fast_2 = QM_EMA(_Symbol, tf, strategy_fast_ema_period, 2);
   const double slow_1 = QM_EMA(_Symbol, tf, strategy_slow_ema_period, 1);
   const double slow_2 = QM_EMA(_Symbol, tf, strategy_slow_ema_period, 2);
   const double rsi_1 = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double force_1 = Strategy_ForceIndexEma(strategy_force_index_period, 1);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || slow_1 <= 0.0 || slow_2 <= 0.0 || rsi_1 <= 0.0 || force_1 == 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   bool signal = false;
   if(fast_2 <= slow_2 && fast_1 > slow_1 && rsi_1 > strategy_rsi_midline && force_1 > 0.0)
     {
      side = QM_BUY;
      signal = true;
     }
   else if(fast_2 >= slow_2 && fast_1 < slow_1 && rsi_1 < strategy_rsi_midline && force_1 < 0.0)
     {
      side = QM_SELL;
      signal = true;
     }
   if(!signal)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_stop_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_target_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "QM5_10365_EMA_RSI_FI_LONG" : "QM5_10365_EMA_RSI_FI_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_MoveToBreakEven(ticket, strategy_breakeven_trigger_pips, strategy_breakeven_buffer_pips);
      QM_TM_TrailStep(ticket, strategy_trail_trigger_pips, strategy_trail_step_pips);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close.
   // Card exits are SL, TP, breakeven, trailing stop, and framework Friday close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook (callable for P8 News Impact phase).
   return false; // defer to QM_NewsAllowsTrade(...)
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

double Strategy_RawForceIndex(const int shift)
  {
   const double close_now = iClose(_Symbol, PERIOD_H1, shift);
   const double close_prev = iClose(_Symbol, PERIOD_H1, shift + 1);
   const long volume = iVolume(_Symbol, PERIOD_H1, shift);
   if(close_now <= 0.0 || close_prev <= 0.0 || volume <= 0)
      return 0.0;
   return (close_now - close_prev) * (double)volume;
  }

double Strategy_ForceIndexEma(const int period, const int shift)
  {
   const int warmup = MathMax(period * 3, period + 2);
   const double alpha = 2.0 / ((double)period + 1.0);
   double ema = Strategy_RawForceIndex(shift + warmup);
   for(int i = shift + warmup - 1; i >= shift; --i)
     {
      const double raw = Strategy_RawForceIndex(i);
      ema = alpha * raw + (1.0 - alpha) * ema;
     }
   return ema;
  }

void Strategy_UpdateSpreadMedian()
  {
   const int bars = MathMax(3, strategy_spread_median_bars);
   double spreads[];
   ArrayResize(spreads, bars);
   int count = 0;
   for(int i = 1; i <= bars; ++i)
     {
      const int sp = iSpread(_Symbol, PERIOD_H1, i);
      if(sp <= 0)
         continue;
      spreads[count] = (double)sp;
      count++;
     }
   if(count <= 0)
      return;
   ArrayResize(spreads, count);
   ArraySort(spreads);
   if((count % 2) == 1)
      g_strategy_spread_median_points = spreads[count / 2];
   else
      g_strategy_spread_median_points = 0.5 * (spreads[(count / 2) - 1] + spreads[count / 2]);
  }

bool Strategy_SpreadBlocked()
  {
   if(g_strategy_spread_median_points <= 0.0 || strategy_spread_median_mult <= 0.0)
      return false;
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points <= 0)
      return false;
   return ((double)spread_points > g_strategy_spread_median_points * strategy_spread_median_mult);
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
