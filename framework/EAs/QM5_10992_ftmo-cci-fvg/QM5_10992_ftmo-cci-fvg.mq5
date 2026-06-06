#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
input int    qm_ea_id                   = 10992;
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
input ENUM_TIMEFRAMES strategy_timeframe             = PERIOD_H1;
input int             strategy_cci_period            = 20;
input int             strategy_ema_period            = 50;
input int             strategy_atr_period            = 14;
input int             strategy_cci_cross_lookback    = 3;
input int             strategy_fvg_lookback          = 8;
input double          strategy_fvg_min_atr           = 0.25;
input double          strategy_fvg_max_atr           = 1.50;
input double          strategy_sl_atr_mult           = 0.35;
input double          strategy_tp_r_multiple         = 2.0;
input int             strategy_time_exit_bars        = 36;
input int             strategy_spread_lookback       = 20;
input double          strategy_spread_median_mult    = 1.50;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card uses framework news gating and per-entry spread/FVG filters only.
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

   if(strategy_cci_period <= 1 || strategy_ema_period <= 1 || strategy_atr_period <= 1)
      return false;
   if(strategy_cci_cross_lookback < 1 || strategy_fvg_lookback < 1 || strategy_time_exit_bars < 1)
      return false;

   if(strategy_spread_lookback > 1 && strategy_spread_median_mult > 0.0)
     {
      MqlRates spread_rates[];
      const int copied = CopyRates(_Symbol, strategy_timeframe, 1, strategy_spread_lookback, spread_rates); // perf-allowed: closed-bar spread median filter.
      if(copied >= strategy_spread_lookback)
        {
         int spreads[];
         ArrayResize(spreads, copied);
         for(int i = 0; i < copied; ++i)
            spreads[i] = spread_rates[i].spread;
         ArraySort(spreads);
         const double median_spread = (copied % 2 == 0)
                                      ? (0.5 * (double)(spreads[copied / 2 - 1] + spreads[copied / 2]))
                                      : (double)spreads[copied / 2];
         const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if(median_spread > 0.0 && current_spread > median_spread * strategy_spread_median_mult)
            return false;
        }
     }

   const double close1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: FVG confirmation uses closed OHLC.
   const double close2 = iClose(_Symbol, strategy_timeframe, 2); // perf-allowed: first-retrace check uses prior closed bar.
   const double low1 = iLow(_Symbol, strategy_timeframe, 1); // perf-allowed: bespoke FVG retrace geometry.
   const double high1 = iHigh(_Symbol, strategy_timeframe, 1); // perf-allowed: bespoke FVG retrace geometry.
   const double low2 = iLow(_Symbol, strategy_timeframe, 2); // perf-allowed: first-retrace check.
   const double high2 = iHigh(_Symbol, strategy_timeframe, 2); // perf-allowed: first-retrace check.
   const double ema1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, 1);
   const double atr1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double cci1 = QM_CCI(_Symbol, strategy_timeframe, strategy_cci_period, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || low1 <= 0.0 || high1 <= 0.0 || low2 <= 0.0 || high2 <= 0.0 ||
      ema1 <= 0.0 || atr1 <= 0.0)
      return false;

   bool cci_crossed_up = false;
   bool cci_crossed_down = false;
   for(int shift = 1; shift <= strategy_cci_cross_lookback; ++shift)
     {
      const double cci_now = QM_CCI(_Symbol, strategy_timeframe, strategy_cci_period, shift);
      const double cci_prev = QM_CCI(_Symbol, strategy_timeframe, strategy_cci_period, shift + 1);
      if(cci_now > 0.0 && cci_prev <= 0.0)
         cci_crossed_up = true;
      if(cci_now < 0.0 && cci_prev >= 0.0)
         cci_crossed_down = true;
     }

   double long_lower = 0.0;
   double long_upper = 0.0;
   double short_lower = 0.0;
   double short_upper = 0.0;

   for(int newest_shift = 2; newest_shift <= strategy_fvg_lookback; ++newest_shift)
     {
      const double newer_low = iLow(_Symbol, strategy_timeframe, newest_shift); // perf-allowed: bespoke FVG scan.
      const double newer_high = iHigh(_Symbol, strategy_timeframe, newest_shift); // perf-allowed: bespoke FVG scan.
      const double older_high = iHigh(_Symbol, strategy_timeframe, newest_shift + 2); // perf-allowed: bespoke FVG scan.
      const double older_low = iLow(_Symbol, strategy_timeframe, newest_shift + 2); // perf-allowed: bespoke FVG scan.
      if(newer_low <= 0.0 || newer_high <= 0.0 || older_high <= 0.0 || older_low <= 0.0)
         continue;

      if(long_lower <= 0.0 && newer_low > older_high)
        {
         const double height = newer_low - older_high;
         if(height >= atr1 * strategy_fvg_min_atr && height <= atr1 * strategy_fvg_max_atr)
           {
            long_lower = older_high;
            long_upper = newer_low;
           }
        }

      if(short_upper <= 0.0 && newer_high < older_low)
        {
         const double height = older_low - newer_high;
         if(height >= atr1 * strategy_fvg_min_atr && height <= atr1 * strategy_fvg_max_atr)
           {
            short_lower = newer_high;
            short_upper = older_low;
           }
        }
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(close1 > ema1 && cci_crossed_up && cci1 < 200.0 && long_lower > 0.0 && long_upper > long_lower)
     {
      const double mid = 0.5 * (long_lower + long_upper);
      const bool first_upper_half_retrace = (low1 <= long_upper && low1 >= mid && close1 > mid && low2 > long_upper);
      if(first_upper_half_retrace)
        {
         const double sl = long_lower - strategy_sl_atr_mult * atr1;
         const double risk = ask - sl;
         if(sl > 0.0 && risk > point)
           {
            req.type = QM_BUY;
            req.price = 0.0;
            req.sl = sl;
            req.tp = ask + strategy_tp_r_multiple * risk;
            req.reason = "CCI_FVG_LONG";
            return true;
           }
        }
     }

   if(close1 < ema1 && cci_crossed_down && cci1 > -200.0 && short_upper > short_lower && short_lower > 0.0)
     {
      const double mid = 0.5 * (short_lower + short_upper);
      const bool first_lower_half_retrace = (high1 >= short_lower && high1 <= mid && close1 < mid && high2 < short_lower);
      if(first_lower_half_retrace)
        {
         const double sl = short_upper + strategy_sl_atr_mult * atr1;
         const double risk = sl - bid;
         if(sl > 0.0 && risk > point)
           {
            req.type = QM_SELL;
            req.price = 0.0;
            req.sl = sl;
            req.tp = bid - strategy_tp_r_multiple * risk;
            req.reason = "CCI_FVG_SHORT";
            return true;
           }
        }
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
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0 || point <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const double initial_risk = (current_tp > 0.0 && strategy_tp_r_multiple > 0.0)
                                  ? (MathAbs(current_tp - open_price) / strategy_tp_r_multiple)
                                  : (is_buy ? (open_price - current_sl) : (current_sl - open_price));
      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(market_price <= 0.0 || initial_risk <= point || moved < initial_risk)
         continue;

      const bool already_be = is_buy ? (current_sl >= open_price - point * 0.5)
                                     : (current_sl <= open_price + point * 0.5);
      if(!already_be)
         QM_TM_MoveSL(ticket, open_price, "CCI_FVG_BE_1R");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double cci1 = QM_CCI(_Symbol, strategy_timeframe, strategy_cci_period, 1);
      if(pos_type == POSITION_TYPE_BUY && cci1 < 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && cci1 > 0.0)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int h1_seconds = PeriodSeconds(PERIOD_H1);
      if(open_time > 0 && h1_seconds > 0 && TimeCurrent() - open_time >= strategy_time_exit_bars * h1_seconds)
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
