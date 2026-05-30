#property strict
#property version   "5.0"
#property description "QM5_10222 TradingView BBSR JMA ATR"

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
input int    qm_ea_id                   = 10222;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H1;
input int             strategy_bb_period       = 20;
input double          strategy_bb_deviation    = 2.0;
input int             strategy_stoch_k_period  = 14;
input int             strategy_stoch_d_period  = 3;
input int             strategy_stoch_slowing   = 3;
input double          strategy_stoch_oversold  = 20.0;
input double          strategy_stoch_overbought= 80.0;
input int             strategy_jma_proxy_period= 55;
input int             strategy_atr_period      = 14;
input double          strategy_atr_trail_mult  = 3.0;
input bool            strategy_skip_overnight  = true;
input int             strategy_skip_start_hour = 22;
input int             strategy_skip_end_hour   = 2;
input double          strategy_max_spread_atr  = 0.10;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_skip_overnight)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(strategy_skip_start_hour < strategy_skip_end_hour)
        {
         if(dt.hour >= strategy_skip_start_hour && dt.hour < strategy_skip_end_hour)
            return true;
        }
      else if(strategy_skip_start_hour > strategy_skip_end_hour)
        {
         if(dt.hour >= strategy_skip_start_hour || dt.hour < strategy_skip_end_hour)
            return true;
        }
     }

   if(strategy_max_spread_atr > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
      if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0 || ask < bid)
         return true;
      if((ask - bid) > strategy_max_spread_atr * atr)
         return true;
     }

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

   if(strategy_bb_period <= 1 || strategy_bb_deviation <= 0.0 ||
      strategy_stoch_k_period <= 1 || strategy_stoch_d_period <= 0 ||
      strategy_stoch_slowing <= 0 || strategy_stoch_oversold <= 0.0 ||
      strategy_stoch_overbought <= strategy_stoch_oversold ||
      strategy_jma_proxy_period < 4 || strategy_atr_period <= 0 ||
      strategy_atr_trail_mult <= 0.0)
      return false;

   const int warmup = MathMax(strategy_bb_period, MathMax(strategy_stoch_k_period, strategy_jma_proxy_period)) + 5;
   if(Bars(_Symbol, strategy_signal_tf) < warmup)
      return false;

   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double close2 = iClose(_Symbol, strategy_signal_tf, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double lower1 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower2 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double upper1 = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper2 = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double k1 = QM_Stoch_K(_Symbol, strategy_signal_tf, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, strategy_signal_tf, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double hma1 = QM_HMA(_Symbol, strategy_signal_tf, strategy_jma_proxy_period, 1);
   const double hma2 = QM_HMA(_Symbol, strategy_signal_tf, strategy_jma_proxy_period, 2);
   if(lower1 <= 0.0 || lower2 <= 0.0 || upper1 <= 0.0 || upper2 <= 0.0 ||
      hma1 <= 0.0 || hma2 <= 0.0)
      return false;

   const bool bullish_reclaim = (close2 < lower2 && close1 > lower1);
   const bool bearish_reclaim = (close2 > upper2 && close1 < upper1);
   const bool stoch_oversold = (k1 < strategy_stoch_oversold && d1 < strategy_stoch_oversold);
   const bool stoch_overbought = (k1 > strategy_stoch_overbought && d1 > strategy_stoch_overbought);
   const bool jma_proxy_green = (hma1 > hma2);
   const bool jma_proxy_red = (hma1 < hma2);

   if(bullish_reclaim && stoch_oversold && jma_proxy_green)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_BUY;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_trail_mult);
      req.tp = 0.0;
      req.reason = "BBSR_JMA_PROXY_ATR_LONG";
      return (entry > 0.0 && req.sl > 0.0 && req.sl < entry);
     }

   if(bearish_reclaim && stoch_overbought && jma_proxy_red)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_SELL;
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_trail_mult);
      req.tp = 0.0;
      req.reason = "BBSR_JMA_PROXY_ATR_SHORT";
      return (entry > 0.0 && req.sl > 0.0 && req.sl > entry);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_atr_trail_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_long = false;
   bool has_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
         has_long = true;
      if(pos_type == POSITION_TYPE_SELL)
         has_short = true;
     }
   if(!has_long && !has_short)
      return false;

   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double close2 = iClose(_Symbol, strategy_signal_tf, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double lower1 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower2 = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double upper1 = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper2 = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 2);
   const double k1 = QM_Stoch_K(_Symbol, strategy_signal_tf, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d1 = QM_Stoch_D(_Symbol, strategy_signal_tf, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double hma1 = QM_HMA(_Symbol, strategy_signal_tf, strategy_jma_proxy_period, 1);
   const double hma2 = QM_HMA(_Symbol, strategy_signal_tf, strategy_jma_proxy_period, 2);
   if(lower1 <= 0.0 || lower2 <= 0.0 || upper1 <= 0.0 || upper2 <= 0.0 ||
      hma1 <= 0.0 || hma2 <= 0.0)
      return false;

   const bool bullish_signal = (close2 < lower2 && close1 > lower1 &&
                                k1 < strategy_stoch_oversold &&
                                d1 < strategy_stoch_oversold &&
                                hma1 > hma2);
   const bool bearish_signal = (close2 > upper2 && close1 < upper1 &&
                                k1 > strategy_stoch_overbought &&
                                d1 > strategy_stoch_overbought &&
                                hma1 < hma2);

   if(has_long && bearish_signal)
      return true;
   if(has_short && bullish_signal)
      return true;

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
