#property strict
#property version   "5.0"
#property description "QM5_10967 FTMO Inverse Fair Value Gap reversal"

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
input int    qm_ea_id                   = 10967;
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
input int    strategy_atr_period                 = 14;
input int    strategy_swing_lookback_bars        = 20;
input int    strategy_reclaim_window_bars        = 12;
input int    strategy_time_exit_bars             = 32;
input double strategy_displacement_atr_mult      = 1.2;
input double strategy_reclaim_range_atr_mult     = 0.8;
input double strategy_fvg_min_atr_mult           = 0.25;
input double strategy_fvg_max_atr_mult           = 2.0;
input double strategy_stop_atr_buffer_mult       = 0.25;
input double strategy_tp_rr                      = 2.0;
input double strategy_be_trigger_rr              = 1.0;
input double strategy_max_spread_r_fraction      = 0.15;

bool g_strategy_close_opposite = false;

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

   if((ENUM_TIMEFRAMES)_Period != PERIOD_M15)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_position = false;
   int open_dir = 0;
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
      has_position = true;
      open_dir = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      break;
     }

   if(has_position && g_strategy_close_opposite)
      return false;
   if(!has_position)
      g_strategy_close_opposite = false;

   const int atr_period = MathMax(2, strategy_atr_period);
   const int swing_lookback = MathMax(2, strategy_swing_lookback_bars);
   int max_gap_shift = MathMax(1, strategy_reclaim_window_bars) + 1;
   if(max_gap_shift < 2)
      max_gap_shift = 2;

   const double atr_reclaim = QM_ATR(_Symbol, PERIOD_M15, atr_period, 1);
   if(atr_reclaim <= 0.0)
      return false;

   // perf-allowed: bespoke IFVG reclaim candle reads run only after the framework QM_IsNewBar() gate.
   const double reclaim_open = iOpen(_Symbol, PERIOD_M15, 1);   // perf-allowed
   const double reclaim_high = iHigh(_Symbol, PERIOD_M15, 1);   // perf-allowed
   const double reclaim_low = iLow(_Symbol, PERIOD_M15, 1);     // perf-allowed
   const double reclaim_close = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed
   if(reclaim_open <= 0.0 || reclaim_high <= 0.0 || reclaim_low <= 0.0 || reclaim_close <= 0.0)
      return false;

   const double reclaim_range = reclaim_high - reclaim_low;
   if(reclaim_range < atr_reclaim * strategy_reclaim_range_atr_mult)
      return false;

   const bool reclaim_upper_35 = (reclaim_close >= reclaim_low + reclaim_range * 0.65);
   const bool reclaim_lower_35 = (reclaim_close <= reclaim_low + reclaim_range * 0.35);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(ask <= 0.0 || bid <= 0.0 || spread < 0.0)
      return false;

   for(int gap_shift = 2; gap_shift <= max_gap_shift; ++gap_shift)
     {
      const int candle1_shift = gap_shift + 2;
      const int displacement_shift = gap_shift + 1;
      const int trend_shift = gap_shift + swing_lookback;

      // perf-allowed: bounded IFVG scan, max 12 setups per closed bar, no per-tick history loop.
      const double c1_high = iHigh(_Symbol, PERIOD_M15, candle1_shift);             // perf-allowed
      const double c1_low = iLow(_Symbol, PERIOD_M15, candle1_shift);               // perf-allowed
      const double c3_high = iHigh(_Symbol, PERIOD_M15, gap_shift);                 // perf-allowed
      const double c3_low = iLow(_Symbol, PERIOD_M15, gap_shift);                   // perf-allowed
      const double c3_close = iClose(_Symbol, PERIOD_M15, gap_shift);               // perf-allowed
      const double trend_close = iClose(_Symbol, PERIOD_M15, trend_shift);          // perf-allowed
      const double displacement_open = iOpen(_Symbol, PERIOD_M15, displacement_shift);   // perf-allowed
      const double displacement_close = iClose(_Symbol, PERIOD_M15, displacement_shift); // perf-allowed
      if(c1_high <= 0.0 || c1_low <= 0.0 || c3_high <= 0.0 || c3_low <= 0.0 ||
         c3_close <= 0.0 || trend_close <= 0.0 || displacement_open <= 0.0 || displacement_close <= 0.0)
         continue;

      const double atr_displacement = QM_ATR(_Symbol, PERIOD_M15, atr_period, displacement_shift);
      if(atr_displacement <= 0.0)
         continue;

      const double displacement_body = MathAbs(displacement_close - displacement_open);
      if(displacement_body < atr_displacement * strategy_displacement_atr_mult)
         continue;

      if(c1_low > c3_high)
        {
         const double lower_boundary = c3_high;
         const double upper_boundary = c1_low;
         const double fvg_height = upper_boundary - lower_boundary;
         if(fvg_height < atr_displacement * strategy_fvg_min_atr_mult ||
            fvg_height > atr_displacement * strategy_fvg_max_atr_mult)
            continue;
         if(c3_close >= trend_close)
            continue;
         if(!reclaim_upper_35 || reclaim_close <= upper_boundary)
            continue;

         bool traded_through = false;
         for(int s = 1; s < gap_shift; ++s)
           {
            const double low_s = iLow(_Symbol, PERIOD_M15, s); // perf-allowed
            if(low_s > 0.0 && low_s <= lower_boundary)
              {
               traded_through = true;
               break;
              }
           }
         if(!traded_through)
            continue;

         if(has_position)
           {
            if(open_dir < 0)
               g_strategy_close_opposite = true;
            return false;
           }

         double sequence_low = reclaim_low;
         for(int s = 2; s <= candle1_shift; ++s)
           {
            const double low_s = iLow(_Symbol, PERIOD_M15, s); // perf-allowed
            if(low_s > 0.0 && low_s < sequence_low)
               sequence_low = low_s;
           }

         const double sl = sequence_low - atr_reclaim * strategy_stop_atr_buffer_mult;
         const double r_dist = ask - sl;
         if(r_dist <= 0.0)
            continue;
         if(spread > r_dist * strategy_max_spread_r_fraction)
            continue;

         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = ask + r_dist * strategy_tp_rr;
         req.reason = "FTMO_IFVG_LONG_RECLAIM";
         return true;
        }

      if(c1_high < c3_low)
        {
         const double lower_boundary = c1_high;
         const double upper_boundary = c3_low;
         const double fvg_height = upper_boundary - lower_boundary;
         if(fvg_height < atr_displacement * strategy_fvg_min_atr_mult ||
            fvg_height > atr_displacement * strategy_fvg_max_atr_mult)
            continue;
         if(c3_close <= trend_close)
            continue;
         if(!reclaim_lower_35 || reclaim_close >= lower_boundary)
            continue;

         bool traded_through = false;
         for(int s = 1; s < gap_shift; ++s)
           {
            const double high_s = iHigh(_Symbol, PERIOD_M15, s); // perf-allowed
            if(high_s > 0.0 && high_s >= upper_boundary)
              {
               traded_through = true;
               break;
              }
           }
         if(!traded_through)
            continue;

         if(has_position)
           {
            if(open_dir > 0)
               g_strategy_close_opposite = true;
            return false;
           }

         double sequence_high = reclaim_high;
         for(int s = 2; s <= candle1_shift; ++s)
           {
            const double high_s = iHigh(_Symbol, PERIOD_M15, s); // perf-allowed
            if(high_s > sequence_high)
               sequence_high = high_s;
           }

         const double sl = sequence_high + atr_reclaim * strategy_stop_atr_buffer_mult;
         const double r_dist = sl - bid;
         if(r_dist <= 0.0)
            continue;
         if(spread > r_dist * strategy_max_spread_r_fraction)
            continue;

         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = bid - r_dist * strategy_tp_rr;
         req.reason = "FTMO_IFVG_SHORT_RECLAIM";
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      double initial_r = MathAbs(open_price - current_sl);
      if(current_tp > 0.0 && strategy_tp_rr > 0.0)
         initial_r = MathAbs(current_tp - open_price) / strategy_tp_rr;
      if(initial_r <= 0.0)
         continue;

      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double favorable = is_buy ? (market - open_price) : (open_price - market);
      if(favorable < initial_r * strategy_be_trigger_rr)
         continue;

      const double be_sl = open_price;
      const bool improves = is_buy ? (be_sl > current_sl + point * 0.5)
                                   : (be_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, be_sl, "ftmo_ifvg_1r_breakeven");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int period_seconds = PeriodSeconds(PERIOD_M15);
   const int hold_seconds = MathMax(1, strategy_time_exit_bars) * period_seconds;
   const datetime now = TimeCurrent();

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

      has_position = true;
      if(g_strategy_close_opposite)
         return true;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(hold_seconds > 0 && opened > 0 && now - opened >= hold_seconds)
         return true;
     }

   if(!has_position)
      g_strategy_close_opposite = false;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // High-impact news avoidance is handled by the framework's two-axis news inputs.
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
