#property strict
#property version   "5.0"
#property description "QM5_10253 TradingView EMA Sweep IFVG Retest"

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
input int    qm_ea_id                   = 10253;
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
input ENUM_TIMEFRAMES strategy_execution_tf          = PERIOD_M15;
input int             strategy_fast_ema              = 13;
input int             strategy_mid_ema               = 21;
input int             strategy_slow_ema              = 34;
input int             strategy_sweep_lookback        = 20;
input int             strategy_atr_period            = 14;
input double          strategy_displacement_atr_mult = 1.0;
input double          strategy_sl_atr_mult           = 0.25;
input double          strategy_tp_r_multiple         = 2.0;
input int             strategy_max_hold_bars         = 32;
input int             strategy_london_start_hour     = 8;
input int             strategy_london_end_hour       = 11;
input int             strategy_ny_start_hour         = 14;
input int             strategy_ny_end_hour           = 17;
input int             strategy_max_spread_points     = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != (int)strategy_execution_tf)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
         return true;
      const int spread_points = (int)MathRound((ask - bid) / point);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const bool london_open = (dt.hour >= strategy_london_start_hour &&
                             dt.hour < strategy_london_end_hour);
   const bool ny_open = (dt.hour >= strategy_ny_start_hour &&
                         dt.hour < strategy_ny_end_hour);
   return !(london_open || ny_open);
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

   static bool   bull_sweep_active = false;
   static bool   bear_sweep_active = false;
   static double bull_sweep_low = 0.0;
   static double bear_sweep_high = 0.0;
   static bool   bull_zone_active = false;
   static bool   bear_zone_active = false;
   static double bull_zone_low = 0.0;
   static double bull_zone_high = 0.0;
   static double bull_zone_sweep_low = 0.0;
   static double bear_zone_low = 0.0;
   static double bear_zone_high = 0.0;
   static double bear_zone_sweep_high = 0.0;

   if(_Period != (int)strategy_execution_tf)
      return false;
   if(strategy_fast_ema <= 0 || strategy_mid_ema <= 0 || strategy_slow_ema <= 0 ||
      strategy_sweep_lookback < 3 || strategy_atr_period <= 0 ||
      strategy_sl_atr_mult <= 0.0 || strategy_tp_r_multiple <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double open1  = iOpen(_Symbol, strategy_execution_tf, 1);  // perf-allowed: M15 structural sweep/IFVG OHLC
   const double high1  = iHigh(_Symbol, strategy_execution_tf, 1);  // perf-allowed: M15 structural sweep/IFVG OHLC
   const double low1   = iLow(_Symbol, strategy_execution_tf, 1);   // perf-allowed: M15 structural sweep/IFVG OHLC
   const double close1 = iClose(_Symbol, strategy_execution_tf, 1); // perf-allowed: M15 structural sweep/IFVG OHLC
   const double high3  = iHigh(_Symbol, strategy_execution_tf, 3);  // perf-allowed: M15 three-bar IFVG reference
   const double low3   = iLow(_Symbol, strategy_execution_tf, 3);   // perf-allowed: M15 three-bar IFVG reference
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || high3 <= 0.0 || low3 <= 0.0)
      return false;

   double prior_high = -DBL_MAX;
   double prior_low = DBL_MAX;
   for(int shift = 2; shift < 2 + strategy_sweep_lookback; ++shift)
     {
      const double h = iHigh(_Symbol, strategy_execution_tf, shift); // perf-allowed: bounded 20-bar structural sweep window
      const double l = iLow(_Symbol, strategy_execution_tf, shift);  // perf-allowed: bounded 20-bar structural sweep window
      if(h <= 0.0 || l <= 0.0)
         return false;
      prior_high = MathMax(prior_high, h);
      prior_low = MathMin(prior_low, l);
     }

   const double h4_fast = QM_EMA(_Symbol, PERIOD_H4, strategy_fast_ema, 1);
   const double h4_mid  = QM_EMA(_Symbol, PERIOD_H4, strategy_mid_ema, 1);
   const double h4_slow = QM_EMA(_Symbol, PERIOD_H4, strategy_slow_ema, 1);
   const double h1_fast = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema, 1);
   const double h1_mid  = QM_EMA(_Symbol, PERIOD_H1, strategy_mid_ema, 1);
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: H1 continuation close vs pooled EMA
   const double atr = QM_ATR(_Symbol, strategy_execution_tf, strategy_atr_period, 1);
   if(h4_fast <= 0.0 || h4_mid <= 0.0 || h4_slow <= 0.0 ||
      h1_fast <= 0.0 || h1_mid <= 0.0 || h1_close <= 0.0 || atr <= 0.0)
      return false;

   const bool h4_bull = (h4_fast > h4_mid && h4_mid > h4_slow);
   const bool h4_bear = (h4_fast < h4_mid && h4_mid < h4_slow);
   const bool h1_bull = (h1_close > h1_mid && h1_fast > h1_mid);
   const bool h1_bear = (h1_close < h1_mid && h1_fast < h1_mid);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(bull_zone_active && h4_bull && h1_bull &&
      high1 >= bull_zone_low && low1 <= bull_zone_high)
     {
      const double sl = bull_zone_sweep_low - atr * strategy_sl_atr_mult;
      if(sl > 0.0 && sl < ask)
        {
         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = ask + (ask - sl) * strategy_tp_r_multiple;
         req.reason = "TV_IFVG_SWEEP_LONG_RETEST";
         bull_zone_active = false;
         return true;
        }
     }

   if(bear_zone_active && h4_bear && h1_bear &&
      high1 >= bear_zone_low && low1 <= bear_zone_high)
     {
      const double sl = bear_zone_sweep_high + atr * strategy_sl_atr_mult;
      if(sl > bid)
        {
         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = bid - (sl - bid) * strategy_tp_r_multiple;
         req.reason = "TV_IFVG_SWEEP_SHORT_RETEST";
         bear_zone_active = false;
         return true;
        }
     }

   const bool sell_side_sweep = (low1 < prior_low && close1 > prior_low);
   const bool buy_side_sweep = (high1 > prior_high && close1 < prior_high);
   const bool displacement = (MathAbs(close1 - open1) >= atr * strategy_displacement_atr_mult);

   if(sell_side_sweep)
     {
      bull_sweep_active = true;
      bull_sweep_low = low1;
     }
   if(buy_side_sweep)
     {
      bear_sweep_active = true;
      bear_sweep_high = high1;
     }

   if(bull_sweep_active && h4_bull && h1_bull && displacement && low1 > high3)
     {
      bull_zone_low = high3;
      bull_zone_high = low1;
      bull_zone_sweep_low = bull_sweep_low;
      bull_zone_active = true;
      bull_sweep_active = false;
     }

   if(bear_sweep_active && h4_bear && h1_bear && displacement && high1 < low3)
     {
      bear_zone_low = high1;
      bear_zone_high = low3;
      bear_zone_sweep_high = bear_sweep_high;
      bear_zone_active = true;
      bear_sweep_active = false;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing stop, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_execution_tf);
   if(hold_seconds <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && TimeCurrent() - opened >= hold_seconds)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   (void)broker_time;
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
