#property strict
#property version   "5.0"
#property description "QM5_9974 ForexFactory Bladerunner 20 EMA Retest"

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
input int    qm_ea_id                   = 9974;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30;
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
input int    strategy_ema_period                  = 20;
input int    strategy_trend_bars                  = 4;
input int    strategy_trend_min_side_bars         = 3;
input double strategy_entry_offset_pips           = 2.0;
input int    strategy_atr_period                  = 14;
input double strategy_min_stop_atr_mult           = 0.5;
input double strategy_rr_target                   = 2.0;
input double strategy_breakeven_rr                = 1.0;
input double strategy_spread_max_stop_fraction    = 0.08;
input bool   strategy_session_filter_enabled      = true;
input int    strategy_session_start_hour_broker   = 7;
input int    strategy_session_end_hour_broker     = 22;
input bool   strategy_news_blackout_enabled       = true;
input int    strategy_news_before_minutes         = 45;
input int    strategy_news_after_minutes          = 15;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_session_filter_enabled)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour_broker));
      const int end_h = MathMax(0, MathMin(24, strategy_session_end_hour_broker));
      const int now_min = dt.hour * 60 + dt.min;
      const int start_min = start_h * 60;
      const int end_min = end_h * 60;

      bool in_session = true;
      if(start_min == end_min)
         in_session = true;
      else if(start_min < end_min)
         in_session = (now_min >= start_min && now_min < end_min);
      else
         in_session = (now_min >= start_min || now_min < end_min);

      if(!in_session)
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
   req.expiration_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(req.expiration_seconds <= 0)
      req.expiration_seconds = 900;

   if(strategy_ema_period < 1 ||
      strategy_trend_bars < 1 ||
      strategy_trend_min_side_bars < 1 ||
      strategy_trend_min_side_bars > strategy_trend_bars ||
      strategy_entry_offset_pips <= 0.0 ||
      strategy_atr_period < 1 ||
      strategy_min_stop_atr_mult <= 0.0 ||
      strategy_rr_target <= 0.0 ||
      strategy_spread_max_stop_fraction <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return false;
   const double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   const double offset = strategy_entry_offset_pips * pip;

   const double confirm_close = iClose(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar OHLC read; no QM_Close helper exists.
   const double confirm_high = iHigh(_Symbol, _Period, 1);   // perf-allowed: fixed closed-bar OHLC read; no QM_High helper exists.
   const double confirm_low = iLow(_Symbol, _Period, 1);     // perf-allowed: fixed closed-bar OHLC read; no QM_Low helper exists.
   const double signal_close = iClose(_Symbol, _Period, 2);  // perf-allowed: fixed closed-bar OHLC read; no QM_Close helper exists.
   const double signal_high = iHigh(_Symbol, _Period, 2);    // perf-allowed: fixed closed-bar OHLC read; no QM_High helper exists.
   const double signal_low = iLow(_Symbol, _Period, 2);      // perf-allowed: fixed closed-bar OHLC read; no QM_Low helper exists.
   const double ema_confirm = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double ema_signal = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 2);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(confirm_close <= 0.0 || confirm_high <= 0.0 || confirm_low <= 0.0 ||
      signal_close <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0 ||
      ema_confirm <= 0.0 || ema_signal <= 0.0 || atr <= 0.0)
      return false;

   int above_count = 0;
   int below_count = 0;
   for(int shift = 2; shift < 2 + strategy_trend_bars; ++shift)
     {
      const double c = iClose(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar trend-side count; no QM_Close helper exists.
      const double e = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, shift);
      if(c <= 0.0 || e <= 0.0)
         return false;
      if(c > e)
         above_count++;
      if(c < e)
         below_count++;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   const double spread = ask - bid;

   if(above_count >= strategy_trend_min_side_bars &&
      signal_low <= ema_signal &&
      signal_close > ema_signal &&
      confirm_close > signal_high &&
      confirm_close > ema_confirm)
     {
      const double entry = confirm_high + offset;
      const double raw_sl = signal_low - offset;
      const double raw_stop_dist = entry - raw_sl;
      const double stop_dist = MathMax(raw_stop_dist, atr * strategy_min_stop_atr_mult);
      if(stop_dist <= 0.0 || spread > stop_dist * strategy_spread_max_stop_fraction)
         return false;

      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(entry - stop_dist, _Digits);
      req.tp = NormalizeDouble(entry + stop_dist * strategy_rr_target, _Digits);
      req.reason = "BLADERUNNER_LONG_EMA20_RETEST";
      return true;
     }

   if(below_count >= strategy_trend_min_side_bars &&
      signal_high >= ema_signal &&
      signal_close < ema_signal &&
      confirm_close < signal_low &&
      confirm_close < ema_confirm)
     {
      const double entry = confirm_low - offset;
      const double raw_sl = signal_high + offset;
      const double raw_stop_dist = raw_sl - entry;
      const double stop_dist = MathMax(raw_stop_dist, atr * strategy_min_stop_atr_mult);
      if(stop_dist <= 0.0 || spread > stop_dist * strategy_spread_max_stop_fraction)
         return false;

      req.type = QM_SELL_STOP;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = NormalizeDouble(entry + stop_dist, _Digits);
      req.tp = NormalizeDouble(entry - stop_dist * strategy_rr_target, _Digits);
      req.reason = "BLADERUNNER_SHORT_EMA20_RETEST";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_breakeven_rr <= 0.0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double initial_r = MathAbs(open_price - current_sl);
      if(initial_r <= point)
         continue;

      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double favorable = is_buy ? (market - open_price) : (open_price - market);
      if(favorable < initial_r * strategy_breakeven_rr)
         continue;

      const bool improves = is_buy ? (current_sl < open_price - point * 0.5)
                                   : (current_sl > open_price + point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "BLADERUNNER_BE_AFTER_1R");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE open_type = POSITION_TYPE_BUY;
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   const double confirm_close = iClose(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar OHLC read; no QM_Close helper exists.
   const double signal_close = iClose(_Symbol, _Period, 2);  // perf-allowed: fixed closed-bar OHLC read; no QM_Close helper exists.
   const double signal_high = iHigh(_Symbol, _Period, 2);    // perf-allowed: fixed closed-bar OHLC read; no QM_High helper exists.
   const double signal_low = iLow(_Symbol, _Period, 2);      // perf-allowed: fixed closed-bar OHLC read; no QM_Low helper exists.
   const double ema_confirm = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double ema_signal = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 2);
   if(confirm_close <= 0.0 || signal_close <= 0.0 ||
      signal_high <= 0.0 || signal_low <= 0.0 ||
      ema_confirm <= 0.0 || ema_signal <= 0.0)
      return false;

   int above_count = 0;
   int below_count = 0;
   for(int shift = 2; shift < 2 + strategy_trend_bars; ++shift)
     {
      const double c = iClose(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar trend-side count; no QM_Close helper exists.
      const double e = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, shift);
      if(c <= 0.0 || e <= 0.0)
         return false;
      if(c > e)
         above_count++;
      if(c < e)
         below_count++;
     }

   const bool long_setup = (above_count >= strategy_trend_min_side_bars &&
                            signal_low <= ema_signal &&
                            signal_close > ema_signal &&
                            confirm_close > signal_high &&
                            confirm_close > ema_confirm);
   const bool short_setup = (below_count >= strategy_trend_min_side_bars &&
                             signal_high >= ema_signal &&
                             signal_close < ema_signal &&
                             confirm_close < signal_low &&
                             confirm_close < ema_confirm);

   if(open_type == POSITION_TYPE_BUY && short_setup)
      return true;
   if(open_type == POSITION_TYPE_SELL && long_setup)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(strategy_news_blackout_enabled)
     {
      datetime utc_time = QM_BrokerToUTC(broker_time);
      if(utc_time <= 0)
         utc_time = TimeGMT();
      if(QM_NewsInWindow(utc_time,
                         _Symbol,
                         MathMax(0, strategy_news_before_minutes),
                         MathMax(0, strategy_news_after_minutes),
                         "high"))
         return true;
     }

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
