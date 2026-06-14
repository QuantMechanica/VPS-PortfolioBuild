#property strict
#property version   "5.0"
#property description "QM5_10895 Brown Bollinger Breakout Confirmation"

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
input int    qm_ea_id                   = 10895;
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
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 2.0;
input int    strategy_ema_fast_period    = 10;
input int    strategy_ema_slow_period    = 50;
input double strategy_psar_step          = 0.02;
input double strategy_psar_maximum       = 0.20;
input int    strategy_macd_fast          = 12;
input int    strategy_macd_slow          = 26;
input int    strategy_macd_signal        = 9;
input int    strategy_rsi_period         = 14;
input double strategy_rsi_midline        = 50.0;
input int    strategy_stoch_k            = 5;
input int    strategy_stoch_d            = 3;
input int    strategy_stoch_slowing      = 3;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 0.8;
input int    strategy_sl_min_pips        = 15;
input double strategy_tp_atr_mult        = 1.2;
input int    strategy_tp_min_pips        = 20;
input int    strategy_max_hold_bars      = 24;
input int    strategy_session_start_hour = 13;
input int    strategy_session_end_hour   = 17;
input double strategy_max_spread_stop_fraction = 0.20;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   if(magic > 0)
     {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) == magic)
            return false;
        }
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool in_session = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         in_session = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
      else
         in_session = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
     }
   if(!in_session)
      return true;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double min_stop = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_min_pips);
   if(atr <= 0.0 || min_stop <= 0.0)
      return true;

   const double stop_distance = MathMax(strategy_sl_atr_mult * atr, min_stop);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(stop_distance <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread = ask - bid;
   if(spread > stop_distance * strategy_max_spread_stop_fraction)
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

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool in_session = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         in_session = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
      else
         in_session = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
     }
   if(!in_session)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close_1 = iClose(_Symbol, tf, 1); // perf-allowed: single closed-bar close; no QM OHLC reader exists.
   if(close_1 <= 0.0)
      return false;

   const double upper = QM_BB_Upper(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower = QM_BB_Lower(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double middle = QM_BB_Middle(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double ema_fast = QM_EMA(_Symbol, tf, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, tf, strategy_ema_slow_period, 1);
   const double sar = QM_SAR(_Symbol, tf, strategy_psar_step, strategy_psar_maximum, 1);
   const double macd_main = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal = QM_MACD_Signal(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double stoch_k = QM_Stoch_K(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);

   if(upper <= 0.0 || lower <= 0.0 || middle <= 0.0 || ema_fast <= 0.0 ||
      ema_slow <= 0.0 || sar <= 0.0 || rsi <= 0.0)
      return false;

   const double macd_hist = macd_main - macd_signal;
   const bool long_signal =
      close_1 > upper &&
      close_1 > ema_fast &&
      close_1 > middle &&
      close_1 > ema_slow &&
      sar < close_1 &&
      macd_hist > 0.0 &&
      rsi > strategy_rsi_midline &&
      stoch_k > stoch_d;

   const bool short_signal =
      close_1 < lower &&
      close_1 < ema_fast &&
      close_1 < middle &&
      close_1 < ema_slow &&
      sar > close_1 &&
      macd_hist < 0.0 &&
      rsi < strategy_rsi_midline &&
      stoch_k < stoch_d;

   if(!long_signal && !short_signal)
      return false;

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double min_stop = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_min_pips);
   const double min_take = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_min_pips);
   if(atr <= 0.0 || min_stop <= 0.0 || min_take <= 0.0)
      return false;

   const double stop_distance = MathMax(strategy_sl_atr_mult * atr, min_stop);
   const double take_distance = MathMax(strategy_tp_atr_mult * atr, min_take);
   if(stop_distance <= 0.0 || take_distance <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, stop_distance);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, take_distance);
   req.reason = long_signal ? "BROWN_BB_BREAK_LONG" : "BROWN_BB_BREAK_SHORT";
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial-close rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(hold_seconds <= 0)
      return false;

   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
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
