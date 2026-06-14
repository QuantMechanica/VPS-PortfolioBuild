#property strict
#property version   "5.0"
#property description "QM5_10689 TradingView ZigZag BOS Retest"

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
input int    qm_ea_id                   = 10689;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_pivot_length       = 5;
input int    strategy_scan_bars          = 160;
input int    strategy_atr_period         = 14;
input double strategy_atr_buffer_mult    = 0.10;
input double strategy_target_rr          = 1.0;
input int    strategy_ny_start_hour      = 8;
input int    strategy_ny_start_minute    = 30;
input int    strategy_ny_end_hour        = 11;
input int    strategy_ny_end_minute      = 30;
input int    strategy_force_close_hour   = 16;
input int    strategy_force_close_minute = 0;

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
   static int      pending_direction = 0;
   static double   pending_level = 0.0;
   static double   pending_pivot = 0.0;
   static datetime pending_bos_time = 0;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int pivot_len = MathMax(2, strategy_pivot_length);
   const int scan_bars = MathMax(pivot_len * 6 + 20, MathMin(strategy_scan_bars, 240));
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: bespoke ZigZag/BOS structure scan, called only after framework QM_IsNewBar().
   const int copied = CopyRates(_Symbol, _Period, 1, scan_bars, rates);
   if(copied < pivot_len * 4 + 10)
      return false;

   int swing_types[24];
   int swing_shifts[24];
   double swing_prices[24];
   datetime swing_times[24];
   int swing_count = 0;

   for(int shift = copied - pivot_len - 1; shift >= pivot_len && swing_count < 24; --shift)
     {
      bool is_high = true;
      bool is_low = true;
      const double high = rates[shift].high;
      const double low = rates[shift].low;
      for(int k = 1; k <= pivot_len; ++k)
        {
         if(high <= rates[shift - k].high || high < rates[shift + k].high)
            is_high = false;
         if(low >= rates[shift - k].low || low > rates[shift + k].low)
            is_low = false;
        }
      if(!is_high && !is_low)
         continue;

      const int type = is_high ? 1 : -1;
      const double price = is_high ? high : low;
      if(swing_count > 0 && swing_types[swing_count - 1] == type)
        {
         const bool replace = (type == 1 && price > swing_prices[swing_count - 1]) ||
                              (type == -1 && price < swing_prices[swing_count - 1]);
         if(replace)
           {
            swing_shifts[swing_count - 1] = shift;
            swing_prices[swing_count - 1] = price;
            swing_times[swing_count - 1] = rates[shift].time;
           }
         continue;
        }

      swing_types[swing_count] = type;
      swing_shifts[swing_count] = shift;
      swing_prices[swing_count] = price;
      swing_times[swing_count] = rates[shift].time;
      ++swing_count;
     }

   if(swing_count < 4)
      return false;

   int last_high = -1;
   int prev_high = -1;
   int last_low = -1;
   int prev_low = -1;
   for(int i = swing_count - 1; i >= 0; --i)
     {
      if(swing_types[i] == 1)
        {
         if(last_high < 0)
            last_high = i;
         else if(prev_high < 0)
            prev_high = i;
        }
      else
        {
         if(last_low < 0)
            last_low = i;
         else if(prev_low < 0)
            prev_low = i;
        }
     }
   if(last_high < 0 || prev_high < 0 || last_low < 0 || prev_low < 0)
      return false;

   const bool up_structure = (swing_prices[last_high] > swing_prices[prev_high] &&
                              swing_prices[last_low] > swing_prices[prev_low]);
   const bool down_structure = (swing_prices[last_high] < swing_prices[prev_high] &&
                                swing_prices[last_low] < swing_prices[prev_low]);

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   const int ny_offset_hours = QM_IsUSDSTUTC(utc_now) ? -4 : -5;
   const datetime ny_now = utc_now + ny_offset_hours * 60 * 60;
   MqlDateTime dt;
   TimeToStruct(ny_now, dt);
   const int now_minutes = dt.hour * 60 + dt.min;
   const int start_minutes = strategy_ny_start_hour * 60 + strategy_ny_start_minute;
   const int end_minutes = strategy_ny_end_hour * 60 + strategy_ny_end_minute;
   const int force_minutes = strategy_force_close_hour * 60 + strategy_force_close_minute;
   const bool in_window = (now_minutes >= start_minutes && now_minutes <= end_minutes);

   if(now_minutes >= force_minutes)
     {
      pending_direction = 0;
      pending_level = 0.0;
      pending_pivot = 0.0;
      pending_bos_time = 0;
      return false;
     }

   const double close1 = rates[0].close;
   if(in_window && up_structure && close1 > swing_prices[last_high] && rates[0].time > pending_bos_time)
     {
      pending_direction = 1;
      pending_level = swing_prices[last_high];
      pending_pivot = swing_prices[last_low];
      pending_bos_time = rates[0].time;
     }
   else if(in_window && down_structure && close1 < swing_prices[last_low] && rates[0].time > pending_bos_time)
     {
      pending_direction = -1;
      pending_level = swing_prices[last_low];
      pending_pivot = swing_prices[last_high];
      pending_bos_time = rates[0].time;
     }

   if(pending_direction == 0 || rates[0].time <= pending_bos_time)
      return false;

   const bool long_retest = (pending_direction > 0 && rates[0].low <= pending_level && close1 >= pending_level);
   const bool short_retest = (pending_direction < 0 && rates[0].high >= pending_level && close1 <= pending_level);
   if(!long_retest && !short_retest)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double entry = (pending_direction > 0)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double buffer = atr * MathMax(0.0, strategy_atr_buffer_mult);
   const QM_OrderType side = (pending_direction > 0) ? QM_BUY : QM_SELL;
   double sl = (pending_direction > 0) ? (pending_pivot - buffer) : (pending_pivot + buffer);
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_target_rr);
   if(sl <= 0.0 || tp <= 0.0 || MathAbs(entry - sl) <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (pending_direction > 0) ? "BULLISH_BOS_RETEST" : "BEARISH_BOS_RETEST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   pending_direction = 0;
   pending_level = 0.0;
   pending_pivot = 0.0;
   pending_bos_time = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, scale-out, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   const int ny_offset_hours = QM_IsUSDSTUTC(utc_now) ? -4 : -5;
   const datetime ny_now = utc_now + ny_offset_hours * 60 * 60;
   MqlDateTime dt;
   TimeToStruct(ny_now, dt);
   const int now_minutes = dt.hour * 60 + dt.min;
   const int force_minutes = strategy_force_close_hour * 60 + strategy_force_close_minute;
   return (now_minutes >= force_minutes);
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
