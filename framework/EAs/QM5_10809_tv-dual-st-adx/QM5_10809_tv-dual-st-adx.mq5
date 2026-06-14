#property strict
#property version   "5.0"
#property description "QM5_10809 TradingView Dual SuperTrend Rising ADX"

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
input int    qm_ea_id                   = 10809;
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
input int    strategy_fast_st_atr_period = 10;
input double strategy_fast_st_multiplier = 3.0;
input int    strategy_slow_st_atr_period = 21;
input double strategy_slow_st_multiplier = 4.0;
input int    strategy_adx_period         = 14;
input int    strategy_adx_rising_window  = 1;
input double strategy_adx_floor          = 0.0;
input int    strategy_adx_flat_exit_bars = 3;
input int    strategy_max_h1_bars        = 120;
input int    strategy_max_h4_bars        = 80;
input int    strategy_supertrend_warmup_bars = 80;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card authorizes only standard V5 spread/news filters.
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

   const int warmup = MathMax(strategy_supertrend_warmup_bars,
                              MathMax(strategy_fast_st_atr_period, strategy_slow_st_atr_period) * 4);
   if(strategy_fast_st_atr_period <= 1 || strategy_slow_st_atr_period <= 1 ||
      strategy_fast_st_multiplier <= 0.0 || strategy_slow_st_multiplier <= 0.0 ||
      strategy_adx_period <= 1 || strategy_adx_rising_window < 1 || warmup < 10)
      return false;

   int fast_dir = 0;
   double fast_upper = 0.0;
   double fast_lower = 0.0;
   double fast_prev_line = 0.0;
   for(int i = warmup; i >= 1; --i)
     {
      const double hi = iHigh(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double lo = iLow(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double cl = iClose(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double prev_cl = iClose(_Symbol, _Period, i + 1); // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_st_atr_period, i);
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0 || prev_cl <= 0.0 || atr <= 0.0)
         return false;

      const double mid = (hi + lo) * 0.5;
      const double basic_upper = mid + strategy_fast_st_multiplier * atr;
      const double basic_lower = mid - strategy_fast_st_multiplier * atr;
      if(i == warmup)
        {
         fast_upper = basic_upper;
         fast_lower = basic_lower;
         fast_dir = (cl >= mid) ? 1 : -1;
        }
      else
        {
         fast_upper = (basic_upper < fast_upper || prev_cl > fast_upper) ? basic_upper : fast_upper;
         fast_lower = (basic_lower > fast_lower || prev_cl < fast_lower) ? basic_lower : fast_lower;
         if(fast_prev_line == fast_upper)
            fast_dir = (cl <= fast_upper) ? -1 : 1;
         else
            fast_dir = (cl >= fast_lower) ? 1 : -1;
        }
      fast_prev_line = (fast_dir > 0) ? fast_lower : fast_upper;
     }

   int slow_dir = 0;
   double slow_line = 0.0;
   double slow_upper = 0.0;
   double slow_lower = 0.0;
   double slow_prev_line = 0.0;
   for(int i = warmup; i >= 1; --i)
     {
      const double hi = iHigh(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double lo = iLow(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double cl = iClose(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double prev_cl = iClose(_Symbol, _Period, i + 1); // perf-allowed: bespoke SuperTrend OHLC, bounded closed-bar loop
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_st_atr_period, i);
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0 || prev_cl <= 0.0 || atr <= 0.0)
         return false;

      const double mid = (hi + lo) * 0.5;
      const double basic_upper = mid + strategy_slow_st_multiplier * atr;
      const double basic_lower = mid - strategy_slow_st_multiplier * atr;
      if(i == warmup)
        {
         slow_upper = basic_upper;
         slow_lower = basic_lower;
         slow_dir = (cl >= mid) ? 1 : -1;
        }
      else
        {
         slow_upper = (basic_upper < slow_upper || prev_cl > slow_upper) ? basic_upper : slow_upper;
         slow_lower = (basic_lower > slow_lower || prev_cl < slow_lower) ? basic_lower : slow_lower;
         if(slow_prev_line == slow_upper)
            slow_dir = (cl <= slow_upper) ? -1 : 1;
         else
            slow_dir = (cl >= slow_lower) ? 1 : -1;
        }
      slow_line = (slow_dir > 0) ? slow_lower : slow_upper;
      slow_prev_line = slow_line;
     }

   if(fast_dir == 0 || slow_dir == 0 || slow_line <= 0.0)
      return false;

   bool adx_rising = true;
   for(int k = 1; k <= strategy_adx_rising_window; ++k)
     {
      const double adx_now = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, k);
      const double adx_prev = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, k + 1);
      if(adx_now <= 0.0 || adx_prev <= 0.0 || adx_now <= adx_prev)
        {
         adx_rising = false;
         break;
        }
     }
   const double adx_last = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
   if(!adx_rising || (strategy_adx_floor > 0.0 && adx_last <= strategy_adx_floor))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double fallback_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || fallback_atr <= 0.0)
      return false;

   if(fast_dir > 0 && slow_dir > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = (slow_line > 0.0 && slow_line < ask) ? slow_line : ask - 2.0 * fallback_atr;
      req.tp = 0.0;
      req.reason = "dual_supertrend_adx_long";
      return (req.sl > 0.0 && req.sl < ask - point);
     }

   if(fast_dir < 0 && slow_dir < 0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = (slow_line > bid) ? slow_line : bid + 2.0 * fallback_atr;
      req.tp = 0.0;
      req.reason = "dual_supertrend_adx_short";
      return (req.sl > bid + point);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_slow_st_atr_period <= 1 || strategy_slow_st_multiplier <= 0.0)
      return;

   const int warmup = MathMax(strategy_supertrend_warmup_bars, strategy_slow_st_atr_period * 4);
   int slow_dir = 0;
   double slow_line = 0.0;
   double slow_upper = 0.0;
   double slow_lower = 0.0;
   double slow_prev_line = 0.0;
   for(int i = warmup; i >= 1; --i)
     {
      const double hi = iHigh(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for trailing stop
      const double lo = iLow(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for trailing stop
      const double cl = iClose(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for trailing stop
      const double prev_cl = iClose(_Symbol, _Period, i + 1); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for trailing stop
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_st_atr_period, i);
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0 || prev_cl <= 0.0 || atr <= 0.0)
         return;

      const double mid = (hi + lo) * 0.5;
      const double basic_upper = mid + strategy_slow_st_multiplier * atr;
      const double basic_lower = mid - strategy_slow_st_multiplier * atr;
      if(i == warmup)
        {
         slow_upper = basic_upper;
         slow_lower = basic_lower;
         slow_dir = (cl >= mid) ? 1 : -1;
        }
      else
        {
         slow_upper = (basic_upper < slow_upper || prev_cl > slow_upper) ? basic_upper : slow_upper;
         slow_lower = (basic_lower > slow_lower || prev_cl < slow_lower) ? basic_lower : slow_lower;
         if(slow_prev_line == slow_upper)
            slow_dir = (cl <= slow_upper) ? -1 : 1;
         else
            slow_dir = (cl >= slow_lower) ? 1 : -1;
        }
      slow_line = (slow_dir > 0) ? slow_lower : slow_upper;
      slow_prev_line = slow_line;
     }
   if(slow_line <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(ptype == POSITION_TYPE_BUY && slow_line < bid && (current_sl <= 0.0 || slow_line > current_sl + point))
         QM_TM_MoveSL(ticket, slow_line, "slow_supertrend_trail_long");
      if(ptype == POSITION_TYPE_SELL && slow_line > ask && (current_sl <= 0.0 || slow_line < current_sl - point))
         QM_TM_MoveSL(ticket, slow_line, "slow_supertrend_trail_short");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_position = false;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      has_position = true;
      break;
     }
   if(!has_position)
      return false;

   const int warmup = MathMax(strategy_supertrend_warmup_bars,
                              MathMax(strategy_fast_st_atr_period, strategy_slow_st_atr_period) * 4);
   int fast_dir = 0;
   double fast_upper = 0.0;
   double fast_lower = 0.0;
   double fast_prev_line = 0.0;
   for(int i = warmup; i >= 1; --i)
     {
      const double hi = iHigh(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for confirmed-bar exit
      const double lo = iLow(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for confirmed-bar exit
      const double cl = iClose(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for confirmed-bar exit
      const double prev_cl = iClose(_Symbol, _Period, i + 1); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for confirmed-bar exit
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_st_atr_period, i);
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0 || prev_cl <= 0.0 || atr <= 0.0)
         return false;
      const double mid = (hi + lo) * 0.5;
      const double basic_upper = mid + strategy_fast_st_multiplier * atr;
      const double basic_lower = mid - strategy_fast_st_multiplier * atr;
      if(i == warmup)
        {
         fast_upper = basic_upper;
         fast_lower = basic_lower;
         fast_dir = (cl >= mid) ? 1 : -1;
        }
      else
        {
         fast_upper = (basic_upper < fast_upper || prev_cl > fast_upper) ? basic_upper : fast_upper;
         fast_lower = (basic_lower > fast_lower || prev_cl < fast_lower) ? basic_lower : fast_lower;
         if(fast_prev_line == fast_upper)
            fast_dir = (cl <= fast_upper) ? -1 : 1;
         else
            fast_dir = (cl >= fast_lower) ? 1 : -1;
        }
      fast_prev_line = (fast_dir > 0) ? fast_lower : fast_upper;
     }

   int slow_dir = 0;
   double slow_upper = 0.0;
   double slow_lower = 0.0;
   double slow_prev_line = 0.0;
   for(int i = warmup; i >= 1; --i)
     {
      const double hi = iHigh(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for confirmed-bar exit
      const double lo = iLow(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for confirmed-bar exit
      const double cl = iClose(_Symbol, _Period, i); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for confirmed-bar exit
      const double prev_cl = iClose(_Symbol, _Period, i + 1); // perf-allowed: bespoke SuperTrend OHLC, bounded loop for confirmed-bar exit
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_st_atr_period, i);
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0 || prev_cl <= 0.0 || atr <= 0.0)
         return false;
      const double mid = (hi + lo) * 0.5;
      const double basic_upper = mid + strategy_slow_st_multiplier * atr;
      const double basic_lower = mid - strategy_slow_st_multiplier * atr;
      if(i == warmup)
        {
         slow_upper = basic_upper;
         slow_lower = basic_lower;
         slow_dir = (cl >= mid) ? 1 : -1;
        }
      else
        {
         slow_upper = (basic_upper < slow_upper || prev_cl > slow_upper) ? basic_upper : slow_upper;
         slow_lower = (basic_lower > slow_lower || prev_cl < slow_lower) ? basic_lower : slow_lower;
         if(slow_prev_line == slow_upper)
            slow_dir = (cl <= slow_upper) ? -1 : 1;
         else
            slow_dir = (cl >= slow_lower) ? 1 : -1;
        }
      slow_prev_line = (slow_dir > 0) ? slow_lower : slow_upper;
     }

   if(ptype == POSITION_TYPE_BUY && (fast_dir < 0 || slow_dir < 0))
      return true;
   if(ptype == POSITION_TYPE_SELL && (fast_dir > 0 || slow_dir > 0))
      return true;

   bool adx_flat = true;
   for(int k = 1; k <= strategy_adx_flat_exit_bars; ++k)
     {
      const double adx_now = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, k);
      const double adx_prev = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, k + 1);
      if(adx_now > adx_prev)
        {
         adx_flat = false;
         break;
        }
     }
   if(adx_flat)
      return true;

   const int max_bars = (_Period == PERIOD_H4) ? strategy_max_h4_bars : strategy_max_h1_bars;
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(max_bars > 0 && period_seconds > 0 && open_time > 0)
     {
      const int bars_held = (int)((TimeCurrent() - open_time) / period_seconds);
      if(bars_held >= max_bars)
         return true;
     }

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
