#property strict
#property version   "5.0"
#property description "QM5_10221 TradingView Ichimoku EMA RSI"

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
input int    qm_ea_id                   = 10221;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H4;
input int             strategy_tenkan_period     = 9;
input int             strategy_kijun_period      = 26;
input int             strategy_senkou_b_period   = 52;
input int             strategy_displacement      = 26;
input int             strategy_ema_fast_period   = 50;
input int             strategy_ema_slow_period   = 200;
input int             strategy_rsi_period        = 14;
input int             strategy_stoch_rsi_period  = 14;
input int             strategy_stoch_rsi_smooth_k = 3;
input int             strategy_stoch_rsi_smooth_d = 3;
input int             strategy_swing_lookback    = 10;
input int             strategy_atr_period        = 14;
input double          strategy_atr_sl_mult       = 2.5;

bool g_strategy_cached_exit_signal = false;

bool Strategy_RangeMid(const MqlRates &rates[],
                       const int count,
                       const int start_shift,
                       const int period,
                       double &mid)
  {
   mid = 0.0;
   if(start_shift < 1 || period <= 0)
      return false;

   double highest = 0.0;
   double lowest = 0.0;
   for(int shift = start_shift; shift < start_shift + period; ++shift)
     {
      const int idx = shift - 1;
      if(idx < 0 || idx >= count)
         return false;

      const double high = rates[idx].high;
      const double low = rates[idx].low;
      if(high <= 0.0 || low <= 0.0)
         return false;

      if(shift == start_shift || high > highest)
         highest = high;
      if(shift == start_shift || low < lowest)
         lowest = low;
     }

   mid = (highest + lowest) * 0.5;
   return (mid > 0.0);
  }

bool Strategy_CloudAtShift(const MqlRates &rates[],
                           const int count,
                           const int shift,
                           double &span_a,
                           double &span_b)
  {
   span_a = 0.0;
   span_b = 0.0;
   const int cloud_shift = shift + strategy_displacement;

   double tenkan = 0.0;
   double kijun = 0.0;
   if(!Strategy_RangeMid(rates, count, cloud_shift, strategy_tenkan_period, tenkan))
      return false;
   if(!Strategy_RangeMid(rates, count, cloud_shift, strategy_kijun_period, kijun))
      return false;
   if(!Strategy_RangeMid(rates, count, cloud_shift, strategy_senkou_b_period, span_b))
      return false;

   span_a = (tenkan + kijun) * 0.5;
   return (span_a > 0.0 && span_b > 0.0);
  }

double Strategy_RawStochRsi(const int shift)
  {
   double min_rsi = 0.0;
   double max_rsi = 0.0;
   const double rsi_now = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, shift);
   if(rsi_now <= 0.0)
      return -1.0;

   for(int i = shift; i < shift + strategy_stoch_rsi_period; ++i)
     {
      const double rsi = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, i);
      if(rsi <= 0.0)
         return -1.0;
      if(i == shift || rsi < min_rsi)
         min_rsi = rsi;
      if(i == shift || rsi > max_rsi)
         max_rsi = rsi;
     }

   if(max_rsi <= min_rsi)
      return -1.0;
   return 100.0 * (rsi_now - min_rsi) / (max_rsi - min_rsi);
  }

double Strategy_StochRsiK(const int shift)
  {
   double sum = 0.0;
   for(int i = shift; i < shift + strategy_stoch_rsi_smooth_k; ++i)
     {
      const double raw = Strategy_RawStochRsi(i);
      if(raw < 0.0)
         return -1.0;
      sum += raw;
     }
   return sum / (double)strategy_stoch_rsi_smooth_k;
  }

double Strategy_StochRsiD(const int shift)
  {
   double sum = 0.0;
   for(int i = shift; i < shift + strategy_stoch_rsi_smooth_d; ++i)
     {
      const double k = Strategy_StochRsiK(i);
      if(k < 0.0)
         return -1.0;
      sum += k;
     }
   return sum / (double)strategy_stoch_rsi_smooth_d;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card specifies no additional time or spread filter; framework handles news and Friday close.
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

   g_strategy_cached_exit_signal = false;

   if(strategy_tenkan_period <= 0 || strategy_kijun_period <= 0 ||
      strategy_senkou_b_period <= 0 || strategy_displacement < 0 ||
      strategy_ema_fast_period <= 0 || strategy_ema_slow_period <= 0 ||
      strategy_rsi_period <= 0 || strategy_stoch_rsi_period <= 1 ||
      strategy_stoch_rsi_smooth_k <= 0 || strategy_stoch_rsi_smooth_d <= 0 ||
      strategy_swing_lookback <= 0 || strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   const int max_cloud_period = MathMax(strategy_senkou_b_period,
                                        MathMax(strategy_tenkan_period, strategy_kijun_period));
   const int bars_needed = strategy_displacement + max_cloud_period + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, bars_needed, rates); // perf-allowed: bounded Ichimoku OHLC window inside framework new-bar entry hook.
   if(copied != bars_needed)
      return false;

   double span_a = 0.0;
   double span_b = 0.0;
   if(!Strategy_CloudAtShift(rates, copied, 1, span_a, span_b))
      return false;

   const MqlRates closed_bar = rates[0];
   if(closed_bar.open <= 0.0 || closed_bar.close <= 0.0)
      return false;

   g_strategy_cached_exit_signal = (closed_bar.close < closed_bar.open && closed_bar.close < span_a);
   if(g_strategy_cached_exit_signal)
      return false;

   if(!(span_a > span_b))
      return false;
   if(!(closed_bar.close > closed_bar.open && closed_bar.close > span_a))
      return false;

   const double ema_fast = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || ema_fast <= ema_slow)
      return false;

   const double stoch_k = Strategy_StochRsiK(1);
   const double stoch_d = Strategy_StochRsiD(1);
   if(stoch_k < 0.0 || stoch_d < 0.0 || stoch_k <= stoch_d)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(ask <= 0.0 || point <= 0.0 || atr <= 0.0)
      return false;

   const double structure_sl = QM_StopStructure(_Symbol, QM_BUY, ask, strategy_swing_lookback);
   const double atr_sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult);
   if(structure_sl <= 0.0 || atr_sl <= 0.0)
      return false;

   const double sl = MathMin(structure_sl, atr_sl);
   if(sl <= 0.0 || sl >= ask)
      return false;

   const double sl_points = MathAbs(ask - sl) / point;
   if(QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "ichi_ema_stochrsi_long";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
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
   if(!g_strategy_cached_exit_signal)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
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
