#property strict
#property version   "5.0"
#property description "QM5_10785 TradingView 200SMA MACD StochRSI Momentum"

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
input int    qm_ea_id                   = 10785;
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
input int    strategy_sma_period        = 200;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_rsi_period        = 14;
input int    strategy_stoch_rsi_period  = 14;
input int    strategy_stoch_k_smooth    = 3;
input double strategy_stoch_long_level  = 80.0;
input double strategy_stoch_short_level = 20.0;
input int    strategy_swing_lookback    = 10;
input int    strategy_swing_confirm     = 2;
input int    strategy_atr_period        = 14;
input double strategy_atr_buffer_mult   = 0.25;
input double strategy_fallback_rr       = 2.0;
input int    strategy_max_bars_in_trade = 96;
input double strategy_max_spread_atr    = 0.20;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_atr > 0.0 && strategy_atr_period > 0)
     {
      const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
      const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(atr > 0.0 && ask > bid && (ask - bid) > atr * strategy_max_spread_atr)
         return true;
     }

   return false;
  }

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

double ClosedClose(const int shift)
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(_Symbol, tf, shift, 1, closes) != 1) // perf-allowed: single closed-bar read inside strategy hook.
      return 0.0;
   return closes[0];
  }

double StochRsiK(const int shift)
  {
   if(strategy_rsi_period <= 0 || strategy_stoch_rsi_period <= 1 || strategy_stoch_k_smooth <= 0)
      return -1.0;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   double sum = 0.0;
   int samples = 0;

   for(int smooth = 0; smooth < strategy_stoch_k_smooth; ++smooth)
     {
      const int base_shift = shift + smooth;
      const double rsi_now = QM_RSI(_Symbol, tf, strategy_rsi_period, base_shift);
      if(rsi_now < 0.0)
         return -1.0;

      double lo = DBL_MAX;
      double hi = -DBL_MAX;
      for(int i = 0; i < strategy_stoch_rsi_period; ++i)
        {
         const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, base_shift + i);
         if(rsi < 0.0)
            return -1.0;
         if(rsi < lo)
            lo = rsi;
         if(rsi > hi)
            hi = rsi;
        }

      if(hi <= lo)
         return 50.0;
      sum += 100.0 * (rsi_now - lo) / (hi - lo);
      samples++;
     }

   if(samples <= 0)
      return -1.0;
   return sum / (double)samples;
  }

bool FindRecentSwing(const bool want_high, double &level)
  {
   level = 0.0;
   if(strategy_swing_lookback <= 0 || strategy_swing_confirm <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int bars_needed = strategy_swing_lookback + strategy_swing_confirm + 3;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 1, bars_needed, rates); // perf-allowed: bounded structure scan inside EntrySignal new-bar path.
   if(copied < bars_needed)
      return false;

   const int max_available_shift = copied - strategy_swing_confirm - 1;
   const int max_shift = (strategy_swing_lookback < max_available_shift)
                         ? strategy_swing_lookback
                         : max_available_shift;
   for(int shift = strategy_swing_confirm; shift <= max_shift; ++shift)
     {
      bool confirmed = true;
      for(int j = 1; j <= strategy_swing_confirm; ++j)
        {
         if(want_high)
           {
            if(rates[shift].high <= rates[shift - j].high ||
               rates[shift].high <= rates[shift + j].high)
              {
               confirmed = false;
               break;
              }
           }
         else
           {
            if(rates[shift].low >= rates[shift - j].low ||
               rates[shift].low >= rates[shift + j].low)
              {
               confirmed = false;
               break;
              }
           }
        }

      if(confirmed)
        {
         level = want_high ? rates[shift].high : rates[shift].low;
         return (level > 0.0);
        }
     }

   return false;
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened)
  {
   ptype = POSITION_TYPE_BUY;
   opened = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);

   if(strategy_sma_period <= 1 || strategy_macd_fast <= 0 ||
      strategy_macd_slow <= strategy_macd_fast || strategy_macd_signal <= 0 ||
      strategy_atr_period <= 0 || strategy_atr_buffer_mult < 0.0 ||
      strategy_fallback_rr <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close1 = ClosedClose(1);
   const double close2 = ClosedClose(2);
   const double sma1 = QM_SMA(_Symbol, tf, strategy_sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, tf, strategy_sma_period, 2);
   if(close1 <= 0.0 || close2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0)
      return false;

   const double macd = QM_MACD_Main(_Symbol, tf, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, 1);
   const double stoch_k = StochRsiK(1);
   if(stoch_k < 0.0)
      return false;

   const bool long_signal =
      (close2 <= sma2 &&
       close1 > sma1 &&
       macd > 0.0 &&
       stoch_k > strategy_stoch_long_level);

   const bool short_signal =
      (close2 >= sma2 &&
       close1 < sma1 &&
       macd < 0.0 &&
       stoch_k < strategy_stoch_short_level);

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double stop_anchor = 0.0;
   if(!FindRecentSwing(side == QM_SELL, stop_anchor))
      return false;

   double target_anchor = 0.0;
   const bool have_target_swing = FindRecentSwing(side == QM_BUY, target_anchor);
   const double buffer = atr * strategy_atr_buffer_mult;

   double sl = 0.0;
   double tp = 0.0;
   if(side == QM_BUY)
     {
      sl = QM_StopRulesNormalizePrice(_Symbol, stop_anchor - buffer);
      if(sl <= 0.0 || sl >= entry)
         return false;
      if(have_target_swing && target_anchor > entry)
         tp = QM_StopRulesNormalizePrice(_Symbol, target_anchor);
      else
         tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_fallback_rr);
     }
   else
     {
      sl = QM_StopRulesNormalizePrice(_Symbol, stop_anchor + buffer);
      if(sl <= 0.0 || sl <= entry)
         return false;
      if(have_target_swing && target_anchor < entry)
         tp = QM_StopRulesNormalizePrice(_Symbol, target_anchor);
      else
         tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_fallback_rr);
     }

   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "SMA200_MACD_STOCHRSI_LONG" : "SMA200_MACD_STOCHRSI_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened = 0;
   if(!GetOurPosition(ptype, opened))
      return false;

   if(strategy_max_bars_in_trade > 0 && opened > 0)
     {
      const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(seconds_per_bar > 0 &&
         TimeCurrent() - opened >= (long)seconds_per_bar * strategy_max_bars_in_trade)
         return true;
     }

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close1 = ClosedClose(1);
   const double close2 = ClosedClose(2);
   const double sma1 = QM_SMA(_Symbol, tf, strategy_sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, tf, strategy_sma_period, 2);
   if(close1 <= 0.0 || close2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && close2 >= sma2 && close1 < sma1)
      return true;
   if(ptype == POSITION_TYPE_SELL && close2 <= sma2 && close1 > sma1)
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
