#property strict
#property version   "5.0"
#property description "QM5_10646 TradingView Quant Synthesis Regime"

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
input int    qm_ea_id                   = 10646;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H1;
input ENUM_TIMEFRAMES strategy_htf                = PERIOD_H4;
input int             strategy_fast_ema_period    = 21;
input int             strategy_slow_ema_period    = 55;
input int             strategy_adx_period         = 14;
input double          strategy_adx_threshold      = 20.0;
input int             strategy_atr_period         = 14;
input double          strategy_atr_sl_mult        = 1.8;
input double          strategy_atr_tp_mult        = 2.8;
input double          strategy_max_stop_atr_mult  = 3.5;
input double          strategy_max_spread_stop_pct = 15.0;
input int             strategy_structure_lookback = 18;
input int             strategy_volume_lookback    = 20;
input int             strategy_min_score          = 4;
input bool            strategy_opening_range_enabled = true;
input int             strategy_session_start_hour = 8;
input int             strategy_opening_range_bars = 2;
input int             strategy_session_end_hour   = 17;
input int             strategy_cooldown_bars      = 6;
input int             strategy_max_hold_bars      = 12;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_signal_tf)
      return true;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.hour < strategy_session_start_hour || now_dt.hour >= strategy_session_end_hour)
      return true;

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

   if(_Period != strategy_signal_tf)
      return false;

   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         has_position = true;
         break;
        }
     }

   static bool s_had_position = false;
   static int  s_cooldown_remaining = 0;
   static int  s_last_entry_day_key = -1;

   if(has_position)
     {
      s_had_position = true;
      return false;
     }

   if(s_had_position)
     {
      s_had_position = false;
      s_cooldown_remaining = strategy_cooldown_bars;
     }

   if(s_cooldown_remaining > 0)
     {
      --s_cooldown_remaining;
      return false;
     }

   const datetime bar_time = iTime(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar session key read; Strategy_EntrySignal is called only after QM_IsNewBar().
   if(bar_time <= 0)
      return false;

   MqlDateTime bar_dt;
   TimeToStruct(bar_time, bar_dt);
   const int day_key = bar_dt.year * 1000 + bar_dt.day_of_year;
   if(s_last_entry_day_key == day_key)
      return false;
   if(bar_dt.hour < strategy_session_start_hour + strategy_opening_range_bars ||
      bar_dt.hour >= strategy_session_end_hour)
      return false;

   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: single closed-bar price read for custom confluence math.
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(close1 <= 0.0 || atr <= 0.0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_ema_period, 1);
   const double ema_slow = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_ema_period, 1);
   const double adx = QM_ADX(_Symbol, strategy_signal_tf, strategy_adx_period, 1);
   const double plus_di = QM_ADX_PlusDI(_Symbol, strategy_signal_tf, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, strategy_signal_tf, strategy_adx_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || adx <= 0.0)
      return false;

   const double htf_fast = QM_EMA(_Symbol, strategy_htf, strategy_fast_ema_period, 1);
   const double htf_slow = QM_EMA(_Symbol, strategy_htf, strategy_slow_ema_period, 1);
   const double htf_fast_prev = QM_EMA(_Symbol, strategy_htf, strategy_fast_ema_period, 2);
   if(htf_fast <= 0.0 || htf_slow <= 0.0 || htf_fast_prev <= 0.0)
      return false;

   double latest_pivot_high = 0.0;
   double latest_pivot_low = DBL_MAX;
   for(int shift = 2; shift <= strategy_structure_lookback; ++shift)
     {
      const double h = iHigh(_Symbol, strategy_signal_tf, shift); // perf-allowed: bounded delayed-pivot scan inside closed-bar entry hook.
      const double h_prev = iHigh(_Symbol, strategy_signal_tf, shift + 1); // perf-allowed: bounded delayed-pivot scan inside closed-bar entry hook.
      const double h_next = iHigh(_Symbol, strategy_signal_tf, shift - 1); // perf-allowed: bounded delayed-pivot scan inside closed-bar entry hook.
      const double l = iLow(_Symbol, strategy_signal_tf, shift); // perf-allowed: bounded delayed-pivot scan inside closed-bar entry hook.
      const double l_prev = iLow(_Symbol, strategy_signal_tf, shift + 1); // perf-allowed: bounded delayed-pivot scan inside closed-bar entry hook.
      const double l_next = iLow(_Symbol, strategy_signal_tf, shift - 1); // perf-allowed: bounded delayed-pivot scan inside closed-bar entry hook.
      if(h > 0.0 && h > h_prev && h > h_next && latest_pivot_high <= 0.0)
         latest_pivot_high = h;
      if(l > 0.0 && l < l_prev && l < l_next && latest_pivot_low == DBL_MAX)
         latest_pivot_low = l;
      if(latest_pivot_high > 0.0 && latest_pivot_low < DBL_MAX)
         break;
     }

   double avg_volume = 0.0;
   for(int shift = 2; shift < 2 + strategy_volume_lookback; ++shift)
      avg_volume += (double)iVolume(_Symbol, strategy_signal_tf, shift); // perf-allowed: bounded tick-volume participation scan inside closed-bar entry hook.
   if(strategy_volume_lookback > 0)
      avg_volume /= (double)strategy_volume_lookback;
   const double volume1 = (double)iVolume(_Symbol, strategy_signal_tf, 1); // perf-allowed: single closed-bar tick-volume read for participation score.
   const bool volume_participates = (avg_volume <= 0.0 || volume1 >= avg_volume);

   double opening_high = 0.0;
   double opening_low = DBL_MAX;
   for(int shift = 1; shift <= 30; ++shift)
     {
      const datetime t = iTime(_Symbol, strategy_signal_tf, shift); // perf-allowed: bounded same-session opening-range scan inside closed-bar entry hook.
      if(t <= 0)
         continue;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      if(dt.year != bar_dt.year || dt.day_of_year != bar_dt.day_of_year)
         continue;
      if(dt.hour >= strategy_session_start_hour &&
         dt.hour < strategy_session_start_hour + strategy_opening_range_bars)
        {
         const double h = iHigh(_Symbol, strategy_signal_tf, shift); // perf-allowed: bounded opening-range high read.
         const double l = iLow(_Symbol, strategy_signal_tf, shift); // perf-allowed: bounded opening-range low read.
         if(h > opening_high)
            opening_high = h;
         if(l > 0.0 && l < opening_low)
            opening_low = l;
        }
     }
   const bool opening_ready = (!strategy_opening_range_enabled ||
                              (opening_high > 0.0 && opening_low < DBL_MAX));

   const bool regime_long = (ema_fast > ema_slow && adx >= strategy_adx_threshold && plus_di > minus_di);
   const bool regime_short = (ema_fast < ema_slow && adx >= strategy_adx_threshold && minus_di > plus_di);
   const bool htf_long = (htf_fast > htf_slow && htf_fast > htf_fast_prev);
   const bool htf_short = (htf_fast < htf_slow && htf_fast < htf_fast_prev);
   const bool structure_long = (latest_pivot_high > 0.0 && close1 > latest_pivot_high);
   const bool structure_short = (latest_pivot_low < DBL_MAX && close1 < latest_pivot_low);
   const bool opening_long = (!strategy_opening_range_enabled || (opening_ready && close1 > opening_high));
   const bool opening_short = (!strategy_opening_range_enabled || (opening_ready && close1 < opening_low));

   if(!opening_ready)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double stop_distance = atr * strategy_atr_sl_mult;
   if(stop_distance <= 0.0 || stop_distance > atr * strategy_max_stop_atr_mult)
      return false;
   if((ask - bid) > stop_distance * strategy_max_spread_stop_pct / 100.0)
      return false;

   int long_score = 0;
   int short_score = 0;
   if(regime_long) ++long_score;
   if(regime_short) ++short_score;
   if(htf_long) ++long_score;
   if(htf_short) ++short_score;
   if(structure_long) ++long_score;
   if(structure_short) ++short_score;
   if(volume_participates)
     {
      ++long_score;
      ++short_score;
     }
   if(opening_long) ++long_score;
   if(opening_short) ++short_score;

   if(long_score >= strategy_min_score)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask - stop_distance;
      req.tp = ask + atr * strategy_atr_tp_mult;
      req.reason = "QSS_LONG_CONFLUENCE";
      s_last_entry_day_key = day_key;
      return true;
     }

   if(short_score >= strategy_min_score)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid + stop_distance;
      req.tp = bid - atr * strategy_atr_tp_mult;
      req.reason = "QSS_SHORT_CONFLUENCE";
      s_last_entry_day_key = day_key;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR SL/TP only; no break-even, trailing, or partial exits.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(now_dt.hour >= strategy_session_end_hour)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_signal_tf);
      if(hold_seconds > 0 && TimeCurrent() - open_time >= hold_seconds)
         return true;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double htf_fast = QM_EMA(_Symbol, strategy_htf, strategy_fast_ema_period, 1);
      const double htf_slow = QM_EMA(_Symbol, strategy_htf, strategy_slow_ema_period, 1);
      const double htf_fast_prev = QM_EMA(_Symbol, strategy_htf, strategy_fast_ema_period, 2);
      const double adx = QM_ADX(_Symbol, strategy_signal_tf, strategy_adx_period, 1);
      const double plus_di = QM_ADX_PlusDI(_Symbol, strategy_signal_tf, strategy_adx_period, 1);
      const double minus_di = QM_ADX_MinusDI(_Symbol, strategy_signal_tf, strategy_adx_period, 1);
      if(htf_fast <= 0.0 || htf_slow <= 0.0 || htf_fast_prev <= 0.0 || adx <= 0.0)
         continue;

      const bool long_valid = (htf_fast > htf_slow && htf_fast > htf_fast_prev &&
                               adx >= strategy_adx_threshold && plus_di >= minus_di);
      const bool short_valid = (htf_fast < htf_slow && htf_fast < htf_fast_prev &&
                                adx >= strategy_adx_threshold && minus_di >= plus_di);
      if(pos_type == POSITION_TYPE_BUY && !long_valid)
         return true;
      if(pos_type == POSITION_TYPE_SELL && !short_valid)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Strategy card has no custom news override; defer to framework news filter.
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
