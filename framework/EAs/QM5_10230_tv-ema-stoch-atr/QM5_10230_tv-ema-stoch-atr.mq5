#property strict
#property version   "5.0"
#property description "QM5_10230 TradingView EMA Stoch RSI ATR"

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
input int    qm_ea_id                   = 10230;
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
input ENUM_TIMEFRAMES strategy_signal_tf             = PERIOD_H1;
input int             strategy_ema_fast              = 50;
input int             strategy_ema_slow              = 200;
input int             strategy_rsi_period            = 14;
input int             strategy_stoch_rsi_lookback    = 14;
input int             strategy_stoch_k_smooth        = 3;
input int             strategy_stoch_d_smooth        = 3;
input int             strategy_recent_extreme_bars   = 5;
input int             strategy_atr_period            = 14;
input double          strategy_atr_sl_mult           = 1.5;
input double          strategy_rr_target             = 2.0;
input bool            strategy_break_even_enabled    = false;
input double          strategy_break_even_trigger_r  = 1.0;
input int             strategy_break_even_buffer_pts = 0;

double g_last_bull_cross_value = EMPTY_VALUE;
double g_last_bear_cross_value = EMPTY_VALUE;

ENUM_TIMEFRAMES StrategyTF()
  {
   return (strategy_signal_tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : strategy_signal_tf;
  }

double Strategy_StochRSIRaw(const int shift)
  {
   if(strategy_rsi_period <= 0 || strategy_stoch_rsi_lookback <= 1)
      return EMPTY_VALUE;

   const ENUM_TIMEFRAMES tf = StrategyTF();
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, shift, PRICE_CLOSE);
   if(rsi == EMPTY_VALUE)
      return EMPTY_VALUE;

   double lowest = DBL_MAX;
   double highest = -DBL_MAX;
   for(int i = 0; i < strategy_stoch_rsi_lookback; ++i)
     {
      const double r = QM_RSI(_Symbol, tf, strategy_rsi_period, shift + i, PRICE_CLOSE);
      if(r == EMPTY_VALUE)
         return EMPTY_VALUE;
      lowest = MathMin(lowest, r);
      highest = MathMax(highest, r);
     }

   const double range = highest - lowest;
   if(range <= 0.0)
      return 50.0;
   return 100.0 * (rsi - lowest) / range;
  }

double Strategy_StochRSIK(const int shift)
  {
   if(strategy_stoch_k_smooth <= 0)
      return EMPTY_VALUE;

   double sum = 0.0;
   for(int i = 0; i < strategy_stoch_k_smooth; ++i)
     {
      const double raw = Strategy_StochRSIRaw(shift + i);
      if(raw == EMPTY_VALUE)
         return EMPTY_VALUE;
      sum += raw;
     }
   return sum / (double)strategy_stoch_k_smooth;
  }

double Strategy_StochRSID(const int shift)
  {
   if(strategy_stoch_d_smooth <= 0)
      return EMPTY_VALUE;

   double sum = 0.0;
   for(int i = 0; i < strategy_stoch_d_smooth; ++i)
     {
      const double k = Strategy_StochRSIK(shift + i);
      if(k == EMPTY_VALUE)
         return EMPTY_VALUE;
      sum += k;
     }
   return sum / (double)strategy_stoch_d_smooth;
  }

bool Strategy_RecentlyBelow(const double threshold)
  {
   for(int i = 1; i <= strategy_recent_extreme_bars; ++i)
     {
      const double k = Strategy_StochRSIK(i);
      if(k != EMPTY_VALUE && k < threshold)
         return true;
     }
   return false;
  }

bool Strategy_RecentlyAbove(const double threshold)
  {
   for(int i = 1; i <= strategy_recent_extreme_bars; ++i)
     {
      const double k = Strategy_StochRSIK(i);
      if(k != EMPTY_VALUE && k > threshold)
         return true;
     }
   return false;
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

   if(strategy_ema_fast <= 0 || strategy_ema_slow <= 0 ||
      strategy_rsi_period <= 0 || strategy_stoch_rsi_lookback <= 1 ||
      strategy_stoch_k_smooth <= 0 || strategy_stoch_d_smooth <= 0 ||
      strategy_recent_extreme_bars <= 0 || strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_rr_target <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = StrategyTF();
   const int warmup = strategy_ema_slow + strategy_rsi_period +
                      strategy_stoch_rsi_lookback + strategy_stoch_k_smooth +
                      strategy_stoch_d_smooth + strategy_recent_extreme_bars + 5;
   if(Bars(_Symbol, tf) < warmup)
      return false;

   const double close1 = iClose(_Symbol, tf, 1);
   const double ema_fast = QM_EMA(_Symbol, tf, strategy_ema_fast, 1, PRICE_CLOSE);
   const double ema_slow = QM_EMA(_Symbol, tf, strategy_ema_slow, 1, PRICE_CLOSE);
   const double k1 = Strategy_StochRSIK(1);
   const double d1 = Strategy_StochRSID(1);
   const double k2 = Strategy_StochRSIK(2);
   const double d2 = Strategy_StochRSID(2);
   if(close1 <= 0.0 || ema_fast == EMPTY_VALUE || ema_slow == EMPTY_VALUE ||
      k1 == EMPTY_VALUE || d1 == EMPTY_VALUE || k2 == EMPTY_VALUE || d2 == EMPTY_VALUE)
      return false;

   const bool bull_cross = (k2 <= d2 && k1 > d1);
   const bool bear_cross = (k2 >= d2 && k1 < d1);

   if(bull_cross)
     {
      const bool higher_low = (g_last_bull_cross_value != EMPTY_VALUE && k1 > g_last_bull_cross_value);
      g_last_bull_cross_value = k1;
      if(ema_fast > ema_slow && close1 < ema_fast && Strategy_RecentlyBelow(20.0) && higher_low)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         req.type = QM_BUY;
         req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
         req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
         req.reason = "EMA50_GT_EMA200_PULLBACK_STOCHRSI_HIGHER_LOW";
         return (entry > 0.0 && req.sl > 0.0 && req.tp > 0.0);
        }
     }

   if(bear_cross)
     {
      const bool lower_high = (g_last_bear_cross_value != EMPTY_VALUE && k1 < g_last_bear_cross_value);
      g_last_bear_cross_value = k1;
      if(ema_fast < ema_slow && close1 > ema_fast && Strategy_RecentlyAbove(80.0) && lower_high)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         req.type = QM_SELL;
         req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
         req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
         req.reason = "EMA50_LT_EMA200_PULLBACK_STOCHRSI_LOWER_HIGH";
         return (entry > 0.0 && req.sl > 0.0 && req.tp > 0.0);
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(!strategy_break_even_enabled || strategy_break_even_trigger_r <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || sl <= 0.0 || point <= 0.0)
         continue;

      const int trigger_points = (int)MathRound((MathAbs(open_price - sl) / point) *
                                                strategy_break_even_trigger_r);
      QM_TM_MoveToBreakEven(ticket, trigger_points, strategy_break_even_buffer_pts);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
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
