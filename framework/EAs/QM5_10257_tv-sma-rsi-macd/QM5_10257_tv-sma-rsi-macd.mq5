#property strict
#property version   "5.0"
#property description "QM5_10257 TradingView SMA RSI MACD Scalper"

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
input int    qm_ea_id                   = 10257;
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
input int    strategy_ema_period        = 200;
input int    strategy_sma_fast_period   = 5;
input int    strategy_sma_mid_period    = 8;
input int    strategy_sma_slow_period   = 13;
input int    strategy_rsi_period        = 4;
input double strategy_rsi_oversold      = 30.0;
input double strategy_rsi_overbought    = 70.0;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_macd_lookback     = 3;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_take_profit_rr    = 2.0;
input bool   strategy_session_enabled   = true;
input int    strategy_session_start_h   = 7;
input int    strategy_session_end_h     = 18;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!strategy_session_enabled)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hour = dt.hour;
   if(strategy_session_start_h <= strategy_session_end_h)
      return !(hour >= strategy_session_start_h && hour < strategy_session_end_h);

   return !(hour >= strategy_session_start_h || hour < strategy_session_end_h);
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

   if(strategy_ema_period <= 0 || strategy_sma_fast_period <= 0 ||
      strategy_sma_mid_period <= 0 || strategy_sma_slow_period <= 0 ||
      strategy_rsi_period <= 0 || strategy_macd_fast <= 0 ||
      strategy_macd_slow <= strategy_macd_fast || strategy_macd_signal <= 0 ||
      strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close1 = iClose(_Symbol, tf, 1);
   if(close1 <= 0.0)
      return false;

   const double ema200 = QM_EMA(_Symbol, tf, strategy_ema_period, 1);
   const double sma5 = QM_SMA(_Symbol, tf, strategy_sma_fast_period, 1);
   const double sma8 = QM_SMA(_Symbol, tf, strategy_sma_mid_period, 1);
   const double sma13 = QM_SMA(_Symbol, tf, strategy_sma_slow_period, 1);
   const double rsi_now = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, tf, strategy_rsi_period, 2);
   if(ema200 <= 0.0 || sma5 <= 0.0 || sma8 <= 0.0 || sma13 <= 0.0 ||
      rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   const bool trend_up = (close1 > ema200 && sma5 > sma8 && sma8 > sma13);
   const bool trend_down = (close1 < ema200 && sma5 < sma8 && sma8 < sma13);
   const bool rsi_long = (rsi_prev < strategy_rsi_oversold &&
                          rsi_now >= strategy_rsi_oversold);
   const bool rsi_short = (rsi_prev > strategy_rsi_overbought &&
                           rsi_now <= strategy_rsi_overbought);

   bool macd_long = false;
   bool macd_short = false;
   const int max_lookback = MathMax(1, MathMin(strategy_macd_lookback, 3));
   for(int shift = 1; shift <= max_lookback; ++shift)
     {
      const double main_now = QM_MACD_Main(_Symbol, tf, strategy_macd_fast,
                                           strategy_macd_slow,
                                           strategy_macd_signal, shift);
      const double sig_now = QM_MACD_Signal(_Symbol, tf, strategy_macd_fast,
                                            strategy_macd_slow,
                                            strategy_macd_signal, shift);
      const double main_prev = QM_MACD_Main(_Symbol, tf, strategy_macd_fast,
                                            strategy_macd_slow,
                                            strategy_macd_signal, shift + 1);
      const double sig_prev = QM_MACD_Signal(_Symbol, tf, strategy_macd_fast,
                                             strategy_macd_slow,
                                             strategy_macd_signal, shift + 1);
      const double main_prev2 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast,
                                             strategy_macd_slow,
                                             strategy_macd_signal, shift + 2);
      const double sig_prev2 = QM_MACD_Signal(_Symbol, tf, strategy_macd_fast,
                                              strategy_macd_slow,
                                              strategy_macd_signal, shift + 2);
      const double hist_now = main_now - sig_now;
      const double hist_prev = main_prev - sig_prev;
      const double hist_prev2 = main_prev2 - sig_prev2;

      if((hist_prev <= 0.0 && hist_now > 0.0) ||
         (hist_now > hist_prev && hist_prev <= hist_prev2))
         macd_long = true;
      if((hist_prev >= 0.0 && hist_now < 0.0) ||
         (hist_now < hist_prev && hist_prev >= hist_prev2))
         macd_short = true;
     }

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(trend_up && rsi_long && macd_long)
     {
      side = QM_BUY;
      reason = "SMA_RSI_MACD_LONG";
     }
   else if(trend_down && rsi_short && macd_short)
     {
      side = QM_SELL;
      reason = "SMA_RSI_MACD_SHORT";
     }
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry,
                                strategy_atr_period, strategy_atr_sl_mult);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl,
                               strategy_take_profit_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no break-even, trailing, or partial management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card baseline exits at ATR stop or fixed 2R take-profit only.
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
