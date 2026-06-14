#property strict
#property version   "5.0"
#property description "QM5_10896 Brown EMA Trend Bounce Confirmation"

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
input int    qm_ea_id                   = 10896;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_M15;
input int             strategy_fast_ema_period = 10;
input int             strategy_slow_ema_period = 50;
input int             strategy_bb_period       = 20;
input double          strategy_bb_deviation    = 2.0;
input int             strategy_macd_fast       = 12;
input int             strategy_macd_slow       = 26;
input int             strategy_macd_signal     = 9;
input int             strategy_rsi_period      = 14;
input double          strategy_rsi_midline     = 50.0;
input int             strategy_stoch_k         = 5;
input int             strategy_stoch_d         = 3;
input int             strategy_stoch_slowing   = 3;
input int             strategy_atr_period      = 14;
input double          strategy_sl_atr_min_mult = 0.8;
input double          strategy_tp_atr_mult     = 1.2;
input double          strategy_stop_buffer_pips = 5.0;
input double          strategy_fixed_tp_pips   = 20.0;
input double          strategy_spread_sl_frac  = 0.20;
input int             strategy_max_hold_bars   = 16;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no time/session filter. Spread cap needs the planned SL distance,
   // so it is applied inside Strategy_EntrySignal after the setup is known.
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

   if(strategy_fast_ema_period <= 0 || strategy_slow_ema_period <= strategy_fast_ema_period ||
      strategy_bb_period <= 0 || strategy_atr_period <= 0 ||
      strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast || strategy_macd_signal <= 0 ||
      strategy_rsi_period <= 0 || strategy_stoch_k <= 0 || strategy_stoch_d <= 0 ||
      strategy_stoch_slowing <= 0 || strategy_max_hold_bars <= 0)
      return false;

   MqlRates bars[2];
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, 2, bars); // perf-allowed: two closed bars for the card's pullback-touch and confirming-close rules; this hook is only called after the framework QM_IsNewBar gate.
   if(copied != 2)
      return false;

   const double close1 = bars[0].close;
   const double high1 = bars[0].high;
   const double low1 = bars[0].low;
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = ((digits == 3 || digits == 5) ? point * 10.0 : point);
   if(point <= 0.0 || pip <= 0.0)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_ema_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_ema_period, 1);
   const double bb_mid_1 = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double atr_1 = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig_1 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_2 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_sig_2 = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double rsi_1 = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1);
   const double stoch_k_1 = QM_Stoch_K(_Symbol, strategy_signal_tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_d_1 = QM_Stoch_D(_Symbol, strategy_signal_tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_k_2 = QM_Stoch_K(_Symbol, strategy_signal_tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double stoch_d_2 = QM_Stoch_D(_Symbol, strategy_signal_tf, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);

   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || bb_mid_1 <= 0.0 || atr_1 <= 0.0 ||
      rsi_1 <= 0.0 || stoch_k_1 == EMPTY_VALUE || stoch_d_1 == EMPTY_VALUE ||
      stoch_k_2 == EMPTY_VALUE || stoch_d_2 == EMPTY_VALUE)
      return false;

   const double hist_1 = macd_main_1 - macd_sig_1;
   const double hist_2 = macd_main_2 - macd_sig_2;
   const double buffer = strategy_stop_buffer_pips * pip;
   const double min_sl_dist = strategy_sl_atr_min_mult * atr_1;
   const double tp_dist = MathMax(strategy_fixed_tp_pips * pip, strategy_tp_atr_mult * atr_1);
   if(buffer <= 0.0 || min_sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const bool long_trend = (close1 > ema_slow_1 && ema_fast_1 > ema_slow_1 && bb_mid_1 > ema_slow_1);
   bool long_touch = false;
   double long_line = DBL_MAX;
   if(low1 <= ema_fast_1)
     {
      long_touch = true;
      long_line = MathMin(long_line, ema_fast_1);
     }
   if(low1 <= bb_mid_1)
     {
      long_touch = true;
      long_line = MathMin(long_line, bb_mid_1);
     }
   if(low1 <= ema_slow_1)
     {
      long_touch = true;
      long_line = MathMin(long_line, ema_slow_1);
     }
   const bool long_macd = ((hist_1 > 0.0 && hist_2 <= 0.0) || (hist_1 < 0.0 && hist_1 > hist_2));
   const bool long_rsi = (rsi_1 >= strategy_rsi_midline);
   const bool long_stoch = (stoch_k_1 > stoch_d_1 && stoch_k_2 <= stoch_d_2);

   if(long_trend && long_touch && close1 >= ema_slow_1 && long_macd && long_rsi && long_stoch)
     {
      const double entry = ask;
      const double line_sl = long_line - buffer;
      const double atr_sl = entry - min_sl_dist;
      const double sl = MathMin(line_sl, atr_sl);
      const double sl_dist = entry - sl;
      if(sl <= 0.0 || sl_dist <= 0.0 || (ask - bid) > sl_dist * strategy_spread_sl_frac)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(entry + tp_dist, digits);
      req.reason = "BROWN_EMA_TREND_LONG";
      return true;
     }

   const bool short_trend = (close1 < ema_slow_1 && ema_fast_1 < ema_slow_1 && bb_mid_1 < ema_slow_1);
   bool short_touch = false;
   double short_line = -DBL_MAX;
   if(high1 >= ema_fast_1)
     {
      short_touch = true;
      short_line = MathMax(short_line, ema_fast_1);
     }
   if(high1 >= bb_mid_1)
     {
      short_touch = true;
      short_line = MathMax(short_line, bb_mid_1);
     }
   if(high1 >= ema_slow_1)
     {
      short_touch = true;
      short_line = MathMax(short_line, ema_slow_1);
     }
   const bool short_macd = ((hist_1 < 0.0 && hist_2 >= 0.0) || (hist_1 > 0.0 && hist_1 < hist_2));
   const bool short_rsi = (rsi_1 <= strategy_rsi_midline);
   const bool short_stoch = (stoch_k_1 < stoch_d_1 && stoch_k_2 >= stoch_d_2);

   if(short_trend && short_touch && close1 <= ema_slow_1 && short_macd && short_rsi && short_stoch)
     {
      const double entry = bid;
      const double line_sl = short_line + buffer;
      const double atr_sl = entry + min_sl_dist;
      const double sl = MathMax(line_sl, atr_sl);
      const double sl_dist = sl - entry;
      if(sl <= 0.0 || sl_dist <= 0.0 || (ask - bid) > sl_dist * strategy_spread_sl_frac)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(entry - tp_dist, digits);
      req.reason = "BROWN_EMA_TREND_SHORT";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card trailing is explicitly optional but does not define a trailing
   // distance. Do not invent one here; SL/TP plus the time exit handle exits.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_signal_tf);
   if(magic <= 0 || hold_seconds <= 0)
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
   // Card specifies a later P8 high-impact-news mode. Defer to the central
   // framework news filter and generated phase setfiles.
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
