#property strict
#property version   "5.0"
#property description "QM5_11196 Freqtrade Heracles Donchian Keltner Ratio"

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
input int    qm_ea_id                   = 11196;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_H4;
input double          strategy_buy_div_min        = 0.16;
input double          strategy_buy_div_max        = 0.75;
input int             strategy_donchian_window    = 10;
input int             strategy_keltner_window     = 20;
input int             strategy_keltner_atr_period = 10;
input int             strategy_donchian_shift     = 15;
input int             strategy_keltner_shift      = 9;
input int             strategy_min_warmup_bars    = 40;
input int             strategy_atr_stop_period    = 14;
input double          strategy_atr_stop_mult      = 2.5;
input double          strategy_max_spread_stop_frac = 0.08;
input double          strategy_roi_0_min          = 0.598;
input int             strategy_roi_1_after_min    = 644;
input double          strategy_roi_1_min          = 0.166;
input int             strategy_roi_2_after_min    = 3269;
input double          strategy_roi_2_min          = 0.115;
input int             strategy_roi_3_after_min    = 7289;
input double          strategy_roi_3_min          = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): central framework handles news and
// Friday time gates; spread is checked in Trade Entry against the planned stop.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry: long when shifted Donchian percent-band divided by shifted
// original-version Keltner width is inside the card's fixed band.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(strategy_donchian_window <= 0 ||
      strategy_keltner_window <= 0 ||
      strategy_keltner_atr_period <= 0 ||
      strategy_donchian_shift < 0 ||
      strategy_keltner_shift < 0)
      return false;

   const int donchian_need = 1 + strategy_donchian_shift + strategy_donchian_window;
   const int keltner_need = 1 + strategy_keltner_shift + strategy_keltner_window;
   const int needed = MathMax(strategy_min_warmup_bars, MathMax(donchian_need, keltner_need));
   if(Bars(_Symbol, strategy_timeframe) < needed) // perf-allowed: closed-bar warmup check for bounded custom channel math.
      return false;

   const int donchian_shift = 1 + strategy_donchian_shift;
   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = 0; i < strategy_donchian_window; ++i)
     {
      const int bar_shift = donchian_shift + i;
      const double high = iHigh(_Symbol, strategy_timeframe, bar_shift); // perf-allowed: bounded closed-bar Donchian structural high.
      const double low = iLow(_Symbol, strategy_timeframe, bar_shift); // perf-allowed: bounded closed-bar Donchian structural low.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest = MathMax(highest, high);
      lowest = MathMin(lowest, low);
     }

   const double donchian_close = iClose(_Symbol, strategy_timeframe, donchian_shift); // perf-allowed: fixed shifted closed-bar Donchian close.
   const double donchian_width = highest - lowest;
   if(donchian_close <= 0.0 || donchian_width <= 0.0)
      return false;

   const double donchian_pband = (donchian_close - lowest) / donchian_width;
   if(!MathIsValidNumber(donchian_pband))
      return false;

   const int keltner_shift = 1 + strategy_keltner_shift;
   double middle_sum = 0.0;
   for(int i = 0; i < strategy_keltner_window; ++i)
     {
      const int bar_shift = keltner_shift + i;
      const double high = iHigh(_Symbol, strategy_timeframe, bar_shift); // perf-allowed: bounded closed-bar Keltner typical-price high.
      const double low = iLow(_Symbol, strategy_timeframe, bar_shift); // perf-allowed: bounded closed-bar Keltner typical-price low.
      const double close = iClose(_Symbol, strategy_timeframe, bar_shift); // perf-allowed: bounded closed-bar Keltner typical-price close.
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || high < low)
         return false;
      middle_sum += (high + low + close) / 3.0;
     }

   const double middle = middle_sum / (double)strategy_keltner_window;
   const double keltner_atr = QM_ATR(_Symbol, strategy_timeframe, strategy_keltner_atr_period, keltner_shift);
   if(middle <= 0.0 || keltner_atr <= 0.0)
      return false;

   const double keltner_mult = 2.0;
   const double keltner_wband = ((2.0 * keltner_mult * keltner_atr) / middle) * 100.0;
   if(!MathIsValidNumber(keltner_wband) || keltner_wband <= 0.0)
      return false;

   const double ratio = donchian_pband / keltner_wband;
   if(!MathIsValidNumber(ratio))
      return false;
   if(ratio < strategy_buy_div_min || ratio > strategy_buy_div_max)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask <= bid)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_stop_period, 1);
   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_stop_mult);
   if(atr <= 0.0 || sl <= 0.0 || sl >= ask)
      return false;

   const double stop_points = MathAbs(ask - sl) / point;
   const double spread_points = (ask - bid) / point;
   if(stop_points <= 0.0 ||
      (strategy_max_spread_stop_frac > 0.0 && spread_points > stop_points * strategy_max_spread_stop_frac))
      return false;

   req.type = QM_BUY;
   req.price = ask;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "HERACLES_DONCHIAN_KELTNER_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management: no trailing, partial close, or break-even logic in card.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: source signal exit is disabled; close when ROI ladder target
// is reached. Protective stop and Friday close are handled elsewhere.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime now = TimeCurrent();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_price <= 0.0 || open_time <= 0)
         continue;

      const int elapsed_minutes = (int)MathMax(0.0, (double)(now - open_time) / 60.0);
      double roi_target = strategy_roi_0_min;
      if(elapsed_minutes >= strategy_roi_3_after_min)
         roi_target = strategy_roi_3_min;
      else if(elapsed_minutes >= strategy_roi_2_after_min)
         roi_target = strategy_roi_2_min;
      else if(elapsed_minutes >= strategy_roi_1_after_min)
         roi_target = strategy_roi_1_min;

      const double roi = (bid - open_price) / open_price;
      if(roi >= roi_target)
         return true;
     }

   return false;
  }

// News Filter Hook: no card-specific override beyond the central high-impact
// news pause configured by framework inputs.
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
