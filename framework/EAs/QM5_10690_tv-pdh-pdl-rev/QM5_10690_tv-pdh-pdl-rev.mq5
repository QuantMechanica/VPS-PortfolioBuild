#property strict
#property version   "5.0"
#property description "QM5_10690 TradingView PDH/PDL Liquidity Reversal"

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
input int    qm_ea_id                   = 10690;
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
input int    strategy_atr_period              = 14;
input double strategy_stop_atr_buffer_mult    = 0.20;
input double strategy_reward_r                = 2.00;
input double strategy_trail_activation_r      = 1.00;
input bool   strategy_require_favorable_half  = true;
input bool   strategy_one_signal_per_dir_day  = true;
input bool   strategy_vol_filter_enabled      = true;
input double strategy_vol_median_ratio        = 0.50;
input int    strategy_session_start_hour      = 13;
input int    strategy_session_end_hour        = 22;
input int    strategy_max_spread_points       = 120;

int g_low_sweep_day   = -1;
int g_high_sweep_day  = -1;
int g_long_signal_day = -1;
int g_short_signal_day = -1;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread_points > strategy_max_spread_points)
      return true;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   bool in_session = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         in_session = (now.hour >= strategy_session_start_hour && now.hour < strategy_session_end_hour);
      else
         in_session = (now.hour >= strategy_session_start_hour || now.hour < strategy_session_end_hour);
     }
   if(!in_session)
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

   if(_Period != PERIOD_M15)
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   MqlDateTime bar_dt;
   TimeToStruct(bar_time, bar_dt);
   const int day_key = bar_dt.year * 1000 + bar_dt.day_of_year;

   const double pdh = iHigh(_Symbol, PERIOD_D1, 1);
   const double pdl = iLow(_Symbol, PERIOD_D1, 1);
   const double day_high = iHigh(_Symbol, PERIOD_D1, 0);
   const double day_low = iLow(_Symbol, PERIOD_D1, 0);
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   const double o1 = iOpen(_Symbol, _Period, 1);
   const double c1 = iClose(_Symbol, _Period, 1);
   if(pdh <= 0.0 || pdl <= 0.0 || day_high <= 0.0 || day_low <= 0.0 ||
      h1 <= 0.0 || l1 <= 0.0 || o1 <= 0.0 || c1 <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(strategy_vol_filter_enabled)
     {
      const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      const int bars_per_day = (seconds > 0) ? (86400 / seconds) : 96;
      double atr_samples[20];
      for(int i = 0; i < 20; ++i)
        {
         const int shift = 1 + ((i + 1) * bars_per_day);
         atr_samples[i] = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
         if(atr_samples[i] <= 0.0)
            return false;
        }
      ArraySort(atr_samples);
      const double median_atr = (atr_samples[9] + atr_samples[10]) * 0.5;
      if(median_atr <= 0.0 || atr < (median_atr * strategy_vol_median_ratio))
         return false;
     }

   if(l1 < pdl)
      g_low_sweep_day = day_key;
   if(h1 > pdh)
      g_high_sweep_day = day_key;

   const double buffer = atr * strategy_stop_atr_buffer_mult;
   if(buffer <= 0.0)
      return false;

   const bool closes_upper_half = (c1 >= ((h1 + l1) * 0.5));
   const bool closes_lower_half = (c1 <= ((h1 + l1) * 0.5));

   if(g_low_sweep_day == day_key &&
      c1 > pdl &&
      (!strategy_require_favorable_half || closes_upper_half) &&
      (!strategy_one_signal_per_dir_day || g_long_signal_day != day_key))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = day_low - buffer;
      if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
         return false;

      const double risk = entry - sl;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry + (risk * strategy_reward_r), _Digits);
      req.reason = "PDL_SWEEP_CLOSE_BACK_LONG";
      g_long_signal_day = day_key;
      return true;
     }

   if(g_high_sweep_day == day_key &&
      c1 < pdh &&
      (!strategy_require_favorable_half || closes_lower_half) &&
      (!strategy_one_signal_per_dir_day || g_short_signal_day != day_key))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = day_high + buffer;
      if(entry <= 0.0 || sl <= entry)
         return false;

      const double risk = sl - entry;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry - (risk * strategy_reward_r), _Digits);
      req.reason = "PDH_SWEEP_CLOSE_BACK_SHORT";
      g_short_signal_day = day_key;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double buffer = atr * strategy_stop_atr_buffer_mult;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);
      if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
         continue;

      double initial_r = 0.0;
      if(ptype == POSITION_TYPE_BUY && tp > entry)
         initial_r = (tp - entry) / strategy_reward_r;
      else if(ptype == POSITION_TYPE_SELL && tp < entry)
         initial_r = (entry - tp) / strategy_reward_r;
      if(initial_r <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid < entry + (initial_r * strategy_trail_activation_r))
            continue;
         const double candidate = NormalizeDouble(iLow(_Symbol, _Period, 1) - buffer, _Digits);
         if(candidate > sl && candidate < bid)
            QM_TM_MoveSL(ticket, candidate, "PDL_HIGHER_LOW_ATR_TRAIL");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > entry - (initial_r * strategy_trail_activation_r))
            continue;
         const double candidate = NormalizeDouble(iHigh(_Symbol, _Period, 1) + buffer, _Digits);
         if((sl <= 0.0 || candidate < sl) && candidate > ask)
            QM_TM_MoveSL(ticket, candidate, "PDH_LOWER_HIGH_ATR_TRAIL");
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         has_position = true;
         break;
        }
     }
   if(!has_position)
      return false;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   if(strategy_session_start_hour == strategy_session_end_hour)
      return false;
   if(strategy_session_start_hour < strategy_session_end_hour)
      return (now.hour >= strategy_session_end_hour);
   return (now.hour >= strategy_session_end_hour && now.hour < strategy_session_start_hour);
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
