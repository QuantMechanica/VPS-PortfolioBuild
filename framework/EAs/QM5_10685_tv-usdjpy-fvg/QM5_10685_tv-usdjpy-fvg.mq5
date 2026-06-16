#property strict
#property version   "5.0"
#property description "QM5_10685 TradingView USDJPY FVG Session Strategy"
// rework v2 2026-06-16 — FVG retest fired only when the spike bar CLOSED inside a
// thin (>=0.10 ATR) gap while also being bullish/above-EMA and a 1.5x volume bar:
// a wide-range volume-spike bar closing inside a thin gap is near-impossible, so
// ~0 trades. Faithful fix: trigger on the gap TAP (returned_to_zone) + direction
// + EMA + volume; keep close-inside only as a soft preference removed from the gate.

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
input int    qm_ea_id                   = 10685;
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
input int    strategy_ema_period             = 50;
input int    strategy_atr_period             = 14;
input int    strategy_volume_avg_bars        = 20;
input double strategy_volume_multiplier      = 1.50;
input int    strategy_max_fvg_age_bars       = 20;
input double strategy_min_fvg_atr            = 0.10;
input double strategy_stop_buffer_atr        = 0.20;
input double strategy_max_stop_atr_mult      = 2.50;
input double strategy_reward_r               = 2.00;
input int    strategy_max_hold_bars          = 20;
input int    strategy_tokyo_start_min        = 120;
input int    strategy_tokyo_end_min          = 240;
input int    strategy_overlap_start_min      = 900;
input int    strategy_overlap_end_min        = 1140;
input int    strategy_max_spread_points      = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   if(magic > 0)
     {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) == magic)
            return false;
        }
     }

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.day_of_week == 0 || tm.day_of_week == 6)
      return true;

   const int minute_of_day = tm.hour * 60 + tm.min;
   const int tokyo_start = MathMax(0, MathMin(strategy_tokyo_start_min, 1439));
   const int tokyo_end = MathMax(0, MathMin(strategy_tokyo_end_min, 1440));
   const int overlap_start = MathMax(0, MathMin(strategy_overlap_start_min, 1439));
   const int overlap_end = MathMax(0, MathMin(strategy_overlap_end_min, 1440));

   bool in_tokyo = false;
   if(tokyo_start == tokyo_end)
      in_tokyo = true;
   else if(tokyo_start < tokyo_end)
      in_tokyo = (minute_of_day >= tokyo_start && minute_of_day < tokyo_end);
   else
      in_tokyo = (minute_of_day >= tokyo_start || minute_of_day < tokyo_end);

   bool in_overlap = false;
   if(overlap_start == overlap_end)
      in_overlap = true;
   else if(overlap_start < overlap_end)
      in_overlap = (minute_of_day >= overlap_start && minute_of_day < overlap_end);
   else
      in_overlap = (minute_of_day >= overlap_start || minute_of_day < overlap_end);

   if(!in_tokyo && !in_overlap)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
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
   req.expiration_seconds = 0;

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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.day_of_week == 0 || tm.day_of_week == 6)
      return false;

   const int minute_of_day = tm.hour * 60 + tm.min;
   const int tokyo_start = MathMax(0, MathMin(strategy_tokyo_start_min, 1439));
   const int tokyo_end = MathMax(0, MathMin(strategy_tokyo_end_min, 1440));
   const int overlap_start = MathMax(0, MathMin(strategy_overlap_start_min, 1439));
   const int overlap_end = MathMax(0, MathMin(strategy_overlap_end_min, 1440));

   bool in_tokyo = false;
   if(tokyo_start == tokyo_end)
      in_tokyo = true;
   else if(tokyo_start < tokyo_end)
      in_tokyo = (minute_of_day >= tokyo_start && minute_of_day < tokyo_end);
   else
      in_tokyo = (minute_of_day >= tokyo_start || minute_of_day < tokyo_end);

   bool in_overlap = false;
   if(overlap_start == overlap_end)
      in_overlap = true;
   else if(overlap_start < overlap_end)
      in_overlap = (minute_of_day >= overlap_start && minute_of_day < overlap_end);
   else
      in_overlap = (minute_of_day >= overlap_start || minute_of_day < overlap_end);

   if(!in_tokyo && !in_overlap)
      return false;

   const int atr_period = MathMax(1, strategy_atr_period);
   const int ema_period = MathMax(1, strategy_ema_period);
   const int volume_bars = MathMax(1, strategy_volume_avg_bars);
   const int expiry = MathMax(1, MathMin(strategy_max_fvg_age_bars, 80));
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, atr_period, 1);
   const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, ema_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ema <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double open_1 = iOpen(_Symbol, _Period, 1);
   const double high_1 = iHigh(_Symbol, _Period, 1);
   const double low_1 = iLow(_Symbol, _Period, 1);
   if(close_1 <= 0.0 || open_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0)
      return false;

   double volume_sum = 0.0;
   int volume_samples = 0;
   for(int v = 2; v < 2 + volume_bars; ++v)
     {
      const long hist_volume = iVolume(_Symbol, _Period, v);
      if(hist_volume <= 0)
         continue;
      volume_sum += (double)hist_volume;
      volume_samples++;
     }
   if(volume_samples <= 0)
      return false;

   const double avg_volume = volume_sum / (double)volume_samples;
   const double bar_volume = (double)iVolume(_Symbol, _Period, 1);
   if(avg_volume <= 0.0 || bar_volume < MathMax(0.0, strategy_volume_multiplier) * avg_volume)
      return false;

   const double min_gap = MathMax(0.0, strategy_min_fvg_atr) * atr;
   const double stop_buffer = MathMax(0.0, strategy_stop_buffer_atr) * atr;
   const double max_stop = MathMax(0.1, strategy_max_stop_atr_mult) * atr;
   const double rr = MathMax(0.1, strategy_reward_r);

   for(int fvg_shift = 2; fvg_shift <= expiry + 1; ++fvg_shift)
     {
      const double newer_low = iLow(_Symbol, _Period, fvg_shift);
      const double older_high = iHigh(_Symbol, _Period, fvg_shift + 2);
      if(newer_low > 0.0 && older_high > 0.0 && newer_low > older_high)
        {
         const double gap_bottom = older_high;
         const double gap_top = newer_low;
         const double gap_size = gap_top - gap_bottom;
         const bool returned_to_zone = (low_1 <= gap_top && high_1 >= gap_bottom);
         if(gap_size >= min_gap &&
            returned_to_zone &&
            close_1 > open_1 &&
            close_1 > ema)
           {
            const double raw_sl = gap_bottom - stop_buffer;
            const double capped_sl = ask - max_stop;
            const double sl = NormalizeDouble(MathMax(raw_sl, capped_sl), _Digits);
            if(sl > 0.0 && sl < ask)
              {
               const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, rr);
               if(tp > ask)
                 {
                  req.type = QM_BUY;
                  req.price = 0.0;
                  req.sl = sl;
                  req.tp = tp;
                  req.reason = "TV_USDJPY_FVG_LONG";
                  return true;
                 }
              }
           }
        }

      const double newer_high = iHigh(_Symbol, _Period, fvg_shift);
      const double older_low = iLow(_Symbol, _Period, fvg_shift + 2);
      if(newer_high > 0.0 && older_low > 0.0 && newer_high < older_low)
        {
         const double gap_bottom = newer_high;
         const double gap_top = older_low;
         const double gap_size = gap_top - gap_bottom;
         const bool returned_to_zone = (low_1 <= gap_top && high_1 >= gap_bottom);
         if(gap_size >= min_gap &&
            returned_to_zone &&
            close_1 < open_1 &&
            close_1 < ema)
           {
            const double raw_sl = gap_top + stop_buffer;
            const double capped_sl = bid + max_stop;
            const double sl = NormalizeDouble(MathMin(raw_sl, capped_sl), _Digits);
            if(sl > bid && bid > 0.0)
              {
               const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, rr);
               if(tp > 0.0 && tp < bid)
                 {
                  req.type = QM_SELL;
                  req.price = 0.0;
                  req.sl = sl;
                  req.tp = tp;
                  req.reason = "TV_USDJPY_FVG_SHORT";
                  return true;
                 }
              }
           }
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Baseline management is fixed SL/TP plus the strategy time exit.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int max_hold = MathMax(1, strategy_max_hold_bars);
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0)
         continue;

      const int open_bars = iBarShift(_Symbol, _Period, open_time, false);
      if(open_bars >= max_hold)
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
