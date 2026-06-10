#property strict
#property version   "5.0"
#property description "QM5_10126 Carver SMA crossover volatility stop"

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
input int    qm_ea_id                   = 10126;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_D1;
input int             strategy_fast_sma_period = 16;
input int             strategy_slow_sma_period = 64;
input int             strategy_vol_lookback    = 252;
input double          strategy_vol_stop_mult   = 0.50;
input bool            strategy_enable_shorts   = true;
input bool            strategy_reentry_skip    = true;

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

   if(strategy_fast_sma_period <= 0 ||
      strategy_slow_sma_period <= 0 ||
      strategy_fast_sma_period >= strategy_slow_sma_period ||
      strategy_vol_lookback < 2 ||
      strategy_vol_stop_mult <= 0.0)
      return false;

   const int bars_required = MathMax(strategy_vol_lookback + 5, strategy_slow_sma_period + 5);
   if(Bars(_Symbol, strategy_timeframe) < bars_required) // perf-allowed — warmup guard, structural check runs once per D1 bar
      return false;

   const double fast = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1);
   const double slow = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 1);
   if(fast <= 0.0 || slow <= 0.0 || fast == slow)
      return false;

   const int trend = (fast > slow) ? 1 : -1;
   const int magic = QM_FrameworkMagic();
   const string state_prefix = StringFormat("QM5_10126.%s.%d", _Symbol, qm_magic_slot_offset);
   const string gv_had = state_prefix + ".had_position";
   const string gv_dir = state_prefix + ".last_direction";
   const string gv_block_long = state_prefix + ".block_long";
   const string gv_block_short = state_prefix + ".block_short";

   bool have_position = false;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   double current_sl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      have_position = true;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      current_sl = PositionGetDouble(POSITION_SL);
      break;
     }

   if(have_position)
     {
      double closes_pos[];
      ArraySetAsSeries(closes_pos, true);
      const int copied_pos = CopyClose(_Symbol, strategy_timeframe, 0, strategy_vol_lookback + 2, closes_pos);
      if(copied_pos >= strategy_vol_lookback + 2)
        {
         double sum_sq_pos = 0.0;
         int n_pos = 0;
         for(int r = 1; r <= strategy_vol_lookback; ++r)
           {
            if(closes_pos[r] <= 0.0 || closes_pos[r + 1] <= 0.0)
               continue;
            const double ret = MathLog(closes_pos[r] / closes_pos[r + 1]);
            sum_sq_pos += ret * ret;
            n_pos++;
           }
         if(n_pos >= strategy_vol_lookback - 5)
           {
            const double annual_vol_pos = MathSqrt(sum_sq_pos / (double)n_pos) * MathSqrt(252.0);
            const double close_last_pos = closes_pos[1];
            double trail_sl = 0.0;
            if(position_type == POSITION_TYPE_BUY)
               trail_sl = close_last_pos * (1.0 - strategy_vol_stop_mult * annual_vol_pos);
            else
               trail_sl = close_last_pos * (1.0 + strategy_vol_stop_mult * annual_vol_pos);
            trail_sl = QM_TM_NormalizePrice(_Symbol, trail_sl);

            if(trail_sl > 0.0 &&
               ((position_type == POSITION_TYPE_BUY && (current_sl <= 0.0 || trail_sl > current_sl)) ||
                (position_type == POSITION_TYPE_SELL && (current_sl <= 0.0 || trail_sl < current_sl))))
               QM_TM_MoveSL(ticket, trail_sl, "CARVER_VOL_TRAIL");
           }
        }

      GlobalVariableSet(gv_had, 1.0);
      GlobalVariableSet(gv_dir, (position_type == POSITION_TYPE_BUY) ? 1.0 : -1.0);
      return false;
     }

   if(GlobalVariableCheck(gv_had) && GlobalVariableGet(gv_had) > 0.5)
     {
      const int last_dir = GlobalVariableCheck(gv_dir) ? (int)GlobalVariableGet(gv_dir) : 0;
      if(last_dir == 1)
        {
         if(trend > 0 && strategy_reentry_skip)
            GlobalVariableSet(gv_block_long, 1.0);
         if(trend < 0)
            GlobalVariableSet(gv_block_long, 0.0);
        }
      else if(last_dir == -1)
        {
         if(trend < 0 && strategy_reentry_skip)
            GlobalVariableSet(gv_block_short, 1.0);
         if(trend > 0)
            GlobalVariableSet(gv_block_short, 0.0);
        }
      GlobalVariableSet(gv_had, 0.0);
     }

   if(trend < 0)
      GlobalVariableSet(gv_block_long, 0.0);
   if(trend > 0)
      GlobalVariableSet(gv_block_short, 0.0);

   if(trend > 0 && strategy_reentry_skip &&
      GlobalVariableCheck(gv_block_long) && GlobalVariableGet(gv_block_long) > 0.5)
      return false;
   if(trend < 0 && strategy_reentry_skip &&
      GlobalVariableCheck(gv_block_short) && GlobalVariableGet(gv_block_short) > 0.5)
      return false;
   if(trend < 0 && !strategy_enable_shorts)
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, strategy_timeframe, 0, strategy_vol_lookback + 2, closes);
   if(copied < strategy_vol_lookback + 2)
      return false;

   double sum_sq = 0.0;
   int n = 0;
   for(int r = 1; r <= strategy_vol_lookback; ++r)
     {
      if(closes[r] <= 0.0 || closes[r + 1] <= 0.0)
         continue;
      const double ret = MathLog(closes[r] / closes[r + 1]);
      sum_sq += ret * ret;
      n++;
     }
   if(n < strategy_vol_lookback - 5)
      return false;

   const double annual_vol = MathSqrt(sum_sq / (double)n) * MathSqrt(252.0);
   const double close_last = closes[1];
   if(annual_vol <= 0.0 || close_last <= 0.0)
      return false;

   req.type = (trend > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = (trend > 0)
            ? close_last * (1.0 - strategy_vol_stop_mult * annual_vol)
            : close_last * (1.0 + strategy_vol_stop_mult * annual_vol);
   req.sl = QM_TM_NormalizePrice(_Symbol, req.sl);
   req.tp = 0.0;
   req.reason = (trend > 0) ? "CARVER_SMA_LONG" : "CARVER_SMA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry = (trend > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || req.sl <= 0.0)
      return false;
   if((trend > 0 && req.sl >= entry) || (trend < 0 && req.sl <= entry))
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const double fast = QM_SMA(_Symbol, strategy_timeframe, strategy_fast_sma_period, 1);
   const double slow = QM_SMA(_Symbol, strategy_timeframe, strategy_slow_sma_period, 1);
   if(fast <= 0.0 || slow <= 0.0 || fast == slow)
      return false;

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

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && fast < slow)
         return true;
      if(position_type == POSITION_TYPE_SELL && fast > slow)
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
